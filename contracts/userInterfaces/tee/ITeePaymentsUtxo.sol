// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { TeeIdKeyIdPair } from "./ITeeIdKeyIdPair.sol";
import { ITeePaymentsBase } from "./ITeePaymentsBase.sol";
import { IPMWMultisigUtxoConfigured } from "../fdc2/IPMWMultisigUtxoConfigured.sol";

/**
 * TeePayments interface for UTXO/anchor based wallets.
 */
interface ITeePaymentsUtxo is ITeePaymentsBase {

    struct UtxoPaymentInstructionMessage {
        bytes32 walletId;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        bytes32 sourceId;
        string accountAddress;
        uint32 accountIndex;
        uint32 anchorIndex;
        string recipientAddress;
        bytes tokenId;
        uint256 amount;
        uint256 maxFee;
        bytes feeSchedule;
        bytes32 paymentReference;
        uint64 nonce;
        uint64 paymentId;
        uint64 batchPaymentId;
        uint64 batchEndTs;
    }

    struct UtxoAnchorState {
        bytes32 genesisAnchorTxid;
        uint32 genesisAnchorVout;
        uint64 nextNonce;
        uint64 availableAt;
    }

    struct BatchRecord {
        uint64 nonce;
        uint64 batchEndTs;
        uint64 paymentCount;
        uint32 anchorIndex;
        uint24 rewardEpochId;
    }

    event UtxoBatchSettingsSet(
        bytes32 indexed walletId,
        bytes32 sourceId,
        string accountAddress,
        uint64 batchSize,
        uint64 batchDurationSeconds
    );

    event PMWMultisigUtxoAccountAdded(
        bytes32 indexed walletId,
        bytes32 sourceId,
        string accountAddress,
        uint32 accountIndex,
        uint32 anchorCount,
        address authorizationAddress
    );

    event UtxoAnchorsAdded(
        bytes32 indexed walletId,
        bytes32 sourceId,
        string accountAddress,
        uint32 accountIndex,
        uint32 anchorCount
    );

    event UtxoReplacementStarted(
        bytes32 indexed walletId,
        bytes32 indexed accountHash,
        uint64 batchPaymentId,
        uint64 replacementId,
        uint64 firstPaymentId,
        uint256 startBlock
    );

    event UtxoReplacementReady(
        bytes32 indexed walletId,
        bytes32 indexed accountHash,
        uint64 batchPaymentId,
        uint64 replacementId,
        uint64 firstPaymentId,
        uint64 paymentCount,
        uint256[] blocks
    );

    error AnchorIndexOutOfBounds();
    error NoNewAnchors();
    error NoPaymentInstructions();
    error AnchorMismatch();
    error AccountIndexMismatch();
    error AnchorNotReady(uint64 availableAt);
    error MaxBatchSizeZero();
    error BatchNotYetEnded();
    error BatchSizeZero();
    error ReplacementAlreadyFinalized();
    error NoActiveReplacement();
    error ReissueRewardEpochChanged();
    error PaymentNotInBatch();
    error InvalidFeeFactor(uint256 index);
    error ScheduledSignaturesUnsupported();

    /**
     * Registers a new PMW multisig UTXO account for a wallet. Verifies the UTXO-configured attestation
     * proof, then stores the account index and anchors taken from the proof together with the
     * authorization address allowed to submit payments. Initializes the batch size to 1.
     * Emits PMWMultisigUtxoAccountAdded and UtxoBatchSettingsSet.
     *
     * The authorization address is IMMUTABLE for the account's lifetime: there is no rotation
     * entry point and the account can never be re-registered. This is deliberate — the wallet
     * owner key stays an admin key with no spend authority (it can pause the wallet but not move
     * funds), and counterparties can audit the authorization contract once, knowing the owner
     * cannot swap it out. Register a contract with its own key management and rotate behind it
     * (see the sample instructions sender pattern); a bare EOA risks permanently stranding the
     * account's funds if its key is lost.
     * @param _walletId The wallet id the account belongs to.
     * @param _proof The UTXO-configured attestation proof carrying the account index and anchors.
     * @param _authorizationAddress The address authorized to submit payments for this account.
     * Can only be called by the wallet owner.
     */
    function addPMWMultisigAccount(
        bytes32 _walletId,
        IPMWMultisigUtxoConfigured.Proof calldata _proof,
        address _authorizationAddress
    )
        external;

