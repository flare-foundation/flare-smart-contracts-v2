// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { Bn256Mock } from "../../../../contracts/fastUpdates/mock/Bn256Mock.sol";
import { G1Point } from "../../../../contracts/userInterfaces/IBn256.sol";

contract Bn256Test is Test {

    Bn256Mock private bn256;

    function setUp() public {
        bn256 = new Bn256Mock();
    }

    function testAddTwoPoints() public {
        bytes memory result = _generatePoints("add");
        (
            uint256 ax, uint256 ay,
            uint256 bx, uint256 by,
            uint256 cx, uint256 cy
        ) = abi.decode(result, (uint256, uint256, uint256, uint256, uint256, uint256));

        G1Point memory c = bn256.publicG1Add(
            G1Point(ax, ay),
            G1Point(bx, by)
        );

        assertEq(c.x, cx);
        assertEq(c.y, cy);
    }

    function testScalarMultiply() public {
        bytes memory result = _generatePoints("mul");
        (
            uint256 ax, uint256 ay,
            uint256 scalar,
            uint256 cx, uint256 cy
        ) = abi.decode(result, (uint256, uint256, uint256, uint256, uint256));

        G1Point memory c = bn256.publicG1ScalarMultiply(
            G1Point(ax, ay),
            scalar
        );

        assertEq(c.x, cx);
        assertEq(c.y, cy);
    }

    function _generatePoints(
        string memory _mode
    )
        internal
        returns (bytes memory)
    {
        string[] memory command = new string[](3);
        command[0] = "node";
        command[1] = "test-forge/scripts/generate_bn256_points.js";
        command[2] = _mode;
        return vm.ffi(command);
    }
}
