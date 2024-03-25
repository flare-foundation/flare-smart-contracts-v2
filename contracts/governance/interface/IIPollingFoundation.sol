// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IGovernor.sol";
import "./IIGovernorProposer.sol";

interface IIPollingFoundation is IGovernor, IIGovernorProposer {

    struct GovernorSettingsWithoutExecParams {
        bool accept;
        uint256 votingStartTs;
        uint256 votingPeriodSeconds;
        uint256 vpBlockPeriodSeconds;
        uint256 thresholdConditionBIPS;
        uint256 majorityConditionBIPS;
    }

    /**
     * Creates a new proposal without execution parameters.
     * @param _description String description of the proposal.
     * @param _settings Settings of the poposal.
     * @return Proposal id (unique identifier obtained by hashing proposal data).
     * Emits a ProposalCreated event.
     */
    function propose(
        string memory _description,
        GovernorSettingsWithoutExecParams memory _settings
    ) external returns (uint256);

    /**
     * Creates a new proposal with execution parameters.
     * @param _targets Array of target addresses on which the calls are to be invoked.
     * @param _values Array of values with which the calls are to be invoked.
     * @param _calldatas Array of call data to be invoked.
     * @param _description String description of the proposal.
     * @param _settings Settings of the poposal.
     * @return Proposal id (unique identifier obtained by hashing proposal data).
     * Emits a ProposalCreated event.
     */
    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description,
        GovernorSettings memory _settings
    ) external returns (uint256);
}
