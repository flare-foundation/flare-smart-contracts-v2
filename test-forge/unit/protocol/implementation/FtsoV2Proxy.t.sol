// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/FtsoV2Proxy.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdater.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdateIncentiveManager.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol";
import "../../../../contracts/ftso/implementation/FtsoRewardOffersManager.sol";
import "../../../../contracts/protocol/implementation/RewardManager.sol";

contract FtsoV2ProxyTest is Test {

    FtsoV2Proxy private ftsoV2Proxy;
    FastUpdateIncentiveManager private fastUpdateIncentiveManager;
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
    RewardManager private rewardManager;

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

        ftsoV2Proxy = new FtsoV2Proxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

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

        ftsoRewardOffersManager = new FtsoRewardOffersManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            100
        );

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0),
            0
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
        contractAddresses[0] = addressUpdater;
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[1] = mockFlareSystemsManager;
        contractNameHashes[2] = keccak256(abi.encode("Inflation"));
        contractAddresses[2] = mockInflation;
        contractNameHashes[3] = keccak256(abi.encode("RewardManager"));
        contractAddresses[3] = mockRewardManager;
        contractNameHashes[4] = keccak256(abi.encode("FastUpdater"));
        contractAddresses[4] = mockFastUpdater;
        contractNameHashes[5] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractAddresses[5] = mockFastUpdatesConfiguration;
        fastUpdateIncentiveManager.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FtsoInflationConfigurations"));
        contractNameHashes[3] = keccak256(abi.encode("FtsoFeedDecimals"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[5] = keccak256(abi.encode("Inflation"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(rewardManager);
        contractAddresses[2] = mockFtsoInflationConfigurations;
        contractAddresses[3] = mockFtsoFeedDecimals;
        contractAddresses[4] = mockFlareSystemsManager;
        contractAddresses[5] = mockInflation;
        ftsoRewardOffersManager.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](8);
        contractAddresses = new address[](8);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[3] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsCalculator"));
        contractNameHashes[5] = keccak256(abi.encode("PChainStakeMirror"));
        contractNameHashes[6] = keccak256(abi.encode("WNat"));
        contractNameHashes[7] = keccak256(abi.encode("FtsoRewardManagerProxy"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("voterRegistry");
        contractAddresses[2] = makeAddr("claimSetupManager");
        contractAddresses[3] = mockFlareSystemsManager;
        contractAddresses[4] = makeAddr("flareSystemsCalculator");
        contractAddresses[5] = makeAddr("pChainStakeMirror");
        contractAddresses[6] = makeAddr("wNat");
        contractAddresses[7] = makeAddr("FtsoRewardManagerProxy");
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);

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
        contractAddresses[2] = address(fastUpdateIncentiveManager);
        contractAddresses[3] = makeAddr("voterRegistry");
        contractAddresses[4] = address(fastUpdatesConfiguration);
        contractAddresses[5] = mockFtsoFeedPublisher;
        fastUpdater.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("FastUpdateIncentiveManager"));
        contractAddresses[0] = address(fastUpdateIncentiveManager);
        contractNameHashes[1] = keccak256(abi.encode("FastUpdater"));
        contractAddresses[1] = address(fastUpdater);
        contractNameHashes[2] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractAddresses[2] = address(fastUpdatesConfiguration);
        contractNameHashes[3] = keccak256(abi.encode("FtsoRewardOffersManager"));
        contractAddresses[3] = address(ftsoRewardOffersManager);
        contractNameHashes[4] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[4] = addressUpdater;
        ftsoV2Proxy.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.stopPrank();

        voter = makeAddr("voter");
        vm.deal(voter, 1000 ether);
    }


    //// IFastUpdateIncentiveManager
    function testOfferIncentive1() public {
        _mockGetCurrentEpochId(1);
        FPA.Range rangeIncrease = FPA.Range.wrap(RANGE);
        FPA.Range rangeLimit = FPA.Range.wrap(RANGE * 2);
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: rangeIncrease,
            rangeLimit: rangeLimit
        });

        uint256 value = 122070312500000000000; // RANGE_INCREASE_PRICE / (1 / RANGE)
        uint256 balanceBefore = voter.balance;
        vm.prank(voter);
        ftsoV2Proxy.offerIncentive{value: value}(offer);
        assertEq(voter.balance, balanceBefore - value, "balance mismatch");
    }

    // range + rangeIncrease > rangeLimit => sender should be partially refunded
    function testOfferIncentive2() public {
        _mockGetCurrentEpochId(1);
        FPA.Range rangeIncrease = FPA.Range.wrap(3 * RANGE);
        FPA.Range rangeLimit = FPA.Range.wrap(RANGE * 2);
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: rangeIncrease,
            rangeLimit: rangeLimit
        });

        uint256 value = 500 ether;
        vm.prank(voter);
        uint256 balanceBefore = voter.balance;
        ftsoV2Proxy.offerIncentive{value: value}(offer);
        assertGt(voter.balance, balanceBefore - value);
    }

    function testOfferIncentiveRevert() public {
         vm.mockCallRevert(
            voter,
            abi.encode(),
            abi.encode()
        );

        _mockGetCurrentEpochId(1);
        FPA.Range rangeIncrease = FPA.Range.wrap(3 * RANGE);
        FPA.Range rangeLimit = FPA.Range.wrap(RANGE * 2);
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: rangeIncrease,
            rangeLimit: rangeLimit
        });
        vm.prank(voter);
        vm.expectRevert("transfer failed");
        ftsoV2Proxy.offerIncentive{value: 500 ether}(offer);
    }

    function testSampleIncreaseLimit() public {
        vm.expectRevert("not supported, use FastUpdateIncentiveManager");
        ftsoV2Proxy.sampleIncreaseLimit();
    }

    function testGetIncentiveDuration() public {
        vm.expectRevert("not supported, use FastUpdateIncentiveManager");
        ftsoV2Proxy.getIncentiveDuration();
    }

    function testGetExpectedSampleSize() public view {
        assertEq(FPA.SampleSize.unwrap(ftsoV2Proxy.getExpectedSampleSize()), SAMPLE_SIZE);
    }

    function testGetPrecision() public view {
        assertEq(FPA.Precision.unwrap(ftsoV2Proxy.getPrecision()), (RANGE << 127) / SAMPLE_SIZE);
    }

    function testGetRange() public view {
        assertEq(FPA.Range.unwrap(ftsoV2Proxy.getRange()), RANGE);
    }

    function testGetCurrentSampleSizeIncreasePrice() public view {
        assertEq(FPA.Fee.unwrap(ftsoV2Proxy.getCurrentSampleSizeIncreasePrice()), SAMPLE_SIZE_INCREASE_PRICE);
    }

    function testGetScale() public view {
        assertEq(FPA.Scale.unwrap(ftsoV2Proxy.getScale()), (1 << 127) + (RANGE << 127) / SAMPLE_SIZE);
    }

    function testGetBaseScale() public view {
        assertEq(FPA.Scale.unwrap(ftsoV2Proxy.getBaseScale()), (1 << 127) + (RANGE << 127) / SAMPLE_SIZE);
    }

    function testRangeIncreaseLimit() public view {
        assertEq(FPA.Range.unwrap(ftsoV2Proxy.rangeIncreaseLimit()), RANGE_INCREASE_LIMIT);
    }

    function testRangeIncreasePrice() public view {
        assertEq(FPA.Fee.unwrap(ftsoV2Proxy.rangeIncreasePrice()), RANGE_INCREASE_PRICE);
    }

    //// IFastUpdater
    // function testFetchCurrentFeeds() public {
    //     _addFeeds();
    //     uint256[] memory indices = new uint256[](2);
    //     indices[0] = 0;
    //     indices[1] = 1;
    //     (uint256[] memory feeds, int8[] memory decimals, uint64 timestamp) = ftsoV2Proxy.fetchCurrentFeeds(indices);
    //     assertEq(feeds.length, 2);
    //     assertEq(feeds[0], 100 * 10 ** (4 - 1));
    //     assertEq(feeds[1], 200 * 10 ** (5 - 1));
    //     assertEq(decimals.length, 2);
    //     assertEq(decimals[0], 4);
    //     assertEq(decimals[1], 5);
    //     assertEq(timestamp, 0);

    //     indices = new uint256[](1);
    //     indices[0] = 2;
    //     (feeds, decimals, timestamp) = ftsoV2Proxy.fetchCurrentFeeds(indices);
    // }

    //// IFtsoRewardOffersManager
    function testOfferRewards() public {
        // set reward offers manager list on reward manager
        address[] memory rewardOffersManagers = new address[](1);
        rewardOffersManagers[0] = address(ftsoRewardOffersManager);
        vm.prank(governance);
        rewardManager.setRewardOffersManagerList(rewardOffersManagers);

        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpochId.selector),
            abi.encode(2)
        );
        vm.warp(100);
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(bytes4(keccak256("currentRewardEpochExpectedEndTs()"))),
            abi.encode(110)
        );
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(bytes4(keccak256("newSigningPolicyInitializationStartSeconds()"))),
            abi.encode(5)
        );

        address claimBackAddr = makeAddr("claimBackAddr");
        bytes21 feedId1 = bytes21("feed1");
        bytes21 feedId2 = bytes21("feed2");

        IFtsoRewardOffersManager.Offer[] memory offers;
        offers = new IFtsoRewardOffersManager.Offer[](2);
        offers[0] = IFtsoRewardOffersManager.Offer(
            uint120(1000),
            feedId1,
            5000,
            10000,
            20000,
            claimBackAddr
        );
        offers[1] = IFtsoRewardOffersManager.Offer(
            uint120(2000),
            feedId2,
            6000,
            40000,
            50000,
            address(0)
        );

        _mockGetDecimals(feedId1, 4);
        _mockGetDecimals(feedId2, -5);

        vm.expectEmit();
        emit RewardsOffered(
            2 + 1,
            offers[0].feedId,
            int8(4),
            offers[0].amount,
            offers[0].minRewardedTurnoutBIPS,
            offers[0].primaryBandRewardSharePPM,
            offers[0].secondaryBandWidthPPM,
            claimBackAddr
        );
        vm.expectEmit();
        // claim back address should be msg.sender (=voter)
        emit RewardsOffered(
            2 + 1,
            offers[1].feedId,
            int8(-5),
            offers[1].amount,
            offers[1].minRewardedTurnoutBIPS,
            offers[1].primaryBandRewardSharePPM,
            offers[1].secondaryBandWidthPPM,
            voter
        );

        vm.prank(voter);
        assertEq(address(rewardManager).balance, 0);
        ftsoV2Proxy.offerRewards{value: 3000} (3, offers);
        assertEq(address(rewardManager).balance, 3000);
    }

    function testMinimalRewardsOfferValue() public {
        assertEq(ftsoV2Proxy.minimalRewardsOfferValueWei(), 100);
        vm.prank(governance);
        ftsoRewardOffersManager.setMinimalRewardsOfferValue(1000);
        assertEq(ftsoV2Proxy.minimalRewardsOfferValueWei(), 1000);
    }

    //// IFastUpdatesConfiguration
    function testGetFeedConfigurations() public {
        _addFeeds();
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            ftsoV2Proxy.getFeedConfigurations();
        assertEq(feedConfigs.length, 3);
        assertEq(feedConfigs[0].feedId, bytes21("feed1"));
        assertEq(feedConfigs[1].feedId, bytes21("feed2"));
        assertEq(feedConfigs[2].feedId, bytes21("feed3"));
        assertEq(feedConfigs[0].rewardBandValue, 100);
        assertEq(feedConfigs[1].rewardBandValue, 200);
        assertEq(feedConfigs[2].rewardBandValue, 300);
        assertEq(feedConfigs[0].inflationShare, 150);
        assertEq(feedConfigs[1].inflationShare, 250);
        assertEq(feedConfigs[2].inflationShare, 350);
    }

    function testGetFeedId() public {
        _addFeeds();
        assertEq(ftsoV2Proxy.getFeedId(0), bytes21("feed1"));
        assertEq(ftsoV2Proxy.getFeedId(1), bytes21("feed2"));
        assertEq(ftsoV2Proxy.getFeedId(2), bytes21("feed3"));
    }

    function testGetFeedIndex() public {
        _addFeeds();
        assertEq(ftsoV2Proxy.getFeedIndex(bytes21("feed1")), 0);
        assertEq(ftsoV2Proxy.getFeedIndex(bytes21("feed2")), 1);
        assertEq(ftsoV2Proxy.getFeedIndex(bytes21("feed3")), 2);
    }

    function testGetNumberOfFeeds() public {
        _addFeeds();
        assertEq(ftsoV2Proxy.getNumberOfFeeds(), 3);
    }

    function testGetUnusedIndices() public {
        _addFeeds();
        uint256[] memory unused = ftsoV2Proxy.getUnusedIndices();
        assertEq(unused.length, 0);

        vm.mockCall(
            mockFastUpdater,
            abi.encodeWithSelector(IIFastUpdater.removeFeeds.selector),
            abi.encode()
        );
        bytes21[] memory feedIdsToRemove = new bytes21[](1);
        feedIdsToRemove[0] = bytes21("feed2");
        vm.prank(governance);
        fastUpdatesConfiguration.removeFeeds(feedIdsToRemove);

        bytes21[] memory feedIds = fastUpdatesConfiguration.getFeedIds();
        assertEq(feedIds.length, 3);
        assertEq(feedIds[0], bytes21("feed1"));
        assertEq(feedIds[1], bytes21(0));
        assertEq(feedIds[2], bytes21("feed3"));

        assertEq(fastUpdatesConfiguration.getNumberOfFeeds(), 3); // 2 used and 1 unused
        unused = fastUpdatesConfiguration.getUnusedIndices();
        assertEq(unused.length, 1);
        assertEq(unused[0], 1);
    }

    function testGetFeedIds() public {
        vm.expectRevert("not supported, use FastUpdatesConfiguration");
        ftsoV2Proxy.getFeedIds();
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