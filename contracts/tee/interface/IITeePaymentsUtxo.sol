// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePaymentsUtxo } from "../../userInterfaces/tee/ITeePaymentsUtxo.sol";

/**
 * Internal UTXO TeePayments interface.
 * @dev Extends the public ITeePaymentsUtxo with governance-only management methods.
 */
interface IITeePaymentsUtxo is ITeePaymentsUtxo {

    event AnchorReuseDelaySet(
        bytes32 indexed sourceId,
        uint64 anchorReuseDelaySeconds
    );

    event MaxBatchSettingsSet(
        bytes32 indexed sourceId,
        uint64 maxBatchSize,
        uint64 maxBatchDurationSeconds
    );

    /**
     * Sets the anchor reuse delay for a source routed to this UTXO TeePayments contract.
     * Emits AnchorReuseDelaySet event.
     * @param _sourceId The source id.
     * @param _anchorReuseDelaySeconds The delay before a used anchor can be reused.
     * Can only be called by governance.
     */
    function setAnchorReuseDelay(
        bytes32 _sourceId,
        uint64 _anchorReuseDelaySeconds
    )
        external;

    /**
     * Sets UTXO batch limits for a source routed to this UTXO TeePayments contract.
     * Emits MaxBatchSettingsSet event.
     * @param _sourceId The source id.
     * @param _maxBatchSize The maximum number of payments in a UTXO batch.
     * @param _maxBatchDurationSeconds The maximum duration of a UTXO batch in seconds.
     * Can only be called by governance.
     */
    function setMaxBatchSettings(
        bytes32 _sourceId,
        uint64 _maxBatchSize,
        uint64 _maxBatchDurationSeconds
    )
        external;
}
