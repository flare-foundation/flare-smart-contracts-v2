// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol";

contract FastUpdatesConfigurationTest is Test {

    FastUpdatesConfiguration private fastUpdatesConfiguration;
    address private governance;
    address private addressUpdater;
    address private mockFastUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    event FeedAdded(bytes21 indexed feedId, uint32 rewardBandValue, uint24 inflationShare, uint256 index);
    event FeedUpdated(bytes21 indexed feedId, uint32 rewardBandValue, uint24 inflationShare, uint256 index);
    event FeedRemoved(bytes21 indexed feedId, uint256 index);


    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        fastUpdatesConfiguration = new FastUpdatesConfiguration(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );
        vm.prank(addressUpdater);
        mockFastUpdater = makeAddr("mockFastUpdater");
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FastUpdater"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFastUpdater;
        fastUpdatesConfiguration.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.startPrank(governance);

        vm.mockCall(
            mockFastUpdater,
            abi.encodeWithSelector(IIFastUpdater.resetFeeds.selector),
            abi.encode()
        );

        vm.mockCall(
            mockFastUpdater,
            abi.encodeWithSelector(IIFastUpdater.removeFeeds.selector),
            abi.encode()
        );
    }

    function testAddFeeds() public {
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

        vm.expectEmit();
        emit FeedAdded(bytes21("feed1"), 100, 150, 0);
        vm.expectEmit();
        emit FeedAdded(bytes21("feed2"), 200, 250, 1);
        vm.expectEmit();
        emit FeedAdded(bytes21("feed3"), 300, 350, 2);
        fastUpdatesConfiguration.addFeeds(feedConfigs);
    }

    function testAddFeedsRevertInvalidFeedId() public {
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](1);

        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21(0),
            rewardBandValue: 100,
            inflationShare: 150
        });

        vm.expectRevert("invalid feed id");
        fastUpdatesConfiguration.addFeeds(feedConfigs);
    }

    function testAddFeedsRevertFeedAlreadyExists() public {
        testAddFeeds();
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](1);

        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed1"),
            rewardBandValue: 100,
            inflationShare: 150
        });

        vm.expectRevert("feed already exists");
        fastUpdatesConfiguration.addFeeds(feedConfigs);
    }

    function testUpdateFeeds() public {
        testAddFeeds();

        (bytes memory names, bytes memory bandValues, bytes memory inflationShares) =
            fastUpdatesConfiguration.getFeedConfigurationsBytes();
        assertEq(names.length, 21 * 3);
        assertEq(bandValues.length, 4 * 3);
        assertEq(inflationShares.length, 3 * 3);
        assertEq(bandValues[3], bytes1(uint8(100)));
        assertEq(bandValues[7], bytes1(uint8(200)));

        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            fastUpdatesConfiguration.getFeedConfigurations();
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

        feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](2);

        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed1"),
            rewardBandValue: 110,
            inflationShare: 550
        });

        feedConfigs[1] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed2"),
            rewardBandValue: 210,
            inflationShare: 650
        });

        vm.expectEmit();
        emit FeedUpdated(bytes21("feed1"), 110, 550, 0);
        vm.expectEmit();
        emit FeedUpdated(bytes21("feed2"), 210, 650, 1);
        fastUpdatesConfiguration.updateFeeds(feedConfigs);

        (names, bandValues, inflationShares) =
            fastUpdatesConfiguration.getFeedConfigurationsBytes();
        assertEq(names.length, 21 * 3);
        assertEq(bandValues.length, 4 * 3);
        assertEq(inflationShares.length, 3 * 3);
        assertEq(bandValues[3], bytes1(uint8(110)));
        assertEq(bandValues[7], bytes1(uint8(210)));

        feedConfigs = fastUpdatesConfiguration.getFeedConfigurations();
        assertEq(feedConfigs.length, 3);
        assertEq(feedConfigs[0].feedId, bytes21("feed1"));
        assertEq(feedConfigs[1].feedId, bytes21("feed2"));
        assertEq(feedConfigs[2].feedId, bytes21("feed3"));
        assertEq(feedConfigs[0].rewardBandValue, 110);
        assertEq(feedConfigs[1].rewardBandValue, 210);
        assertEq(feedConfigs[2].rewardBandValue, 300);
        assertEq(feedConfigs[0].inflationShare, 550);
        assertEq(feedConfigs[1].inflationShare, 650);
        assertEq(feedConfigs[2].inflationShare, 350);
    }

    function testUpdateFeedsRevertFeedDoesNotExist() public {
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](1);

        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed11"),
            rewardBandValue: 110,
            inflationShare: 550
        });

        vm.expectRevert("feed does not exist");
        fastUpdatesConfiguration.updateFeeds(feedConfigs);
    }

    function testUpdateFeedsRevertInvalidFeedId() public {
        testAddFeeds();
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](1);

        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21(0),
            rewardBandValue: 110,
            inflationShare: 550
        });

        vm.expectRevert("invalid feed id");
        fastUpdatesConfiguration.updateFeeds(feedConfigs);
    }

    function testRemoveFeeds() public {
        bytes21[] memory feedIds = fastUpdatesConfiguration.getFeedIds();
        assertEq(feedIds.length, 0);

        testAddFeeds();

        feedIds = fastUpdatesConfiguration.getFeedIds();
        assertEq(feedIds.length, 3);
        assertEq(feedIds[0], bytes21("feed1"));
        assertEq(feedIds[1], bytes21("feed2"));
        assertEq(feedIds[2], bytes21("feed3"));

        assertEq(fastUpdatesConfiguration.getNumberOfFeeds(), 3);
        uint256[] memory unused = fastUpdatesConfiguration.getUnusedIndices();
        assertEq(unused.length, 0);

        bytes21[] memory feedIdsToRemove = new bytes21[](1);
        feedIdsToRemove[0] = bytes21("feed2");
        vm.expectEmit();
        emit FeedRemoved(bytes21("feed2"), 1);
        fastUpdatesConfiguration.removeFeeds(feedIdsToRemove);

        feedIds = fastUpdatesConfiguration.getFeedIds();
        assertEq(feedIds.length, 3);
        assertEq(feedIds[0], bytes21("feed1"));
        assertEq(feedIds[1], bytes21(0));
        assertEq(feedIds[2], bytes21("feed3"));

        assertEq(fastUpdatesConfiguration.getNumberOfFeeds(), 3); // 2 used and 1 unused
        unused = fastUpdatesConfiguration.getUnusedIndices();
        assertEq(unused.length, 1);
        assertEq(unused[0], 1);

        // add new feed; it should use the unused index (1) and not new one (3)
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](1);
        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed9"),
            rewardBandValue: 9,
            inflationShare: 19
        });
        vm.expectEmit();
        emit FeedAdded(bytes21("feed9"), 9, 19, 1);
        fastUpdatesConfiguration.addFeeds(feedConfigs);

        unused = fastUpdatesConfiguration.getUnusedIndices();
        assertEq(unused.length, 0);

        feedIds = fastUpdatesConfiguration.getFeedIds();
        assertEq(feedIds.length, 3);
        assertEq(feedIds[0], bytes21("feed1"));
        assertEq(feedIds[1], bytes21("feed9"));
        assertEq(feedIds[2], bytes21("feed3"));

        // remove last feed
        feedIdsToRemove = new bytes21[](1);
        feedIdsToRemove[0] = bytes21("feed3");
        vm.expectEmit();
        emit FeedRemoved(bytes21("feed3"), 2);
        fastUpdatesConfiguration.removeFeeds(feedIdsToRemove);

        assertEq(fastUpdatesConfiguration.getNumberOfFeeds(), 3); // 2 used and 1 unused
        unused = fastUpdatesConfiguration.getUnusedIndices();
        assertEq(unused.length, 1);

        feedIds = fastUpdatesConfiguration.getFeedIds();
        assertEq(feedIds.length, 3);
        assertEq(feedIds[0], bytes21("feed1"));
        assertEq(feedIds[1], bytes21("feed9"));
        assertEq(feedIds[2], bytes21(0));
    }

    function testRemoveFeedsRevertFeedDoesNotExist() public {
        testAddFeeds();
        bytes21[] memory feedIds = new bytes21[](1);
        feedIds[0] = bytes21("feed11");
        vm.expectRevert("feed does not exist");
        fastUpdatesConfiguration.removeFeeds(feedIds);
    }

    function testGetFeedIndexAndName() public {
        testAddFeeds();
        assertEq(fastUpdatesConfiguration.getFeedIndex(bytes21("feed1")), 0);
        assertEq(fastUpdatesConfiguration.getFeedIndex(bytes21("feed2")), 1);
        assertEq(fastUpdatesConfiguration.getFeedIndex(bytes21("feed3")), 2);
        vm.expectRevert("feed does not exist");
        fastUpdatesConfiguration.getFeedIndex(bytes21("feed4"));

        assertEq(fastUpdatesConfiguration.getFeedId(0), bytes21("feed1"));
        assertEq(fastUpdatesConfiguration.getFeedId(1), bytes21("feed2"));
        assertEq(fastUpdatesConfiguration.getFeedId(2), bytes21("feed3"));
        vm.expectRevert("invalid index");
        fastUpdatesConfiguration.getFeedId(3);
    }

}