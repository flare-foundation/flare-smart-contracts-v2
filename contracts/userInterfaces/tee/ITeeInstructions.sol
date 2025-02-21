// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeInstructions interface.
 */
interface ITeeInstructions {

    event TeeInstructionsSent (
        bytes32 indexed instructionId,
        uint24 indexed rewardEpochId,
        ITeeRegistry.TeeMachine[] teeMachines,
        bytes32 opType,
        bytes32 instruction,
        bytes message,
        uint256 fee
    );

    /**
     * Send instructions to the TEE machines.
     * Emits a TeeInstructionsSent event.
     * @param _instructionId The instruction ID.
     * @param _teeMachines The TEE machines.
     * @param _rewardEpochId The reward epoch ID.
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @param _message The message.
     */
    function sendInstructions(
        bytes32 _instructionId,
        ITeeRegistry.TeeMachine[] memory _teeMachines,
        uint24 _rewardEpochId,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message
    )
        external payable;


    /**
     * Returns the list of instruction initiator contracts.
     */
    function getInstructionInitiators() external view returns (address[] memory);
}