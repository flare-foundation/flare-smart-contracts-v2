// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeWalletOpTypeSettings.sol";

/**
 * TeePayments interface.
 */
interface ITeePayments is ITeeWalletOpTypeSettings {

    /// Payment instruction structure
    struct PaymentInstruction {
        string recipientAddress;
        uint256 amount;
        bytes32 paymentReference;
    }

    struct PaymentInstructionMessage {
        bytes32 walletId;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        string senderAddress;
        string recipientAddress;
        uint256 amount;
        bytes32 paymentReference;
        uint64 nonce;
        uint64 subNonce;
        uint256 maxFee;
        uint32 maxFeeTolerancePPM;
        uint64 batchEndTs;
    }

    struct SetPaymentLimits {
        bytes32 walletId;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        uint256 transactionLimit;
        uint256 dailyLimit;
    }

    event BatchSettingsSet(
        bytes32 indexed walletId,
        uint64 batchSize,
        uint64 batchDurationSeconds
    );

    event FeesSet(
        bytes32 indexed walletId,
        uint96 maxFee,
        uint32 maxFeeTolerancePPM,
        uint96 maxControlFee
    );

    event ControlAddressSet(
        bytes32 indexed walletId,
        address controlAddress
    );

    event SenderAddressSet(
        bytes32 indexed walletId,
        string senderAddress,
        uint64 initialNonce
    );

    /**
     * Payment instruction method.
     * Can only be called by the submit address.
     * @param _projectId The project id.
     * @param _walletId The wallet id.
     * @param _paymentInstruction The payment instruction.
     * @return _nonce The batch nonce of the payment instruction.
     * @return _subNonce The sequence number of the payment instruction.
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
     * Can only be called by the control address.
     * @param _walletId The wallet id.
     * @param _nonce Batch nonce of the payment instructions to be reissued.
     * @param _firstSubNonce SubNonce of the first payment instruction in the batch.
     * @param _paymentInstructions List of the payment instructions.
     * @param _fee The new (usually bumped) fee.
     * @param _nullify List of nullification flags for the payment instructions.
     */
    function reissue(
        bytes32 _walletId,
        uint64 _nonce,
        uint64 _firstSubNonce,
        PaymentInstruction[] calldata _paymentInstructions,
        uint96 _fee,
        bool[] calldata _nullify
    )
        external payable;

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
     * Method for setting the sender address.
     * Can only be called by the wallet owner.
     * @param _walletId The wallet id.
     * @param _senderAddress The new sender address.
     * @param _initialNonce The initial nonce.
     */
    function setSenderAddressAndInitialNonce(
        bytes32 _walletId,
        string calldata _senderAddress,
        uint64 _initialNonce
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

    /**
     * Set payment limits instruction method.
     * Can only be called by the wallet owner address.
     * @param _walletId The wallet id.
     * @param _transactionLimit The transaction limit.
     * @param _dailyLimit The daily limit.
     */
    function setPaymentLimits(
        bytes32 _walletId,
        uint256 _transactionLimit,
        uint256 _dailyLimit
    )
        external payable;

    /**
     * Returns wallet's sender address.
     * @param _walletId The wallet id.
     * @return _senderAddress The wallet owner.
     */
    function getSenderAddress(bytes32 _walletId) external view returns (string memory _senderAddress);

    /**
     * Returns wallet's settings.
     * @param _walletId The wallet id.
     * @return _batchSize The batch size.
     * @return _batchDurationSeconds The batch duration in seconds.
     * @return _maxFee The maximum fee.
     * @return _maxFeeTolerancePPM The maximum fee tolerance, in parts per million.
     * @return _controlAddress The control address.
     * @return _maxControlFee The maximum control fee.
     */
    function getWalletSettings(
        bytes32 _walletId
    )
        external view
        returns(
            uint64 _batchSize,
            uint64 _batchDurationSeconds,
            uint96 _maxFee,
            uint32 _maxFeeTolerancePPM,
            address _controlAddress,
            uint96 _maxControlFee
        );
}