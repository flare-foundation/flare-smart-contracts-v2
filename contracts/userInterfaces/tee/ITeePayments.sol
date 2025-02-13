// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeePayments interface.
 */
interface ITeePayments {

    /// Payment instruction structure
    struct PaymentInstruction {
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
     * @param _walletId The wallet id.
     * @param _paymentInstruction The payment instruction.
     * @return _subNonce The sequence number of the payment instruction.
     */
    function send(
        bytes32 _walletId,
        PaymentInstruction calldata _paymentInstruction
    )
        external
        returns (uint256 _subNonce);

    /**
     * Payment reissuance method.
     * Can only be called by the control address.
     * @param _walletId The wallet id.
     * @param _nonce Batch nonce of the payment instruction to be reissued.
     * @param _paymentInstruction The payment instruction.
     * @param _fee The new (usually bumped) fee.
     * @param _nullify If true, nullification transaction should be issued instead.
     */
    function reissue(
        bytes32 _walletId,
        uint64 _nonce,
        PaymentInstruction[] calldata _paymentInstruction,
        uint96 _fee,
        bool _nullify
    )
        external;

    /**
     * Method for setting the control address.
     * Can only be called by the wallet owner.
     * @param _walletId The wallet id.
     * @param _controlAddress The new control address.
     */
    function setControlAddress(
        bytes32 _walletId,
        address _controlAddress
    )
        external;

    /**
    * Method for setting the fees.
    * Can only be called by the wallet owner.
    * @param _walletId The wallet id.
    * @param _maxFee The maximum fee.
    * @param _maxFeeTolerancePPM The maximum fee tolerance, in parts per million.
    * @param _maxControlFee The maximum control fee.
    */
    function setFees(
        bytes32 _walletId,
        uint96 _maxFee,
        uint32 _maxFeeTolerancePPM,
        uint96 _maxControlFee
    )
        external;

    /**
    * Method for setting the batch settings.
    * Can only be called by the wallet owner.
    * @param _walletId The wallet id.
    * @param _batchSize The batch size.
    * @param _batchDurationSeconds The batch duration in seconds.
    */
    function setBatchSettings(
        bytes32 _walletId,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        external;

}