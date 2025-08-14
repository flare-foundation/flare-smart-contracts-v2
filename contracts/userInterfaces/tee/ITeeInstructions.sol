// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeInstructions interface.
 */
interface ITeeInstructions {

    error OnlyInstructionInitiator();

    /**
     * Send instructions to the TEE machines.
     * @param _instructionId The instruction ID.
     * @param _teeIds The TEE machine IDs to which the instructions are sent.
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @param _message The message.
     * @param _cosigners The cosigners.
     * @param _cosignersThreshold The cosigners threshold.
     */
    function sendInstructions(
        bytes32 _instructionId,
        address[] memory _teeIds,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        external payable;

    /**
     * Returns the list of instruction initiator contracts.
     */
    function getInstructionInitiators() external view returns (address[] memory);
}