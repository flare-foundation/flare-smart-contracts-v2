// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";

interface IITeeExtensionRegistry is ITeeExtensionRegistry {

    /**
     * Send instructions to the TEE machines - same as sendInstructions but with full TEE machine data provided.
     * Emits a TeeInstructionsSent event.
     * @param _instructionId The instruction ID.
     * @param _teeMachines The TEE machines to which the instructions are sent (must all belong to the same extension).
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @param _message The message.
     * @param _cosigners The cosigners.
     * @param _cosignersThreshold The cosigners threshold.
     * Can only be called by the system instruction initiators.
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
        external payable;
}