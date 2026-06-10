// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { TeeIdKeyIdPair } from "./ITeeIdKeyIdPair.sol";
import { IPMWMultisigAccountConfigured } from "../fdc2/IPMWMultisigAccountConfigured.sol";

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
        bytes tokenId;
        uint256 amount;
        uint256 maxFee;
        bytes32 paymentReference;
    }

    /**
     * Reissue fee parameters structure.
     * @param maxFeePerPayment The max fee per payment instruction.
     * @param factorsBIPSPerPayment The factor schedule per payment instruction (in BIPS). Part of max fee.
     * @param delaysSeconds The shared time schedule for all payment instructions (in seconds from the start,
      ordered ascending).
     */
    struct ReissueFeeParams {
        uint256[] maxFeePerPayment;
        int16[][] factorsBIPSPerPayment;
        uint16[] delaysSeconds;
    }

    struct PaymentInstructionMessage {
        bytes32 walletId;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        bytes32 sourceId;
        string senderAddress;
        string recipientAddress;
        bytes tokenId;
        uint256 amount;
        uint256 maxFee;
        bytes feeSchedule;
        bytes32 paymentReference;
        uint64 nonce;
        uint64 subNonce;
        uint64 batchEndTs;
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
        uint64 initialNonce,
        address authorizationAddress,
        uint64 batchSize,
        uint64 batchDurationSeconds
    );

    error OnlyWalletOwner();
    error OnlySystemExtensionId();
    error MaxBatchSizeZero();
    error OpTypeZero();
    error KeyTypeZero();
    error OnlyAuthorizationAddress();
    error WrongKeyType();
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
    error AccountAddressZero();
    error UnsupportedSourceId();
    error InvalidProof();
    error PaymentAmountZero();
    error RecipientIsSender();
    error AuthorizationAddressZero();
    error InvalidAttestation();
    error InvalidRequestBody();

    /**
     * Payment instruction method.
     * @param _account The PMW multisig account.
     * @param _paymentInstruction The payment instruction.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     * @return _nonce The batch nonce of the payment instruction.
     * @return _subNonce The sequence number of the payment instruction.
     * Can only be called by the authorization address of the PMW multisig account.
     */
    function pay(
        PMWMultisigAccount calldata _account,
        PaymentInstruction calldata _paymentInstruction,
        address _claimBackAddress
    )
        external payable
        returns (
            uint64 _nonce,
            uint64 _subNonce
        );

    /**
     * Payment reissuance method.
     * @param _account The PMW multisig account.
     * @param _nonce Batch nonce of the payment instructions to be reissued.
     * @param _firstSubNonce SubNonce of the first payment instruction in the batch.
     * @param _paymentInstructions List of the payment instructions.
     * @param _reissueFeeParams The fee parameters for the reissue.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     * Can only be called by the authorization address of the PMW multisig account.
     */
    function reissue(
        PMWMultisigAccount calldata _account,
        uint64 _nonce,
        uint64 _firstSubNonce,
        PaymentInstruction[] calldata _paymentInstructions,
        ReissueFeeParams calldata _reissueFeeParams,
        address _claimBackAddress
    )
        external payable;

    /**
     * Method for adding the PMW multisig account to the wallet.
     * Emits PMWMultisigAccountAdded event.
     * @param _walletId The wallet id.
     * @param _proof The PMW multisig account configured proof.
     * @param _authorizationAddress The address authorized to submit payment instructions for the account.
     * Can only be called by the wallet owner.
     */
    function addPMWMultisigAccount(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof,
        address _authorizationAddress
    )
        external;

    /**
     * Requests a PMW multisig account configured attestation - triggers an FDC2 attestation request.
     * @param _walletId The wallet id.
     * @param _sourceId The source id.
     * @param _accountAddress The account address.
     * @param _testOnTeeId The TEE machine id to test on; if address(0) a random active TEE is used.
     * @param _proofOwner The proof owner address (optional).
     * @param _claimBackAddress An address that can claim back the fee if not executed (optional).
     */
    function requestPMWMultisigAccountConfiguredAttestation(
        bytes32 _walletId,
        bytes32 _sourceId,
        string calldata _accountAddress,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable;

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
     * Returns the operation type.
     * @return _opType The operation type.
     */
    function getOpType()
        external view
        returns (bytes32);

    /**
     * Returns the supported key type.
     * @return _keyType The key type.
     */
    function getKeyType()
        external view
        returns (bytes32);

    /**
     * Returns wallet's accounts.
     * @param _walletId The wallet id.
     * @return _walletAccounts The wallet accounts.
     */
    function getWalletAccounts(
        bytes32 _walletId
    )
        external view
        returns (PMWMultisigAccount[] memory _walletAccounts);

    /**
     * Returns wallet's id.
     * @param _account The PMW multisig account.
     * @return _walletId The wallet id.
     */
    function getWalletId(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (bytes32 _walletId);

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
        returns (
            uint64 _batchSize,
            uint64 _batchDurationSeconds
        );

    /**
     * Returns the authorization address for the given PMW multisig account.
     * @param _account The PMW multisig account.
     * @return _authorizationAddress The authorization address that can submit payment instructions for the account.
     */
    function getAuthorizationAddress(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (address _authorizationAddress);
}
