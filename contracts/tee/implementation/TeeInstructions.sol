// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../protocol/interface/IIRewardManager.sol";
import "../../utils/lib/AddressSet.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * TeeInstructions is used for issuing instructions (emitting events)
 * that data providers are listening to perform operations on TEE machines.
 */
contract TeeInstructions is ITeeInstructions, GovernedProxyImplementation, AddressUpdatable, UUPSUpgradeable {
    using AddressSet for AddressSet.State;

    /// The RewardManager contract.
    IIRewardManager public rewardManager;

    /// List of instruction initiator contracts.
    AddressSet.State internal instructionInitiators;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        GovernedProxyImplementation() AddressUpdatable(address(0))
    { }

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
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
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
        require(instructionInitiators.index[msg.sender] != 0, "only instruction initiators");
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

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(newImplementation, data);
    }

    /**
     * Unused. just to present to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeTo and upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

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
