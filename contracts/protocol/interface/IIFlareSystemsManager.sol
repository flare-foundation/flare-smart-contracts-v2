// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IFlareSystemsManager.sol";

/**
 * FlareSystemsManager internal interface.
 */
interface IIFlareSystemsManager is IFlareSystemsManager {

    /// Event emitted when triggering voter registration fails.
    event TriggeringVoterRegistrationFailed(uint24 rewardEpochId);
    /// Event emitted when closing expired reward epoch fails.
    event ClosingExpiredRewardEpochFailed(uint24 rewardEpochId);
    /// Event emitted when setting clean-up block number fails.
    event SettingCleanUpBlockNumberFailed(uint64 blockNumber);

    /**
     * Uptime vote hash for given reward epoch id
     */
    function uptimeVoteHash(uint256 _rewardEpochId) external view returns (bytes32);

    /**
     * Rewards hash for given reward epoch id
     */
    function rewardsHash(uint256 _rewardEpochId) external view returns (bytes32);

    /**
     * Number of weight based claims for given reward epoch
     */
    function noOfWeightBasedClaims(uint256 _rewardEpochId) external view returns (uint256);

    /**
     * Maximum duration of random acquisition phase, in seconds.
     */
    function randomAcquisitionMaxDurationSeconds() external view returns (uint64);

    /**
     * Maximum duration of random acquisition phase, in blocks.
     */
    function randomAcquisitionMaxDurationBlocks() external view returns (uint64);

    /**
     * Time before reward epoch end when new signing policy initialization starts, in seconds.
     */
    function newSigningPolicyInitializationStartSeconds() external view returns (uint64);

    /**
     * Minimum delay before new signing policy can be active, in voting rounds.
     */
    function newSigningPolicyMinNumberOfVotingRoundsDelay() external view returns (uint32);

    /**
     * Reward epoch expiry offset, in seconds.
     */
    function rewardExpiryOffsetSeconds() external view returns (uint32);

    /**
     * Minimum duration of voter registration phase, in seconds.
     */
    function voterRegistrationMinDurationSeconds() external view returns (uint64);

    /**
     * Minimum duration of voter registration phase, in blocks.
     */
    function voterRegistrationMinDurationBlocks() external view returns (uint64);

    /**
     * Minimum duration of submit uptime vote phase, in seconds.
     */
    function submitUptimeVoteMinDurationSeconds() external view returns (uint64);

    /**
     * Minimum duration of submit uptime vote phase, in blocks.
     */
    function submitUptimeVoteMinDurationBlocks() external view returns (uint64);

    /**
     * Signing policy threshold, in parts per million.
     */
    function signingPolicyThresholdPPM() external view returns (uint24);

    /**
     * Minimum number of voters for signing policy.
     */
    function signingPolicyMinNumberOfVoters() external view returns (uint16);

    /**
     * Timestamp when current reward epoch should end, in seconds since UNIX epoch.
     */
    function currentRewardEpochExpectedEndTs() external view returns (uint64 _currentRewardEpochExpectedEndTs);

    /**
     * The last voting round id that was initialized.
     */
    function lastInitializedVotingRoundId() external view returns (uint32 _lastInitializedVotingRoundId);

    /**
     * The reward epoch id that will expire next.
     */
    function rewardEpochIdToExpireNext() external view returns (uint24 _rewardEpochIdToExpireNext);

