// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/governance/implementation/PollingFtso.sol";

contract PollingFtsoTest is Test {

    address payable constant internal BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);

    PollingFtso private pollingFtso;

    address private governance;
    address private governanceSettings;
    address private addressUpdater;
    address private mockVoterRegistry;
    address private mockFlareSystemsManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private maintainer;
    address[] private voters;
    address private proposer;
    address private proxyVoter;

    event FtsoProposalCreated(
        uint256 indexed proposalId,
        uint256 indexed rewardEpochId,
        address proposer,
        string description,
        uint256 voteStartTime,
        uint256 voteEndTime,
        uint256 threshold,
        uint256 majorityConditionBIPS,
        uint256 totalWeight
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 forVotePower,
        uint256 againstVotePower
    );

    event ProposalCanceled(uint256 indexed proposalId);

    function setUp() public {
        governance = makeAddr("governance");
        governanceSettings = makeAddr("governanceSettings");
        addressUpdater = makeAddr("addressUpdater");
        pollingFtso = new PollingFtso(IGovernanceSettings(governanceSettings), governance, addressUpdater);

        mockVoterRegistry = makeAddr("mockVoterRegistry");
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockVoterRegistry;
        contractAddresses[2] = mockFlareSystemsManager;
        pollingFtso.updateContractAddresses(contractNameHashes, contractAddresses);

        // set maintainer
        maintainer = makeAddr("maintainer");
        vm.prank(governance);
        pollingFtso.setMaintainer(maintainer);

        // set parameters
        vm.prank(maintainer);
        pollingFtso.setParameters(
            3600,  // voting delay
            7200,  // voting duration
            6000,  // threshold condition
            5000,  // majority condition
            100    // fee
        );

        proposer = makeAddr("proposer");
        vm.deal(proposer, 1 ether);

        _createVoters(10);

        proxyVoter = makeAddr("proxyVoter");
    }

    function testCheckParameters() public {
        assertEq(pollingFtso.votingDelaySeconds(), 3600);
        assertEq(pollingFtso.votingPeriodSeconds(), 7200);
        assertEq(pollingFtso.thresholdConditionBIPS(), 6000);
        assertEq(pollingFtso.majorityConditionBIPS(), 5000);
        assertEq(pollingFtso.proposalFeeValueWei(), 100);
        assertEq(pollingFtso.maintainer(), maintainer);
    }

    function testSetMaintainerRevert() public {
        vm.prank(governance);
        vm.expectRevert("zero address");
        pollingFtso.setMaintainer(address(0));
    }

    function testSetParametersRevertInvalidParameters() public {
        vm.prank(maintainer);
        vm.expectRevert("invalid parameters");
        pollingFtso.setParameters(3600, 0, 6000, 5000, 100);
    }

    function testSetParametersRevertOnlyMaintainer() public {
        vm.expectRevert("only maintainer");
        pollingFtso.setParameters(3600, 7200, 6000, 5000, 100);
    }

    function testProposeRevertNotEligibleSubmitter() public {
        _mockGetCurrentRewardEpochId(10);

        _mockIsVoterRegistered(proposer, 10, false);
        vm.prank(proposer);
        vm.expectRevert("submitter is not eligible to submit a proposal");
        pollingFtso.propose("proposal1");
    }

    function testProposeRevertInvalidFee() public {
        _mockGetCurrentRewardEpochId(10);

        _mockIsVoterRegistered(proposer, 10, true);
        vm.prank(proposer);
        vm.expectRevert("proposal fee invalid");
        pollingFtso.propose{ value: 99 } ("proposal1");
    }

    function testPropose() public {
        uint256 currentRewardEpoch = 10;
        _mockGetCurrentRewardEpochId(currentRewardEpoch);
        _mockIsVoterRegistered(proposer, currentRewardEpoch, true);
        _mockGetWeightsSums(currentRewardEpoch, 1000);
        vm.warp(123);

        vm.prank(proposer);
        vm.expectEmit();
        emit FtsoProposalCreated(
            1,
            currentRewardEpoch,
            proposer,
            "proposal1",
            123 + 3600,
            123 + 3600 + 7200,
            6000,
            5000,
            1000
        );
        pollingFtso.propose{ value: 100 } ("proposal1");
        assertEq(BURN_ADDRESS.balance, 100);
    }

    function testGetProposalInfo() public {
        testPropose();

        (uint256 rewardEpochId, string memory description, address proposer1, uint256 voteStartTime,
        uint256 voteEndTime, uint256 threshold, uint256 majorityConditionBIPS, uint256 totalWeight)
            = pollingFtso.getProposalInfo(1);
        assertEq(rewardEpochId, 10);
        assertEq(proposer1, proposer);
        assertEq(description, "proposal1");
        assertEq(voteStartTime, 123 + 3600);
        assertEq(voteEndTime, 123 + 3600 + 7200);
        assertEq(threshold, 6000);
        assertEq(majorityConditionBIPS, 5000);
        assertEq(totalWeight, 1000);

        // proposal with id 2 does not exist yet
        (rewardEpochId, description, proposer1, voteStartTime,
        voteEndTime, threshold, majorityConditionBIPS, totalWeight)
            = pollingFtso.getProposalInfo(2);
        assertEq(rewardEpochId, 0);
        assertEq(proposer1, address(0));
        assertEq(description, "");
        assertEq(voteStartTime, 0);
        assertEq(voteEndTime, 0);
        assertEq(threshold, 0);
        assertEq(majorityConditionBIPS, 0);
        assertEq(totalWeight, 0);
    }

    function testGetProposalDescription() public {
        testPropose();
        assertEq(pollingFtso.getProposalDescription(1), "proposal1");
        assertEq(pollingFtso.getProposalDescription(2), "");
    }

    function testGetLastProposal() public {
        testPropose();
        (uint256 lastProposalId, string memory description) = pollingFtso.getLastProposal();
        assertEq(lastProposalId, 1);
        assertEq(description, "proposal1");
    }

    function testCastVoteProposalSuccessful() public {
        testPropose();
        _setVoters(4, 10, true);

        // voters did not vote yet
        for (uint256 i = 0; i < 4; i++) {
            assertEq(pollingFtso.hasVoted(1, voters[i]), false);
        }
        (uint256 votesFor, uint256 votesAgainst) = pollingFtso.getProposalVotes(1);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
        assertEq(uint256(pollingFtso.state(1)), 1);

        // move to voting period -> proposal is active
        vm.warp(123 + 3600);
        assertEq(uint256(pollingFtso.state(1)), 2);

        // voters 1 and 2 vote (in favor)
        vm.prank(voters[0]);
        vm.expectEmit();
        emit VoteCast(voters[0], 1, 1, 100, 0);
        pollingFtso.castVote(1, 1);
        vm.prank(voters[1]);
        vm.expectEmit();
        emit VoteCast(voters[1], 1, 1, 300, 0);
        pollingFtso.castVote(1, 1);
        for (uint256 i = 0; i < 2; i++) {
            assertEq(pollingFtso.hasVoted(1, voters[i]), true);
        }
        (votesFor, votesAgainst) = pollingFtso.getProposalVotes(1);
        assertEq(votesFor, 300);
        assertEq(votesAgainst, 0);

        // voter 3 votes against; threshold is reached but majority is not in favor
        vm.prank(voters[2]);
        vm.expectEmit();
        emit VoteCast(voters[2], 1, 0, 300, 300);
        pollingFtso.castVote(1, 0);
        (votesFor, votesAgainst) = pollingFtso.getProposalVotes(1);
        assertEq(votesFor, 300);
        assertEq(votesAgainst, 300);

        // move to the end of the voting period; proposal is defeated
        vm.warp(123 + 3600 + 7200);
        assertEq(uint256(pollingFtso.state(1)), 3);
    }

    function testCastVoteProposalDefeated() public {
        testPropose();
        _setVoters(4, 10, true);

        // voters did not vote yet
        for (uint256 i = 0; i < 4; i++) {
            assertEq(pollingFtso.hasVoted(1, voters[i]), false);
        }
        (uint256 votesFor, uint256 votesAgainst) = pollingFtso.getProposalVotes(1);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
        assertEq(uint256(pollingFtso.state(1)), 1);

        // move to voting period -> proposal is active
        vm.warp(123 + 3600);
        assertEq(uint256(pollingFtso.state(1)), 2);

        // voters 1 and 2 vote (in favor)
        vm.prank(voters[0]);
        vm.expectEmit();
        emit VoteCast(voters[0], 1, 1, 100, 0);
        pollingFtso.castVote(1, 1);
        vm.prank(voters[1]);
        vm.expectEmit();
        emit VoteCast(voters[1], 1, 1, 300, 0);
        pollingFtso.castVote(1, 1);
        for (uint256 i = 0; i < 2; i++) {
            assertEq(pollingFtso.hasVoted(1, voters[i]), true);
        }
        (votesFor, votesAgainst) = pollingFtso.getProposalVotes(1);
        assertEq(votesFor, 300);
        assertEq(votesAgainst, 0);

        // voter 3 votes against; threshold is reached but majority is not in favor
        vm.prank(voters[2]);
        vm.expectEmit();
        emit VoteCast(voters[2], 1, 0, 300, 300);
        pollingFtso.castVote(1, 0);
        (votesFor, votesAgainst) = pollingFtso.getProposalVotes(1);
        assertEq(votesFor, 300);
        assertEq(votesAgainst, 300);

        // voter 4 votes in favor; proposal is successful
        vm.prank(voters[3]);
        vm.expectEmit();
        emit VoteCast(voters[3], 1, 1, 700, 300);
        pollingFtso.castVote(1, 1);
        (votesFor, votesAgainst) = pollingFtso.getProposalVotes(1);
        assertEq(votesFor, 700);
        assertEq(votesAgainst, 300);

        // move to the end of the voting period
        vm.warp(123 + 3600 + 7200);
        assertEq(uint256(pollingFtso.state(1)), 4);
    }

    function testCastVoteProposalDefeated2() public {
        testPropose();
        _setVoters(4, 10, true);

        // voters did not vote yet
        for (uint256 i = 0; i < 4; i++) {
            assertEq(pollingFtso.hasVoted(1, voters[i]), false);
        }
        (uint256 votesFor, uint256 votesAgainst) = pollingFtso.getProposalVotes(1);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
        assertEq(uint256(pollingFtso.state(1)), 1);

        // move to voting period -> proposal is active
        vm.warp(123 + 3600);
        assertEq(uint256(pollingFtso.state(1)), 2);

        // voters 1 and 2 vote (in favor)
        vm.prank(voters[0]);
        vm.expectEmit();
        emit VoteCast(voters[0], 1, 1, 100, 0);
        pollingFtso.castVote(1, 1);
        vm.prank(voters[1]);
        vm.expectEmit();
        emit VoteCast(voters[1], 1, 1, 300, 0);
        pollingFtso.castVote(1, 1);
        for (uint256 i = 0; i < 2; i++) {
            assertEq(pollingFtso.hasVoted(1, voters[i]), true);
        }
        (votesFor, votesAgainst) = pollingFtso.getProposalVotes(1);
        assertEq(votesFor, 300);
        assertEq(votesAgainst, 0);


        // move to the end of the voting period
        // majority of voters was in favor but threshold was not reached (turnout too low)
        vm.warp(123 + 3600 + 7200);
        assertEq(uint256(pollingFtso.state(1)), 3);
    }

    function testCastVoteRevertProposalNotActive() public {
        testPropose();
        _setVoters(1, 10, true);

        vm.expectRevert("proposal not active");
        pollingFtso.castVote(1, 1);
    }

    function testCastVoteRevertVoterNotEligible() public {
        testPropose();
        _setVoters(1, 10, false);

        vm.warp(123 + 3600);
        vm.prank(voters[0]);
        vm.expectRevert("address is not eligible to cast a vote");
        pollingFtso.castVote(1, 1);
    }

    function testCastVoteRevertVoteAlreadyCast() public {
        testPropose();
        _setVoters(1, 10, true);
        vm.warp(123 + 3600);

        vm.startPrank(voters[0]);
        pollingFtso.castVote(1, 1);

        vm.expectRevert("vote already cast");
        pollingFtso.castVote(1, 0);
        vm.stopPrank();
    }

    function testCastVoteRevertInvalidVote() public {
        testPropose();
        _setVoters(1, 10, true);
        vm.warp(123 + 3600);

        vm.prank(voters[0]);
        vm.expectRevert("invalid value for enum VoteType");
        pollingFtso.castVote(1, 2);
    }

    function testChangeThresholdAndDontUpdateCurrentProposal() public {
        testPropose();
        vm.prank(maintainer);
        pollingFtso.setParameters(3600, 7200, 8000, 9000, 100);
        (, , , , , uint256 threshold, uint256 majorityConditionBIPS, )
            = pollingFtso.getProposalInfo(1);
        assertEq(threshold, 6000);
        assertEq(majorityConditionBIPS, 5000);

        // create another proposal
        vm.prank(proposer);
        pollingFtso.propose{ value: 100 } ("proposal1");
        (, , , , , threshold, majorityConditionBIPS, )
            = pollingFtso.getProposalInfo(2);
        assertEq(threshold, 8000);
        assertEq(majorityConditionBIPS, 9000);
    }

    function testGetStateRevertUnknownProposal() public {
        vm.expectRevert("unknown proposal id");
        pollingFtso.state(1);
    }

    function testCancelProposal() public {
        testPropose();
        vm.prank(proposer);
        vm.expectEmit();
        emit ProposalCanceled(1);
        pollingFtso.cancel(1);
        assertEq(uint256(pollingFtso.state(1)), 0);
    }

    function testCancelRevertAlreadyCanceled() public {
        testCancelProposal();
        vm.expectRevert("proposal is already canceled");
        pollingFtso.cancel(1);
    }

    function testCancelRevertNotEligible() public {
        testPropose();
        address randomAddr = makeAddr("random");
        _mockIsVoterRegistered(randomAddr, 10, true);
        vm.prank(randomAddr);
        vm.expectRevert("proposal can only be canceled by its proposer or his proxy address");
        pollingFtso.cancel(1);
    }

    function testCancelRevertAfterVotingStarted() public {
        testPropose();
        _mockIsVoterRegistered(maintainer, 10, true);
        vm.warp(123 + 3600);
        vm.prank(proposer);
        vm.expectRevert("proposal can only be canceled before voting starts");
        pollingFtso.cancel(1);
    }

    function testSetProxyVoter() public {
        _setVoters(1, 10, false);
        vm.prank(voters[0]);
        pollingFtso.setProxyVoter(proxyVoter);
        assertEq(pollingFtso.voterToProxy(voters[0]), proxyVoter);
        assertEq(pollingFtso.proxyToVoter(proxyVoter), voters[0]);
    }

    function testChangeProxyVoter() public {
        testSetProxyVoter();
        address proxy2 = makeAddr("proxy2");
        vm.prank(voters[0]);
        pollingFtso.setProxyVoter(proxy2);
        assertEq(pollingFtso.voterToProxy(voters[0]), proxy2);
        assertEq(pollingFtso.proxyToVoter(proxy2), voters[0]);
    }

    function testRemoveProxyVoter() public {
        testSetProxyVoter();
        vm.prank(voters[0]);
        pollingFtso.setProxyVoter(address(0));
        assertEq(pollingFtso.voterToProxy(voters[0]), address(0));
        assertEq(pollingFtso.proxyToVoter(address(0)), address(0));
    }

    function testSetProxyVoterRevert() public {
        testSetProxyVoter();
        vm.prank(voters[1]);
        vm.expectRevert("address is already a proxy of some voter");
        pollingFtso.setProxyVoter(proxyVoter);
    }


    // TODO voting by proxy



    function _mockGetCurrentRewardEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _mockIsVoterRegistered(address _voter, uint256 _rewardEpochId, bool _isRegistered) private {
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IVoterRegistry.isVoterRegistered.selector, _voter, _rewardEpochId),
            abi.encode(_isRegistered)
        );
    }

    function _createVoters(uint256 _numOfVoters) private {
        for (uint256 i = 0; i < _numOfVoters; i++) {
            voters.push(makeAddr(string.concat("voter", vm.toString(i))));
        }
    }

    function _setVoters(uint256 _numOfVoters, uint256 _rewardEpochId, bool register) private {
        for (uint256 i = 0; i < _numOfVoters; i++) {
            if (i < voters.length) {
                vm.mockCall(
                    mockVoterRegistry,
                    abi.encodeWithSelector(
                        IIVoterRegistry.getVoterRegistrationWeight.selector,
                        voters[i],
                        _rewardEpochId
                    ),
                    abi.encode((i + 1) * 100)
                );
                _mockIsVoterRegistered(voters[i], _rewardEpochId, register);
            }
        }
    }

    function _mockGetWeightsSums(uint256 _rewardEpochId, uint128 _weightsSum) private {
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getWeightsSums.selector, _rewardEpochId),
            abi.encode(_weightsSum, uint16(1), uint16(1))
        );
    }

}