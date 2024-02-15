// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "src/interfaces/IBlast.sol";

uint256 constant TOTAL_SUPPLY = 3000;
uint256 constant PRICE = 0.5 ether;
uint256 constant MAX_MINTING_PER_TX = 5;
IBlast constant BLAST = IBlast(0x4300000000000000000000000000000000000002);