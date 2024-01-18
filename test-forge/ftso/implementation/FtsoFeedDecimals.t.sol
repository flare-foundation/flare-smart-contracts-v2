// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/ftso/implementation/FtsoFeedDecimals.sol";

contract FtsoFeedDecimalsTest is Test {

    FtsoFeedDecimals private ftsoFeedDecimals;
    address private addressUpdater;
    address private mockFlareSystemManager;
    address private governance;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes8 private feedName1;
    bytes8 private feedName2;
    bytes private feedNames;
    bytes private decimals;

    function setUp() public {
        addressUpdater = makeAddr("addressUpdater");
        governance = makeAddr("governance");
        ftsoFeedDecimals = new FtsoFeedDecimals(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            2,
            6
        );

        vm.prank(addressUpdater);
        mockFlareSystemManager = makeAddr("mockFlareSystemManager");
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemManager;
        ftsoFeedDecimals.updateContractAddresses(contractNameHashes, contractAddresses);

        feedName1 = bytes8("feed1");
        feedName2 = bytes8("feed2");
    }


    function testConstructorOffsetTooSmall() public {
        vm.expectRevert("offset too small");
        new FtsoFeedDecimals(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            1,
            6
        );
    }

    function testSetDecimals() public {
        _mockGetCurrentEpochId(0);
        assertEq(ftsoFeedDecimals.getCurrentDecimals(feedName1), 6); // default decimals
        feedNames = bytes.concat(feedName1, feedName2);
        decimals = bytes.concat(bytes1(uint8(6)), bytes1(uint8(6)));
        assertEq(ftsoFeedDecimals.getCurrentDecimalsBulk(feedNames), decimals);

        vm.startPrank(governance);
        ftsoFeedDecimals.setDecimals(feedName1, 8);
        assertEq(ftsoFeedDecimals.getCurrentDecimals(feedName1), 6);
        assertEq(ftsoFeedDecimals.getDecimals(feedName1, 0 + 2), 8);
        // change again (to 10)
        ftsoFeedDecimals.setDecimals(feedName1, 10);
        assertEq(ftsoFeedDecimals.getDecimals(feedName1, 0 + 2), 10);
        // move to epoch 1 and set fee to 12
        _mockGetCurrentEpochId(1);
        ftsoFeedDecimals.setDecimals(feedName1, 12);
        assertEq(ftsoFeedDecimals.getDecimals(feedName1, 1 + 2), 12);

        decimals = bytes.concat(bytes1(uint8(12)), bytes1(uint8(6)));
        assertEq(ftsoFeedDecimals.getDecimalsBulk(feedNames, 3), decimals);
    }

    function testUpdateInThePastRevert() public {
        vm.startPrank(governance);
        _mockGetCurrentEpochId(10);
        ftsoFeedDecimals.setDecimals(feedName1, 5);

        // go back in time
        _mockGetCurrentEpochId(9);
        vm.expectRevert();
        ftsoFeedDecimals.setDecimals(feedName1, 5);
        vm.stopPrank();
    }

    function testGetDecimalsRevertWrongFeedsLength() public {
        _mockGetCurrentEpochId(0);
        feedNames = bytes.concat(feedName1, feedName2, bytes9("feed3"));
        decimals = bytes.concat(bytes1(uint8(6)), bytes1(uint8(6)));
        vm.expectRevert();
        ftsoFeedDecimals.getCurrentDecimalsBulk(feedNames);
    }

    //// helper functions
    function _mockGetCurrentEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(FlareSystemManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }
}
