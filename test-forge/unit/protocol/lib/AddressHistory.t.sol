// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/lib/AddressHistory.sol";

contract AddressHistoryTest is Test {
    using AddressHistory for AddressHistory.CheckPointHistoryState;

    AddressHistory.CheckPointHistoryState private checkPointHistoryState;

    AddressHistory.CheckPointHistoryState private emptyState;

    AddressHistory.CheckPointHistoryState private emptyState2;

    function setUp() public {
        for (uint256 j = 1; j < 100; j++) {
            vm.roll(j);

            checkPointHistoryState.setAddress(makeAddr(string(abi.encode(j))));
        }
    }

    function testSetAddressInPastFail() public {
        vm.expectRevert();

        vm.roll(10);
        checkPointHistoryState.setAddress(makeAddr("whatever"));
    }

    function testAddressAtEmpty() public {
        vm.roll(99);

        address atNow = emptyState.addressAtNow();
        address at = emptyState.addressAt(70);

        assertEq(at, address(0));
        assertEq(atNow, address(0));
    }

    function testAddressAt() public {
        vm.roll(99);

        address at = checkPointHistoryState.addressAt(30);
        address atNow = checkPointHistoryState.addressAtNow();

        assertEq(at, makeAddr(string(abi.encode(30))));
        assertEq(atNow, makeAddr(string(abi.encode(99))));
    }

    function testCleanEmpty() public {
        vm.roll(99);

        uint256 cleaned = emptyState.cleanupOldCheckpoints(3, 3);
        address at = emptyState.addressAt(30);
        assertEq(at, address(0));
        assertEq(cleaned, 0);
    }

    function testSetAddressEmpty() public {
        vm.roll(99);

        emptyState2.setAddress(makeAddr("address"));
        assertEq(emptyState2.addressAtNow(), makeAddr("address"));
        assertEq(emptyState2.startIndex, 0);
        assertEq(emptyState2.endIndex, 1);
    }

    function testResetAddress() public {
        vm.roll(99);

        uint64 endIndex = checkPointHistoryState.endIndex;
        checkPointHistoryState.setAddress(makeAddr("newAddress"));
        assertEq(checkPointHistoryState.addressAt(99), makeAddr("newAddress"));
        assertEq(endIndex, checkPointHistoryState.endIndex);
    }

    function testSetAddress() public {
        vm.roll(120);

        uint64 endIndex = checkPointHistoryState.endIndex;
        checkPointHistoryState.setAddress(makeAddr("addedAddress"));
        assertEq(
            checkPointHistoryState.addressAtNow(),
            makeAddr("addedAddress")
        );
        assertEq(endIndex + 1, checkPointHistoryState.endIndex);
    }

    function testClean() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(3, 50);
        assertEq(cleaned, 3);
        assertEq(checkPointHistoryState.startIndex, 3);
    }

    function testClean2() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(11, 10);
        assertEq(cleaned, 9);
        assertEq(checkPointHistoryState.startIndex, 9);
    }

    function testClean3() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(0, 10);
        assertEq(cleaned, 0);
        assertEq(checkPointHistoryState.startIndex, 0);
    }

    function testClean4() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(10, 0);
        assertEq(cleaned, 0);
        assertEq(checkPointHistoryState.startIndex, 0);
    }

    function testCleanAndAddressAt() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(11, 10);
        assertEq(cleaned, 9);
        assertEq(checkPointHistoryState.startIndex, 9);

        vm.expectRevert("AddressHistory: reading from cleaned-up block");
        checkPointHistoryState.addressAt(3);
    }

    function testCleanAndAddressAt2() public {
        vm.roll(120);

        AddressHistory.cleanupOldCheckpoints(checkPointHistoryState, 11, 10);

        address addressAt10 = checkPointHistoryState.addressAt(10);
        assertEq(addressAt10, makeAddr(string(abi.encode(10))));
    }

    function testAddressAtBeforeFirstSet() public {
        vm.roll(120);

        emptyState.setAddress(makeAddr("anything"));

        address addressAt10 = emptyState.addressAt(10);
        assertEq(addressAt10, address(0));
    }
}
