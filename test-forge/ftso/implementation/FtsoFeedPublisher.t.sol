// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/ftso/implementation/FtsoFeedPublisher.sol";

contract FtsoFeedPublisherTest is Test {

    FtsoFeedPublisher private ftsoFeedPublisher;
    address private addressUpdater;
    address private mockRelay;
    address private governance;
    Relay private relay;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;
    uint8 private ftsoProtocolId;
    bytes8 private feedName1;
    bytes8 private feedName2;
    address private feedsPublisher;

    event FtsoFeedPublished(IFtsoFeedPublisher.Feed feed);

    function setUp() public {
        addressUpdater = makeAddr("addressUpdater");
        governance = makeAddr("governance");
        ftsoProtocolId = 1;
        ftsoFeedPublisher = new FtsoFeedPublisher(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            ftsoProtocolId,
            10
        );

        vm.prank(addressUpdater);
        mockRelay = makeAddr("mockRelay");
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("Relay"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockRelay;
        ftsoFeedPublisher.updateContractAddresses(contractNameHashes, contractAddresses);

        feedName1 = bytes8("feed1");
        feedName2 = bytes8("feed2");

        feedsPublisher = makeAddr("feedsPublisher");
    }


    function testConstructorRevertInvalidProtocolId() public {
        vm.expectRevert("invalid ftso protocol id");
        new FtsoFeedPublisher(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            0,
            2
        );
    }

    function testConstructorRevertInvalidHistorySize() public {
        vm.expectRevert("history size zero");
        new FtsoFeedPublisher(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            1,
            0
        );
    }

    function testPublish() public {
        uint32 roundId = 2;
        _mockGetVotingRoundId(block.timestamp, 4);
        IFtsoFeedPublisher.FeedWithProof[] memory proofs = new IFtsoFeedPublisher.FeedWithProof[](2);
        bytes32[] memory merkleProof1 = new bytes32[](1);
        bytes32[] memory merkleProof2 = new bytes32[](1);

        IFtsoFeedPublisher.Feed memory body1 = IFtsoFeedPublisher.Feed(
            roundId, feedName1, int32(100), uint16(1000), int8(2));
        IFtsoFeedPublisher.Feed memory body2 = IFtsoFeedPublisher.Feed(
            roundId, feedName2, int32(200), uint16(2000), int8(3));
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 leaf2 = keccak256(abi.encode(body2));
        bytes32 merkleRoot = _hashPair(leaf1, leaf2);

        merkleProof1[0] = leaf2;
        proofs[0] = IFtsoFeedPublisher.FeedWithProof(merkleProof1, body1);

        merkleProof2[0] = leaf1;
        proofs[1] = IFtsoFeedPublisher.FeedWithProof(merkleProof2, body2);

        _mockGetMerkleRoot(1, roundId, merkleRoot);

        vm.expectEmit();
        emit FtsoFeedPublished(body1);
        vm.expectEmit();
        emit FtsoFeedPublished(body2);
        ftsoFeedPublisher.publish(proofs);

        IFtsoFeedPublisher.Feed memory getFeed = ftsoFeedPublisher.getCurrentFeed(feedName1);
        assertEq(getFeed.votingRoundId, roundId);
        assertEq(getFeed.name, feedName1);
        assertEq(getFeed.value, int32(100));
        assertEq(getFeed.turnoutBIPS, uint16(1000));
        assertEq(getFeed.decimals, int8(2));

        getFeed = ftsoFeedPublisher.getFeed(feedName2, 2);
        assertEq(getFeed.votingRoundId, roundId);
        assertEq(getFeed.name, feedName2);
        assertEq(getFeed.value, int32(200));
        assertEq(getFeed.turnoutBIPS, uint16(2000));
        assertEq(getFeed.decimals, int8(3));
    }

    function testGetFeedRevertTooOldVotingRound() public {
        _mockGetVotingRoundId(block.timestamp, 300);
        vm.expectRevert("too old voting round id");
        ftsoFeedPublisher.getFeed(feedName2, 2);
    }

    function testGetFeedRevertNotYetPublished() public {
        _mockGetVotingRoundId(block.timestamp, 4);
        vm.expectRevert("feed not published yet");
        ftsoFeedPublisher.getFeed(feedName2, 2);
    }

    function testPublishRevertInvalidProof() public {
        uint32 roundId = 2;
        _mockGetVotingRoundId(block.timestamp, 4);
        IFtsoFeedPublisher.FeedWithProof[] memory proofs = new IFtsoFeedPublisher.FeedWithProof[](2);
        bytes32[] memory merkleProof1 = new bytes32[](1);
        bytes32[] memory merkleProof2 = new bytes32[](1);

        IFtsoFeedPublisher.Feed memory body1 = IFtsoFeedPublisher.Feed(
            roundId, feedName1, int32(100), uint16(1000), int8(2));
        IFtsoFeedPublisher.Feed memory body2 = IFtsoFeedPublisher.Feed(
            roundId, feedName2, int32(200), uint16(2000), int8(3));
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 leaf2 = keccak256(abi.encode(body2));

        merkleProof1[0] = leaf2;
        proofs[0] = IFtsoFeedPublisher.FeedWithProof(merkleProof1, body1);

        merkleProof2[0] = leaf1;
        proofs[1] = IFtsoFeedPublisher.FeedWithProof(merkleProof2, body2);

        _mockGetMerkleRoot(1, roundId, keccak256("invalid root"));

        vm.expectRevert("merkle proof invalid");
        ftsoFeedPublisher.publish(proofs);
    }

    function testSetFeedsPublisher() public {
        assertEq(ftsoFeedPublisher.feedsPublisher(), address(0));
        vm.prank(governance);
        ftsoFeedPublisher.setFeedsPublisher(feedsPublisher);
        assertEq(ftsoFeedPublisher.feedsPublisher(), feedsPublisher);
    }

    function testPublishFeeds() public {
        IFtsoFeedPublisher.Feed memory getFeed;
        testSetFeedsPublisher();
        _mockGetVotingRoundId(block.timestamp, 4);
        uint32 roundId = 2;
        IFtsoFeedPublisher.Feed memory feed1 = IFtsoFeedPublisher.Feed(
            roundId, feedName1, int32(100), uint16(1000), int8(2));
        IFtsoFeedPublisher.Feed memory feed2 = IFtsoFeedPublisher.Feed(
            roundId, feedName2, int32(200), uint16(2000), int8(3));

        IFtsoFeedPublisher.Feed[] memory feeds = new IFtsoFeedPublisher.Feed[](2);
        feeds[0] = feed1;
        feeds[1] = feed2;

        vm.expectEmit();
        emit FtsoFeedPublished(feed1);
        vm.expectEmit();
        emit FtsoFeedPublished(feed2);
        vm.prank(feedsPublisher);
        ftsoFeedPublisher.publishFeeds(feeds);

        getFeed = ftsoFeedPublisher.getFeed(feedName1, 2);
        assertEq(getFeed.votingRoundId, roundId);
        assertEq(getFeed.name, feedName1);
        assertEq(getFeed.value, int32(100));
        assertEq(getFeed.turnoutBIPS, uint16(1000));
        assertEq(getFeed.decimals, int8(2));

        // move to voting round 15
        roundId = 12;
        IFtsoFeedPublisher.Feed memory feed = IFtsoFeedPublisher.Feed(
            roundId, feedName1, int32(8), uint16(18), int8(13));
        feeds = new IFtsoFeedPublisher.Feed[](1);
        feeds[0] = feed;
        vm.prank(feedsPublisher);
        ftsoFeedPublisher.publishFeeds(feeds);

        getFeed = ftsoFeedPublisher.getFeed(feedName1, 12);
        assertEq(getFeed.votingRoundId, roundId);
        assertEq(getFeed.name, feedName1);
        assertEq(getFeed.value, int32(8));
        assertEq(getFeed.turnoutBIPS, uint16(18));
        assertEq(getFeed.decimals, int8(13));

        // feed for voting round 2 was overwritten by feed for voting round 12 (history size is 10)
        vm.expectRevert("feed not published yet");
        getFeed = ftsoFeedPublisher.getFeed(feedName1, 2);

        // publish again feed for voting round 2
        roundId = 2;
        feed = IFtsoFeedPublisher.Feed(
            roundId, feedName1, int32(100), uint16(1000), int8(2));
        feeds = new IFtsoFeedPublisher.Feed[](1);
        feeds[0] = feed;
        vm.prank(feedsPublisher);
        ftsoFeedPublisher.publishFeeds(feeds);

        getFeed = ftsoFeedPublisher.getFeed(feedName1, 2);
        assertEq(getFeed.votingRoundId, 2);
        assertEq(getFeed.name, feedName1);
        assertEq(getFeed.value, int32(100));
        assertEq(getFeed.turnoutBIPS, uint16(1000));
        assertEq(getFeed.decimals, int8(2));

        // feed for voting round 12 was overwritten by feed for voting round 2 (history size is 10)
        vm.expectRevert("feed not published yet");
        getFeed = ftsoFeedPublisher.getFeed(feedName1, 12);
    }


    //// helper functions
    function _mockGetVotingRoundId(uint256 _blockTs, uint256 _roundId) private {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.getVotingRoundId.selector, _blockTs),
            abi.encode(_roundId)
        );
    }

    function _mockGetMerkleRoot(uint256 _protocolId, uint256 _votingRoundId, bytes32 _root) private {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(relay.merkleRoots.selector, _protocolId, _votingRoundId),
            abi.encode(_root)
        );
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }
}
