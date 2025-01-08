// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IPollingManagementGroup.sol";

interface IIPollingManagementGroup is IPollingManagementGroup {

    struct ProposalSettings {
        bool accept;
        uint256 votingStartTs;
        uint256 votingPeriodSeconds;
        uint256 thresholdConditionBIPS;
        uint256 majorityConditionBIPS;
    }

    /**
     * Sets (or changes) contract's parameters. It is called after deployment of the contract
     * and every time one of the parameters changes.
     * @param _votingDelaySeconds Period between proposal creation and start of the vote, in seconds.
     * @param _votingPeriodSeconds Length of voting period, in seconds.
     * @param _thresholdConditionBIPS Share of total vote power (in BIPS) required to participate in vote
     * for proposal to pass.
     * @param _majorityConditionBIPS Share of participating vote power (in BIPS) required to vote in favor.
     * @param _proposalFeeValueWei Fee value (in wei) that proposer must pay to submit a proposal.
     * @param _addAfterRewardedEpochs Number of epochs with rewards after which a voter can be added.
     * @param _addAfterNotChilledEpochs Number of epochs without chilling after which a voter can be added.
     * @param _removeAfterNotRewardedEpochs Number of epochs without rewards after which a voter can be removed.
     * @param _removeAfterEligibleProposals Number of eligible proposals after which a voter can be removed.
     * @param _removeAfterNonParticipatingProposals Number of non-participating proposals after which a voter
     * can be removed.
     * @param _removeForDays Number of days for which a voter is removed.
     */
    function setParameters(
        uint256 _votingDelaySeconds,
        uint256 _votingPeriodSeconds,
        uint256 _thresholdConditionBIPS,
        uint256 _majorityConditionBIPS,
        uint256 _proposalFeeValueWei,
        uint256 _addAfterRewardedEpochs,
        uint256 _addAfterNotChilledEpochs,
        uint256 _removeAfterNotRewardedEpochs,
        uint256 _removeAfterEligibleProposals,
        uint256 _removeAfterNonParticipatingProposals,
        uint256 _removeForDays
    ) external;

    /**
     * Changes list of management group members.
     * @param _votersToAdd Array of addresses to add to the list.
     * @param _votersToRemove Array of addresses to remove from the list.
     */
    function changeManagementGroupMembers(
        address[] memory _votersToAdd,
        address[] memory _votersToRemove
    ) external;

    /**
     * Creates a new proposal with the given description and settings.
     * @param _description String description of the proposal.
     * @param _settings Settings of the proposal.
     * @return _proposalId Unique identifier of the proposal.
     */
    function proposeWithSettings(
        string memory _description,
        ProposalSettings memory _settings
    ) external returns (uint256 _proposalId);
}