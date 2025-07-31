// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeIdKeyIdPair.sol";

/**
 * TeePayments interface.
 */
interface ITeePayments {

    /// Payment instruction structure
    struct PaymentInstruction {
        string recipientAddress;
        uint256 amount;
        uint256 fee;
        bytes32 paymentReference;
    }

    struct PaymentInstructionMessage {
        bytes32 walletId;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        string senderAddress;
        string recipientAddress;
        uint256 amount;
        uint256 fee;
        bytes32 paymentReference;
        uint64 nonce;
        uint64 subNonce;
        uint64 batchEndTs;
    }

    struct SetPaymentLimits {
        bytes32 walletId;
        uint256 nonce;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        uint256 transactionLimit;
        uint256 dailyLimit;
    }

    event BatchSettingsSet(
        bytes32 indexed walletId,
        uint64 batchSize,
        uint64 batchDurationSeconds
    );

    event MinFeeSet(
        bytes32 indexed walletId,
        uint128 minFee
    );

    event SenderAddressSet(
        bytes32 indexed walletId,
        string senderAddress,
        uint64 initialNonce
    );

    /**
     * Payment instruction method.
     * @param _projectId The project id.
     * @param _walletId The wallet id.
     * @param _paymentInstruction The payment instruction.
     * @return _nonce The batch nonce of the payment instruction.
     * @return _subNonce The sequence number of the payment instruction.
     * Can only be called by the submit address of the project.
     */
    function pay(
        bytes32 _projectId,
        bytes32 _walletId,
        PaymentInstruction calldata _paymentInstruction
    )
        external payable
        returns (uint64 _nonce, uint64 _subNonce);

    /**
     * Payment reissuance method.
     * @param _walletId The wallet id.
     * @param _nonce Batch nonce of the payment instructions to be reissued.
     * @param _firstSubNonce SubNonce of the first payment instruction in the batch.
     * @param _paymentInstructions List of the payment instructions.
     * @param _fees List of fees for the payment instructions.
     * @param _nullify List of nullification flags for the payment instructions.
     * Can only be called by the submit address of the project.
     */
    function reissue(
        bytes32 _walletId,
        uint64 _nonce,
        uint64 _firstSubNonce,
        PaymentInstruction[] calldata _paymentInstructions,
        uint256[] calldata _fees,
        bool[] calldata _nullify
    )
        external payable;

    /**
     * Method for setting the sender address.
     * Emits SenderAddressSet event.
     * @param _walletId The wallet id.
     * @param _senderAddress The new sender address.
     * @param _initialNonce The initial nonce.
     * Can only be called by the wallet owner.
     */
    function setSenderAddressAndInitialNonce(
        bytes32 _walletId,
        string calldata _senderAddress,
        uint64 _initialNonce
    )
        external;

    /**
    * Method for setting the minimum fee.
    * Emits MinFeeSet event.
    * @param _walletId The wallet id.
    * @param _minFee The minimum fee.
    * Can only be called by the wallet owner.
    */
    function setMinFee(
        bytes32 _walletId,
        uint128 _minFee
    )
        external;

    /**
    * Method for setting the batch settings.
    * Emits BatchSettingsSet event.
    * @param _walletId The wallet id.
    * @param _batchSize The batch size.
    * @param _batchDurationSeconds The batch duration in seconds.
    * Can only be called by the wallet owner.
    */
    function setBatchSettings(
        bytes32 _walletId,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        external;

    /**
     * Set payment limits instruction method.
     * @param _walletId The wallet id.
     * @param _transactionLimit The transaction limit.
     * @param _dailyLimit The daily limit.
     * Can only be called by the wallet owner address.
     */
    function setPaymentLimits(
        bytes32 _walletId,
        uint256 _transactionLimit,
        uint256 _dailyLimit
    )
        external payable;

    /**
     * Returns the wallet operation type.
     * @return _opType The operation type.
     */
    function getOpType() external view returns (bytes32);

    /**
     * Returns wallet's sender address.
     * @param _walletId The wallet id.
     * @return _senderAddress The wallet owner.
     */
    function getSenderAddress(bytes32 _walletId) external view returns (string memory _senderAddress);

    /**
     * Returns wallet's batch settings.
     * @param _walletId The wallet id.
     * @return _batchSize The batch size.
     * @return _batchDurationSeconds The batch duration in seconds.
     */
    function getBatchSettings(
        bytes32 _walletId
    )
        external view
        returns(
            uint64 _batchSize,
            uint64 _batchDurationSeconds
        );

    /**
     * Returns wallet's minimum fee.
     * @param _walletId The wallet id.
     * @return _minFee The minimum fee.
     */
    function getMinFee(
        bytes32 _walletId
    )
        external view
        returns (
            uint128 _minFee
        );
}