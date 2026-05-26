// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IMachineEmergencyPause } from "../../userInterfaces/tee/IMachineEmergencyPause.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IIRewardManager } from "../../protocol/interface/IIRewardManager.sol";
import { MachineEmergencyPause } from "./MachineEmergencyPause.sol";
import { MachineManager } from "./MachineManager.sol";
import { OperationFees } from "./OperationFees.sol";
import { ExternalAddresses } from "./ExternalAddresses.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Instructions
 * @notice Library for the core instruction-sending logic.
 * @dev Validates tee machines, calculates fee, sends fee to reward manager, emits event.
 *      Does NOT validate the caller (sender) — that is the responsibility of the calling facet.
 *      Also manages system instructions senders and instruction ID generation.
 */
library Instructions {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:storage-location erc7201:tee.Instructions.State
    struct State {
        /// List of system instructions sender contracts.
        EnumerableSet.AddressSet systemInstructionsSenders;
        /// Instruction IDs counter per extension ID.
        mapping(uint256 extensionId => uint256 counter) instructionIdsCounter;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.Instructions.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// Prefix reserved for system-owned extension.
    bytes2 internal constant SYSTEM_OP_TYPE_PREFIX = bytes2("F_");

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }

    function isSystemInstructionsSender(
        address _sender
    )
        internal view
        returns (bool)
    {
        return getState().systemInstructionsSenders.contains(_sender);
    }

    function isSystemOpType(
        bytes32 _opType
    )
        internal pure
        returns (bool)
    {
        return _opType[0] == SYSTEM_OP_TYPE_PREFIX[0] && _opType[1] == SYSTEM_OP_TYPE_PREFIX[1];
    }

    function generateInstructionId(
        uint256 _extensionId
    )
        internal
        returns (bytes32)
    {
        State storage s = getState();
        uint256 counter = s.instructionIdsCounter[_extensionId]++;
        return keccak256(abi.encode(_extensionId, counter, blockhash(block.number - 1)));
    }

    function removeDuplicates(
        address[] memory _teeIds
    )
        internal pure
    {
        uint256 length = _teeIds.length;
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (_teeIds[i] == _teeIds[j]) {
                    _teeIds[j] = _teeIds[length - 1];
                    length--;
                    j--;
                }
            }
        }
        // solhint-disable-next-line no-inline-assembly
        assembly { mstore(_teeIds, length) }
    }

    function sendInstructions(
        bytes32 _instructionId,
        IMachineManager.TeeMachine[] memory _teeMachines,
        IInstructions.TeeInstructionParams memory _instructionParams
    )
        internal
        returns (bytes32)
    {
        require(_teeMachines.length > 0, IInstructions.NoTeeMachinesSpecified());
        require(_instructionParams.opType != bytes32(0), IInstructions.OperationTypeEmpty());
        require(_instructionParams.opCommand != bytes32(0), IInstructions.OperationCommandEmpty());
        require(_instructionParams.message.length > 0, IInstructions.MessageEmpty());
        require(
            _instructionParams.cosignersThreshold <= _instructionParams.cosigners.length,
            IInstructions.CosignersThresholdTooHigh()
        );

        uint256 extensionId;
        {
            address[] memory teeIds = new address[](_teeMachines.length);
            extensionId = MachineManager.getExtensionId(_teeMachines[0].teeId);
            // Block every dispatch path (regular + system opTypes) when the destination
            // extension is in emergency pause. All machines are validated below to share
            // this extensionId, so a single check covers the whole batch.
            require(
                !MachineEmergencyPause.isExtensionEmergencyPaused(extensionId),
                IMachineEmergencyPause.EmergencyPauseActive(extensionId)
            );
            if (_instructionId == bytes32(0)) {
                _instructionId = generateInstructionId(extensionId);
            }

            bool _isSystemOpType = isSystemOpType(_instructionParams.opType);
            for (uint256 i = 0; i < _teeMachines.length; i++) {
                address teeId = _teeMachines[i].teeId;
                require(
                    i == 0 || MachineManager.getExtensionId(teeId) == extensionId,
                    ITeeCommonErrors.ExtensionIdMismatch()
                );
                if (!_isSystemOpType) {
                    require(
                        MachineManager.getTeeMachineStatus(teeId) ==
                            IMachineManager.TeeStatus.PRODUCTION,
                        ITeeCommonErrors.TeeMachineNotAvailable()
                    );
                }
                teeIds[i] = teeId;
            }

            uint256 calculatedFee = OperationFees.calculateFeeByTeeIds(
                _instructionParams.opType, _instructionParams.opCommand, teeIds
            );
            require(calculatedFee <= msg.value, IInstructions.FeeTooLow());
        }

        // Send fee to reward manager and emit event
        ExternalAddresses.State storage ext = ExternalAddresses.getState();
        uint24 currentRewardEpochId = IFlareSystemsManager(ext.flareSystemsManager)
            .getCurrentRewardEpochId();
        IIRewardManager(ext.rewardManager).receiveRewards{value: msg.value}(
            currentRewardEpochId, false
        );

        emit IInstructions.TeeInstructionsSent(
            extensionId,
            _instructionId,
            uint32(currentRewardEpochId),
            _teeMachines,
            _instructionParams.opType,
            _instructionParams.opCommand,
            _instructionParams.message,
            _instructionParams.cosigners,
            _instructionParams.cosignersThreshold,
            _instructionParams.claimBackAddress,
            msg.value
        );

        return _instructionId;
    }

    /**
     * Convenience overload that accepts TEE IDs and resolves TeeMachine data internally.
     */
    function sendInstructions(
        bytes32 _instructionId,
        address[] memory _teeIds,
        IInstructions.TeeInstructionParams memory _instructionParams
    )
        internal
        returns (bytes32)
    {
        IMachineManager.TeeMachine[] memory teeMachines =
            new IMachineManager.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = MachineManager.getTeeMachine(_teeIds[i]);
        }
        return sendInstructions(_instructionId, teeMachines, _instructionParams);
    }
}
