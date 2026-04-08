// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeVerificationFacet } from "../../userInterfaces/tee/ITeeVerificationFacet.sol";

/**
 * @title IITeeVerificationFacet
 * @notice Internal interface for the TeeVerificationFacet.
 * @dev Contains governance-only methods: setCosigners, updateSettings.
 */
interface IITeeVerificationFacet is ITeeVerificationFacet {

    /**
     * Sets the FDC2 cosigners and their threshold used for the TEE machine registration.
     * Emits CosignersSet event.
     * @param _cosigners The cosigners.
     * @param _cosignersThreshold The cosigners threshold.
     * Can only be called by the governance.
     */
    function setCosigners(
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external;

    /**
     * Update the settings of the TeeVerification.
     * Emits SettingsUpdated event.
     * @param _availabilityCheckValidityDurationSeconds The TEE availability check validity
     *        duration, in seconds.
     * @param _signingPolicyValidityDurationInRewardEpochs The signing policy validity duration,
     *        in reward epochs.
     * @param _challengeValidityDurationSeconds Challenge validity duration, in seconds.
     * Can only be called by the governance.
     */
    function updateSettings(
        uint64 _availabilityCheckValidityDurationSeconds,
        uint64 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds
    )
        external;
}
