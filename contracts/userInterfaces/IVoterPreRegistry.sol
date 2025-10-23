// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IIVoterRegistry } from "../protocol/interface/IIVoterRegistry.sol";
import { Signature } from "./ISignature.sol";

interface IVoterPreRegistry {

    /// Event emitted when a voter is pre-registered.
    event VoterPreRegistered(address indexed voter, uint32 indexed rewardEpochId);

    /// Event emitted when a voter registration failed.
    event VoterRegistrationFailed(address indexed voter, uint32 indexed rewardEpochId);

    /**
     * Pre-register voter to enable it to be registered by the system.
     * @param _voter The voter address.
     * @param _signature The signature.
     */
    function preRegisterVoter(address _voter, Signature calldata _signature) external;

    /**
     * Returns the list of pre-registered voters for a given reward epoch.
     * @param _rewardEpochId The reward epoch id.
     */
    function getPreRegisteredVoters(uint256 _rewardEpochId) external view returns (address[] memory);

    /**
     * Returns true if a voter was (is currently) pre-registered in a given reward epoch.
     * @param _voter The voter address.
     * @param _rewardEpochId The reward epoch id.
     */
    function isVoterPreRegistered(uint256 _rewardEpochId, address _voter) external view returns (bool);

    /**
     * Returns voter's signature for a given reward epoch and voter address, reverts if not pre-registered.
     * @param _rewardEpochId The reward epoch id.
     * @param _voter The voter address.
     * @return _signature The voter's signature.
     */
    function getVoterSignature(uint256 _rewardEpochId, address _voter) external view returns (Signature memory);
}
