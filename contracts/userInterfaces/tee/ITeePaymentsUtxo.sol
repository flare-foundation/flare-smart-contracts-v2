// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

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

    function addPMWMultisigAccount(
        bytes32 _walletId,
        IPMWMultisigUtxoConfigured.Proof calldata _proof,
        address _authorizationAddress
    )
        external;

    function addAnchors(
        IPMWMultisigUtxoConfigured.Proof calldata _proof
    )
        external;

    function setBatchSettings(
        PMWMultisigAccount calldata _account,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        external;

    function getBatchSettings(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (
            uint64 _batchSize,
            uint64 _batchDurationSeconds
        );

    function getMaxBatchSettings(
        bytes32 _sourceId
    )
        external view
        returns (
            uint64 _maxBatchSize,
            uint64 _maxBatchDurationSeconds
        );

    function getAnchorReuseDelay(
        bytes32 _sourceId
    )
        external view
        returns (uint64 _anchorReuseDelaySeconds);

    function getAnchor(
        PMWMultisigAccount calldata _account,
        uint256 _anchorIndex
    )
        external view
        returns (UtxoAnchorState memory _anchor);

    function getAnchorCount(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (uint256 _anchorCount);

}
