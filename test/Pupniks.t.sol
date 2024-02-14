// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/StdCheats.sol";
import "forge-std/StdAssertions.sol";
import "forge-std/StdUtils.sol";
import {TestBase} from "forge-std/Base.sol";
import "src/Pupniks.sol";

contract PupniksTest is TestBase, StdCheats, StdAssertions, StdUtils {

    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address signer;
    uint256 signerPkey;

    Pupniks public pupniks;

    function _deploy() internal {
        vm.warp(1707864020);

        vm.deal(owner, 10000 ether);

        vm.startPrank(owner);
        pupniks = new Pupniks();
        (signer, signerPkey) = makeAddrAndKey("signer");

        changePrank(user);
        vm.deal(user, 10000 ether);
    }

    function test_deployPupnik() public {
        _deploy();

        assertEq(pupniks.balanceOf(user), 0);
        assertEq(pupniks.amountMinted(), 0);
        assertEq(pupniks.saleLive(), false);
        assertEq(pupniks.locked(), false);
        assertEq(pupniks.PRICE(), 0.5 ether);
        assertEq(pupniks.TOTAL_SUPPLY(), 3000);
        assertEq(pupniks.owner(), owner);
    }

    function test_mintPupnik_mint(uint256 nonce, uint256 amount) public {
        amount = bound(amount, 1, 5);
        _deploy();

        changePrank(owner);
        pupniks.setSignerAddress(signer);
        pupniks.toggleSaleStatus();
        changePrank(user);

        assertEq(pupniks.saleLive(), true);
        assertEq(pupniks.isValidNonce(user, nonce), true);

        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = getSignature(user, nonce, amount, signerPkey);

        pupniks.mintPupnik{value: 0.5 ether * amount}(hash, abi.encodePacked(r, s, v), nonce, amount);
        assertEq(pupniks.balanceOf(user), amount);
        assertEq(pupniks.amountMinted(), amount);
        assertEq(pupniks.isValidNonce(user, nonce), false);
        assertEq(address(pupniks).balance, 0.5 ether * amount);
        assertEq(address(user).balance, 10000 ether - (0.5 ether * amount));
    }

    function test_mintPupnik_invalidSignature_badSigner(uint256 badPkey, uint256 nonce, uint256 amount) public {
        amount = bound(amount, 1, 5);
        badPkey = bound(badPkey, 1, 115792089237316195423570985008687907852837564279074904382605163141518161494336);
        vm.assume(badPkey != signerPkey);

        _deploy();

        changePrank(owner);
        pupniks.setSignerAddress(signer);
        pupniks.toggleSaleStatus();
        changePrank(user);

        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = getSignature(user, nonce, amount, badPkey);

        vm.expectRevert(InvalidSignature.selector);
        pupniks.mintPupnik{value: 0.5 ether}(hash, abi.encodePacked(r, s, v), nonce, amount);
    }

    function test_mintPupnik_invalidETHAmount(uint256 amount, uint256 nonce) public {
        amount = bound(amount, 0, 10000 ether);
        vm.assume(amount != 0.5 ether);
        _deploy();

        changePrank(owner);
        pupniks.setSignerAddress(signer);
        pupniks.toggleSaleStatus();
        changePrank(user);

        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = getSignature(user, nonce, 1, signerPkey);

        vm.expectRevert(IncorrectAmountSent.selector);
        pupniks.mintPupnik{value: amount}(hash, abi.encodePacked(r, s, v), nonce, 1);
    }

    function test_mintPupnik_usedNonce(uint256 amount, uint256 nonce) public {
        amount = bound(amount, 1, 5);
        nonce = bound(nonce, 0, 255);
        _deploy();

        uint256 ethToSend = 0.5 ether * amount;

        changePrank(owner);
        pupniks.setSignerAddress(signer);
        pupniks.toggleSaleStatus();
        changePrank(user);

        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = getSignature(user, nonce, amount, signerPkey);

        pupniks.mintPupnik{value: ethToSend}(hash, abi.encodePacked(r, s, v), nonce, amount);
        assertEq(pupniks.balanceOf(user), amount);
        assertEq(pupniks.amountMinted(), amount);
        assertEq(pupniks.isValidNonce(user, nonce), false);
        assertEq(address(pupniks).balance,ethToSend);
        assertEq(address(user).balance, 10000 ether - ethToSend);

        vm.expectRevert(NonceAlreadyUsedOrRevoked.selector);
        pupniks.mintPupnik{value: ethToSend}(hash, abi.encodePacked(r, s, v), nonce, amount);
    }

    function test_mintPupnik_incorrectCaller(uint256 nonce) public {
        _deploy();

        changePrank(owner);
        pupniks.setSignerAddress(signer);
        pupniks.toggleSaleStatus();

        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = getSignature(user, nonce, 1, signerPkey);

        vm.expectRevert(InvalidHash.selector);
        pupniks.mintPupnik{value: 0.5 ether}(hash, abi.encodePacked(r, s, v), nonce, 1);
    }

    function test_mintPupnik_maxSupplyExceeded(uint256 nonce) public {
        nonce = bound(nonce, 0, 255);
        _deploy();

        changePrank(owner);
        pupniks.setSignerAddress(signer);
        pupniks.toggleSaleStatus();
        changePrank(user);

        uint256 amountToSend = 0.5 ether * 5;

        for (uint256 i = 0; i < 600; i++) {
            (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = getSignature(user, nonce + i, 5, signerPkey);

            pupniks.mintPupnik{value: amountToSend}(hash, abi.encodePacked(r, s, v), nonce + i, 5);
        }

        assertEq(pupniks.amountMinted(), 3000);

        (bytes32 hash2, uint8 v2, bytes32 r2, bytes32 s2) = getSignature(user, nonce + 601, 1, signerPkey);

        vm.expectRevert(OutOfStock.selector);
        pupniks.mintPupnik{value: 0.5 ether}(hash2, abi.encodePacked(r2, s2, v2), nonce + 601, 1);
    }

    function test_redeemPupnik(uint256 amount) public {
        amount = bound(amount, 1, 5);
        _deploy();

        changePrank(owner);
        pupniks.setSignerAddress(signer);
        pupniks.toggleSaleStatus();
        changePrank(user);

        uint256 nonce = 0;

        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = getSignature(user, nonce, amount, signerPkey);

        pupniks.mintPupnik{value: 0.5 ether * amount}(hash, abi.encodePacked(r, s, v), nonce, amount);
        assertEq(pupniks.balanceOf(user), amount);
        assertEq(pupniks.amountMinted(), amount);
        assertEq(pupniks.isValidNonce(user, nonce), false);
        assertEq(address(pupniks).balance, 0.5 ether * amount);
        assertEq(address(user).balance, 10000 ether - (0.5 ether * amount));

        pupniks.redeemPupnik(1);
        assertEq(pupniks.balanceOf(user), amount - 1);
        assertEq(pupniks.amountMinted(), amount - 1);
        assertEq(address(pupniks).balance, 0.5 ether * (amount - 1));
        assertEq(address(user).balance, 10000 ether - (0.5 ether * (amount - 1)));
    }

    function test_batchRedeemPupnik() public {
        _deploy();

        changePrank(owner);
        pupniks.setSignerAddress(signer);
        pupniks.toggleSaleStatus();
        changePrank(user);

        uint256 nonce = 0;

        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = getSignature(user, nonce, 5, signerPkey);

        pupniks.mintPupnik{value: 0.5 ether * 5}(hash, abi.encodePacked(r, s, v), nonce, 5);
        assertEq(pupniks.balanceOf(user), 5);
        assertEq(pupniks.amountMinted(), 5);
        assertEq(pupniks.isValidNonce(user, nonce), false);
        assertEq(address(pupniks).balance, 0.5 ether * 5);
        assertEq(address(user).balance, 10000 ether - (0.5 ether * 5));

        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i + 1;
        }

        pupniks.redeemPupnikBatch(tokenIds);
        assertEq(pupniks.balanceOf(user), 0);
        assertEq(pupniks.amountMinted(), 0);
        assertEq(address(pupniks).balance, 0);
        assertEq(address(user).balance, 10000 ether);
    }

    function changePrank(address msgSender) internal virtual override {
        vm.stopPrank();
        vm.startPrank(msgSender);
    }

    function getSignature(address addr, uint256 nonce, uint256 quantity, uint256 pkey) public pure returns (bytes32 hash, uint8 v, bytes32 r, bytes32 s) {
        hash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(addr, quantity, nonce)))
          );
        (v, r, s) = vm.sign(pkey, hash);
    }
}