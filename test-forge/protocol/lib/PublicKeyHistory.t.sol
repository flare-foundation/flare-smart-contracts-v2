// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/lib/PublicKeyHistory.sol";

contract PublicKeyHistoryTest is Test {
    using PublicKeyHistory for PublicKeyHistory.CheckPointHistoryState;

    PublicKeyHistory.CheckPointHistoryState checkPointHistoryState;

    PublicKeyHistory.CheckPointHistoryState emptyState;

    PublicKeyHistory.CheckPointHistoryState emptyState2;

    function setUp() public {
        for (uint256 j = 1; j < 100; j++) {
            vm.roll(j);

            checkPointHistoryState.setPublicKey(
                keccak256(abi.encode(j)),
                keccak256(abi.encode(2 * j))
            );
        }
    }

    function test_setPublicKeyInPastFail() public {
        vm.expectRevert();

        vm.roll(10);
        checkPointHistoryState.setPublicKey(
            keccak256(abi.encode("whatever")),
            keccak256(abi.encode("else"))
        );
    }

    function test_publicKeyAtEmpty() public {
        vm.roll(99);

        (bytes32 atNow1, bytes32 atNow2) = emptyState.publicKeyAtNow();
        (bytes32 at1, bytes32 at2) = emptyState.publicKeyAt(70);

        assertEq(at1, bytes32(0));
        assertEq(at2, bytes32(0));
        assertEq(atNow1, bytes32(0));
        assertEq(atNow2, bytes32(0));
    }

    function test_publicKeyAt() public {
        vm.roll(99);

        (bytes32 at1, bytes32 at2) = checkPointHistoryState.publicKeyAt(30);
        (bytes32 atNow1, bytes32 atNow2) = checkPointHistoryState
            .publicKeyAtNow();

        assertEq(at1, keccak256(abi.encode(30)));
        assertEq(at2, keccak256(abi.encode(60)));
        assertEq(atNow1, keccak256(abi.encode(99)));
        assertEq(atNow2, keccak256(abi.encode(198)));
    }

    function test_cleanEmpty() public {
        vm.roll(99);

        uint256 cleaned = emptyState.cleanupOldCheckpoints(3, 3);
        (bytes32 at1, bytes32 at2) = emptyState.publicKeyAt(30);

        assertEq(at1, bytes32(0));
        assertEq(at2, bytes32(0));
        assertEq(cleaned, 0);
    }

    function test_setAddressEmpty() public {
        vm.roll(99);

        emptyState2.setPublicKey(
            keccak256(abi.encode("whatever")),
            keccak256(abi.encode("else"))
        );

        assertEq(emptyState2.startIndex, 0);
        assertEq(emptyState2.endIndex, 1);
    }

    function test_resetPublicKey() public {
        vm.roll(99);

        uint64 endIndex = checkPointHistoryState.endIndex;
        checkPointHistoryState.setPublicKey(
            keccak256(abi.encode("newKey")),
            keccak256(abi.encode("newKey2"))
        );
        (bytes32 at1, bytes32 at2) = checkPointHistoryState.publicKeyAt(99);

        assertEq(at1, keccak256(abi.encode("newKey")));
        assertEq(at2, keccak256(abi.encode("newKey2")));

        assertEq(endIndex, checkPointHistoryState.endIndex);
    }

    function test_setPublicKey() public {
        vm.roll(120);

        uint64 endIndex = checkPointHistoryState.endIndex;
        checkPointHistoryState.setPublicKey(
            keccak256(abi.encode("newKey")),
            keccak256(abi.encode("newKey2"))
        );
        (bytes32 at1, bytes32 at2) = checkPointHistoryState.publicKeyAtNow();

        assertEq(at1, keccak256(abi.encode("newKey")));
        assertEq(at2, keccak256(abi.encode("newKey2")));
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

    function test_clean4() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(10, 0);
        assertEq(cleaned, 0);
        assertEq(checkPointHistoryState.startIndex, 0);
    }

    function test_cleanAndAddressAt() public {
        vm.roll(120);

        uint256 cleaned = checkPointHistoryState.cleanupOldCheckpoints(11, 10);
        assertEq(cleaned, 9);
        assertEq(checkPointHistoryState.startIndex, 9);

        vm.expectRevert("PublicKeyHistory: reading from cleaned-up block");
        checkPointHistoryState.publicKeyAt(3);
    }

    function test_cleanAndAddressAt2() public {
        vm.roll(120);

        checkPointHistoryState.cleanupOldCheckpoints(11, 10);

        (bytes32 at1, bytes32 at2) = checkPointHistoryState.publicKeyAt(10);
        assertEq(at1, keccak256(abi.encode(10)));
        assertEq(at2, keccak256(abi.encode(20)));
    }

    function test_addressAtBeforeFirstSet() public {
        vm.roll(120);

        emptyState.setPublicKey(
            keccak256(abi.encode("new")),
            keccak256(abi.encode("key"))
        );

        (bytes32 at1, bytes32 at2) = emptyState.publicKeyAt(10);
        assertEq(at1, bytes32(0));
        assertEq(at2, bytes32(0));
    }
}
