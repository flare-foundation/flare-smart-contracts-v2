// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/FlareSystemsManager.sol";
import "../../../mock/MockCleanupBlockNumberManager.sol";
import "../../../mock/MockVoterRegistrationTrigger.sol";

contract FlareSystemsManagerTest is Test {

    FlareSystemsManager private flareSystemsManager;
    address private flareDaemon;
    address private governance;
    address private addressUpdater;
    address private mockRelay;
    address private mockVoterRegistry;
    address private mockRewardManager;
    address private mockCleanupBlockNumberManager;
    address private mockSubmission;

    FlareSystemsManager.Settings private settings;
    FlareSystemsManager.InitialSettings private initialSettings;
    address private voter1;
    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private signingAddresses;
    uint256[] private signingAddressesPk;

    address[] private voters;
    uint16[] private votersWeight;

    IIRewardEpochSwitchoverTrigger[] private switchoverContracts;

    uint16 private constant REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 3360; // 3.5 days
    uint8 private constant VOTING_EPOCH_DURATION_SEC = 90;
    uint64 private constant REWARD_EPOCH_DURATION_IN_SEC =
    uint64(REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS) * VOTING_EPOCH_DURATION_SEC;
    uint24 private constant PPM_MAX = 1e6;

    //// events
    /// Event emitted when random acquisition phase starts.
    event RandomAcquisitionStarted(
        uint24 indexed rewardEpochId,   // Reward epoch id
        uint64 timestamp                // Timestamp when this happened
    );

    /// Event emitted when vote power block is selected.
    event VotePowerBlockSelected(
        uint24 indexed rewardEpochId,   // Reward epoch id
        uint64 votePowerBlock,          // Vote power block for given reward epoch
        uint64 timestamp                // Timestamp when this happened
    );

    /// Event emitted when signing policy is signed.
    event SigningPolicySigned(
        uint24 indexed rewardEpochId,           // Reward epoch id
        address indexed signingPolicyAddress,   // Address which signed this
        address indexed voter,                  // Voter (entity)
        uint64 timestamp,                       // Timestamp when this happened
        bool thresholdReached                   // Indicates if signing threshold was reached
    );

    /// Event emitted when reward epoch starts.
    event RewardEpochStarted(
        uint24 indexed rewardEpochId,   // Reward epoch id
        uint32 startVotingRoundId,      // First voting round id of validity
        uint64 timestamp                // Timestamp when this happened
    );

    /// Event emitted when it is time to sign uptime vote.
    event SignUptimeVoteEnabled(
        uint24 indexed rewardEpochId,   // Reward epoch id
        uint64 timestamp                // Timestamp when this happened
    );

    /// Event emitted when uptime vote is signed.
    event UptimeVoteSigned(
        uint24 indexed rewardEpochId,           // Reward epoch id
        address indexed signingPolicyAddress,   // Address which signed this
        address indexed voter,                  // Voter (entity)
        bytes32 uptimeVoteHash,                 // Uptime vote hash
        uint64 timestamp,                       // Timestamp when this happened
        bool thresholdReached                   // Indicates if signing threshold was reached
    );

    /// Event emitted when rewards are signed.
    event RewardsSigned(
        uint24 indexed rewardEpochId,                       // Reward epoch id
        address indexed signingPolicyAddress,               // Address which signed this
        address indexed voter,                              // Voter (entity)
        bytes32 rewardsHash,                                // Rewards hash
        IFlareSystemsManager.NumberOfWeightBasedClaims[] noOfWeightBasedClaims, // Number of weight based claims list
        uint64 timestamp,                                   // Timestamp when this happened
        bool thresholdReached                               // Indicates if signing threshold was reached
    );

    event TriggeringVoterRegistrationFailed(uint24 rewardEpochId);
    event ClosingExpiredRewardEpochFailed(uint24 rewardEpochId);
    event SettingCleanUpBlockNumberFailed(uint64 blockNumber);

    event UptimeVoteSubmitted(
        uint24 indexed rewardEpochId,           // Reward epoch id
        address indexed signingPolicyAddress,   // Address which signed this
        address indexed voter,                  // Voter (entity)
        bytes20[] nodeIds,                      // Node ids with high enough uptime
        uint64 timestamp                        // Timestamp when this happened
    );

    function setUp() public {
        vm.warp(1000);
        flareDaemon = makeAddr("flareDaemon");
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        settings = FlareSystemsManager.Settings(
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
            1000
        );

        initialSettings = FlareSystemsManager.InitialSettings(
            5,
            0,
            0
        );

        flareSystemsManager = new FlareSystemsManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            initialSettings
        );

        mockSubmission = makeAddr("submission");
        mockRelay = makeAddr("relay");
        mockRewardManager = makeAddr("rewardManager");
        mockVoterRegistry = makeAddr("voterRegistry");
        mockCleanupBlockNumberManager = makeAddr("cleanupBlockNumberManager");

        //// update contract addresses
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
        contractAddresses[2] = mockSubmission;
        contractAddresses[3] = mockRelay;
        contractAddresses[4] = mockRewardManager;
        contractAddresses[5] = mockCleanupBlockNumberManager;
        vm.prank(addressUpdater);
        flareSystemsManager.updateContractAddresses(contractNameHashes, contractAddresses);

        // mock registered addresses
        _mockRegisteredAddresses(0);

        _createSigningAddressesAndPk(3);

        // don't cleanup anything yet
        _mockCleanupBlockNumber(0);

        vm.mockCall(
            mockSubmission,
            abi.encodeWithSelector(IISubmission.initNewVotingRound.selector),
            abi.encode()
        );
    }

    // constructor tests
    function testRevertFlareDaemonZero() public {
        flareDaemon = address(0);
        vm.expectRevert("flare daemon zero");
        new FlareSystemsManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            initialSettings
        );
    }

    function testRevertRewardEpochDurationZero() public {
        vm.expectRevert("reward epoch duration zero");
        new FlareSystemsManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            0,
            initialSettings
        );
    }

    function testRevertVotingEpochDurationZero() public {
        vm.expectRevert("voting epoch duration zero");
        new FlareSystemsManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            uint32(block.timestamp),
            0,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            initialSettings
        );
    }

    function testRevertThresholdTooHigh() public {
        settings.signingPolicyThresholdPPM = PPM_MAX + 1;
        vm.prank(governance);
        vm.expectRevert("threshold too high");
        flareSystemsManager.updateSettings(settings);
    }

    function testRevertInvalidNumberOfVoters() public {
        settings.signingPolicyMinNumberOfVoters = 0;
        vm.prank(governance);
        vm.expectRevert("invalid number of voters");
        flareSystemsManager.updateSettings(settings);
    }

    function testRevertInvalidNumberOfVoters2() public {
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IVoterRegistry.maxVoters.selector),
            abi.encode(10)
        );
        settings.signingPolicyMinNumberOfVoters = 20;
        vm.prank(governance);
        vm.expectRevert("invalid number of voters");
        flareSystemsManager.updateSettings(settings);
    }


    function testRevertExpiryTooLong() public {
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IVoterRegistry.maxVoters.selector),
            abi.encode(100)
        );
        settings.rewardExpiryOffsetSeconds = uint32(block.timestamp) + 100;
        vm.prank(governance);
        vm.expectRevert("expiry too long");
        flareSystemsManager.updateSettings(settings);
    }

    function testRevertZeroRandomAcqBlocks() public {
        initialSettings.initialRandomVotePowerBlockSelectionSize = 0;
        vm.expectRevert("zero blocks");
        new FlareSystemsManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            initialSettings
        );
    }

    function testRevertRewardEpochEndInThePast() public {
        uint32 firstVotingRoundStartTs = uint32(block.timestamp);
        vm.warp(1641070800);
        vm.expectRevert("reward epoch end not in the future");
        new FlareSystemsManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            firstVotingRoundStartTs,
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            initialSettings
        );
    }

    // changing settings and view methods tests
    function testGetContractName() public {
        assertEq(flareSystemsManager.getContractName(), "FlareSystemsManager");
    }

    function testSwitchToFallbackMode() public {
        vm.prank(flareDaemon);
        assertEq(flareSystemsManager.switchToFallbackMode(), false);

        vm.expectRevert("only flare daemon");
        flareSystemsManager.switchToFallbackMode();
    }

    function testGetContrastAddresses() public {
        assertEq(address(flareSystemsManager.voterRegistry()), mockVoterRegistry);
        assertEq(address(flareSystemsManager.submission()), mockSubmission);
        assertEq(address(flareSystemsManager.relay()), mockRelay);
    }

    /////
    function testStartRandomAcquisition() public {
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 0);
        // 2 hours before new reward epoch
        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        _mockToSigningPolicyHash(1, bytes32(0));


        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.setNewSigningPolicyInitializationStartBlockNumber.selector, 1),
            abi.encode()
        );

        vm.prank(flareDaemon);
        vm.expectEmit();
        emit RandomAcquisitionStarted(1, currentTime);
        flareSystemsManager.daemonize();
    }

    function testSelectVotePowerBlock() public {
        vm.expectRevert("vote power block not initialized yet");
        flareSystemsManager.getVotePowerBlock(1);

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        _mockToSigningPolicyHash(1, bytes32(0));

        // start random acquisition
        vm.roll(199);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        vm.expectRevert("seed not initialized yet");
        flareSystemsManager.getSeed(1);

        vm.roll(234);
        vm.warp(currentTime + uint64(11));
        // select vote power block
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, true, currentTime + 1)
        );
        vm.expectEmit();
        emit VotePowerBlockSelected(1, 196, uint64(block.timestamp));
        assertEq(flareSystemsManager.isVoterRegistrationEnabled(), false);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getSeed(1), 123);

        // voter registration started
        assertEq(flareSystemsManager.isVoterRegistrationEnabled(), true);
        // endBlock = 199, _initialRandomVotePowerBlockSelectionSize = 5
        // numberOfBlocks = 5, random (=123) % 5 = 3 -> vote power block = 199 - 3 = 196
        assertEq(flareSystemsManager.getVotePowerBlock(1), 196);
        (uint256 vpBlock, bool enabled) = flareSystemsManager.getVoterRegistrationData(1);
        assertEq(vpBlock, 196);
        assertEq(enabled, true);

        (uint64 startTs, uint64 startBlock, uint64 endTs, uint64 endBlock) =
            flareSystemsManager.getRandomAcquisitionInfo(1);
        assertEq(startTs, currentTime);
        assertEq(startBlock, 199);
        assertEq(endTs, currentTime + 11);
        assertEq(endBlock, 234);
    }

    // use current vote power block; initial reward epoch -> use unsecure random
    function testSelectVotePowerBlockUnsecureRandom() public {
        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        _mockToSigningPolicyHash(1, bytes32(0));

        // start random acquisition
        vm.roll(199);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // select vote power block
        // move to the end of acquisition period and don't get secure random
        vm.roll(block.number + 15000 + 1);
        vm.warp(block.timestamp + uint64(8 * 60 * 60 + 1));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, false, currentTime + 1)
        );

        vm.expectEmit();
        emit VotePowerBlockSelected(1, 196, uint64(block.timestamp));
        flareSystemsManager.daemonize();
        // voter registration started
        // endBlock = 199, _initialRandomVotePowerBlockSelectionSize = 5
        // numberOfBlocks = 5, random (=123) % 5 = 3 -> vote power block = 199 - 3 = 196
        assertEq(flareSystemsManager.getVotePowerBlock(1), 196);
    }

    function testSelectVotePowerBlockCurrentBlock() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        // start new epoch
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(2, bytes32(0));

        // start random acquisition
        // vm.roll(199);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // don't yet select vote power block
        flareSystemsManager.daemonize();

        // select vote power block
        // move to the end of acquisition period and don't get secure random
        vm.roll(block.number + 15000 + 1);
        vm.warp(block.timestamp + uint64(8 * 60 * 60 + 1));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, false, currentTime + 1)
        );

        // should use current vp block
        uint64 vpBlock1 = flareSystemsManager.getVotePowerBlock(1);
        vm.expectEmit();
        emit VotePowerBlockSelected(2, vpBlock1, uint64(block.timestamp));
        flareSystemsManager.daemonize();
    }

    function testTriggerRewardEpochSwitchover() public {
        // set switchover contracts
        switchoverContracts = new IIRewardEpochSwitchoverTrigger[](1);
        address mockSwitchover = makeAddr("switchover");
        switchoverContracts[0] = IIRewardEpochSwitchoverTrigger(mockSwitchover);
        vm.prank(governance);
        flareSystemsManager.setRewardEpochSwitchoverTriggerContracts(switchoverContracts);
        IIRewardEpochSwitchoverTrigger[] memory getContracts =
            flareSystemsManager.getRewardEpochSwitchoverTriggerContracts();
        assertEq(getContracts.length, 1);
        assertEq(address(getContracts[0]), mockSwitchover);

        _initializeSigningPolicyAndMoveToNewEpoch(1);

        vm.mockCall(
            mockSwitchover,
            abi.encodeWithSelector(IIRewardEpochSwitchoverTrigger.triggerRewardEpochSwitchover.selector, 1),
            abi.encode()
        );

        // start new reward epoch and do switchover
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
    }

    function testSwitchoverTriggerContractsRevertDuplicated() public {
        switchoverContracts = new IIRewardEpochSwitchoverTrigger[](2);
        address mockSwitchover = makeAddr("switchover");
        switchoverContracts[0] = IIRewardEpochSwitchoverTrigger(mockSwitchover);
        switchoverContracts[1] = IIRewardEpochSwitchoverTrigger(mockSwitchover);

        vm.startPrank(governance);
        vm.expectRevert("duplicated contracts");
        flareSystemsManager.setRewardEpochSwitchoverTriggerContracts(switchoverContracts);

        switchoverContracts[1] = IIRewardEpochSwitchoverTrigger(makeAddr("switchover2"));
        flareSystemsManager.setRewardEpochSwitchoverTriggerContracts(switchoverContracts);
        vm.stopPrank();
    }

    function testTriggerVoterRegistration() public {
        // set voter register trigger contract
        address voterRegTrigger = makeAddr("voterRegTrigger");
        vm.prank(governance);
        flareSystemsManager.setVoterRegistrationTriggerContract(IIVoterRegistrationTrigger(voterRegTrigger));
        assertEq(address(flareSystemsManager.voterRegistrationTriggerContract()), voterRegTrigger);

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        _mockToSigningPolicyHash(1, bytes32(0));

        // start random acquisition
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // select vote power block and trigger voter registration
        vm.roll(234);
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, true, currentTime + 1)
        );

        vm.mockCall(
            voterRegTrigger,
            abi.encodeWithSelector(IIVoterRegistrationTrigger.triggerVoterRegistration.selector, 1),
            abi.encode()
        );

        flareSystemsManager.daemonize();
    }


    function testTriggerVoterRegistrationFailed() public {
        // address voterRegTrigger = makeAddr("voterRegTrigger");
        // vm.prank(governance);
        // flareSystemsManager.setVoterRegistrationTriggerContract(IIVoterRegistrationTrigger(voterRegTrigger));
        // assertEq(address(flareSystemsManager.voterRegistrationTriggerContract()), voterRegTrigger);
        // // TODO: why is that not working?
        // vm.mockCallRevert(
        //     voterRegTrigger,
        //     abi.encodeWithSelector(IIVoterRegistrationTrigger.triggerVoterRegistration.selector, 1),
        //     abi.encode("err123")
        // );

        // set voter register trigger contract
        MockVoterRegistrationTrigger voterRegTrigger = new MockVoterRegistrationTrigger();
        vm.prank(governance);
        flareSystemsManager.setVoterRegistrationTriggerContract(IIVoterRegistrationTrigger(voterRegTrigger));
        assertEq(address(flareSystemsManager.voterRegistrationTriggerContract()), address(voterRegTrigger));


        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        _mockToSigningPolicyHash(1, bytes32(0));

        // start random acquisition
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // select vote power block and trigger voter registration
        vm.roll(234);
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, true, currentTime + 1)
        );
        vm.expectEmit();
        emit TriggeringVoterRegistrationFailed(1);
        flareSystemsManager.daemonize();
    }

    function testTriggerCloseExpiredEpochs() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // start reward epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // set cleanupBlockNumber to 200; vp block for epoch 1 is 1
        _mockCleanupBlockNumber(9);

        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.closeExpiredRewardEpoch.selector),
            abi.encode()
        );
        // it should trigger closeExpiredRewardEpoch once and set rewardEpochIdToExpireNext to 2
        assertEq(flareSystemsManager.rewardEpochIdToExpireNext(), 1);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.rewardEpochIdToExpireNext(), 2);

        // start reward epoch 3
        _initializeSigningPolicyAndMoveToNewEpoch(3);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // vp block for epoch 2 is 10 -> it should not yet trigger closeExpiredRewardEpoch for epoch 2
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.rewardEpochIdToExpireNext(), 2);

        // close epoch 2
        _mockCleanupBlockNumber(11);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.rewardEpochIdToExpireNext(), 3);
    }

    function testSetTriggerExpirationAndCleanup() public {
        assertEq(flareSystemsManager.triggerExpirationAndCleanup(), false);
        vm.prank(governance);
        flareSystemsManager.setTriggerExpirationAndCleanup(true);
        assertEq(flareSystemsManager.triggerExpirationAndCleanup(), true);
        vm.prank(governance);
        flareSystemsManager.setTriggerExpirationAndCleanup(false);
        assertEq(flareSystemsManager.triggerExpirationAndCleanup(), false);

        vm.expectRevert("only governance");
        flareSystemsManager.setTriggerExpirationAndCleanup(true);
    }

    function testSetSubmit3Aligned() public {
        assertEq(flareSystemsManager.submit3Aligned(), true);
        vm.prank(governance);
        flareSystemsManager.setSubmit3Aligned(false);
        assertEq(flareSystemsManager.submit3Aligned(), false);
        vm.prank(governance);
        flareSystemsManager.setSubmit3Aligned(true);
        assertEq(flareSystemsManager.submit3Aligned(), true);

        vm.expectRevert("only governance");
        flareSystemsManager.setSubmit3Aligned(true);
    }

    function testCloseExpiredEpochs() public {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.closeExpiredRewardEpoch.selector),
            abi.encode()
        );

        vm.mockCall(
            mockCleanupBlockNumberManager,
            abi.encodeWithSelector(IICleanupBlockNumberManager.setCleanUpBlockNumber.selector),
            abi.encode()
        );

        vm.prank(governance);
        flareSystemsManager.setTriggerExpirationAndCleanup(true);
        assertEq(flareSystemsManager.triggerExpirationAndCleanup(), true);

        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // start reward epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();

        // start reward epoch 3 and close epoch 1
        assertEq(flareSystemsManager.rewardEpochIdToExpireNext(), 1);
        _initializeSigningPolicyAndMoveToNewEpoch(3);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.rewardEpochIdToExpireNext(), 2);

        // start reward epoch 4 and close epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(4);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.rewardEpochIdToExpireNext(), 3);

        // move to epoch 10 and do not close expired epoch
        vm.prank(governance);
        flareSystemsManager.setTriggerExpirationAndCleanup(false);
        for (uint256 i = 5; i < 11; i++) {
            _initializeSigningPolicyAndMoveToNewEpoch(i);
            vm.prank(flareDaemon);
            flareSystemsManager.daemonize();
        }
        vm.prank(governance);
        flareSystemsManager.setTriggerExpirationAndCleanup(true);

        // move to epoch 11 and close epochs 3-9
        _initializeSigningPolicyAndMoveToNewEpoch(11);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.rewardEpochIdToExpireNext(), 10);
    }

    function testCloseExpiredEpochsFailed() public {
        vm.mockCallRevert(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.closeExpiredRewardEpoch.selector),
            abi.encode()
        );

        vm.mockCall(
            mockCleanupBlockNumberManager,
            abi.encodeWithSelector(IICleanupBlockNumberManager.setCleanUpBlockNumber.selector),
            abi.encode()
        );

        vm.prank(governance);
        flareSystemsManager.setTriggerExpirationAndCleanup(true);

        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // start reward epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();

        // start reward epoch 3 and try to close epoch 1
        _initializeSigningPolicyAndMoveToNewEpoch(3);
        vm.prank(flareDaemon);
        vm.expectEmit();
        emit ClosingExpiredRewardEpochFailed(1);
        flareSystemsManager.daemonize();
    }

    function testSetCleanupBlockNumberFailed() public {
        // TODO why is that not working?
        // vm.mockCallRevert(
        //     mockCleanupBlockNumberManager,
        //     abi.encodeWithSelector(IICleanupBlockNumberManager.setCleanUpBlockNumber.selector, 1),
        //     abi.encode()
        // );

        MockCleanupBlockNumberManager cleanupManager = new MockCleanupBlockNumberManager();
        vm.prank(addressUpdater);
        // contractNameHashes[5] = _keccak256AbiEncode("CleanupBlockNumberManager");
        contractAddresses[5] = address(cleanupManager);
        flareSystemsManager.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.prank(governance);
        flareSystemsManager.setTriggerExpirationAndCleanup(true);

        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        vm.expectEmit();
        emit SettingCleanUpBlockNumberFailed(1);
        flareSystemsManager.daemonize();
    }

    function testTriggerCloseExpiredEpochsFailed() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // start reward epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        // set cleanupBlockNumber to 9; vp block for epoch 1 is 1
        _mockCleanupBlockNumber(9);
        vm.mockCallRevert(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.closeExpiredRewardEpoch.selector),
            abi.encode("err123")
        );

        vm.expectEmit();
        emit ClosingExpiredRewardEpochFailed(1);
        flareSystemsManager.daemonize();
    }

    function testGetStartVotingRoundId() public {
        vm.expectRevert("reward epoch not initialized yet");
        flareSystemsManager.getStartVotingRoundId(1);
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getStartVotingRoundId(1), 3360);
        assertEq(flareSystemsManager.getCurrentVotingEpochId(), 3360);

        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getStartVotingRoundId(2), 2 * 3360);
        assertEq(flareSystemsManager.getCurrentVotingEpochId(), 2 * 3360);

        vm.warp(block.timestamp + 5400 + 500);
        // voting round duration is 90 seconds
        // new signing policy was initialized 5 voting rounds after supposed start voting round
        // -> start voting round id should be  _getCurrentVotingEpochId() + delay) + 1
        _initializeSigningPolicyAndMoveToNewEpoch(3);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getStartVotingRoundId(3), 3 * 3360 + 5 + 1);
        assertEq(flareSystemsManager.getCurrentVotingEpochId(),
            (block.timestamp - flareSystemsManager.firstVotingRoundStartTs()) / VOTING_EPOCH_DURATION_SEC);
    }

    function testGetThreshold() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        assertEq(flareSystemsManager.getThreshold(1), 500);

        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();

        _initializeSigningPolicyAndMoveToNewEpoch(2);
        assertEq(flareSystemsManager.getThreshold(2), 500);
    }

    function testUpdateSettings() public {
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IVoterRegistry.maxVoters.selector),
            abi.encode(100)
        );
        settings = FlareSystemsManager.Settings(
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11
        );

        vm.prank(governance);
        flareSystemsManager.updateSettings(settings);
        assertEq(flareSystemsManager.randomAcquisitionMaxDurationSeconds(), 1);
        assertEq(flareSystemsManager.randomAcquisitionMaxDurationBlocks(), 2);
        assertEq(flareSystemsManager.newSigningPolicyInitializationStartSeconds(), 3);
        assertEq(flareSystemsManager.newSigningPolicyMinNumberOfVotingRoundsDelay(), 4);
        assertEq(flareSystemsManager.voterRegistrationMinDurationSeconds(), 5);
        assertEq(flareSystemsManager.voterRegistrationMinDurationBlocks(), 6);
        assertEq(flareSystemsManager.submitUptimeVoteMinDurationSeconds(), 7);
        assertEq(flareSystemsManager.submitUptimeVoteMinDurationBlocks(), 8);
        assertEq(flareSystemsManager.signingPolicyThresholdPPM(), 9);
        assertEq(flareSystemsManager.signingPolicyMinNumberOfVoters(), 10);
        assertEq(flareSystemsManager.rewardExpiryOffsetSeconds(), 11);
    }

    //// sign signing policy tests
    function testRevertInvalidNewSigningPolicyHash() public {
        _mockToSigningPolicyHash(1, bytes32(0));

        bytes32 newSigningPolicyHash = keccak256("new signing policy hash");
        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);

        vm.expectRevert("new signing policy hash invalid");
        flareSystemsManager.signNewSigningPolicy(1, newSigningPolicyHash, signature);
    }

    function testSignNewSigningPolicy() public {
        assertEq(flareSystemsManager.isVoterRegistrationEnabled(), false);
        _initializeSigningPolicy(1);
        // signing policy initialized -> voter registration period ended
        assertEq(flareSystemsManager.isVoterRegistrationEnabled(), false);

        bytes32 newSigningPolicyHash = keccak256("new signing policy hash");
        _mockToSigningPolicyHash(1, newSigningPolicyHash);

        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 0, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);


        // move in time and voter0 signs
        uint64 signPolicyStartTs = uint64(block.timestamp);
        uint64 signPolicyStartBlock = uint64(block.number);
        vm.warp(signPolicyStartTs + 100);
        vm.roll(signPolicyStartBlock + 100);

        vm.expectEmit();
        emit SigningPolicySigned(1, signingAddresses[0], voters[0], uint64(block.timestamp), true);
        flareSystemsManager.signNewSigningPolicy(1, newSigningPolicyHash, signature);
        (uint64 signTs, uint64 signBlock) = flareSystemsManager.getVoterSigningPolicySignInfo(1, voters[0]);
        assertEq(signTs, signPolicyStartTs + 100);
        assertEq(signBlock, signPolicyStartBlock + 100);


        uint64[] memory signingPolicyInfo = new uint64[](4);
        (signingPolicyInfo[0], signingPolicyInfo[1], signingPolicyInfo[2], signingPolicyInfo[3]) =
            flareSystemsManager.getSigningPolicySignInfo(1);
        assertEq(signingPolicyInfo[0], signPolicyStartTs);
        assertEq(signingPolicyInfo[1], signPolicyStartBlock);
        assertEq(signingPolicyInfo[2], signPolicyStartTs + 100);
        assertEq(signingPolicyInfo[3], signPolicyStartBlock + 100);

        // new signing policy already signed -> should revert
        vm.expectRevert("new signing policy already signed");
        flareSystemsManager.signNewSigningPolicy(1, newSigningPolicyHash, signature);


        //// sign signing policy for epoch 2
        _mockRegisteredAddresses(1);

        // start new reward epoch - epoch 1
        vm.warp(block.timestamp + 5400 - 100); // after end of reward epoch
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();

        _initializeSigningPolicy(2);
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        // voter0 signs
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[0], voters[0], uint64(block.timestamp), false);
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);
        (signTs, signBlock) = flareSystemsManager.getVoterSigningPolicySignInfo(2, voters[0]);
        assertEq(signTs, uint64(block.timestamp));
        assertEq(signBlock, uint64(block.number));

        // voter1 signs; threshold (500) is reached
        signPolicyStartTs = uint64(block.timestamp);
        signPolicyStartBlock = uint64(block.number);
        vm.warp(signPolicyStartTs + 12);
        vm.roll(signPolicyStartBlock + 13);
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        (signTs, signBlock) = flareSystemsManager.getVoterSigningPolicySignInfo(2, voters[1]);
        assertEq(signTs, uint64(block.timestamp));
        assertEq(signBlock, uint64(block.number));

        (signingPolicyInfo[0], signingPolicyInfo[1], signingPolicyInfo[2], signingPolicyInfo[3]) =
            flareSystemsManager.getSigningPolicySignInfo(2);
        assertEq(signingPolicyInfo[0], signPolicyStartTs);
        assertEq(signingPolicyInfo[1], signPolicyStartBlock);
        assertEq(signingPolicyInfo[2], uint64(block.timestamp));
        assertEq(signingPolicyInfo[3], uint64(block.number));
    }

    function testRevertSignNewSigningPolicyTwice() public {
        _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("new signing policy hash");

        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // should revert when trying to sign again
        vm.expectRevert("voter already signed");
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);
    }

    function testRevertNewSigningPolicyInvalidSignature() public {
         _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("new signing policy hash");

        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(address(0), votersWeight[0])
        );
        vm.expectRevert("signature invalid");
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);
    }

    //// submit uptime tests
    function testSubmitUptimeVote() public {
        _initializeSigningPolicy(1);
        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);
        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        // initialize signing policy and move to epoch 2
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        bytes20[] memory nodeIds = new bytes20[](2);
        nodeIds[0] = bytes20("node1");
        nodeIds[1] = bytes20("node2");

        bytes32 messageHash = keccak256(abi.encode(1, nodeIds));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );

        vm.expectEmit();
        emit UptimeVoteSubmitted(1, signingAddresses[0], voters[0], nodeIds, uint64(block.timestamp));
        flareSystemsManager.submitUptimeVote(1, nodeIds, signature);

        (uint64 submitTs, uint64 submitBlock) = flareSystemsManager.getVoterUptimeVoteSubmitInfo(1, voters[0]);
        assertEq(submitTs, uint64(block.timestamp));
        assertEq(submitBlock, uint64(block.number));
        uint256 submitTime1 = block.timestamp;
        uint256 submitBlock1 = block.number;

        nodeIds = new bytes20[](3);
        nodeIds[0] = bytes20("node1");
        nodeIds[1] = bytes20("node2");
        nodeIds[2] = bytes20("node2");

        messageHash = keccak256(abi.encode(1, nodeIds));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );

        vm.warp(block.timestamp + 10);
        vm.roll(block.number + 20);
        vm.expectEmit();
        emit UptimeVoteSubmitted(1, signingAddresses[1], voters[1], nodeIds, uint64(block.timestamp));
        flareSystemsManager.submitUptimeVote(1, nodeIds, signature);
        (submitTs, submitBlock) = flareSystemsManager.getVoterUptimeVoteSubmitInfo(1, voters[1]);
        assertEq(submitTs, uint64(submitTime1 + 10));
        assertEq(submitBlock, uint64(submitBlock1 + 20));
    }

    function testSubmitUptimeVoteRevertEpochNotEnded() public {
        bytes20[] memory nodeIds = new bytes20[](2);
        nodeIds[0] = bytes20("node1");
        nodeIds[1] = bytes20("node2");

        bytes32 messageHash = keccak256(abi.encode(1, nodeIds));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);

        vm.expectRevert("epoch not ended yet");
        flareSystemsManager.submitUptimeVote(1, nodeIds, signature);
    }

    function testSubmitUptimeVoteRevertSubmitVoteFinished() public {
        _initializeSigningPolicy(1);
        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        _moveToSignUptimeStart();

        _initializeSigningPolicy(2);
        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        // initialize signing policy and move to epoch 2
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)
        _moveToSignUptimeStart();

        bytes20[] memory nodeIds = new bytes20[](2);
        nodeIds[0] = bytes20("node1");
        nodeIds[1] = bytes20("node2");

        bytes32 messageHash = keccak256(abi.encode(1, nodeIds));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);

        vm.expectRevert("submit uptime vote already ended");
        flareSystemsManager.submitUptimeVote(1, nodeIds, signature);
    }

    function testSubmitUptimeVoteRevertInvalidSignature() public {
        _initializeSigningPolicy(1);
        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);
        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        // initialize signing policy and move to epoch 2
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        bytes20[] memory nodeIds = new bytes20[](2);
        nodeIds[0] = bytes20("node1");
        nodeIds[1] = bytes20("node2");

        bytes32 messageHash = keccak256(abi.encode(2, nodeIds));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1),
            abi.encode(address(0), votersWeight[0])
        );

        vm.expectRevert("signature invalid");
        flareSystemsManager.submitUptimeVote(1, nodeIds, signature);
    }


    //// sign uptime vote tests
    function testRevertSignUptimeVoteEpochNotEnded() public {
        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(0, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);

        vm.expectRevert("epoch not ended yet");
        flareSystemsManager.signUptimeVote(0, uptimeHash, signature);
    }

    function testRevertSignUptimeVoteHashZero() public {
        bytes32 messageHash = keccak256(abi.encode(0, bytes32(0)));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);

        vm.expectRevert("uptime vote hash zero");
        flareSystemsManager.signUptimeVote(0, bytes32(0), signature);
    }

    function testSignUptimeVoteRevertNotStartedYet() public {
        _initializeSigningPolicy(1);

        // define new signing policy
        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);

        // define new signing policy
        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        // initialize signing policy and move to epoch 2
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        vm.expectRevert("sign uptime vote not started yet");
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);
    }

    function testSignUptimeVote() public {
        _initializeSigningPolicy(1);

        // define new signing policy
        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);

        // define new signing policy
        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        // initialize signing policy and move to epoch 2
        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        // reward epoch 1 is already finished.
        // First transaction in the block (daemonize() call will change `currentRewardEpochExpectedEndTs` value)
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 1);
        assertEq(flareSystemsManager.getCurrentRewardEpoch(), 1);
        vm.prank(flareDaemon);
        vm.expectEmit();
        emit RewardEpochStarted(2, 2 * 3360, uint64(block.timestamp));
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 2);
        assertEq(flareSystemsManager.getCurrentRewardEpoch(), 2);
        (uint64 startTs, uint64 startBlock) = flareSystemsManager.getRewardEpochStartInfo(2);
        assertEq(startTs, uint64(block.timestamp));
        assertEq(startBlock, uint64(block.number));

        // move to sign uptime phase
        _moveToSignUptimeStart();
        (uint64 signUptimeStartTs, uint64 signUptimeStartBlock) = flareSystemsManager.getUptimeVoteSignStartInfo(1);
        assertEq(signUptimeStartTs, uint64(block.timestamp));
        assertEq(signUptimeStartBlock, uint64(block.number));

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[0], voters[0], uptimeHash, uint64(block.timestamp), false);
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);

        (uint64 signTs, uint64 signBlock) = flareSystemsManager.getVoterUptimeVoteSignInfo(1, voters[1]);
        assertEq(signTs, uint64(block.timestamp));
        assertEq(signBlock, uint64(block.number));

        // reading data for next epoch -> should revert
        vm.expectRevert("uptime vote hash not signed yet");
        flareSystemsManager.getVoterUptimeVoteSignInfo(2, voters[1]);

        // new signing policy already signed -> should revert
        vm.expectRevert("uptime vote hash already signed");
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);
    }

    function testRevertSignUptimeVotesTwice() public {
        _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        _moveToSignUptimeStart();

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);

        // should revert when trying to sign again
        vm.expectRevert("voter already signed");
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);
    }

    function testRevertSignUptimeVoteInvalidSignature() public {
        _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);

        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        _moveToSignUptimeStart();

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(address(0), votersWeight[0])
        );
        vm.expectRevert("signature invalid");
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);
    }

    // sign rewards tests
    function testRevertSignRewardsHashZero() public {
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 3);
        bytes32 messageHash = keccak256(abi.encode(1, keccak256(abi.encode(noOfWeightBasedClaims)), bytes32(0)));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);

        vm.expectRevert("rewards hash zero");
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, bytes32(0), signature);
    }

    function testRevertSignRewardsEpochNotEnded() public {
        bytes32 rewardsHash = keccak256("rewards hash");
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 3);
        bytes32 messageHash = keccak256(abi.encode(0, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);

        vm.expectRevert("epoch not ended yet");
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsSigningPolicyNotSigned() public {
        _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);


        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 rewardsHash = keccak256("rewards hash");
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 3);
        messageHash = keccak256(abi.encode(0, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        vm.expectRevert("signing policy not signed yet");
        flareSystemsManager.signRewards(0, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsUptimeVoteNotSigned() public {
        _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 rewardsHash = keccak256("rewards hash");
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 3);
        messageHash = keccak256(abi.encode(1, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        vm.expectRevert("uptime vote hash not signed yet");
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testSignRewards() public {
        _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        _moveToSignUptimeStart();

        // sign uptime vote
        bytes32 uptimeHash = keccak256("uptime vote hash");
        messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);

        // uint64[] memory rewardsSignStart = new uint64[](2);
        // rewardsSignStart[0] = uint64(block.timestamp);
        // rewardsSignStart[1] = uint64(block.number);

        // sign rewards
        bytes32 rewardsHash = keccak256("rewards hash");
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 3);
        messageHash = keccak256(abi.encode(1, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit RewardsSigned(1, signingAddresses[0], voters[0],
            rewardsHash, noOfWeightBasedClaims, uint64(block.timestamp), false);
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);

        vm.warp(block.timestamp + 123);
        vm.roll(block.number + 321);
        // voter1 signs
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit RewardsSigned(1, signingAddresses[1], voters[1],
            rewardsHash, noOfWeightBasedClaims, uint64(block.timestamp), true);
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);

        (uint64 signTs, uint64 signBlock) = flareSystemsManager.getVoterRewardsSignInfo(1, voters[1]);
        assertEq(signTs, uint64(block.timestamp));
        assertEq(signBlock, uint64(block.number));

        uint64[] memory rewardsSignInfo = new uint64[](4);
        (rewardsSignInfo[0], rewardsSignInfo[1], rewardsSignInfo[2], rewardsSignInfo[3]) =
            flareSystemsManager.getRewardsSignInfo(1);
        assertEq(rewardsSignInfo[0], uint64(block.timestamp - 123));
        assertEq(rewardsSignInfo[1], uint64(block.number - 321));
        assertEq(rewardsSignInfo[2], uint64(block.timestamp));
        assertEq(rewardsSignInfo[3], uint64(block.number));

        // reading data for next epoch -> should revert
        vm.expectRevert("rewards hash not signed yet");
        flareSystemsManager.getVoterRewardsSignInfo(2, voters[1]);

        // new signing policy already signed -> should revert
        vm.expectRevert("rewards hash already signed");
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsTwice() public {
        _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        _moveToSignUptimeStart();

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        _moveToSignUptimeStart();

        // sign uptime vote
        bytes32 uptimeHash = keccak256("uptime vote hash");
        messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);

        // sign rewards
        bytes32 rewardsHash = keccak256("rewards hash");
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 3);
        messageHash = keccak256(abi.encode(1, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);

        // should revert when trying to sign again
        vm.expectRevert("voter already signed");
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsInvalidSignature() public {
        _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        _moveToSignUptimeStart();

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        _moveToSignUptimeStart();

        // sign uptime vote
        bytes32 uptimeHash = keccak256("uptime vote hash");
        messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemsManager.signUptimeVote(1, uptimeHash, signature);

        // sign rewards
        bytes32 rewardsHash = keccak256("rewards hash");
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 3);
        messageHash = keccak256(abi.encode(1, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(address(0), votersWeight[0])
        );
        vm.expectRevert("signature invalid");
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    // set rewards hash tests

    function testRevertSetRewardsDataRewardsHashZero() public {
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 1);
        vm.prank(governance);
        vm.expectRevert("rewards hash zero");
        flareSystemsManager.setRewardsData(1, noOfWeightBasedClaims, bytes32(0));
    }

    function testRevertSetRewardsDataEpochNotEnded() public {
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 1);
        vm.prank(governance);
        vm.expectRevert("epoch not ended yet");
        flareSystemsManager.setRewardsData(1, noOfWeightBasedClaims, keccak256("rewards hash"));
    }

    function testRevertSetRewardsDataSigningPolicyNotSigned() public {
        _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);


        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 1);

        vm.expectRevert("signing policy not signed yet");
        vm.prank(governance);
        flareSystemsManager.setRewardsData(0, noOfWeightBasedClaims, keccak256("rewards hash"));
    }

    function testRevertSetRewardsDataRewardManagerIdNotIncreasing() public {
        testSignRewards();
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](2);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(2, 1);
        noOfWeightBasedClaims[1] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 1);
        bytes32 rewardsHash = keccak256("rewards hash 2");
        assertNotEq(flareSystemsManager.rewardsHash(1), rewardsHash);
        assertNotEq(flareSystemsManager.noOfWeightBasedClaims(1, 0), 1);
        assertNotEq(flareSystemsManager.noOfWeightBasedClaims(1, 2), 1);
        vm.expectRevert("reward manager id not increasing");
        vm.prank(governance);
        flareSystemsManager.setRewardsData(1, noOfWeightBasedClaims, rewardsHash);
    }

    function testUpdateRewardsData() public {
        testSignRewards();
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 1);
        bytes32 rewardsHash = keccak256("rewards hash 2");
        assertNotEq(flareSystemsManager.rewardsHash(1), rewardsHash);
        assertNotEq(flareSystemsManager.noOfWeightBasedClaims(1, 0), 1);
        vm.prank(governance);
        vm.expectEmit();
        emit RewardsSigned(1, governance, governance,
            rewardsHash, noOfWeightBasedClaims, uint64(block.timestamp), true);
        flareSystemsManager.setRewardsData(1, noOfWeightBasedClaims, rewardsHash);
        assertEq(flareSystemsManager.rewardsHash(1), rewardsHash);
        assertEq(flareSystemsManager.noOfWeightBasedClaims(1, 0), 1);
    }

    function testSetRewardsData() public {
        // end reward epoch 0
        _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemsManager.Signature memory signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemsManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize(); // start new reward epoch (epoch 2)

        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](2);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 3);
        noOfWeightBasedClaims[1] = IFlareSystemsManager.NumberOfWeightBasedClaims(1, 4);
        bytes32 rewardsHash = keccak256("rewards hash");
        vm.prank(governance);
        vm.expectEmit();
        emit RewardsSigned(1, governance, governance,
            rewardsHash, noOfWeightBasedClaims, uint64(block.timestamp), true);
        flareSystemsManager.setRewardsData(1, noOfWeightBasedClaims, rewardsHash);
        assertEq(flareSystemsManager.rewardsHash(1), rewardsHash);
        assertEq(flareSystemsManager.noOfWeightBasedClaims(1, 0), 3);
        assertEq(flareSystemsManager.noOfWeightBasedClaims(1, 1), 4);
        assertEq(flareSystemsManager.noOfWeightBasedClaims(1, 2), 0);
    }



    //// helper functions
    function _mockRegisteredAddresses(uint256 _epochid) internal {
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getRegisteredSubmitAddresses.selector, _epochid),
            abi.encode(new address[](0))
        );
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getRegisteredSubmitSignaturesAddresses.selector, _epochid),
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
            abi.encodeWithSelector(IIVoterRegistry.createSigningPolicySnapshot.selector, _nextEpochId),
            abi.encode(voters, votersWeight, 1000)
        );
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IIRelay.setSigningPolicy.selector),
            abi.encode(bytes32(0))
        );

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.toSigningPolicyHash.selector, _nextEpochId),
            abi.encode(bytes32(0))
        );

        vm.startPrank(flareDaemon);
        // start random acquisition
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(
                IIVoterRegistry.setNewSigningPolicyInitializationStartBlockNumber.selector, _nextEpochId),
            abi.encode()
        );
        flareSystemsManager.daemonize();

        // select vote power block
        vm.roll(block.number + 1);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();

        // initialize signing policy
        vm.warp(currentTime + 30 * 60 + 1); // after 30 minutes
        vm.roll(block.number + 21); // after 20 blocks
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IVoterRegistry.getNumberOfRegisteredVoters.selector, _nextEpochId),
            abi.encode(3)
        ); // 3 registered voters
        flareSystemsManager.daemonize();
        vm.stopPrank();
    }

    function _mockCleanupBlockNumber(uint256 _cleanupBlock) internal {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(bytes4(keccak256("cleanupBlockNumber()"))),
            abi.encode(_cleanupBlock)
        );
    }

    function _initializeSigningPolicyAndMoveToNewEpoch(uint256 _nextEpochId) private {
        _initializeSigningPolicy(_nextEpochId);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.toSigningPolicyHash.selector, _nextEpochId),
            abi.encode(bytes32("signing policy1"))
        ); // define new signing policy
        _mockRegisteredAddresses(_nextEpochId);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (_nextEpochId - 1)
        // vm.prank(flareDaemon);
        // flareSystemsManager.daemonize(); // start new reward epoch (_nextEpochId)
    }

    function _mockToSigningPolicyHash(uint256 _epochId, bytes32 _hash) private {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.toSigningPolicyHash.selector, _epochId),
            abi.encode(_hash)
        );
    }

    function _keccak256AbiEncode(string memory _value) internal pure returns(bytes32) {
        return keccak256(abi.encode(_value));
    }

    function _moveToSignUptimeStart() internal {
        vm.prank(flareDaemon);
        vm.warp(block.timestamp + 10 + 1);
        vm.roll(block.number + 2 + 1);
        flareSystemsManager.daemonize();
    }

}
