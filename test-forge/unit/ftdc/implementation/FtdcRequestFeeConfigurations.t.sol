// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import {
    FtdcRequestFeeConfigurations
} from "../../../../contracts/ftdc/implementation/FtdcRequestFeeConfigurations.sol";
import { FtdcRequestFeeConfigurationsProxy } from "../../../../contracts/ftdc/proxy/FtdcRequestFeeConfigurationsProxy.sol";
import {
    IFtdcRequestFeeConfigurations
} from "../../../../contracts/userInterfaces/ftdc/IFtdcRequestFeeConfigurations.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract FtdcRequestFeeConfigurationsTest is Test {

    FtdcRequestFeeConfigurations private ftdcRequestFeeConfigurations;
    FtdcRequestFeeConfigurations private ftdcRequestFeeConfigurationsImpl;
    FtdcRequestFeeConfigurationsProxy private ftdcRequestFeeConfigurationsProxy;

    address private initialGovernance;

    bytes32 private testType;
    bytes32 private source;
    uint256 private fee;
    bytes32[] private testTypes;
    bytes32[] private sources;
    uint256[] private fees;


    function setUp() public {
        testType = keccak256("type");
        source = keccak256("source");
        fee = 10;

        testTypes = new bytes32[](1);
        testTypes[0] = testType;
        sources = new bytes32[](1);
        sources[0] = source;
        fees = new uint256[](1);
        fees[0] = fee;

        initialGovernance = makeAddr("initialGovernance");

        ftdcRequestFeeConfigurationsImpl = new FtdcRequestFeeConfigurations();
        ftdcRequestFeeConfigurationsProxy = new FtdcRequestFeeConfigurationsProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            address(ftdcRequestFeeConfigurationsImpl)
        );
        ftdcRequestFeeConfigurations = FtdcRequestFeeConfigurations(address(ftdcRequestFeeConfigurationsProxy));
    }


    // setTypeAndSourceFee
    function testSetTypeAndSourceFeeRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        ftdcRequestFeeConfigurations.setTypeAndSourceFee(testType, source, fee);
    }


    function testSetTypeAndSourceFeeRevertFeeMustBeGreaterThanZero() public {
        vm.prank(initialGovernance);
        vm.expectRevert(IFtdcRequestFeeConfigurations.FeeMustBeGreaterThanZero.selector);
        ftdcRequestFeeConfigurations.setTypeAndSourceFee(testType, source, 0);
    }


    function testSetTypeAndSourceFee() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IFtdcRequestFeeConfigurations.TypeAndSourceFeeSet(
            testType, source, fee
        );
        ftdcRequestFeeConfigurations.setTypeAndSourceFee(testType, source, fee);
    }


    // removeTypeAndSourceFee
    function testRemoveTypeAndSourceFeeRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        ftdcRequestFeeConfigurations.removeTypeAndSourceFee(testType, source);
    }


    function testRemoveTypeAndSourceFeeRevertFeeNotSet() public {
        vm.prank(initialGovernance);
        vm.expectRevert(IFtdcRequestFeeConfigurations.FeeNotSet.selector);
        ftdcRequestFeeConfigurations.removeTypeAndSourceFee(testType, source);
    }


    function testRemoveTypeAndSourceFee() public {
        testSetTypeAndSourceFee();
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IFtdcRequestFeeConfigurations.TypeAndSourceFeeRemoved(
            testType, source
        );
        ftdcRequestFeeConfigurations.removeTypeAndSourceFee(testType, source);
    }


    // setTypeAndSourceFees
    function testSetTypeAndSourceFeesRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        ftdcRequestFeeConfigurations.setTypeAndSourceFees(testTypes, sources, fees);
    }


    function testSetTypeAndSourceFeesRevertLengthsMismatch() public {
        fees = new uint256[](0);
        vm.prank(initialGovernance);
        vm.expectRevert(IFtdcRequestFeeConfigurations.LengthsMismatch.selector);
        ftdcRequestFeeConfigurations.setTypeAndSourceFees(testTypes, sources, fees);
    }


    function testSetTypeAndSourceFees() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IFtdcRequestFeeConfigurations.TypeAndSourceFeeSet(
            testTypes[0], sources[0], fees[0]
        );
        ftdcRequestFeeConfigurations.setTypeAndSourceFees(testTypes, sources, fees);
    }


    // removeTypeAndSourceFees
    function testRemoveTypeAndSourceFeesRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        ftdcRequestFeeConfigurations.removeTypeAndSourceFees(testTypes, sources);
    }


    function testRemoveTypeAndSourceFeesRevertLengthsMismatch() public {
        testTypes = new bytes32[](0);
        vm.prank(initialGovernance);
        vm.expectRevert(IFtdcRequestFeeConfigurations.LengthsMismatch.selector);
        ftdcRequestFeeConfigurations.removeTypeAndSourceFees(testTypes, sources);
    }


    function testRemoveTypeAndSourceFees() public {
        testSetTypeAndSourceFees();
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IFtdcRequestFeeConfigurations.TypeAndSourceFeeRemoved(
            testTypes[0], sources[0]
        );
        ftdcRequestFeeConfigurations.removeTypeAndSourceFees(testTypes, sources);
    }


    // getTypeAndSourceFee
    function testGetTypeAndSourceFeeRevertTypeAndSourceCombinationNotSupported() public {
        vm.expectRevert(IFtdcRequestFeeConfigurations.TypeAndSourceCombinationNotSupported.selector);
        ftdcRequestFeeConfigurations.getTypeAndSourceFee(keccak256("invalidType"), source);
    }


    function testGetTypeAndSourceFee() public {
        testSetTypeAndSourceFee();
        uint256 returnedFee =
            ftdcRequestFeeConfigurations.getTypeAndSourceFee(testType, source);
        assertEq(returnedFee, fee);
    }
}