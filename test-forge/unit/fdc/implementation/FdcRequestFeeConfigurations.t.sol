// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/fdc/implementation/FdcHub.sol";
import "../../../../contracts/fdc/implementation/FdcInflationConfigurations.sol";
import "../../../../contracts/fdc/implementation/FdcRequestFeeConfigurations.sol";
import "../../../../contracts/protocol/implementation/RewardManager.sol";

contract FdcRequestFeeConfigurationsTest is Test {
    FdcRequestFeeConfigurations private fdcRequestFeeConfigurations;

    address private governance;

    bytes32 private type1;
    bytes32 private source1;
    uint256 private fee1;
    bytes32 private type2;
    bytes32 private source2;
    uint256 private fee2;

    function setUp() public {
        governance = makeAddr("governance");

        fdcRequestFeeConfigurations = new FdcRequestFeeConfigurations(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance
        );

        type1 = bytes32("type1");
        source1 = bytes32("source1");
        fee1 = 123;
        type2 = bytes32("type2");
        source2 = bytes32("source2");
        fee2 = 456;
    }

    // type and source fee
    function testSetTypeAndSourceFee() public {
        vm.prank(governance);
        fdcRequestFeeConfigurations.setTypeAndSourceFee(type1, source1, fee1);

        assertEq(fdcRequestFeeConfigurations.typeAndSourceFees(_joinTypeAndSource(type1, source1)), fee1);
    }

    function testSetTypeAndSourceFeeRevertFeeZero() public {
        vm.prank(governance);
        vm.expectRevert("Fee must be greater than 0");
        fdcRequestFeeConfigurations.setTypeAndSourceFee(type1, source1, 0);
    }

    function testRemoveTypeAndSourceFee() public {
        testSetTypeAndSourceFee();

        vm.prank(governance);
        fdcRequestFeeConfigurations.removeTypeAndSourceFee(type1, source1);

        assertEq(fdcRequestFeeConfigurations.typeAndSourceFees(_joinTypeAndSource(type1, source1)), 0);
    }

    function testRemoveTypeAndSourceFeeRevertNotSet() public {
        vm.prank(governance);
        vm.expectRevert("Fee not set");
        fdcRequestFeeConfigurations.removeTypeAndSourceFee(type1, source1);
    }

    function testSetTypeAndSourceFees() public {
        bytes32[] memory types = new bytes32[](2);
        types[0] = type1;
        types[1] = type2;
        bytes32[] memory sources = new bytes32[](2);
        sources[0] = source1;
        sources[1] = source2;
        uint256[] memory fees = new uint256[](2);
        fees[0] = fee1;
        fees[1] = fee2;
        vm.prank(governance);
        fdcRequestFeeConfigurations.setTypeAndSourceFees(types, sources, fees);

        assertEq(fdcRequestFeeConfigurations.typeAndSourceFees(_joinTypeAndSource(type1, source1)), fee1);
        assertEq(fdcRequestFeeConfigurations.typeAndSourceFees(_joinTypeAndSource(type2, source2)), fee2);
    }

    function testSetTypeAndSourceFeeRevertMismatch() public {
        bytes32[] memory types = new bytes32[](2);
        types[0] = type1;
        types[1] = type2;
        bytes32[] memory sources = new bytes32[](2);
        sources[0] = source1;
        sources[1] = source2;
        uint256[] memory fees = new uint256[](1);
        fees[0] = fee1;
        vm.prank(governance);
        vm.expectRevert("length mismatch");
        fdcRequestFeeConfigurations.setTypeAndSourceFees(types, sources, fees);
    }

    function testRemoveTypeAndSourceFees() public {
        testSetTypeAndSourceFees();

        bytes32[] memory types = new bytes32[](1);
        types[0] = type1;
        bytes32[] memory sources = new bytes32[](1);
        sources[0] = source1;
        vm.prank(governance);
        fdcRequestFeeConfigurations.removeTypeAndSourceFees(types, sources);

        assertEq(fdcRequestFeeConfigurations.typeAndSourceFees(_joinTypeAndSource(type1, source1)), 0);
        assertEq(fdcRequestFeeConfigurations.typeAndSourceFees(_joinTypeAndSource(type2, source2)), 456);
    }

    function testRemoveTypeAndSourceFeesRevertMismatch() public {
        testSetTypeAndSourceFees();

        bytes32[] memory types = new bytes32[](1);
        types[0] = type1;
        bytes32[] memory sources = new bytes32[](0);
        vm.prank(governance);
        vm.expectRevert("length mismatch");
        fdcRequestFeeConfigurations.removeTypeAndSourceFees(types, sources);
    }

    function testGetRequestFee() public {
        testSetTypeAndSourceFee();

        bytes memory data = abi.encodePacked(type1, source1);
        data = abi.encodePacked(data, bytes32("additional data"));
        assertEq(fdcRequestFeeConfigurations.getRequestFee(data), fee1);
    }

    function testGetRequestFeeRevertTypeAndSourceCombinationNotSupported() public {
        testSetTypeAndSourceFee();

        bytes memory data = abi.encodePacked(type1, source2);
        data = abi.encodePacked(data, bytes32("additional data"));
        vm.expectRevert("Type and source combination not supported");
        fdcRequestFeeConfigurations.getRequestFee(data);
    }

    function testGetBaseFeeRevert() public {
        vm.expectRevert("Request data too short, should at least specify type and source");
        fdcRequestFeeConfigurations.getRequestFee(abi.encodePacked(type1));
    }

    function _joinTypeAndSource(bytes32 _type, bytes32 _source) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_type, _source));
    }
}
