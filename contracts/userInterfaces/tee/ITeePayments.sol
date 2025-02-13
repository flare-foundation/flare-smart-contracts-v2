// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeePayments interface.
 */
interface ITeePayments {

    /// Payment instruction structure
    struct PaymentInstruction {
        bytes32 walletId;
        string recipientAddress;
        uint256 amount;
        bytes32 paymentReference;
    }

    struct PaymentInstructionMessage {
        bytes32 walletId;
        string senderAddress;
        string recipientAddress;
        uint256 amount;
        bytes32 paymentReference;
        uint256 nonce;
        uint256 subNonce;
        uint256 maxFee;
        uint256 maxFeeTolerancePPM;
        uint256 batchEndTs;
    }

    /**
     * Payment instruction method.
     * Can only be called by the submit address.
     * @param _paymentInstruction The payment instruction.
     * @return _subNonce The sequence number of the payment instruction.
     */
    function pay(PaymentInstruction calldata _paymentInstruction) external returns (uint256 _subNonce);
}