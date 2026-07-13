// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IIVerification } from "../interface/IIVerification.sol";
import { IVerification, TEE_SOURCE_ID } from "../../userInterfaces/tee/IVerification.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { Verification } from "../library/Verification.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { FlareGovernedAccess } from "../../governance/implementation/FlareGovernedAccess.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title VerificationFacet
 * @notice Facet for TEE machine attestation and availability checks.
 */
contract VerificationFacet is IIVerification, FlareGovernedAccess {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IVerification
    function requestTeeAttestation(
        address _teeId,
        address _claimBackAddress
    )
        external payable
    {
        Verification.requestTeeAttestation(_teeId, _claimBackAddress);
    }

    /// @inheritdoc IVerification
    function requestAvailabilityCheckAttestation(
        address _teeId,
        bytes32 _instructionId,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable
    {
        Verification.State storage s = Verification.getState();
        require(
            s.challengeTs[_teeId] + s.challengeValidityDurationSeconds > block.timestamp,
            ChallengeExpired(s.challengeTs[_teeId])
        );
        IMachineManager.TeeMachine memory teeMachine = MachineManager.getTeeMachine(_teeId);
        ITeeAvailabilityCheck.RequestBody memory requestBody = ITeeAvailabilityCheck.RequestBody({
            teeId: _teeId,
            teeProxyId: teeMachine.teeProxyId,
            url: teeMachine.url,
            challenge: s.challenges[_teeId],
            instructionId: _instructionId
        });

        address[] memory registrationCosigners = new address[](0);
        uint64 registrationCosignersThreshold = 0;
        IMachineManager.TeeStatus status = MachineManager.getTeeMachineStatus(_teeId);
        if (status == IMachineManager.TeeStatus.INITIALIZED) {
            registrationCosigners = s.cosigners.values();
            registrationCosignersThreshold = s.cosignersThreshold;
        }

        Verification.requestFdc2Attestation(
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

    /// @inheritdoc IVerification
    function confirmAvailability(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        MachineManager.checkTeeMachineInProduction(teeId);
        MachineManager.validateAvailabilityCheckStatus(_proof.responseBody.status);
        uint256 extensionId = MachineManager.getExtensionId(teeId);
        IMachineManager.TeeMachineWithAttestationData memory teeMachine =
            MachineManager.getTeeMachineWithAttestationData(teeId);
        MachineManager.checkCodeHashPlatformSupported(extensionId, teeMachine.codeHash, teeMachine.platform);
        require(
            Verification.verifyAvailabilityCheckProof(
                teeMachine, IMachineManager.TeeStatus.PRODUCTION, _proof
            ),
            InvalidResponseData()
        );
        Verification.extendAvailability(_proof);
    }

    /// @inheritdoc IIVerification
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
        Verification.State storage s = Verification.getState();
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

    /// @inheritdoc IIVerification
    function updateSettings(
        uint64 _availabilityCheckValidityDurationSeconds,
        uint64 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds
    )
        external
        onlyGovernance
    {
        Verification.updateSettings(
            _availabilityCheckValidityDurationSeconds,
            _signingPolicyValidityDurationInRewardEpochs,
            _challengeValidityDurationSeconds
        );
    }

    // =========================================================================
    // Getters
    // =========================================================================

    /// @inheritdoc IVerification
    function getCosigners()
        external view
        returns (
            address[] memory _cosigners,
            uint64 _cosignersThreshold
        )
    {
        Verification.State storage s = Verification.getState();
        _cosigners = s.cosigners.values();
        _cosignersThreshold = s.cosignersThreshold;
    }

    /// @inheritdoc IVerification
    function getSettings()
        external view
        returns (
            uint256 _availabilityCheckValidityDurationSeconds,
            uint256 _challengeValidityDurationSeconds
        )
    {
        Verification.State storage s = Verification.getState();
        _availabilityCheckValidityDurationSeconds = s.availabilityCheckValidityDurationSeconds;
        _challengeValidityDurationSeconds = s.challengeValidityDurationSeconds;
    }

    /// @inheritdoc IVerification
    function getAvailabilityCheckValidity(
        address _teeId
    )
        external view
        returns (
            uint64 _endTs,
            uint32 _lastSigningPolicyId
        )
    {
        return Verification.getAvailabilityCheckValidity(_teeId);
    }
}
