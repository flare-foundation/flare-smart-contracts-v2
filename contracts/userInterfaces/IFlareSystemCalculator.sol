// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


/**
 * FlareSystemCalculator interface.
 */
interface IFlareSystemCalculator {

    /// Event emitted when the registration weight of a voter is calculated.
    event VoterRegistrationInfo(
        address voter,
        uint24 rewardEpochId,
        uint256 wNatWeight,
        uint256 wNatCappedWeight,
        bytes20[] nodeIds,
        uint256[] nodeWeights,
        uint16 delegationFeeBIPS
    );

    /// WNat cap used in signing policy weight.
    function wNatCapPPM() external view returns (uint24);
    /// Non-punishable time to sign new signing policy.
    function signingPolicySignNonPunishableDurationSeconds() external view returns (uint64);
    /// Number of non-punishable blocks to sign new signing policy.
    function signingPolicySignNonPunishableDurationBlocks() external view returns (uint64);
    /// Number of blocks (in addition to non-punishable blocks) after which all rewards are burned.
    function signingPolicySignNoRewardsDurationBlocks() external view returns (uint64);

}
