// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
error RedemptionTransferFailed();