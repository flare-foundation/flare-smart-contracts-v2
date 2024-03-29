// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/governance/implementation/PollingFoundation.sol";
import "../../../mock/ExecuteMock.sol";
import "../../../mock/ExecuteMockSquare.sol";

// solhint-disable-next-line max-states-count
contract PollingFoundationTest is Test {

    address payable constant internal BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);
    uint256 internal constant MAX_BIPS = 1e4;

    PollingFoundation private pollingFoundation;

    address private governance;
    address private governanceSettings;
    address private addressUpdater;
    address private mockFlareSystemsManager;
    address private mockSupply;
    address private mockSubmission;
    address private mockGovernanceVotePower;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private voters;
    uint256[] private privateKeys;
    uint256[] private votePowers;
    address[] private proposers;

    uint256 private proposalId;
    uint256 private vpBlock;

    address[] private targets;
    uint256[] private values;
    bytes[] private calldatas;

    ExecuteMock private executeMock;
    ExecuteMockSquare private executeMockSquare;

    IIPollingFoundation.GovernorSettingsWithoutExecParams private settings;
    IGovernor.GovernorSettings private settingsExec;

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votePower,
        string reason,
        uint256 forVotePower,
        uint256 againstVotePower
    );

    event ProposalExecuted(uint256 indexed proposalId);


    function setUp() public {
        governance = makeAddr("governance");
        governanceSettings = makeAddr("governanceSettings");
        addressUpdater = makeAddr("addressUpdater");
        _createProposers(3);
        pollingFoundation = new PollingFoundation(
            IGovernanceSettings(governanceSettings),
            governance,
            addressUpdater,
            proposers
        );

        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockSupply = makeAddr("mockSupply");
        mockSubmission = makeAddr("mockSubmission");
        mockGovernanceVotePower = makeAddr("mockGovernanceVotePower");
        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("Supply"));
        contractNameHashes[3] = keccak256(abi.encode("Submission"));
        contractNameHashes[4] = keccak256(abi.encode("GovernanceVotePower"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        contractAddresses[2] = mockSupply;
        contractAddresses[3] = mockSubmission;
        contractAddresses[4] = mockGovernanceVotePower;
        pollingFoundation.updateContractAddresses(contractNameHashes, contractAddresses);

        _createVoters(4);

        executeMock = new ExecuteMock();
        executeMockSquare = new ExecuteMockSquare();
    }

    function testCheckChainId() public {
        assertEq(pollingFoundation.version(), "2");
        assertEq(pollingFoundation.name(), "PollingFoundation");
        assertEq(pollingFoundation.chainId(), block.chainid);
    }

    function testChangeProposers() public {
        assertEq(pollingFoundation.isProposer(proposers[0]), true);
        assertEq(pollingFoundation.isProposer(proposers[1]), true);
        assertEq(pollingFoundation.isProposer(proposers[2]), true);
        address newProposer = makeAddr("newProposer");
        assertEq(pollingFoundation.isProposer(newProposer), false);

        // change proposers
        vm.prank(governance);
        address[] memory proposersToAdd = new address[](1);
        proposersToAdd[0] = newProposer;
        address[] memory proposersToRemove = new address[](2);
        proposersToRemove[0] = proposers[0];
        proposersToRemove[1] = proposers[1];
        pollingFoundation.changeProposers(proposersToAdd, proposersToRemove);
        assertEq(pollingFoundation.isProposer(proposers[0]), false);
        assertEq(pollingFoundation.isProposer(proposers[1]), false);
        assertEq(pollingFoundation.isProposer(proposers[2]), true);
        assertEq(pollingFoundation.isProposer(newProposer), true);
    }


    // propose (without on-chain execution) tests
    function testProposeRevertNotEligible() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        vm.warp(100);
        vm.roll(100);

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 6000,
            majorityConditionBIPS: 5000
        });
        vm.expectRevert("submitter is not eligible to submit a proposal");
        pollingFoundation.propose("proposalAccept", settings);
    }

    function testProposeRevertVotingPeriodTooLow() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        vm.warp(100);
        vm.roll(100);

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp,
            votingPeriodSeconds: 0,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 6000,
            majorityConditionBIPS: 5000
        });
        vm.prank(proposers[0]);
        vm.expectRevert("voting period too low");
        pollingFoundation.propose("proposalAccept", settings);
    }

    function testProposeRevertInvalidThreshold() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        vm.warp(100);
        vm.roll(100);

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: MAX_BIPS + 1,
            majorityConditionBIPS: 5000
        });
        vm.prank(proposers[0]);
        vm.expectRevert("invalid thresholdConditionBIPS");
        pollingFoundation.propose("proposalAccept", settings);
    }

    function testProposeRevertInvalidMajorityCondition() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        vm.warp(100);
        vm.roll(100);

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 3000,
            majorityConditionBIPS: 1000
        });
        vm.prank(proposers[0]);
        vm.expectRevert("invalid majorityConditionBIPS");
        pollingFoundation.propose("proposalAccept", settings);
    }

    function testProposeRevertVPBlockTooFarInThePast() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(300);

        vm.warp(200);
        vm.roll(200);

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: false,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000
        });
        proposalId = _getProposalId("proposalReject");

        // proposal does not exist yet
        vm.expectRevert("unknown proposal id");
        pollingFoundation.state(proposalId);

        vm.prank(proposers[0]);
        vm.expectRevert("vote power block is too far in the past");
        pollingFoundation.propose("proposalReject", settings);
    }


    // reject, non-executable on-chain proposal
    function testCreateRejectProposal() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(200);
        vm.roll(200);

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: false,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000
        });
        proposalId = _getProposalId("proposalReject");

        // proposal does not exist yet
        vm.expectRevert("unknown proposal id");
        pollingFoundation.state(proposalId);

        vm.prank(proposers[0]);
        pollingFoundation.propose("proposalReject", settings);

        (address proposer, bool accept, uint256 _vpBlock,
            uint256 startTime, uint256 endTime, , ,
            uint256 threshold, uint256 majority, uint256 supply,
            string memory description) = pollingFoundation.getProposalInfo(proposalId);
        assertEq(proposer, proposers[0]);
        assertEq(accept, false);
        assertEq(startTime, block.timestamp + 100);
        assertEq(endTime, block.timestamp + 100 + 3600);
        assertEq(threshold, 7500);
        assertEq(majority, 6000);
        assertEq(supply, 1000);
        assertEq(description, "proposalReject");
        vpBlock = _vpBlock;
    }

    function testCancelProposal() public {
        testCreateRejectProposal();

        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

        vm.prank(proposers[0]);
        pollingFoundation.cancel(proposalId);
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testCancelProposalRevertAlreadyCanceled() public {
        testCancelProposal();
        vm.expectRevert("proposal is already canceled");
        pollingFoundation.cancel(proposalId);
    }

    function testCancelProposalRevertOnlyProposer() public {
        testCreateRejectProposal();
        vm.expectRevert("proposal can only be canceled by its proposer");
        pollingFoundation.cancel(proposalId);
    }

    function testCancelProposalRevertOnlyBeforeVoting() public {
        testCreateRejectProposal();

        vm.warp(block.timestamp + 100);
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Active));

        vm.prank(proposers[0]);
        vm.expectRevert("proposal can only be canceled before voting starts");
        pollingFoundation.cancel(proposalId);
    }

    function testCastVoteRevertNotActive() public {
        testCreateRejectProposal();
        vm.prank(voters[0]);
        vm.expectRevert("proposal not active");
        pollingFoundation.castVote(proposalId, 0);
    }

    function testCastVote() public {
        testCreateRejectProposal();
        _setVotePowers(4, vpBlock);
        // voting starts
        vm.warp(block.timestamp + 100);

        // voter0 votes against
        vm.prank(voters[0]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter1 votes against
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter2 votes against
        vm.startPrank(voters[2]);
        vm.expectEmit();
        uint256 vpVoter2 = pollingFoundation.getVotes(voters[2], vpBlock);
        emit VoteCast(
            voters[2],
            proposalId,
            uint8(GovernorVotes.VoteType.Against),
            vpVoter2,
            "bad proposal",
            0,
            600
        );
        pollingFoundation.castVoteWithReason(proposalId, uint8(GovernorVotes.VoteType.Against), "bad proposal");
        vm.stopPrank();

        // voter3 votes for
        vm.prank(voters[3]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        (uint256 forVotes, uint256 againstVotes) = pollingFoundation.getProposalVotes(proposalId);
        assertEq(forVotes, 400);
        assertEq(againstVotes, 600);

        vm.prank(proposers[0]);
        vm.expectRevert("proposal not in execution state");
        pollingFoundation.execute(proposalId);
    }

    function testCastVoteRevertVotingTwice() public {
        testCastVote();

        vm.prank(voters[0]);
        vm.expectRevert("vote already cast");
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));
    }

    function testCastVoteBySig() public {
        testCreateRejectProposal();
        _setVotePowers(4, vpBlock);
        // voting starts
        vm.warp(block.timestamp + 100);

        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 hashedName = keccak256(bytes("PollingFoundation"));
        bytes32 hashedVersion = keccak256(bytes("2"));
        bytes32 domainSeparator = keccak256(abi.encode(
            typeHash, hashedName, hashedVersion, pollingFoundation.chainId(), address(pollingFoundation)));
        bytes32 structHash = keccak256(abi.encode(
            pollingFoundation.BALLOT_TYPEHASH(), proposalId, uint8(GovernorVotes.VoteType.Against))
        );
        bytes32 hashTypedDataV4 = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(hashTypedDataV4);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[0], messageHash);

        // voter0 votes by sig
        vm.expectEmit();
        emit VoteCast(voters[0], proposalId, uint8(GovernorVotes.VoteType.Against), 100, "", 0, 100);
        pollingFoundation.castVoteBySig(proposalId, uint8(GovernorVotes.VoteType.Against), v, r, s);

        assertTrue(pollingFoundation.hasVoted(proposalId, voters[0]));
    }

    function testCastVoteRevertInvalidValue() public {
        testCreateRejectProposal();
        _setVotePowers(4, vpBlock);
        // voting starts
        vm.warp(block.timestamp + 100);

        vm.prank(voters[0]);
        vm.expectRevert("invalid value for enum VoteType");
        pollingFoundation.castVote(proposalId, 2);
    }

    function testExecuteRevertNotInExecutionState() public {
        testCastVote();
        vm.prank(proposers[0]);
        vm.expectRevert("proposal not in execution state");
        pollingFoundation.execute(proposalId);
    }

    function testExecute() public {
        testCastVote();

        // voting ends
        vm.warp(block.timestamp + 3600);

        // proposal is successful
        // (more vote power is against than in favor but for rejection type
        // it is accepted unless enough vote power is against - majority reached)
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Queued));
        vm.warp(block.timestamp + 3600);
        vm.prank(proposers[0]);
        vm.expectEmit();
        emit ProposalExecuted(proposalId);
        pollingFoundation.execute(proposalId);
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }

    function testExecuteRevertOnlyProposer() public {
        testCastVote();

        // voting ends
        vm.warp(block.timestamp + 3600);

        vm.expectRevert("proposal can only be executed by its proposer");
        pollingFoundation.execute(proposalId);
    }

    function testExecuteRevertAlreadyExecuted() public {
        testExecute();
        vm.expectRevert("proposal already executed");
        pollingFoundation.execute(proposalId);
    }

    function testProposalSuccessful() public {
        testCreateRejectProposal();

        _setVotePowers(4, vpBlock);
        // voting starts
        vm.warp(block.timestamp + 100);

        // voter0 votes against
        vm.prank(voters[0]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter1 votes against
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter3 votes against
        vm.prank(voters[3]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voting ends
        vm.warp(block.timestamp + 3600);

        // proposal is successful
        // (majority is against but threshold is not reached)
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Queued));
    }


    function testProposalDefeated() public {
        testCreateRejectProposal();

        _setVotePowers(4, vpBlock);
        // voting starts
        vm.warp(block.timestamp + 100);

        // voter0 votes against
        vm.prank(voters[0]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter1 votes against
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter2 votes against
        vm.prank(voters[2]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter3 votes against
        vm.prank(voters[3]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voting ends
        vm.warp(block.timestamp + 3600);

        // proposal is defeated
        // (majority is in against and threshold is reached)
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));

        //// create another proposal but supply has increased
        _mockGetCirculatingSupply(2000);
        _mockRewardExpiryOffsetSeconds(2 * 7200);
        vm.prank(proposers[0]);
           settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 2000,
            majorityConditionBIPS: 5000
        });
        pollingFoundation.propose("proposalReject2", settings);
        uint256 proposalId2 = _getProposalId("proposalReject2");

        // voting starts
        vm.warp(block.timestamp + 100);

        // voter0 votes against
        vm.prank(voters[0]);
        pollingFoundation.castVote(proposalId2, uint8(GovernorVotes.VoteType.Against));

        // voter1 votes against
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId2, uint8(GovernorVotes.VoteType.Against));

        // voter2 votes against
        vm.prank(voters[2]);
        pollingFoundation.castVote(proposalId2, uint8(GovernorVotes.VoteType.Against));

        // voter3 votes against
        vm.prank(voters[3]);
        pollingFoundation.castVote(proposalId2, uint8(GovernorVotes.VoteType.Against));

        // voting ends
        vm.warp(block.timestamp + 3600);

        // proposal is not successful.
        // Again all voters voted against but supply increased and
        // vote power against was only 50 % of supply
        assertEq(uint256(pollingFoundation.state(proposalId2)), uint256(IGovernor.ProposalState.Defeated));

        (uint256 forVotes, uint256 againstVotes) = pollingFoundation.getProposalVotes(proposalId);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 1000);

        uint256[] memory proposalIds = pollingFoundation.getProposalIds();
        assertEq(proposalIds.length, 2);
        assertEq(proposalIds[0], proposalId);
        assertEq(proposalIds[1], proposalId2);
    }

    function testProposeRevertProposalAlreadyExists() public {
        testCreateRejectProposal();
        vm.prank(proposers[0]);
        vm.expectRevert("proposal already exists");
        pollingFoundation.propose("proposalReject", settings);
    }

    //// reject, executable on-chain proposal
    function testProposeRejectExecOnChain() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(200);
        vm.roll(200);

        settingsExec = IGovernor.GovernorSettings({
            accept: false,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000,
            executionDelaySeconds: 1000,
            executionPeriodSeconds: 2000
        });

        targets = new address[](3);
        targets[0] = address(executeMock);
        targets[1] = address(executeMockSquare);
        targets[2] = address(executeMockSquare);
        values = new uint256[](3);
        values[0] = 1;
        values[1] = 10;
        values[2] = 8;
        calldatas = new bytes[](3);
        calldatas[0] = abi.encodeWithSelector(executeMock.setNum.selector, 3);
        calldatas[1] = abi.encodeWithSelector(executeMockSquare.setSquare.selector, 3);
        calldatas[2] = abi.encodeWithSelector(executeMockSquare.setSquare.selector, 3);

        proposalId = pollingFoundation.getProposalId(targets, values, calldatas, "proposalRejectExecuteOnChain");
        vm.prank(proposers[1]);
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain", settingsExec);

        (address proposer, bool accept, uint256 _vpBlock,
            uint256 startTime, uint256 endTime, uint256 execStartTime, uint256 execEndTime,
            uint256 threshold, uint256 majority, uint256 supply,
            string memory description) = pollingFoundation.getProposalInfo(proposalId);
        assertEq(proposer, proposers[1]);
        assertEq(accept, false);
        assertEq(startTime, block.timestamp + 100);
        assertEq(endTime, startTime + 3600);
        assertEq(execStartTime, endTime + 1000);
        assertEq(execEndTime, execStartTime + 2000);
        assertEq(threshold, 7500);
        assertEq(majority, 6000);
        assertEq(supply, 1000);
        assertEq(description, "proposalRejectExecuteOnChain");

        vpBlock = _vpBlock;
    }

    function testProposeExecutableOnChainRevertInvalidLength() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(200);
        vm.roll(200);

        settingsExec = IGovernor.GovernorSettings({
            accept: false,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000,
            executionDelaySeconds: 1000,
            executionPeriodSeconds: 2000
        });

        targets = new address[](3);
        targets[0] = address(executeMock);
        targets[1] = address(executeMockSquare);
        targets[2] = address(executeMockSquare);
        values = new uint256[](2);
        values[0] = 1;
        values[1] = 10;
        calldatas = new bytes[](3);
        calldatas[0] = abi.encodeWithSelector(executeMock.setNum.selector, 3);
        calldatas[1] = abi.encodeWithSelector(executeMockSquare.setSquare.selector, 3);
        calldatas[2] = abi.encodeWithSelector(executeMockSquare.setSquare.selector, 3);

        vm.prank(proposers[1]);
        vm.expectRevert("invalid proposal length");
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain", settingsExec);

        values = new uint256[](3);
        values[0] = 1;
        values[1] = 10;
        values[2] = 8;
        calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSelector(executeMock.setNum.selector, 3);
        calldatas[1] = abi.encodeWithSelector(executeMockSquare.setSquare.selector, 3);

        vm.prank(proposers[1]);
        vm.expectRevert("invalid proposal length");
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain", settingsExec);
    }


    // proposal is successful
    function testRejectTypeOnChainSuccessful() public {
        testProposeRejectExecOnChain();

        _setVotePowers(4, vpBlock);

        // voting starts
        vm.warp(block.timestamp + 100);

        // voter0 votes against
        vm.prank(voters[0]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter1 votes against
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter2 votes against
        vm.prank(voters[2]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // voter3 votes for
        vm.prank(voters[3]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voting ends
        vm.warp(block.timestamp + 3600);

        // proposal is successful
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // move to execution period
        vm.warp(block.timestamp + 1000);
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        // execute proposal
        assertEq(executeMock.getNum(), 0);
        assertEq(executeMockSquare.getSquare(3), 0);
        assertEq(address(executeMock).balance, 0);
        assertEq(address(executeMockSquare).balance, 0);
        vm.prank(proposers[1]);
        pollingFoundation.execute{value: 19} (proposalId, targets, values, calldatas);

        assertEq(executeMock.getNum(), 3);
        assertEq(executeMockSquare.getSquare(3), 9);
        assertEq(address(executeMock).balance, 1);
        assertEq(address(executeMockSquare).balance, 18);
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }

    function testExecuteRevertExpired() public {
        testProposeRejectExecOnChain();

        // voting starts
        vm.warp(block.timestamp + 100);

        // voting ends
        vm.warp(block.timestamp + 3600);

        // proposal is successful
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // move to execution period
        vm.warp(block.timestamp + 1000);

        // move to end of execution period
        vm.warp(block.timestamp + 2000);

        // proposal is expired
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Expired));
        vm.prank(proposers[1]);
        vm.expectRevert("proposal not in execution state");
        pollingFoundation.execute{value: 19} (proposalId, targets, values, calldatas);
    }

    // propose and execute parameters does not match
    function testExecuteRevertWrongParameters() public {
        testProposeRejectExecOnChain();

        // move to execution period
        vm.warp(block.timestamp + 100 + 3600 + 1000);

        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        targets[0] = address(executeMockSquare);
        vm.prank(proposers[1]);
        vm.expectRevert("execution parameters do not match proposal");
        pollingFoundation.execute{value: 19} (proposalId, targets, values, calldatas);
    }

    function testExecuteRevertWithMessage() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(200);
        vm.roll(200);

        settingsExec = IGovernor.GovernorSettings({
            accept: false,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000,
            executionDelaySeconds: 1000,
            executionPeriodSeconds: 2000
        });

        targets = new address[](2);
        targets[0] = address(executeMock);
        targets[1] = address(executeMockSquare);
        values = new uint256[](2);
        values[0] = 0;
        values[1] = 1;
        calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSelector(executeMock.setNum2.selector, 5);
        calldatas[1] = abi.encodeWithSelector(executeMockSquare.setSquare.selector, 3);

        proposalId = pollingFoundation.getProposalId(targets, values, calldatas, "proposalRejectExecuteOnChain");
        vm.prank(proposers[1]);
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain", settingsExec);

        // move to execution period
        vm.warp(block.timestamp + 100 + 3600 + 1000);

        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        vm.prank(proposers[1]);
        vm.expectRevert("wrong number");
        pollingFoundation.execute {value: 1} (proposalId, targets, values, calldatas);

        assertEq(executeMock.getNum(), 0);
        assertEq(executeMockSquare.getSquare(3), 0);
        assertEq(address(executeMock).balance, 0);
        assertEq(address(executeMockSquare).balance, 0);
    }

    function testExecuteRevertWithoutMessage() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(200);
        vm.roll(200);

        settingsExec = IGovernor.GovernorSettings({
            accept: false,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000,
            executionDelaySeconds: 1000,
            executionPeriodSeconds: 0
        });

        targets = new address[](2);
        targets[0] = address(executeMock);
        targets[1] = address(executeMockSquare);
        values = new uint256[](2);
        values[0] = 1;
        values[1] = 1;
        calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSelector(executeMock.setNum1.selector, 5);
        calldatas[1] = abi.encodeWithSelector(executeMockSquare.setSquare.selector, 3);

        proposalId = pollingFoundation.getProposalId(targets, values, calldatas, "proposalRejectExecuteOnChain");
        vm.prank(proposers[1]);
        vm.expectRevert("execution period too low");
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain", settingsExec);

        // longer execution period
        settingsExec.executionPeriodSeconds = 2000;
        vm.prank(proposers[1]);
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain", settingsExec);

        // move to execution period
        vm.warp(block.timestamp + 100 + 3600 + 1000);

        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        vm.prank(proposers[1]);
        vm.expectRevert();
        pollingFoundation.execute {value: 2} (proposalId, targets, values, calldatas);

        assertEq(executeMock.getNum(), 0);
        assertEq(executeMockSquare.getSquare(3), 0);
        assertEq(address(executeMock).balance, 0);
        assertEq(address(executeMockSquare).balance, 0);
    }

    function testExecuteRevertWrongMsgValue() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(200);
        vm.roll(200);

        settingsExec = IGovernor.GovernorSettings({
            accept: false,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000,
            executionDelaySeconds: 1000,
            executionPeriodSeconds: 0
        });

        targets = new address[](2);
        targets[0] = address(executeMock);
        targets[1] = address(executeMockSquare);
        values = new uint256[](2);
        values[0] = 1;
        values[1] = 1;
        calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSelector(executeMock.setNum.selector, 5);
        calldatas[1] = abi.encodeWithSelector(executeMockSquare.setSquare.selector, 3);

        proposalId = pollingFoundation.getProposalId(targets, values, calldatas, "proposalRejectExecuteOnChain");
        vm.prank(proposers[1]);
        vm.expectRevert("execution period too low");
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain", settingsExec);

        // longer execution period
        settingsExec.executionPeriodSeconds = 2000;
        vm.prank(proposers[1]);
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain", settingsExec);

        // move to execution period
        vm.warp(block.timestamp + 100 + 3600 + 1000);

        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        vm.prank(proposers[1]);
        vm.expectRevert("sum of _values does not equals msg.value");
        pollingFoundation.execute {value: 3} (proposalId, targets, values, calldatas);
    }

    function testMoveExecutionPeriod() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 80, 10);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(200);
        vm.roll(200);

        settingsExec = IGovernor.GovernorSettings({
            accept: false,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 5,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000,
            executionDelaySeconds: 1000,
            executionPeriodSeconds: 2000
        });

        targets = new address[](1);
        targets[0] = address(executeMock);
        values = new uint256[](1);
        values[0] = 1;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(executeMock.setNum.selector, 3);

        proposalId = pollingFoundation.getProposalId(targets, values, calldatas, "proposalRejectExecuteOnChain");
        vm.prank(proposers[1]);
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain", settingsExec);

        (, , , ,  , uint256 executionStartTime, uint256 executionEndTime, , ,  ,) =
            pollingFoundation.getProposalInfo(proposalId);
        assertEq(executionStartTime, block.timestamp + 100 + 3600 + 1000); // 200 + 4700 = 4900
        assertEq(executionEndTime, executionStartTime + 2000); // 4900 + 2000 = 6900

        vm.warp(500);
        vm.roll(300);
        settingsExec.votingPeriodSeconds = 3000;
        uint256 proposal2Id = pollingFoundation.getProposalId(
            targets, values, calldatas, "proposalRejectExecuteOnChain1");
        vm.prank(proposers[1]);
        pollingFoundation.propose(targets, values, calldatas, "proposalRejectExecuteOnChain1", settingsExec);

        // execution start time should be 200 + 500 + 100+ 3600 + 1000 = 5300
        // because that is before execution end time of the previous proposal (6900) it is moved after it
        (, , , ,  , executionStartTime, executionEndTime, , ,  ,) =
            pollingFoundation.getProposalInfo(proposal2Id);
        assertEq(executionStartTime, 6900);
        assertEq(executionEndTime, 6900 + 2000);
    }

    //// accept proposals
    function testAcceptProposal1() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 400, 200);
        _mockGetRewardEpochStartInfo(9, 350, 180);
        _mockGetRewardEpochStartInfo(8, 190, 145);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(80);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(1500);
        vm.roll(1000);

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 1300,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000
        });
        proposalId = _getProposalId("proposalAccept");

        vm.prank(proposers[0]);
        pollingFoundation.propose("proposalAccept", settings);
        (, , vpBlock, , , , , , , ,) = pollingFoundation.getProposalInfo(proposalId);
        _setVotePowers(4, vpBlock);

        // voting starts
        vm.warp(block.timestamp + 100);

        // voter0 votes for
        vm.prank(voters[0]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voter1 votes for
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voter2 votes for
        vm.prank(voters[2]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // end of voting period
        // all voted in favor but threshold is was not reached -> defeated
        vm.warp(block.timestamp + 3600);
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }

    function testAcceptProposal2() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 400, 200);
        _mockGetRewardEpochStartInfo(9, 350, 180);
        _mockGetRewardEpochStartInfo(8, 190, 145);
        _mockGetCleanupBlockNumber(183);
        _mockGetCurrentRandom(360);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(1500);
        vm.roll(1000);

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 1300,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 5000
        });
        proposalId = _getProposalId("proposalAccept");

        vm.prank(proposers[0]);
        pollingFoundation.propose("proposalAccept", settings);
        (, , vpBlock, , , , , , , ,) = pollingFoundation.getProposalInfo(proposalId);
        _setVotePowers(4, vpBlock);

        // voting starts
        vm.warp(block.timestamp + 100);

        // voter0 votes for
        vm.prank(voters[0]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voter1 votes for
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voter2 votes for
        vm.prank(voters[2]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voter3 votes against
        vm.prank(voters[3]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // end of voting period
        // all voted in favor but threshold is was not reached -> defeated
        vm.warp(block.timestamp + 3600);
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Queued));
    }

       function testAcceptProposal3() public {
        _mockGetCurrentRewardEpochId(10);
        _mockGetRewardEpochStartInfo(10, 400, 200);
        _mockGetRewardEpochStartInfo(9, 350, 180);
        _mockGetRewardEpochStartInfo(8, 190, 145);
        _mockGetCleanupBlockNumber(1);
        _mockGetCurrentRandom(450);
        _mockGetCirculatingSupply(1000);
        _mockRewardExpiryOffsetSeconds(7200);

        vm.warp(1500);
        vm.roll(1000);

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp + 100,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 1300,
            thresholdConditionBIPS: 7500,
            majorityConditionBIPS: 6000
        });
        proposalId = _getProposalId("proposalAccept");

        vm.prank(proposers[0]);
        pollingFoundation.propose("proposalAccept", settings);
        (, , vpBlock, , , , , , , ,) = pollingFoundation.getProposalInfo(proposalId);
        _setVotePowers(4, vpBlock);

        // voting starts
        vm.warp(block.timestamp + 100);

        // voter0 votes for
        vm.prank(voters[0]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voter1 votes for
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voter2 votes for
        vm.prank(voters[2]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voter3 votes against
        vm.prank(voters[3]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));

        // end of voting period
        // all voted in favor but threshold is was not reached -> defeated
        vm.warp(block.timestamp + 3600);
        assertEq(uint256(pollingFoundation.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }







    function _mockGetCurrentRewardEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _mockGetRewardEpochStartInfo(uint256 _epochId, uint256 _startTs, uint256 _startBlock) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.getRewardEpochStartInfo.selector, _epochId),
            abi.encode(_startTs, _startBlock)
        );
    }

    function _mockGetCleanupBlockNumber(uint256 _cleanupBlockNumber) private {
        vm.mockCall(
            mockGovernanceVotePower,
            abi.encodeWithSelector(IIGovernanceVotePower.getCleanupBlockNumber.selector),
            abi.encode(_cleanupBlockNumber)
        );
    }

    function _mockGetCurrentRandom(uint256 _random) private {
        vm.mockCall(
            mockSubmission,
            abi.encodeWithSelector(IRandomProvider.getCurrentRandom.selector),
            abi.encode(_random)
        );
    }

    function _createProposers(uint256 _numOfVoters) private {
        for (uint256 i = 0; i < _numOfVoters; i++) {
            proposers.push(makeAddr(string.concat("proposer", vm.toString(i))));
            vm.deal(proposers[i], 1 ether);
        }
    }

    function _createVoters(uint256 _numOfVoters) private {
        address voter;
        uint256 privateKey;
        for (uint256 i = 0; i < _numOfVoters; i++) {
            (voter, privateKey) = makeAddrAndKey(string.concat("voter", vm.toString(i)));
            voters.push(voter);
            privateKeys.push(privateKey);
            votePowers.push((i + 1) * 100);
        }
    }

    function _mockGetCirculatingSupplyAt(uint256 _blockNumber, uint256 _supply) private {
        vm.mockCall(
            mockSupply,
            abi.encodeWithSelector(IISupply.getCirculatingSupplyAt.selector, _blockNumber),
            abi.encode(_supply)
        );
    }

    function _mockGetCirculatingSupply(uint256 _supply) private {
        vm.mockCall(
            mockSupply,
            abi.encodeWithSelector(IISupply.getCirculatingSupplyAt.selector),
            abi.encode(_supply)
        );
    }

    function _mockRewardExpiryOffsetSeconds(uint256 _offsetSeconds) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.rewardExpiryOffsetSeconds.selector),
            abi.encode(_offsetSeconds)
        );
    }

    function _mockVotePowerOfAt(address _owner, uint256 _blockNumber, uint256 _votePower) private {
        vm.mockCall(
            mockGovernanceVotePower,
            abi.encodeWithSelector(IGovernanceVotePower.votePowerOfAt.selector, _owner, _blockNumber),
            abi.encode(_votePower)
        );
    }

    function _setVotePowers(uint256 _numVoters, uint256 _vpBlock) private {
        for (uint256 i = 0; i < _numVoters; i++) {
            _mockVotePowerOfAt(voters[i], _vpBlock, votePowers[i]);
        }
    }

    function _getProposalId(
        string memory _description
    ) private view returns (uint256) {
        return uint256(keccak256(abi.encode(
            pollingFoundation.chainId(),
            address(pollingFoundation),
            new address[](0),
            new uint256[](0),
            new bytes[](0),
            keccak256(bytes(_description))
        )));
    }
}