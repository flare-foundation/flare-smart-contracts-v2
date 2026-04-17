// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IMachineManagerFacet } from "./IMachineManagerFacet.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IInstructionsFacet
 * @notice Public interface for the InstructionsFacet.
 */
interface IInstructionsFacet is ITeeCommonErrors {

    /**
     * Struct containing the instruction parameters.
     * @param opType The operation type.
     * @param opCommand The operation command.
     * @param message The message.
     * @param cosigners The cosigners.
     * @param cosignersThreshold The cosigners threshold.
     * @param claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     */
    struct TeeInstructionParams {
        bytes32 opType;
        bytes32 opCommand;
        bytes message;
        address[] cosigners;
        uint64 cosignersThreshold;
        address claimBackAddress;
    }

    event TeeInstructionsSent(
        uint256 indexed extensionId,
        bytes32 indexed instructionId,
        uint32 indexed rewardEpochId,
        IMachineManagerFacet.TeeMachine[] teeMachines,
        bytes32 opType,
        bytes32 opCommand,
        bytes message,
        address[] cosigners,
        uint64 cosignersThreshold,
        address claimBackAddress,
        uint256 fee
    );

    event SystemInstructionsSendersRegistered(
        address[] instructionsSenders
    );

    event SystemInstructionsSendersUnregistered(
        address[] instructionsSenders
    );

    error NoTeeMachinesSpecified();
    error OperationTypeEmpty();
    error OperationCommandEmpty();
    error MessageEmpty();
    error OnlyInstructionsSender();
    error OnlySystemInstructionsSender();
    error SystemOpTypeNotAllowed(bytes32 opType);
    error FeeTooLow();
    error CosignersThresholdTooHigh();
    error SystemInstructionsSenderAlreadyExists(address instructionsSender);
    error SystemInstructionsSenderNotFound(address instructionsSender);

    /**
     * Send instructions to the TEE machines. Instruction ID will be generated internally and returned.
     * Emits TeeInstructionsSent event.
     * @param _teeIds The TEE machine IDs to which the instructions are sent (must all belong to the same extension).
     * @param _instructionParams The instruction parameters.
     * @return _instructionId The generated instruction ID.
     * Can only be called by the TEE machines extension instructions sender.
     */
    function sendInstructions(
        address[] calldata _teeIds,
        TeeInstructionParams calldata _instructionParams
    )
        external payable
        returns (bytes32 _instructionId);

    /**
     * Get system instructions senders.
     * @return The list of system instructions senders.
     */
    function getSystemInstructionsSenders()
        external view
        returns (address[] memory);
}
