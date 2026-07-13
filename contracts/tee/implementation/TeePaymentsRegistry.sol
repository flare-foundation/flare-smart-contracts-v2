// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "../../governance/implementation/FlareUpgradeableBase.sol";
import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";
import { ITeePaymentsModel, PaymentModel } from "../../userInterfaces/tee/ITeePaymentsModel.sol";
import { IITeePaymentsRegistry } from "../interface/IITeePaymentsRegistry.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * TeePaymentsRegistry — single source of truth for `sourceId` -> `TeePayments` bindings.
 *
 * Governance-only register/unregister. Stores forward map, reverse map, and an
 * enumerable set of distinct TeePayments contracts with at least one bound sourceId.
 */
contract TeePaymentsRegistry is IITeePaymentsRegistry, FlareUpgradeableBase {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(bytes32 sourceId => SourceConfig sourceConfig) private sourceConfigs;
    EnumerableSet.Bytes32Set private registeredSourceIds;
    EnumerableSet.AddressSet private registeredTeePaymentsContracts;
    mapping(address teePayments => EnumerableSet.Bytes32Set) private sourceIdsByTeePayments;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by the `initializer` modifier).
     * @param _governanceSettings The governance settings interface.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address updater contract.
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external virtual
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc IITeePaymentsRegistry
     */
    function registerSources(
        SourceRegistration[] calldata _registrations
    )
        external
        onlyGovernance
    {
        for (uint256 i = 0; i < _registrations.length; i++) {
            SourceRegistration calldata registration = _registrations[i];
            require(registration.sourceId != bytes32(0), SourceIdZero(i));
            require(registration.opType != bytes32(0), SourceOpTypeZero(i));
            require(registration.keyType != bytes32(0), SourceKeyTypeZero(i));
            require(registration.paymentModel != PaymentModel.UNKNOWN, SourcePaymentModelUnknown(i));
            require(
                registration.teePayments.code.length > 0,
                TeePaymentsNotContract(registration.teePayments)
            );
            PaymentModel actualPaymentModel = ITeePaymentsModel(registration.teePayments).paymentModel();
            require(
                actualPaymentModel == registration.paymentModel,
                WrongPaymentModel(registration.teePayments, registration.paymentModel, actualPaymentModel)
            );
            address registeredTeePayments = sourceConfigs[registration.sourceId].teePayments;
            require(
                registeredTeePayments == address(0),
                SourceAlreadyRegistered(registration.sourceId, registeredTeePayments)
            );
            sourceConfigs[registration.sourceId] = SourceConfig({
                keyType: registration.keyType,
                opType: registration.opType,
                paymentModel: registration.paymentModel,
                teePayments: registration.teePayments
            });
            registeredSourceIds.add(registration.sourceId);
            sourceIdsByTeePayments[registration.teePayments].add(registration.sourceId);
            registeredTeePaymentsContracts.add(registration.teePayments);
        }
        emit SourcesRegistered(_registrations);
    }

    /**
     * @inheritdoc IITeePaymentsRegistry
     */
    function unregisterSources(
        bytes32[] calldata _sourceIds
    )
        external
        onlyGovernance
    {
        for (uint256 i = 0; i < _sourceIds.length; i++) {
            bytes32 sourceId = _sourceIds[i];
            address registeredTeePayments = sourceConfigs[sourceId].teePayments;
            require(registeredTeePayments != address(0), SourceNotRegistered(sourceId));
            delete sourceConfigs[sourceId];
            registeredSourceIds.remove(sourceId);
            sourceIdsByTeePayments[registeredTeePayments].remove(sourceId);
            if (sourceIdsByTeePayments[registeredTeePayments].length() == 0) {
                registeredTeePaymentsContracts.remove(registeredTeePayments);
            }
        }
        emit SourcesUnregistered(_sourceIds);
    }

    /**
     * @inheritdoc ITeePaymentsRegistry
     */
    function getTeePaymentsForSource(
        bytes32 _sourceId
    )
        external view
        returns (address)
    {
        return sourceConfigs[_sourceId].teePayments;
    }

    /**
     * @inheritdoc ITeePaymentsRegistry
     */
    function getSourceConfig(
        bytes32 _sourceId
    )
        external view
        returns (SourceConfig memory)
    {
        return sourceConfigs[_sourceId];
    }

    /**
     * @inheritdoc ITeePaymentsRegistry
     */
    function getSourceOpTypeAndTeePayments(
        bytes32 _sourceId
    )
        external view
        returns (
            bytes32 _opType,
            address _teePayments
        )
    {
        SourceConfig storage sourceConfig = sourceConfigs[_sourceId];
        _opType = sourceConfig.opType;
        _teePayments = sourceConfig.teePayments;
    }

    /**
     * @inheritdoc ITeePaymentsRegistry
     */
    function getSourceKeyTypeAndTeePayments(
        bytes32 _sourceId
    )
        external view
        returns (
            bytes32 _keyType,
            address _teePayments
        )
    {
        SourceConfig storage sourceConfig = sourceConfigs[_sourceId];
        _keyType = sourceConfig.keyType;
        _teePayments = sourceConfig.teePayments;
    }

    /**
     * @inheritdoc ITeePaymentsRegistry
     */
    function getSourcePaymentModel(
        bytes32 _sourceId
    )
        external view
        returns (PaymentModel)
    {
        return sourceConfigs[_sourceId].paymentModel;
    }

    /**
     * @inheritdoc ITeePaymentsRegistry
     */
    function getSourceIdsForTeePayments(
        address _teePayments
    )
        external view
        returns (bytes32[] memory)
    {
        return sourceIdsByTeePayments[_teePayments].values();
    }

    /**
     * @inheritdoc ITeePaymentsRegistry
     */
    function getRegisteredSourceIds()
        external view
        returns (bytes32[] memory)
    {
        return registeredSourceIds.values();
    }

    /**
     * @inheritdoc ITeePaymentsRegistry
     */
    function getRegisteredTeePaymentsContracts()
        external view
        returns (address[] memory)
    {
        return registeredTeePaymentsContracts.values();
    }

    /**
     * @inheritdoc ITeePaymentsRegistry
     */
    function isSourceRegistered(
        bytes32 _sourceId
    )
        external view
        returns (bool)
    {
        return registeredSourceIds.contains(_sourceId);
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory /* _contractNameHashes */,
        address[] memory /* _contractAddresses */
    )
        internal virtual override
    {
        // Registry has no external dependencies.
    }
}
