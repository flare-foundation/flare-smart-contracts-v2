// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITEERegistry.sol";

/**
 * TEERegistry is used for registration of TEE machines.
 */
contract TEERegistry is ITEERegistry, Governed, AddressUpdatable {

    TEEMachine[] private teeMachines;

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
     * Register a list of TEE machines.
     * @param _teeMachines List of TEE machines.
     */
    function registerTEEMachines(TEEMachine[] calldata _teeMachines) external onlyGovernance {
        for (uint256 i = 0; i < _teeMachines.length; i++) {
            _registerTEEMachine(_teeMachines[i]);
        }
    }

    /**
     * @inheritdoc ITEERegistry
     */
    function isRegisteredTEEMachine(TEEMachine calldata _teeMachine) external view returns (bool) {
        for (uint256 i = 0; i < teeMachines.length; i++) {
            TEEMachine storage teeMachine = teeMachines[i];
            if (teeMachine.publicKey == _teeMachine.publicKey &&
                _keccak256AbiEncode(teeMachine.IPAddress) == _keccak256AbiEncode(_teeMachine.IPAddress)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @inheritdoc ITEERegistry
     */
    function getTEEMachines() external view returns (TEEMachine[] memory) {
        return teeMachines;
    }

    /**
     * Register a TEE machine.
     * @param _teeMachine The TEE machine.
     */
    function _registerTEEMachine(TEEMachine calldata _teeMachine) internal {
        for (uint256 i = 0; i < teeMachines.length; i++) {
            TEEMachine storage teeMachine = teeMachines[i];
            require(teeMachine.publicKey != _teeMachine.publicKey &&
                _keccak256AbiEncode(teeMachine.IPAddress) != _keccak256AbiEncode(_teeMachine.IPAddress),
                "TEE machine already registered"
            );
        }
        teeMachines.push(_teeMachine);
        emit TEEMachineRegistered(_teeMachine.publicKey, _teeMachine.IPAddress);
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

    /**
     * @notice Returns hash from string value
     */
    function _keccak256AbiEncode(string memory _value) internal pure returns(bytes32) {
        return keccak256(abi.encode(_value));
    }
}
