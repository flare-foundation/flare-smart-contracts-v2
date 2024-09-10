// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Protocols V2 long term support interface.
 */
interface ProtocolsV2Interface {

    /**
     * Timestamp when the first reward epoch started, in seconds since UNIX epoch.
     */
    function firstRewardEpochStartTs() external view returns (uint64);

    /**
     * Duration of reward epoch, in seconds.
     */
    function rewardEpochDurationSeconds() external view returns (uint64);

    /**
     * Timestamp when the first voting epoch started, in seconds since UNIX epoch.
     */
    function firstVotingRoundStartTs() external view returns (uint64);

    /**
     * Duration of voting epoch, in seconds.
     */
    function votingEpochDurationSeconds() external view returns (uint64);

    /**
     * Returns the vote power block for given reward epoch id.
     */
    function getVotePowerBlock(uint256 _rewardEpochId)
        external view
        returns(uint64 _votePowerBlock);

    /**
     * Returns the start voting round id for given reward epoch id.
     */
    function getStartVotingRoundId(uint256 _rewardEpochId)
        external view
        returns(uint32);

    /**
     * Returns the current reward epoch id.
     */
    function getCurrentRewardEpochId() external view returns(uint24);

    /**
     * Returns the current voting epoch id.
     */
    function getCurrentVotingEpochId() external view returns(uint32);

}