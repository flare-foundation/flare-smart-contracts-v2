// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { TeeIdKeyIdPair } from "./ITeeIdKeyIdPair.sol";
import { IPMWMultisigAccountConfigured } from "../ftdc/IPMWMultisigAccountConfigured.sol";

/**
 * TeePayments interface.
 */
interface ITeePayments {

    struct PMWMultisigAccount {
        bytes32 sourceId;
        string accountAddress;
    }

    /// Payment instruction structure
    struct PaymentInstruction {
        string recipientAddress;
        bytes32 tokenId;
        uint256 amount;
        uint256 fee;
        bytes32 paymentReference;
    }

    struct PaymentInstructionMessage {
        bytes32 walletId;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        bytes32 sourceId;
        string senderAddress;
        string recipientAddress;
        bytes32 tokenId;
        uint256 amount;
        uint256 fee;
        bytes32 paymentReference;
        uint64 nonce;
        uint64 subNonce;
        uint64 batchEndTs;
    }

    struct SetPaymentLimits {
        bytes32 walletId;
        bytes32 sourceId;
        string accountAddress;
        uint256 nonce;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        uint256 transactionLimit;
        uint256 dailyLimit;
    }

    event BatchSettingsSet(
        bytes32 indexed walletId,
        bytes32 sourceId,
        string accountAddress,
        uint64 batchSize,
        uint64 batchDurationSeconds
    );

    event PMWMultisigAccountAdded(
        bytes32 indexed walletId,
        bytes32 sourceId,
        string accountAddress,
        uint64 initialNonce
    );

    event SupportedSourceIdAdded(
        bytes32 indexed opType,
        bytes32 indexed sourceId
    );

    error OnlyWalletOwner();
    error OnlySystemExtensionId();
    error MaxBatchSizeZero();
    error OpTypeZero();
    error SupportedSourceIdsLengthZero();
    error SourceIdZero(uint256 index);
    error SourceIdAlreadyExists(bytes32 sourceId);
    error OnlySubmitAddress();
    error WrongOpType();
    error WalletNotInProduction();
    error NoPaymentInstructions();
    error LengthsMismatch();
    error BatchNotYetEnded();
    error BatchHashMismatch();
    error BatchSizeZero();
    error BatchSizeTooLarge();
    error BatchDurationTooLarge();
    error PMWMultisigAccountAddressAlreadySet();
    error OnlyProductionOrPausedStatus();
    error MinFeeNotSet();
    error DailyLimitBelowTransactionLimit();
    error AccountAddressZero();
    error UnsupportedSourceId();
    error InvalidProof();

    /**
     * Payment instruction method.
     * @param _account The PMW multisig account.
     * @param _paymentInstruction The payment instruction.
     * @return _nonce The batch nonce of the payment instruction.
     * @return _subNonce The sequence number of the payment instruction.
     * Can only be called by the submit address of the project.
     */
    function pay(
        PMWMultisigAccount calldata _account,
        PaymentInstruction calldata _paymentInstruction
    )
        external payable
        returns (uint64 _nonce, uint64 _subNonce);

    /**
     * Payment reissuance method.
     * @param _account The PMW multisig account.
     * @param _nonce Batch nonce of the payment instructions to be reissued.
     * @param _firstSubNonce SubNonce of the first payment instruction in the batch.
     * @param _paymentInstructions List of the payment instructions.
     * @param _fees List of fees for the payment instructions.
     * @param _nullify List of nullification flags for the payment instructions.
     * Can only be called by the submit address of the project.
     */
    function reissue(
        PMWMultisigAccount calldata _account,
        uint64 _nonce,
        uint64 _firstSubNonce,
        PaymentInstruction[] calldata _paymentInstructions,
        uint256[] calldata _fees,
        bool[] calldata _nullify
    )
        external payable;

    /**
     * Method for adding the PMW multisig account to the wallet.
     * Emits PMWMultisigAccountAdded event.
     * @param _walletId The wallet id.
     * @param _proof The PMW multisig account configured proof.
     * Can only be called by the wallet owner.
     */
    function addPMWMultisigAccount(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external;

    /**
    * Method for setting the batch settings.
    * Emits BatchSettingsSet event.
    * @param _account The PMW multisig account.
    * @param _batchSize The batch size.
    * @param _batchDurationSeconds The batch duration in seconds.
    * Can only be called by the wallet owner.
    */
    function setBatchSettings(
        PMWMultisigAccount calldata _account,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        external;

    /**
     * Set payment limits instruction method.
     * @param _account The PMW multisig account.
     * @param _transactionLimit The transaction limit.
     * @param _dailyLimit The daily limit.
     * Can only be called by the wallet owner address.
     */
    function setPaymentLimits(
        PMWMultisigAccount calldata _account,
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
     * Returns wallet's accounts.
     * @param _walletId The wallet id.
     * @return _walletAccounts The wallet accounts.
     */
    function getWalletAccounts(bytes32 _walletId) external view returns (PMWMultisigAccount[] memory _walletAccounts);

    /**
     * Returns wallet's id.
     * @param _account The PMW multisig account.
     * @return _walletId The wallet id.
     */
    function getWalletId(PMWMultisigAccount calldata _account) external view returns (bytes32 _walletId);

    /**
     * Returns wallet's batch settings.
     * @param _account The PMW multisig account.
     * @return _batchSize The batch size.
     * @return _batchDurationSeconds The batch duration in seconds.
     */
    function getBatchSettings(
        PMWMultisigAccount calldata _account
    )
        external view
        returns(
            uint64 _batchSize,
            uint64 _batchDurationSeconds
        );

    /**
     * Returns the supported source ids.
     * @return _supportedSourceIds The supported source ids.
     */
    function getSupportedSourceIds() external view returns (bytes32[] memory _supportedSourceIds);

    /**
     * Returns whether the given source id is supported.
     * @param _sourceId The source id to check.
     * @return True if the source id is supported, false otherwise.
     */
    function isSourceIdSupported(bytes32 _sourceId) external view returns (bool);
}