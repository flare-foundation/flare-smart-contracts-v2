// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/fdc/implementation/FdcInflationConfigurations.sol";

contract FdcInflationConfigurationsTest is Test {

    FdcInflationConfigurations private inflationConfigs;
    address private governance;
    address private addressUpdater;
    address private mockFdcHub;

    IFdcInflationConfigurations.FdcConfiguration private config;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes32 private type1;
    bytes32 private source1;
    bytes32 private type2;
    bytes32 private source2;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockFdcHub = makeAddr("fdcHub");

        inflationConfigs = new FdcInflationConfigurations(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        // set contracts on fdc inflation configurations
        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FdcHub"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(mockFdcHub);
        inflationConfigs.updateContractAddresses(contractNameHashes, contractAddresses);

        type1 = bytes32("type1");
        source1 = bytes32("source1");
        type2 = bytes32("type2");
        source2 = bytes32("source2");
        vm.startPrank(governance);
    }

    function testAddConfigRevertTypeAndSourceNotSupported() public {
        _mockGetRequestFee(type1, source1, 0);
        config = IFdcInflationConfigurations.FdcConfiguration(
            type1, source1, 10000, 2, 0
        );
        vm.expectRevert("attestation type and source not supported");
        inflationConfigs.addFdcConfiguration(config);
    }


    function testAddFdcConfiguration() public {
        _mockGetRequestFee(type1, source1, 10);
        _mockGetRequestFee(type2, source2, 5);
        IFdcInflationConfigurations.FdcConfiguration[] memory fdcConfigurations;

        config = IFdcInflationConfigurations.FdcConfiguration(
            type1, source1, 10000, 2, 0
        );
        inflationConfigs.addFdcConfiguration(config);

        vm.expectRevert("invalid index");
        inflationConfigs.getFdcConfiguration(3);

        config = IFdcInflationConfigurations.FdcConfiguration(
            type2, source2, 5000, 5, 1
        );
        inflationConfigs.addFdcConfiguration(config);

        fdcConfigurations = inflationConfigs.getFdcConfigurations();
        assertEq(fdcConfigurations.length, 2);
        assertEq(fdcConfigurations[0].attestationType, type1);
        assertEq(fdcConfigurations[1].attestationType, type2);
        assertEq(fdcConfigurations[0].inflationShare, 10000);
        assertEq(fdcConfigurations[1].inflationShare, 5000);
        assertEq(fdcConfigurations[0].minRequestsThreshold, 2);
        assertEq(fdcConfigurations[1].minRequestsThreshold, 5);
        assertEq(fdcConfigurations[0].mode, 0);
        assertEq(fdcConfigurations[1].mode, 1);
    }

    function testReplaceFdcConfiguration() public {
        IFdcInflationConfigurations.FdcConfiguration memory getConfig;
        testAddFdcConfiguration();
         // replace fdc configuration on index 2 -> should revert if index is invalid
        config = IFdcInflationConfigurations.FdcConfiguration(
            type1, source2, 6000, 100, 3
        );
        vm.expectRevert("invalid index");
        inflationConfigs.replaceFdcConfiguration(2, config);

        // replace fdc configuration on index 1 -> should revert if type and source not supported
        _mockGetRequestFee(type1, source2, 0);
        vm.expectRevert("attestation type and source not supported");
        inflationConfigs.replaceFdcConfiguration(1, config);

        _mockGetRequestFee(type1, source2, 1);
        // replace fdc configuration on index 1
        getConfig = inflationConfigs.getFdcConfiguration(1);
        assertEq(getConfig.attestationType, type2);
        assertEq(getConfig.source, source2);
        assertEq(getConfig.inflationShare, 5000);
        assertEq(getConfig.minRequestsThreshold, 5);
        assertEq(getConfig.mode, 1);
        inflationConfigs.replaceFdcConfiguration(1, config);
        getConfig = inflationConfigs.getFdcConfiguration(1);
        assertEq(getConfig.attestationType, type1);
        assertEq(getConfig.source, source2);
        assertEq(getConfig.inflationShare, 6000);
        assertEq(getConfig.minRequestsThreshold, 100);
        assertEq(getConfig.mode, 3);
    }

    function testRemoveFdcConfiguration() public {
        IFdcInflationConfigurations.FdcConfiguration memory getConfig;
        IFdcInflationConfigurations.FdcConfiguration[] memory fdcConfigurations;
        testAddFdcConfiguration();
        // remove fdc configuration on index 2 -> should revert
        vm.expectRevert("invalid index");
        inflationConfigs.removeFdcConfiguration(2);

        // remove fdc configuration on index 0
        getConfig = inflationConfigs.getFdcConfiguration(0);
        assertEq(getConfig.attestationType, type1);
        inflationConfigs.removeFdcConfiguration(0);
        // configuration from index 1 is now on index 0
        getConfig = inflationConfigs.getFdcConfiguration(0);
        assertEq(getConfig.attestationType, type2);
        fdcConfigurations = inflationConfigs.getFdcConfigurations();
        assertEq(fdcConfigurations.length, 1);

        // remove new fdc configuration on index 0
        inflationConfigs.removeFdcConfiguration(0);
        fdcConfigurations = inflationConfigs.getFdcConfigurations();
        assertEq(fdcConfigurations.length, 0);
    }

    function _mockGetRequestFee(bytes32 _type, bytes32 _source, uint256 _fee) internal {
        vm.mockCall(
            mockFdcHub,
            abi.encodeWithSelector(IFdcHub.getRequestFee.selector, abi.encodePacked(_type, _source)),
            abi.encode(_fee)
        );
    }

}
