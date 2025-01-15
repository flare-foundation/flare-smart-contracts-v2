// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TEERegistry interface.
 */
interface ITEERegistry {

    struct TEEMachine {
        bytes32 publicKey;
        string IPAddress;
    }

    event TEEMachineRegistered(bytes32 indexed publicKey, string indexed IPAddress);

    /**
     * Returns info if the TEE machine is registered.
     * @param _teeMachine The TEE machine.
     * @return True if the TEE machine is registered, false otherwise.
     */
    function isRegisteredTEEMachine(TEEMachine calldata _teeMachine) external view returns (bool);

    /**
     * Returns all registered TEE machines.
     * @return All registered TEE machines.
     */
    function getTEEMachines() external view returns (TEEMachine[] memory);
}