// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/ftso/implementation/FtsoFeedDecimals.sol";

contract FtsoFeedDecimalsTest is Test {

    FtsoFeedDecimals private ftsoFeedDecimals;
    address private addressUpdater;
    address private mockFlareSystemsManager;
    address private governance;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes21 private feedId1;
    bytes21 private feedId2;
    bytes private feedIds;
    bytes private decimals;

    function setUp() public {
        addressUpdater = makeAddr("addressUpdater");
        governance = makeAddr("governance");
        ftsoFeedDecimals = new FtsoFeedDecimals(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            2,
            6,
            0,
            new FtsoFeedDecimals.InitialFeedDecimals[](0)
        );

        vm.prank(addressUpdater);
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        ftsoFeedDecimals.updateContractAddresses(contractNameHashes, contractAddresses);

        feedId1 = bytes21("feed1");
        feedId2 = bytes21("feed2");
    }

    function testConstructorOffsetTooSmall() public {
        vm.expectRevert("offset too small");
        new FtsoFeedDecimals(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            1,
            6,
            0,
            new FtsoFeedDecimals.InitialFeedDecimals[](0)
        );
    }

    function testConstructorInitialFeedDecimals() public {
        FtsoFeedDecimals.InitialFeedDecimals[] memory initialFeedDecimals =
            new FtsoFeedDecimals.InitialFeedDecimals[](2);
        initialFeedDecimals[0] = FtsoFeedDecimals.InitialFeedDecimals(feedId1, 9);
        initialFeedDecimals[1] = FtsoFeedDecimals.InitialFeedDecimals(feedId2, 3);

        ftsoFeedDecimals = new FtsoFeedDecimals(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            2,
            6,
            1,
            initialFeedDecimals
        );
        vm.prank(addressUpdater);
        ftsoFeedDecimals.updateContractAddresses(contractNameHashes, contractAddresses);

        _mockGetCurrentEpochId(1);
        assertEq(ftsoFeedDecimals.getCurrentDecimals(feedId1), 9);
        assertEq(ftsoFeedDecimals.getDecimals(feedId1, 0), 6);
        assertEq(ftsoFeedDecimals.getDecimals(feedId1, 1), 9);
        assertEq(ftsoFeedDecimals.getCurrentDecimals(feedId2), 3);
        assertEq(ftsoFeedDecimals.getDecimals(feedId2, 0), 6);
        assertEq(ftsoFeedDecimals.getDecimals(feedId2, 1), 3);
        vm.startPrank(governance);
        ftsoFeedDecimals.setDecimals(feedId1, 8);
        assertEq(ftsoFeedDecimals.getDecimals(feedId1, 1 + 2), 8);
    }

    function testSetDecimals() public {
        _mockGetCurrentEpochId(0);
        assertEq(ftsoFeedDecimals.getCurrentDecimals(feedId1), 6); // default decimals
        feedIds = bytes.concat(feedId1, feedId2);
        decimals = bytes.concat(bytes1(uint8(6)), bytes1(uint8(6)));
        assertEq(ftsoFeedDecimals.getCurrentDecimalsBulk(feedIds), decimals);

        (int8[] memory _decimals, uint256[] memory validFrom, bool[] memory isFixed) =
            ftsoFeedDecimals.getScheduledDecimalsChanges(feedId1);
        assertEq(_decimals.length, 0);

        vm.startPrank(governance);
        ftsoFeedDecimals.setDecimals(feedId1, 8);
        assertEq(ftsoFeedDecimals.getCurrentDecimals(feedId1), 6);
        assertEq(ftsoFeedDecimals.getDecimals(feedId1, 0 + 2), 8);
        // change again (to 10)
        ftsoFeedDecimals.setDecimals(feedId1, 10);
        assertEq(ftsoFeedDecimals.getDecimals(feedId1, 0 + 2), 10);
        // move to epoch 1 and set fee to 12
        _mockGetCurrentEpochId(1);
        ftsoFeedDecimals.setDecimals(feedId1, 12);
        assertEq(ftsoFeedDecimals.getDecimals(feedId1, 1 + 2), 12);

        (_decimals, validFrom, isFixed) = ftsoFeedDecimals.getScheduledDecimalsChanges(feedId1);
        assertEq(_decimals.length, 2);
        assertEq(_decimals[0], 10);
        assertEq(_decimals[1], 12);
        assertEq(validFrom[0], 2);
        assertEq(validFrom[1], 3);
        assertEq(isFixed[0], true);
        assertEq(isFixed[1], false);

        decimals = bytes.concat(bytes1(uint8(12)), bytes1(uint8(6)));
        assertEq(ftsoFeedDecimals.getDecimalsBulk(feedIds, 3), decimals);
    }

    function testUpdateInThePastRevert() public {
        vm.startPrank(governance);
        _mockGetCurrentEpochId(10);
        ftsoFeedDecimals.setDecimals(feedId1, 5);

        // go back in time
        _mockGetCurrentEpochId(9);
        vm.expectRevert();
        ftsoFeedDecimals.setDecimals(feedId1, 5);
        vm.stopPrank();
    }

    function testGetBulkDecimalsRevert() public {
        _mockGetCurrentEpochId(1);
        vm.expectRevert("invalid reward epoch id");
        ftsoFeedDecimals.getDecimalsBulk(feedIds, 6);
    }

    function testGetDecimalsRevert() public {
        _mockGetCurrentEpochId(1);
        vm.expectRevert("invalid reward epoch id");
        ftsoFeedDecimals.getDecimals(feedId1, 6);
    }

    function testGetDecimalsRevertWrongFeedsLength() public {
        _mockGetCurrentEpochId(0);
        feedIds = bytes.concat(feedId1, feedId2, bytes9("feed3"));
        decimals = bytes.concat(bytes1(uint8(6)), bytes1(uint8(6)));
        vm.expectRevert("invalid _feedIds length");
        ftsoFeedDecimals.getCurrentDecimalsBulk(feedIds);
    }

    //// helper functions
    function _mockGetCurrentEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }
}
