// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { ITeeInstructions } from "../../userInterfaces/tee/ITeeInstructions.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { AddressSet } from "../../utils/lib/AddressSet.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeInstructions is used for issuing instructions (emitting events)
 * that data providers are listening to perform operations on TEE machines.
 */
contract TeeInstructions is ITeeInstructions, TeeBase {
    using AddressSet for AddressSet.State;

    /// List of instruction initiator contracts.
    AddressSet.State internal instructionInitiators;

    // TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;

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
     * @inheritdoc ITeeInstructions
     */
    function sendInstructions(
        bytes32 _instructionId,
        address[] memory _teeIds,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        external payable
    {
        require(instructionInitiators.index[msg.sender] != 0, OnlyInstructionInitiator());
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            _instructionId,
            _teeIds,
            _opType,
            _opCommand,
            _message,
            _cosigners,
            _cosignersThreshold
        );
    }

    /**
     * Registers instruction initiator contracts.
     * @param _instructionInitiators List of contracts to register.
     * @dev Only governance can call this method.
     */
    function registerInstructionInitiators(
        address[] calldata _instructionInitiators
    )
        external onlyGovernance
    {
        instructionInitiators.addAll(_instructionInitiators);
    }

    /**
     * Unregisters instruction initiator contracts.
     * @param _instructionInitiators List of contracts to unregister.
     * @dev Only governance can call this method.
     */
    function unregisterInstructionInitiators(
        address[] calldata _instructionInitiators
    )
        external onlyGovernance
    {
        for (uint256 i = 0; i < _instructionInitiators.length; ++i) {
            instructionInitiators.remove(_instructionInitiators[i]);
        }
    }

    /**
     * @inheritdoc ITeeInstructions
     */
    function getInstructionInitiators() external view returns(address[] memory) {
        return instructionInitiators.list;
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
    }
}
