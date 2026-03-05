// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeFeeCalculator } from "../../../../contracts/tee/implementation/TeeFeeCalculator.sol";
import { TeeFeeCalculatorProxy } from "../../../../contracts/tee/proxy/TeeFeeCalculatorProxy.sol";
import { ITeeFeeCalculator } from "../../../../contracts/userInterfaces/tee/ITeeFeeCalculator.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract TeeFeeCalculatorTest is Test {

    TeeFeeCalculator private teeFeeCalculator;
    TeeFeeCalculator private teeFeeCalculatorImpl;
    TeeFeeCalculatorProxy private teeFeeCalculatorProxy;

    address private governance;
    address private mockTeeWalletManager;
    address private mockTeeWalletKeyManager;
    uint256 private defaultFee;

    function setUp() public {
        governance = makeAddr("governance");
        defaultFee = 1000;
        teeFeeCalculatorImpl = new TeeFeeCalculator();
        teeFeeCalculatorProxy = new TeeFeeCalculatorProxy(
            IGovernanceSettings(address(this)),
            governance,
            defaultFee,
            address(teeFeeCalculatorImpl)
        );
        teeFeeCalculator = TeeFeeCalculator(address(teeFeeCalculatorProxy));
        mockTeeWalletManager = makeAddr("mockTeeWalletManager");
        mockTeeWalletKeyManager = makeAddr("mockTeeWalletKeyManager");
    }


    function testSetOperationFeesRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeFeeCalculator.setOperationFees(
            new bytes32[](0),
            new bytes32[](0),
            new uint256[](0)
        );
    }

    function testSetOperationFeesRevertLengthsMismatch1() public {
        vm.expectRevert(ITeeFeeCalculator.LengthsMismatch.selector);
        vm.prank(governance);
        teeFeeCalculator.setOperationFees(
            new bytes32[](1),
            new bytes32[](2),
            new uint256[](1)
        );
    }

    function testSetOperationFeesRevertLengthsMismatch2() public {
        vm.expectRevert(ITeeFeeCalculator.LengthsMismatch.selector);
        vm.prank(governance);
        teeFeeCalculator.setOperationFees(
            new bytes32[](1),
            new bytes32[](1),
            new uint256[](2)
        );
    }

    function testSetOperationFees() public {
        bytes32[] memory opTypes = new bytes32[](2);
        bytes32[] memory opCommands = new bytes32[](2);
        uint256[] memory fees = new uint256[](2);
        opTypes[0] = bytes32("F_XRP");
        opTypes[1] = bytes32("F_BTC");
        opCommands[0] = bytes32("PAY");
        opCommands[1] = bytes32("REISSUE");
        fees[0] = 100;
        fees[1] = 200;

        vm.prank(governance);
        vm.expectEmit();
        emit ITeeFeeCalculator.OperationFeesSet(opTypes, opCommands, fees);
        teeFeeCalculator.setOperationFees(opTypes, opCommands, fees);

        // assert
        assertEq(teeFeeCalculator.getOperationFee(opTypes[0], opCommands[0]), fees[0]);
        assertEq(teeFeeCalculator.getOperationFee(opTypes[1], opCommands[1]), fees[1]);
        // no fee set
        assertEq(teeFeeCalculator.getOperationFee(opTypes[0], opCommands[1]), 0);
    }

    function testSetDefaultFeeRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeFeeCalculator.setDefaultFee(defaultFee);
    }

    function testSetDefaultFee() public {
        vm.prank(governance);
        vm.expectEmit();
        emit ITeeFeeCalculator.DefaultFeeSet(defaultFee + 1);
        teeFeeCalculator.setDefaultFee(defaultFee + 1);
    }

    function testGetDefaultFee() public {
        assertEq(teeFeeCalculator.getDefaultFee(), defaultFee);
    }

    function testCalculateFeeByTeeIds() public {
        testSetOperationFees();

        address[] memory teeIds = new address[](2);
        teeIds[0] = makeAddr("teeId1");
        teeIds[1] = makeAddr("teeId2");

        assertEq(teeFeeCalculator.calculateFeeByTeeIds(bytes32("F_XRP"), bytes32("PAY"), teeIds),
            100 * teeIds.length);
        assertEq(teeFeeCalculator.calculateFeeByTeeIds(bytes32("F_BTC"), bytes32("REISSUE"), teeIds),
            200 * teeIds.length);
        // no fee set
        assertEq(teeFeeCalculator.calculateFeeByTeeIds(bytes32("F_BTC"), bytes32("PAY"), teeIds),
            teeIds.length * defaultFee);
    }

}
