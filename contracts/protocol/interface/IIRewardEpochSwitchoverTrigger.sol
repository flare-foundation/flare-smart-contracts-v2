// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


interface IIRewardEpochSwitchoverTrigger {

    function triggerRewardEpochSwitchover(
        uint24 _currentRewardEpochId,
        uint64 _currentRewardEpochExpectedEndTs,
        uint64 _rewardEpochDurationSeconds
    )
        external;
}
