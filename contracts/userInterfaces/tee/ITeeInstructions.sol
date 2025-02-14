// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeInstructions interface.
 */
interface ITeeInstructions {

    event TeeInstructionsSent (
        bytes32 indexed instructionId,
        ITeeRegistry.TeeMachine[] teeMachines,
        uint256 rewardEpochId,
        bytes32 opType,
        bytes32 instruction,
        bytes message
    );

    /**
     * Send instructions to the TEE machines.
     * Emits a TeeInstructionsSent event.
     * @param _instructionId The instruction ID.
     * @param _teeMachines The TEE machines.
     * @param _rewardEpochId The reward epoch ID.
     * @param _opType The operation type.
     * @param _instruction The instruction.
     * @param _message The message.
     */
    function send(
        bytes32 _instructionId,
        ITeeRegistry.TeeMachine[] memory _teeMachines,
        uint256 _rewardEpochId,
        bytes32 _opType,
        bytes32 _instruction,
        bytes memory _message
    )
        external;
}