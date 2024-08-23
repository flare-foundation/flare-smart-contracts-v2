// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/fscV1/implementation/FtsoManagerProxy.sol";
import "../../../../contracts/protocol/implementation/FlareSystemsManager.sol";
import "../../../../contracts/mock/IIIFtsoRegistry.sol";
import "../../../../contracts/fscV1/implementation/FtsoProxy.sol";
import "../../../../contracts/protocol/interface/IIFtsoManagerProxy.sol";
import "../../../../contracts/mock/IIIPriceSubmitter.sol";

// solhint-disable-next-line max-states-count
contract FtsoManagerProxyTest is Test {

    FtsoManagerProxy private ftsoManagerProxy;
    address private flareDaemon;
    address private governance;
    address private addressUpdater;
    address private mockRewardManager; // FtsoRewardManagerProxy
    address private mockRewardManagerV2; // RewardManager

    FlareSystemsManager private flareSystemsManager;
    address private mockRelay;
    address private mockVoterRegistry;
    address private mockCleanupBlockNumberManager;
    address private mockSubmission;
    address private mockFastUpdater;
    address private mockFastUpdatesConfiguration;
    IIIFtsoRegistry private ftsoRegistry;
    address private ftsoRegistryProxy;
    IIIFtsoRegistry private registry;
    IIIPriceSubmitter private priceSubmitter;

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

    IFtso private ftso1;
    IFtso private ftso2;

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
        mockRewardManager = makeAddr("ftsoRewardManagerProxy");
        mockRewardManagerV2 = makeAddr("rewardManagerV2");
        mockVoterRegistry = makeAddr("voterRegistry");
        mockCleanupBlockNumberManager = makeAddr("cleanupBlockNumberManager");
        mockFastUpdater = makeAddr("fastUpdater");
        mockFastUpdatesConfiguration = makeAddr("fastUpdatesConfiguration");


        ftsoRegistry = IIIFtsoRegistry(deployCode(
            "artifacts-forge/FlareSmartContracts.sol/FtsoRegistry.json",
            abi.encode()
        ));

        ftsoRegistryProxy = deployCode(
            "artifacts-forge/FlareSmartContracts.sol/FtsoRegistryProxy.json",
            abi.encode(governance, address(ftsoRegistry))
        );

        registry = IIIFtsoRegistry(ftsoRegistryProxy);

        vm.prank(governance);
        registry.initialiseRegistry(addressUpdater);

        // price submitter
        deployCodeTo(
            "artifacts-forge/FlareSmartContracts.sol/PriceSubmitter.json",
            abi.encode(),
            0x1000000000000000000000000000000000000003
        );
        priceSubmitter = IIIPriceSubmitter(0x1000000000000000000000000000000000000003);
        priceSubmitter.initialiseFixedAddress();
        address submitterGovernance = address(0xfffEc6C83c8BF5c3F4AE0cCF8c45CE20E4560BD7);
        vm.prank(submitterGovernance);
        priceSubmitter.setAddressUpdater(addressUpdater);


        ftsoManagerProxy = new FtsoManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            makeAddr("oldFtsoManager")
        );

        //// update contract addresses
        vm.startPrank(addressUpdater);
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
        contractAddresses[4] = mockRewardManagerV2;
        contractAddresses[5] = mockCleanupBlockNumberManager;
        flareSystemsManager.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("FtsoRegistry"));
        contractNameHashes[1] = keccak256(abi.encode("FtsoManager"));
        contractNameHashes[2] = keccak256(abi.encode("VoterWhitelister"));
        contractNameHashes[3] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = address(registry);
        contractAddresses[1] = address(ftsoManagerProxy);
        contractAddresses[2] = makeAddr("voterWhitelister");
        contractAddresses[3] = addressUpdater;
        priceSubmitter.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](8);
        contractAddresses = new address[](8);
        contractNameHashes[0] = keccak256(abi.encode("FtsoRewardManager"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[4] = keccak256(abi.encode("Relay"));
        contractNameHashes[5] = keccak256(abi.encode("FastUpdater"));
        contractNameHashes[6] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractNameHashes[7] = keccak256(abi.encode("FtsoRegistry"));
        contractAddresses[0] = mockRewardManager;
        contractAddresses[1] = mockRewardManagerV2;
        contractAddresses[2] = address(flareSystemsManager);
        contractAddresses[3] = addressUpdater;
        contractAddresses[4] = mockRelay;
        contractAddresses[5] = mockFastUpdater;
        contractAddresses[6] = mockFastUpdatesConfiguration;
        contractAddresses[7] = address(registry);
        ftsoManagerProxy.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("FtsoManager"));
        contractNameHashes[1] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = address(ftsoManagerProxy);
        contractAddresses[1] = addressUpdater;
        registry.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

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

        ftso1 = new FtsoProxy(
            "BTC",
            bytes21("BTC"),
            100,
            IIFtsoManagerProxy(address(ftsoManagerProxy))
        );
        ftso2 = new FtsoProxy(
            "FLR",
            bytes21("FLR"),
            100,
            IIFtsoManagerProxy(address(ftsoManagerProxy))
        );
    }

    function testContractAddresses() public {
        assertEq(ftsoManagerProxy.oldFtsoManager(), makeAddr("oldFtsoManager"));
        assertEq(address(ftsoManagerProxy.rewardManager()), mockRewardManager);
        assertEq(address(ftsoManagerProxy.flareSystemsManager()), address(flareSystemsManager));
        assertEq(address(ftsoManagerProxy.rewardManagerV2()), mockRewardManagerV2);
    }

    function testGetRewardEpochVotePowerBlock() public {
        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);

        _mockToSigningPolicyHash(1, bytes32(0));

        // start random acquisition
        vm.roll(199);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();

        vm.roll(234);
        vm.warp(currentTime + uint64(11));
        // select vote power block
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();
        // endBlock = 199, _initialRandomVotePowerBlockSelectionSize = 5
        // numberOfBlocks = 5, random (=123) % 5 = 3 -> vote power block = 199 - 3 = 196
        assertEq(flareSystemsManager.getVotePowerBlock(1), 196);
        assertEq(ftsoManagerProxy.getRewardEpochVotePowerBlock(1), 196);
        assertEq(ftsoManagerProxy.getVotePowerBlock(1), 196);
    }

    function testGetCurrentRewardEpoch() public {
        assertEq(ftsoManagerProxy.getCurrentRewardEpochId(), 0);
        for (uint256 i = 1; i < 12; i++) {
            _initializeSigningPolicyAndMoveToNewEpoch(i);
            vm.prank(flareDaemon);
            flareSystemsManager.daemonize();
            assertEq(ftsoManagerProxy.getCurrentRewardEpochId(), i);
            assertEq(ftsoManagerProxy.getCurrentRewardEpoch(), i);
        }
    }

    function testGetCurrentPriceEpochId() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(ftsoManagerProxy.getCurrentPriceEpochId(), 3360);
        assertEq(ftsoManagerProxy.getCurrentVotingEpochId(), 3360);

        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(ftsoManagerProxy.getCurrentPriceEpochId(), 2 * 3360);
        assertEq(ftsoManagerProxy.getCurrentVotingEpochId(), 2 * 3360);

        // move 5 voting rounds
        vm.warp(block.timestamp + 5 * 90);
        assertEq(ftsoManagerProxy.getCurrentPriceEpochId(), 2 * 3360 + 5);
        assertEq(ftsoManagerProxy.getCurrentVotingEpochId(), 2 * 3360 + 5);
    }

    function testGetCurrentPriceEpochData() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();

        uint256 firstVotingEpochStartTs = 1000;

        (uint256 priceEpochId, uint256 priceEpochStartTimestamp,
            uint256 priceEpochEndTimestamp, uint256 priceEpochRevealEndTimestamp,
            uint256 currentTimestamp
        ) = ftsoManagerProxy.getCurrentPriceEpochData();
        assertEq(priceEpochId, 3360);
        assertEq(priceEpochStartTimestamp, firstVotingEpochStartTs + 3360 * 90);
        assertEq(priceEpochEndTimestamp, firstVotingEpochStartTs + 3360 * 90 + 90);
        assertEq(priceEpochRevealEndTimestamp, firstVotingEpochStartTs + 3360 * 90 + 90 + 45);
        assertEq(currentTimestamp, block.timestamp);
    }

    function testGetPriceEpochConfiguration() public {
        (uint256 firstPriceEpochStart, uint256 priceEpochDuration, uint256 revealEpochDuration) =
            ftsoManagerProxy.getPriceEpochConfiguration();
        assertEq(firstPriceEpochStart, 1000);
        assertEq(priceEpochDuration, 90);
        assertEq(revealEpochDuration, 45);
    }

    function testGetRewardEpochConfiguration() public {
        (uint256 firstRewardEpochStart, uint256 rewardEpochDuration) =
            ftsoManagerProxy.getRewardEpochConfiguration();
        assertEq(firstRewardEpochStart, 1000 + 0);
        assertEq(rewardEpochDuration, 3360 * 90);

        FlareSystemsManager flareSystemsManager1 = new FlareSystemsManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            9876,
            VOTING_EPOCH_DURATION_SEC,
            8,
            1234,
            initialSettings
        );
        contractNameHashes = new bytes32[](8);
        contractAddresses = new address[](8);
        contractNameHashes[0] = keccak256(abi.encode("FtsoRewardManager"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[4] = keccak256(abi.encode("Relay"));
        contractNameHashes[5] = keccak256(abi.encode("FastUpdater"));
        contractNameHashes[6] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractNameHashes[7] = keccak256(abi.encode("FtsoRegistry"));
        contractAddresses[0] = mockRewardManager;
        contractAddresses[1] = mockRewardManagerV2;
        contractAddresses[2] = address(flareSystemsManager1);
        contractAddresses[3] = addressUpdater;
        contractAddresses[4] = mockRelay;
        contractAddresses[5] = mockFastUpdater;
        contractAddresses[6] = mockFastUpdatesConfiguration;
        contractAddresses[7] = address(registry);
        vm.prank(addressUpdater);
        ftsoManagerProxy.updateContractAddresses(contractNameHashes, contractAddresses);

        (firstRewardEpochStart, rewardEpochDuration) =
            ftsoManagerProxy.getRewardEpochConfiguration();
        assertEq(firstRewardEpochStart, 9876 + 8 * 90);
        assertEq(rewardEpochDuration, 1234 * 90);
    }

    function testFirstRewardEpochStartTs() public {
        assertEq(ftsoManagerProxy.firstRewardEpochStartTs(), 1000);
    }

    function testRewardEpochDurationSeconds() public {
        assertEq(ftsoManagerProxy.rewardEpochDurationSeconds(), 3360 * 90);
    }

    function testFirstVotingRoundStartTs() public {
        assertEq(ftsoManagerProxy.firstVotingRoundStartTs(), 1000);
    }

    function testVotingEpochDurationSeconds() public {
        assertEq(ftsoManagerProxy.votingEpochDurationSeconds(), 90);
    }

    function testGetStartVotingRoundId() public {
        _initializeSigningPolicyAndMoveToNewEpoch(1);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(ftsoManagerProxy.getStartVotingRoundId(1), 3360);

        _initializeSigningPolicyAndMoveToNewEpoch(2);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(ftsoManagerProxy.getStartVotingRoundId(2), 3360 * 2);
    }

    function testActive() public {
        assert(ftsoManagerProxy.active());
    }

    function testGetFallbackMode() public {
        (bool fallbackMode, IIFtso[] memory ftsos, bool[] memory ftsosFallbackMode) =
            ftsoManagerProxy.getFallbackMode();
        assert(!fallbackMode);
        assertEq(ftsos.length, 0);
        assertEq(ftsosFallbackMode.length, 0);
    }

    function testGetRewardEpochToExpireNext() public {
        vm.mockCall(
            mockRewardManagerV2,
            abi.encodeWithSelector(bytes4(keccak256("getRewardEpochIdToExpireNext()"))),
            abi.encode(8)
        );
        assertEq(ftsoManagerProxy.getRewardEpochToExpireNext(), 8);
    }

    function testAddFtsos() public {
        IFtso[] memory ftsos = new IFtso[](2);
        ftsos[0] = ftso1;
        ftsos[1] = ftso2;
        vm.prank(governance);
        ftsoManagerProxy.addFtsos(ftsos);
    }

    function testGetFtsos() public {
        IIFtso[] memory ftsos = ftsoManagerProxy.getFtsos();
        assertEq(ftsos.length, 0);

        testAddFtsos();

        ftsos = ftsoManagerProxy.getFtsos();
        assertEq(ftsos.length, 2);
        assertEq(address(ftsos[0]), address(ftso1));
        assertEq(address(ftsos[1]), address(ftso2));
    }

    function testRemoveFtso() public {
        testAddFtsos();

        IFtso[] memory ftsosToRemove = new IFtso[](1);
        ftsosToRemove[0] = ftso1;
        vm.prank(governance);
        ftsoManagerProxy.removeFtsos(ftsosToRemove);
        IIFtso[] memory ftsos = ftsoManagerProxy.getFtsos();
        assertEq(ftsos.length, 1);
        assertEq(address(ftsos[0]), address(ftso2));
    }

    function testAddFtsosRevert() public {
        FtsoManagerProxy ftsoManagerProxy1 = new FtsoManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            makeAddr("oldFtsoManager")
        );

        contractNameHashes = new bytes32[](8);
        contractAddresses = new address[](8);
        contractNameHashes[0] = keccak256(abi.encode("FtsoRewardManager"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[4] = keccak256(abi.encode("Relay"));
        contractNameHashes[5] = keccak256(abi.encode("FastUpdater"));
        contractNameHashes[6] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractNameHashes[7] = keccak256(abi.encode("FtsoRegistry"));
        contractAddresses[0] = mockRewardManager;
        contractAddresses[1] = mockRewardManagerV2;
        contractAddresses[2] = address(flareSystemsManager);
        contractAddresses[3] = addressUpdater;
        contractAddresses[4] = mockRelay;
        contractAddresses[5] = mockFastUpdater;
        contractAddresses[6] = mockFastUpdatesConfiguration;
        contractAddresses[7] = address(registry);
        vm.prank(addressUpdater);
        ftsoManagerProxy1.updateContractAddresses(contractNameHashes, contractAddresses);

        ftso2 = new FtsoProxy(
            "FLR",
            bytes21("FLR"),
            100,
            IIFtsoManagerProxy(address(ftsoManagerProxy1))
        );
        IFtso[] memory ftsos = new IFtso[](2);
        ftsos[0] = ftso1;
        ftsos[1] = ftso2;
        vm.prank(governance);
        vm.expectRevert("invalid ftso manager");
        ftsoManagerProxy.addFtsos(ftsos);
    }

    function testRemoveFtsoRevert() public {
        testAddFtsos();

        FtsoManagerProxy ftsoManagerProxy1 = new FtsoManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            makeAddr("oldFtsoManager")
        );

        contractNameHashes = new bytes32[](8);
        contractAddresses = new address[](8);
        contractNameHashes[0] = keccak256(abi.encode("FtsoRewardManager"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[4] = keccak256(abi.encode("Relay"));
        contractNameHashes[5] = keccak256(abi.encode("FastUpdater"));
        contractNameHashes[6] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractNameHashes[7] = keccak256(abi.encode("FtsoRegistry"));
        contractAddresses[0] = mockRewardManager;
        contractAddresses[1] = mockRewardManagerV2;
        contractAddresses[2] = address(flareSystemsManager);
        contractAddresses[3] = addressUpdater;
        contractAddresses[4] = mockRelay;
        contractAddresses[5] = mockFastUpdater;
        contractAddresses[6] = mockFastUpdatesConfiguration;
        contractAddresses[7] = address(registry);
        vm.prank(addressUpdater);
        ftsoManagerProxy1.updateContractAddresses(contractNameHashes, contractAddresses);

        IFtso[] memory ftsosToRemove = new IFtso[](1);
        ftsosToRemove[0] = ftso1;

        vm.prank(governance);
        vm.expectRevert("invalid ftso manager");
        ftsoManagerProxy1.removeFtsos(ftsosToRemove);
    }

    function testRemoveTrustedAddresses() public {
        address[] memory trustedAddresses = new address[](2);
        trustedAddresses[0] = makeAddr("trustedAddress0");
        trustedAddresses[1] = makeAddr("trustedAddress1");
        vm.prank(address(ftsoManagerProxy));
        priceSubmitter.setTrustedAddresses(trustedAddresses);

        address[] memory trusted = priceSubmitter.getTrustedAddresses();
        assertEq(trusted.length, 2);
        assertEq(trusted[0], trustedAddresses[0]);
        assertEq(trusted[1], trustedAddresses[1]);

        vm.prank(governance);
        ftsoManagerProxy.removeTrustedAddresses();
        assertEq(priceSubmitter.getTrustedAddresses().length, 0);
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
            mockRewardManagerV2,
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
    }

    function _mockToSigningPolicyHash(uint256 _epochId, bytes32 _hash) private {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.toSigningPolicyHash.selector, _epochId),
            abi.encode(_hash)
        );
    }

}
