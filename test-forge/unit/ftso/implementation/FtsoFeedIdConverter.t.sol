// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/ftso/implementation/FtsoFeedIdConverter.sol";

contract FtsoFeedIdConverterTest is Test {

    FtsoFeedIdConverter private ftsoFeedIdConverter;

    function setUp() public {
        ftsoFeedIdConverter = new FtsoFeedIdConverter();
    }

    function testGetFeedId() public {
        bytes21 feedId = ftsoFeedIdConverter.getFeedId(16, "feed1");
        assertEq(feedId, hex"106665656431000000000000000000000000000000");
    }

    function testGetFeedIdRevertNameTooLong() public {
        vm.expectRevert("name too long");
        ftsoFeedIdConverter.getFeedId(123, "feedTooLongName123456");
    }

    function testGetFeedCategoryAndName() public {
        string memory name = "feed1";
        (uint8 feedCategory, string memory feedName) =
            ftsoFeedIdConverter.getFeedCategoryAndName(hex"106665656431000000000000000000000000000000");
        assertEq(feedCategory, 16);
        assertEq(keccak256(abi.encode(feedName)), keccak256(abi.encode(name)));
        assertEq(feedName, name);
    }
}
