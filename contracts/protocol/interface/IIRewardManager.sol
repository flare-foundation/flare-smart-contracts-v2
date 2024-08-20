// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IRewardManager.sol";


/**
 * RewardManager internal interface.
 */
interface IIRewardManager is IRewardManager {

    /**
     * Claim rewards for `_rewardOwner` and transfer them to `_recipient`.
     * It can be called only by FtsoRewardManagerProxy contract.
     * @param _msgSender Address of the message sender.
     * @param _rewardOwner Address of the reward owner.
     * @param _recipient Address of the reward recipient.
     * @param _rewardEpochId Id of the reward epoch up to which the rewards are claimed.
     * @param _wrap Indicates if the reward should be wrapped (deposited) to the WNAT contract.
     * @param _proofs Array of reward claims with merkle proofs.
     * @return _rewardAmountWei Amount of rewarded native tokens (wei).
     */
    function claimProxy(
        address _msgSender,
        address _rewardOwner,
        address payable _recipient,
        uint24 _rewardEpochId,
        bool _wrap,
        RewardClaimWithProof[] calldata _proofs
    )
        external
        returns (uint256 _rewardAmountWei);

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
