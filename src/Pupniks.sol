// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import "@solady/tokens/ERC721.sol";
import "@solady/auth/Ownable.sol";
import "@solady/utils/ECDSA.sol";
import "@solady/utils/LibString.sol";

error InvalidSignature();
error InvalidHash();
error SaleClosed();
error ContractLocked();
error OutOfStock();
error IncorrectAmountSent();
error NotApprovedOrOwner();
error TokenNotFound();
error NonceAlreadyUsedOrRevoked();
error CannotMintMoreThanMax();

contract Pupniks is ERC721, Ownable {
    using LibString for uint256;
    using ECDSA for bytes32;

    uint256 public constant TOTAL_SUPPLY = 3000;
    uint256 public constant PRICE = 0.5 ether;
    uint256 public constant MAX_MINTING_PER_TX = 5;
    uint256 private constant ONE = 1;
    uint256 private constant ZERO = 0;

    /// @dev Map of an address to a bitmap (slot => status)
    mapping(address => mapping(uint256 => uint256)) private _usedNonces;

    /// @dev Base token uri
    string public baseTokenURI;

    /// @dev Contract URI - ERC7572 compliance
    string public contractURI;

    uint256 public amountMinted;
    bool public saleLive;
    bool public locked;

    address private _signerAddress;

    constructor() ERC721() {
        _initializeOwner(msg.sender);
     }

    function mintPupnik(bytes32 hash, bytes calldata signature, uint256 nonce, uint256 quantity) external payable {
        _requireSaleOpen();
        _requireValidSignature(hash, signature, nonce, quantity);
        _useNonce(msg.sender, nonce);

        uint256 currentAmount = amountMinted;

        if (currentAmount + quantity > TOTAL_SUPPLY) {
            revert OutOfStock();
        }
        if (PRICE * quantity != msg.value) {
            revert IncorrectAmountSent();
        }
        if (quantity > MAX_MINTING_PER_TX) {
            revert CannotMintMoreThanMax();
        }

        unchecked {
            amountMinted += quantity;

            for (uint256 i = 1; i <= quantity;) {
                _mint(msg.sender, currentAmount + i);
                ++i;
            }
        }
    }

    function redeemPupnikBatch(uint256[] calldata tokenIds) external {
        unchecked {
            for (uint256 i = 0; i < tokenIds.length;) {
                _redeemPupnik(tokenIds[i]);
                ++i;
            }
        }
    }

    function redeemPupnik(uint256 tokenId) external  {
        _redeemPupnik(tokenId);
    }

    function _redeemPupnik(uint256 tokenId) private {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert NotApprovedOrOwner();
        }
        _burn(tokenId);

        payable(msg.sender).transfer(PRICE);
    }

    function lockMetadata() external onlyOwner {
        locked = true;
    }
    
    function toggleSaleStatus() external onlyOwner {
        saleLive = !saleLive;
    }
    
    function setSignerAddress(address addr) external onlyOwner {
        _signerAddress = addr;
    }
    
    function setContractURI(string calldata URI) external onlyOwner {
        _requireNotLocked();
        contractURI = URI;
    }

    function setBaseURI(string calldata URI) external onlyOwner {
        _requireNotLocked();
        baseTokenURI = URI;
    }
    
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        if (!_exists(tokenId)) {
            revert TokenNotFound();
        }
        return string(abi.encodePacked(baseTokenURI, tokenId.toString()));
    }

    function name() public pure override returns (string memory) {
        return "Pupniks";
    }

    function symbol() public pure override returns (string memory) {
        return "PUPNIK";
    }

    /// @dev This is a helper function to check if a nonce is valid
    function isValidNonce(address tokenOwner, uint256 nonce) external view returns (bool isValid) {
        isValid = ((_usedNonces[tokenOwner][uint248(nonce >> 8)] >> uint8(nonce)) & ONE) == ZERO;
    }

    function _requireValidSignature(bytes32 hash, bytes calldata signature, uint256 nonce, uint256 quantity) private view {
        if (_signerAddress != hash.recover(signature)) {
            revert InvalidSignature();
        }

        bytes32 localHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(msg.sender, quantity, nonce)))
          );

        if (localHash != hash) {
            revert InvalidHash();
        }
    }

    function _requireSaleOpen() private view {
        if (!saleLive) {
            revert SaleClosed();
        }
    }

    function _requireNotLocked() private view {
        if (locked) {
            revert ContractLocked();
        }
    }

    function _useNonce(address account, uint256 nonce) internal {
        unchecked {
            if (uint256(_usedNonces[account][uint248(nonce >> 8)] ^= (ONE << uint8(nonce))) & 
                (ONE << uint8(nonce)) == ZERO) {
                revert NonceAlreadyUsedOrRevoked();
            }
        }
    }
}