    /**
     * Returns reward epoch start info.
     * @param _rewardEpochId Reward epoch id.
     * @return _rewardEpochStartTs Reward epoch start timestamp (0 if not started yet).
     * @return _rewardEpochStartBlock Reward epoch start block number (0 if not started yet).
     */
    function getRewardEpochStartInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _rewardEpochStartTs,
            uint64 _rewardEpochStartBlock
        );

    /**
     * Returns random acquisition info.
     * @param _rewardEpochId Reward epoch id.
     * @return _randomAcquisitionStartTs Random acquisition start timestamp (0 if not started yet).
     * @return _randomAcquisitionStartBlock Random acquisition start block number (0 if not started yet).
     * @return _randomAcquisitionEndTs Random acquisition end timestamp (0 if not ended yet).
     * @return _randomAcquisitionEndBlock Random acquisition end block number (0 if not ended yet).
     */
    function getRandomAcquisitionInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _randomAcquisitionStartTs,
            uint64 _randomAcquisitionStartBlock,
            uint64 _randomAcquisitionEndTs,
            uint64 _randomAcquisitionEndBlock
        );

    /**
     * Returns signing policy sign info for voter.
     * @param _rewardEpochId Reward epoch id.
     * @param _voter Voter address.
     * @return _signingPolicySignTs Timestamp when voter signed the signing policy (0 if not signed).
     * @return _signingPolicySignBlock Block number when voter signed the signing policy (0 if not signed).
     */
    function getVoterSigningPolicySignInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _signingPolicySignTs,
            uint64 _signingPolicySignBlock
        );

    /**
     * Returns signing policy sign info.
     * @param _rewardEpochId Reward epoch id.
     * @return _signingPolicySignStartTs Signing policy sign start timestamp (0 if not started yet).
     * @return _signingPolicySignStartBlock Signing policy sign start block number (0 if not started yet).
     * @return _signingPolicySignEndTs Signing policy sign end timestamp (0 if not ended yet).
     * @return _signingPolicySignEndBlock Signing policy sign end block number (0 if not ended yet).
     */
    function getSigningPolicySignInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _signingPolicySignStartTs,
            uint64 _signingPolicySignStartBlock,
            uint64 _signingPolicySignEndTs,
            uint64 _signingPolicySignEndBlock
        );

    /**
     * Returns voter's submit uptime vote info.
     * @param _rewardEpochId Reward epoch id.
     * @param _voter Voter address.
     * @return _uptimeVoteSubmitTs Timestamp when voter submitted the uptime vote (0 if not submitted).
     * @return _uptimeVoteSubmitBlock Block number when voter submitted the uptime vote (0 if not submitted).
     */
    function getVoterUptimeVoteSubmitInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _uptimeVoteSubmitTs,
            uint64 _uptimeVoteSubmitBlock
        );

    /**
     * Returns uptime vote sign info for voter.
     * @param _rewardEpochId Reward epoch id.
     * @param _voter Voter address.
     * @return _uptimeVoteSignTs Timestamp when voter signed the uptime vote (0 if not signed).
     * @return _uptimeVoteSignBlock Block number when voter signed the uptime vote (0 if not signed).
     */
    function getVoterUptimeVoteSignInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _uptimeVoteSignTs,
            uint64 _uptimeVoteSignBlock
        );

    /**
     * Returns uptime vote sign start info.
     * @param _rewardEpochId Reward epoch id.
     * @return _uptimeVoteSignStartTs Uptime vote sign start timestamp (0 if not started yet).
     * @return _uptimeVoteSignStartBlock Uptime vote sign start block number (0 if not started yet).
     */
    function getUptimeVoteSignStartInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _uptimeVoteSignStartTs,
            uint64 _uptimeVoteSignStartBlock
        );

    /**
     * Returns rewards sign info for voter.
     * @param _rewardEpochId Reward epoch id.
     * @param _voter Voter address.
     * @return _rewardsSignTs Timestamp when voter signed the rewards (0 if not signed).
     * @return _rewardsSignBlock Block number when voter signed the rewards (0 if not signed).
     */
    function getVoterRewardsSignInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _rewardsSignTs,
            uint64 _rewardsSignBlock
        );

    /**
     * Returns rewards sign info.
     * @param _rewardEpochId Reward epoch id.
     * @return _rewardsSignStartTs Rewards sign start timestamp (0 if not started yet).
     * @return _rewardsSignStartBlock Rewards sign start block number (0 if not started yet).
     * @return _rewardsSignEndTs Rewards sign end timestamp (0 if not ended yet).
     * @return _rewardsSignEndBlock Rewards sign end block number (0 if not ended yet).
     */
    function getRewardsSignInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _rewardsSignStartTs,
            uint64 _rewardsSignStartBlock,
            uint64 _rewardsSignEndTs,
            uint64 _rewardsSignEndBlock
        );
}
