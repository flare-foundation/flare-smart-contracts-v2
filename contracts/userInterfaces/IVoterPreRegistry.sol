// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../protocol/interface/IIVoterRegistry.sol";

interface IVoterPreRegistry {

    /// Event emitted when a voter is pre-registered.
    event VoterPreRegistered(address indexed voter, uint256 indexed rewardEpochId);

    /// Event emitted when a voter registration failed.
    event VoterRegistrationFailed(address indexed voter, uint256 indexed rewardEpochId);

    /**
     * Pre-register voter to enable it to be registered by the system.
     * @param _voter The voter address.
     * @param _signature The signature.
     */
    function preRegisterVoter(address _voter, IIVoterRegistry.Signature calldata _signature) external;

    /**
     * Returns the list of pre-registered voters for a given reward epoch.
     * @param _rewardEpochId The reward epoch id.
     */
    function getPreRegisteredVoters(uint24 _rewardEpochId) external view returns (address[] memory);

    /**
     * Returns true if a voter was (is currently) pre-registered in a given reward epoch.
     * @param _voter The voter address.
     * @param _rewardEpochId The reward epoch id.
     */
    function isVoterPreRegistered(uint24 _rewardEpochId, address _voter) external view returns (bool);
}
