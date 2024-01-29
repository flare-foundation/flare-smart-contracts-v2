// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * RewardManager interface.
 */
interface IRewardManager {

    /// Claim type enum.
    enum ClaimType { DIRECT, FEE, WNAT, MIRROR, CCHAIN }

    /// Struct used for claiming rewards with Merkle proof.
    struct RewardClaimWithProof {
        bytes32[] merkleProof;
        RewardClaim body;
    }

    /// Struct used in Merkle tree for storing reward claims.
    struct RewardClaim {
        uint24 rewardEpochId;
        bytes20 beneficiary; // c-chain address or node id (bytes20) in case of type MIRROR
        uint120 amount; // in wei
        ClaimType claimType;
    }

    /// Struct used for returning state of rewards.
    struct RewardState {
        bytes20 beneficiary; // c-chain address or node id (bytes20) in case of type MIRROR
        uint120 amount; // in wei
        ClaimType claimType;
        bool initialised;
    }

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
     * Claim rewards for `_rewardOwner` and transfer them to `_recipient`.
     * It can be called by reward owner or its authorized executor.
     * @param _rewardOwner Address of the reward owner.
     * @param _recipient Address of the reward recipient.
     * @param _rewardEpochId Id of the reward epoch up to which the rewards are claimed.
     * @param _wrap Indicates if the reward should be wrapped (deposited) to the WNAT contract.
     * @param _proofs Array of reward claims with merkle proofs.
     * @return _rewardAmountWei Amount of rewarded native tokens (wei).
     */
    function claim(
        address _rewardOwner,
        address payable _recipient,
        uint24 _rewardEpochId,
        bool _wrap,
        RewardClaimWithProof[] calldata _proofs
    )
        external
        returns (uint256 _rewardAmountWei);

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
        * Indicates if the contract is active - claims are enabled.
        */
    function active() external view returns (bool);

    /**
     * Get the current cleanup block number.
     * @return The currently set cleanup block number.
     */
    function cleanupBlockNumber() external view returns (uint256);

    /**
     * Returns the state of rewards for a given address at a specific reward epoch.
     * @param _rewardOwner Address of the reward owner.
     * @param _rewardEpochId Id of the reward epoch.
     * @return _rewardStates Array of reward states.
     */
    function getStateOfRewards(
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
     * Returns the start and the end of the reward epoch range for which the reward is claimable.
     * **NOTE**: If rewards hash was not signed yet, some epoch might not be claimable.
     * @return _startEpochId The oldest epoch id that allows reward claiming.
     * @return _endEpochId The newest epoch id that allows reward claiming.
     */
    function getEpochIdsWithClaimableRewards()
        external view
        returns (
            uint256 _startEpochId,
            uint256 _endEpochId
        );

    /**
     * Returns totals.
     * @return _totalFundsReceivedWei Total amount of funds ever received (wei).
     * @return _totalClaimedWei Total claimed amount (wei).
     * @return _totalBurnedWei Total burned amount (wei).
     * @return _totalInflationAuthorizedWei Total inflation authorized amount (wei).
     * @return _totalInflationReceivedWei Total inflation received amount (wei).
     */
    function getTotals()
        external view
        returns (
            uint256 _totalFundsReceivedWei,
            uint256 _totalClaimedWei,
            uint256 _totalBurnedWei,
            uint256 _totalInflationAuthorizedWei,
            uint256 _totalInflationReceivedWei
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

    /**
     * Returns the next claimable reward epoch for a reward owner.
     * @param _rewardOwner Address of the reward owner to query.
     */
    function nextClaimableRewardEpochId(address _rewardOwner) external view returns (uint256);
}
