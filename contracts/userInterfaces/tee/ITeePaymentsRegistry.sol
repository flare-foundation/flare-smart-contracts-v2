// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { PaymentModel } from "./ITeePaymentsModel.sol";

/**
 * ITeePaymentsRegistry interface.
 *
 * Single source of truth mapping `sourceId` -> `TeePayments` contract. Used by:
 *  - The TeePayments / TeePaymentsUtxo `addPMWMultisigAccount` to verify the source is bound
 *    to this contract.
 *  - TeePaymentsFeeScheduleManager to resolve the TeePayments instance for a given
 *    account's sourceId (and from there, the walletId -> projectId -> owner chain).
 *
 * Governance-only register/unregister. Strict semantics: `registerSources` reverts if any
 * sourceId is already registered; `unregisterSources` reverts if any sourceId is not.
 * To rebind a sourceId, governance must unregister it and then register it again — no silent
 * overwrite is permitted.
 */
interface ITeePaymentsRegistry {

    /// Input struct for batch registration.
    // NOTE: alphabetical field order for stdJson compatibility.
    struct SourceRegistration {
        bytes32 keyType;
        bytes32 opType;
        PaymentModel paymentModel;
        bytes32 sourceId;
        address teePayments;
    }

    struct SourceConfig {
        bytes32 keyType;
        bytes32 opType;
        PaymentModel paymentModel;
        address teePayments;
    }

    event SourcesRegistered(
        SourceRegistration[] registrations
    );

    event SourcesUnregistered(
        bytes32[] sourceIds
    );

    error SourceNotRegistered(bytes32 sourceId);
    error SourceAlreadyRegistered(bytes32 sourceId, address teePayments);
    error TeePaymentsNotContract(address teePayments);
    error WrongPaymentModel(address teePayments, PaymentModel expected, PaymentModel actual);
    error SourceIdZero(uint256 index);
    error SourceKeyTypeZero(uint256 index);
    error SourceOpTypeZero(uint256 index);
    error SourcePaymentModelUnknown(uint256 index);

    /**
     * Returns the TeePayments address bound to the given sourceId, or `address(0)` if unknown.
     * Callers are expected to do the zero-check themselves (simplifies compositions like
     * `== address(this)` inside TeePayments.addPMWMultisigAccount).
     * @param _sourceId The sourceId to look up.
     * @return _teePayments The bound TeePayments address (zero if not registered).
     */
    function getTeePaymentsForSource(
        bytes32 _sourceId
    )
        external view
        returns (address _teePayments);

    /**
     * Returns the full source configuration, or zero/default values if the source is unknown.
     * @param _sourceId The sourceId to look up.
     * @return _sourceConfig The source configuration.
     */
    function getSourceConfig(
        bytes32 _sourceId
    )
        external view
        returns (SourceConfig memory _sourceConfig);

    /**
     * Returns the operation type and TeePayments address bound to the given sourceId.
     * @param _sourceId The sourceId to look up.
     * @return _opType The operation type.
     * @return _teePayments The bound TeePayments address (zero if not registered).
     */
    function getSourceOpTypeAndTeePayments(
        bytes32 _sourceId
    )
        external view
        returns (
            bytes32 _opType,
            address _teePayments
        );

    /**
     * Returns the key type and TeePayments address bound to the given sourceId.
     * @param _sourceId The sourceId to look up.
     * @return _keyType The key type.
     * @return _teePayments The bound TeePayments address (zero if not registered).
     */
    function getSourceKeyTypeAndTeePayments(
        bytes32 _sourceId
    )
        external view
        returns (
            bytes32 _keyType,
            address _teePayments
        );

    /**
     * Returns the payment model bound to the given sourceId (`UNKNOWN` if not registered).
     * @param _sourceId The sourceId to look up.
     * @return _paymentModel The payment model.
     */
    function getSourcePaymentModel(
        bytes32 _sourceId
    )
        external view
        returns (PaymentModel _paymentModel);

    /**
     * Returns all sourceIds bound to the given TeePayments contract (reverse lookup).
     * @param _teePayments The TeePayments contract address.
     * @return _sourceIds The sourceIds bound to the given TeePayments.
     */
    function getSourceIdsForTeePayments(
        address _teePayments
    )
        external view
        returns (bytes32[] memory _sourceIds);

    /**
     * Returns all registered sourceIds (enumeration).
     * @return _sourceIds The list of all registered sourceIds.
     */
    function getRegisteredSourceIds()
        external view
        returns (bytes32[] memory _sourceIds);

    /**
     * Returns the list of distinct TeePayments contracts that have at least one sourceId bound
     * (enumeration / observability).
     * @return _teePaymentsContracts The list of distinct TeePayments contract addresses.
     */
    function getRegisteredTeePaymentsContracts()
        external view
        returns (address[] memory _teePaymentsContracts);

    /**
     * Returns whether the given sourceId is registered.
     * @param _sourceId The sourceId to check.
     * @return True if the sourceId is registered, false otherwise.
     */
    function isSourceRegistered(
        bytes32 _sourceId
    )
        external view
        returns (bool);
}
