// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


interface IIRewardEpochSwitchoverTrigger {

    /**
     * Trigger the reward epoch switchover.
     * @param _currentRewardEpochId The current reward epoch id.
     * @param _currentRewardEpochExpectedEndTs The current reward epoch expected end timestamp.
     * @param _rewardEpochDurationSeconds The reward epoch duration in seconds (global setting).
     */
    function triggerRewardEpochSwitchover(
        uint24 _currentRewardEpochId,
        uint64 _currentRewardEpochExpectedEndTs,
        uint64 _rewardEpochDurationSeconds
    )
        external;
}
