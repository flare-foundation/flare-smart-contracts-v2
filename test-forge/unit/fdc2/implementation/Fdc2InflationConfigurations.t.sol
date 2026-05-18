// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { Fdc2InflationConfigurations } from
    "../../../../contracts/fdc2/implementation/Fdc2InflationConfigurations.sol";
import { Fdc2InflationConfigurationsProxy } from
    "../../../../contracts/fdc2/proxy/Fdc2InflationConfigurationsProxy.sol";
import { IFdc2InflationConfigurations } from
    "../../../../contracts/userInterfaces/fdc2/IFdc2InflationConfigurations.sol";
import { IFdc2RequestFeeConfigurations } from
    "../../../../contracts/userInterfaces/fdc2/IFdc2RequestFeeConfigurations.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract Fdc2InflationConfigurationsTest is Test {

    Fdc2InflationConfigurations private inflationConfigs;
    address private governance;
    address private addressUpdater;
    address private mockFdc2RequestFeeConfigurations;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes32 private type1;
    bytes32 private source1;
    bytes32 private type2;
    bytes32 private source2;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockFdc2RequestFeeConfigurations = makeAddr("fdc2RequestFeeConfigurations");

        Fdc2InflationConfigurations impl = new Fdc2InflationConfigurations();
        Fdc2InflationConfigurationsProxy proxy = new Fdc2InflationConfigurationsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(impl)
        );
        inflationConfigs = Fdc2InflationConfigurations(address(proxy));

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("Fdc2RequestFeeConfigurations"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(mockFdc2RequestFeeConfigurations);
        inflationConfigs.updateContractAddresses(contractNameHashes, contractAddresses);

        type1 = bytes32("type1");
        source1 = bytes32("source1");
        type2 = bytes32("type2");
        source2 = bytes32("source2");
        vm.startPrank(governance);
    }

    function testAddConfigRevertTypeAndSourceNotSupported() public {
        _mockGetTypeAndSourceFee(type1, source1, true);
        IFdc2InflationConfigurations.Fdc2Configuration[] memory configs =
            new IFdc2InflationConfigurations.Fdc2Configuration[](1);
        configs[0] = IFdc2InflationConfigurations.Fdc2Configuration(
            type1, source1, 10000, 2, 0
        );
        vm.expectRevert(IFdc2RequestFeeConfigurations.TypeAndSourceCombinationNotSupported.selector);
        inflationConfigs.addFdc2Configurations(configs);
    }

    function testAddFdc2Configurations() public {
        _mockGetTypeAndSourceFee(type1, source1, false);
        _mockGetTypeAndSourceFee(type2, source2, false);
        IFdc2InflationConfigurations.Fdc2Configuration[] memory fdc2Configurations;

        vm.expectRevert(IFdc2InflationConfigurations.InvalidIndex.selector);
        inflationConfigs.getFdc2Configuration(3);

        IFdc2InflationConfigurations.Fdc2Configuration[] memory configs =
            new IFdc2InflationConfigurations.Fdc2Configuration[](2);
        configs[0] = IFdc2InflationConfigurations.Fdc2Configuration(
            type1, source1, 10000, 2, 0
        );
        configs[1] = IFdc2InflationConfigurations.Fdc2Configuration(
            type2, source2, 5000, 5, 1
        );
        inflationConfigs.addFdc2Configurations(configs);

        fdc2Configurations = inflationConfigs.getFdc2Configurations();
        assertEq(fdc2Configurations.length, 2);
        assertEq(fdc2Configurations[0].attestationType, type1);
        assertEq(fdc2Configurations[1].attestationType, type2);
        assertEq(fdc2Configurations[0].sourceId, source1);
        assertEq(fdc2Configurations[1].sourceId, source2);
        assertEq(fdc2Configurations[0].inflationShare, 10000);
        assertEq(fdc2Configurations[1].inflationShare, 5000);
        assertEq(fdc2Configurations[0].minRequestsThreshold, 2);
        assertEq(fdc2Configurations[1].minRequestsThreshold, 5);
        assertEq(fdc2Configurations[0].mode, 0);
        assertEq(fdc2Configurations[1].mode, 1);
    }

    function testReplaceFdc2Configurations() public {
        IFdc2InflationConfigurations.Fdc2Configuration memory getConfig;
        testAddFdc2Configurations();

        uint256[] memory indices = new uint256[](1);
        indices[0] = 2;
        IFdc2InflationConfigurations.Fdc2Configuration[] memory configs =
            new IFdc2InflationConfigurations.Fdc2Configuration[](1);
        configs[0] = IFdc2InflationConfigurations.Fdc2Configuration(
            type1, source2, 6000, 100, 3
        );
        vm.expectRevert(IFdc2InflationConfigurations.InvalidIndex.selector);
        inflationConfigs.replaceFdc2Configurations(indices, configs);

        _mockGetTypeAndSourceFee(type1, source2, true);
        vm.expectRevert(IFdc2RequestFeeConfigurations.TypeAndSourceCombinationNotSupported.selector);
        indices[0] = 1;
        inflationConfigs.replaceFdc2Configurations(indices, configs);

        _mockGetTypeAndSourceFee(type1, source2, false);
        getConfig = inflationConfigs.getFdc2Configuration(1);
        assertEq(getConfig.attestationType, type2);
        assertEq(getConfig.sourceId, source2);
        assertEq(getConfig.inflationShare, 5000);
        assertEq(getConfig.minRequestsThreshold, 5);
        assertEq(getConfig.mode, 1);
        inflationConfigs.replaceFdc2Configurations(indices, configs);
        getConfig = inflationConfigs.getFdc2Configuration(1);
        assertEq(getConfig.attestationType, type1);
        assertEq(getConfig.sourceId, source2);
        assertEq(getConfig.inflationShare, 6000);
        assertEq(getConfig.minRequestsThreshold, 100);
        assertEq(getConfig.mode, 3);
    }

    function testReplaceFdc2ConfigurationsRevertMismatch() public {
        testAddFdc2Configurations();
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        IFdc2InflationConfigurations.Fdc2Configuration[] memory configs =
            new IFdc2InflationConfigurations.Fdc2Configuration[](1);
        configs[0] = IFdc2InflationConfigurations.Fdc2Configuration(
            type1, source2, 6000, 100, 3
        );
        vm.expectRevert(IFdc2InflationConfigurations.LengthsMismatch.selector);
        inflationConfigs.replaceFdc2Configurations(indices, configs);
    }

    function testRemoveFdc2Configuration() public {
        IFdc2InflationConfigurations.Fdc2Configuration memory getConfig;
        IFdc2InflationConfigurations.Fdc2Configuration[] memory fdc2Configurations;
        testAddFdc2Configurations();

        vm.expectRevert(IFdc2InflationConfigurations.InvalidIndex.selector);
        inflationConfigs.removeFdc2Configuration(2);

        getConfig = inflationConfigs.getFdc2Configuration(0);
        assertEq(getConfig.attestationType, type1);
        inflationConfigs.removeFdc2Configuration(0);
        getConfig = inflationConfigs.getFdc2Configuration(0);
        assertEq(getConfig.attestationType, type2);
        fdc2Configurations = inflationConfigs.getFdc2Configurations();
        assertEq(fdc2Configurations.length, 1);

        inflationConfigs.removeFdc2Configuration(0);
        fdc2Configurations = inflationConfigs.getFdc2Configurations();
        assertEq(fdc2Configurations.length, 0);
    }

    function testOnlyGovernanceCanAdd() public {
        vm.stopPrank();
        IFdc2InflationConfigurations.Fdc2Configuration[] memory configs =
            new IFdc2InflationConfigurations.Fdc2Configuration[](0);
        vm.expectRevert("only governance");
        inflationConfigs.addFdc2Configurations(configs);
    }

    function _mockGetTypeAndSourceFee(bytes32 _type, bytes32 _source, bool _revert) internal {
        bytes memory selectorWithData = abi.encodeWithSelector(
            IFdc2RequestFeeConfigurations.getTypeAndSourceFee.selector,
            _type,
            _source
        );
        if (_revert) {
            vm.mockCallRevert(
                mockFdc2RequestFeeConfigurations,
                selectorWithData,
                abi.encodeWithSelector(
                    IFdc2RequestFeeConfigurations.TypeAndSourceCombinationNotSupported.selector
                )
            );
        } else {
            vm.mockCall(
                mockFdc2RequestFeeConfigurations,
                selectorWithData,
                abi.encode(5)
            );
        }
    }
}
