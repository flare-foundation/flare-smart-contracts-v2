// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { TeePaymentsBase } from "./TeePaymentsBase.sol";
import { IITeePaymentsUtxo } from "../interface/IITeePaymentsUtxo.sol";
import { ITeePaymentsBase, PAY, REISSUE } from "../../userInterfaces/tee/ITeePaymentsBase.sol";
import { ITeePaymentsModel, PaymentModel } from "../../userInterfaces/tee/ITeePaymentsModel.sol";
import { ITeePaymentsUtxo } from "../../userInterfaces/tee/ITeePaymentsUtxo.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { DEFAULT_FEE_SCHEDULE } from "../../userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";
import { IPMWMultisigUtxoConfigured } from "../../userInterfaces/fdc2/IPMWMultisigUtxoConfigured.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";

/**
 * TeePaymentsUtxo is a contract used for instructing TEE based UTXO wallet payments.
 */
contract TeePaymentsUtxo is TeePaymentsBase, IITeePaymentsUtxo {

    struct AccountState {
        uint64 nextPaymentId;
        uint64 batchSize;
        uint64 batchDurationSeconds;
        uint64 batchPaymentId;
        uint64 batchEndTs;
        uint64 batchPaymentCount;
        // Effective batch size snapshotted when the batch was opened; settings changes mid-batch only
        // take effect for the next batch, which keeps the full/close checks free of recomputation.
        uint64 batchSizeEffective;
        uint64 batchNonce;
        uint32 batchAnchorIndex;
        uint24 batchRewardEpochId;
        uint32 nextAnchorIndex;
        uint32 anchorCount;
        uint32 accountIndex;
        bool batchOpen;
    }

    struct MaxBatchSettings {
        uint64 maxBatchSize;
        uint64 maxBatchDurationSeconds;
    }

    struct ReplacementAttempt {
        uint64 id;
        uint64 nextPaymentId;
        uint64 emittedCount;
        uint24 rewardEpochId;
        bool finalized;
        // Exact block numbers in which this replacement emitted reissue instructions (deduped, ascending),
        // so the off-chain watcher scans only those blocks.
        uint256[] blocks;
    }

    struct ReissueSendContext {
        bytes32 accountHash;
        bytes32 walletId;
        bytes32 opType;
        bytes32 instructionId;
        address[] cosigners;
        uint64 cosignersThreshold;
        uint64 batchPaymentId;
        uint64 firstPaymentId;
        uint256 instructionsFee;
        bytes[] encodedSchedules;
        uint32 accountIndex;
        uint32 anchorIndex;
        uint64 nonce;
        uint64 batchEndTs;
    }

    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    mapping(bytes32 accountHash => AccountState) private states;
    mapping(bytes32 accountHash => UtxoAnchorState[]) private anchors;
    mapping(bytes32 accountHash => mapping(uint256 batchPaymentId => BatchRecord)) private batchRecords;
    mapping(bytes32 accountHash => mapping(uint256 batchPaymentId => uint64)) private replacementCounters;
    // Sparse paymentId -> batchPaymentId index. Only written for payments that are NOT the first of
    // their batch; for a batch's first payment paymentId == batchPaymentId, which the getter derives
    // without a stored slot. A zero entry therefore means "first payment of its batch".
    mapping(bytes32 accountHash => mapping(uint256 paymentId => uint64)) private batchPaymentIdByPayment;
    mapping(bytes32 accountHash => mapping(uint256 batchPaymentId => ReplacementAttempt)) private activeReplacements;
    mapping(bytes32 sourceId => uint64 anchorReuseDelaySeconds) private anchorReuseDelaySeconds;
    mapping(bytes32 sourceId => MaxBatchSettings) private maxBatchSettings;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeePaymentsBase() {}

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function pay(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        ITeePaymentsBase.PaymentInstruction calldata _paymentInstruction,
        address _claimBackAddress
    )
        external payable
        returns (uint64 _paymentId)
    {
        require(_paymentInstruction.amount > 0, ITeePaymentsBase.PaymentAmountZero());

        bytes32 accountHash = _toAccountHash(_account);
        bytes32 walletId = accountHashToWalletId[accountHash];
        _checkAuthorizationAddress(accountHash);
        _requireValidRecipientAddress(_account.sourceId, _paymentInstruction.recipientAddress);
        _checkWalletStatus(walletId);

        AccountState storage state = states[accountHash];
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        _closeOpenBatchIfDue(accountHash, _account.sourceId, state, currentRewardEpochId);
        if (!state.batchOpen) {
            _openBatch(accountHash, _account.sourceId, state, currentRewardEpochId);
        }

        _paymentId = state.nextPaymentId++;
        paymentHashes[accountHash][_paymentId] = _getPaymentHash(_paymentInstruction, _paymentId);
        state.batchPaymentCount++;
        // Index this payment to its batch, skipping the batch's first payment (paymentId ==
        // batchPaymentId, derived by the getter) so single-payment batches cost no extra SSTORE.
        if (_paymentId != state.batchPaymentId) {
            batchPaymentIdByPayment[accountHash][_paymentId] = state.batchPaymentId;
        }
        // The batch was rolled/opened at the start of this call, so the only new reason it can need
        // closing now is that this payment filled it (block.timestamp and reward epoch are fixed within
        // the call). Capture it once and reuse for both the emitted close timestamp and the final close.
        bool batchFull = _isBatchFull(state);

        // If this payment fills the batch it is closed below, at the current block. Emit that actual
        // close timestamp (now) instead of the planned end, so off-chain consumers detect the full
        // close immediately via the standard "batchEndTs has passed" rule — no batch-size tracking.
        uint64 batchEndTs = batchFull ? uint64(block.timestamp) : state.batchEndTs;
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = flareTeeManager.receivingTeesAndKeys(walletId);
        UtxoPaymentInstructionMessage memory message = _buildMessage(
            _account,
            walletId,
            state.accountIndex,
            state.batchAnchorIndex,
            state.batchNonce,
            _paymentId,
            state.batchPaymentId,
            batchEndTs,
            _paymentInstruction,
            teeIdKeyIdPairs
        );
        message.maxFee = _paymentInstruction.maxFee;
        message.feeSchedule = DEFAULT_FEE_SCHEDULE;

        (address[] memory cosigners, uint64 cosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(walletId);
        bytes32 sourceOpType = _sourceOpType(_account.sourceId);
        // `batchPaymentId` (the batch's first paymentId, monotonic per account) is the batch identity
        // in the id preimage; it is shared by every payment in the batch. PAY uses reissue number 0.
        bytes32 instructionId = _computeInstructionId(
            sourceOpType, PAY, _account.sourceId, _account.accountAddress, state.batchPaymentId, 0
        );
        // Checks-effects-interactions: close the batch (state write) before the external instruction send.
        // The message and instructionId are already built above, so closing here does not affect them.
        if (batchFull) {
            _closeBatch(accountHash, _account.sourceId, state, uint64(block.timestamp));
        }

        _sendPaymentInstructions(
            sourceOpType,
            instructionId,
            _toTeeIds(teeIdKeyIdPairs),
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            _claimBackAddress,
            msg.value
        );
    }

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function reissue(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        uint64 _batchPaymentId,
        ITeePaymentsBase.PaymentInstruction[] calldata _paymentInstructions,
        ITeePaymentsBase.ReissueFeeParams calldata _reissueFeeParams,
        address _claimBackAddress
    )
        external payable
        returns (bool _finalized)
    {
        require(_paymentInstructions.length > 0, ITeePaymentsUtxo.NoPaymentInstructions());
        bytes[] memory encodedSchedules =
            _validateAndEncodeReissueSchedules(_paymentInstructions.length, _reissueFeeParams);

        bytes32 accountHash = _toAccountHash(_account);
        bytes32 walletId = accountHashToWalletId[accountHash];
        _checkAuthorizationAddress(accountHash);
        _checkWalletStatus(walletId);

        AccountState storage state = states[accountHash];
        BatchRecord memory batch =
            _batchRecordForReissue(accountHash, _account.sourceId, state, _batchPaymentId);
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        ReplacementAttempt storage replacement =
            _replacementAttempt(accountHash, walletId, _batchPaymentId, _paymentInstructions[0], currentRewardEpochId);
        uint64 firstPaymentId = replacement.nextPaymentId;
        _checkPaymentRange(_batchPaymentId, firstPaymentId, _paymentInstructions.length, batch.paymentCount);

        // update the replacement record
        replacement.nextPaymentId = _addToUint64(firstPaymentId, _paymentInstructions.length);
        replacement.emittedCount = _addToUint64(replacement.emittedCount, _paymentInstructions.length);
        _recordReissueBlock(replacement);

        bytes32 sourceOpType = _sourceOpType(_account.sourceId);

        ReissueSendContext memory context;
        context.accountHash = accountHash;
        context.walletId = walletId;
        context.opType = sourceOpType;
        // Same `batchPaymentId` identity as the original batch's PAY id, with the replacement
        // attempt id (reissueNumber, starting at 1) appended so two replacements of the same batch
        // that both restart from the beginning derive distinct instruction ids.
        context.instructionId = _computeInstructionId(
            sourceOpType, REISSUE, _account.sourceId, _account.accountAddress, _batchPaymentId, replacement.id
        );
        (context.cosigners, context.cosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(walletId);
        context.batchPaymentId = _batchPaymentId;
        context.firstPaymentId = firstPaymentId;
        context.instructionsFee = msg.value;
        context.encodedSchedules = encodedSchedules;
        context.accountIndex = state.accountIndex;
        context.anchorIndex = batch.anchorIndex;
        context.nonce = batch.nonce;
        context.batchEndTs = batch.batchEndTs;
        _sendReissueMessages(
            _account,
            _paymentInstructions,
            _reissueFeeParams,
            _claimBackAddress,
            context
        );
        _finalized = replacement.emittedCount == batch.paymentCount;
        if (_finalized) {
            _finalizeReplacement(walletId, accountHash, _batchPaymentId, replacement);
        }
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function addPMWMultisigAccount(
        bytes32 _walletId,
        IPMWMultisigUtxoConfigured.Proof calldata _proof,
        address _authorizationAddress
    )
        external
    {
        // Validates the proof (reverts if invalid); the verified fields are then read straight from
        // the calldata proof — the same bytes the verifier just validated.
        teePaymentsConfigVerifier.verifyUtxoConfiguredProof(_walletId, _proof);
        bytes32 sourceId = _proof.header.sourceId;
        uint32 accountIndex = _proof.requestBody.accountIndex;
        uint32 anchorCount = uint32(_proof.requestBody.anchors.length); // < MAX_ANCHOR_COUNT

        bytes32 accountHash = _registerAccount(
            _walletId,
            sourceId,
            _proof.responseBody.accountAddress,
            _authorizationAddress
        );
        AccountState storage state = states[accountHash];
        state.nextPaymentId = 1;
        state.batchSize = 1;
        state.accountIndex = accountIndex;
        state.anchorCount = anchorCount;

        _appendAnchors(accountHash, _proof.requestBody.anchors, 0);

        emit PMWMultisigUtxoAccountAdded(
            _walletId,
            sourceId,
            _proof.responseBody.accountAddress,
            accountIndex,
            anchorCount,
            _authorizationAddress
        );
        emit UtxoBatchSettingsSet(_walletId, sourceId, _proof.responseBody.accountAddress, 1, 0);
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function addAnchors(
        IPMWMultisigUtxoConfigured.Proof calldata _proof
    )
        external
    {
        // The account identity is taken straight from the (verifier-validated) proof; no separate
        // account argument is needed. The owner check below gates the caller to this account's wallet.
        bytes32 accountHash = _toAccountHash(_proof.header.sourceId, _proof.responseBody.accountAddress);
        bytes32 walletId = accountHashToWalletId[accountHash];
        _checkWalletOwner(walletId);
        AccountState storage state = states[accountHash];

        teePaymentsConfigVerifier.verifyUtxoConfiguredProof(walletId, _proof);
        require(_proof.requestBody.accountIndex == state.accountIndex, AccountIndexMismatch());

        uint32 newAnchorCount = uint32(_proof.requestBody.anchors.length); // < MAX_ANCHOR_COUNT
        uint32 currentAnchorCount = state.anchorCount;
        require(newAnchorCount > currentAnchorCount, NoNewAnchors());
        _checkStoredAnchorsMatch(accountHash, _proof, currentAnchorCount);

        _appendAnchors(
            accountHash,
            _proof.requestBody.anchors,
            currentAnchorCount
        );

        state.anchorCount = newAnchorCount;
        emit UtxoAnchorsAdded(
            walletId,
            _proof.header.sourceId,
            _proof.responseBody.accountAddress,
            state.accountIndex,
            newAnchorCount
        );
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function setBatchSettings(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        external
        onlyWalletOwner(_account)
    {
        require(_batchSize > 0, BatchSizeZero());
        bytes32 accountHash = _toAccountHash(_account);
        AccountState storage state = states[accountHash];
        state.batchSize = _batchSize;
        state.batchDurationSeconds = _batchDurationSeconds;
        emit UtxoBatchSettingsSet(
            accountHashToWalletId[accountHash],
            _account.sourceId,
            _account.accountAddress,
            _batchSize,
            _batchDurationSeconds
        );
    }

    /**
     * @inheritdoc IITeePaymentsUtxo
     */
    function setAnchorReuseDelay(
        bytes32 _sourceId,
        uint64 _anchorReuseDelaySeconds
    )
        external
        onlyGovernance
    {
        _checkSource(_sourceId);
        anchorReuseDelaySeconds[_sourceId] = _anchorReuseDelaySeconds;
        emit AnchorReuseDelaySet(_sourceId, _anchorReuseDelaySeconds);
    }

    /**
     * @inheritdoc IITeePaymentsUtxo
     */
    function setMaxBatchSettings(
        bytes32 _sourceId,
        uint64 _maxBatchSize,
        uint64 _maxBatchDurationSeconds
    )
        external
        onlyGovernance
    {
        require(_maxBatchSize > 0, MaxBatchSizeZero());
        _checkSource(_sourceId);
        maxBatchSettings[_sourceId] = MaxBatchSettings(_maxBatchSize, _maxBatchDurationSeconds);
        emit MaxBatchSettingsSet(_sourceId, _maxBatchSize, _maxBatchDurationSeconds);
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function getBatchSettings(
        ITeePaymentsBase.PMWMultisigAccount calldata _account
    )
        external view
        returns (
            uint64 _batchSize,
            uint64 _batchDurationSeconds
        )
    {
        AccountState storage state = states[_toAccountHash(_account)];
        _batchSize = state.batchSize;
        _batchDurationSeconds = state.batchDurationSeconds;
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function getMaxBatchSettings(
        bytes32 _sourceId
    )
        external view
        returns (
            uint64 _maxBatchSize,
            uint64 _maxBatchDurationSeconds
        )
    {
        MaxBatchSettings storage settings = maxBatchSettings[_sourceId];
        _maxBatchSize = settings.maxBatchSize;
        _maxBatchDurationSeconds = settings.maxBatchDurationSeconds;
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function getAnchorReuseDelay(
        bytes32 _sourceId
    )
        external view
        returns (uint64)
    {
        return anchorReuseDelaySeconds[_sourceId];
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function getAnchor(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        uint256 _anchorIndex
    )
        external view
        returns (UtxoAnchorState memory _anchor)
    {
        UtxoAnchorState[] storage accountAnchors = anchors[_toAccountHash(_account)];
        require(_anchorIndex < accountAnchors.length, AnchorIndexOutOfBounds());
        _anchor = accountAnchors[_anchorIndex];
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function getAnchorCount(
        ITeePaymentsBase.PMWMultisigAccount calldata _account
    )
        external view
        returns (uint256)
    {
        return anchors[_toAccountHash(_account)].length;
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function getBatchRecord(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        uint64 _batchPaymentId
    )
        external view
        returns (
            BatchRecord memory _batch,
            bool _open
        )
    {
        bytes32 accountHash = _toAccountHash(_account);
        _batch = batchRecords[accountHash][_batchPaymentId];
        if (_batch.paymentCount == 0) {
            // No closed record: if this is the currently-open batch, synthesize the record from the
            // live account state and flag it open. Here batchEndTs is the batch's *planned* end; a
            // closed record instead stamps the actual close time (the current block when a batch closes
            // on fullness). Unknown ids fall through as a zeroed record with _open false.
            AccountState storage state = states[accountHash];
            if (state.batchOpen && state.batchPaymentId == _batchPaymentId) {
                _batch = BatchRecord({
                    nonce: state.batchNonce,
                    batchEndTs: state.batchEndTs,
                    paymentCount: state.batchPaymentCount,
                    anchorIndex: state.batchAnchorIndex,
                    rewardEpochId: state.batchRewardEpochId
                });
                _open = true;
            }
        }
    }

    /**
     * @inheritdoc ITeePaymentsUtxo
     */
    function getBatchPaymentId(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        uint64 _paymentId
    )
        external view
        returns (uint64 _batchPaymentId)
    {
        bytes32 accountHash = _toAccountHash(_account);
        require(_paymentId > 0 && _paymentId < _getNextPaymentId(accountHash), InvalidPaymentId());
        _batchPaymentId = batchPaymentIdByPayment[accountHash][_paymentId];
        // Zero sentinel: this payment is the first of its batch, where batchPaymentId == paymentId.
        if (_batchPaymentId == 0) {
            _batchPaymentId = _paymentId;
        }
    }

    /**
     * @inheritdoc ITeePaymentsModel
     */
    function paymentModel()
        external pure
        returns (PaymentModel)
    {
        return PaymentModel.UTXO;
    }

    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        super._updateContractAddresses(_contractNameHashes, _contractAddresses);
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    function _sendReissueMessages(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        ITeePaymentsBase.PaymentInstruction[] calldata _paymentInstructions,
        ITeePaymentsBase.ReissueFeeParams calldata _reissueFeeParams,
        address _claimBackAddress,
        ReissueSendContext memory _context
    )
        internal
    {
        // All reissue payments in this call target the same wallet, so the receiving TEEs are constant:
        // fetch them once and reuse for every instruction instead of per payment.
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = flareTeeManager.receivingTeesAndKeys(_context.walletId);
        address[] memory teeIds = _toTeeIds(teeIdKeyIdPairs);
        uint256 remainingAmount = _context.instructionsFee;
        for (uint256 i = 0; i < _paymentInstructions.length; i++) {
            uint64 paymentId = _addToUint64(_context.firstPaymentId, i);
            require(
                paymentHashes[_context.accountHash][paymentId] == _getPaymentHash(_paymentInstructions[i], paymentId),
                PaymentHashMismatch()
            );

            UtxoPaymentInstructionMessage memory message = _buildMessage(
                _account,
                _context.walletId,
                _context.accountIndex,
                _context.anchorIndex,
                _context.nonce,
                paymentId,
                _context.batchPaymentId,
                _context.batchEndTs,
                _paymentInstructions[i],
                teeIdKeyIdPairs
            );
            message.maxFee = _reissueFeeParams.maxFeePerPayment[i];
            message.feeSchedule =
                _context.encodedSchedules.length > 0 ? _context.encodedSchedules[i] : DEFAULT_FEE_SCHEDULE;

            uint256 amount = remainingAmount / (_paymentInstructions.length - i);
            remainingAmount -= amount;
            _sendPaymentInstructions(
                _context.opType,
                _context.instructionId,
                teeIds,
                REISSUE,
                abi.encode(message),
                _context.cosigners,
                _context.cosignersThreshold,
                _claimBackAddress,
                amount
            );
        }
    }

    function _replacementAttempt(
        bytes32 _accountHash,
        bytes32 _walletId,
        uint64 _batchPaymentId,
        ITeePaymentsBase.PaymentInstruction calldata _firstPaymentInstruction,
        uint24 _currentRewardEpochId
    )
        internal
        returns (ReplacementAttempt storage _replacement)
    {
        _replacement = activeReplacements[_accountHash][_batchPaymentId];
        if (_paymentInstructionMatches(_accountHash, _batchPaymentId, _firstPaymentInstruction)) {
            uint64 replacementId = ++replacementCounters[_accountHash][_batchPaymentId];
            _replacement.id = replacementId;
            _replacement.nextPaymentId = _batchPaymentId;
            _replacement.emittedCount = 0;
            _replacement.rewardEpochId = _currentRewardEpochId;
            _replacement.finalized = false;
            delete _replacement.blocks;
            emit UtxoReplacementStarted(
                _walletId,
                _accountHash,
                _batchPaymentId,
                replacementId,
                _batchPaymentId,
                block.number
            );
            return _replacement;
        }
        require(_replacement.id != 0 && !_replacement.finalized, NoActiveReplacement());
        require(_replacement.rewardEpochId == _currentRewardEpochId, ReissueRewardEpochChanged());
        // The first instruction's hash is validated against `nextPaymentId` by the send loop (i == 0,
        // which reverts PaymentHashMismatch on a mismatch before any instruction is sent), so it is not
        // re-checked here.
    }

    function _finalizeReplacement(
        bytes32 _walletId,
        bytes32 _accountHash,
        uint64 _batchPaymentId,
        ReplacementAttempt storage _replacement
    )
        internal
    {
        require(!_replacement.finalized, ReplacementAlreadyFinalized());
        require(_replacement.emittedCount > 0, NoActiveReplacement());
        _replacement.finalized = true;
        emit UtxoReplacementReady(
            _walletId,
            _accountHash,
            _batchPaymentId,
            _replacement.id,
            _batchPaymentId,
            _replacement.emittedCount,
            _replacement.blocks
        );
    }

    /**
     * Appends the current block to the replacement's reissue-block list, skipping consecutive
     * duplicates so multiple reissue calls within the same block record a single entry.
     */
    function _recordReissueBlock(
        ReplacementAttempt storage _replacement
    )
        internal
    {
        uint256 length = _replacement.blocks.length;
        if (length == 0 || _replacement.blocks[length - 1] != block.number) {
            _replacement.blocks.push(block.number);
        }
    }

    function _openBatch(
        bytes32 _accountHash,
        bytes32 _sourceId,
        AccountState storage _state,
        uint24 _currentRewardEpochId
    )
        internal
    {
        (uint64 effectiveBatchSize, uint64 effectiveBatchDurationSeconds) =
            _effectiveBatchSettings(_sourceId, _state.batchSize, _state.batchDurationSeconds);
        // Cyclic round-robin anchor selection: scan from the per-account cursor and take the first
        // anchor whose reuse window has cleared, so a busy cursor anchor moves on to the next free
        // chain (including any newly added ones) instead of blocking. Revert only if all are busy,
        // reporting the earliest free timestamp.
        UtxoAnchorState[] storage accountAnchors = anchors[_accountHash];
        uint32 count = _state.anchorCount;
        uint32 start = _state.nextAnchorIndex;
        uint32 anchorIndex = start;
        bool found = false;
        uint64 earliestAvailableAt = type(uint64).max;
        for (uint32 i = 0; i < count; i++) {
            uint32 candidate = uint32((uint256(start) + i) % count);
            uint64 candidateAvailableAt = accountAnchors[candidate].availableAt;
            if (candidateAvailableAt <= block.timestamp) {
                anchorIndex = candidate;
                found = true;
                break;
            }
            if (candidateAvailableAt < earliestAvailableAt) {
                earliestAvailableAt = candidateAvailableAt;
            }
        }
        require(found, AnchorNotReady(earliestAvailableAt));
        UtxoAnchorState storage anchor = accountAnchors[anchorIndex];
        _state.batchPaymentId = _state.nextPaymentId;
        _state.batchEndTs = uint64(block.timestamp) + effectiveBatchDurationSeconds;
        _state.batchPaymentCount = 0;
        _state.batchSizeEffective = effectiveBatchSize;
        _state.batchNonce = anchor.nextNonce++;
        _state.batchAnchorIndex = anchorIndex;
        _state.batchRewardEpochId = _currentRewardEpochId;
        _state.batchOpen = true;
        _state.nextAnchorIndex = uint32((uint256(anchorIndex) + 1) % count);
        anchor.availableAt = _state.batchEndTs + anchorReuseDelaySeconds[_sourceId];
    }

    /**
     * Closes the currently-open batch if it is due to close — i.e. it has ended (passed its end
     * timestamp) or its reward epoch changed. Closing on "ended" stamps the batch end timestamp;
     * otherwise the current block timestamp is used. Fullness is not checked here: a batch that fills
     * is closed synchronously in the same pay call (see `pay`), so an open batch is never full.
     * No-op if no batch is open or none of the conditions hold. Shared by the pay path (open/rotate
     * batches) and the reissue path (decide whether a batch can be replaced). Returns whether a batch
     * was closed.
     */
    function _closeOpenBatchIfDue(
        bytes32 _accountHash,
        bytes32 _sourceId,
        AccountState storage _state,
        uint24 _currentRewardEpochId
    )
        internal
        returns (bool _closed)
    {
        if (!_state.batchOpen) {
            return false;
        }
        bool batchEnded = block.timestamp > _state.batchEndTs;
        if (batchEnded || _state.batchRewardEpochId != _currentRewardEpochId) {
            _closeBatch(_accountHash, _sourceId, _state, batchEnded ? _state.batchEndTs : uint64(block.timestamp));
            return true;
        }
        return false;
    }

    function _batchRecordForReissue(
        bytes32 _accountHash,
        bytes32 _sourceId,
        AccountState storage _state,
        uint64 _batchPaymentId
    )
        internal
        returns (BatchRecord memory _batch)
    {
        _batch = batchRecords[_accountHash][_batchPaymentId];
        if (_batch.paymentCount == 0 && _state.batchOpen && _state.batchPaymentId == _batchPaymentId) {
            require(
                _closeOpenBatchIfDue(_accountHash, _sourceId, _state, flareSystemsManager.getCurrentRewardEpochId()),
                BatchNotYetEnded()
            );
            _batch = batchRecords[_accountHash][_batchPaymentId];
        }
        require(_batch.paymentCount > 0, BatchNotYetEnded());
    }

    function _closeBatch(
        bytes32 _accountHash,
        bytes32 _sourceId,
        AccountState storage _state,
        uint64 _closedAt
    )
        internal
    {
        batchRecords[_accountHash][_state.batchPaymentId] = BatchRecord({
            nonce: _state.batchNonce,
            batchEndTs: _closedAt,
            paymentCount: _state.batchPaymentCount,
            anchorIndex: _state.batchAnchorIndex,
            rewardEpochId: _state.batchRewardEpochId
        });
        // Closing can only bring the anchor's reuse window earlier than the window already reserved
        // at open time, never push it later (e.g. an early close, or a reuse delay lowered after open).
        UtxoAnchorState storage closedAnchor = anchors[_accountHash][_state.batchAnchorIndex];
        uint64 closeAvailableAt = _closedAt + anchorReuseDelaySeconds[_sourceId];
        if (closeAvailableAt < closedAnchor.availableAt) {
            closedAnchor.availableAt = closeAvailableAt;
        }
        _state.batchEndTs = _closedAt;
        _state.batchOpen = false;
    }

    function _appendAnchors(
        bytes32 _accountHash,
        IPMWMultisigUtxoConfigured.Anchor[] calldata _anchors,
        uint256 _fromIndex
    )
        internal
    {
        for (uint256 i = _fromIndex; i < _anchors.length; i++) {
            IPMWMultisigUtxoConfigured.Anchor calldata anchor = _anchors[i];
            anchors[_accountHash].push(UtxoAnchorState({
                genesisAnchorTxid: anchor.genesisAnchorTxid,
                genesisAnchorVout: anchor.genesisAnchorVout,
                nextNonce: 1,
                availableAt: 0
            }));
        }
    }

    /**
     * @inheritdoc TeePaymentsBase
     */
    function _getNextPaymentId(
        bytes32 _accountHash
    )
        internal view override
        returns (uint64)
    {
        return states[_accountHash].nextPaymentId;
    }

    function _paymentInstructionMatches(
        bytes32 _accountHash,
        uint64 _paymentId,
        ITeePaymentsBase.PaymentInstruction calldata _paymentInstruction
    )
        internal view
        returns (bool)
    {
        return paymentHashes[_accountHash][_paymentId] == _getPaymentHash(_paymentInstruction, _paymentId);
    }

    function _isBatchFull(
        AccountState storage _state
    )
        internal view
        returns (bool)
    {
        return _state.batchPaymentCount >= _state.batchSizeEffective;
    }

    function _effectiveBatchSettings(
        bytes32 _sourceId,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        internal view
        returns (
            uint64 _effectiveBatchSize,
            uint64 _effectiveBatchDurationSeconds
        )
    {
        MaxBatchSettings storage settings = maxBatchSettings[_sourceId];
        require(settings.maxBatchSize > 0, MaxBatchSizeZero());
        _effectiveBatchSize = _batchSize < settings.maxBatchSize ? _batchSize : settings.maxBatchSize;
        _effectiveBatchDurationSeconds =
            _batchDurationSeconds < settings.maxBatchDurationSeconds
                ? _batchDurationSeconds
                : settings.maxBatchDurationSeconds;
    }

    function _checkStoredAnchorsMatch(
        bytes32 _accountHash,
        IPMWMultisigUtxoConfigured.Proof calldata _proof,
        uint256 _anchorCount
    )
        internal view
    {
        for (uint256 i = 0; i < _anchorCount; i++) {
            UtxoAnchorState storage storedAnchor = anchors[_accountHash][i];
            IPMWMultisigUtxoConfigured.Anchor calldata proofAnchor = _proof.requestBody.anchors[i];
            require(
                storedAnchor.genesisAnchorTxid == proofAnchor.genesisAnchorTxid &&
                storedAnchor.genesisAnchorVout == proofAnchor.genesisAnchorVout,
                AnchorMismatch()
            );
        }
    }

    function _buildMessage(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        bytes32 _walletId,
        uint32 _accountIndex,
        uint32 _anchorIndex,
        uint64 _nonce,
        uint64 _paymentId,
        uint64 _batchPaymentId,
        uint64 _batchEndTs,
        ITeePaymentsBase.PaymentInstruction calldata _paymentInstruction,
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    )
        internal pure
        returns (UtxoPaymentInstructionMessage memory _message)
    {
        _message.walletId = _walletId;
        _message.teeIdKeyIdPairs = _teeIdKeyIdPairs;
        _message.sourceId = _account.sourceId;
        _message.accountAddress = _account.accountAddress;
        _message.accountIndex = _accountIndex;
        _message.anchorIndex = _anchorIndex;
        _message.nonce = _nonce;
        _message.paymentId = _paymentId;
        _message.batchPaymentId = _batchPaymentId;
        _message.batchEndTs = _batchEndTs;
        _message.recipientAddress = _paymentInstruction.recipientAddress;
        _message.tokenId = _paymentInstruction.tokenId;
        _message.amount = _paymentInstruction.amount;
        _message.paymentReference = _paymentInstruction.paymentReference;
    }

    /**
     * Validates the reissue fee parameters and returns the per-payment encoded fee schedules in one
     * pass. Empty `factorsBIPSPerPayment` (and no delays) means "no schedule override" → returns an
     * empty array (callers fall back to DEFAULT_FEE_SCHEDULE). Otherwise only the trivial single-entry,
     * zero-delay schedule shape is supported (covers fee bumps and negative-factor nullification).
     */
    function _validateAndEncodeReissueSchedules(
        uint256 _paymentCount,
        ITeePaymentsBase.ReissueFeeParams calldata _reissueFeeParams
    )
        internal pure
        returns (bytes[] memory _encodedSchedules)
    {
        require(_paymentCount == _reissueFeeParams.maxFeePerPayment.length, ITeePaymentsBase.LengthsMismatch());
        if (_reissueFeeParams.factorsBIPSPerPayment.length == 0 && _reissueFeeParams.delaysSeconds.length == 0) {
            return _encodedSchedules;
        }
        require(_paymentCount == _reissueFeeParams.factorsBIPSPerPayment.length, ITeePaymentsBase.LengthsMismatch());
        require(
            _reissueFeeParams.delaysSeconds.length == 1 &&
            _reissueFeeParams.delaysSeconds[0] == 0,
            ScheduledSignaturesUnsupported()
        );
        _encodedSchedules = new bytes[](_reissueFeeParams.factorsBIPSPerPayment.length);
        for (uint256 i = 0; i < _reissueFeeParams.factorsBIPSPerPayment.length; i++) {
            require(_reissueFeeParams.factorsBIPSPerPayment[i].length == 1, ScheduledSignaturesUnsupported());
            int16 factor = _reissueFeeParams.factorsBIPSPerPayment[i][0];
            require(-10000 <= factor && factor <= 10000 && factor != 0, InvalidFeeFactor(i));
            _encodedSchedules[i] = abi.encodePacked(factor, uint16(0));
        }
    }

    function _checkPaymentRange(
        uint64 _batchPaymentId,
        uint64 _paymentId,
        uint256 _paymentCount,
        uint64 _batchPaymentCount
    )
        internal pure
    {
        require(_paymentId >= _batchPaymentId, PaymentNotInBatch());
        uint64 lastPaymentId = _addToUint64(_paymentId, _paymentCount - 1);
        require(lastPaymentId < _addToUint64(_batchPaymentId, _batchPaymentCount), PaymentNotInBatch());
    }

}
