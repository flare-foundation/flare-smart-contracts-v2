// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIInstructionsFacet } from "../interface/IIInstructionsFacet.sol";
import { IInstructionsFacet } from "../../userInterfaces/tee/IInstructionsFacet.sol";
import { IExtensionManagerFacet } from "../../userInterfaces/tee/IExtensionManagerFacet.sol";
import { IMachineManagerFacet } from "../../userInterfaces/tee/IMachineManagerFacet.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { Instructions } from "../library/Instructions.sol";
import { GovernedFacet } from "./GovernedFacet.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title InstructionsFacet
 * @notice Facet for TEE instruction routing and system instructions sender management.
 */
contract InstructionsFacet is IIInstructionsFacet, GovernedFacet {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IInstructionsFacet
    function sendInstructions(
        address[] memory _teeIds,
        TeeInstructionParams memory _instructionParams
    )
        external payable
        returns (bytes32)
    {
        Instructions.removeDuplicates(_teeIds);
        IMachineManagerFacet.TeeMachine[] memory teeMachines =
            new IMachineManagerFacet.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = MachineManager.getTeeMachine(_teeIds[i]);
        }
        // Validate sender for non-system callers
        require(teeMachines.length > 0, NoTeeMachinesSpecified());
        uint256 extensionId = MachineManager.getExtensionId(teeMachines[0].teeId);
        if (!Instructions.isSystemInstructionsSender(msg.sender)) {
            require(
                msg.sender == ExtensionManager.getExtensionInstructionsSender(extensionId),
                OnlyInstructionsSender()
            );
            require(
                extensionId == 0 || !Instructions.isSystemOpType(_instructionParams.opType),
                SystemOpTypeNotAllowed(_instructionParams.opType)
            );
        }
        return Instructions.sendInstructions(bytes32(0), teeMachines, _instructionParams);
    }

    /// @inheritdoc IIInstructionsFacet
    function sendSystemInstructions(
        bytes32 _instructionId,
        address[] memory _teeIds,
        TeeInstructionParams memory _instructionParams
    )
        external payable
        returns (bytes32)
    {
        require(
            Instructions.isSystemInstructionsSender(msg.sender),
            OnlySystemInstructionsSender()
        );
        Instructions.removeDuplicates(_teeIds);
        IMachineManagerFacet.TeeMachine[] memory teeMachines =
            new IMachineManagerFacet.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = MachineManager.getTeeMachine(_teeIds[i]);
        }
        return Instructions.sendInstructions(_instructionId, teeMachines, _instructionParams);
    }

    /// @inheritdoc IIInstructionsFacet
    function sendSystemInstructions(
        bytes32 _instructionId,
        IMachineManagerFacet.TeeMachine[] memory _teeMachines,
        TeeInstructionParams memory _instructionParams
    )
        external payable
        returns (bytes32)
    {
        require(
            Instructions.isSystemInstructionsSender(msg.sender),
            OnlySystemInstructionsSender()
        );
        return Instructions.sendInstructions(_instructionId, _teeMachines, _instructionParams);
    }

    /// @inheritdoc IIInstructionsFacet
    function registerSystemInstructionsSenders(
        address[] calldata _instructionsSenders
    )
        external
        onlyGovernance
    {
        Instructions.State storage s = Instructions.getState();
        for (uint256 i = 0; i < _instructionsSenders.length; ++i) {
            require(_instructionsSenders[i] != address(0), IExtensionManagerFacet.InvalidInstructionsSender());
            require(
                s.systemInstructionsSenders.add(_instructionsSenders[i]),
                SystemInstructionsSenderAlreadyExists(_instructionsSenders[i])
            );
        }
        emit SystemInstructionsSendersRegistered(_instructionsSenders);
    }

    /// @inheritdoc IIInstructionsFacet
    function unregisterSystemInstructionsSenders(
        address[] calldata _instructionsSenders
    )
        external
        onlyGovernance
    {
        Instructions.State storage s = Instructions.getState();
        for (uint256 i = 0; i < _instructionsSenders.length; ++i) {
            require(
                s.systemInstructionsSenders.remove(_instructionsSenders[i]),
                SystemInstructionsSenderNotFound(_instructionsSenders[i])
            );
        }
        emit SystemInstructionsSendersUnregistered(_instructionsSenders);
    }

    // =========================================================================
    // Getters
    // =========================================================================

    /// @inheritdoc IInstructionsFacet
    function getSystemInstructionsSenders()
        external view
        returns (address[] memory)
    {
        return Instructions.getState().systemInstructionsSenders.values();
    }
}
