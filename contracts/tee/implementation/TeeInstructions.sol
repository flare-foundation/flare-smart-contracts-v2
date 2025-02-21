// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../protocol/interface/IIRewardManager.sol";
import "../../utils/lib/AddressSet.sol";

/**
 * TeeInstructions is used for issuing instructions (emitting events)
 * that data providers are listening to perform operations on TEE machines.
 */
contract TeeInstructions is ITeeInstructions, Governed, AddressUpdatable {
    using AddressSet for AddressSet.State;

    /// The RewardManager contract.
    IIRewardManager public rewardManager;

    /// List of instruction initiator contracts.
    AddressSet.State internal instructionInitiators;

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
        uint24 _rewardEpochId,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message
    )
        external payable
    {
        emit TeeInstructionsSent(
            _instructionId,
            _rewardEpochId,
            _teeMachines,
            _opType,
            _opCommand,
            _message,
            msg.value
        );
        rewardManager.receiveRewards{value: msg.value} (_rewardEpochId, false);
    }

    /**
     Registers instruction initiator contracts.
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
     Unregisters instruction initiator contracts.
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
        rewardManager = IIRewardManager(_getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
    }
}
