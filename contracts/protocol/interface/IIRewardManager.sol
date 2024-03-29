// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IRewardManager.sol";


/**
 * RewardManager internal interface.
 */
interface IIRewardManager is IRewardManager {

    /**
     * Receives funds from reward offers manager.
     * @param _rewardEpochId ID of the reward epoch for which the funds are received.
     * @param _inflation Indicates if the funds come from the inflation (true) or from the community (false).
     * @dev Only reward offers manager can call this method.
     */
    function receiveRewards(
        uint24 _rewardEpochId,
        bool _inflation
    )
        external payable;

    /**
     * Collects funds from expired reward epoch and calculates totals.
     *
     * Triggered by FlareSystemsManager on finalization of a reward epoch.
     * Operation is irreversible: when some reward epoch is closed according to current
     * settings, it cannot be reopened even if new parameters would
     * allow it, because `nextRewardEpochIdToExpire` in FlareSystemsManager never decreases.
     * @param _rewardEpochId Id of the reward epoch to close.
     */
    function closeExpiredRewardEpoch(uint256 _rewardEpochId) external;

}
