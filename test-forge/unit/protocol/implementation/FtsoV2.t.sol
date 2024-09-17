// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/FtsoV2.sol";
import "../../../../contracts/userInterfaces/IFtsoFeedPublisher.sol";
import "../../../../contracts/userInterfaces/IFeeCalculator.sol";
import { FastUpdater } from "../../../../contracts/fastUpdates/implementation/FastUpdater.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdateIncentiveManager.sol";

contract FtsoV2Test is Test {

    FtsoV2 private ftsoV2;
    FastUpdater private fastUpdater;
    FastUpdatesConfiguration private fastUpdatesConfiguration;
    address private mockFeeCalculator;

    address private governance;
    address private addressUpdater;
    address private flareDaemon;
    address private mockFlareSystemsManager;
    address private mockInflation;
    address private mockRewardManager;
    address private mockFastUpdatesConfiguration;
    address private mockFtsoInflationConfigurations;
    address private mockFtsoFeedPublisher;
    FastUpdateIncentiveManager private fastUpdateIncentiveManager;
    address private mockRelay;
    address private feeDestination;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint256 constant private SAMPLE_SIZE = 0x1000000000000000000000000000000;
    uint256 constant private RANGE = 0x800000000000000000000000000;
    uint256 constant private SAMPLE_INCREASE_LIMIT = 0x100000000000000000000000000000;
    uint256 constant private RANGE_INCREASE_LIMIT = 0x8000000000000000000000000000;
    uint256 constant private RANGE_INCREASE_PRICE = 10 ** 24;
    uint256 constant private SAMPLE_SIZE_INCREASE_PRICE = 1425;
    uint256 constant private DURATION = 8;

    address private voter;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        flareDaemon = makeAddr("flareDaemon");

        ftsoV2 = new FtsoV2(
            addressUpdater
        );

        fastUpdatesConfiguration = new FastUpdatesConfiguration(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        fastUpdater = new FastUpdater(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            uint32(block.timestamp),
            90,
            10
        );
        feeDestination = makeAddr("feeDestination");
        vm.prank(governance);
        fastUpdater.setFeeDestination(feeDestination);

        fastUpdateIncentiveManager = new FastUpdateIncentiveManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            FPA.SampleSize.wrap(SAMPLE_SIZE),
            FPA.Range.wrap(RANGE),
            FPA.SampleSize.wrap(SAMPLE_INCREASE_LIMIT),
            FPA.Range.wrap(RANGE_INCREASE_LIMIT),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            FPA.Fee.wrap(RANGE_INCREASE_PRICE),
            DURATION
        );

        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockInflation = makeAddr("mockInflation");
        mockRewardManager = makeAddr("mockRewardManager");
        mockFastUpdatesConfiguration = makeAddr("mockFastUpdatesConfiguration");
        mockFtsoInflationConfigurations = makeAddr("mockFtsoInflationConfigurations");
        mockFtsoFeedPublisher = makeAddr("ftsoFeedPublisher");
        mockFeeCalculator = makeAddr("feeCalculator");
        mockRelay = makeAddr("relay");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FastUpdater"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(fastUpdater);
        fastUpdatesConfiguration.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("FastUpdateIncentiveManager"));
        contractNameHashes[3] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[4] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractNameHashes[5] = keccak256(abi.encode("FtsoFeedPublisher"));
        contractNameHashes[6] = keccak256(abi.encode("FeeCalculator"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        contractAddresses[2] = address(fastUpdateIncentiveManager);
        contractAddresses[3] = makeAddr("voterRegistry");
        contractAddresses[4] = address(fastUpdatesConfiguration);
        contractAddresses[5] = mockFtsoFeedPublisher;
        contractAddresses[6] = mockFeeCalculator;
        fastUpdater.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("FastUpdater"));
        contractAddresses[0] = address(fastUpdater);
        contractNameHashes[1] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractAddresses[1] = address(fastUpdatesConfiguration);
        contractNameHashes[2] = keccak256(abi.encode("Relay"));
        contractAddresses[2] = mockRelay;
        contractNameHashes[3] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[3] = addressUpdater;
        ftsoV2.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.stopPrank();

        voter = makeAddr("voter");
        vm.deal(voter, 1000 ether);
    }


    //// IFastUpdater
    // function testFetchCurrentFeeds() public {
    //     _addFeeds();
    //     uint256[] memory indices = new uint256[](2);
    //     indices[0] = 0;
    //     indices[1] = 1;
    //     (uint256[] memory feeds, int8[] memory decimals, uint64 timestamp) = ftsoV2.fetchCurrentFeeds(indices);
    //     assertEq(feeds.length, 2);
    //     assertEq(feeds[0], 100 * 10 ** (4 - 1));
    //     assertEq(feeds[1], 200 * 10 ** (5 - 1));
    //     assertEq(decimals.length, 2);
    //     assertEq(decimals[0], 4);
    //     assertEq(decimals[1], 5);
    //     assertEq(timestamp, 0);

    //     indices = new uint256[](1);
    //     indices[0] = 2;
    //     (feeds, decimals, timestamp) = ftsoV2.fetchCurrentFeeds(indices);
    // }

    function testGetFeedId() public {
        _addFeeds();
        assertEq(ftsoV2.getFeedId(0), bytes21("FLR"));
        assertEq(ftsoV2.getFeedId(1), bytes21("SGB"));
        assertEq(ftsoV2.getFeedId(2), bytes21("BTC"));
    }

    function testGetFeedIndex() public {
        _addFeeds();
        assertEq(ftsoV2.getFeedIndex(bytes21("FLR")), 0);
        assertEq(ftsoV2.getFeedIndex(bytes21("SGB")), 1);
        assertEq(ftsoV2.getFeedIndex(bytes21("BTC")), 2);
    }

    function testGetFeedById() public {
        _addFeeds();
        uint256 fee = 8;
        vm.mockCall(
            mockFeeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIndices.selector),
            abi.encode(fee)
        );

        (uint256 value, int8 decimals, uint64 timestamp) = ftsoV2.getFeedById{value: fee} (bytes21("FLR"));
        assertEq(value, 123456);
        assertEq(decimals, 4);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedById{value: fee} (bytes21("SGB"));
        assertEq(value, 1234567);
        assertEq(decimals, 6);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedById{value: fee} (bytes21("BTC"));
        assertEq(value, 12345678);
        assertEq(decimals, -2);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedById{value: fee} (bytes21("ETH"));
        assertEq(value, 9876543);
        assertEq(decimals, 20);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 4 * fee);
    }

    function testGetFeedByIndex() public {
        _addFeeds();
        uint256 fee = 8;
        vm.mockCall(
            mockFeeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIndices.selector),
            abi.encode(fee)
        );

        (uint256 value, int8 decimals, uint64 timestamp) = ftsoV2.getFeedByIndex{value: fee} (0);
        assertEq(value, 123456);
        assertEq(decimals, 4);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedByIndex{value: fee} (1);
        assertEq(value, 1234567);
        assertEq(decimals, 6);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedByIndex{value: fee} (2);
        assertEq(value, 12345678);
        assertEq(decimals, -2);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 3 * fee);
    }


    function testGetFeedsByIndex() public {
        _addFeeds();
        uint256 fee = 8;
        vm.mockCall(
            mockFeeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIndices.selector),
            abi.encode(fee)
        );

        uint256[] memory indices = new uint256[](3);
        indices[0] = 0;
        indices[1] = 1;
        indices[2] = 2;
        (uint256[] memory values, int8[] memory decimals, uint64 timestamp) =
            ftsoV2.getFeedsByIndex{value: fee} (indices);
        assertEq(values.length, 3);
        assertEq(values[0], 123456);
        assertEq(values[1], 1234567);
        assertEq(values[2], 12345678);
        assertEq(decimals.length, 3);
        assertEq(decimals[0], 4);
        assertEq(decimals[1], 6);
        assertEq(decimals[2], -2);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, fee);
    }

    function testGetFeedsById() public {
        _addFeeds();
        uint256 fee = 8;
        vm.mockCall(
            mockFeeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIndices.selector),
            abi.encode(fee)
        );

        bytes21[] memory feedIds = new bytes21[](3);
        feedIds[0] = bytes21("FLR");
        feedIds[1] = bytes21("SGB");
        feedIds[2] = bytes21("BTC");
        (uint256[] memory values, int8[] memory decimals, uint64 timestamp) =
            ftsoV2.getFeedsById{value: fee} (feedIds);
        assertEq(values.length, 3);
        assertEq(values[0], 123456);
        assertEq(values[1], 1234567);
        assertEq(values[2], 12345678);
        assertEq(decimals.length, 3);
        assertEq(decimals[0], 4);
        assertEq(decimals[1], 6);
        assertEq(decimals[2], -2);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, fee);
    }

    function testGetFeedByIndexInWei() public {
        _addFeeds();
        uint256 fee = 8;
        vm.mockCall(
            mockFeeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIndices.selector),
            abi.encode(fee)
        );

        (uint256 value, uint64 timestamp) = ftsoV2.getFeedByIndexInWei{value: fee} (0);
        assertEq(value, 123456 * 10 ** (18 - 4));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIndexInWei{value: fee} (1);
        assertEq(value, 1234567 * 10 ** (18 - 6));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIndexInWei{value: fee} (2);
        assertEq(value, 12345678 * 10 ** (18 + 2));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIndexInWei{value: fee} (3);
        assertEq(value, 98765);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 4 * fee);
    }

    function testGetFeedByIdInWei() public {
        _addFeeds();
        uint256 fee = 8;
        vm.mockCall(
            mockFeeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIndices.selector),
            abi.encode(fee)
        );

        (uint256 value, uint64 timestamp) = ftsoV2.getFeedByIdInWei{value: fee} (bytes21("FLR"));
        assertEq(value, 123456 * 10 ** (18 - 4));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIdInWei{value: fee} (bytes21("SGB"));
        assertEq(value, 1234567 * 10 ** (18 - 6));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIdInWei{value: fee} (bytes21("BTC"));
        assertEq(value, 12345678 * 10 ** (18 + 2));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIdInWei{value: fee} (bytes21("ETH"));
        assertEq(value, 98765);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 4 * fee);
    }

    function testGetFeedsByIdInWei() public {
        _addFeeds();
        uint256 fee = 8;
        vm.mockCall(
            mockFeeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIndices.selector),
            abi.encode(fee)
        );

        bytes21[] memory feedIds = new bytes21[](4);
        feedIds[0] = bytes21("FLR");
        feedIds[1] = bytes21("SGB");
        feedIds[2] = bytes21("BTC");
        feedIds[3] = bytes21("ETH");

        (uint256[] memory values, uint64 timestamp) = ftsoV2.getFeedsByIdInWei{value: fee} (feedIds);
        assertEq(values.length, 4);
        assertEq(values[0], 123456 * 10 ** (18 - 4));
        assertEq(values[1], 1234567 * 10 ** (18 - 6));
        assertEq(values[2], 12345678 * 10 ** (18 + 2));
        assertEq(values[3], 98765);
        assertEq(timestamp, 0);
    }

    function testGetFeedsByIndexInWei() public {
        _addFeeds();
        uint256 fee = 8;
        vm.mockCall(
            mockFeeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIndices.selector),
            abi.encode(fee)
        );

        uint256[] memory indices = new uint256[](4);
        indices[0] = 0;
        indices[1] = 1;
        indices[2] = 2;
        indices[3] = 3;

        (uint256[] memory values, uint64 timestamp) = ftsoV2.getFeedsByIndexInWei{value: fee} (indices);
        assertEq(values.length, 4);
        assertEq(values[0], 123456 * 10 ** (18 - 4));
        assertEq(values[1], 1234567 * 10 ** (18 - 6));
        assertEq(values[2], 12345678 * 10 ** (18 + 2));
        assertEq(values[3], 98765);
        assertEq(timestamp, 0);
    }

    function testVerifyFeedData() public {
        FtsoV2Interface.FeedData memory feedData1 = FtsoV2Interface.FeedData({
            votingRoundId: 2,
            id: bytes21("FLR"),
            value: 123456,
            turnoutBIPS: 1000,
            decimals: 4
        });
        FtsoV2Interface.FeedData memory feedData2 = FtsoV2Interface.FeedData({
            votingRoundId: 2,
            id: bytes21("SGB"),
            value: 123456,
            turnoutBIPS: 1000,
            decimals: 4
        });

        bytes32 leaf1 = keccak256(abi.encode(feedData1));
        bytes32 leaf2 = keccak256(abi.encode(feedData2));
        bytes32 merkleRoot = _hashPair(leaf1, leaf2);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        FtsoV2Interface.FeedDataWithProof memory feedDataWithProof = FtsoV2Interface.FeedDataWithProof({
            proof:proof,
            body: feedData1
        });

        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.merkleRoots.selector, 100, 2),
            abi.encode(merkleRoot)
        );

        assertTrue(ftsoV2.verifyFeedData(feedDataWithProof));
    }

    function testVerifyFeedDataRevert() public {
         FtsoV2Interface.FeedData memory feedData1 = FtsoV2Interface.FeedData({
            votingRoundId: 2,
            id: bytes21("FLR"),
            value: 123456,
            turnoutBIPS: 1000,
            decimals: 4
        });
        FtsoV2Interface.FeedData memory feedData2 = FtsoV2Interface.FeedData({
            votingRoundId: 2,
            id: bytes21("SGB"),
            value: 123456,
            turnoutBIPS: 1000,
            decimals: 4
        });

        bytes32 leaf2 = keccak256(abi.encode(feedData2));
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        FtsoV2Interface.FeedDataWithProof memory feedDataWithProof = FtsoV2Interface.FeedDataWithProof({
            proof:proof,
            body: feedData1
        });

        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.merkleRoots.selector, 100, 2),
            abi.encode(bytes32(0))
        );

        vm.expectRevert("merkle proof invalid");
        ftsoV2.verifyFeedData(feedDataWithProof);
    }


    ////
    function _addFeeds() public {
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](4);

        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("FLR"),
            rewardBandValue: 100,
            inflationShare: 150
        });

        feedConfigs[1] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("SGB"),
            rewardBandValue: 200,
            inflationShare: 250
        });

        feedConfigs[2] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("BTC"),
            rewardBandValue: 300,
            inflationShare: 350
        });

        feedConfigs[3] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("ETH"),
            rewardBandValue: 300,
            inflationShare: 350
        });

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("FLR")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("FLR"),
                value: 123456,
                turnoutBIPS: 1000,
                decimals: 4
            }))
        );

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("SGB")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("SGB"),
                value: 1234567,
                turnoutBIPS: 1000,
                decimals: 6
            }))
        );

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("BTC")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("BTC"),
                value: 12345678,
                turnoutBIPS: 1000,
                decimals: -2
            }))
        );

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("ETH")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("ETH"),
                value: 9876543,
                turnoutBIPS: 1000,
                decimals: 20
            }))
        );

        vm.prank(governance);
        fastUpdatesConfiguration.addFeeds(feedConfigs);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }
}