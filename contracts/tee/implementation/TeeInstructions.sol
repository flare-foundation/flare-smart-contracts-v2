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

    /// List of instruction initiator contracts.
    AddressSet.State internal instructionInitiatorContracts;

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
    function sendInstructions(
        bytes32 _instructionId,
        ITeeRegistry.TeeMachine[] memory _teeMachines,
        uint256 _rewardEpochId,
        bytes32 _opType,
        bytes32 _instruction,
        bytes memory _message
    )
        external payable
    {
        emit TeeInstructionsSent(_instructionId, _teeMachines, _rewardEpochId, _opType, _instruction, _message);
    }

    /**
     Registers an instruction initiator contracts.
     * @param _instructionInitiatorContracts The functionality contract.
     * @dev Only governance can call this method.
     */
    function registerInstructionInitiatorContracts(
        address[] calldata _instructionInitiatorContracts
    )
        external onlyGovernance
    {
        instructionInitiatorContracts.addAll(_instructionInitiatorContracts);
    }

    /**
     Registers an instruction initiator contracts.
     * @param _instructionInitiatorContracts The functionality contract.
     * @dev Only governance can call this method.
     */
    function unregisterInstructionInitiatorContracts(
        address[] calldata _instructionInitiatorContracts
    )
        external onlyGovernance
    {
        for (uint256 i = 0; i < _instructionInitiatorContracts.length; ++i) {
            instructionInitiatorContracts.remove(_instructionInitiatorContracts[i]);
        }
    }

    /**
     * @inheritdoc ITeeInstructions
     */
    function getInstructionInitiatorContracts() external view returns(address[] memory) {
        return instructionInitiatorContracts.list;
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
