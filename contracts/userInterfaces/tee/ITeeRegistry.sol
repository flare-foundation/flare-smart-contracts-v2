// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeRegistry interface.
 */
interface ITeeRegistry {

    struct TeeMachine {
        bytes32 publicKey;
        string ipAddress;
    }

    event TeeMachineRegistered(bytes32 indexed publicKey, string indexed ipAddress);

    /**
     * Returns info if the TEE machine is registered.
     * @param _teeMachine The TEE machine.
     * @return True if the TEE machine is registered, false otherwise.
     */
    function isRegisteredTeeMachine(TeeMachine calldata _teeMachine) external view returns (bool);

    /**
     * Returns all registered TEE machines.
     * @return All registered TEE machines.
     */
    function getTeeMachines() external view returns (TeeMachine[] memory);
}