    /**
     * Appends newly attested anchors to an existing PMW multisig UTXO account. Verifies the
     * UTXO-configured proof, requires the account index to match and the already-stored anchors to be
     * unchanged, then appends the additional anchors. Emits UtxoAnchorsAdded.
     * @param _proof The UTXO-configured attestation proof carrying the full anchor set; the existing
     * anchors must match the stored ones and the proof must contain at least one new anchor.
     * Can only be called by the wallet owner.
     */
    function addAnchors(
        IPMWMultisigUtxoConfigured.Proof calldata _proof
    )
        external;

    /**
     * Sets the account's preferred batch size and duration. Both take effect from the next batch that
     * opens; an already-open batch keeps the size snapshotted when it opened. Governance caps these
     * per source via setMaxBatchSettings. Emits UtxoBatchSettingsSet.
     * @param _account The account.
     * @param _batchSize The maximum number of payments in a batch (must be greater than 0).
     * @param _batchDurationSeconds The maximum batch duration in seconds.
     * Can only be called by the wallet owner.
     */
    function setBatchSettings(
        PMWMultisigAccount calldata _account,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        external;

    /**
     * Returns the account's configured batch settings, before the per-source maximum caps are applied.
     * @param _account The account.
     * @return _batchSize The configured maximum number of payments in a batch.
     * @return _batchDurationSeconds The configured maximum batch duration in seconds.
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
     * Returns the per-source maximum batch settings that cap each account's configured values.
     * @param _sourceId The source id.
     * @return _maxBatchSize The maximum number of payments in a batch for the source.
     * @return _maxBatchDurationSeconds The maximum batch duration in seconds for the source.
     */
    function getMaxBatchSettings(
        bytes32 _sourceId
    )
        external view
        returns (
            uint64 _maxBatchSize,
            uint64 _maxBatchDurationSeconds
        );

    /**
     * Returns the per-source delay before an anchor used by a batch can be reused by a later batch.
     * @param _sourceId The source id.
     * @return _anchorReuseDelaySeconds The anchor reuse delay in seconds.
     */
    function getAnchorReuseDelay(
        bytes32 _sourceId
    )
        external view
        returns (uint64 _anchorReuseDelaySeconds);

    /**
     * Returns the stored state of one of an account's anchors by index.
     * @param _account The account.
     * @param _anchorIndex The anchor index (must be less than getAnchorCount).
     * @return _anchor The anchor state (genesis txid/vout, next nonce, and earliest reuse timestamp).
     */
    function getAnchor(
        PMWMultisigAccount calldata _account,
        uint256 _anchorIndex
    )
        external view
        returns (UtxoAnchorState memory _anchor);

    /**
     * Returns the number of anchors registered for an account.
     * @param _account The account.
     * @return _anchorCount The number of anchors.
     */
    function getAnchorCount(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (uint256 _anchorCount);

    /**
     * Returns the record of a batch for an account, as identified by its batch payment id (the payment
     * id of the batch's first payment). For a closed batch this is the stored record; for the
     * currently-open batch the record is synthesized from the live account state, in which case
     * `batchEndTs` is the batch's *planned* end (a closed record instead stamps the actual close time).
     * A zeroed record (`paymentCount == 0`) means the id is unknown — neither a closed batch nor the
     * open one. Any existing batch (open or closed) has `paymentCount >= 1`, so that sentinel is
     * unambiguous. `_open` disambiguates the two non-zeroed cases: when true the record is the live,
     * still-mutating open batch (and `batchEndTs` is its planned end); when false it is a final closed
     * record (and `batchEndTs` is the actual close time).
     * @param _account The account.
     * @param _batchPaymentId The batch payment id (first payment id of the batch).
     * @return _batch The batch record.
     * @return _open True if the record is the currently-open batch, false for a closed or unknown id.
     */
    function getBatchRecord(
        PMWMultisigAccount calldata _account,
        uint64 _batchPaymentId
    )
        external view
        returns (
            BatchRecord memory _batch,
            bool _open
        );

    /**
     * Returns the batch payment id (the first payment id of the batch) that a given payment belongs to.
     * Works for payments in both open and closed batches. Reverts with `InvalidPaymentId` if the payment
     * id was never issued for the account (zero, or not less than the next payment id to be assigned).
     * @param _account The account.
     * @param _paymentId The payment id to resolve.
     * @return _batchPaymentId The batch payment id the payment belongs to.
     */
    function getBatchPaymentId(
        PMWMultisigAccount calldata _account,
        uint64 _paymentId
    )
        external view
        returns (uint64 _batchPaymentId);

}
