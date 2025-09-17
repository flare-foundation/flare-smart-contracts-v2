
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { IITeeSystemStateVerifier } from "../interface/IITeeSystemStateVerifier.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeSystemStateVerifier is used for verifying TEE machine state.
 */
contract TeeSystemStateVerifier is IITeeSystemStateVerifier, TeeBase {

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE machine registry contract.
    ITeeMachineRegistry public teeMachineRegistry;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeeBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external
    {
        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc IITeeSystemStateVerifier
     */
    function verifyTeeSystemState(
        address _teeId,
        bytes32 _stateVersion,
        bytes calldata _state
    )
        external view
        returns (bool _isValid)
    {
        ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachine =
            teeMachineRegistry.getTeeMachineWithAttestationData(_teeId);
        uint256 extensionId = teeMachineRegistry.getExtensionId(_teeId);
        bytes32 teeGovernanceHash = teeExtensionRegistry.getTeeGovernanceHash(extensionId, teeMachine.codeHash);
        if (_stateVersion == bytes32(0)) {
            return _state.length == 0 && teeGovernanceHash == bytes32(0);
        }
        IITeeSystemStateVerifier.TeeSystemState memory state =
            abi.decode(_state, (IITeeSystemStateVerifier.TeeSystemState));
        // Check if the TEE machine is active and the state matches the governance hash.
        return
            state.status == IITeeSystemStateVerifier.TeeMachineStatus.ACTIVE &&
            state.initialTeeId == teeMachine.initialTeeId &&
            state.teeGovernanceHash == teeGovernanceHash;
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeMachineRegistry = ITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
    }
}
