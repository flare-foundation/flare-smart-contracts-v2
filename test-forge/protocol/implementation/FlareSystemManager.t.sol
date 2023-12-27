// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";
import "../../../contracts/protocol/implementation/Relay.sol";
import "../../../contracts/protocol/implementation/VoterRegistry.sol";

contract FlareSystemManagerTest is Test {

    //// contracts
    FlareSystemManager private flareSystemManager;
    address private flareDaemon;
    address private governance;
    address private addressUpdater;
    VoterRegistry private voterRegistry;
    Submission private submission;
    address private mockRelay;
    address private mockPriceSubmitter;
    Relay private relay;

    FlareSystemManager.Settings private settings;
    uint64 private startTs;
    address private voter1;
    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint64 private constant REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 3360; // 3.5 days
    uint64 private constant VOTING_EPOCH_DURATION_SEC = 90;
    uint64 private constant REWARD_EPOCH_DURATION_IN_SEC =
    REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS * VOTING_EPOCH_DURATION_SEC;
    uint64 private constant PPM_MAX = 1e6;

    //// events
    event SigningPolicyInitialized(
        uint24 rewardEpochId,       // Reward epoch id
        uint32 startVotingRoundId,  // First voting round id of validity.
                                    // Usually it is the first voting round of reward epoch rewardEpochId.
                                    // It can be later,
                                    // if the confirmation of the signing policy on Flare blockchain gets delayed.
        uint16 threshold,           // Confirmation threshold (absolute value of noramalised weights).
        uint256 seed,               // Random seed.
        address[] voters,           // The list of eligible voters in the canonical order.
        uint16[] weights            // The corresponding list of normalised signing weights of eligible voters.
                                    // Normalisation is done by compressing the weights from 32-byte values to 2 bytes,
                                    // while approximately keeping the weight relations.
    );

    event RandomAcquisitionStarted(
        uint24 rewardEpochId,       // Reward epoch id
        uint64 timestamp            // Timestamp when this happened
    );

    event VotePowerBlockSelected(
        uint24 rewardEpochId,       // Reward epoch id
        uint64 votePowerBlock,      // Vote power block for given reward epoch
        uint64 timestamp            // Timestamp when this happened
    );

    event SigningPolicySigned(
        uint24 rewardEpochId,       // Reward epoch id
        address signingAddress,     // Address which signed this
        address voter,              // Voter (entity)
        uint64 timestamp,           // Timestamp when this happened
        bool thresholdReached       // Indicates if signing threshold was reached
    );

    event UptimeVoteSigned(
        uint24 rewardEpochId,       // Reward epoch id
        address signingAddress,     // Address which signed this
        address voter,              // Voter (entity)
        bytes32 uptimeVoteHash,     // Uptime vote hash
        uint64 timestamp,           // Timestamp when this happened
        bool thresholdReached       // Indicates if signing threshold was reached
    );

    event RewardsSigned(
        uint24 rewardEpochId,           // Reward epoch id
        address signingAddress,         // Address which signed this
        address voter,                  // Voter (entity)
        bytes32 rewardsHash,            // Rewards hash
        uint256 noOfWeightBasedClaims,  // Number of weight based claims
        uint64 timestamp,               // Timestamp when this happened
        bool thresholdReached           // Indicates if signing threshold was reached
    );

    function setUp() public {
        flareDaemon = makeAddr("flareDaemon");
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        startTs = uint64(block.timestamp); // 1
        settings = FlareSystemManager.Settings(
            startTs,
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            3600 * 2,
            75 * 60,
            2250,
            30 * 60,
            20,
            20 * 60,
            600,
            500000,
            2
        );

        flareSystemManager = new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );

        // voter registry contract
        voter1 = makeAddr("voter1");
        address[] memory initialVoters = new address[](1);
        initialVoters[0] = voter1;
        voterRegistry = new VoterRegistry(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            100,
            0,
            initialVoters
        );

        // submission contract
        submission = new Submission(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            false
        );
        mockRelay = makeAddr("relay");
        mockPriceSubmitter = makeAddr("priceSubmitter");

        //// update contract addresses
        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = _keccak256AbiEncode("AddressUpdater");
        contractNameHashes[1] = _keccak256AbiEncode("VoterRegistry");
        contractNameHashes[2] = _keccak256AbiEncode("Submission");
        contractNameHashes[3] = _keccak256AbiEncode("Relay");
        contractNameHashes[4] = _keccak256AbiEncode("PriceSubmitter");
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(voterRegistry);
        contractAddresses[2] = address(submission);
        contractAddresses[3] = mockRelay;
        contractAddresses[4] = mockPriceSubmitter;
        flareSystemManager.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = _keccak256AbiEncode("AddressUpdater");
        contractNameHashes[1] = _keccak256AbiEncode("FlareSystemManager");
        contractNameHashes[2] = _keccak256AbiEncode("Relay");
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(flareSystemManager);
        contractAddresses[2] = mockRelay;
        submission.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();
    }

    // constructor tests
    function testRevertFlareDaemonZero() public {
        flareDaemon = address(0);
        vm.expectRevert("flare daemon zero");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    function testRevertRewardEpochDurationZero() public {
        settings.rewardEpochDurationInVotingEpochs = 0;
        vm.expectRevert("reward epoch duration zero");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    function testRevertVotingEpochDurationZero() public {
        settings.votingEpochDurationSeconds = 0;
        vm.expectRevert("voting epoch duration zero");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    function testRevertThresholdTooHigh() public {
        settings.signingPolicyThresholdPPM = PPM_MAX + 1;
        vm.expectRevert("threshold too high");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    function testRevertZeroVoters() public {
        settings.signingPolicyMinNumberOfVoters = 0;
        vm.expectRevert("zero voters");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            0,
            0
        );
    }

    function testRevertZeroRandomAcqBlocks() public {
        vm.expectRevert("zero blocks");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            0,
            0
        );
    }

    function testRevertRewardEpochEndInThePast() public {
        vm.warp(1641070800);
        vm.expectRevert("reward epoch end not in the future");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    // changing settings and view methods tests
    function testChangeSigningPolicySettings() public {
        vm.prank(governance);
        flareSystemManager.changeSigningPolicySettings(600000, 3);
        assertEq(flareSystemManager.signingPolicyThresholdPPM(), 600000);
        assertEq(flareSystemManager.signingPolicyMinNumberOfVoters(), 3);
    }

    function testRevertThresholdTooHighChangeSettings() public {
        vm.prank(governance);
        vm.expectRevert("threshold too high");
        flareSystemManager.changeSigningPolicySettings(PPM_MAX + 1, 3);
    }

    function testRevertZeroVotersChangeSettings() public {
        vm.prank(governance);
        vm.expectRevert("zero voters");
        flareSystemManager.changeSigningPolicySettings(60000, 0);
    }

    function testChangeRandomProvider() public {
        assertEq(flareSystemManager.usePriceSubmitterAsRandomProvider(), false);
        vm.prank(governance);
        flareSystemManager.changeRandomProvider(true);
        assertEq(flareSystemManager.usePriceSubmitterAsRandomProvider(), true);
    }

    function testGetContractName() public {
        assertEq(flareSystemManager.getContractName(), "FlareSystemManager");
    }

    function testSwitchToFallbackMode() public {
        assertEq(flareSystemManager.switchToFallbackMode(), false);
    }

    function testGetContrastAddresses() public {
        assertEq(address(flareSystemManager.voterRegistry()), address(voterRegistry));
        assertEq(address(flareSystemManager.submission()), address(submission));
        assertEq(address(flareSystemManager.relay()), mockRelay);
        assertEq(address(flareSystemManager.priceSubmitter()), mockPriceSubmitter);
    }

    /////
    function testStartRandomAcquisition() public {
        // 2 hours before new reward epoch
        uint64 currentTime = startTs + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        // deploy instead relay contract??
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32(0))
        );
        vm.prank(flareDaemon);
        vm.expectEmit();
        emit RandomAcquisitionStarted(1, currentTime);
        flareSystemManager.daemonize();
    }

    function testSelectVotePowerBlock() public {
        uint64 currentTime = startTs + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32(0))
        );
        vm.startPrank(flareDaemon);
        // start random acquisition
        flareSystemManager.daemonize();

        // select vote power block
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.getRandomNumber.selector),
            abi.encode(123, true, currentTime + 1)
        );
        vm.expectEmit(false, false, false, false);
        emit VotePowerBlockSelected(1,2,3);
        flareSystemManager.daemonize();
    }



    //// helper functions
    function _keccak256AbiEncode(string memory _value) internal pure returns(bytes32) {
        return keccak256(abi.encode(_value));
    }

}