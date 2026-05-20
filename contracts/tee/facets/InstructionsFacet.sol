// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIInstructions } from "../interface/IIInstructions.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IExtensionManager } from "../../userInterfaces/tee/IExtensionManager.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { Instructions } from "../library/Instructions.sol";
import { FlareGovernedAccess } from "../../governance/implementation/FlareGovernedAccess.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title InstructionsFacet
 * @notice Facet for TEE instruction routing and system instructions sender management.
 */
contract InstructionsFacet is IIInstructions, FlareGovernedAccess {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IInstructions
    function sendInstructions(
        address[] memory _teeIds,
        TeeInstructionParams memory _instructionParams
    )
        external payable
        returns (bytes32)
    {
        Instructions.removeDuplicates(_teeIds);
        IMachineManager.TeeMachine[] memory teeMachines =
            new IMachineManager.TeeMachine[](_teeIds.length);
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

    /// @inheritdoc IIInstructions
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
        IMachineManager.TeeMachine[] memory teeMachines =
            new IMachineManager.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = MachineManager.getTeeMachine(_teeIds[i]);
        }
        return Instructions.sendInstructions(_instructionId, teeMachines, _instructionParams);
    }

    /// @inheritdoc IIInstructions
    function sendSystemInstructions(
        bytes32 _instructionId,
        IMachineManager.TeeMachine[] memory _teeMachines,
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

    /// @inheritdoc IIInstructions
    function registerSystemInstructionsSenders(
        address[] calldata _instructionsSenders
    )
        external
        onlyGovernance
    {
        Instructions.State storage s = Instructions.getState();
        for (uint256 i = 0; i < _instructionsSenders.length; ++i) {
            require(_instructionsSenders[i] != address(0), IExtensionManager.InvalidInstructionsSender());
            require(
                s.systemInstructionsSenders.add(_instructionsSenders[i]),
                SystemInstructionsSenderAlreadyExists(_instructionsSenders[i])
            );
        }
        emit SystemInstructionsSendersRegistered(_instructionsSenders);
    }

    /// @inheritdoc IIInstructions
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

    /// @inheritdoc IInstructions
    function getSystemInstructionsSenders()
        external view
        returns (address[] memory)
    {
        return Instructions.getState().systemInstructionsSenders.values();
    }
}
