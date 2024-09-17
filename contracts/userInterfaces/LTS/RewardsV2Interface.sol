// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Rewards V2 long term support interface.
 */
interface RewardsV2Interface {

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
        uint24 rewardEpochId;
        bytes20 beneficiary; // c-chain address or node id (bytes20) in case of type MIRROR
        uint120 amount; // in wei
        ClaimType claimType;
        bool initialised;
    }

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
     * Indicates if the contract is active - claims are enabled.
     */
    function active() external view returns (bool);

    /**
     * Returns the start and the end of the reward epoch range for which the reward is claimable.
     * @return _startEpochId The oldest epoch id that allows reward claiming.
     * @return _endEpochId The newest epoch id that allows reward claiming.
     */
    function getRewardEpochIdsWithClaimableRewards()
        external view
        returns (
            uint24 _startEpochId,
            uint24 _endEpochId
        );

    /**
     * Returns the next claimable reward epoch for a reward owner.
     * @param _rewardOwner Address of the reward owner to query.
     */
    function getNextClaimableRewardEpochId(address _rewardOwner) external view returns (uint256);

    /**
     * Returns the state of rewards for a given address for all unclaimed reward epochs with claimable rewards.
     * @param _rewardOwner Address of the reward owner.
     * @return _rewardStates Array of reward states.
     */
    function getStateOfRewards(
        address _rewardOwner
    )
        external view
        returns (
            RewardState[][] memory _rewardStates
        );

}