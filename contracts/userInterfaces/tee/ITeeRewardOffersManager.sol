// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeRewardOffersManager interface.
 */
interface ITeeRewardOffersManager {

    /// Event emitted when inflation rewards are offered.
    event InflationRewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // amount (in wei) of reward in native coin
        uint256 amount,
        // part of the rewards that goes to the TEE owners
        uint256 teeOwnersPPM
    );

    /// Event emitted when the part of the rewards that goes to the TEE owners is set.
    event TeeOwnersPPMSet(
        // part of the rewards that goes to the TEE owners
        uint24 teeOwnersPPM
    );

    error InvalidTeeOwnersPPMValue();
}
