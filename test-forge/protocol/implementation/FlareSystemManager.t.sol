// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";

contract FlareSystemManagerTest is Test {

    FlareSystemManager private flareSystemManager;
    address private flareDaemon;
    address private governance;
    address private addressUpdater;
    address private mockRelay;
    address private mockVoterRegistry;
    address private mockRewardManager;
    address private mockCleanupBlockNumberManager;
    address private mockSubmission;

    FlareSystemManager.Settings private settings;
    FlareSystemManager.InitialSettings private initialSettings;
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
    event SingUptimeVoteEnabled(
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
        uint24 indexed rewardEpochId,           // Reward epoch id
        address indexed signingPolicyAddress,   // Address which signed this
        address indexed voter,                  // Voter (entity)
        bytes32 rewardsHash,                    // Rewards hash
        uint256 noOfWeightBasedClaims,          // Number of weight based claims
        uint64 timestamp,                       // Timestamp when this happened
        bool thresholdReached                   // Indicates if signing threshold was reached
    );

    event TriggeringVoterRegistrationFailed(uint24 rewardEpochId);
    event ClosingExpiredRewardEpochFailed(uint24 rewardEpochId);
    event SettingCleanUpBlockNumberFailed(uint64 blockNumber);

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
            10,
            2,
            500000,
            2,
            1000
        );

        initialSettings = FlareSystemManager.InitialSettings(
            5,
            0,
            0
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
        flareSystemManager.updateContractAddresses(contractNameHashes, contractAddresses);

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
            initialSettings
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
            initialSettings
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
            initialSettings
        );
    }

    function testRevertThresholdTooHigh() public {
        settings.signingPolicyThresholdPPM = PPM_MAX + 1;
        vm.prank(governance);
        vm.expectRevert("threshold too high");
        flareSystemManager.updateSettings(settings);
    }

    function testRevertZeroVoters() public {
        settings.signingPolicyMinNumberOfVoters = 0;
        vm.prank(governance);
        vm.expectRevert("zero voters");
        flareSystemManager.updateSettings(settings);
    }

    function testRevertZeroRandomAcqBlocks() public {
        initialSettings.initialRandomVotePowerBlockSelectionSize = 0;
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
            initialSettings
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
            initialSettings
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
        vm.prank(flareDaemon);
        assertEq(flareSystemManager.switchToFallbackMode(), false);

        vm.expectRevert("only flare daemon");
        flareSystemManager.switchToFallbackMode();
    }

    function testGetContrastAddresses() public {
        assertEq(address(flareSystemManager.voterRegistry()), mockVoterRegistry);
        assertEq(address(flareSystemManager.submission()), mockSubmission);
        assertEq(address(flareSystemManager.relay()), mockRelay);
    }

    /////
    function testStartRandomAcquisition() public {
        assertEq(flareSystemManager.getCurrentRewardEpochId(), 0);
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
        flareSystemManager.daemonize();
    }

    function testSelectVotePowerBlock() public {
        vm.expectRevert("vote power block not initialized yet");
        flareSystemManager.getVotePowerBlock(1);

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        _mockToSigningPolicyHash(1, bytes32(0));

        // start random acquisition
        vm.roll(199);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        vm.expectRevert("seed not initialized yet");
        flareSystemManager.getSeed(1);

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
        assertEq(flareSystemManager.isVoterRegistrationEnabled(), false);
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.getSeed(1), 123);

        // voter registration started
        assertEq(flareSystemManager.isVoterRegistrationEnabled(), true);
        // endBlock = 199, _initialRandomVotePowerBlockSelectionSize = 5
        // numberOfBlocks = 5, random (=123) % 5 = 3 -> vote power block = 199 - 3 = 196
        assertEq(flareSystemManager.getVotePowerBlock(1), 196);
        (uint256 vpBlock, bool enabled) = flareSystemManager.getVoterRegistrationData(1);
        assertEq(vpBlock, 196);
        assertEq(enabled, true);

        (uint64 startTs, uint64 startBlock, uint64 endTs, uint64 endBlock) =
            flareSystemManager.getRandomAcquisitionInfo(1);
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
        flareSystemManager.daemonize();

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
        flareSystemManager.daemonize();
        // voter registration started
        // endBlock = 199, _initialRandomVotePowerBlockSelectionSize = 5
        // numberOfBlocks = 5, random (=123) % 5 = 3 -> vote power block = 199 - 3 = 196
        assertEq(flareSystemManager.getVotePowerBlock(1), 196);
    }

    function testSelectVotePowerBlockCurrentBlock() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        // start new epoch
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(2, bytes32(0));

        // start random acquisition
        // vm.roll(199);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        // don't yet select vote power block
        flareSystemManager.daemonize();

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
        uint64 vpBlock1 = flareSystemManager.getVotePowerBlock(1);
        vm.expectEmit();
        emit VotePowerBlockSelected(2, vpBlock1, uint64(block.timestamp));
        flareSystemManager.daemonize();
    }

    function testTriggerRewardEpochSwitchover() public {
        // set switchover contracts
        switchoverContracts = new IIRewardEpochSwitchoverTrigger[](1);
        address mockSwitchover = makeAddr("switchover");
        switchoverContracts[0] = IIRewardEpochSwitchoverTrigger(mockSwitchover);
        vm.prank(governance);
        flareSystemManager.setRewardEpochSwitchoverTriggerContracts(switchoverContracts);
        IIRewardEpochSwitchoverTrigger[] memory getContracts =
            flareSystemManager.getRewardEpochSwitchoverTriggerContracts();
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
        flareSystemManager.daemonize();
    }

    function testSwitchoverTriggerContractsRevertDuplicated() public {
        switchoverContracts = new IIRewardEpochSwitchoverTrigger[](2);
        address mockSwitchover = makeAddr("switchover");
        switchoverContracts[0] = IIRewardEpochSwitchoverTrigger(mockSwitchover);
        switchoverContracts[1] = IIRewardEpochSwitchoverTrigger(mockSwitchover);

        vm.startPrank(governance);
        vm.expectRevert("duplicated contracts");
        flareSystemManager.setRewardEpochSwitchoverTriggerContracts(switchoverContracts);

        switchoverContracts[1] = IIRewardEpochSwitchoverTrigger(makeAddr("switchover2"));
        flareSystemManager.setRewardEpochSwitchoverTriggerContracts(switchoverContracts);
        vm.stopPrank();
    }

    function testTriggerVoterRegistration() public {
        // set voter register trigger contract
        address voterRegTrigger = makeAddr("voterRegTrigger");
        vm.prank(governance);
        flareSystemManager.setVoterRegistrationTriggerContract(IIVoterRegistrationTrigger(voterRegTrigger));
        assertEq(address(flareSystemManager.voterRegistrationTriggerContract()), voterRegTrigger);

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        _mockToSigningPolicyHash(1, bytes32(0));

        // start random acquisition
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

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

        flareSystemManager.daemonize();
    }


    function testTriggerVoterRegistrationFailed() public {
        // address voterRegTrigger = makeAddr("voterRegTrigger");
        // vm.prank(governance);
        // flareSystemManager.setVoterRegistrationTriggerContract(IIVoterRegistrationTrigger(voterRegTrigger));
        // assertEq(address(flareSystemManager.voterRegistrationTriggerContract()), voterRegTrigger);
        // // TODO: why is that not working?
        // vm.mockCallRevert(
        //     voterRegTrigger,
        //     abi.encodeWithSelector(IIVoterRegistrationTrigger.triggerVoterRegistration.selector, 1),
        //     abi.encode("err123")
        // );

        // set voter register trigger contract
        MockVoterRegistrationTrigger voterRegTrigger = new MockVoterRegistrationTrigger();
        vm.prank(governance);
        flareSystemManager.setVoterRegistrationTriggerContract(IIVoterRegistrationTrigger(voterRegTrigger));
        assertEq(address(flareSystemManager.voterRegistrationTriggerContract()), address(voterRegTrigger));


        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        _mockToSigningPolicyHash(1, bytes32(0));

        // start random acquisition
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

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
        flareSystemManager.daemonize();
    }

    function testTriggerCloseExpiredEpochs() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        // start reward epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        // set cleanupBlockNumber to 200; vp block for epoch 1 is 1
        _mockCleanupBlockNumber(9);

        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.closeExpiredRewardEpoch.selector),
            abi.encode()
        );
        // it should trigger closeExpiredRewardEpoch once and set rewardEpochIdToExpireNext to 2
        assertEq(flareSystemManager.rewardEpochIdToExpireNext(), 1);
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.rewardEpochIdToExpireNext(), 2);

        // start reward epoch 3
        _initializeSigningPolicyAndMoveToNewEpoch(3);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        // vp block for epoch 2 is 10 -> it should not yet trigger closeExpiredRewardEpoch for epoch 2
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.rewardEpochIdToExpireNext(), 2);

        // close epoch 2
        _mockCleanupBlockNumber(11);
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.rewardEpochIdToExpireNext(), 3);
    }

    function testSetTriggerExpirationAndCleanup() public {
        assertEq(flareSystemManager.triggerExpirationAndCleanup(), false);
        vm.prank(governance);
        flareSystemManager.setTriggerExpirationAndCleanup(true);
        assertEq(flareSystemManager.triggerExpirationAndCleanup(), true);
        vm.prank(governance);
        flareSystemManager.setTriggerExpirationAndCleanup(false);
        assertEq(flareSystemManager.triggerExpirationAndCleanup(), false);

        vm.expectRevert("only governance");
        flareSystemManager.setTriggerExpirationAndCleanup(true);
    }

    function testSetSubmit3Aligned() public {
        assertEq(flareSystemManager.submit3Aligned(), true);
        vm.prank(governance);
        flareSystemManager.setSubmit3Aligned(false);
        assertEq(flareSystemManager.submit3Aligned(), false);
        vm.prank(governance);
        flareSystemManager.setSubmit3Aligned(true);
        assertEq(flareSystemManager.submit3Aligned(), true);

        vm.expectRevert("only governance");
        flareSystemManager.setSubmit3Aligned(true);
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
        flareSystemManager.setTriggerExpirationAndCleanup(true);
        assertEq(flareSystemManager.triggerExpirationAndCleanup(), true);

        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        // start reward epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();

        // start reward epoch 3 and close epoch 1
        assertEq(flareSystemManager.rewardEpochIdToExpireNext(), 1);
        _initializeSigningPolicyAndMoveToNewEpoch(3);
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.rewardEpochIdToExpireNext(), 2);

        // start reward epoch 4 and close epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(4);
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.rewardEpochIdToExpireNext(), 3);

        // move to epoch 10 and do not close expired epoch
        vm.prank(governance);
        flareSystemManager.setTriggerExpirationAndCleanup(false);
        for (uint256 i = 5; i < 11; i++) {
            _initializeSigningPolicyAndMoveToNewEpoch(i);
            vm.prank(flareDaemon);
            flareSystemManager.daemonize();
        }
        vm.prank(governance);
        flareSystemManager.setTriggerExpirationAndCleanup(true);

        // move to epoch 11 and close epochs 3-9
        _initializeSigningPolicyAndMoveToNewEpoch(11);
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.rewardEpochIdToExpireNext(), 10);
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
        flareSystemManager.setTriggerExpirationAndCleanup(true);

        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        // start reward epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();

        // start reward epoch 3 and try to close epoch 1
        _initializeSigningPolicyAndMoveToNewEpoch(3);
        vm.prank(flareDaemon);
        vm.expectEmit();
        emit ClosingExpiredRewardEpochFailed(1);
        flareSystemManager.daemonize();
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
        flareSystemManager.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.prank(governance);
        flareSystemManager.setTriggerExpirationAndCleanup(true);

        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        vm.expectEmit();
        emit SettingCleanUpBlockNumberFailed(1);
        flareSystemManager.daemonize();
    }

    function testTriggerCloseExpiredEpochsFailed() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        // start reward epoch 2
        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.startPrank(flareDaemon);
        flareSystemManager.daemonize();

        // set cleanupBlockNumber to 9; vp block for epoch 1 is 1
        _mockCleanupBlockNumber(9);
        vm.mockCallRevert(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.closeExpiredRewardEpoch.selector),
            abi.encode("err123")
        );

        vm.expectEmit();
        emit ClosingExpiredRewardEpochFailed(1);
        flareSystemManager.daemonize();
    }

    function testGetStartVotingRoundId() public {
        vm.expectRevert("reward epoch not initialized yet");
        flareSystemManager.getStartVotingRoundId(1);
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.getStartVotingRoundId(1), 3360);

        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.getStartVotingRoundId(2), 2 * 3360);

        vm.warp(block.timestamp + 5400 + 500);
        // voting round duration is 90 seconds
        // new signing policy was initialized 5 voting rounds after supposed start voting round
        // -> start voting round id should be  _getCurrentVotingEpochId() + delay) + 1
        _initializeSigningPolicyAndMoveToNewEpoch(3);
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();
        assertEq(flareSystemManager.getStartVotingRoundId(3), 3 * 3360 + 5 + 1);
    }

    function testGetThreshold() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        assertEq(flareSystemManager.getThreshold(1), 500);

        vm.prank(flareDaemon);
        flareSystemManager.daemonize();

        _initializeSigningPolicyAndMoveToNewEpoch(2);
        assertEq(flareSystemManager.getThreshold(2), 500);
    }

    function testUpdateSettings() public {
        settings = FlareSystemManager.Settings(
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
        flareSystemManager.updateSettings(settings);
        assertEq(flareSystemManager.randomAcquisitionMaxDurationSeconds(), 1);
        assertEq(flareSystemManager.randomAcquisitionMaxDurationBlocks(), 2);
        assertEq(flareSystemManager.newSigningPolicyInitializationStartSeconds(), 3);
        assertEq(flareSystemManager.newSigningPolicyMinNumberOfVotingRoundsDelay(), 4);
        assertEq(flareSystemManager.voterRegistrationMinDurationSeconds(), 5);
        assertEq(flareSystemManager.voterRegistrationMinDurationBlocks(), 6);
        assertEq(flareSystemManager.submitUptimeVoteMinDurationSeconds(), 7);
        assertEq(flareSystemManager.submitUptimeVoteMinDurationBlocks(), 8);
        assertEq(flareSystemManager.signingPolicyThresholdPPM(), 9);
        assertEq(flareSystemManager.signingPolicyMinNumberOfVoters(), 10);
        assertEq(flareSystemManager.rewardExpiryOffsetSeconds(), 11);
    }

    //// sign signing policy tests
    function testRevertInvalidNewSigningPolicyHash() public {
        _mockToSigningPolicyHash(1, bytes32(0));

        bytes32 newSigningPolicyHash = keccak256("new signing policy hash");
        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);

        vm.expectRevert("new signing policy hash invalid");
        flareSystemManager.signNewSigningPolicy(1, newSigningPolicyHash, signature);
    }

    function testSignNewSigningPolicy() public {
        assertEq(flareSystemManager.isVoterRegistrationEnabled(), false);
        _initializeSigningPolicy(1);
        // signing policy initialized -> voter registration period ended
        assertEq(flareSystemManager.isVoterRegistrationEnabled(), false);

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
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);


        // move in time and voter0 signs
        uint64 signPolicyStartTs = uint64(block.timestamp);
        uint64 signPolicyStartBlock = uint64(block.number);
        vm.warp(signPolicyStartTs + 100);
        vm.roll(signPolicyStartBlock + 100);

        vm.expectEmit();
        emit SigningPolicySigned(1, signingAddresses[0], voters[0], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(1, newSigningPolicyHash, signature);
        (uint64 signTs, uint64 signBlock) = flareSystemManager.getVoterSigningPolicySignInfo(1, voters[0]);
        assertEq(signTs, signPolicyStartTs + 100);
        assertEq(signBlock, signPolicyStartBlock + 100);


        uint64[] memory signingPolicyInfo = new uint64[](4);
        (signingPolicyInfo[0], signingPolicyInfo[1], signingPolicyInfo[2], signingPolicyInfo[3]) =
            flareSystemManager.getSigningPolicySignInfo(1);
        assertEq(signingPolicyInfo[0], signPolicyStartTs);
        assertEq(signingPolicyInfo[1], signPolicyStartBlock);
        assertEq(signingPolicyInfo[2], signPolicyStartTs + 100);
        assertEq(signingPolicyInfo[3], signPolicyStartBlock + 100);

        // new signing policy already signed -> should revert
        vm.expectRevert("new signing policy already signed");
        flareSystemManager.signNewSigningPolicy(1, newSigningPolicyHash, signature);


        //// sign signing policy for epoch 2
        _mockRegisteredAddresses(1);

        // start new reward epoch - epoch 1
        vm.warp(block.timestamp + 5400 - 100); // after end of reward epoch
        vm.prank(flareDaemon);
        flareSystemManager.daemonize();

        _initializeSigningPolicy(2);
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        // voter0 signs
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[0], voters[0], uint64(block.timestamp), false);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);
        (signTs, signBlock) = flareSystemManager.getVoterSigningPolicySignInfo(2, voters[0]);
        assertEq(signTs, uint64(block.timestamp));
        assertEq(signBlock, uint64(block.number));

        // voter1 signs; threshold (500) is reached
        signPolicyStartTs = uint64(block.timestamp);
        signPolicyStartBlock = uint64(block.number);
        vm.warp(signPolicyStartTs + 12);
        vm.roll(signPolicyStartBlock + 13);
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        (signTs, signBlock) = flareSystemManager.getVoterSigningPolicySignInfo(2, voters[1]);
        assertEq(signTs, uint64(block.timestamp));
        assertEq(signBlock, uint64(block.number));

        (signingPolicyInfo[0], signingPolicyInfo[1], signingPolicyInfo[2], signingPolicyInfo[3]) =
            flareSystemManager.getSigningPolicySignInfo(2);
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
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
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

        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
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
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);

        vm.expectRevert("epoch not ended yet");
        flareSystemManager.signUptimeVote(0, uptimeHash, signature);
    }

    function testRevertSignUptimeVoteHashZero() public {
        bytes32 messageHash = keccak256(abi.encode(0, bytes32(0)));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);

        vm.expectRevert("uptime vote hash zero");
        flareSystemManager.signUptimeVote(0, bytes32(0), signature);
    }

    function testSignUptimeVote() public {
        _initializeSigningPolicy(1);

        // define new signing policy
        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);

        // define new signing policy
        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        // reward epoch 1 is already finished.
        // First transaction in the block (daemonize() call will change `currentRewardEpochExpectedEndTs` value)
        assertEq(flareSystemManager.getCurrentRewardEpochId(), 1);
        vm.prank(flareDaemon);
        vm.expectEmit();
        emit RewardEpochStarted(2, 2 * 3360, uint64(block.timestamp));
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)
        assertEq(flareSystemManager.getCurrentRewardEpochId(), 2);
        (uint64 startTs, uint64 startBlock) = flareSystemManager.getRewardEpochStartInfo(2);
        assertEq(startTs, uint64(block.timestamp));
        assertEq(startBlock, uint64(block.number));

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[0], voters[0], uptimeHash, uint64(block.timestamp), false);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        (uint64 signTs, uint64 signBlock) = flareSystemManager.getVoterUptimeVoteSignInfo(1, voters[1]);
        assertEq(signTs, uint64(block.timestamp));
        assertEq(signBlock, uint64(block.number));

        // new signing policy already signed -> should revert
        vm.expectRevert("uptime vote hash already signed");
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);
    }

    function testRevertSignUptimeVotesTwice() public {
        _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        // should revert when trying to sign again
        vm.expectRevert("voter already signed");
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);
    }

    function testRevertSignUptimeVoteInvalidSignature() public {
        _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);

        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        bytes32 uptimeHash = keccak256("uptime vote hash");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(address(0), votersWeight[0])
        );
        vm.expectRevert("signature invalid");
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);
    }

    // sign rewards tests
    function testRevertSignRewardsHashZero() public {
        uint64 noOfWeightBasedClaims = 3;
        bytes32 messageHash = keccak256(abi.encode(0, noOfWeightBasedClaims, bytes32(0)));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);

        vm.expectRevert("rewards hash zero");
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, bytes32(0), signature);
    }

    function testRevertSignRewardsEpochNotEnded() public {
        bytes32 rewardsHash = keccak256("rewards hash");
        uint64 noOfWeightBasedClaims = 3;
        bytes32 messageHash = keccak256(abi.encode(0, noOfWeightBasedClaims, rewardsHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);

        vm.expectRevert("epoch not ended yet");
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsSigningPolicyNotSigned() public {
        _initializeSigningPolicy(1);

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);


        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

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
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

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

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, bytes32("signing policy2"));

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        // sign uptime vote
        bytes32 uptimeHash = keccak256("uptime vote hash");
        messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.expectEmit();
        emit UptimeVoteSigned(1, signingAddresses[1], voters[1], uptimeHash, uint64(block.timestamp), true);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        // uint64[] memory rewardsSignStart = new uint64[](2);
        // rewardsSignStart[0] = uint64(block.timestamp);
        // rewardsSignStart[1] = uint64(block.number);

        // sign rewards
        bytes32 rewardsHash = keccak256("rewards hash");
        uint64 noOfWeightBasedClaims = 3;
        messageHash = keccak256(abi.encode(1, noOfWeightBasedClaims, rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.expectEmit();
        emit RewardsSigned(1, signingAddresses[0], voters[0],
            rewardsHash, noOfWeightBasedClaims, uint64(block.timestamp), false);
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);

        vm.warp(block.timestamp + 123);
        vm.roll(block.number + 321);
        // voter1 signs
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.expectEmit();
        emit RewardsSigned(1, signingAddresses[1], voters[1],
            rewardsHash, noOfWeightBasedClaims, uint64(block.timestamp), true);
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);

        (uint64 signTs, uint64 signBlock) = flareSystemManager.getVoterRewardsSignInfo(1, voters[1]);
        assertEq(signTs, uint64(block.timestamp));
        assertEq(signBlock, uint64(block.number));

        uint64[] memory rewardsSignInfo = new uint64[](4);
        (rewardsSignInfo[0], rewardsSignInfo[1], rewardsSignInfo[2], rewardsSignInfo[3]) =
            flareSystemManager.getRewardsSignInfo(1);
        assertEq(rewardsSignInfo[0], uint64(block.timestamp - 123));
        assertEq(rewardsSignInfo[1], uint64(block.number - 321));
        assertEq(rewardsSignInfo[2], uint64(block.timestamp));
        assertEq(rewardsSignInfo[3], uint64(block.number));


        // new signing policy already signed -> should revert
        vm.expectRevert("rewards hash already signed");
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsTwice() public {
         _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        // sign uptime vote
        bytes32 uptimeHash = keccak256("uptime vote hash");
        messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
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
        signature = IFlareSystemManager.Signature(v, r, s);
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);

        // should revert when trying to sign again
        vm.expectRevert("voter already signed");
        flareSystemManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signature);
    }

    function testRevertSignRewardsInvalidSignature() public {
        _initializeSigningPolicy(1);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        bytes32 newSigningPolicyHash = keccak256("signing policy2");
        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        bytes32 messageHash = newSigningPolicyHash;
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // voter0 signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        IFlareSystemManager.Signature memory signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
            abi.encode(voters[0], votersWeight[0])
        );
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        // voter1 signs; threshold (500) is reached
        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[1]),
            abi.encode(voters[1], votersWeight[1])
        );
        vm.expectEmit();
        emit SigningPolicySigned(2, signingAddresses[1], voters[1], uint64(block.timestamp), true);
        flareSystemManager.signNewSigningPolicy(2, newSigningPolicyHash, signature);

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

        _mockRegisteredAddresses(1);
        vm.warp(block.timestamp + 5400); // after end of current reward epoch (0)
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch

        // initialize another reward epoch
        _initializeSigningPolicy(2);

        _mockToSigningPolicyHash(2, newSigningPolicyHash);

        _mockRegisteredAddresses(2);
        vm.warp(block.timestamp + 5400); // after end of reward epoch 1
        vm.prank(flareDaemon);
        flareSystemManager.daemonize(); // start new reward epoch (epoch 2)

        // sign uptime vote
        bytes32 uptimeHash = keccak256("uptime vote hash");
        messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (v, r, s) = vm.sign(signingAddressesPk[0], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
        flareSystemManager.signUptimeVote(1, uptimeHash, signature);

        (v, r, s) = vm.sign(signingAddressesPk[1], signedMessageHash);
        signature = IFlareSystemManager.Signature(v, r, s);
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
        signature = IFlareSystemManager.Signature(v, r, s);
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IIVoterRegistry.getVoterWithNormalisedWeight.selector, 1, signingAddresses[0]),
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

        _mockToSigningPolicyHash(1, bytes32("signing policy1"));

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
        flareSystemManager.daemonize();

        // select vote power block
        vm.roll(block.number + 1);
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, true, currentTime + 1)
        );
        flareSystemManager.daemonize();

        // initialize signing policy
        vm.warp(currentTime + 30 * 60 + 1); // after 30 minutes
        vm.roll(block.number + 21); // after 20 blocks
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(IVoterRegistry.getNumberOfRegisteredVoters.selector, _nextEpochId),
            abi.encode(3)
        ); // 3 registered voters
        flareSystemManager.daemonize();
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
        // flareSystemManager.daemonize(); // start new reward epoch (_nextEpochId)
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

}

contract MockVoterRegistrationTrigger is IIVoterRegistrationTrigger {
    //solhint-disable-next-line no-unused-vars
        function triggerVoterRegistration(uint24 _rewardEpochId) external {
            revert("error456");
        }
}

contract MockCleanupBlockNumberManager is IICleanupBlockNumberManager {
    //solhint-disable-next-line no-unused-vars
        function setCleanUpBlockNumber(uint256 _cleanupBlock) external {
            revert("error123");
        }
}
