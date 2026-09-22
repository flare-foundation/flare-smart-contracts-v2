// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

/**
 * FlareSystemsCalculator interface.
 */
interface IFlareSystemsCalculator {

    /// Event emitted when the registration weight of a voter is calculated.
    event VoterRegistrationInfo(
        address indexed voter,
        uint32 indexed rewardEpochId,
        address delegationAddress,
        uint16 delegationFeeBIPS,
        uint256 wNatWeight,
        uint256 wNatCappedWeight,
        bytes20[] nodeIds,
        uint256[] nodeWeights
    );

    /// Event emitted when the WNat cap is set.
    event WNatCapPPMSet(uint24 wNatCapPPM);

    /// Event emitted when the signing policy sign phase durations are set.
    event SigningPolicySignDurationsSet(
        uint64 signingPolicySignNonPunishableDurationSeconds,
        uint64 signingPolicySignNonPunishableDurationBlocks,
        uint64 signingPolicySignNoRewardsDurationBlocks
    );

    /// Event emitted when the staking factor is set.
    event StakingFactorSet(uint16 stakingFactor);

    /// Event emitted when the P-Chain stakes mirror is enabled.
    event PChainStakeMirrorEnabled();

    /// Reverts when the provided WNat cap exceeds 100% (PPM_MAX).
    error WNatCapPPMTooHigh();
    /// Reverts when the caller is not the VoterRegistry contract.
    error OnlyVoterRegistry();
    /// Reverts when the staking factor is updated while voter registration is enabled.
    error VoterRegistrationEnabled();
    /// Reverts when the burn factor is queried for an epoch whose signing policy has not been signed yet.
    error SigningPolicyNotSignedYet();

    /// WNat cap used in signing policy weight.
    function wNatCapPPM() external view returns (uint24);
    /// Non-punishable time to sign new signing policy.
    function signingPolicySignNonPunishableDurationSeconds() external view returns (uint64);
    /// Number of non-punishable blocks to sign new signing policy.
    function signingPolicySignNonPunishableDurationBlocks() external view returns (uint64);
    /// Number of blocks (in addition to non-punishable blocks) after which all rewards are burned.
    function signingPolicySignNoRewardsDurationBlocks() external view returns (uint64);
    /// Multiplier applied to node staking weights when computing registration weight.
    function stakingFactor() external view returns (uint16);

}
