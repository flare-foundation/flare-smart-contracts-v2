// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * VoterRegistry interface.
 */
interface IVoterRegistry {

    /// Signature data.
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// Event emitted when a voter is chilled.
    event VoterChilled(address voter, uint256 untilRewardEpochId);

    /// Event emitted when a voter is removed.
    event VoterRemoved(address voter, uint256 rewardEpochId);

    /// Event emitted when a voter is registered.
    event VoterRegistered(
        address voter,
        uint24 rewardEpochId,
        address signingPolicyAddress,
        address delegationAddress,
        address submitAddress,
        address submitSignaturesAddress,
        uint256 registrationWeight
    );

    /**
     * Registers a voter if the weight is high enough.
     * @param _voter The voter address.
     * @param _signature The signature.
     */
    function registerVoter(address _voter, Signature calldata _signature) external;

    /**
     * Maximum number of voters in one reward epoch.
     */
    function maxVoters() external view returns (uint256);

    /**
     * In case of providing bad votes (e.g. ftso collusion), the voter can be chilled for a few reward epochs.
     * A voter can register again from a returned reward epoch onwards.
     * @param _voter The voter address.
     * @return _rewardEpochId The reward epoch id until which the voter is chilled.
     */
    function chilledUntilRewardEpochId(address _voter) external view returns (uint256 _rewardEpochId);

    /**
     * Returns the list of registered voters for a given reward epoch.
     * List can be empty if the reward epoch is not supported (before initial reward epoch or future reward epoch).
     * List for the next reward epoch can still change until the signing policy snapshot is created.
     * @param _rewardEpochId The reward epoch id.
     */
    function getRegisteredVoters(uint256 _rewardEpochId) external view returns (address[] memory);

    /**
     * Returns the number of registered voters for a given reward epoch.
     * Size can be zero if the reward epoch is not supported (before initial reward epoch or future reward epoch).
     * Size for the next reward epoch can still change until the signing policy snapshot is created.
     * @param _rewardEpochId The reward epoch id.
     */
    function getNumberOfRegisteredVoters(uint256 _rewardEpochId) external view returns (uint256);

    /**
     * Returns true if a voter was (is currently) registered in a given reward epoch.
     * @param _voter The voter address.
     * @param _rewardEpochId The reward epoch id.
     */
    function isVoterRegistered(address _voter, uint256 _rewardEpochId) external view returns(bool);
}
