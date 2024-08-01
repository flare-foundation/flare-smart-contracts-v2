// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/FtsoV2.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdater.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol";
import "../../../../contracts/ftso/implementation/FtsoRewardOffersManager.sol";
import "../../../../contracts/protocol/implementation/RewardManager.sol";

contract FtsoV2Test is Test {

    FtsoV2 private ftsoV2;
    FastUpdater private fastUpdater;
    FastUpdatesConfiguration private fastUpdatesConfiguration;
    FtsoRewardOffersManager private ftsoRewardOffersManager;

    address private governance;
    address private addressUpdater;
    address private flareDaemon;
    address private mockFlareSystemsManager;
    address private mockInflation;
    address private mockRewardManager;
    address private mockFastUpdater;
    address private mockFastUpdatesConfiguration;
    address private mockFtsoInflationConfigurations;
    address private mockFtsoFeedDecimals;
    address private mockFtsoFeedPublisher;
    address private mockFastUpdateIncentiveManager;

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

    event RewardsOffered(
        uint24 indexed rewardEpochId,
        bytes21 feedId,
        int8 decimals,
        uint256 amount,
        uint16 minRewardedTurnoutBIPS,
        uint24 primaryBandRewardSharePPM,
        uint24 secondaryBandWidthPPM,
        address claimBackAddress
    );

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

        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockInflation = makeAddr("mockInflation");
        mockRewardManager = makeAddr("mockRewardManager");
        mockFastUpdater = makeAddr("mockFastUpdater");
        mockFastUpdatesConfiguration = makeAddr("mockFastUpdatesConfiguration");
        mockFtsoInflationConfigurations = makeAddr("mockFtsoInflationConfigurations");
        mockFtsoFeedDecimals = makeAddr("mockFtsoFeedDecimals");
        mockFtsoFeedPublisher = makeAddr("ftsoFeedPublisher");
        mockFastUpdateIncentiveManager = makeAddr("mockFastUpdateIncentiveManager");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FastUpdater"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(fastUpdater);
        fastUpdatesConfiguration.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("FastUpdateIncentiveManager"));
        contractNameHashes[3] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[4] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractNameHashes[5] = keccak256(abi.encode("FtsoFeedPublisher"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        contractAddresses[2] = mockFastUpdateIncentiveManager;
        contractAddresses[3] = makeAddr("voterRegistry");
        contractAddresses[4] = address(fastUpdatesConfiguration);
        contractAddresses[5] = mockFtsoFeedPublisher;
        fastUpdater.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("FastUpdateIncentiveManager"));
        contractAddresses[0] = mockFastUpdateIncentiveManager;
        contractNameHashes[1] = keccak256(abi.encode("FastUpdater"));
        contractAddresses[1] = address(fastUpdater);
        contractNameHashes[2] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractAddresses[2] = address(fastUpdatesConfiguration);
        contractNameHashes[3] = keccak256(abi.encode("FtsoRewardOffersManager"));
        contractAddresses[3] = address(ftsoRewardOffersManager);
        contractNameHashes[4] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[4] = addressUpdater;
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
        assertEq(ftsoV2.getFeedId(0), bytes21("feed1"));
        assertEq(ftsoV2.getFeedId(1), bytes21("feed2"));
        assertEq(ftsoV2.getFeedId(2), bytes21("feed3"));
    }

    function testGetFeedIndex() public {
        _addFeeds();
        assertEq(ftsoV2.getFeedIndex(bytes21("feed1")), 0);
        assertEq(ftsoV2.getFeedIndex(bytes21("feed2")), 1);
        assertEq(ftsoV2.getFeedIndex(bytes21("feed3")), 2);
    }


    ////
    function _mockGetCurrentEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IRewardManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _mockGetDecimals(bytes21 _feedId, int8 _decimals) internal {
        vm.mockCall(
            mockFtsoFeedDecimals,
            abi.encodeWithSelector(IFtsoFeedDecimals.getDecimals.selector, _feedId),
            abi.encode(_decimals)
        );
    }

    function _addFeeds() public {
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](3);

        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed1"),
            rewardBandValue: 100,
            inflationShare: 150
        });

        feedConfigs[1] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed2"),
            rewardBandValue: 200,
            inflationShare: 250
        });

        feedConfigs[2] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed3"),
            rewardBandValue: 300,
            inflationShare: 350
        });

        vm.mockCall(
            mockFastUpdater,
            abi.encodeWithSelector(IIFastUpdater.resetFeeds.selector),
            abi.encode()
        );

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("feed1")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("feed1"),
                value: 100,
                turnoutBIPS: 1000,
                decimals: 4
            }))
        );

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("feed2")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("feed2"),
                value: 200,
                turnoutBIPS: 1000,
                decimals: 1
            }))
        );

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("feed3")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("feed3"),
                value: 300,
                turnoutBIPS: 1000,
                decimals: -6
            }))
        );

        vm.prank(governance);
        fastUpdatesConfiguration.addFeeds(feedConfigs);
    }


}