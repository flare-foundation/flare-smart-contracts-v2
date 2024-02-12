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

    /// Event emitted when a beneficiary (c-chain address or node id) is chilled.
    event BeneficiaryChilled(bytes20 indexed beneficiary, uint256 untilRewardEpochId);

    /// Event emitted when a voter is removed.
    event VoterRemoved(address indexed voter, uint256 indexed rewardEpochId);

    /// Event emitted when a voter is registered.
    event VoterRegistered(
        address indexed voter,
        uint24 indexed rewardEpochId,
        address indexed signingPolicyAddress,
        address submitAddress,
        address submitSignaturesAddress,
        bytes32 publicKeyPart1,
        bytes32 publicKeyPart2,
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
     * In case of providing bad votes (e.g. ftso collusion), the beneficiary can be chilled for a few reward epochs.
     * If beneficiary is chilled, the vote power assigned to it is zero.
     * @param _beneficiary The beneficiary (c-chain address or node id).
     * @return _rewardEpochId The reward epoch id until which the voter is chilled.
     */
    function chilledUntilRewardEpochId(bytes20 _beneficiary) external view returns (uint256 _rewardEpochId);

    /**
     * Returns the block number of the start of the new signing policy initialisation for a given reward epoch.
     * It is a snaphost block of the voters' addresses (it is zero if the reward epoch is not supported).
     * @param _rewardEpochId The reward epoch id.
     */
    function newSigningPolicyInitializationStartBlockNumber(uint256 _rewardEpochId) external view returns (uint256);

    /**
     * Indicates if the voter must have the public key set when registering.
     */
    function publicKeyRequired() external view returns (bool);

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
