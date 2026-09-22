// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IIInstructions } from "../interface/IIInstructions.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IExtensionManager } from "../../userInterfaces/tee/IExtensionManager.sol";
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
        // Validate sender for non-system callers
        require(_teeIds.length > 0, NoTeeMachinesSpecified());
        uint256 extensionId = MachineManager.getExtensionId(_teeIds[0]);
        if (!Instructions.isSystemInstructionsSender(msg.sender)) {
            require(
                msg.sender == ExtensionManager.getExtensionInstructionsSender(extensionId),
                OnlyInstructionsSender()
            );
            require(
                !Instructions.isSystemOpType(_instructionParams.opType),
                SystemOpTypeNotAllowed(_instructionParams.opType)
            );
        }
        return Instructions.sendInstructions(bytes32(0), _teeIds, _instructionParams);
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
        return Instructions.sendInstructions(_instructionId, _teeIds, _instructionParams);
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
