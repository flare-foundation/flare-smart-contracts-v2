// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";
import "../ftdc/ITeeAvailabilityCheck.sol";

/**
 * TeeVerification interface.
 */
interface ITeeVerification {

    struct TeeAttestation {
        ITeeRegistry.TeeMachineWithAttestationData teeMachine;
        uint256 challenge;
    }

    event SettingsUpdated(
        uint256 availabilityCheckValidityDurationSeconds,
        uint256 challengeValidityDurationSeconds
    );

    event CosignersSet(
        address[] cosigners,
        uint64 cosignersThreshold
    );

    event TeeAttestationRequested(
        address indexed teeId,
        uint256 challenge
    );

    event AvailabilityCheckValidityExtended(
        address indexed teeId,
        address indexed owner,
        uint256 endTs
    );

    /**
     * Request attestation for a TEE machine.
     * @param _teeId The TEE machine id.
     */
    function requestTeeAttestation(
        address _teeId
    )
        external payable;

    /**
     * Request availability check attestation for a TEE machine.
     * @param _teeId The TEE machine id.
     * @param _testOnTeeId The TEE machine id to test on.
     */
    function requestAvailabilityCheckAttestation(
        address _teeId,
        address _testOnTeeId
    )
        external payable;

    /**
     * Extend the availability check validity.
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
        returns(bool _responseDataValid);

    /**
     * Returns the list of FTDC cosigners and their threshold used for the TEE machine registration.
     * @return _cosigners The list of cosigners.
     * @return _cosignersThreshold The cosigners threshold.
     */
    function getCosigners()
        external view
        returns(address[] memory _cosigners, uint64 _cosignersThreshold);


    /**
     * Returns the settings.
     * @return _availabilityCheckValidityDurationSeconds The availability check validity duration.
     * @return _challengeValidityDurationSeconds The challenge validity duration.
     */
    function getSettings()
        external view
        returns(
            uint256 _availabilityCheckValidityDurationSeconds,
            uint256 _challengeValidityDurationSeconds
        );
}
