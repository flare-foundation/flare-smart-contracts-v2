// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import {
    Fdc2RequestFeeConfigurations
} from "../../../../contracts/fdc2/implementation/Fdc2RequestFeeConfigurations.sol";
import {
    Fdc2RequestFeeConfigurationsProxy
} from "../../../../contracts/fdc2/proxy/Fdc2RequestFeeConfigurationsProxy.sol";
import {
    IFdc2RequestFeeConfigurations
} from "../../../../contracts/userInterfaces/fdc2/IFdc2RequestFeeConfigurations.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract Fdc2RequestFeeConfigurationsTest is Test {

    Fdc2RequestFeeConfigurations private fdc2RequestFeeConfigurations;
    Fdc2RequestFeeConfigurations private fdc2RequestFeeConfigurationsImpl;
    Fdc2RequestFeeConfigurationsProxy private fdc2RequestFeeConfigurationsProxy;

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

        fdc2RequestFeeConfigurationsImpl = new Fdc2RequestFeeConfigurations();
        fdc2RequestFeeConfigurationsProxy = new Fdc2RequestFeeConfigurationsProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            address(0),
            address(fdc2RequestFeeConfigurationsImpl)
        );
        fdc2RequestFeeConfigurations = Fdc2RequestFeeConfigurations(address(fdc2RequestFeeConfigurationsProxy));
    }


    // setTypeAndSourceFee
    function testSetTypeAndSourceFeeRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        fdc2RequestFeeConfigurations.setTypeAndSourceFee(testType, source, fee);
    }


    function testSetTypeAndSourceFeeRevertFeeMustBeGreaterThanZero() public {
        vm.prank(initialGovernance);
        vm.expectRevert(IFdc2RequestFeeConfigurations.FeeMustBeGreaterThanZero.selector);
        fdc2RequestFeeConfigurations.setTypeAndSourceFee(testType, source, 0);
    }


    function testSetTypeAndSourceFee() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IFdc2RequestFeeConfigurations.TypeAndSourceFeeSet(
            testType, source, fee
        );
        fdc2RequestFeeConfigurations.setTypeAndSourceFee(testType, source, fee);
    }


    // removeTypeAndSourceFee
    function testRemoveTypeAndSourceFeeRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        fdc2RequestFeeConfigurations.removeTypeAndSourceFee(testType, source);
    }


    function testRemoveTypeAndSourceFeeRevertFeeNotSet() public {
        vm.prank(initialGovernance);
        vm.expectRevert(IFdc2RequestFeeConfigurations.FeeNotSet.selector);
        fdc2RequestFeeConfigurations.removeTypeAndSourceFee(testType, source);
    }


    function testRemoveTypeAndSourceFee() public {
        testSetTypeAndSourceFee();
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IFdc2RequestFeeConfigurations.TypeAndSourceFeeRemoved(
            testType, source
        );
        fdc2RequestFeeConfigurations.removeTypeAndSourceFee(testType, source);
    }


    // setTypeAndSourceFees
    function testSetTypeAndSourceFeesRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        fdc2RequestFeeConfigurations.setTypeAndSourceFees(testTypes, sources, fees);
    }


    function testSetTypeAndSourceFeesRevertLengthsMismatch() public {
        fees = new uint256[](0);
        vm.prank(initialGovernance);
        vm.expectRevert(IFdc2RequestFeeConfigurations.LengthsMismatch.selector);
        fdc2RequestFeeConfigurations.setTypeAndSourceFees(testTypes, sources, fees);
    }


    function testSetTypeAndSourceFees() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IFdc2RequestFeeConfigurations.TypeAndSourceFeeSet(
            testTypes[0], sources[0], fees[0]
        );
        fdc2RequestFeeConfigurations.setTypeAndSourceFees(testTypes, sources, fees);
    }


    // removeTypeAndSourceFees
    function testRemoveTypeAndSourceFeesRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        fdc2RequestFeeConfigurations.removeTypeAndSourceFees(testTypes, sources);
    }


    function testRemoveTypeAndSourceFeesRevertLengthsMismatch() public {
        testTypes = new bytes32[](0);
        vm.prank(initialGovernance);
        vm.expectRevert(IFdc2RequestFeeConfigurations.LengthsMismatch.selector);
        fdc2RequestFeeConfigurations.removeTypeAndSourceFees(testTypes, sources);
    }


    function testRemoveTypeAndSourceFees() public {
        testSetTypeAndSourceFees();
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IFdc2RequestFeeConfigurations.TypeAndSourceFeeRemoved(
            testTypes[0], sources[0]
        );
        fdc2RequestFeeConfigurations.removeTypeAndSourceFees(testTypes, sources);
    }


    // getTypeAndSourceFee
    function testGetTypeAndSourceFeeRevertTypeAndSourceCombinationNotSupported() public {
        vm.expectRevert(IFdc2RequestFeeConfigurations.TypeAndSourceCombinationNotSupported.selector);
        fdc2RequestFeeConfigurations.getTypeAndSourceFee(keccak256("invalidType"), source);
    }


    function testGetTypeAndSourceFee() public {
        testSetTypeAndSourceFee();
        uint256 returnedFee =
            fdc2RequestFeeConfigurations.getTypeAndSourceFee(testType, source);
        assertEq(returnedFee, fee);
    }
}