// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./LTS/RewardsV2Interface.sol";

/**
 * RewardManager interface.
 */
interface IRewardManager is RewardsV2Interface {

    /// Struct used for storing unclaimed reward data.
    struct UnclaimedRewardState {
        bool initialised;           // Information if already initialised
                                    // amount and weight might be 0 if all users already claimed
        uint120 amount;             // Total unclaimed amount.
        uint128 weight;             // Total unclaimed weight.
    }

    /**
     * Emitted when rewards are claimed.
     * @param beneficiary Address of the beneficiary (voter or node id) that accrued the reward.
     * @param rewardOwner Address that was eligible for the rewards.
     * @param recipient Address that received the reward.
     * @param rewardEpochId Id of the reward epoch where the reward was accrued.
     * @param claimType Claim type
     * @param amount Amount of rewarded native tokens (wei).
     */
    event RewardClaimed(
        address indexed beneficiary,
        address indexed rewardOwner,
        address indexed recipient,
        uint24 rewardEpochId,
        ClaimType claimType,
        uint120 amount
    );

    /**
     * Unclaimed rewards have expired and are now inaccessible.
     *
     * `getUnclaimedRewardState()` can be used to retrieve more information.
     * @param rewardEpochId Id of the reward epoch that has just expired.
     */
    event RewardClaimsExpired(uint256 indexed rewardEpochId);

    /**
     * Emitted when reward claims have been enabled.
     * @param rewardEpochId First claimable reward epoch.
     */
    event RewardClaimsEnabled(uint256 indexed rewardEpochId);

    /**
     * Claim rewards for `_rewardOwners` and their PDAs.
     * Rewards are deposited to the WNAT (to reward owner or PDA if enabled).
     * It can be called by reward owner or its authorized executor.
     * Only claiming from weight based claims is supported.
     * @param _rewardOwners Array of reward owners.
     * @param _rewardEpochId Id of the reward epoch up to which the rewards are claimed.
     * @param _proofs Array of reward claims with merkle proofs.
     */
    function autoClaim(
        address[] calldata _rewardOwners,
        uint24 _rewardEpochId,
        RewardClaimWithProof[] calldata _proofs
    )
        external;

    /**
     * Initialises weight based claims.
     * @param _proofs Array of reward claims with merkle proofs.
     */
    function initialiseWeightBasedClaims(RewardClaimWithProof[] calldata _proofs) external;

    /**
     * Returns the reward manager id.
     */
    function rewardManagerId() external view returns (uint256);

    /**
     * Returns the number of weight based claims that have been initialised.
     * @param _rewardEpochId Reward epoch id.
     */
    function noOfInitialisedWeightBasedClaims(uint256 _rewardEpochId) external view returns (uint256);

    /**
     * Get the current cleanup block number.
     * @return The currently set cleanup block number.
     */
    function cleanupBlockNumber() external view returns (uint256);

    /**
     * Returns the state of rewards for a given address at a specific reward epoch.
     * @param _rewardOwner Address of the reward owner.
     * @param _rewardEpochId Reward epoch id.
     * @return _rewardStates Array of reward states.
     */
    function getStateOfRewardsAt(
        address _rewardOwner,
        uint24 _rewardEpochId
    )
        external view
        returns (
            RewardState[] memory _rewardStates
        );

    /**
     * Gets the unclaimed reward state for a beneficiary, reward epoch id and claim type.
     * @param _beneficiary Address of the beneficiary to query.
     * @param _rewardEpochId Id of the reward epoch to query.
     * @param _claimType Claim type to query.
     * @return _state Unclaimed reward state.
     */
    function getUnclaimedRewardState(
        address _beneficiary,
        uint24 _rewardEpochId,
        ClaimType _claimType
    )
        external view
        returns (
            UnclaimedRewardState memory _state
        );

    /**
     * Returns totals.
     * @return _totalRewardsWei Total rewards (wei).
     * @return _totalInflationRewardsWei Total inflation rewards (wei).
     * @return _totalClaimedWei Total claimed rewards (wei).
     * @return _totalBurnedWei Total burned rewards (wei).
     */
    function getTotals()
        external view
        returns (
            uint256 _totalRewardsWei,
            uint256 _totalInflationRewardsWei,
            uint256 _totalClaimedWei,
            uint256 _totalBurnedWei
        );

    /**
     * Returns reward epoch totals.
     * @param _rewardEpochId Reward epoch id.
     * @return _totalRewardsWei Total rewards (inflation + community) for the epoch (wei).
     * @return _totalInflationRewardsWei Total inflation rewards for the epoch (wei).
     * @return _initialisedRewardsWei Initialised rewards of all claim types for the epoch (wei).
     * @return _claimedRewardsWei Claimed rewards for the epoch (wei).
     * @return _burnedRewardsWei Burned rewards for the epoch (wei).
     */
    function getRewardEpochTotals(uint24 _rewardEpochId)
        external view
        returns (
            uint256 _totalRewardsWei,
            uint256 _totalInflationRewardsWei,
            uint256 _initialisedRewardsWei,
            uint256 _claimedRewardsWei,
            uint256 _burnedRewardsWei
        );

     /**
     * Returns current reward epoch id.
     */
    function getCurrentRewardEpochId() external view returns (uint24);

    /**
     * Returns initial reward epoch id.
     */
    function getInitialRewardEpochId() external view returns (uint256);

    /**
     * Returns the reward epoch id that will expire next once a new reward epoch starts.
     */
    function getRewardEpochIdToExpireNext() external view returns (uint256);

    /**
     * The first reward epoch id that was claimable.
     */
    function firstClaimableRewardEpochId() external view returns (uint24);
}
