// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/FtsoV2.sol";
import "../../../../contracts/userInterfaces/IFtsoFeedPublisher.sol";
import "../../../../contracts/userInterfaces/IFeeCalculator.sol";
import { FastUpdater } from "../../../../contracts/fastUpdates/implementation/FastUpdater.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdateIncentiveManager.sol";
import "../../../../contracts/customFeeds/implementation/SFlrCustomFeed.sol";
import "../../../../contracts/fastUpdates/implementation/FeeCalculator.sol";
import "../../../../contracts/protocol/implementation/FtsoV2Proxy.sol";

// solhint-disable-next-line max-states-count
contract FtsoV2Test is Test {

    FtsoV2 private ftsoV2;
    FtsoV2 private ftsoV2Implementation;
    FtsoV2Proxy private ftsoV2Proxy;
    FastUpdater private fastUpdater;
    FastUpdatesConfiguration private fastUpdatesConfiguration;
    address private mockFlareContractRegistry;
    SFlrCustomFeed private sFlrCustomFeed;
    address private sFlr;
    FeeCalculator private feeCalculator;

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
    bytes21 private flrFeedId = bytes21(bytes.concat(bytes1(uint8(0)), bytes("FLR")));
    bytes21 private sflrFeedId = bytes21(bytes.concat(bytes1(uint8(50)), bytes("SFLR")));

    address private voter;

    event CustomFeedAdded(bytes21 indexed feedId, IICustomFeed customFeed);
    event CustomFeedReplaced(bytes21 indexed feedId, IICustomFeed oldCustomFeed, IICustomFeed newCustomFeed);
    event CustomFeedRemoved(bytes21 indexed feedId);
    event FeedIdChanged(bytes21 indexed oldFeedId, bytes21 indexed newFeedId);

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        flareDaemon = makeAddr("flareDaemon");
        sFlr = makeAddr("sFlr");
        mockFlareContractRegistry = makeAddr("flareContractRegistry");

        // deploy contracts
        ftsoV2Implementation = new FtsoV2();
        ftsoV2Proxy = new FtsoV2Proxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(ftsoV2Implementation)
        );
        ftsoV2 = FtsoV2(address(ftsoV2Proxy));

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

        feeCalculator = new FeeCalculator(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            8
        );

        sFlrCustomFeed = new SFlrCustomFeed(
            sflrFeedId,
            flrFeedId,
            IFlareContractRegistry(mockFlareContractRegistry),
            ISFlr(sFlr)
        );

        // set contract addresses
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockInflation = makeAddr("mockInflation");
        mockRewardManager = makeAddr("mockRewardManager");
        mockFastUpdatesConfiguration = makeAddr("mockFastUpdatesConfiguration");
        mockFtsoInflationConfigurations = makeAddr("mockFtsoInflationConfigurations");
        mockFtsoFeedPublisher = makeAddr("ftsoFeedPublisher");
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
        contractAddresses[6] = address(feeCalculator);
        fastUpdater.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("FastUpdater"));
        contractAddresses[0] = address(fastUpdater);
        contractNameHashes[1] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractAddresses[1] = address(fastUpdatesConfiguration);
        contractNameHashes[2] = keccak256(abi.encode("Relay"));
        contractAddresses[2] = mockRelay;
        contractNameHashes[3] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[3] = addressUpdater;
        contractNameHashes[4] = keccak256(abi.encode("FeeCalculator"));
        contractAddresses[4] = address(feeCalculator);
        ftsoV2.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractAddresses[0] = address(fastUpdatesConfiguration);
        contractNameHashes[1] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[1] = addressUpdater;
        feeCalculator.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        voter = makeAddr("voter");
        vm.deal(voter, 1000 ether);
    }

    function testGetFeedId() public {
        _addFeeds();
        assertEq(ftsoV2.getFeedId(0), flrFeedId);
        assertEq(ftsoV2.getFeedId(1), bytes21("SGB"));
        assertEq(ftsoV2.getFeedId(2), bytes21("BTC"));
    }

    function testGetFeedIndex() public {
        _addFeeds();
        assertEq(ftsoV2.getFeedIndex(flrFeedId), 0);
        assertEq(ftsoV2.getFeedIndex(bytes21("SGB")), 1);
        assertEq(ftsoV2.getFeedIndex(bytes21("BTC")), 2);
    }

    function testGetFeedById() public {
        _addFeeds();

        (uint256 value, int8 decimals, uint64 timestamp) = ftsoV2.getFeedById{value: 12} (flrFeedId);
        assertEq(value, 123456);
        assertEq(decimals, 4);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedById{value: 9} (bytes21("SGB"));
        assertEq(value, 1234567);
        assertEq(decimals, 6);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedById{value: 8} (bytes21("BTC"));
        assertEq(value, 12345678);
        assertEq(decimals, -2);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedById{value: 8} (bytes21("ETH"));
        assertEq(value, 9876543);
        assertEq(decimals, 20);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 12 + 9 + 2 * 8);
    }

    function testGetFeedByIndex() public {
        _addFeeds();

        (uint256 value, int8 decimals, uint64 timestamp) = ftsoV2.getFeedByIndex{value: 12} (0);
        assertEq(value, 123456);
        assertEq(decimals, 4);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedByIndex{value: 9} (1);
        assertEq(value, 1234567);
        assertEq(decimals, 6);
        assertEq(timestamp, 0);

        (value, decimals, timestamp) = ftsoV2.getFeedByIndex{value: 8} (2);
        assertEq(value, 12345678);
        assertEq(decimals, -2);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 12 + 9 + 8);
    }


    function testGetFeedsByIndex() public {
        _addFeeds();

        uint256[] memory indices = new uint256[](3);
        indices[0] = 0;
        indices[1] = 1;
        indices[2] = 2;
        (uint256[] memory values, int8[] memory decimals, uint64 timestamp) =
            ftsoV2.getFeedsByIndex{value: 12 + 9 + 8} (indices);
        assertEq(values.length, 3);
        assertEq(values[0], 123456);
        assertEq(values[1], 1234567);
        assertEq(values[2], 12345678);
        assertEq(decimals.length, 3);
        assertEq(decimals[0], 4);
        assertEq(decimals[1], 6);
        assertEq(decimals[2], -2);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 12 + 9 + 8);
    }

    function testGetFeedsById() public {
        _addFeeds();

        bytes21[] memory feedIds = new bytes21[](3);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("SGB");
        feedIds[2] = bytes21("BTC");
        (uint256[] memory values, int8[] memory decimals, uint64 timestamp) =
            ftsoV2.getFeedsById{value: 12 + 9 + 8} (feedIds);
        assertEq(values.length, 3);
        assertEq(values[0], 123456);
        assertEq(values[1], 1234567);
        assertEq(values[2], 12345678);
        assertEq(decimals.length, 3);
        assertEq(decimals[0], 4);
        assertEq(decimals[1], 6);
        assertEq(decimals[2], -2);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 12 + 9 + 8);
    }

    function testGetFeedByIndexInWei() public {
        _addFeeds();

        (uint256 value, uint64 timestamp) = ftsoV2.getFeedByIndexInWei{value: 12} (0);
        assertEq(value, 123456 * 10 ** (18 - 4));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIndexInWei{value: 9} (1);
        assertEq(value, 1234567 * 10 ** (18 - 6));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIndexInWei{value: 8} (2);
        assertEq(value, 12345678 * 10 ** (18 + 2));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIndexInWei{value: 8} (3);
        assertEq(value, 98765);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 37);
    }

    function testGetFeedByIdInWei() public {
        _addFeeds();
        (uint256 value, uint64 timestamp) = ftsoV2.getFeedByIdInWei{value: 12} (flrFeedId);
        assertEq(value, 123456 * 10 ** (18 - 4));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIdInWei{value: 9} (bytes21("SGB"));
        assertEq(value, 1234567 * 10 ** (18 - 6));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIdInWei{value: 8} (bytes21("BTC"));
        assertEq(value, 12345678 * 10 ** (18 + 2));
        assertEq(timestamp, 0);

        (value, timestamp) = ftsoV2.getFeedByIdInWei{value: 8} (bytes21("ETH"));
        assertEq(value, 98765);
        assertEq(timestamp, 0);

        assertEq(feeDestination.balance, 37);
    }

    function testGetFeedsByIdInWei() public {
        _addFeeds();

        bytes21[] memory feedIds = new bytes21[](4);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("SGB");
        feedIds[2] = bytes21("BTC");
        feedIds[3] = bytes21("ETH");

        (uint256[] memory values, uint64 timestamp) = ftsoV2.getFeedsByIdInWei{value: 37} (feedIds);
        assertEq(values.length, 4);
        assertEq(values[0], 123456 * 10 ** (18 - 4));
        assertEq(values[1], 1234567 * 10 ** (18 - 6));
        assertEq(values[2], 12345678 * 10 ** (18 + 2));
        assertEq(values[3], 98765);
        assertEq(timestamp, 0);
    }

    function testGetFeedsByIndexInWei() public {
        _addFeeds();

        uint256[] memory indices = new uint256[](4);
        indices[0] = 0;
        indices[1] = 1;
        indices[2] = 2;
        indices[3] = 3;

        (uint256[] memory values, uint64 timestamp) = ftsoV2.getFeedsByIndexInWei{value: 37} (indices);
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
            id: flrFeedId,
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
            id: flrFeedId,
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

    function testAddCustomFeeds() public {
        assertEq(ftsoV2.getSupportedFeedIds().length, 0);
        assertEq(ftsoV2.getCustomFeeds().length, 0);
        vm.expectEmit();
        emit CustomFeedAdded(sflrFeedId, sFlrCustomFeed);
        _addSFlrCustomFeed();
        assertEq(ftsoV2.getSupportedFeedIds().length, 1);
        assertEq(ftsoV2.getCustomFeeds()[0].feedId, sflrFeedId);
        assertEq(address(ftsoV2.getCustomFeeds()[0].customFeed), address(sFlrCustomFeed));
    }

    function testAddCustomFeedsRevertInvalidCategory() public {
        SFlrCustomFeed invalidFeed = new SFlrCustomFeed(
            bytes21(bytes.concat(bytes1(uint8(uint8(0))), bytes("SFLR"))),
            flrFeedId,
            IFlareContractRegistry(mockFlareContractRegistry),
            ISFlr(makeAddr("sFlr"))
        );
        IICustomFeed[] memory customFeeds = new IICustomFeed[](1);
        customFeeds[0] = invalidFeed;
        vm.prank(governance);
        vm.expectRevert("invalid feed category");
        ftsoV2.addCustomFeeds(customFeeds);
    }

    function testAddCustomFeedsRevertAlreadyExists() public {
        IICustomFeed[] memory customFeeds = new IICustomFeed[](1);
        customFeeds[0] = sFlrCustomFeed;
        vm.startPrank(governance);
        ftsoV2.addCustomFeeds(customFeeds);
        vm.expectRevert("feed already exists");
        ftsoV2.addCustomFeeds(customFeeds);
        vm.stopPrank();
    }

    function testReplaceCustomFeeds() public {
        IICustomFeed[] memory customFeeds = new IICustomFeed[](1);
        customFeeds[0] = sFlrCustomFeed;
        vm.prank(governance);
        ftsoV2.addCustomFeeds(customFeeds);
        assertEq(ftsoV2.getCustomFeeds().length, 1);
        assertEq(ftsoV2.getCustomFeeds()[0].feedId, sflrFeedId);
        assertEq(address(ftsoV2.getCustomFeeds()[0].customFeed), address(sFlrCustomFeed));

        SFlrCustomFeed newFeed = new SFlrCustomFeed(
            sflrFeedId,
            flrFeedId,
            IFlareContractRegistry(mockFlareContractRegistry),
            ISFlr(sFlr)
        );
        customFeeds[0] = newFeed;
        vm.prank(governance);
        vm.expectEmit();
        emit CustomFeedReplaced(sflrFeedId, sFlrCustomFeed, newFeed);
        ftsoV2.replaceCustomFeeds(customFeeds);
        assertEq(ftsoV2.getCustomFeeds().length, 1);
        assertEq(ftsoV2.getCustomFeeds()[0].feedId, sflrFeedId);
        assertEq(address(ftsoV2.getCustomFeeds()[0].customFeed), address(newFeed));
    }

    function testReplaceCustomFeedsDoesntExists() public {
        IICustomFeed[] memory customFeeds = new IICustomFeed[](1);
        customFeeds[0] = sFlrCustomFeed;
        vm.prank(governance);
        vm.expectRevert("feed does not exist");
        ftsoV2.replaceCustomFeeds(customFeeds);
    }

    function testRemoveCustomFeeds1() public {
        _addSFlrCustomFeed();
        // add another custom feed
        bytes21 sflrFeedId1 = bytes21(bytes.concat(bytes1(uint8(51)), bytes("SFLR")));
        SFlrCustomFeed sFlrCustomFeed1 = new SFlrCustomFeed(
            sflrFeedId1,
            flrFeedId,
            IFlareContractRegistry(mockFlareContractRegistry),
            ISFlr(sFlr)
        );
        IICustomFeed[] memory customFeeds = new IICustomFeed[](1);
        customFeeds[0] = sFlrCustomFeed1;
        vm.prank(governance);
        ftsoV2.addCustomFeeds(customFeeds);
        bytes21[] memory feedIds = new bytes21[](1);
        feedIds[0] = sflrFeedId;
        assertEq(ftsoV2.getCustomFeeds().length, 2);
        assertEq(ftsoV2.getCustomFeeds()[0].feedId, sflrFeedId);
        assertEq(address(ftsoV2.getCustomFeeds()[0].customFeed), address(sFlrCustomFeed));
        assertEq(ftsoV2.getCustomFeeds()[1].feedId, sflrFeedId1);
        assertEq(address(ftsoV2.getCustomFeeds()[1].customFeed), address(sFlrCustomFeed1));
        vm.prank(governance);
        ftsoV2.removeCustomFeeds(feedIds);
        assertEq(ftsoV2.getCustomFeeds().length, 1);
        assertEq(ftsoV2.getCustomFeeds()[0].feedId, sflrFeedId1);
        assertEq(address(ftsoV2.getCustomFeeds()[0].customFeed), address(sFlrCustomFeed1));
    }

    function testRemoveCustomFeeds2() public {
        _addSFlrCustomFeed();
        bytes21[] memory feedIds = new bytes21[](1);
        feedIds[0] = sflrFeedId;
        assertEq(ftsoV2.getCustomFeeds().length, 1);
        assertEq(ftsoV2.getCustomFeeds()[0].feedId, sflrFeedId);
        assertEq(address(ftsoV2.getCustomFeeds()[0].customFeed), address(sFlrCustomFeed));
        vm.prank(governance);
        ftsoV2.removeCustomFeeds(feedIds);
        assertEq(ftsoV2.getCustomFeeds().length, 0);
    }

    function testRemoveCustomFeedsRevertDoesntExist() public {
        bytes21[] memory feedIds = new bytes21[](1);
        feedIds[0] = bytes21("wrong feed");
        vm.prank(governance);
        vm.expectRevert("feed does not exist");
        ftsoV2.removeCustomFeeds(feedIds);
    }

    function testGetSupportedFeedIds() public {
        _addSFlrCustomFeed();
        _addFeeds();
        bytes21[] memory feedIds = ftsoV2.getSupportedFeedIds();
        assertEq(feedIds.length, 5);
        assertEq(feedIds[0], flrFeedId);
        assertEq(feedIds[1], bytes21("SGB"));
        assertEq(feedIds[2], bytes21("BTC"));
        assertEq(feedIds[3], bytes21("ETH"));
        assertEq(feedIds[4], sflrFeedId);

        // remove FU feed
        bytes21[] memory feedIdsToRemove = new bytes21[](1);
        feedIdsToRemove[0] = bytes21("SGB");
        vm.prank(governance);
        fastUpdatesConfiguration.removeFeeds(feedIdsToRemove);
        feedIds = ftsoV2.getSupportedFeedIds();
        assertEq(feedIds.length, 4);
        assertEq(feedIds[0], flrFeedId);
        assertEq(feedIds[1], bytes21("BTC"));
        assertEq(feedIds[2], bytes21("ETH"));
        assertEq(feedIds[3], sflrFeedId);
    }

    // feed index for custom feeds doesn't exist
    function getFeedIndexRevert() public {
        _addSFlrCustomFeed();
        vm.expectRevert("feed does not exist");
        ftsoV2.getFeedIndex(sflrFeedId);
    }

    // get custom feed
    function testGetFeedById1() public {
        _addSFlrCustomFeed();
        _addFeeds();

        _mockGetPooledFlrByShares(123456);
        _mockGetContractAddressByName("FastUpdatesConfiguration", address(fastUpdatesConfiguration));
        _mockGetContractAddressByName("FastUpdater", address(fastUpdater));
        _mockGetContractAddressByName("FeeCalculator", address(feeCalculator));

        (uint256 value, int8 decimals, uint64 timestamp) = ftsoV2.getFeedById{value: 12} (sflrFeedId);
        assertEq(value, 123456 * 2);
        assertEq(decimals, 4);
        assertEq(timestamp, 0);
    }

    function testGetFeedByIdRevert() public {
        vm.expectRevert("custom feed id not supported");
        ftsoV2.getFeedById(sflrFeedId);
    }

    // one FU feed and one custom feed
    function testGetFeedsById1() public {
        _addSFlrCustomFeed();
        _addFeeds();
        _mockGetPooledFlrByShares(123456);
        _mockGetContractAddressByName("FastUpdatesConfiguration", address(fastUpdatesConfiguration));
        _mockGetContractAddressByName("FastUpdater", address(fastUpdater));
        _mockGetContractAddressByName("FeeCalculator", address(feeCalculator));

        bytes21[] memory feedIds = new bytes21[](5);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("SGB");
        feedIds[2] = bytes21("BTC");
        feedIds[3] = bytes21("ETH");
        feedIds[4] = sflrFeedId;
        (uint256[] memory values, int8[] memory decimals, uint64 timestamp) =
            ftsoV2.getFeedsById{value: 12 * 2 + 9 + 8 * 2} (feedIds);
        assertEq(values.length, 5);
        assertEq(values[0], 123456);
        assertEq(decimals[0], 4);
        assertEq(timestamp, 0);
        assertEq(values[1], 1234567);
        assertEq(decimals[1], 6);
        assertEq(values[2], 12345678);
        assertEq(decimals[2], -2);
        assertEq(values[3], 9876543);
        assertEq(decimals[3], 20);
        assertEq(values[4], 123456 * 2);
        assertEq(decimals[4], 4);
    }

    function testGetFeedsByIdRevert() public {
        bytes21[] memory feedIds = new bytes21[](2);
        feedIds[0] = flrFeedId;
        feedIds[1] = sflrFeedId;
        vm.expectRevert("feed does not exist");
        ftsoV2.getFeedsById(feedIds);
    }

    function testGetFeedsByIdRevertCustom() public {
        _addFeeds();
        bytes21[] memory feedIds = new bytes21[](2);
        feedIds[0] = flrFeedId;
        feedIds[1] = sflrFeedId;
        vm.expectRevert("custom feed id not supported");
        ftsoV2.getFeedsById(feedIds);
    }

    function testGetFeedsByIdRevertFeeTooLow() public {
        _addFeeds();
        _addSFlrCustomFeed();
        _mockGetPooledFlrByShares(123456);
        _mockGetContractAddressByName("FastUpdatesConfiguration", address(fastUpdatesConfiguration));
        _mockGetContractAddressByName("FastUpdater", address(fastUpdater));
        _mockGetContractAddressByName("FeeCalculator", address(feeCalculator));
        bytes21[] memory feedIds = new bytes21[](5);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("SGB");
        feedIds[2] = bytes21("BTC");
        feedIds[3] = bytes21("ETH");
        feedIds[4] = sflrFeedId;
        vm.expectRevert("too low fee");
        ftsoV2.getFeedsById{value: 12 * 2 + 9 + 8} (feedIds);
    }


    function testGetFeedsByIdUseContractFunds() public {
        _addFeeds();
        _addSFlrCustomFeed();
        _mockGetPooledFlrByShares(123456);
        _mockGetContractAddressByName("FastUpdatesConfiguration", address(fastUpdatesConfiguration));
        _mockGetContractAddressByName("FastUpdater", address(fastUpdater));
        _mockGetContractAddressByName("FeeCalculator", address(feeCalculator));
        bytes21[] memory feedIds = new bytes21[](5);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("SGB");
        feedIds[2] = bytes21("BTC");
        feedIds[3] = bytes21("ETH");
        feedIds[4] = sflrFeedId;
        vm.deal(address(ftsoV2), 100);
        assertEq(address(ftsoV2).balance, 100);
        assertEq(address(fastUpdater).balance, 0);
        // send only fee for custom feed
        // fee for FU feeds will be paid from the contract balance
        (uint256[] memory values, int8[] memory decimals, uint64 timestamp) =
            ftsoV2.getFeedsById{value: 12} (feedIds);
        assertEq(values.length, 5);
        assertEq(values[0], 123456);
        assertEq(decimals[0], 4);
        assertEq(timestamp, 0);
        assertEq(values[1], 1234567);
        assertEq(decimals[1], 6);
        assertEq(values[2], 12345678);
        assertEq(decimals[2], -2);
        assertEq(values[3], 9876543);
        assertEq(decimals[3], 20);
        assertEq(values[4], 123456 * 2);
        assertEq(decimals[4], 4);
        // whole FtsoV2 balance is used to pay for FU feeds
        uint256 totalFee = 12 * 2 + 9 + 8 * 2;
        assertEq(feeDestination.balance, totalFee);
        assertEq(address(ftsoV2).balance, 0);
        // remaining fee remains on the FastUpdater contract
        assertEq(address(fastUpdater).balance, 100 - totalFee + 12);
    }

    // calculate fee
    function testCalculateFeeById1() public {
        _addSFlrCustomFeed();
        uint256 fee = 8;
        _mockGetContractAddressByName("FeeCalculator", address(feeCalculator));
        assertEq(ftsoV2.calculateFeeById(sflrFeedId), fee);
    }

    // FU feed
    function testCalculateFeeById2() public {
        _addFeeds();
        assertEq(ftsoV2.calculateFeeById(flrFeedId), 12);
    }

    function testCalculateFeedByIdRevert() public {
        vm.expectRevert("custom feed id not supported");
        ftsoV2.calculateFeeById(sflrFeedId);
    }

    function testCalculateFeeByIdRevertInvalidId() public {
        vm.expectRevert("feed does not exist");
        ftsoV2.calculateFeeById(bytes21("invalid"));
    }

    // only FU feeds
    function testCalculateFeeByIds1() public {
        _addFeeds();
        bytes21[] memory feedIds = new bytes21[](2);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("SGB");
        assertEq(ftsoV2.calculateFeeByIds(feedIds), 12 + 9);
    }

    // FU feeds and custom feeds
    function testCalculateFeeByIds2() public {
        _addSFlrCustomFeed();
        _addFeeds();
        _mockGetContractAddressByName("FeeCalculator", address(feeCalculator));
        bytes21[] memory fuFeedIds = new bytes21[](2);
        bytes21[] memory referenceFeedIds = new bytes21[](1);
        fuFeedIds[0] = flrFeedId;
        fuFeedIds[1] = bytes21("SGB");
        referenceFeedIds[0] = flrFeedId;
        bytes21[] memory feedIds = new bytes21[](3);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("SGB");
        feedIds[2] = sflrFeedId;
        assertEq(ftsoV2.calculateFeeByIds(feedIds), 12 + 12 + 9);
    }

    function testCalculateFeeByIdsRevert() public {
        _addFeeds();
        bytes21[] memory feedIds = new bytes21[](3);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("SGB");
        feedIds[2] = sflrFeedId;
        vm.expectRevert("custom feed id not supported");
        ftsoV2.calculateFeeByIds(feedIds);
    }

    function testCalculateFeeByIdsRevertInvalidId() public {
        _addSFlrCustomFeed();
        _addFeeds();
        _mockGetContractAddressByName("FeeCalculator", address(feeCalculator));
        bytes21[] memory feedIds = new bytes21[](3);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("wrong feed");
        feedIds[2] = sflrFeedId;
        vm.expectRevert("feed does not exist");
        ftsoV2.calculateFeeByIds(feedIds);
    }

    function testCalculateFeeByIndex() public {
        _addFeeds();
        assertEq(ftsoV2.calculateFeeByIndex(0), 12);
    }

    function testCalculateFeeByIndices() public {
        _addFeeds();
        uint256[] memory indices = new uint256[](3);
        indices[0] = 0;
        indices[1] = 1;
        indices[2] = 2;
        assertEq(ftsoV2.calculateFeeByIndices(indices), 12 + 9 + 8);
    }

    function testGetFtsoProtocolId() public {
        assertEq(ftsoV2.getFtsoProtocolId(), 100);
    }

    function testChangeFeedId() public {
        _addFeeds();
        FtsoV2Interface.FeedIdChange[] memory feedIdChanges = new FtsoV2Interface.FeedIdChange[](1);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldSGB"), bytes21("SGB"));
        vm.prank(governance);
        vm.expectEmit();
        emit FeedIdChanged(feedIdChanges[0].oldFeedId, feedIdChanges[0].newFeedId);
        ftsoV2.changeFeedIds(feedIdChanges);

        // calculate fee
        assertEq(ftsoV2.calculateFeeById(bytes21("oldSGB")), 9);

        // get feed
        (uint256 value, int8 decimals, ) = ftsoV2.getFeedById{value: 9} (bytes21("oldSGB"));
        assertEq(value, 1234567);
        assertEq(decimals, 6);

        assertEq(ftsoV2.getFeedIdChanges().length, 1);
        assertEq(ftsoV2.getFeedIdChanges()[0].oldFeedId, bytes21("oldSGB"));
        assertEq(ftsoV2.getFeedIdChanges()[0].newFeedId, bytes21("SGB"));
    }

    function testGetFeedIdChanges() public {
        _addFeeds();
        assertEq(ftsoV2.getFeedIdChanges().length, 0);
        FtsoV2Interface.FeedIdChange[] memory feedIdChanges = new FtsoV2Interface.FeedIdChange[](2);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldSGB"), bytes21("SGB"));
        feedIdChanges[1] = FtsoV2Interface.FeedIdChange(bytes21("oldBTC"), bytes21("BTC"));
        vm.prank(governance);
        vm.expectEmit();
        emit FeedIdChanged(feedIdChanges[0].oldFeedId, feedIdChanges[0].newFeedId);
        vm.expectEmit();
        emit FeedIdChanged(feedIdChanges[1].oldFeedId, feedIdChanges[1].newFeedId);
        ftsoV2.changeFeedIds(feedIdChanges);
        assertEq(ftsoV2.getFeedIdChanges().length, 2);
        assertEq(ftsoV2.getFeedIdChanges()[0].oldFeedId, bytes21("oldSGB"));
        assertEq(ftsoV2.getFeedIdChanges()[0].newFeedId, bytes21("SGB"));
        assertEq(ftsoV2.getFeedIdChanges()[1].oldFeedId, bytes21("oldBTC"));
        assertEq(ftsoV2.getFeedIdChanges()[1].newFeedId, bytes21("BTC"));
    }

    function testRemoveFeedIdsChange() public {
        _addFeeds();
        FtsoV2Interface.FeedIdChange[] memory feedIdChanges = new FtsoV2Interface.FeedIdChange[](3);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldSGB"), bytes21("SGB"));
        feedIdChanges[1] = FtsoV2Interface.FeedIdChange(bytes21("oldBTC"), bytes21("BTC"));
        feedIdChanges[2] = FtsoV2Interface.FeedIdChange(bytes21("oldETH"), bytes21("ETH"));
        vm.prank(governance);
        ftsoV2.changeFeedIds(feedIdChanges);
        assertEq(ftsoV2.getFeedIdChanges().length, 3);
        assertEq(ftsoV2.getFeedIdChanges()[0].oldFeedId, bytes21("oldSGB"));
        assertEq(ftsoV2.getFeedIdChanges()[0].newFeedId, bytes21("SGB"));
        assertEq(ftsoV2.getFeedIdChanges()[1].oldFeedId, bytes21("oldBTC"));
        assertEq(ftsoV2.getFeedIdChanges()[1].newFeedId, bytes21("BTC"));
        assertEq(ftsoV2.getFeedIdChanges()[2].oldFeedId, bytes21("oldETH"));
        assertEq(ftsoV2.getFeedIdChanges()[2].newFeedId, bytes21("ETH"));

        // remove oldSGB change
        feedIdChanges = new FtsoV2Interface.FeedIdChange[](1);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldSGB"), bytes21(0));
        vm.prank(governance);
        vm.expectEmit();
        emit FeedIdChanged(feedIdChanges[0].oldFeedId, feedIdChanges[0].newFeedId);
        ftsoV2.changeFeedIds(feedIdChanges);
        assertEq(ftsoV2.getFeedIdChanges().length, 2);
        assertEq(ftsoV2.getFeedIdChanges()[0].oldFeedId, bytes21("oldETH"));
        assertEq(ftsoV2.getFeedIdChanges()[0].newFeedId, bytes21("ETH"));
        assertEq(ftsoV2.getFeedIdChanges()[1].oldFeedId, bytes21("oldBTC"));
        assertEq(ftsoV2.getFeedIdChanges()[1].newFeedId, bytes21("BTC"));
    }

    function testRemoveFeedIdsChange1() public {
        testChangeFeedId();
        assertEq(ftsoV2.getFeedIdChanges().length, 1);
        FtsoV2Interface.FeedIdChange[] memory feedIdChanges = new FtsoV2Interface.FeedIdChange[](1);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldSGB"), bytes21(0));
        vm.prank(governance);
        ftsoV2.changeFeedIds(feedIdChanges);
        assertEq(ftsoV2.getFeedIdChanges().length, 0);
    }

    function testRemoveFeedIdsChangeRevert() public {
        FtsoV2Interface.FeedIdChange[] memory feedIdChanges = new FtsoV2Interface.FeedIdChange[](1);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldSGB"), bytes21(0));
        vm.prank(governance);
        vm.expectRevert("feed id change does not exist");
        ftsoV2.changeFeedIds(feedIdChanges);
    }

    function testChangeFeedIdsRevertFeedDoesNotExist() public {
        FtsoV2Interface.FeedIdChange[] memory feedIdChanges = new FtsoV2Interface.FeedIdChange[](1);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldFLR"), flrFeedId);
        vm.prank(governance);
        vm.expectRevert("feed does not exist");
        ftsoV2.changeFeedIds(feedIdChanges);
    }

    function testChangeFeedIdsRevertCustomFeedIdNotSupported() public {
        FtsoV2Interface.FeedIdChange[] memory feedIdChanges = new FtsoV2Interface.FeedIdChange[](1);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldSFLR"), sflrFeedId);
        vm.prank(governance);
        vm.expectRevert("custom feed id not supported");
        ftsoV2.changeFeedIds(feedIdChanges);
    }

    function testChangeFeedIdsRevertSameIds() public {
        FtsoV2Interface.FeedIdChange[] memory feedIdChanges = new FtsoV2Interface.FeedIdChange[](1);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldSGB"), bytes21("oldSGB"));
        vm.prank(governance);
        vm.expectRevert("feed ids are the same");
        ftsoV2.changeFeedIds(feedIdChanges);
    }

    function testUpdateFeedIdsChange() public {
        testChangeFeedId();
        assertEq(ftsoV2.getFeedIdChanges().length, 1);
        assertEq(ftsoV2.getFeedIdChanges()[0].oldFeedId, bytes21("oldSGB"));
        assertEq(ftsoV2.getFeedIdChanges()[0].newFeedId, bytes21("SGB"));

        _addNewSGBFeedToFastUpdates();

        // update feed id change
        FtsoV2Interface.FeedIdChange[] memory feedIdChanges = new FtsoV2Interface.FeedIdChange[](1);
        feedIdChanges[0] = FtsoV2Interface.FeedIdChange(bytes21("oldSGB"), bytes21("newSGB"));
        vm.prank(governance);
        vm.expectEmit();
        emit FeedIdChanged(feedIdChanges[0].oldFeedId, feedIdChanges[0].newFeedId);
        ftsoV2.changeFeedIds(feedIdChanges);
        assertEq(ftsoV2.getFeedIdChanges().length, 1);
        assertEq(ftsoV2.getFeedIdChanges()[0].oldFeedId, bytes21("oldSGB"));
        assertEq(ftsoV2.getFeedIdChanges()[0].newFeedId, bytes21("newSGB"));
    }

    //// Proxy upgrade
    function testUpgradeProxy() public {
        testAddCustomFeeds();
        assertEq(ftsoV2.getSupportedFeedIds().length, 1);
        assertEq(ftsoV2.implementation(), address(ftsoV2Implementation));
        // upgrade
        FtsoV2 newFtsoV2Impl = new FtsoV2();
        vm.prank(governance);
        ftsoV2.upgradeToAndCall(address(newFtsoV2Impl), bytes(""));
        // check
        assertEq(ftsoV2.implementation(), address(newFtsoV2Impl));
        assertEq(ftsoV2.governance(), governance);
        assertEq(ftsoV2.getSupportedFeedIds().length, 1);
    }

    function testUpgradeProxyRevertOnlyGovernance() public {
        FtsoV2 newFtsoV2Impl = new FtsoV2();
        vm.expectRevert("only governance");
        ftsoV2.upgradeToAndCall(address(newFtsoV2Impl), bytes(""));
    }

    // should revert if trying to initialize again
    // revert in GovernedBase.initialise
    function testUpgradeProxyAndInitializeRevert() public {
        FtsoV2 newFtsoV2Impl = new FtsoV2();
        vm.prank(governance);
        vm.expectRevert("initialised != false");
        ftsoV2.upgradeToAndCall(address(newFtsoV2Impl), abi.encodeCall(
            FtsoV2.initialize, (
                IGovernanceSettings(makeAddr("governanceSettings")),
                governance,
                addressUpdater
            )
        ));
    }

    function testUpgradeToAndCall() public {
        FtsoV2 newFtsoV2Impl = new FtsoV2();
        assertEq(ftsoV2.getSupportedFeedIds().length, 0);
        IICustomFeed[] memory customFeeds = new IICustomFeed[](1);
        customFeeds[0] = sFlrCustomFeed;
        vm.expectEmit();
        emit CustomFeedAdded(sflrFeedId, sFlrCustomFeed);
        vm.prank(governance);
        ftsoV2.upgradeToAndCall(
            address(newFtsoV2Impl),
            abi.encodeCall(FtsoV2.addCustomFeeds, (customFeeds))
        );
        assertEq(ftsoV2.getSupportedFeedIds().length, 1);
    }

    ////
    function _addFeeds() public {
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](4);

        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: flrFeedId,
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
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), flrFeedId),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: flrFeedId,
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

        // set feeds fees
        bytes21[] memory feedIds = new bytes21[](2);
        feedIds[0] = flrFeedId;
        feedIds[1] = bytes21("SGB");
        uint256[] memory fees = new uint256[](2);
        fees[0] = 12;
        fees[1] = 9;
        vm.prank(governance);
        feeCalculator.setFeedsFees(feedIds, fees);
    }

    function _addNewSGBFeedToFastUpdates() private {
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](1);
        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("newSGB"),
            rewardBandValue: 400,
            inflationShare: 250
        });

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("newSGB")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("newSGB"),
                value: 12345678,
                turnoutBIPS: 1000,
                decimals: 7
            }))
        );

        vm.prank(governance);
        fastUpdatesConfiguration.addFeeds(feedConfigs);
    }

    function _addSFlrCustomFeed() private {
        IICustomFeed[] memory customFeeds = new IICustomFeed[](1);
        customFeeds[0] = sFlrCustomFeed;
        vm.prank(governance);
        ftsoV2.addCustomFeeds(customFeeds);
    }

    function _mockGetContractAddressByName(string memory _contractName, address _contractAddr) private {
        vm.mockCall(
            mockFlareContractRegistry,
            abi.encodeWithSelector(IFlareContractRegistry.getContractAddressByName.selector, _contractName),
            abi.encode(_contractAddr)
        );
    }

    function _mockGetPooledFlrByShares(uint256 _value) private {
        vm.mockCall(
            sFlr,
            abi.encodeWithSelector(ISFlr.getPooledFlrByShares.selector, _value),
            abi.encode(_value * 2)
        );
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }
}