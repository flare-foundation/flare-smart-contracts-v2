// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";
import "../../../contracts/protocol/implementation/Relay.sol";
import "../../../contracts/protocol/implementation/VoterRegistry.sol";
import "../../../contracts/protocol/implementation/EntityManager.sol";

import "forge-std/console2.sol";


contract FlareSystemManagerTest is Test {

    FlareSystemManager private flareSystemManager;
    address private flareDaemon;
    address private governance;
    address private addressUpdater;
    Submission private submission;
    address private mockRelay;
    EntityManager private entityManager;
    address private mockVoterRegistry;
    Relay private relay;

    FlareSystemManager.Settings private settings;
    address private voter1;
    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private signingAddresses;
    uint256[] private signingAddressesPk;

    address[] private voters;
    uint16[] private votersWeight;

    uint16 private constant REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 3360; // 3.5 days
    uint8 private constant VOTING_EPOCH_DURATION_SEC = 90;
    uint64 private constant REWARD_EPOCH_DURATION_IN_SEC =
    uint64(REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS) * VOTING_EPOCH_DURATION_SEC;
    uint24 private constant PPM_MAX = 1e6;

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

    event RewardEpochStarted(
        uint24 rewardEpochId,           // Reward epoch id
        uint32 startVotingRoundId,      // First voting round id of validity
        uint64 timestamp                // Timestamp when this happened
    );

    function setUp() public {
        flareDaemon = makeAddr("flareDaemon");
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        settings = FlareSystemManager.Settings(
            3600 * 8,
            15000,
            3600 * 2,
            0,
            30 * 60,
            20,
            500000,
            2,
            1000
        );

        flareSystemManager = new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            5,
            0,
            0
        );

        mockVoterRegistry = makeAddr("voterRegistry");

        // submission contract
        submission = new Submission(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            false
        );

        // entity manager contract
        entityManager = new EntityManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            4
        );
        mockRelay = makeAddr("relay");

        //// update contract addresses
        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = _keccak256AbiEncode("AddressUpdater");
        contractNameHashes[1] = _keccak256AbiEncode("VoterRegistry");
        contractNameHashes[2] = _keccak256AbiEncode("Submission");
        contractNameHashes[3] = _keccak256AbiEncode("Relay");
        contractNameHashes[4] = _keccak256AbiEncode("RewardManager");
        contractNameHashes[5] = _keccak256AbiEncode("CleanupBlockNumberManager");
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockVoterRegistry;
        contractAddresses[2] = address(submission);
        contractAddresses[3] = mockRelay;
        contractAddresses[4] = makeAddr("rewardManager");
        contractAddresses[5] = makeAddr("cleanupBlockNumberManager");
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

        // mock registered addresses
        _mockRegisteredAddresses(0);

        _createSigningAddressesAndPk(3);
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
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            5,
            0,
            0
        );
    }

    function testRevertRewardEpochDurationZero() public {
        vm.expectRevert("reward epoch duration zero");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            0,
            5,
            0,
            0
        );
    }

    function testRevertVotingEpochDurationZero() public {
        vm.expectRevert("voting epoch duration zero");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            uint32(block.timestamp),
            0,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            5,
            0,
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
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            5,
            0,
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
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            5,
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
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            0,
            0,
            0
        );
    }

    function testRevertRewardEpochEndInThePast() public {
        uint32 firstVotingRoundStartTs = uint32(block.timestamp);
        vm.warp(1641070800);
        vm.expectRevert("reward epoch end not in the future");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            firstVotingRoundStartTs,
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            5,
            0,
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

    function testGetContractName() public {
        assertEq(flareSystemManager.getContractName(), "FlareSystemManager");
    }

    function testSwitchToFallbackMode() public {
        assertEq(flareSystemManager.switchToFallbackMode(), false);
    }

    function testGetContrastAddresses() public {
        assertEq(address(flareSystemManager.voterRegistry()), mockVoterRegistry);
        assertEq(address(flareSystemManager.submission()), address(submission));
        assertEq(address(flareSystemManager.relay()), mockRelay);
    }

    /////
    function testStartRandomAcquisition() public {
        assertEq(flareSystemManager.getCurrentRewardEpochId(), 0);
        // 2 hours before new reward epoch
        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32(0))
        );

        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.setNewSigningPolicyInitializationStartBlockNumber.selector, 1),
            abi.encode()
        );

        vm.prank(flareDaemon);
        vm.expectEmit();
        emit RandomAcquisitionStarted(1, currentTime);
        flareSystemManager.daemonize();
    }

    function testSelectVotePowerBlock() public {
        vm.expectRevert("vote power block not initialized yet");
        flareSystemManager.getVotePowerBlock(1);

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32(0))
        );

        // start random acquisition
        vm.roll(234);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        // select vote power block
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(Relay.getRandomNumber.selector),
            abi.encode(123, true, currentTime + 1)
        );
        assertEq(flareSystemManager.getCurrentRandom(), 123);
        (uint256 currentRandom, bool quality) = flareSystemManager.getCurrentRandomWithQuality();
        assertEq(currentRandom, 123);
        assertEq(quality, true);
        vm.expectEmit();
        emit VotePowerBlockSelected(1,231,uint64(block.timestamp));
        assertEq(flareSystemManager.isVoterRegistrationEnabled(), false);
        flareSystemManager.daemonize();
        // voter registration started
        assertEq(flareSystemManager.isVoterRegistrationEnabled(), true);
        // endBlock = 234, _initialRandomVotePowerBlockSelectionSize = 5
        // numberOfBlocks = 5, random (=123) % 5 = 3 -> vote power block = 234 - 3 = 231
        assertEq(flareSystemManager.getVotePowerBlock(1), 231);
        (uint256 vpBlock, bool enabled) = flareSystemManager.getVoterRegistrationData(1);
        assertEq(vpBlock, 231);
        assertEq(enabled, true);
    }

    //// sign signing policy tests
    function testRevertInvalidNewSigningPolicyHash() public {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32(0))
        );

        bytes32 newSigningPolicyHash = keccak256("new signing policy hash");
        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);

        vm.expectRevert("new signing policy hash invalid");
        flareSystemManager.signNewSigningPolicy(1, newSigningPolicyHash, signature);
    }

    function testSignNewSigningPolicy() public {
        assertEq(flareSystemManager.isVoterRegistrationEnabled(), false);
        _initializeSigningPolicy(1);
        // signing policy initialized -> voter registration period ended
        assertEq(flareSystemManager.isVoterRegistrationEnabled(), false);


        bytes32 newSigningPolicyHash = keccak256("new signing policy hash");
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        );

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[0], voters[0], uint64(block.timestamp), false);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // new signing policy already signed -> should revert
        vm.expectRevert("new signing policy already signed");
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);
    }

    function testRevertSignNewSigningPolicyTwice() public {
        _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("new signing policy hash");
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        );

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // should revert when trying to sign again
        vm.expectRevert("signing address already signed");
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);
    }

    function testRevertNewSigningPolicyInvalidSignature() public {
         _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("new signing policy hash");
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        );

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(address(0), votersWeight[0])
        );
        vm.expectRevert("signature invalid");
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);
    }

     //// sign uptime vote tests
    function testRevertSignUptimeVoteEpochNotEnded() public {
        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(0, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);

        vm.expectRevert("epoch not ended yet");
        flareSystemManager.signUptimeVote(0, uptimeHash, signature);
    }

    function testSignUptimeVote() public {
        _initializeSigningPolicy(1);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(bytes32("signing policy2"))
        ); // define new signing policy
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        // reward epoch 1 is already finished.
        // First transaction in the block (daemonize() call will change `currentRewardEpochExpectedEndTs` value)
        assertEq(flareSystemManager.getCurrentRewardEpochId(), 2);
        vm.prank(flareDaemon);
        vm.expectEmit();
        emit RewardEpochStarted(2, 2 * 3360, uint64(block.timestamp));
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[0], voters[0], uptimeHash, uint64(block.timestamp), false);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        // new signing policy already signed -> should revert
        vm.expectRevert("uptime vote hash already signed");
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);
    }

    function testRevertSignUptimeVotesTwice() public {
        _initializeSigningPolicy(1);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(bytes32("signing policy2"))
        ); // define new signing policy
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        // should revert when trying to sign again
        vm.expectRevert("voter already signed");
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);
    }

    function testRevertSignUptimeVoteInvalidSignature() public {
        _initializeSigningPolicy(1);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(bytes32("signing policy2"))
        ); // define new signing policy
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);

        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(address(0), votersWeight[0])
        );
        vm.expectRevert("signature invalid");
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);
    }

    // sign rewards tests
    function testRevertSignRewardsEpochNotEnded() public {
        bytes32 rewardsHash = keccak256("rewards hash");
        uint64 noOfWeightBasedClaims = 3;
        bytes32 messageHash = keccak256(abi.encode(0, noOfWeightBasedClaims, rewardsHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);

        vm.expectRevert("epoch not ended yet");
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsSigningPolicyNotSigned() public {
        _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        );

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(keccak256("signing policy2"))
        ); // define new signing policy
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 rewardsHash = keccak256("rewards hash");
        uint64 noOfWeightBasedClaims = 3;
        messageHash = keccak256(abi.encode(0, noOfWeightBasedClaims, rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        vm.expectRevert("new signing policy not signed yet");
        flareSystemManager.signRewards(0, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsUptimeVoteNotSigned() public {
        _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        );

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(keccak256("signing policy2"))
        ); // define new signing policy
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 rewardsHash = keccak256("rewards hash");
        uint64 noOfWeightBasedClaims = 3;
        messageHash = keccak256(abi.encode(1, noOfWeightBasedClaims, rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        vm.expectRevert("uptime vote hash not signed yet");
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testSignRewards() public {
         _initializeSigningPolicy(1);
         vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        );

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        ); // define new signing policy
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        // sign uptime vote
        bytes32 uptimeHash = keccak256("uptime vote hash");
        messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        // sign rewards
        bytes32 rewardsHash = keccak256("rewards hash");
        uint64 noOfWeightBasedClaims = 3;
        messageHash = keccak256(abi.encode(1, noOfWeightBasedClaims, rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.expectEmit();
        emit RewardsSigned(1, signingAddresses[0], voters[0],
            rewardsHash, noOfWeightBasedClaims, uint64(block.timestamp), false);
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);

        // voter1 signs
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.expectEmit();
        emit RewardsSigned(1, signingAddresses[1], voters[1],
            rewardsHash, noOfWeightBasedClaims, uint64(block.timestamp), true);
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);

        // new signing policy already signed -> should revert
        vm.expectRevert("rewards hash already signed");
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsTwice() public {
         _initializeSigningPolicy(1);
         vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        );

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        ); // define new signing policy
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        // sign uptime vote
        bytes32 uptimeHash = keccak256("uptime vote hash");
        messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        // sign rewards
        bytes32 rewardsHash = keccak256("rewards hash");
        uint64 noOfWeightBasedClaims = 3;
        messageHash = keccak256(abi.encode(1, noOfWeightBasedClaims, rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);

        // should revert when trying to sign again
        vm.expectRevert("voter already signed");
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsInvalidSignature() public {
         _initializeSigningPolicy(1);
         vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        );

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        FlareSystemManager.Signature memory signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 2),
            abi.encode(newSigningPolicyHash)
        ); // define new signing policy
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        // sign uptime vote
        bytes32 uptimeHash = keccak256("uptime vote hash");
        messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        // sign rewards
        bytes32 rewardsHash = keccak256("rewards hash");
        uint64 noOfWeightBasedClaims = 3;
        messageHash = keccak256(abi.encode(1, noOfWeightBasedClaims, rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = FlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(address(0), votersWeight[0])
        );
        vm.expectRevert("signature invalid");
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    // set rewards hash tests
    function testRevertSetRewardsDataEpochNotEnded() public {
        vm.prank(governance);
        vm.expectRevert("epoch not ended yet");
        flareSystemManager.setRewardsData(1, 2, keccak256("rewards hash"));
    }

    function testUpdateRewardsData() public {
        testSignRewards();
        uint64 noOfWeightBasedClaims = 1;
        vm.prank(governance);
        vm.expectEmit();
        emit RewardsSigned(1, governance, governance,
            keccak256("rewards hash2"), noOfWeightBasedClaims, uint64(block.timestamp), true);
        flareSystemManager.setRewardsData(1, noOfWeightBasedClaims, keccak256("rewards hash2"));
    }

    function testSetRewardsData() public {
        // end reward epoch 0
        _initializeSigningPolicy(1);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, 1),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        uint64 noOfWeightBasedClaims = 3;
        vm.prank(governance);
        vm.expectEmit();
        emit RewardsSigned(0, governance, governance,
            keccak256("rewards hash"), noOfWeightBasedClaims, uint64(block.timestamp), true);
        flareSystemManager.setRewardsData(0, noOfWeightBasedClaims, keccak256("rewards hash"));
    }



    //// helper functions
    function _mockRegisteredAddresses(uint256 _epochid) internal {
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getRegisteredSubmitAddresses.selector, _epochid),
            abi.encode(new address[](0))
        );
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getRegisteredSubmitSignaturesAddresses.selector, _epochid),
            abi.encode(new address[](0))
        );
    }

    function _createSigningAddressesAndPk(uint256 _num) internal {
        for (uint256 i = 0; i < _num; i++) {
            (address signingAddress, uint256 pk) = makeAddrAndKey(
                string.concat("signingAddress", vm.toString(i)));
            signingAddresses.push(signingAddress);
            signingAddressesPk.push(pk);
        }
    }


    function _initializeSigningPolicy(uint256 _nextEpochId) internal {
        // mock signing policy snapshot
        voters = new address[](3);
        voters[0] = makeAddr("voter0");
        voters[1] = makeAddr("voter1");
        voters[2] = makeAddr("voter2");
        votersWeight = new uint16[](3);
        votersWeight[0] = 400;
        votersWeight[1] = 250;
        votersWeight[2] = 350;
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.createSigningPolicySnapshot.selector, _nextEpochId),
            abi.encode(voters, votersWeight, 1000)
        );
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(Relay.setSigningPolicy.selector),
            abi.encode(bytes32(0)));

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.toSigningPolicyHash.selector, _nextEpochId),
            abi.encode(bytes32(0))
        );

        vm.startPrank(flareDaemon);
        // start random acquisition
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(
                VoterRegistry.setNewSigningPolicyInitializationStartBlockNumber.selector, _nextEpochId),
            abi.encode()
        );
        flareSystemManager.daemonize();

        // select vote power block
        vm.roll(block.number + 1);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(Relay.getRandomNumber.selector),
            abi.encode(123, true, currentTime + 1)
        );
        flareSystemManager.daemonize();

        // initialize signing policy
        vm.warp(currentTime + 30 * 60 + 1); // after 30 minutes
        vm.roll(block.number + 21); // after 20 blocks
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.getNumberOfRegisteredVoters.selector, _nextEpochId),
            abi.encode(3)
        ); // 3 registered voters
        flareSystemManager.daemonize();
        vm.stopPrank();
    }

    function _keccak256AbiEncode(string memory _value) internal pure returns(bytes32) {
        return keccak256(abi.encode(_value));
    }

}