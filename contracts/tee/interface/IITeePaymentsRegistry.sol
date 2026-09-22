// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";

/**
 * IITeePaymentsRegistry internal interface.
 * @dev Extends the public ITeePaymentsRegistry with governance-only management methods.
 */
interface IITeePaymentsRegistry is ITeePaymentsRegistry {

    /**
     * Batch registers new sourceId -> TeePayments bindings.
     * Reverts with `SourceAlreadyRegistered` if any sourceId is already mapped — to rebind,
     * governance must call `unregisterSources` first. Reverts with `SourceIdZero` if any
     * sourceId is `bytes32(0)` or `TeePaymentsNotContract` if any teePayments address has no
     * deployed code (guards against EOAs and typos).
     * Emits a single `SourcesRegistered` event with all input registrations.
     * @param _registrations The batch of registrations.
     * Can only be called by the governance.
     */
    function registerSources(
        ITeePaymentsRegistry.SourceRegistration[] calldata _registrations
    )
        external;

    /**
     * Batch unregisters previously-registered sourceIds.
     * Reverts with `SourceNotRegistered` if any sourceId is not registered.
     * Emits a single `SourcesUnregistered` event with the sourceIds removed.
     * @param _sourceIds The sourceIds to unregister.
     * Can only be called by the governance.
     */
    function unregisterSources(
        bytes32[] calldata _sourceIds
    )
        external;
}
