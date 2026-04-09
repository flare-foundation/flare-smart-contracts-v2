// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IITeeVerificationFacet } from "../interface/IITeeVerificationFacet.sol";
import { ITeeVerificationFacet, TEE_SOURCE_ID } from "../../userInterfaces/tee/ITeeVerificationFacet.sol";
import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { ITeeMachineRegistryFacet, REG_OP_TYPE } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
import { TeeVerification } from "../library/TeeVerification.sol";
import { TeeMachineRegistry } from "../library/TeeMachineRegistry.sol";
import { TeeReplication } from "../library/TeeReplication.sol";
import { TeeExternalAddresses } from "../library/TeeExternalAddresses.sol";
import { TeeInstructionSender } from "../library/TeeInstructionSender.sol";
import { GovernedFacet } from "./GovernedFacet.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TeeVerificationFacet
 * @notice Facet for TEE machine attestation challenges and availability checks.
 */
contract TeeVerificationFacet is IITeeVerificationFacet, GovernedFacet {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant TEE_ATTESTATION = bytes32("TEE_ATTESTATION");

    /// @inheritdoc ITeeVerificationFacet
    function requestTeeAttestation(
        address _teeId,
        address _claimBackAddress
    )
        external payable
    {
        TeeVerification.State storage s = TeeVerification.getState();
        bytes32 challenge;
        if (s.challengeTs[_teeId] + s.challengeValidityDurationSeconds > block.timestamp) {
            challenge = s.challenges[_teeId];
        } else {
            (uint256 randomNumber,,) = IRelay(TeeExternalAddresses.getState().relay).getRandomNumber();
            challenge = keccak256(abi.encode(_teeId, block.timestamp, randomNumber));
            s.challenges[_teeId] = challenge;
            s.challengeTs[_teeId] = block.timestamp;
        }

        address attestingTeeId = _getAttestingTeeId(_teeId);

        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory teeMachineWithAttestationData =
            TeeMachineRegistry.getTeeMachineWithAttestationData(attestingTeeId);
        ITeeMachineRegistryFacet.TeeMachine memory teeMachine = TeeMachineRegistry.getTeeMachine(attestingTeeId);
        teeMachineWithAttestationData.teeId = _teeId;
        teeMachine.teeId = _teeId;

        TeeAttestation memory message = TeeAttestation({
            teeMachine: teeMachineWithAttestationData,
            challenge: challenge
        });
        ITeeMachineRegistryFacet.TeeMachine[] memory teeMachines =
            new ITeeMachineRegistryFacet.TeeMachine[](1);
        teeMachines[0] = teeMachine;

        TeeInstructionSender.sendInstructions(
            bytes32(0),
            teeMachines,
            ITeeExtensionRegistryFacet.TeeInstructionParams(
                REG_OP_TYPE,
                TEE_ATTESTATION,
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            )
        );
        emit TeeAttestationRequested(_teeId, challenge);
    }

    /// @inheritdoc ITeeVerificationFacet
    function requestAvailabilityCheckAttestation(
        address _teeId,
        bytes32 _instructionId,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable
    {
        TeeVerification.State storage s = TeeVerification.getState();
        require(
            s.challengeTs[_teeId] + s.challengeValidityDurationSeconds > block.timestamp,
            ChallengeExpired(s.challengeTs[_teeId])
        );
        address attestingTeeId = _getAttestingTeeId(_teeId);
        ITeeMachineRegistryFacet.TeeMachine memory teeMachine = TeeMachineRegistry.getTeeMachine(attestingTeeId);
        ITeeAvailabilityCheck.RequestBody memory requestBody = ITeeAvailabilityCheck.RequestBody({
            teeId: _teeId,
            teeProxyId: teeMachine.teeProxyId,
            url: teeMachine.url,
            challenge: s.challenges[_teeId],
            instructionId: _instructionId
        });

        address[] memory registrationCosigners = new address[](0);
        uint64 registrationCosignersThreshold = 0;
        ITeeMachineRegistryFacet.TeeStatus status = TeeMachineRegistry.getTeeMachineStatus(attestingTeeId);
        if (status == ITeeMachineRegistryFacet.TeeStatus.INITIALIZED ||
            status == ITeeMachineRegistryFacet.TeeStatus.REPLICATING)
        {
            registrationCosigners = s.cosigners.values();
            registrationCosignersThreshold = s.cosignersThreshold;
        }

        TeeVerification.requestFdc2Attestation(
            _testOnTeeId,
            registrationCosigners,
            registrationCosignersThreshold,
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            abi.encode(requestBody),
            _proofOwner,
            _claimBackAddress
        );
    }

    /// @inheritdoc ITeeVerificationFacet
    function confirmAvailability(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        TeeMachineRegistry.checkTeeMachineInProduction(teeId);
        TeeMachineRegistry.validateAvailabilityCheckStatus(_proof.responseBody.status);
        uint256 extensionId = TeeMachineRegistry.getExtensionId(teeId);
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory teeMachine =
            TeeMachineRegistry.getTeeMachineWithAttestationData(teeId);
        TeeMachineRegistry.checkCodeHashPlatformSupported(extensionId, teeMachine.codeHash, teeMachine.platform);
        require(
            TeeVerification.verifyAvailabilityCheckProof(
                teeMachine, ITeeMachineRegistryFacet.TeeStatus.PRODUCTION, _proof
            ),
            InvalidResponseData()
        );
        TeeVerification.extendAvailability(_proof);
    }

    /// @inheritdoc ITeeVerificationFacet
    function verifyAvailabilityCheckProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        returns (bool)
    {
        address teeId = _proof.requestBody.teeId;
        ITeeMachineRegistryFacet.TeeStatus status = TeeMachineRegistry.getTeeMachineStatus(teeId);
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory teeMachine =
            TeeMachineRegistry.getTeeMachineWithAttestationData(teeId);
        return TeeVerification.verifyAvailabilityCheckProof(teeMachine, status, _proof);
    }

    /// @inheritdoc IITeeVerificationFacet
    function setCosigners(
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external
        onlyGovernance
    {
        require(
            _cosigners.length >= _cosignersThreshold && (_cosigners.length == 0 || _cosignersThreshold > 0),
            InvalidThreshold()
        );
        TeeVerification.State storage s = TeeVerification.getState();
        address[] memory currentCosigners = s.cosigners.values();
        for (uint256 i = currentCosigners.length; i > 0; i--) {
            s.cosigners.remove(currentCosigners[i - 1]);
        }
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), InvalidCosigner(_cosigners[i]));
            require(s.cosigners.add(_cosigners[i]), DuplicatedCosigner(_cosigners[i]));
        }
        s.cosignersThreshold = _cosignersThreshold;
        emit CosignersSet(_cosigners, _cosignersThreshold);
    }

    /// @inheritdoc IITeeVerificationFacet
    function updateSettings(
        uint64 _availabilityCheckValidityDurationSeconds,
        uint64 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds
    )
        external
        onlyGovernance
    {
        TeeVerification.updateSettings(
            _availabilityCheckValidityDurationSeconds,
            _signingPolicyValidityDurationInRewardEpochs,
            _challengeValidityDurationSeconds
        );
    }

    // =========================================================================
    // Getters
    // =========================================================================

    /// @inheritdoc ITeeVerificationFacet
    function getCosigners()
        external view
        returns (
            address[] memory _cosigners,
            uint64 _cosignersThreshold
        )
    {
        TeeVerification.State storage s = TeeVerification.getState();
        _cosigners = s.cosigners.values();
        _cosignersThreshold = s.cosignersThreshold;
    }

    /// @inheritdoc ITeeVerificationFacet
    function getSettings()
        external view
        returns (
            uint256 _availabilityCheckValidityDurationSeconds,
            uint256 _challengeValidityDurationSeconds
        )
    {
        TeeVerification.State storage s = TeeVerification.getState();
        _availabilityCheckValidityDurationSeconds = s.availabilityCheckValidityDurationSeconds;
        _challengeValidityDurationSeconds = s.challengeValidityDurationSeconds;
    }

    /// @inheritdoc ITeeVerificationFacet
    function getAvailabilityCheckValidity(
        address _teeId
    )
        external view
        returns (
            uint64 _endTs,
            uint32 _lastSigningPolicyId
        )
    {
        return TeeVerification.getAvailabilityCheckValidity(_teeId);
    }

    // =========================================================================
    // Internal
    // =========================================================================

    function _getAttestingTeeId(
        address _teeId
    )
        private view
        returns (address _attestingTeeId)
    {
        _attestingTeeId = TeeReplication.getReplicatingTeeId(_teeId);
        if (_attestingTeeId == address(0)) {
            _attestingTeeId = _teeId;
        }
    }
}
