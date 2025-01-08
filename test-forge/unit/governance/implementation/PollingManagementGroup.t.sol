// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/governance/implementation/PollingManagementGroup.sol";

contract PollingManagementGroupTest is Test {

    address payable constant internal BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);

    uint256 constant internal DAY_TO_SECONDS = 86400;

    PollingManagementGroup private pollingManagementGroup;
    PollingManagementGroup.ProposalSettings private settings;

    address private governance;
    address private governanceSettings;
    address private addressUpdater;
    address private mockVoterRegistry;
    address private mockFlareSystemsManager;
    address private mockRewardManager;
    address private mockEntityManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private maintainer;
    address[] private voters;
    address[] private members;
    address private proposer;
    address private proxyVoter;

    event ManagementGroupProposalCreated(
        uint256 indexed proposalId,
        address proposer,
        string description,
        uint256 voteStartTime,
        uint256 voteEndTime,
        uint256 thresholdConditionBIPS,
        uint256 majorityConditionBIPS,
        address[] eligibleMembers,
        bool accept
    );
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 forVotePower,
        uint256 againstVotePower
    );
    event ProposalCanceled(uint256 indexed proposalId);
    event ManagementGroupMemberAdded(address addedMember);
    event ManagementGroupMemberRemoved(address removedMember);

    function setUp() public {
        governance = makeAddr("governance");
        governanceSettings = makeAddr("governanceSettings");
        addressUpdater = makeAddr("addressUpdater");
        pollingManagementGroup = new PollingManagementGroup(
            IGovernanceSettings(governanceSettings), governance, addressUpdater);
        settings = IIPollingManagementGroup.ProposalSettings({
            accept: true,
            votingStartTs: 0,
            votingPeriodSeconds: 7200,
            thresholdConditionBIPS: 6000,
            majorityConditionBIPS: 5000
        });

        mockVoterRegistry = makeAddr("mockVoterRegistry");
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockRewardManager = makeAddr("mockRewardManager");
        mockEntityManager = makeAddr("mockEntityManager");
        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[4] = keccak256(abi.encode("EntityManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockVoterRegistry;
        contractAddresses[2] = mockFlareSystemsManager;
        contractAddresses[3] = mockRewardManager;
        contractAddresses[4] = mockEntityManager;
        pollingManagementGroup.updateContractAddresses(contractNameHashes, contractAddresses);

        // set maintainer
        maintainer = makeAddr("maintainer");
        vm.prank(governance);
        pollingManagementGroup.setMaintainer(maintainer);

        // set parameters
        vm.prank(maintainer);
        pollingManagementGroup.setParameters(
            3600,  // voting delay
            7200,  // voting duration
            6000,  // threshold condition
            5000,  // majority condition
            100,   // fee
            3,     // add after rewarded epochs
            4,     // add after not chilled epochs
            2,     // remove after not rewarded epochs
            2,     // remove after eligible proposals
            2,     // remove after non-participating proposals
            7      // remove for days
        );

        _createVoters(10);
        proxyVoter = makeAddr("proxyVoter");
        members = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            members[i] = voters[i];
        }
        proposer = members[0];
        vm.deal(proposer, 1 ether);
        _mockGetCurrentRewardEpochId(8);
        vm.prank(maintainer);
        pollingManagementGroup.changeManagementGroupMembers(members, new address[](0));
    }

    function testCheckParameters() public {
        assertEq(pollingManagementGroup.votingDelaySeconds(), 3600);
        assertEq(pollingManagementGroup.votingPeriodSeconds(), 7200);
        assertEq(pollingManagementGroup.thresholdConditionBIPS(), 6000);
        assertEq(pollingManagementGroup.majorityConditionBIPS(), 5000);
        assertEq(pollingManagementGroup.proposalFeeValueWei(), 100);
        assertEq(pollingManagementGroup.maintainer(), maintainer);
    }

    function testGetManagementGroupMembers() public {
        address[] memory mgMembers = pollingManagementGroup.getManagementGroupMembers();
        assertEq(mgMembers.length, 5);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(mgMembers[i], voters[i]);
        }

        // change management group members
        address[] memory newMembers = new address[](1);
        address[] memory removedMembers = new address[](1);
        removedMembers[0] = voters[0];
        newMembers[0] = makeAddr("newMember");
        vm.prank(maintainer);
        pollingManagementGroup.changeManagementGroupMembers(newMembers, removedMembers);
        mgMembers = pollingManagementGroup.getManagementGroupMembers();
        assertEq(mgMembers.length, 5);
        assertEq(mgMembers[0], voters[4]);
        assertEq(mgMembers[1], voters[1]);
        assertEq(mgMembers[2], voters[2]);
        assertEq(mgMembers[3], voters[3]);
        assertEq(mgMembers[4], newMembers[0]);
    }

    function testsIsMember() public {
        for (uint256 i = 0; i < 5; i++) {
            assertEq(pollingManagementGroup.isMember(voters[i]), true);
        }
        assertEq(pollingManagementGroup.isMember(makeAddr("random")), false);

        // change management group members
        address[] memory newMembers = new address[](1);
        address[] memory removedMembers = new address[](1);
        removedMembers[0] = voters[0];
        newMembers[0] = makeAddr("newMember");
        vm.prank(maintainer);
        pollingManagementGroup.changeManagementGroupMembers(newMembers, removedMembers);
        assertEq(pollingManagementGroup.isMember(voters[0]), false);
        assertEq(pollingManagementGroup.isMember(newMembers[0]), true);
        for (uint256 i = 1; i < 5; i++) {
            assertEq(pollingManagementGroup.isMember(voters[i]), true);
        }
    }

    function testSetMaintainerRevert() public {
        vm.prank(governance);
        vm.expectRevert("zero address");
        pollingManagementGroup.setMaintainer(address(0));
    }

    function testSetParametersRevertInvalidParameters() public {
        vm.prank(maintainer);
        vm.expectRevert("invalid parameters");
        pollingManagementGroup.setParameters(3600, 0, 6000, 5000, 100, 20, 20, 2, 4, 2, 7);
    }

    function testSetParametersRevertOnlyMaintainer() public {
        vm.expectRevert("only maintainer");
        pollingManagementGroup.setParameters(3600, 7200, 6000, 5000, 100, 20, 20, 2, 4, 2, 7);
    }

    function testProposeRevertNotEligibleSubmitter() public {
        _mockGetCurrentRewardEpochId(10);

        vm.prank(voters[9]);
        vm.expectRevert("submitter is not eligible to submit a proposal");
        pollingManagementGroup.propose("proposal1");
    }

    function testProposeRevertInvalidFee() public {
        _mockGetCurrentRewardEpochId(10);

        vm.prank(proposer);
        vm.expectRevert("proposal fee invalid");
        pollingManagementGroup.propose{ value: 99 } ("proposal1");
    }

    function testPropose() public {
        uint256 currentRewardEpoch = 10;
        _mockGetCurrentRewardEpochId(currentRewardEpoch);
        vm.warp(123);

        vm.prank(proposer);
        vm.expectEmit();
        emit ManagementGroupProposalCreated(
            1,
            proposer,
            "proposal1",
            123 + 3600,
            123 + 3600 + 7200,
            6000,
            5000,
            members,
            true
        );
        pollingManagementGroup.propose{ value: 100 } ("proposal1");
        assertEq(BURN_ADDRESS.balance, 100);
    }

    function testChangeManagementGroupMembersAndVote() public {
        uint256 currentRewardEpoch = 10;
        _mockGetCurrentRewardEpochId(currentRewardEpoch);
        vm.warp(123);

        vm.prank(proposer);
        vm.expectEmit();
        emit ManagementGroupProposalCreated(
            1,
            proposer,
            "proposal1",
            123 + 3600,
            123 + 3600 + 7200,
            6000,
            5000,
            members,
            true
        );
        pollingManagementGroup.propose{ value: 100 } ("proposal1");
        assertEq(BURN_ADDRESS.balance, 100);

        // members can vote
        vm.warp(123 + 3600);
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(members[i]);
            pollingManagementGroup.castVote(1, 1);
        }
        // non-members can't vote
        vm.prank(voters[5]);
        vm.expectRevert("address is not eligible to cast a vote");
        pollingManagementGroup.castVote(1, 1);

        // change management group members
        address[] memory newMembers = new address[](1);
        newMembers[0] = voters[5];
        vm.prank(maintainer);
        pollingManagementGroup.changeManagementGroupMembers(newMembers, members);
        // create a new proposal
        proposer = newMembers[0];
        vm.deal(proposer, 1 ether);
        vm.prank(proposer);
        vm.expectEmit();
        emit ManagementGroupProposalCreated(
            2,
            proposer,
            "proposal2",
            123 + 3600 + 3600,
            123 + 3600 + 3600 + 7200,
            6000,
            5000,
            newMembers,
            true
        );
        pollingManagementGroup.propose{ value: 100 } ("proposal2");
        assertEq(BURN_ADDRESS.balance, 200);

        // members can vote
        vm.warp(123 + 3600 + 3600);
        vm.prank(newMembers[0]);
        pollingManagementGroup.castVote(2, 1);
        // non-members can't vote
        vm.prank(voters[0]);
        vm.expectRevert("address is not eligible to cast a vote");
        pollingManagementGroup.castVote(2, 1);
    }

    function testChangeManagementGroupMembersRevertOnlyMaintainer() public {
        vm.expectRevert("only maintainer");
        pollingManagementGroup.changeManagementGroupMembers(new address[](0), new address[](0));
    }

    function testChangeManagementGroupMembersRevertAlreadyMember() public {
        vm.prank(maintainer);
        vm.expectRevert("voter is already a member of the management group");
        pollingManagementGroup.changeManagementGroupMembers(members, new address[](0));
    }

    function testChangeManagementGroupMembersRevertNotMember() public {
        address[] memory notMembers = new address[](1);
        notMembers[0] = makeAddr("notMember");
        vm.prank(maintainer);
        vm.expectRevert("voter is not a member of the management group");
        pollingManagementGroup.changeManagementGroupMembers(new address[](0), notMembers);
    }

    function testGetProposalInfo() public {
        testPropose();

        (string memory description, address proposer1, bool accept, uint256 voteStartTime,
        uint256 voteEndTime, uint256 threshold, uint256 majorityConditionBIPS, uint256 noOfEligibleMembers)
            = pollingManagementGroup.getProposalInfo(1);
        assertEq(accept, true);
        assertEq(proposer1, proposer);
        assertEq(description, "proposal1");
        assertEq(voteStartTime, 123 + 3600);
        assertEq(voteEndTime, 123 + 3600 + 7200);
        assertEq(threshold, 6000);
        assertEq(majorityConditionBIPS, 5000);
        assertEq(noOfEligibleMembers, 5);

        // proposal with id 2 does not exist yet
        (description, proposer1, accept, voteStartTime,
        voteEndTime, threshold, majorityConditionBIPS, noOfEligibleMembers)
            = pollingManagementGroup.getProposalInfo(2);
        assertEq(accept, false);
        assertEq(proposer1, address(0));
        assertEq(description, "");
        assertEq(voteStartTime, 0);
        assertEq(voteEndTime, 0);
        assertEq(threshold, 0);
        assertEq(majorityConditionBIPS, 0);
        assertEq(noOfEligibleMembers, 0);
    }

    function testGetProposalDescription() public {
        testPropose();
        assertEq(pollingManagementGroup.getProposalDescription(1), "proposal1");
        assertEq(pollingManagementGroup.getProposalDescription(2), "");
    }

    function testGetLastProposal() public {
        testPropose();
        (uint256 lastProposalId, string memory description) = pollingManagementGroup.getLastProposal();
        assertEq(lastProposalId, 1);
        assertEq(description, "proposal1");
    }

    function testCastVoteProposalDefeated() public {
        testPropose();

        // voters did not vote yet
        for (uint256 i = 0; i < 4; i++) {
            assertEq(pollingManagementGroup.hasVoted(1, voters[i]), false);
        }
        (uint256 getVotesFor, uint256 getVotesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(getVotesFor, 0);
        assertEq(getVotesAgainst, 0);
        assertEq(uint256(pollingManagementGroup.state(1)), 1);

        // move to voting period -> proposal is active
        vm.warp(123 + 3600);
        assertEq(uint256(pollingManagementGroup.state(1)), 2);

        // voters 1 and 2 vote (in favor)
        uint256 votesFor;
        for (uint256 i = 0; i < 2; i++) {
            votesFor++;
            vm.prank(voters[i]);
            vm.expectEmit();
            emit VoteCast(voters[i], 1, 1, votesFor, 0);
            pollingManagementGroup.castVote(1, 1);
        }
        for (uint256 i = 0; i < 2; i++) {
            assertEq(pollingManagementGroup.hasVoted(1, voters[i]), true);
        }
        (getVotesFor, getVotesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 2);
        assertEq(getVotesAgainst, 0);

        // voter 3 votes against; threshold is reached but majority is not in favor
        uint256 votesAgainst;
        for (uint256 i = 2; i < 4; i++) {
            votesAgainst++;
            vm.prank(voters[i]);
            vm.expectEmit();
            emit VoteCast(voters[i], 1, 0, votesFor, votesAgainst);
            pollingManagementGroup.castVote(1, 0);
        }
        (votesFor, getVotesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 2);
        assertEq(getVotesAgainst, 2);

        // move to the end of the voting period; proposal is defeated
        vm.warp(123 + 3600 + 7200);
        assertEq(uint256(pollingManagementGroup.state(1)), 3);
    }

    function testCastVoteProposalSuccessful() public {
        testPropose();

        // voters did not vote yet
        for (uint256 i = 0; i < 4; i++) {
            assertEq(pollingManagementGroup.hasVoted(1, voters[i]), false);
        }
        (uint256 votesFor, uint256 votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
        assertEq(uint256(pollingManagementGroup.state(1)), 1);

        // move to voting period -> proposal is active
        vm.warp(123 + 3600);
        assertEq(uint256(pollingManagementGroup.state(1)), 2);

        // voters 1 and 2 vote (in favor)
        vm.prank(voters[0]);
        vm.expectEmit();
        emit VoteCast(voters[0], 1, 1, 1, 0);
        pollingManagementGroup.castVote(1, 1);
        vm.prank(voters[1]);
        vm.expectEmit();
        emit VoteCast(voters[1], 1, 1, 2, 0);
        pollingManagementGroup.castVote(1, 1);
        for (uint256 i = 0; i < 2; i++) {
            assertEq(pollingManagementGroup.hasVoted(1, voters[i]), true);
        }
        (votesFor, votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 2);
        assertEq(votesAgainst, 0);

        // voter 3 votes against; threshold is reached and majority is in favor
        vm.prank(voters[2]);
        vm.expectEmit();
        emit VoteCast(voters[2], 1, 0, 2, 1);
        pollingManagementGroup.castVote(1, 0);
        (votesFor, votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 2);
        assertEq(votesAgainst, 1);

        // move to the end of the voting period
        vm.warp(123 + 3600 + 7200);
        assertEq(uint256(pollingManagementGroup.state(1)), 4);
    }

    function testCastVoteProposalDefeated2() public {
        testPropose();

        // voters did not vote yet
        for (uint256 i = 0; i < 4; i++) {
            assertEq(pollingManagementGroup.hasVoted(1, voters[i]), false);
        }
        (uint256 votesFor, uint256 votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
        assertEq(uint256(pollingManagementGroup.state(1)), 1);

        // move to voting period -> proposal is active
        vm.warp(123 + 3600);
        assertEq(uint256(pollingManagementGroup.state(1)), 2);

        // voters 1 and 2 vote (in favor)
        vm.prank(voters[0]);
        vm.expectEmit();
        emit VoteCast(voters[0], 1, 1, 1, 0);
        pollingManagementGroup.castVote(1, 1);
        vm.prank(voters[1]);
        vm.expectEmit();
        emit VoteCast(voters[1], 1, 1, 2, 0);
        pollingManagementGroup.castVote(1, 1);
        for (uint256 i = 0; i < 2; i++) {
            assertEq(pollingManagementGroup.hasVoted(1, voters[i]), true);
        }
        (votesFor, votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 2);
        assertEq(votesAgainst, 0);


        // move to the end of the voting period
        // majority of voters was in favor but threshold was not reached (turnout too low)
        vm.warp(123 + 3600 + 7200);
        assertEq(uint256(pollingManagementGroup.state(1)), 3);
    }

    function testCastVoteRevertProposalNotActive() public {
        testPropose();

        vm.expectRevert("proposal not active");
        pollingManagementGroup.castVote(1, 1);
    }

    function testCastVoteRevertVoterNotEligible() public {
        testPropose();

        vm.warp(123 + 3600);
        vm.prank(voters[5]);
        vm.expectRevert("address is not eligible to cast a vote");
        pollingManagementGroup.castVote(1, 1);
    }

    function testCastVoteRevertVoteAlreadyCast() public {
        testPropose();
        vm.warp(123 + 3600);

        vm.startPrank(voters[0]);
        pollingManagementGroup.castVote(1, 1);

        vm.expectRevert("vote already cast");
        pollingManagementGroup.castVote(1, 0);
        vm.stopPrank();
    }

    function testCastVoteRevertInvalidVote() public {
        testPropose();
        vm.warp(123 + 3600);

        vm.prank(voters[0]);
        vm.expectRevert("invalid value for enum VoteType");
        pollingManagementGroup.castVote(1, 2);
    }

    function testChangeThresholdAndDontUpdateCurrentProposal() public {
        testPropose();
        vm.prank(maintainer);
        pollingManagementGroup.setParameters(3600, 7200, 8000, 9000, 100, 20, 20, 2, 4, 2, 7);
        (, , , , , uint256 threshold, uint256 majorityConditionBIPS, )
            = pollingManagementGroup.getProposalInfo(1);
        assertEq(threshold, 6000);
        assertEq(majorityConditionBIPS, 5000);

        // create another proposal
        vm.prank(proposer);
        pollingManagementGroup.propose{ value: 100 } ("proposal1");
        (, , , , , threshold, majorityConditionBIPS, )
            = pollingManagementGroup.getProposalInfo(2);
        assertEq(threshold, 8000);
        assertEq(majorityConditionBIPS, 9000);
    }

    function testGetStateRevertUnknownProposal() public {
        vm.expectRevert("unknown proposal id");
        pollingManagementGroup.state(1);
    }

    function testCancelProposal() public {
        testPropose();
        vm.prank(proposer);
        vm.expectEmit();
        emit ProposalCanceled(1);
        pollingManagementGroup.cancel(1);
        assertEq(uint256(pollingManagementGroup.state(1)), 0);
    }

    function testCancelRevertAlreadyCanceled() public {
        testCancelProposal();
        vm.expectRevert("proposal is already canceled");
        pollingManagementGroup.cancel(1);
    }

    function testCancelRevertNotEligible() public {
        testPropose();
        address randomAddr = makeAddr("random");
        vm.prank(randomAddr);
        vm.expectRevert("proposal can only be canceled by its proposer or his proxy address");
        pollingManagementGroup.cancel(1);
    }

    function testCancelRevertAfterVotingStarted() public {
        testPropose();
        vm.warp(123 + 3600);
        vm.prank(proposer);
        vm.expectRevert("proposal can only be canceled before voting starts");
        pollingManagementGroup.cancel(1);
    }

    function testSetProxyVoter() public {
        vm.prank(voters[0]);
        pollingManagementGroup.setProxyVoter(proxyVoter);
        assertEq(pollingManagementGroup.voterToProxy(voters[0]), proxyVoter);
        assertEq(pollingManagementGroup.proxyToVoter(proxyVoter), voters[0]);
    }

    function testChangeProxyVoter() public {
        testSetProxyVoter();
        address proxy2 = makeAddr("proxy2");
        vm.prank(voters[0]);
        pollingManagementGroup.setProxyVoter(proxy2);
        assertEq(pollingManagementGroup.voterToProxy(voters[0]), proxy2);
        assertEq(pollingManagementGroup.proxyToVoter(proxy2), voters[0]);
    }

    function testRemoveProxyVoter() public {
        testSetProxyVoter();
        vm.prank(voters[0]);
        pollingManagementGroup.setProxyVoter(address(0));
        assertEq(pollingManagementGroup.voterToProxy(voters[0]), address(0));
        assertEq(pollingManagementGroup.proxyToVoter(address(0)), address(0));
    }

    function testSetProxyVoterRevert() public {
        testSetProxyVoter();
        vm.prank(voters[1]);
        vm.expectRevert("address is already a proxy of some voter");
        pollingManagementGroup.setProxyVoter(proxyVoter);
    }

    function testProposeByProxy() public {
        uint256 currentRewardEpoch = 10;
        _mockGetCurrentRewardEpochId(currentRewardEpoch);

        // set proxy voter for first registered voter
        vm.prank(voters[0]);
        pollingManagementGroup.setProxyVoter(proxyVoter);

        // proxy creates a proposal
        vm.deal(proxyVoter, 1 ether);
        vm.prank(proxyVoter);
        pollingManagementGroup.propose{ value: 100} ("proposal1");
        (, address proposerAddr, , , , , , ) = pollingManagementGroup.getProposalInfo(1);
        // proposer should be registered voter and not its proxy address
        assertEq(proposerAddr, voters[0]);
    }

    // cancel proposal by proxy
    function testCancelByProxy() public {
        testPropose();

        // set proposer's proxy
        vm.prank(proposer);
        pollingManagementGroup.setProxyVoter(proxyVoter);

        // cancel proposal by proxy
        vm.prank(proxyVoter);
        vm.expectEmit();
        emit ProposalCanceled(1);
        pollingManagementGroup.cancel(1);
        assertEq(uint256(pollingManagementGroup.state(1)), 0);
    }

    function testVoteByProxy() public {
        testProposeByProxy();

        // move to the voting period
        vm.warp(123 + 3600);

        // voters[0] votes as proxy
        vm.prank(proxyVoter);
        vm.expectEmit();
        emit VoteCast(voters[0], 1, 1, 1, 0);
        pollingManagementGroup.castVote(1, 1);
        assertEq(pollingManagementGroup.hasVoted(1, voters[0]), true);

        address proxy2 = makeAddr("proxy2");
        vm.prank(voters[5]);
        pollingManagementGroup.setProxyVoter(proxy2);

        // voters[5] is not member of the management group
        vm.prank(proxy2);
        vm.expectRevert("address is not eligible to cast a vote");
        pollingManagementGroup.castVote(1, 1);

        // voters[0] unregisters its proxy
        vm.prank(voters[0]);
        pollingManagementGroup.setProxyVoter(address(0));
        // voters[1] can set this address as its proxy
        vm.prank(voters[1]);
        pollingManagementGroup.setProxyVoter(proxyVoter);

        // voters[1] votes through proxy
        vm.prank(proxyVoter);
        vm.expectEmit();
        emit VoteCast(voters[1], 1, 1, 2, 0);
        pollingManagementGroup.castVote(1, 1);
        assertEq(pollingManagementGroup.hasVoted(1, voters[1]), true);

        (uint256 votesFor, uint256 votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 2);
        assertEq(votesAgainst, 0);

        // move to the end of the voting period
        vm.warp(123 + 3600 + 7200);

        // proposal is defeated (all in favor but quorum not reached)
        assertEq(uint256(pollingManagementGroup.state(1)), 3);
    }

    function testProxyVotesInItsOwnName() public {
        testPropose();

        // set proxy voter for first registered voter
        vm.prank(voters[0]);
        proxyVoter = members[1];
        pollingManagementGroup.setProxyVoter(proxyVoter);

        // move to the voting period
        vm.warp(123 + 3600);

        // proxyVoter votes; because it is also a registered voter,
        // it votes in its own name and not in the name of voters[0]
        vm.prank(proxyVoter);
        vm.expectEmit();
        emit VoteCast(proxyVoter, 1, 1, 1, 0);
        pollingManagementGroup.castVote(1, 1);
        assertEq(pollingManagementGroup.hasVoted(1, proxyVoter), true);

        // voters[0] votes
        vm.prank(voters[0]);
        vm.expectEmit();
        emit VoteCast(voters[0], 1, 1, 2, 0);
        pollingManagementGroup.castVote(1, 1);
        assertEq(pollingManagementGroup.hasVoted(1, voters[0]), true);

        // voters[1] votes
        vm.prank(voters[2]);
        vm.expectEmit();
        emit VoteCast(voters[2], 1, 1, 3, 0);
        pollingManagementGroup.castVote(1, 1);
        assertEq(pollingManagementGroup.hasVoted(1, voters[1]), true);

        // move to the end of the voting period
        vm.warp(123 + 3600 + 7200);

        // proposal is successful
        assertEq(uint256(pollingManagementGroup.state(1)), 4);
    }

    function testMaintainerProposes () public {
        uint256 currentRewardEpoch = 10;
        _mockGetCurrentRewardEpochId(currentRewardEpoch);
        vm.deal(maintainer, 1 ether);

        // maintainer creates a proposal
        vm.startPrank(maintainer);
        pollingManagementGroup.proposeWithSettings("proposal1", settings);
        (, address proposerAddr, , , , , , ) = pollingManagementGroup.getProposalInfo(1);
        assertEq(proposerAddr, maintainer);

        // maintainer can't vote
        vm.warp(123 + 3600);
        vm.expectRevert("address is not eligible to cast a vote");
        pollingManagementGroup.castVote(1, 1);
        vm.stopPrank();
    }

    function testProposeWithSettingsRevertInvalidParameters() public {
        settings.majorityConditionBIPS = 4999;
        vm.expectRevert("invalid parameters");
        vm.prank(maintainer);
        pollingManagementGroup.proposeWithSettings("proposal1", settings);
    }

    function testCanProposeAndCanVote() public {
        _mockGetCurrentRewardEpochId(10);

        vm.prank(voters[0]);
        pollingManagementGroup.setProxyVoter(proxyVoter);
        address proxy2 = makeAddr("proxy2");
        vm.prank(voters[5]);
        pollingManagementGroup.setProxyVoter(proxy2);

        assertEq(pollingManagementGroup.canPropose(voters[0]), true);
        assertEq(pollingManagementGroup.canPropose(proxyVoter), true);
        assertEq(pollingManagementGroup.canPropose(voters[1]), true);
        assertEq(pollingManagementGroup.canPropose(voters[2]), true);
        assertEq(pollingManagementGroup.canPropose(voters[3]), true);
        assertEq(pollingManagementGroup.canPropose(voters[4]), true);
        assertEq(pollingManagementGroup.canPropose(voters[5]), false);
        assertEq(pollingManagementGroup.canPropose(proxy2), false);
        assertEq(pollingManagementGroup.canPropose(maintainer), false);

        // create proposal
        vm.warp(123);
        vm.prank(maintainer);
        vm.deal(maintainer, 1 ether);
        pollingManagementGroup.proposeWithSettings("proposal1", settings);

        assertEq(pollingManagementGroup.canVote(voters[0], 1), true);
        assertEq(pollingManagementGroup.canVote(proxyVoter, 1), true);
        assertEq(pollingManagementGroup.canVote(voters[1], 1), true);
        assertEq(pollingManagementGroup.canVote(voters[2], 1), true);
        assertEq(pollingManagementGroup.canVote(voters[3], 1), true);
        assertEq(pollingManagementGroup.canVote(voters[4], 1), true);
        assertEq(pollingManagementGroup.canVote(voters[5], 1), false);
        assertEq(pollingManagementGroup.canVote(proxy2, 1), false);
        assertEq(pollingManagementGroup.canVote(maintainer, 1), false);
    }

    // only maintainer can create proposals with settings
    function testProposeRejectionRevert() public {
        vm.expectRevert("only maintainer");
        pollingManagementGroup.proposeWithSettings("reject proposal", settings);
    }

    function testCreateProposeRejection() public {
        uint256 currentRewardEpoch = 10;
        _mockGetCurrentRewardEpochId(currentRewardEpoch);
        vm.warp(123);

        vm.prank(maintainer);
        vm.expectEmit();
        emit ManagementGroupProposalCreated(
            1,
            maintainer,
            "rejection based proposal",
            123, // settings.votingStartTs = 0; block.timestamp = 123
            123 + 7200,
            6000,
            5000,
            members,
            false
        );
        settings.accept = false;
        pollingManagementGroup.proposeWithSettings("rejection based proposal", settings);
    }

    // threshold reached but majority votes in favor
    function testRejectionProposalSuccessful() public {
        testCreateProposeRejection();

        // voters 1 and 2 vote (in favor)
        vm.prank(voters[0]);
        vm.expectEmit();
        emit VoteCast(voters[0], 1, 1, 1, 0);
        pollingManagementGroup.castVote(1, 1);
        vm.prank(voters[1]);
        vm.expectEmit();
        emit VoteCast(voters[1], 1, 1, 2, 0);
        pollingManagementGroup.castVote(1, 1);
        for (uint256 i = 0; i < 2; i++) {
            assertEq(pollingManagementGroup.hasVoted(1, voters[i]), true);
        }
        (uint256 votesFor, uint256 votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 2);
        assertEq(votesAgainst, 0);

        // voters 3 and 4 votes against; threshold is reached but majority is not against
        vm.prank(voters[2]);
        vm.expectEmit();
        emit VoteCast(voters[2], 1, 0, 2, 1);
        pollingManagementGroup.castVote(1, 0);
        vm.prank(voters[3]);
        vm.expectEmit();
        emit VoteCast(voters[3], 1, 0, 2, 2);
        pollingManagementGroup.castVote(1, 0);
        (votesFor, votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 2);
        assertEq(votesAgainst, 2);

        // move to the end of the voting period; proposal is successful (not defeated)
        vm.warp(123 + 7200);
        assertEq(uint256(pollingManagementGroup.state(1)), 4);
    }

    // majority opposes the proposal but threshold is not reached
    function testRejectionProposalSuccessful1() public {
        testCreateProposeRejection();

        // voters 1 and 2 vote (against)
        vm.prank(voters[0]);
        vm.expectEmit();
        emit VoteCast(voters[0], 1, 0, 0, 1);
        pollingManagementGroup.castVote(1, 0);
        vm.prank(voters[1]);
        vm.expectEmit();
        emit VoteCast(voters[1], 1, 0, 0, 2);
        pollingManagementGroup.castVote(1, 0);
        for (uint256 i = 0; i < 2; i++) {
            assertEq(pollingManagementGroup.hasVoted(1, voters[i]), true);
        }
        (uint256 votesFor, uint256 votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 2);

        // move to the end of the voting period
        vm.warp(123 + 7200);
        assertEq(uint256(pollingManagementGroup.state(1)), 4);
    }

    // majority opposes the proposal and threshold is reached
    function testRejectionProposalDefeated() public {
        testCreateProposeRejection();
        assertEq(uint256(pollingManagementGroup.state(1)), 2);

        // voters 1, 2 and 3 vote (against)
        uint256 vpAgainst = 0;
        for (uint256 i = 0; i < 3; i++) {
            vpAgainst += 1;
            vm.prank(voters[i]);
            vm.expectEmit();
            emit VoteCast(voters[i], 1, 0, 0, vpAgainst);
            pollingManagementGroup.castVote(1, 0);
        }
        // voter 4 votes in favor
        vm.prank(voters[3]);
        vm.expectEmit();
        emit VoteCast(voters[3], 1, 1, 1, 3);
        pollingManagementGroup.castVote(1, 1);
        for (uint256 i = 0; i < 4; i++) {
            assertEq(pollingManagementGroup.hasVoted(1, voters[i]), true);
        }
        (uint256 votesFor, uint256 votesAgainst) = pollingManagementGroup.getProposalVotes(1);
        assertEq(votesFor, 1);
        assertEq(votesAgainst, 3);

        // move to the end of the voting period
        vm.warp(123 + 7200);
        assertEq(uint256(pollingManagementGroup.state(1)), 3);
    }

    function testAddMemberRevertAlreadyMember() public {
        vm.prank(members[0]);
        vm.expectRevert("voter is already a member of the management group");
        pollingManagementGroup.addMember();
    }

    function testAddMemberRevertChilled() public {
        // current reward epoch is 8
        _mockChilledUntilRewardEpochId(voters[6], 5);
        vm.warp(7 * DAY_TO_SECONDS);
        vm.startPrank(voters[6]);
        vm.expectRevert("recently chilled");
        pollingManagementGroup.addMember();
        // move to the next reward epoch
        _mockGetCurrentRewardEpochId(9);
        vm.expectRevert("recently chilled");
        pollingManagementGroup.addMember();
        // move to the next reward epoch
        _mockGetCurrentRewardEpochId(10);
        // not chilled anymore -> no "recently chilled" revert
        vm.expectRevert(bytes("")); // evm revert
        pollingManagementGroup.addMember();
        vm.stopPrank();
    }

    // noOfWeightBasedClaims == 0
    function testAddMemberRevertNoRewards1() public {
        vm.warp(7 * DAY_TO_SECONDS);
        _mockChilledUntilRewardEpochId(voters[6], 0);
        uint256 currentRewardEpoch = 10;
        _mockGetCurrentRewardEpochId(currentRewardEpoch);
        _mockGetVPBlock(currentRewardEpoch - 1, 123);
        address delegationAddress = makeAddr("delegationAddress");
        _mockGetDelegationAddress(voters[6], delegationAddress, 123);
        _mockRewardManagerId();
        _mockGetUnclaimedRewardState(delegationAddress, currentRewardEpoch - 1, false);
        _mockNoOfWeightBasedClaims(currentRewardEpoch - 1, 0);
        _mockRewardsHash(currentRewardEpoch - 1, bytes32("rewardsHash"));
        vm.startPrank(voters[6]);
        vm.expectRevert("no rewards");
        pollingManagementGroup.addMember();
    }

    // noOfWeightBasedClaims != 0
    function testAddMemberRevertNoRewards2() public {
        vm.warp(7 * DAY_TO_SECONDS);
        _mockChilledUntilRewardEpochId(voters[6], 0);
        _mockRewardManagerId();
        uint256 currentRewardEpoch = 10;
        _mockGetCurrentRewardEpochId(currentRewardEpoch);
        _mockGetVPBlock(currentRewardEpoch - 1, 123);
        address delegationAddress = makeAddr("delegationAddress");
        _mockGetDelegationAddress(voters[6], delegationAddress, 123);
        _mockGetUnclaimedRewardState(delegationAddress, currentRewardEpoch - 1, false);
        _mockNoOfWeightBasedClaims(currentRewardEpoch - 1, 10);
        _mockNoOfInitialisedWeightBasedClaims(currentRewardEpoch - 1, 10);
        vm.startPrank(voters[6]);
        vm.expectRevert("no rewards");
        pollingManagementGroup.addMember();
    }

    function testAddMemberRevertNotEnoughInitialised() public {
        vm.warp(7 * DAY_TO_SECONDS);
        _mockChilledUntilRewardEpochId(voters[6], 0);
        _mockRewardManagerId();
        uint256 epoch = 10;
        _mockGetCurrentRewardEpochId(epoch);
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        while (epoch > 0) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[6], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, false);
            _mockNoOfWeightBasedClaims(epoch - 1, 0);
            _mockRewardsHash(epoch - 1, bytes32(0));
            epoch--;
            vpBlock *= 2;
        }
        vm.startPrank(voters[6]);
        vm.expectRevert("not enough initialised epochs");
        pollingManagementGroup.addMember();
    }

    function testAddMember() public {
        vm.warp(7 * DAY_TO_SECONDS);
        _mockChilledUntilRewardEpochId(voters[6], 0);
        _mockRewardManagerId();
        uint256 epoch = 10;
        _mockGetCurrentRewardEpochId(epoch);
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        while (epoch > pollingManagementGroup.addAfterRewardedEpochs()) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[6], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, true);
            epoch--;
            vpBlock *= 2;
        }
        assertEq(pollingManagementGroup.isMember(voters[6]), false);
        vm.startPrank(voters[6]);
        vm.expectEmit();
        emit ManagementGroupMemberAdded(voters[6]);
        pollingManagementGroup.addMember();
        assertEq(pollingManagementGroup.isMember(voters[6]), true);
    }

    function testRemoveMemberRevertNotMember() public {
        vm.expectRevert("voter is not a member of the management group");
        pollingManagementGroup.removeMember(voters[6]);
    }

    // voter was added in epoch 8, not enough epochs passed and not enough proposals were created
    function testRemoveMemberRevert1() public {
        _mockGetCurrentRewardEpochId(10);
        _mockChilledUntilRewardEpochId(voters[0], 0);
        vm.expectRevert("cannot remove member");
        pollingManagementGroup.removeMember(voters[0]);

    }

    // didn't receive rewards in the last initialised reward epochs
    function testRemoveMember1() public {
        _mockChilledUntilRewardEpochId(voters[0], 0);
        _mockRewardManagerId();
        uint256 epoch = 11;
        _mockGetCurrentRewardEpochId(epoch);
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        while (epoch > pollingManagementGroup.removeAfterNotRewardedEpochs()) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[0], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, false);
            _mockNoOfWeightBasedClaims(epoch - 1, 0);
            _mockRewardsHash(epoch - 1, bytes32("hash"));
            epoch--;
            vpBlock *= 2;
        }
        assertEq(pollingManagementGroup.isMember(voters[0]), true);
        vm.expectEmit();
        emit ManagementGroupMemberRemoved(voters[0]);
        pollingManagementGroup.removeMember(voters[0]);
        assertEq(pollingManagementGroup.isMember(voters[0]), false);
    }

    // voter was receiving rewards (up to epoch when voter was added)
    function testRemoveMemberRevert2() public {
        _mockChilledUntilRewardEpochId(voters[6], 0);
        testAddMember(); // voter was added in epoch 10
        _mockRewardManagerId();
        uint256 epoch = 13;
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        _mockGetCurrentRewardEpochId(epoch);
        while (epoch > 9) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[6], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, false);
            _mockNoOfWeightBasedClaims(epoch - 1, 0);
            _mockRewardsHash(epoch - 1, bytes32(0));
            epoch--;
            vpBlock *= 2;
        }
        vm.expectRevert("cannot remove member");
        pollingManagementGroup.removeMember(voters[6]);
    }

    // voter received rewards in the last initialised reward epochs
    function testRemoveMemberRevert3() public {
        _mockChilledUntilRewardEpochId(voters[0], 0);
        _mockRewardManagerId();
        uint256 epoch = 11;
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        _mockGetCurrentRewardEpochId(epoch);
        _mockGetVPBlock(epoch - 1, vpBlock);
        _mockGetDelegationAddress(voters[0], delegationAddress, vpBlock);
        _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, true);
        vm.expectRevert("cannot remove member");
        pollingManagementGroup.removeMember(voters[0]);
    }

    // not enough initialised epochs to remove voter
    function testRemoveMemberRevert4() public {
        _mockChilledUntilRewardEpochId(voters[7], 0);
        _mockGetCurrentRewardEpochId(0);
        vm.prank(maintainer);
        address[] memory membersToAdd = new address[](1);
        membersToAdd[0] = voters[7];
        pollingManagementGroup.changeManagementGroupMembers(membersToAdd, new address[](0));
        _mockRewardManagerId();
        uint256 epoch = 11;
        _mockGetCurrentRewardEpochId(epoch);
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        for (uint256 i = 0; i < pollingManagementGroup.removeAfterNotRewardedEpochs() - 1; i++) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[7], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, false);
            _mockNoOfWeightBasedClaims(epoch - 1, 8);
            _mockNoOfInitialisedWeightBasedClaims(epoch - 1, 8);
            epoch--;
            vpBlock *= 2;
        }
        while (epoch > 0) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[7], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, false);
            _mockNoOfWeightBasedClaims(epoch - 1, 8);
            _mockNoOfInitialisedWeightBasedClaims(epoch - 1, 7);
            epoch--;
            vpBlock *= 2;
        }
        vm.expectRevert("cannot remove member");
        pollingManagementGroup.removeMember(voters[7]);
    }

    // voter didn't participate but there was not enough relevant proposals
    function testRemoveMemberRevert5() public {
        _mockChilledUntilRewardEpochId(voters[0], 0);
        _mockRewardManagerId();
        uint256 epoch = 13;
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        _mockGetCurrentRewardEpochId(epoch);
        while (epoch > 0) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[0], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, false);
            _mockNoOfWeightBasedClaims(epoch - 1, 0);
            _mockRewardsHash(epoch - 1, bytes32(0));
            epoch--;
            vpBlock *= 2;
        }

        // create 3 proposals
        vm.startPrank(proposer);
        pollingManagementGroup.propose{ value: 100 } ("proposal1");
        pollingManagementGroup.propose{ value: 100 } ("proposal2");
        vm.stopPrank();
        // move to voting period
        vm.warp(123 + 3600);
        vm.startPrank(voters[1]);
        pollingManagementGroup.castVote(1, 1);
        pollingManagementGroup.castVote(2, 1);
        vm.stopPrank();
        // move to the end of voting period
        vm.warp(123 + 3600 + 7200);

        // create another proposal
        vm.prank(proposer);
        pollingManagementGroup.propose{ value: 100 } ("proposal3");
        // move to voting period
        vm.warp(123 + 3600 + 7200 + 3600);
        vm.prank(voters[0]);
        pollingManagementGroup.castVote(3, 1);

        // there were three proposals; voter0 didn't participate in two of them; one is not yet finished
        vm.expectRevert("cannot remove member");
        pollingManagementGroup.removeMember(voters[0]);
    }

    // voter didn't participate but there was not enough relevant proposals
    function testRemoveMemberRevert6() public {
        _mockChilledUntilRewardEpochId(voters[0], 0);
        _mockRewardManagerId();
        uint256 epoch = 13;
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        _mockGetCurrentRewardEpochId(epoch);
        while (epoch > 0) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[0], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, false);
            _mockNoOfWeightBasedClaims(epoch - 1, 0);
            _mockRewardsHash(epoch - 1, bytes32(0));
            epoch--;
            vpBlock *= 2;
        }

        // create 2 proposals
        vm.startPrank(proposer);
        pollingManagementGroup.propose{ value: 100 } ("proposal1");
        pollingManagementGroup.propose{ value: 100 } ("proposal2");
        vm.stopPrank();
        // move to voting period
        vm.warp(123 + 3600);
        // quorums is reached for one proposal
        for (uint256 i = 1; i < 4; i++) {
            vm.startPrank(voters[i]);
            pollingManagementGroup.castVote(1, 1);
            vm.stopPrank();
        }
        // move to the end of voting period
        vm.warp(123 + 3600 + 7200);

        // there were three proposals; voter0 didn't participate in two of them; one is not yet finished
        vm.expectRevert("cannot remove member");
        pollingManagementGroup.removeMember(voters[0]);
    }

    function testRemoveMember2() public {
        _mockChilledUntilRewardEpochId(voters[0], 0);
        _mockRewardManagerId();
        uint256 epoch = 13;
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        _mockGetCurrentRewardEpochId(epoch);
        while (epoch > 0) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[0], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, false);
            _mockNoOfWeightBasedClaims(epoch - 1, 0);
            _mockRewardsHash(epoch - 1, bytes32(0));
            epoch--;
            vpBlock *= 2;
        }

        // create 2 proposals
        vm.startPrank(proposer);
        pollingManagementGroup.propose{ value: 100 } ("proposal1");
        pollingManagementGroup.propose{ value: 100 } ("proposal2");
        vm.stopPrank();
        // move to voting period
        vm.warp(123 + 3600);
        // quorums is reached for one proposal
        for (uint256 i = 1; i < 4; i++) {
            vm.startPrank(voters[i]);
            pollingManagementGroup.castVote(1, 1);
            pollingManagementGroup.castVote(2, 1);
            vm.stopPrank();
        }
        // move to the end of voting period
        vm.warp(123 + 3600 + 7200);

        // there were three proposals; voter0 didn't participate in two of them; one is not yet finished
        assertEq(pollingManagementGroup.isMember(voters[0]), true);
        pollingManagementGroup.removeMember(voters[0]);
        assertEq(pollingManagementGroup.isMember(voters[0]), false);
    }

    // voter was chilled in the last reward epochs
    function testRemoveMember3() public {
        // voter was added in reward epoch 8
        _mockGetCurrentRewardEpochId(19);
        _mockChilledUntilRewardEpochId(voters[0], 15);
        _mockChilledUntilRewardEpochId(voters[1], 15);
        vm.warp(7 * DAY_TO_SECONDS);
        vm.expectEmit();
        emit ManagementGroupMemberRemoved(voters[0]);
        pollingManagementGroup.removeMember(voters[0]);

        // move to the reward epoch 20
        _mockRewardManagerId();
        uint256 epoch = 20;
        address delegationAddress = makeAddr("delegationAddress");
        uint256 vpBlock = 123;
        _mockGetCurrentRewardEpochId(epoch);
        while (epoch > 0) {
            _mockGetVPBlock(epoch - 1, vpBlock);
            _mockGetDelegationAddress(voters[1], delegationAddress, vpBlock);
            _mockGetUnclaimedRewardState(delegationAddress, epoch - 1, false);
            _mockNoOfWeightBasedClaims(epoch - 1, 0);
            _mockRewardsHash(epoch - 1, bytes32(0));
            epoch--;
            vpBlock *= 2;
        }
        // enough time passed since voter has been chilled and it can't be removed anymore
        vm.expectRevert("cannot remove member");
        pollingManagementGroup.removeMember(voters[1]);
    }

    function testAddMemberRevertRecentlyRemoved() public {
        testRemoveMember2();
        vm.prank(voters[0]);
        vm.expectRevert("recently removed");
        pollingManagementGroup.addMember();
    }

    function testViewMethodsProxy() public {
        // proposal doesn't exist yet
        assertEq(pollingManagementGroup.canVote(voters[0], 1), false);
        assertEq(pollingManagementGroup.canVote(proxyVoter, 1), false);
        // create a proposal
        vm.warp(123);
        vm.prank(maintainer);
        vm.deal(maintainer, 1 ether);
        pollingManagementGroup.proposeWithSettings("proposal1", settings);
        assertEq(pollingManagementGroup.hasVoted(1, voters[0]), false);
        assertEq(pollingManagementGroup.hasVoted(1, proxyVoter), false);
        // move to the voting period
        vm.warp(123 + 3600);
        vm.prank(voters[0]);
        pollingManagementGroup.castVote(1, 1);

        // is member
        assertEq(pollingManagementGroup.isMember(voters[0]), true);
        assertEq(pollingManagementGroup.isMember(proxyVoter), false);
        // can propose
        assertEq(pollingManagementGroup.canPropose(voters[0]), true);
        assertEq(pollingManagementGroup.canPropose(proxyVoter), false);
        // can vote
        assertEq(pollingManagementGroup.canVote(voters[0], 1), true);
        assertEq(pollingManagementGroup.canVote(proxyVoter, 1), false);
        // has voted
        assertEq(pollingManagementGroup.hasVoted(1, voters[0]), true);
        assertEq(pollingManagementGroup.hasVoted(1, proxyVoter), false);

        // set proxy voter for first registered voter
        vm.prank(voters[0]);
        pollingManagementGroup.setProxyVoter(proxyVoter);

        // is member
        assertEq(pollingManagementGroup.isMember(voters[0]), true);
        assertEq(pollingManagementGroup.isMember(proxyVoter), true);
        // can propose
        assertEq(pollingManagementGroup.canPropose(voters[0]), true);
        assertEq(pollingManagementGroup.canPropose(proxyVoter), true);
        // can vote
        assertEq(pollingManagementGroup.canVote(voters[0], 1), true);
        assertEq(pollingManagementGroup.canVote(proxyVoter, 1), true);
        // has voted
        assertEq(pollingManagementGroup.hasVoted(1, voters[0]), true);
        assertEq(pollingManagementGroup.hasVoted(1, proxyVoter), true);
    }


    /////// helper functions
    function _mockGetCurrentRewardEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _createVoters(uint256 _numOfVoters) private {
        for (uint256 i = 0; i < _numOfVoters; i++) {
            voters.push(makeAddr(string.concat("voter", vm.toString(i))));
        }
    }

    function _mockChilledUntilRewardEpochId(address _voter, uint256 _epoch) private {
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IVoterRegistry.chilledUntilRewardEpochId.selector, bytes20(_voter)),
            abi.encode(_epoch)
        );
    }

    function _mockGetVPBlock(uint256 _rewardEpoch, uint256 _vpBlock) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getVotePowerBlock.selector, _rewardEpoch),
            abi.encode(_vpBlock)
        );
    }

    function _mockGetDelegationAddress(address _voter, address _delegationAddress, uint256 _block) private {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IEntityManager.getDelegationAddressOfAt.selector, _voter, _block),
            abi.encode(_delegationAddress)
        );
    }

    function _mockGetUnclaimedRewardState(
        address _delegationAddress,
        uint256 _rewardEpoch,
        bool _initialised
    )
        private
    {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(
                IRewardManager.getUnclaimedRewardState.selector,
                _delegationAddress,
                _rewardEpoch,
                RewardsV2Interface.ClaimType.WNAT
            ),
            abi.encode(IRewardManager.UnclaimedRewardState(_initialised, uint120(0), uint128(0)))
        );
    }

    function _mockNoOfWeightBasedClaims(uint256 _rewardEpoch, uint256 _noOf) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.noOfWeightBasedClaims.selector, _rewardEpoch),
            abi.encode(_noOf)
        );
    }

    function _mockRewardManagerId() private {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IRewardManager.rewardManagerId.selector),
            abi.encode(1)
        );
    }

    function _mockRewardsHash(uint256 _rewardEpoch, bytes32 _hash) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.rewardsHash.selector, _rewardEpoch),
            abi.encode(_hash)
        );
    }

    function _mockNoOfInitialisedWeightBasedClaims(uint256 _rewardEpoch, uint256 _noOf) private {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IRewardManager.noOfInitialisedWeightBasedClaims.selector, _rewardEpoch),
            abi.encode(_noOf)
        );
    }

}