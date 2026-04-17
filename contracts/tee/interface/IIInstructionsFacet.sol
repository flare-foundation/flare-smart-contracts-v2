// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IInstructionsFacet } from "../../userInterfaces/tee/IInstructionsFacet.sol";
import { IMachineManagerFacet } from "../../userInterfaces/tee/IMachineManagerFacet.sol";

/**
 * @title IIInstructionsFacet
 * @notice Internal interface for the InstructionsFacet.
 * @dev Extends the public interface with governance-only methods and methods
 *      called by external contracts outside the Diamond (e.g. Fdc2Hub, TeePayments).
 */
interface IIInstructionsFacet is IInstructionsFacet {

    /**
     * Send instructions to the TEE machines - same as sendInstructions but with instruction ID
     * (might be bytes32(0)).
     * Emits TeeInstructionsSent event.
     * @param _instructionId The instruction ID - auto generated in case of bytes32(0).
     * @param _teeIds The TEE machine IDs to which the instructions are sent
     *        (must all belong to the same extension).
     * @param _instructionParams The instruction parameters.
     * @return The instruction ID.
     * Can only be called by the system instructions senders.
     * @dev No check for duplicated TEE machines is performed.
     */
    function sendSystemInstructions(
        bytes32 _instructionId,
        address[] memory _teeIds,
        TeeInstructionParams memory _instructionParams
    )
        external payable
        returns (bytes32);

    /**
     * Send instructions to the TEE machines - same as sendSystemInstructions but with full TEE
     * machine data provided.
     * Emits TeeInstructionsSent event.
     * @param _instructionId The instruction ID - auto generated in case of bytes32(0).
     * @param _teeMachines The TEE machines to which the instructions are sent
     *        (must all belong to the same extension).
     * @param _instructionParams The instruction parameters.
     * @return The instruction ID.
     * Can only be called by the system instructions senders.
     * @dev No check for duplicated TEE machines is performed.
     */
    function sendSystemInstructions(
        bytes32 _instructionId,
        IMachineManagerFacet.TeeMachine[] memory _teeMachines,
        TeeInstructionParams memory _instructionParams
    )
        external payable
        returns (bytes32);

    /**
     * Register system instructions sender contracts.
     * Emits SystemInstructionsSendersRegistered event.
     * @param _instructionsSenders List of contracts to register.
     * @dev Only governance can call this method.
     */
    function registerSystemInstructionsSenders(
        address[] calldata _instructionsSenders
    )
        external;

    /**
     * Unregister system instructions sender contracts.
     * Emits SystemInstructionsSendersUnregistered event.
     * @param _instructionsSenders List of contracts to unregister.
     * @dev Only governance can call this method.
     */
    function unregisterSystemInstructionsSenders(
        address[] calldata _instructionsSenders
    )
        external;
}
