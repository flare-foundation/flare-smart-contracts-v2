// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { ITeeMachineRegistryFacet } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IIRewardManager } from "../../protocol/interface/IIRewardManager.sol";
import { TeeExtensionRegistry } from "./TeeExtensionRegistry.sol";
import { TeeMachineRegistry } from "./TeeMachineRegistry.sol";
import { TeeFeeCalculator } from "./TeeFeeCalculator.sol";
import { TeeExternalAddresses } from "./TeeExternalAddresses.sol";

/**
 * @title TeeInstructionSender
 * @notice Library for the core instruction-sending logic shared by TeeExtensionRegistryFacet
 *         and TeeVerificationFacet.
 * @dev Validates tee machines, calculates fee, sends fee to reward manager, emits event.
 *      Does NOT validate the caller (sender) — that is the responsibility of the calling facet.
 */
library TeeInstructionSender {

    function sendInstructions(
        bytes32 _instructionId,
        ITeeMachineRegistryFacet.TeeMachine[] memory _teeMachines,
        ITeeExtensionRegistryFacet.TeeInstructionParams memory _instructionParams
    )
        internal
        returns (bytes32)
    {
        require(_teeMachines.length > 0, ITeeExtensionRegistryFacet.NoTeeMachinesSpecified());
        require(_instructionParams.opType != bytes32(0), ITeeExtensionRegistryFacet.OperationTypeEmpty());
        require(_instructionParams.opCommand != bytes32(0), ITeeExtensionRegistryFacet.OperationCommandEmpty());
        require(_instructionParams.message.length > 0, ITeeExtensionRegistryFacet.MessageEmpty());
        require(
            _instructionParams.cosignersThreshold <= _instructionParams.cosigners.length,
            ITeeExtensionRegistryFacet.CosignersThresholdTooHigh()
        );

        uint256 extensionId;
        {
            address[] memory teeIds = new address[](_teeMachines.length);
            extensionId = TeeMachineRegistry.getExtensionId(_teeMachines[0].teeId);
            if (_instructionId == bytes32(0)) {
                _instructionId = TeeExtensionRegistry.generateInstructionId(extensionId);
            }

            bool isSystemOpType = TeeExtensionRegistry.isSystemOpType(_instructionParams.opType);
            for (uint256 i = 0; i < _teeMachines.length; i++) {
                address teeId = _teeMachines[i].teeId;
                require(
                    i == 0 || TeeMachineRegistry.getExtensionId(teeId) == extensionId,
                    ITeeCommonErrors.ExtensionIdMismatch()
                );
                if (!isSystemOpType) {
                    require(
                        TeeMachineRegistry.getTeeMachineStatus(teeId) ==
                            ITeeMachineRegistryFacet.TeeStatus.PRODUCTION,
                        ITeeCommonErrors.TeeMachineNotAvailable()
                    );
                }
                teeIds[i] = teeId;
            }

            uint256 calculatedFee = TeeFeeCalculator.calculateFeeByTeeIds(
                _instructionParams.opType, _instructionParams.opCommand, teeIds
            );
            require(calculatedFee <= msg.value, ITeeExtensionRegistryFacet.FeeTooLow());
        }

        // Send fee to reward manager and emit event
        TeeExternalAddresses.State storage ext = TeeExternalAddresses.getState();
        uint24 currentRewardEpochId = IFlareSystemsManager(ext.flareSystemsManager)
            .getCurrentRewardEpochId();
        IIRewardManager(ext.rewardManager).receiveRewards{value: msg.value}(
            currentRewardEpochId, false
        );

        emit ITeeExtensionRegistryFacet.TeeInstructionsSent(
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
        ITeeExtensionRegistryFacet.TeeInstructionParams memory _instructionParams
    )
        internal
        returns (bytes32)
    {
        ITeeMachineRegistryFacet.TeeMachine[] memory teeMachines =
            new ITeeMachineRegistryFacet.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = TeeMachineRegistry.getTeeMachine(_teeIds[i]);
        }
        return sendInstructions(_instructionId, teeMachines, _instructionParams);
    }
}
