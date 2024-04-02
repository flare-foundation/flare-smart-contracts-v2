// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../contracts/governance/implementation/PollingFoundation.sol";
import "../../contracts/protocol/implementation/FlareSystemsManager.sol";
import "flare-smart-contracts/contracts/token/interface/IIGovernanceVotePower.sol";
import "../../contracts/userInterfaces/IWNat.sol";
import "flare-smart-contracts/contracts/token/interface/IIVPContract.sol";

// solhint-disable-next-line max-states-count
contract PollingFoundationIntegrationTest is Test {

    address payable constant internal BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);
    uint256 internal constant MAX_BIPS = 1e4;

    PollingFoundation private pollingFoundation;

    address private governance;
    address private governanceSettings;
    address private addressUpdater;
    address private flareDaemon;
    FlareSystemsManager private flareSystemsManager;
    address private mockSupply;
    address private mockSubmission;
    IIGovernanceVotePower private governanceVotePower;
    address private mockVoterRegistry;
    address private mockCleanupBlockNumberManager;
    address private mockRewardManager;
    address private mockRelay;
    IWNat private wNat;
    IIVPContract private vpContract;

    IIPollingFoundation.GovernorSettingsWithoutExecParams private settings;
    IGovernor.GovernorSettings private settingsExec;

    FlareSystemsManager.Settings private fsmSettings;
    FlareSystemsManager.InitialSettings private initialSettings;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private voters;
    uint256[] private privateKeys;
    uint256[] private initialVotePowers;
    address[] private proposers;

    uint16 private constant REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 3360; // 3.5 days
    uint8 private constant VOTING_EPOCH_DURATION_SEC = 90;
    uint64 private constant REWARD_EPOCH_DURATION_IN_SEC =
    uint64(REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS) * VOTING_EPOCH_DURATION_SEC;
    uint24 private constant PPM_MAX = 1e6;

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
        vm.warp(300000);
        vm.roll(150000);

        governance = makeAddr("governance");
        governanceSettings = makeAddr("governanceSettings");
        addressUpdater = makeAddr("addressUpdater");
        flareDaemon = makeAddr("flareDaemon");
        _createProposers(3);
        pollingFoundation = new PollingFoundation(
            IGovernanceSettings(governanceSettings),
            governance,
            addressUpdater,
            proposers
        );

        // flare systems manager
        fsmSettings = FlareSystemsManager.Settings(
            3600 * 8,
            15000,
            3600 * 2,
            0,
            30 * 60,
            20,
            10,
            2,
            500000,
            2,
            280000
        );

        initialSettings = FlareSystemsManager.InitialSettings(
            5,
            0,
            0
        );

        uint32 firstRewardEpochStartVotingRoundId = 10;
        uint256 firstVotingEpochStartTs = block.timestamp - firstRewardEpochStartVotingRoundId * 3600;
        flareSystemsManager = new FlareSystemsManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            fsmSettings,
            uint32(firstVotingEpochStartTs),
            VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            initialSettings
        );

        // deploy contracts (with different solidity version)
        wNat = IWNat(deployCode(
            "artifacts-forge/FlareSmartContracts.sol/WNat.json",
            abi.encode(governance, "Wrapped NAT", "WNat")
        ));
        vpContract = IIVPContract(deployCode(
            "artifacts-forge/FlareSmartContracts.sol/VPContract.json",
            abi.encode(wNat, false)
        ));
        governanceVotePower = IIGovernanceVotePower(deployCode(
            "GovernanceVotePower.sol", abi.encode(wNat, makeAddr("pChain"), makeAddr("cChain"))));

        // set contract addresses
        mockSupply = makeAddr("mockSupply");
        mockSubmission = makeAddr("mockSubmission");
        mockVoterRegistry = makeAddr("mockVoterRegistry");
        mockRewardManager = makeAddr("mockRewardManager");
        mockCleanupBlockNumberManager = makeAddr("mockCleanupBlockNumberManager");
        mockRelay = makeAddr("mockRelay");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("Supply"));
        contractNameHashes[3] = keccak256(abi.encode("Submission"));
        contractNameHashes[4] = keccak256(abi.encode("GovernanceVotePower"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(flareSystemsManager);
        contractAddresses[2] = mockSupply;
        contractAddresses[3] = mockSubmission;
        contractAddresses[4] = address(governanceVotePower);
        pollingFoundation.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("Submission"));
        contractNameHashes[3] = keccak256(abi.encode("Relay"));
        contractNameHashes[4] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[5] = keccak256(abi.encode("CleanupBlockNumberManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockVoterRegistry;
        contractAddresses[2] = mockSubmission;
        contractAddresses[3] = mockRelay;
        contractAddresses[4] = mockRewardManager;
        contractAddresses[5] = mockCleanupBlockNumberManager;
        flareSystemsManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        _createVoters(4);

        _mockCleanupBlockNumber(0);
        vm.prank(address(wNat));
        governanceVotePower.setCleanupBlockNumber(50000);


        // registered addresses
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getRegisteredSubmitAddresses.selector),
            abi.encode(new address[](0))
        );
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getRegisteredSubmitSignaturesAddresses.selector),
            abi.encode(new address[](0))
        );

        vm.mockCall(
            mockSubmission,
            abi.encodeWithSelector(IISubmission.initNewVotingRound.selector),
            abi.encode()
        );

        // without staking
        vm.mockCall(
            makeAddr("pChain"),
            abi.encodeWithSelector(bytes4(keccak256("balanceOfAt(address,uint256)"))),
            abi.encode(0)
        );
        vm.mockCall(
            makeAddr("cChain"),
            abi.encodeWithSelector(bytes4(keccak256("balanceOfAt(address,uint256)"))),
            abi.encode(0)
        );
        vm.mockCall(
            makeAddr("pChain"),
            abi.encodeWithSelector(bytes4(keccak256("balanceOf(address)"))),
            abi.encode(0)
        );
        vm.mockCall(
            makeAddr("cChain"),
            abi.encodeWithSelector(bytes4(keccak256("balanceOf(address)"))),
            abi.encode(0)
        );
    }

    function testVPBlockSelectionAndVoting() public {
        _mockGetCirculatingSupply(1000);
        // 2 hours before new reward epoch
        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        vm.roll(block.number + 5000);
        _mockToSigningPolicyHash(1, bytes32(0));
        vm.roll(block.number + 128);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.setNewSigningPolicyInitializationStartBlockNumber.selector, 1),
            abi.encode()
        );
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        uint256 currentRandom = 103;
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(currentRandom, true, currentTime + 1)
        );
        _mockGetCurrentRandom(currentRandom);
        flareSystemsManager.daemonize();
        vm.stopPrank();

        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 500000,
            thresholdConditionBIPS: 6000,
            majorityConditionBIPS: 5000
        });
        vm.prank(proposers[0]);
        // start block of initial reward epoch is 0
        vm.expectRevert("start block already cleaned-up");
        pollingFoundation.propose("proposalAccept", settings);


        // move to the next reward epoch (1)
        _createSigningPolicySnapshot(1);
        bytes32 newSigningPolicyHash = keccak256("signingPolicyHash1");
        _mockToSigningPolicyHash(1, newSigningPolicyHash);
        vm.warp(block.timestamp + 5400);
        vm.roll(block.number + 100);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 1);

        vm.roll(block.number + 100000);

        // move to the next reward epoch (2)
        currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        vm.roll(block.number + 5000);
        _mockToSigningPolicyHash(2, bytes32(0));
        vm.roll(block.number + 128);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.setNewSigningPolicyInitializationStartBlockNumber.selector, 1),
            abi.encode()
        );
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        currentRandom = 1089;
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(currentRandom, true, currentTime + 1)
        );
        _mockGetCurrentRandom(currentRandom);
        flareSystemsManager.daemonize();
        vm.stopPrank();

        _createSigningPolicySnapshot(2);
        newSigningPolicyHash = keccak256("signingPolicyHash2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);
        vm.warp(block.timestamp + 5400);
        vm.roll(block.number + 100);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 2);

        vm.roll(block.number + 500);
        _mockGetCirculatingSupply(1200);
        vm.prank(voters[2]);
        wNat.deposit{ value: 200 }();

        // create proposal
        vm.prank(proposers[0]);
        // vp block can be chosen after the start of the reward epoch 1 which is too far in the past
        // (can already be expired)
        vm.expectRevert("vote power block is too far in the past");
        pollingFoundation.propose("proposalAccept", settings);

        vm.roll(block.number + 5000);
        // change vpBlockPeriodSeconds such that vp block will be after start of the reward epoch 2
        settings.vpBlockPeriodSeconds = 0;
        settings.votingStartTs = block.timestamp + 1000;
        vm.prank(proposers[0]);
        pollingFoundation.propose("proposalAccept", settings);
        uint256 proposalId = _getProposalId("proposalAccept");

        // vote
        vm.prank(voters[0]);
        vm.expectRevert("proposal not active");
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // voter3 unwraps 50
        vm.prank(voters[3]);
        wNat.withdraw(350);

        vm.prank(voters[0]);
        governanceVotePower.delegate(voters[1]);

        // move to start of the voting period
        vm.warp(block.timestamp + 1000);
        vm.prank(voters[0]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));
        // voter 2 wrapped additional funds before vote power block
        vm.prank(voters[2]);
        vm.expectEmit();
        emit VoteCast(voters[2], proposalId, uint8(GovernorVotes.VoteType.Against), 500, "", 300, 500);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.Against));
        vm.prank(voters[3]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // move to end of the voting period
        vm.warp(block.timestamp + 3600);
        (uint256 forVotes, uint256 againstVotes) = pollingFoundation.getProposalVotes(proposalId);
        assertEq(forVotes, 700);
        assertEq(againstVotes, 500);

        // execute proposal
        vm.prank(proposers[0]);
        pollingFoundation.execute(proposalId);
        assertEq(uint8(pollingFoundation.state(proposalId)), uint8(IGovernor.ProposalState.Executed));

         // move to the next reward epoch (3)
        currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        vm.roll(block.number + 5000);
        _mockToSigningPolicyHash(3, bytes32(0));
        vm.roll(block.number + 128);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.setNewSigningPolicyInitializationStartBlockNumber.selector, 1),
            abi.encode()
        );
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        currentRandom = 1089;
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(currentRandom, true, currentTime + 1)
        );
        _mockGetCurrentRandom(currentRandom);
        flareSystemsManager.daemonize();
        vm.stopPrank();

        _createSigningPolicySnapshot(3);
        newSigningPolicyHash = keccak256("signingPolicyHash3");
        _mockToSigningPolicyHash(3, newSigningPolicyHash);
        vm.warp(block.timestamp + 5400);
        vm.roll(block.number + 100);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 3);

        vm.warp(block.timestamp + 700);
        vm.roll(block.number + 500);

        // create another proposal
        settings = IIPollingFoundation.GovernorSettingsWithoutExecParams({
            accept: true,
            votingStartTs: block.timestamp + 500,
            votingPeriodSeconds: 3600,
            vpBlockPeriodSeconds: 0,
            thresholdConditionBIPS: 9000,
            majorityConditionBIPS: 7500
        });

        vm.prank(proposers[0]);
        pollingFoundation.propose("proposalAccept2", settings);
        proposalId = _getProposalId("proposalAccept2");
        (, , uint256 vpBlock, , , , , , , uint256 circulatingSupply, ) = pollingFoundation.getProposalInfo(proposalId);
        // voter0 delegated to voter1
        assertEq(pollingFoundation.getVotes(voters[0], vpBlock), 0);
        assertEq(pollingFoundation.getVotes(voters[1], vpBlock), 200 + 100);
        assertEq(pollingFoundation.getVotes(voters[2], vpBlock), 500);
        assertEq(pollingFoundation.getVotes(voters[3], vpBlock), 50);
        assertEq(circulatingSupply, 1200);

        vm.warp(block.timestamp + 500);
        vm.roll(block.number + 200);
        vm.prank(voters[0]);
        vm.expectEmit();
        emit VoteCast(voters[0], proposalId, uint8(GovernorVotes.VoteType.For), 0, "", 0, 0);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));
        vm.prank(voters[1]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));
        vm.prank(voters[2]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));
        vm.prank(voters[3]);
        pollingFoundation.castVote(proposalId, uint8(GovernorVotes.VoteType.For));

        // move to end of the voting period
        vm.warp(block.timestamp + 3600);
        // all voted in favor but their combined vote power is not 90 % of the total supply -> proposal is defeated
        assertEq(uint8(pollingFoundation.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function _mockCleanupBlockNumber(uint256 _cleanupBlock) internal {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(bytes4(keccak256("cleanupBlockNumber()"))),
            abi.encode(_cleanupBlock)
        );
    }

    function _createProposers(uint256 _numOfVoters) internal {
        for (uint256 i = 0; i < _numOfVoters; i++) {
            proposers.push(makeAddr(string.concat("proposer", vm.toString(i))));
            vm.deal(proposers[i], 1 ether);
        }
    }

    function _createVoters(uint256 _numOfVoters) internal {
        address voter;
        uint256 privateKey;
        for (uint256 i = 0; i < _numOfVoters; i++) {
            (voter, privateKey) = makeAddrAndKey(string.concat("voter", vm.toString(i)));
            voters.push(voter);
            privateKeys.push(privateKey);
            initialVotePowers.push((i + 1) * 100);
            vm.deal(voter, 10 ether);

            // set vote power for voter
            vm.prank(voter);
            wNat.deposit{ value: (i + 1) * 100}();
        }
    }

    function _mockToSigningPolicyHash(uint256 _epochId, bytes32 _hash) internal {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.toSigningPolicyHash.selector, _epochId),
            abi.encode(_hash)
        );
    }

    function _mockGetCurrentRandom(uint256 _random) internal {
        vm.mockCall(
            mockSubmission,
            abi.encodeWithSelector(IRandomProvider.getCurrentRandom.selector),
            abi.encode(_random)
        );
    }

    function _createSigningPolicySnapshot(uint256 _nextEpochId) internal {
        // mock signing policy snapshot
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.createSigningPolicySnapshot.selector, _nextEpochId),
            abi.encode(voters, initialVotePowers, 1000)
        );

        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IVoterRegistry.getNumberOfRegisteredVoters.selector, _nextEpochId),
            abi.encode(3)
        );

        vm.warp(block.timestamp + 30 * 60 + 1); // after 30 minutes
        vm.roll(block.number + 21); // after 20 blocks
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IIRelay.setSigningPolicy.selector),
            abi.encode(bytes32(0))
        );
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
    }

    function _mockGetCirculatingSupply(uint256 _supply) private {
        vm.mockCall(
            mockSupply,
            abi.encodeWithSelector(IISupply.getCirculatingSupplyAt.selector),
            abi.encode(_supply)
        );
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