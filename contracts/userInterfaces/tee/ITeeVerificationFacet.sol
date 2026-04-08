// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeMachineRegistryFacet } from "./ITeeMachineRegistryFacet.sol";
import { ITeeAvailabilityCheck } from "../fdc2/ITeeAvailabilityCheck.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

bytes32 constant TEE_SOURCE_ID = bytes32("TEE");

/**
 * @title ITeeVerificationFacet
 * @notice Public interface for the TeeVerificationFacet (machine verification).
 */
interface ITeeVerificationFacet is ITeeCommonErrors {

    struct TeeAttestation {
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData teeMachine;
        bytes32 challenge;
    }

    event SettingsUpdated(
        uint64 availabilityCheckValidityDurationSeconds,
        uint64 signingPolicyValidityDurationInRewardEpochs,
        uint64 challengeValidityDurationSeconds
    );

    event CosignersSet(
        address[] cosigners,
        uint64 cosignersThreshold
    );

    event TeeAttestationRequested(
        address indexed teeId,
        bytes32 challenge
    );

    event AvailabilityCheckValidityExtended(
        address indexed teeId,
        address indexed owner,
        uint256 endTs
    );

    error ChallengeExpired(uint256 challengeTs);
    error InvalidAttestation();
    error InvalidRequestBody();
    error InvalidSigningPolicy();
    error CosignersThresholdNotMet();

    /**
     * Request attestation for a TEE machine.
     * Emits TeeAttestationRequested event.
     * @param _teeId The TEE machine id.
     * @param _claimBackAddress An address that can claim back the fee if the instructions
     *        are not executed (optional).
     */
    function requestTeeAttestation(
        address _teeId,
        address _claimBackAddress
    )
        external payable;

    /**
     * Request availability check attestation for a TEE machine - triggers FDC2 availability check.
     * @param _teeId The TEE machine id.
     * @param _instructionId The instruction ID used for the TEE attestation check (challenge must match).
     * @param _testOnTeeId The TEE machine id to test on, if address(0) a random active TEE
     *        machine will be used.
     * @param _proofOwner The proof owner address (optional).
     * @param _claimBackAddress An address that can claim back the fee if the instructions
     *        are not executed (optional).
     */
    function requestAvailabilityCheckAttestation(
        address _teeId,
        bytes32 _instructionId,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable;

    /**
     * Extend the availability check validity.
     * Emits AvailabilityCheckValidityExtended event.
     * @param _proof The availability check proof.
     */
    function confirmAvailability(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Validate the availability check proof.
     * @param _proof The availability check proof.
     * @return _responseDataValid True if the response data is valid, false otherwise.
     */
    function verifyAvailabilityCheckProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        returns (bool _responseDataValid);

    /**
     * Returns the list of FDC2 cosigners and their threshold used for the TEE machine registration.
     * @return _cosigners The list of cosigners.
     * @return _cosignersThreshold The cosigners threshold.
     */
    function getCosigners()
        external view
        returns (
            address[] memory _cosigners,
            uint64 _cosignersThreshold
        );

    /**
     * Returns the settings.
     * @return _availabilityCheckValidityDurationSeconds The availability check validity duration.
     * @return _challengeValidityDurationSeconds The challenge validity duration.
     */
    function getSettings()
        external view
        returns (
            uint256 _availabilityCheckValidityDurationSeconds,
            uint256 _challengeValidityDurationSeconds
        );

    /**
     * Returns the availability check validity for a TEE machine.
     * @param _teeId The TEE machine id.
     * @return _endTs The end timestamp of the availability check validity.
     * @return _lastSigningPolicyId The last signing policy id.
     */
    function getAvailabilityCheckValidity(
        address _teeId
    )
        external view
        returns (
            uint64 _endTs,
            uint32 _lastSigningPolicyId
        );
}
