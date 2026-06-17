// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FastUpdater} from "../../../../contracts/fastUpdates/implementation/FastUpdater.sol";
import {FastUpdatesConfiguration} from "../../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol";
import {FlareSystemMock} from "../../../../contracts/fastUpdates/mock/FlareSystemMock.sol";
import {IFtsoFeedPublisher} from "../../../../contracts/userInterfaces/IFtsoFeedPublisher.sol";
import {IFastUpdater} from "../../../../contracts/userInterfaces/IFastUpdater.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {IFastUpdatesConfiguration} from "../../../../contracts/userInterfaces/IFastUpdatesConfiguration.sol";
import {Signature} from "../../../../contracts/userInterfaces/ISignature.sol";
import {SortitionCredential} from "../../../../contracts/userInterfaces/ISortition.sol";
import {G1Point} from "../../../../contracts/userInterfaces/IBn256.sol";

contract FastUpdaterTest is Test {

    uint256 private constant EPOCH_LEN = 1000;
    uint8 private constant SUBMISSION_WINDOW = 10;
    uint256 private constant NUM_FEEDS = 20;
    uint256 private constant SCALE = (1 << 127) + (1 << 111);
    uint256 private constant SAMPLE_SIZE_VAL = uint256(8) << 120;

    FastUpdater private fastUpdater;
    address private incentiveManager;
    FastUpdatesConfiguration private fastUpdatesConfig;
    FlareSystemMock private flareSystemMock;
    address private feeCalculator;
    address private ftsoFeedPublisher;

    address private governance;
    address private addressUpdater;
    address private flareDaemon;

    bytes21[] private feedIds;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        flareDaemon = makeAddr("flareDaemon");

        // Deploy mocks
        flareSystemMock = new FlareSystemMock(12345, EPOCH_LEN);
        feeCalculator = makeAddr("feeCalculator");
        vm.mockCall(
            feeCalculator,
            abi.encodeWithSignature("calculateFeeByIndices(uint256[])"),
            abi.encode(uint256(1))
        );
        ftsoFeedPublisher = makeAddr("ftsoFeedPublisher");
        incentiveManager = makeAddr("incentiveManager");
        _mockIncentiveManager(SCALE, SAMPLE_SIZE_VAL);

        // Deploy FastUpdatesConfiguration
        fastUpdatesConfig = new FastUpdatesConfiguration(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        // Deploy FastUpdater
        fastUpdater = new FastUpdater(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            uint32(vm.getBlockTimestamp()),
            90,
            SUBMISSION_WINDOW
        );

        vm.prank(governance);
        fastUpdater.setFeeDestination(address(0xdead));

        // Update contract addresses for FastUpdatesConfiguration
        {
            bytes32[] memory names = new bytes32[](2);
            address[] memory addrs = new address[](2);
            names[0] = keccak256(abi.encode("AddressUpdater"));
            names[1] = keccak256(abi.encode("FastUpdater"));
            addrs[0] = addressUpdater;
            addrs[1] = address(fastUpdater);
            vm.prank(addressUpdater);
            fastUpdatesConfig.updateContractAddresses(names, addrs);
        }

        // Update contract addresses for FastUpdater
        {
            bytes32[] memory names = new bytes32[](7);
            address[] memory addrs = new address[](7);
            names[0] = keccak256(abi.encode("AddressUpdater"));
            names[1] = keccak256(abi.encode("FlareSystemsManager"));
            names[2] = keccak256(abi.encode("FastUpdateIncentiveManager"));
            names[3] = keccak256(abi.encode("VoterRegistry"));
            names[4] = keccak256(abi.encode("FastUpdatesConfiguration"));
            names[5] = keccak256(abi.encode("FtsoFeedPublisher"));
            names[6] = keccak256(abi.encode("FeeCalculator"));
            addrs[0] = addressUpdater;
            addrs[1] = address(flareSystemMock);
            addrs[2] = incentiveManager;
            addrs[3] = address(flareSystemMock);
            addrs[4] = address(fastUpdatesConfig);
            addrs[5] = ftsoFeedPublisher;
            addrs[6] = feeCalculator;
            vm.prank(addressUpdater);
            fastUpdater.updateContractAddresses(names, addrs);
        }

        // Initialize feeds via daemonize to fill the circular list
        for (uint256 i = 0; i <= SUBMISSION_WINDOW; i++) {
            vm.roll(vm.getBlockNumber() + 1);
            vm.prank(flareDaemon);
            fastUpdater.daemonize();
        }

        // Generate feed IDs and add them
        for (uint256 i = 0; i < NUM_FEEDS; i++) {
            feedIds.push(bytes21(uint168((uint256(1) << 160) | (i + 1))));
        }

        // Mock getCurrentFeed for each feed ID
        for (uint256 i = 0; i < NUM_FEEDS; i++) {
            _mockCurrentFeed(feedIds[i], int32(int256((i + 1) * 5000)), 2);
        }

        // Add feeds
        IFastUpdatesConfiguration.FeedConfiguration[] memory configs =
            new IFastUpdatesConfiguration.FeedConfiguration[](NUM_FEEDS);
        for (uint256 i = 0; i < NUM_FEEDS; i++) {
            configs[i] = IFastUpdatesConfiguration.FeedConfiguration({
                feedId: feedIds[i],
                rewardBandValue: 2000,
                inflationShare: 200
            });
        }
        vm.prank(governance);
        fastUpdatesConfig.addFeeds(configs);
    }

    // ── Constructor revert tests ─────────────────────────────────────────────

    function testRevertDeployFlareDaemonZero() public {
        vm.expectRevert("flare daemon zero");
        new FastUpdater(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0),
            uint32(vm.getBlockTimestamp()),
            90,
            SUBMISSION_WINDOW
        );
    }

    function testRevertDeployVotingEpochDurationZero() public {
        vm.expectRevert("voting epoch duration zero");
        new FastUpdater(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            uint32(vm.getBlockTimestamp()),
            0,
            SUBMISSION_WINDOW
        );
    }

    // ── Daemonize ────────────────────────────────────────────────────────────

    function testRevertDaemonizeNotFlareDaemon() public {
        vm.prank(governance);
        vm.expectRevert("only flare daemon");
        fastUpdater.daemonize();
    }

    // ── Submission window ────────────────────────────────────────────────────

    function testSetSubmissionWindow() public {
        vm.prank(governance);
        fastUpdater.setSubmissionWindow(2);
        assertEq(fastUpdater.submissionWindow(), 2);
    }

    function testRevertSetSubmissionWindowNotGovernance() public {
        vm.prank(flareDaemon);
        vm.expectRevert("only governance");
        fastUpdater.setSubmissionWindow(2);
    }

    function testRevertSetSubmissionWindowTooBig() public {
        vm.prank(governance);
        vm.expectRevert("Submission window too big");
        fastUpdater.setSubmissionWindow(100);
    }

    // ── Fetch feeds ──────────────────────────────────────────────────────────

    function testRevertFetchFeedsIndexTooBig() public {
        uint256[] memory indices = new uint256[](3);
        indices[0] = 0;
        indices[1] = 1;
        indices[2] = NUM_FEEDS + 2;

        vm.expectRevert();
        fastUpdater.fetchCurrentFeeds{value: 1}(indices);
    }

    function testFetchCurrentFeeds() public {
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;

        (uint256[] memory feeds,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertGt(feeds[0], 0);
        assertGt(feeds[1], 0);
    }

    function testFetchAllCurrentFeeds() public {
        (bytes21[] memory fIds, uint256[] memory feeds,,) =
            fastUpdater.fetchAllCurrentFeeds{value: 1}();

        assertEq(fIds.length, NUM_FEEDS);
        assertEq(feeds.length, NUM_FEEDS);
    }

    function testRevertFetchFeedsTooLowFee() public {
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;

        address user = makeAddr("user");
        vm.prank(user);
        vm.expectRevert("too low fee");
        fastUpdater.fetchCurrentFeeds{value: 0}(indices);
    }

    function testRevertFetchAllCurrentFeedsTooLowFee() public {
        vm.expectRevert("too low fee");
        fastUpdater.fetchAllCurrentFeeds{value: 0}();
    }

    // ── Free fetch addresses ─────────────────────────────────────────────────

    function testSetFreeFetchAddresses() public {
        address[] memory freeAddrs = new address[](2);
        freeAddrs[0] = makeAddr("free1");
        freeAddrs[1] = makeAddr("free2");

        vm.prank(governance);
        fastUpdater.setFreeFetchAddresses(freeAddrs);

        address[] memory result = fastUpdater.getFreeFetchAddresses();
        assertEq(result.length, 2);
        assertEq(result[0], freeAddrs[0]);
        assertEq(result[1], freeAddrs[1]);
    }

    function testRevertSetFreeFetchAddressesNotGovernance() public {
        address[] memory freeAddrs = new address[](0);
        vm.expectRevert("only governance");
        fastUpdater.setFreeFetchAddresses(freeAddrs);
    }

    function testFreeFetchAddressCanFetchForFree() public {
        address freeUser = makeAddr("freeUser");
        address[] memory freeAddrs = new address[](1);
        freeAddrs[0] = freeUser;

        vm.prank(governance);
        fastUpdater.setFreeFetchAddresses(freeAddrs);

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;

        vm.prank(freeUser);
        (uint256[] memory feeds,,) = fastUpdater.fetchCurrentFeeds{value: 0}(indices);
        assertGt(feeds[0], 0);
    }

    function testRevertFreeFetchAddressSendsFee() public {
        address freeUser = makeAddr("freeUser");
        address[] memory freeAddrs = new address[](1);
        freeAddrs[0] = freeUser;

        vm.prank(governance);
        fastUpdater.setFreeFetchAddresses(freeAddrs);
        vm.prank(governance);
        fastUpdater.setFeeDestination(address(0xdead));

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;

        vm.deal(freeUser, 100);
        vm.prank(freeUser);
        vm.expectRevert("no fee expected");
        fastUpdater.fetchCurrentFeeds{value: 100}(indices);
    }

    // ── Fee destination ──────────────────────────────────────────────────────

    function testSetFeeDestination() public {
        address burnAddr = address(0xdead);
        vm.prank(governance);
        fastUpdater.setFeeDestination(burnAddr);
        assertEq(fastUpdater.feeDestination(), burnAddr);
    }

    function testRevertSetFeeDestinationZero() public {
        vm.prank(governance);
        vm.expectRevert("address zero");
        fastUpdater.setFeeDestination(address(0));
    }

    function testRevertSetFeeDestinationNotGovernance() public {
        vm.expectRevert("only governance");
        fastUpdater.setFeeDestination(address(0));
    }

    function testFeeGoesToDestination() public {
        address burnAddr = address(0xdead);
        vm.prank(governance);
        fastUpdater.setFeeDestination(burnAddr);

        uint256 balBefore = burnAddr.balance;

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        address payer = makeAddr("payer");
        vm.deal(payer, 10);
        vm.prank(payer);
        fastUpdater.fetchCurrentFeeds{value: 1}(indices);

        assertEq(burnAddr.balance - balBefore, 1);
    }

    // ── Number of updates ────────────────────────────────────────────────────

    function testNumberOfUpdates() public {
        vm.roll(10);
        uint256[] memory counts = fastUpdater.numberOfUpdates(5);
        assertEq(counts.length, 5);
    }

    function testRevertNumberOfUpdatesHistoryTooBig() public {
        vm.expectRevert("History size too big");
        fastUpdater.numberOfUpdates(101);
    }

    function testRevertNumberOfUpdatesInBlockFuture() public {
        vm.expectRevert("The given block is no longer or not yet available");
        fastUpdater.numberOfUpdatesInBlock(vm.getBlockNumber() + 1);
    }

    function testRevertNumberOfUpdatesInBlockTooOld() public {
        // Advance blocks far enough
        vm.roll(200);
        for (uint256 i = 0; i < SUBMISSION_WINDOW + 1; i++) {
            vm.roll(vm.getBlockNumber() + 1);
            vm.prank(flareDaemon);
            fastUpdater.daemonize();
        }

        vm.expectRevert("The given block is no longer or not yet available");
        fastUpdater.numberOfUpdatesInBlock(0);
    }

    // ── Submit updates reverts ───────────────────────────────────────────────

    function testRevertSubmitUpdatesNotYetAvailable() public {
        Signature memory sig = Signature(27, bytes32(uint256(1)), bytes32(uint256(2)));
        SortitionCredential memory cred = SortitionCredential(0, G1Point(0, 0), 0, 0);

        IFastUpdater.FastUpdates memory updates = IFastUpdater.FastUpdates({
            sortitionBlock: 99999,
            sortitionCredential: cred,
            deltas: hex"",
            signature: sig
        });

        vm.expectRevert("Updates not yet available for the given block");
        fastUpdater.submitUpdates(updates);
    }

    function testRevertSubmitUpdatesBlockTooOld() public {
        vm.prank(governance);
        fastUpdater.setSubmissionWindow(2);

        Signature memory sig = Signature(27, bytes32(uint256(1)), bytes32(uint256(2)));
        SortitionCredential memory cred = SortitionCredential(0, G1Point(0, 0), 0, 0);

        IFastUpdater.FastUpdates memory updates = IFastUpdater.FastUpdates({
            sortitionBlock: 3,
            sortitionCredential: cred,
            deltas: hex"",
            signature: sig
        });

        vm.expectRevert("Updates no longer accepted for the given block");
        fastUpdater.submitUpdates(updates);
    }

    function testRevertSubmitUpdatesMoreThanFeeds() public {
        Signature memory sig = Signature(27, bytes32(uint256(1)), bytes32(uint256(2)));
        SortitionCredential memory cred = SortitionCredential(0, G1Point(0, 0), 0, 0);

        // Create deltas with more entries than feeds (each feed = 2 bits, so ceil(feeds/4) bytes)
        // With 20 feeds, we need more than 20*2/8 = 5 bytes of delta data
        // Actually, more deltas than feeds means the byte array encodes more 2-bit deltas
        bytes memory deltas = new bytes(NUM_FEEDS + 1); // More deltas than feeds
        for (uint256 i = 0; i < NUM_FEEDS + 1; i++) {
            deltas[i] = 0x11; // Each byte = 4 deltas
        }

        IFastUpdater.FastUpdates memory updates = IFastUpdater.FastUpdates({
            sortitionBlock: vm.getBlockNumber(),
            sortitionCredential: cred,
            deltas: deltas,
            signature: sig
        });

        vm.expectRevert("More updates than available feeds");
        fastUpdater.submitUpdates(updates);
    }

    function testRevertSubmitUpdatesNoPublicKey() public {
        uint256 privKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        SortitionCredential memory cred = SortitionCredential(0, G1Point(0, 0), 0, 0);
        bytes memory deltas = hex"";

        // Create a valid ECDSA signature so recover returns a real (but unregistered) address
        bytes32 msgHash = sha256(abi.encode(vm.getBlockNumber(), cred, deltas));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, ethHash);

        IFastUpdater.FastUpdates memory updates = IFastUpdater.FastUpdates({
            sortitionBlock: vm.getBlockNumber(),
            sortitionCredential: cred,
            deltas: deltas,
            signature: Signature(v, r, s)
        });

        vm.expectRevert("Public key not registered");
        fastUpdater.submitUpdates(updates);
    }

    // ── Remove / Reset feeds ─────────────────────────────────────────────────

    function testRevertRemoveFeedsWrongAddress() public {
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;

        vm.prank(governance);
        vm.expectRevert("only fast updates configuration");
        fastUpdater.removeFeeds(indices);
    }

    function testRemoveFeeds() public {
        // Point FastUpdatesConfiguration to a controllable address
        address configController = makeAddr("configController");
        _updateFastUpdaterConfig(configController);

        // Verify feeds exist before removal
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        (uint256[] memory feedsBefore,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertGt(feedsBefore[0], 0);
        assertGt(feedsBefore[1], 0);

        // Remove feeds
        vm.prank(configController);
        fastUpdater.removeFeeds(indices);

        // Verify feeds are zeroed out
        (uint256[] memory feedsAfter, int8[] memory decimalsAfter,) =
            fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertEq(feedsAfter[0], 0);
        assertEq(feedsAfter[1], 0);
        assertEq(decimalsAfter[0], 0);
        assertEq(decimalsAfter[1], 0);
    }

    function testRevertResetFeedsWrongAddress() public {
        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert("only fast updates configuration or governance");
        fastUpdater.resetFeeds(indices);
    }

    // ── Reset feeds ────────────────────────────────────────────────────────

    function testRevertResetFeedsIndexNotSupported() public {
        // Mock getFeedId to return bytes21(0) for index 0
        vm.mockCall(
            address(fastUpdatesConfig),
            abi.encodeWithSelector(IFastUpdatesConfiguration.getFeedId.selector, uint256(0)),
            abi.encode(bytes21(0))
        );

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        vm.prank(governance);
        vm.expectRevert("index not supported");
        fastUpdater.resetFeeds(indices);
    }

    function testRevertResetFeedsTooOld() public {
        // Mock getFeedId to return a valid feedId
        vm.mockCall(
            address(fastUpdatesConfig),
            abi.encodeWithSelector(IFastUpdatesConfiguration.getFeedId.selector, uint256(0)),
            abi.encode(feedIds[0])
        );

        // Advance time far enough so the feed's votingRoundId=0 becomes too old
        // MAX_FEED_AGE_IN_VOTING_EPOCHS = 20, votingEpochDuration = 90s
        vm.warp(vm.getBlockTimestamp() + 1200000);

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        vm.prank(governance);
        vm.expectRevert("feed too old");
        fastUpdater.resetFeeds(indices);
    }

    function testRevertResetFeedValueZero() public {
        // Mock getFeedId to return a valid feedId
        bytes21 testFeedId = bytes21(uint168((uint256(1) << 160) | 99));
        vm.mockCall(
            address(fastUpdatesConfig),
            abi.encodeWithSelector(IFastUpdatesConfiguration.getFeedId.selector, uint256(5)),
            abi.encode(testFeedId)
        );

        // Mock getCurrentFeed to return feed with value = 0
        IFtsoFeedPublisher.Feed memory feed = IFtsoFeedPublisher.Feed(
            uint32(vm.getBlockTimestamp() / 90), testFeedId, 0, 6000, 5
        );
        vm.mockCall(
            ftsoFeedPublisher,
            abi.encodeWithSelector(IFtsoFeedPublisher.getCurrentFeed.selector, testFeedId),
            abi.encode(feed)
        );

        uint256[] memory indices = new uint256[](1);
        indices[0] = 5;
        vm.prank(governance);
        vm.expectRevert("feed value zero or negative");
        fastUpdater.resetFeeds(indices);
    }

    function testResetFeeds() public {
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 2;

        // Mock getFeedId for each index
        vm.mockCall(
            address(fastUpdatesConfig),
            abi.encodeWithSelector(IFastUpdatesConfiguration.getFeedId.selector, uint256(0)),
            abi.encode(feedIds[0])
        );
        vm.mockCall(
            address(fastUpdatesConfig),
            abi.encodeWithSelector(IFastUpdatesConfiguration.getFeedId.selector, uint256(2)),
            abi.encode(feedIds[2])
        );

        // Mock getCurrentFeed with new values and a recent votingRoundId
        uint32 recentRound = uint32(vm.getBlockTimestamp() / 90);
        _mockCurrentFeedWithRound(feedIds[0], 7777, 5, recentRound);
        _mockCurrentFeedWithRound(feedIds[2], 8888, 6, recentRound);

        // Fetch feeds before reset
        (uint256[] memory feedsBefore,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertGt(feedsBefore[0], 0);
        assertGt(feedsBefore[1], 0);

        // Reset feeds
        vm.prank(governance);
        fastUpdater.resetFeeds(indices);

        // Verify feeds were updated (values changed)
        (uint256[] memory feedsAfter,,) =
            fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertGt(feedsAfter[0], 0);
        assertGt(feedsAfter[1], 0);
    }

    // ── Score cutoff ─────────────────────────────────────────────────────────

    function testScoreCutoffIncrease() public {
        uint256 blockNum = vm.getBlockNumber();
        uint256 scoreCutoff = fastUpdater.blockScoreCutoff(blockNum);

        // Increase scale and sample size to simulate incentive offer
        uint256 newScale = (1 << 127) + (1 << 112); // larger precision
        uint256 newSampleSize = uint256(16) << 120;  // larger sample size
        _mockIncentiveManager(newScale, newSampleSize);

        // Daemonize to pick up new values
        vm.roll(vm.getBlockNumber() + 1);
        vm.prank(flareDaemon);
        fastUpdater.daemonize();

        // Old block's cutoff unchanged
        uint256 oldCutoff = fastUpdater.blockScoreCutoff(blockNum);
        assertEq(oldCutoff, scoreCutoff);

        // New block should have higher cutoff
        uint256 newBlockNum = vm.getBlockNumber();
        uint256 newCutoff = fastUpdater.blockScoreCutoff(newBlockNum + 1);
        assertGt(newCutoff, scoreCutoff);
    }

    function testRevertScoreCutoffNotAvailable() public {
        vm.expectRevert("score cutoff not available for the given block");
        fastUpdater.blockScoreCutoff(vm.getBlockNumber() + SUBMISSION_WINDOW + 2);
    }

    // ── Switch to fallback mode ──────────────────────────────────────────────

    function testSwitchToFallbackMode() public {
        vm.prank(flareDaemon);
        bool result = fastUpdater.switchToFallbackMode();
        assertFalse(result);
    }

    function testRevertSwitchToFallbackModeNotDaemon() public {
        vm.prank(governance);
        vm.expectRevert("only flare daemon");
        fastUpdater.switchToFallbackMode();
    }

    // ── Current score cutoff ──────────────────────────────────────────────────

    function testCurrentScoreCutoff() public {
        uint256 cutoff = fastUpdater.currentScoreCutoff();
        assertGt(cutoff, 0);
    }

    // ── Current sortition weight ──────────────────────────────────────────────

    function testCurrentSortitionWeightNoKey() public {
        // Unregistered address should revert
        address unknown = makeAddr("unknown");
        vm.expectRevert("Public key not registered");
        fastUpdater.currentSortitionWeight(unknown);
    }

    function testCurrentSortitionWeightRegistered() public {
        // Register a voter via FlareSystemMock
        address voter = makeAddr("voter");
        uint24 rewardEpochId = flareSystemMock.getCurrentRewardEpochId();
        // Use a dummy BN254 public key that is on the curve: generator point (1, 2)
        FlareSystemMock.Policy memory policy = FlareSystemMock.Policy({
            pk1: bytes32(uint256(1)),
            pk2: bytes32(uint256(2)),
            weight: 4096
        });
        flareSystemMock.registerAsVoter(rewardEpochId, voter, policy);

        uint256 weight = fastUpdater.currentSortitionWeight(voter);
        assertGt(weight, 0);
    }

    // ── Daemonize emits feeds on epoch change ─────────────────────────────────

    function testDaemonizeEmitsFeedsOnEpochChange() public {
        // Advance time by one voting epoch (90s) to trigger _fetchAllCurrentFeeds
        vm.warp(vm.getBlockTimestamp() + 90);
        vm.roll(vm.getBlockNumber() + 1);
        vm.prank(flareDaemon);
        fastUpdater.daemonize();
    }

    // ── Adjust scale of feeds on reward epoch change ──────────────────────────

    function testDaemonizeAdjustsScaleOnRewardEpochChange() public {
        // Advance to next reward epoch (EPOCH_LEN blocks) to trigger _adjustScaleOfFeeds
        vm.roll(vm.getBlockNumber() + EPOCH_LEN);
        vm.warp(vm.getBlockTimestamp() + EPOCH_LEN);
        vm.prank(flareDaemon);
        fastUpdater.daemonize();
    }

    // ── Verify public key ─────────────────────────────────────────────────────

    function testVerifyPublicKey() public {
        address voter = makeAddr("voter");

        // Generate BN254 key + Schnorr signature over sha256(voter) via ffi
        string[] memory command = new string[](4);
        command[0] = "node";
        command[1] = "test-forge/scripts/generate_sortition_data.js";
        command[2] = "verify_key";
        command[3] = vm.toString(voter);
        bytes memory result = vm.ffi(command);

        (uint256 pkx, uint256 pky, uint256 s, uint256 rx, uint256 ry) =
            abi.decode(result, (uint256, uint256, uint256, uint256, uint256));

        bytes memory verificationData = abi.encode(s, rx, ry);
        // Should not revert
        fastUpdater.verifyPublicKey(voter, bytes32(pkx), bytes32(pky), verificationData);
    }

    function testRevertVerifyPublicKeyBadPoint() public {
        bytes memory verificationData = abi.encode(uint256(1), uint256(3), uint256(4));
        vm.expectRevert();
        fastUpdater.verifyPublicKey(
            makeAddr("voter"),
            bytes32(uint256(999)),
            bytes32(uint256(999)),
            verificationData
        );
    }

    // ── Submit updates with valid sortition ──────────────────────────────────

    function testSubmitUpdates() public {
        uint256 ecdsaPrivKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address voter = vm.addr(ecdsaPrivKey);
        uint24 rewardEpochId = flareSystemMock.getCurrentRewardEpochId();

        bytes memory result = _generateSubmitData(ecdsaPrivKey);
        _registerVoterFromResult(result, voter, rewardEpochId);
        _buildAndSubmitUpdates(result);

        assertEq(fastUpdater.numberOfUpdatesInBlock(vm.getBlockNumber()), 1);
    }

    function testRevertSubmitUpdatesAlreadyProvided() public {
        uint256 ecdsaPrivKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address voter = vm.addr(ecdsaPrivKey);
        uint24 rewardEpochId = flareSystemMock.getCurrentRewardEpochId();

        bytes memory result = _generateSubmitData(ecdsaPrivKey);
        _registerVoterFromResult(result, voter, rewardEpochId);
        _buildAndSubmitUpdates(result);

        // Second submission with same data should revert
        vm.expectRevert("submission already provided");
        _buildAndSubmitUpdates(result);
    }

    // ── Submit updates with deltas ───────────────────────────────────────────

    function testSubmitUpdatesWithDeltasAndFetch() public {
        uint256 ecdsaPrivKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address voter = vm.addr(ecdsaPrivKey);
        uint24 rewardEpochId = flareSystemMock.getCurrentRewardEpochId();

        // Fetch feeds before submitting deltas
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        (uint256[] memory feedsBefore,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);

        // Submit with deltas: 0x55 = four "multiply" deltas (01 01 01 01)
        // 5 bytes for 20 feeds (short delta path, < 31 bytes)
        bytes memory result = _generateSubmitDataWithDeltas(ecdsaPrivKey, "0x5555555555");
        _registerVoterFromResult(result, voter, rewardEpochId);
        _buildAndSubmitUpdates(result);

        // Fetch feeds after — deltas should be applied, values should differ
        (uint256[] memory feedsAfter,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        // Feed 0 had delta=01 (multiply by scale), so value should increase
        assertGt(feedsAfter[0], feedsBefore[0]);
        assertGt(feedsAfter[1], feedsBefore[1]);
    }

    function testSubmitUpdatesWithDivDeltasAndFetch() public {
        uint256 ecdsaPrivKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address voter = vm.addr(ecdsaPrivKey);
        uint24 rewardEpochId = flareSystemMock.getCurrentRewardEpochId();

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        (uint256[] memory feedsBefore,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);

        // Submit with deltas: 0xFF = four "divide" deltas (11 11 11 11)
        bytes memory result = _generateSubmitDataWithDeltas(ecdsaPrivKey, "0xFFFFFFFFFF");
        _registerVoterFromResult(result, voter, rewardEpochId);
        _buildAndSubmitUpdates(result);

        (uint256[] memory feedsAfter,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        // Feed 0 had delta=11 (divide by scale), so value should decrease
        assertLt(feedsAfter[0], feedsBefore[0]);
        assertLt(feedsAfter[1], feedsBefore[1]);
    }

    function testSubmitUpdatesAndDaemonizeAppliesDeltas() public {
        uint256 ecdsaPrivKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address voter = vm.addr(ecdsaPrivKey);
        uint24 rewardEpochId = flareSystemMock.getCurrentRewardEpochId();

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        (uint256[] memory feedsBefore,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);

        // Submit deltas
        bytes memory result = _generateSubmitDataWithDeltas(ecdsaPrivKey, "0x5555555555");
        _registerVoterFromResult(result, voter, rewardEpochId);
        _buildAndSubmitUpdates(result);

        // Daemonize to apply deltas via _applySubmitted
        vm.roll(vm.getBlockNumber() + 1);
        vm.prank(flareDaemon);
        fastUpdater.daemonize();

        // Fetch after daemonize — deltas already applied
        (uint256[] memory feedsAfter,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertGt(feedsAfter[0], feedsBefore[0]);
    }

    function testFetchAllCurrentFeedsWithDeltas() public {
        uint256 ecdsaPrivKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address voter = vm.addr(ecdsaPrivKey);
        uint24 rewardEpochId = flareSystemMock.getCurrentRewardEpochId();

        bytes memory result = _generateSubmitDataWithDeltas(ecdsaPrivKey, "0x5555555555");
        _registerVoterFromResult(result, voter, rewardEpochId);
        _buildAndSubmitUpdates(result);

        // fetchAllCurrentFeeds should also apply pending deltas
        (bytes21[] memory fIds, uint256[] memory feeds,,) =
            fastUpdater.fetchAllCurrentFeeds{value: 1}();
        assertEq(fIds.length, NUM_FEEDS);
        assertEq(feeds.length, NUM_FEEDS);
        assertGt(feeds[0], 0);
    }

    function testFetchCurrentFeedsWithManyFeeds() public {
        // Add feeds to exceed 31 total (currently 20) to hit the "long decimals" assembly path
        _addExtraFeeds(15);

        // Now we have 35 feeds (> 31) → long decimals path
        uint256[] memory indices = new uint256[](3);
        indices[0] = 0;
        indices[1] = 19; // last of original 20
        indices[2] = 34; // one of the new feeds
        (uint256[] memory feeds,,) =
            fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertGt(feeds[0], 0);
        assertGt(feeds[1], 0);
        assertGt(feeds[2], 0);
    }

    function testSubmitAndFetchWithManyFeeds() public {
        // Add enough feeds to exceed 124 total for the "long deltas" assembly paths
        _addExtraFeeds(110);
        // Total feeds = 130 → 130*2 bits = 260 bits = 33 bytes (> 31 → long path)

        uint256 ecdsaPrivKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address voter = vm.addr(ecdsaPrivKey);
        uint24 rewardEpochId = flareSystemMock.getCurrentRewardEpochId();

        // Build a 33-byte delta (130 feeds): all "multiply" (01 01 01 01 ...)
        // 0x55 = 01010101 in binary
        bytes memory deltasBytes = new bytes(33);
        for (uint256 i = 0; i < 33; i++) {
            deltasBytes[i] = 0x55;
        }
        string memory deltasHex = vm.toString(deltasBytes);

        bytes memory result = _generateSubmitDataWithDeltas(ecdsaPrivKey, deltasHex);
        _registerVoterFromResult(result, voter, rewardEpochId);
        _buildAndSubmitUpdates(result);

        // Fetch feeds after submitting long deltas
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 129;
        (uint256[] memory feeds,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertGt(feeds[0], 0);
        assertGt(feeds[1], 0);

        // Daemonize to exercise _applySubmitted with long deltas
        vm.roll(vm.getBlockNumber() + 1);
        vm.prank(flareDaemon);
        fastUpdater.daemonize();

        // Fetch again after apply
        (uint256[] memory feedsAfter,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertGt(feedsAfter[0], 0);
    }

    function testFetchFeedsAfterDaemonizeWithDeltas() public {
        // Submit deltas, then daemonize (applies deltas), then fetch in a NEW block
        // This exercises _getLastSubmissionTs branch 3: submissions exist but not in current block
        uint256 ecdsaPrivKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address voter = vm.addr(ecdsaPrivKey);
        uint24 rewardEpochId = flareSystemMock.getCurrentRewardEpochId();

        bytes memory result = _generateSubmitDataWithDeltas(ecdsaPrivKey, "0x5555555555");
        _registerVoterFromResult(result, voter, rewardEpochId);
        _buildAndSubmitUpdates(result);

        // Advance block and daemonize — this applies deltas and resets backlog
        vm.roll(vm.getBlockNumber() + 1);
        vm.prank(flareDaemon);
        fastUpdater.daemonize();

        // Fetch in a new block after daemonize
        vm.roll(vm.getBlockNumber() + 1);
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        (uint256[] memory feeds,,) = fastUpdater.fetchCurrentFeeds{value: 1}(indices);
        assertGt(feeds[0], 0);
    }

    // ── Contract name ────────────────────────────────────────────────────────

    function testGetContractName() public {
        assertEq(fastUpdater.getContractName(), "FastUpdater");
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    function _mockIncentiveManager(uint256 _scale, uint256 _sampleSize) internal {
        vm.mockCall(incentiveManager, abi.encodeWithSignature("getScale()"), abi.encode(_scale));
        vm.mockCall(incentiveManager, abi.encodeWithSignature("getBaseScale()"), abi.encode(_scale));
        vm.mockCall(
            incentiveManager,
            abi.encodeWithSignature("getExpectedSampleSize()"),
            abi.encode(_sampleSize)
        );
        vm.mockCall(incentiveManager, abi.encodeWithSignature("advance()"), abi.encode());
    }

    function _mockCurrentFeed(bytes21 _feedId, int32 _value, int8 _decimals) internal {
        IFtsoFeedPublisher.Feed memory feed =
            IFtsoFeedPublisher.Feed(0, _feedId, _value, 6000, _decimals);
        vm.mockCall(
            ftsoFeedPublisher,
            abi.encodeWithSelector(IFtsoFeedPublisher.getCurrentFeed.selector, _feedId),
            abi.encode(feed)
        );
    }

    function _mockCurrentFeedWithRound(
        bytes21 _feedId,
        int32 _value,
        int8 _decimals,
        uint32 _votingRoundId
    ) internal {
        IFtsoFeedPublisher.Feed memory feed =
            IFtsoFeedPublisher.Feed(_votingRoundId, _feedId, _value, 6000, _decimals);
        vm.mockCall(
            ftsoFeedPublisher,
            abi.encodeWithSelector(IFtsoFeedPublisher.getCurrentFeed.selector, _feedId),
            abi.encode(feed)
        );
    }

    function _generateSubmitData(uint256 _ecdsaPrivKey) internal returns (bytes memory) {
        return _generateSubmitDataWithDeltas(_ecdsaPrivKey, "0x");
    }

    function _generateSubmitDataWithDeltas(
        uint256 _ecdsaPrivKey,
        string memory _deltasHex
    ) internal returns (bytes memory) {
        uint256 baseSeed = flareSystemMock.getSeed(flareSystemMock.getCurrentRewardEpochId());
        uint256 scoreCutoff = fastUpdater.blockScoreCutoff(vm.getBlockNumber());

        string[] memory command = new string[](8);
        command[0] = "node";
        command[1] = "test-forge/scripts/generate_sortition_data.js";
        command[2] = "submit_update";
        command[3] = vm.toString(baseSeed);
        command[4] = vm.toString(vm.getBlockNumber());
        command[5] = vm.toString(scoreCutoff);
        command[6] = vm.toString(_ecdsaPrivKey);
        command[7] = _deltasHex;
        return vm.ffi(command);
    }

    function _registerVoterFromResult(
        bytes memory _result,
        address _voter,
        uint24 _rewardEpochId
    ) internal {
        // Only decode pk.x and pk.y (first two uint256s)
        (uint256 pkx, uint256 pky) = abi.decode(_result, (uint256, uint256));
        FlareSystemMock.Policy memory policy = FlareSystemMock.Policy({
            pk1: bytes32(pkx),
            pk2: bytes32(pky),
            weight: 4096
        });
        flareSystemMock.registerAsVoter(_rewardEpochId, _voter, policy);
    }

    function _buildAndSubmitUpdates(bytes memory _result) internal {
        (
            , ,  // pkx, pky (already used for registration)
            uint256 replicate,
            uint256 gammax, uint256 gammay,
            uint256 c, uint256 s,
            uint8 v, bytes32 r, bytes32 ecdsaS,
            bytes memory deltas
        ) = abi.decode(_result, (
            uint256, uint256, uint256, uint256, uint256,
            uint256, uint256, uint8, bytes32, bytes32, bytes
        ));

        IFastUpdater.FastUpdates memory updates = IFastUpdater.FastUpdates({
            sortitionBlock: vm.getBlockNumber(),
            sortitionCredential: SortitionCredential(replicate, G1Point(gammax, gammay), c, s),
            deltas: deltas,
            signature: Signature(v, r, ecdsaS)
        });

        fastUpdater.submitUpdates(updates);
    }

    function _addExtraFeeds(uint256 _count) internal {
        IFastUpdatesConfiguration.FeedConfiguration[] memory configs =
            new IFastUpdatesConfiguration.FeedConfiguration[](_count);
        for (uint256 i = 0; i < _count; i++) {
            bytes21 fid = bytes21(uint168((uint256(1) << 160) | (NUM_FEEDS + i + 1)));
            _mockCurrentFeed(fid, int32(int256((i + 1) * 1000)), 3);
            configs[i] = IFastUpdatesConfiguration.FeedConfiguration({
                feedId: fid,
                rewardBandValue: 2000,
                inflationShare: 200
            });
        }
        vm.prank(governance);
        fastUpdatesConfig.addFeeds(configs);
    }

    function _updateFastUpdaterConfig(address _configAddr) internal {
        bytes32[] memory names = new bytes32[](7);
        address[] memory addrs = new address[](7);
        names[0] = keccak256(abi.encode("AddressUpdater"));
        names[1] = keccak256(abi.encode("FlareSystemsManager"));
        names[2] = keccak256(abi.encode("FastUpdateIncentiveManager"));
        names[3] = keccak256(abi.encode("VoterRegistry"));
        names[4] = keccak256(abi.encode("FastUpdatesConfiguration"));
        names[5] = keccak256(abi.encode("FtsoFeedPublisher"));
        names[6] = keccak256(abi.encode("FeeCalculator"));
        addrs[0] = addressUpdater;
        addrs[1] = address(flareSystemMock);
        addrs[2] = incentiveManager;
        addrs[3] = address(flareSystemMock);
        addrs[4] = _configAddr;
        addrs[5] = ftsoFeedPublisher;
        addrs[6] = feeCalculator;
        vm.prank(addressUpdater);
        fastUpdater.updateContractAddresses(names, addrs);
    }
}
