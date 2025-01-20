// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";

/**
 * TeeRegistry is used for registration of TEE machines.
 */
contract TeeRegistry is ITeeRegistry, Governed, AddressUpdatable {

    TeeMachine[] private teeMachines;

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
    function registerTeeMachines(TeeMachine[] calldata _teeMachines) external onlyGovernance {
        for (uint256 i = 0; i < _teeMachines.length; i++) {
            _registerTeeMachine(_teeMachines[i]);
        }
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function isRegisteredTeeMachine(TeeMachine calldata _teeMachine) external view returns (bool) {
        for (uint256 i = 0; i < teeMachines.length; i++) {
            TeeMachine storage teeMachine = teeMachines[i];
            if (teeMachine.publicKey == _teeMachine.publicKey &&
                _keccak256AbiEncode(teeMachine.ipAddress) == _keccak256AbiEncode(_teeMachine.ipAddress)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getTeeMachines() external view returns (TeeMachine[] memory) {
        return teeMachines;
    }

    /**
     * Register a TEE machine.
     * @param _teeMachine The TEE machine.
     */
    function _registerTeeMachine(TeeMachine calldata _teeMachine) internal {
        for (uint256 i = 0; i < teeMachines.length; i++) {
            TeeMachine storage teeMachine = teeMachines[i];
            require(teeMachine.publicKey != _teeMachine.publicKey &&
                _keccak256AbiEncode(teeMachine.ipAddress) != _keccak256AbiEncode(_teeMachine.ipAddress),
                "TEE machine already registered"
            );
        }
        teeMachines.push(_teeMachine);
        emit TeeMachineRegistered(_teeMachine.publicKey, _teeMachine.ipAddress);
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
