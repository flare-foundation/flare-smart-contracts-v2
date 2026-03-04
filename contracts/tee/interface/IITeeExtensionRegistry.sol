// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";

interface IITeeExtensionRegistry is ITeeExtensionRegistry {

    /**
     * Send instructions to the TEE machines - same as sendInstructions but with instruction ID (might be bytes32(0)).
     * Emits TeeInstructionsSent event.
     * @param _instructionId The instruction ID - auto generated in case of bytes32(0).
     * @param _teeIds The TEE machine IDs to which the instructions are sent (must all belong to the same extension).
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @param _message The message.
     * @param _cosigners The cosigners.
     * @param _cosignersThreshold The cosigners threshold.
     * @return The instruction ID.
     * Can only be called by the system instructions senders.
     * @dev No check for duplicated TEE machines is performed.
     */
    function sendSystemInstructions(
        bytes32 _instructionId,
        address[] memory _teeIds,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        external payable
        returns (bytes32);

    /**
     * Send instructions to the TEE machines - same as sendSystemInstructions but with full TEE machine data provided.
     * Emits TeeInstructionsSent event.
     * @param _instructionId The instruction ID.
     * @param _teeMachines The TEE machines to which the instructions are sent (must all belong to the same extension).
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @param _message The message.
     * @param _cosigners The cosigners.
     * @param _cosignersThreshold The cosigners threshold.
     * @return The instruction ID.
     * Can only be called by the system instructions senders.
     * @dev No check for duplicated TEE machines is performed.
     */
    function sendSystemInstructions(
        bytes32 _instructionId,
        ITeeMachineRegistry.TeeMachine[] memory _teeMachines,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        external payable
        returns (bytes32);
}