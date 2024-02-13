// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

abstract contract GovernorVotes {

    /**
     * @notice Enum that determines vote (support) type
     * @dev 0 = Against, 1 = For
     */
    enum VoteType {
        Against,
        For
    }

    /**
     * @notice Struct holding the information about proposal voting
     */
    struct ProposalVoting {
        uint256 againstVotePower;           // accumulated vote power against the proposal
        uint256 forVotePower;               // accumulated vote power for the proposal
        mapping(address => bool) hasVoted;  // flag if a voter has cast a vote
    }

    mapping(uint256 proposalId => ProposalVoting) internal proposalVotings;

    /**
     * @notice Stores a proposal vote
     * @param _proposalId           Id of the proposal
     * @param _voter                Address of the voter
     * @param _support              Parameter indicating the vote type
     * @param _votePower            Vote power of the voter
     */
    function _storeVote(
        uint256 _proposalId,
        address _voter,
        uint8 _support,
        uint256 _votePower
    ) internal returns (ProposalVoting storage _voting) {
        _voting = proposalVotings[_proposalId];

        require(!_voting.hasVoted[_voter], "vote already cast");
        _voting.hasVoted[_voter] = true;

        if (_support == uint8(VoteType.Against)) {
            _voting.againstVotePower += _votePower;
        } else if (_support == uint8(VoteType.For)) {
            _voting.forVotePower += _votePower;
        } else {
            revert("invalid value for enum VoteType");
        }
    }

}
