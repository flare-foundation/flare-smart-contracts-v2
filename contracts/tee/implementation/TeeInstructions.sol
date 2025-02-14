// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../utils/lib/AddressSet.sol";

/**
 * TeeInstructions is used for issuing instructions (emitting events)
 * that data providers are listening to perform operations on TEE machines.
 */
contract TeeInstructions is ITeeInstructions, Governed, AddressUpdatable {
        using AddressSet for AddressSet.State;

    /// List of opType contracts.
    AddressSet.State internal opTypeContracts;

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * @inheritdoc ITeeInstructions
     */
    function registerOpTypeContract(address _opTypeContract) external override onlyGovernance {
        opTypeContracts.add(_opTypeContract);
    }

    /**
     * @inheritdoc ITeeInstructions
     */
    function unregisterOpTypeContract(address _opTypeContract) external override onlyGovernance {
        opTypeContracts.remove(_opTypeContract);
    }

    /**
     * @inheritdoc ITeeInstructions
     */
    function send(
        bytes32 _instructionId,
        ITeeRegistry.TeeMachine[] memory _teeMachines,
        uint256 _rewardEpochId,
        bytes32 _opType,
        bytes32 _instruction,
        bytes memory _message
    )
        external override
    {
        emit TeeInstructionsSent(_instructionId, _teeMachines, _rewardEpochId, _opType, _instruction, _message);
    }

    /**
     * Returns opTypes contracts.
     */
    function getOpTypeContracts() external view returns(address[] memory) {
        return opTypeContracts.list;
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
    }
}
