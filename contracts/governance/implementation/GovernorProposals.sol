// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IGovernor.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract GovernorProposals {

    /**
     * Struct holding the information about proposal properties
     */
    struct Proposal {
        address proposer;               // address of the proposer
        bool accept;                    // type of the proposal - accept or reject
        bool executed;                  // flag indicating if proposal has been executed
        bool canceled;                  // flag indicating if proposal has been canceled
        bool executableOnChain;         // flag indicating if proposal is executable on chain (via execution params)
        uint256 votePowerBlock;         // block number used for identifying vote power
        uint256 voteStartTime;          // start time of voting window (in seconds from epoch)
        uint256 voteEndTime;            // end time of voting window (in seconds from epoch)
        uint256 execStartTime;          // start time of execution window (in seconds from epoch)
        uint256 execEndTime;            // end time of execution window (in seconds from epoch)
        uint256 thresholdConditionBIPS; // percentage in BIPS of the total vote power required for proposal "quorum"
        uint256 majorityConditionBIPS;  // percentage in BIPS of the proper relation between FOR and AGAINST votes
        uint256 circulatingSupply;      // circulating supply at votePowerBlock
        string description;             // description of the proposal
    }

    uint256 internal nextExecutionStartTime;            // first available time for next proposal execution
    mapping(uint256 proposalId => Proposal) internal proposals;
    /// Array of proposal ids
    uint256[] public proposalIds;
    /// Chain id used for proposal id generation
    uint256 immutable public chainId;

    constructor() {
        uint256 id;
        /* solhint-disable no-inline-assembly */
        assembly {
            id := chainid()
        }
        /* solhint-enable no-inline-assembly */
        chainId = id;
    }

    /**
     * Stores a new proposal
     * @param _proposer             Address of the proposer
     * @param _targets              Array of target addresses on which the calls are to be invoked
     * @param _values               Array of values with which the calls are to be invoked
     * @param _calldatas            Array of call data to be invoked
     * @param _description          String description of the proposal
     * @param _votePowerBlock       Block number used for identifying vote power
     * @param _minVPBlockTimestamp  Timestamp of a minimal vote power block
     * @param _settings             Address identifying the governance settings address
     * @param _circulatingSupply    Total circulating supply (total vote power) at vote power block
     * @return Proposal id and proposal object
     */
    function _storeProposal(
        address _proposer,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description,
        uint256 _votePowerBlock,
        uint256 _minVPBlockTimestamp,
        IGovernor.GovernorSettings memory _settings,
        uint256 _circulatingSupply,
        uint256 _maxProposalDurationSeconds
    ) internal returns (uint256, Proposal storage) {
        require(_targets.length == _values.length, "invalid proposal length");
        require(_targets.length == _calldatas.length, "invalid proposal length");
        uint256 proposalId = _getProposalId(_targets, _values, _calldatas, _getDescriptionHash(_description));

        Proposal storage proposal = proposals[proposalId];
        require(proposal.voteStartTime == 0, "proposal already exists");

        proposal.proposer = _proposer;
        proposal.description = _description;
        proposal.votePowerBlock = _votePowerBlock;
        proposal.accept = _settings.accept;
        proposal.voteStartTime = Math.max(block.timestamp, _settings.votingStartTs);
        proposal.voteEndTime = proposal.voteStartTime + _settings.votingPeriodSeconds;

        require(proposal.voteEndTime - _minVPBlockTimestamp < _maxProposalDurationSeconds,
            "vote power block is too far in the past");

        if (_targets.length > 0) {
            proposal.executableOnChain = true;
            proposal.execStartTime = proposal.voteEndTime + _settings.executionDelaySeconds;
            if (proposal.execStartTime < nextExecutionStartTime) {
                proposal.execStartTime = nextExecutionStartTime;
            }
            proposal.execEndTime = proposal.execStartTime + _settings.executionPeriodSeconds;
            nextExecutionStartTime = proposal.execEndTime;
        }

        proposal.thresholdConditionBIPS = _settings.thresholdConditionBIPS;
        proposal.majorityConditionBIPS = _settings.majorityConditionBIPS;
        proposal.circulatingSupply = _circulatingSupply;

        proposalIds.push(proposalId);

        return (proposalId, proposal);
    }

    /**
     * Executes proposal
     * @param _targets              Array of target addresses on which the calls are to be invoked
     * @param _values               Array of values with which the calls are to be invoked
     * @param _calldatas            Array of call data to be invoked
     */
    function _executeProposal(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas
    ) internal {
        uint256 sum = 0;
        for(uint256 i = 0; i < _values.length; i++) {
            sum = sum + _values[i];
        }
        require(msg.value == sum, "sum of _values does not equals msg.value");
        for (uint256 i = 0; i < _targets.length; ++i) {
            /* solhint-disable avoid-low-level-calls */
            (bool success, bytes memory returndata) = _targets[i].call{value: _values[i]}(_calldatas[i]);
            /* solhint-enable avoid-low-level-calls */
            if (!success) {
                if (returndata.length > 0) {
                    /* solhint-disable no-inline-assembly */
                    assembly {
                        let returndata_size := mload(returndata)
                        revert(add(32, returndata), returndata_size)
                    }
                    /* solhint-enable no-inline-assembly */
                } else {
                    revert("call reverted without message");
                }
            }
        }
    }

    /**
     * Creates the hash of a proposal which is used as its id
     * @param _targets              Array of target addresses on which the calls are to be invoked
     * @param _values               Array of values with which the calls are to be invoked
     * @param _calldatas            Array of call data to be invoked
     * @param _descriptionHash      Hashed description of the proposal
     */
    function _getProposalId(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal view returns (uint256) {
        return uint256(keccak256(abi.encode(chainId, address(this), _targets, _values, _calldatas, _descriptionHash)));
    }

    /**
     * Hashes the proposal description
     * @param _description          String representing the proposal description
     * @return Bytes array representing hashed proposal description
     */
    function _getDescriptionHash(string memory _description) internal pure returns (bytes32) {
        return keccak256(bytes(_description));
    }
}
