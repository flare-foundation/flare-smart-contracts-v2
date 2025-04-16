// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeFeeCalculator.sol";


contract TeeFeeCalculatorTest is Test {

    TeeFeeCalculator private teeFeeCalculator;

    address private governance;
    address private addressUpdater;
    address private mockTeeWalletManager;
    address private mockTeeWalletKeyManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    event OperationFeeSet(
        bytes32 opType,
        bytes32 opCommand,
        uint256 fee
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        teeFeeCalculator = new TeeFeeCalculator(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );
        mockTeeWalletManager = makeAddr("mockTeeWalletManager");
        mockTeeWalletKeyManager = makeAddr("mockTeeWalletKeyManager");

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[2] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockTeeWalletManager;
        contractAddresses[2] = mockTeeWalletKeyManager;
        teeFeeCalculator.updateContractAddresses(contractNameHashes, contractAddresses);
    }


    function testSetOperationFeesRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeFeeCalculator.setOperationFees(
            new bytes32[](0),
            new bytes32[](0),
            new uint256[](0)
        );
    }

    function testSetOperationFeesRevertLengthMismatch() public {
        vm.expectRevert("lengths mismatch");
        vm.prank(governance);
        teeFeeCalculator.setOperationFees(
            new bytes32[](1),
            new bytes32[](2),
            new uint256[](2)
        );
    }

    function testSetOperationFees() public {
        bytes32[] memory opTypes = new bytes32[](2);
        bytes32[] memory opCommands = new bytes32[](2);
        uint256[] memory fees = new uint256[](2);
        opTypes[0] = bytes32("XRP");
        opTypes[1] = bytes32("BTC");
        opCommands[0] = bytes32("PAY");
        opCommands[1] = bytes32("REISSUE");
        fees[0] = 100;
        fees[1] = 200;

        vm.prank(governance);
        vm.expectEmit();
        emit OperationFeeSet(opTypes[0], opCommands[0], fees[0]);
        vm.expectEmit();
        emit OperationFeeSet(opTypes[1], opCommands[1], fees[1]);
        teeFeeCalculator.setOperationFees(opTypes, opCommands, fees);

        // assert
        assertEq(teeFeeCalculator.getOperationFee(opTypes[0], opCommands[0]), fees[0]);
        assertEq(teeFeeCalculator.getOperationFee(opTypes[1], opCommands[1]), fees[1]);
        // no fee set
        assertEq(teeFeeCalculator.getOperationFee(opTypes[0], opCommands[1]), 0);
    }

    function testCalculateFeeByWalletId() public {
        testSetOperationFees();

        uint256 feeFactor = 8;
        bytes32 walletId = bytes32("walletId");
        vm.mockCall(
            mockTeeWalletKeyManager,
            abi.encodeWithSelector(ITeeWalletKeyManager.getFeeFactor.selector, walletId),
            abi.encode(feeFactor)
        );

        assertEq(teeFeeCalculator.calculateFeeByWalletId(bytes32("XRP"), bytes32("PAY"), walletId),
            100 * feeFactor);
        assertEq(teeFeeCalculator.calculateFeeByWalletId(bytes32("BTC"), bytes32("REISSUE"), walletId),
            200 * feeFactor);
        // no fee set
        assertEq(teeFeeCalculator.calculateFeeByWalletId(bytes32("BTC"), bytes32("PAY"), walletId), 0);
    }

    function testCalculateFeeByTeeIds() public {
        testSetOperationFees();

        address[] memory teeIds = new address[](2);
        address[] memory backupTeeIds = new address[](2);
        teeIds[0] = makeAddr("teeId1");
        teeIds[1] = makeAddr("teeId2");
        backupTeeIds[0] = makeAddr("backupTeeId1");
        backupTeeIds[1] = makeAddr("backupTeeId2");

        assertEq(teeFeeCalculator.calculateFeeByTeeIds(bytes32("XRP"), bytes32("PAY"), teeIds, backupTeeIds),
            100 * (teeIds.length + backupTeeIds.length));
        assertEq(teeFeeCalculator.calculateFeeByTeeIds(bytes32("BTC"), bytes32("REISSUE"), teeIds, backupTeeIds),
            200 * (teeIds.length + backupTeeIds.length));
        // no fee set
        assertEq(teeFeeCalculator.calculateFeeByTeeIds(bytes32("BTC"), bytes32("PAY"), teeIds, backupTeeIds), 0);
    }

}
