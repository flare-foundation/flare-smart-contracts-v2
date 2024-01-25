// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/lib/AddressHistory.sol";

contract AddressHistoryTest is Test {
    using AddressHistory for AddressHistory.CheckPointHistoryState;

    AddressHistory.CheckPointHistoryState checkPointHistoryState;

    AddressHistory.CheckPointHistoryState emptyState;

    AddressHistory.CheckPointHistoryState emptyState2;

    function setUp() public {
        for (uint256 j = 1; j < 100; j++) {
            vm.roll(j);

            checkPointHistoryState.setAddress(makeAddr(string(abi.encode(j))));
        }
    }

    function test_setAddressInPastFail() public {
        vm.expectRevert();

        vm.roll(10);
        checkPointHistoryState.setAddress(makeAddr("whatever"));
    }

    function test_addressAtEmpty() public {
        vm.roll(99);

        address atNow = emptyState.addressAtNow();
        address at = emptyState.addressAt(30);
        assertEq(at, address(0));
        assertEq(atNow, address(0));
    }

    function test_cleanEmpty() public {
        vm.roll(99);

        uint256 cleaned = emptyState.cleanupOldCheckpoints(3, 3);
        address at = emptyState.addressAt(30);
        assertEq(at, address(0));
        assertEq(cleaned, 0);
    }

    function test_setAddressEmpty() public {
        vm.roll(99);

        emptyState2.setAddress(makeAddr("address"));
        assertEq(emptyState2.addressAtNow(), makeAddr("address"));
        assertEq(emptyState2.startIndex, 0);
        assertEq(emptyState2.endIndex, 1);
    }

    function test_resetAddress() public {
        vm.roll(99);

        uint64 endIndex = checkPointHistoryState.endIndex;
        checkPointHistoryState.setAddress(makeAddr("newAddress"));
        assertEq(checkPointHistoryState.addressAt(99), makeAddr("newAddress"));
        assertEq(endIndex, checkPointHistoryState.endIndex);
    }

    function test_setAddress() public {
        vm.roll(120);

        uint64 endIndex = checkPointHistoryState.endIndex;
        checkPointHistoryState.setAddress(makeAddr("addedAddress"));
        assertEq(checkPointHistoryState.addressAtNow(), makeAddr("addedAddress"));
        assertEq(endIndex + 1, checkPointHistoryState.endIndex);
    }

    function test_clean() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(3, 50);
        assertEq(cleaned, 3);
        assertEq(checkPointHistoryState.startIndex, 3);
    }

    function test_clean2() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(11, 10);
        assertEq(cleaned, 9);
        assertEq(checkPointHistoryState.startIndex, 9);
    }

    function test_clean3() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(0, 10);
        assertEq(cleaned, 0);
        assertEq(checkPointHistoryState.startIndex, 0);
    }

    function test_cleanAndAddressAt() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(11, 10);
        assertEq(cleaned, 9);
        assertEq(checkPointHistoryState.startIndex, 9);

        vm.expectRevert("AddressHistory: reading from cleaned-up block");
        checkPointHistoryState.addressAt(3);
    }

    function test_cleanAndAddressAt2() public {
        vm.roll(120);

        AddressHistory.cleanupOldCheckpoints(checkPointHistoryState, 11, 10);

        address addressAt10 = checkPointHistoryState.addressAt(10);
        assertEq(addressAt10, makeAddr(string(abi.encode(10))));
    }

    function test_addressAtBeforeFirstSet() public {
        vm.roll(120);

        emptyState.setAddress(makeAddr("anything"));

        address addressAt10 = emptyState.addressAt(10);
        assertEq(addressAt10, address(0));
    }
}
