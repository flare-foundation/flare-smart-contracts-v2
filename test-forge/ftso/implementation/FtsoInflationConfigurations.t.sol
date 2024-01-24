// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/ftso/implementation/FtsoInflationConfigurations.sol";

contract FtsoInflationConfigurationsTest is Test {

    FtsoInflationConfigurations private inflationConfigs;
    address private governance;

    IFtsoInflationConfigurations.FtsoConfiguration private config;
    bytes private feeds;
    bytes8 private feed1;
    bytes8 private feed2;
    bytes private secondaryBands;

    uint16 internal constant MAX_BIPS = 1e4;

    function setUp() public {
        governance = makeAddr("governance");
        inflationConfigs = new FtsoInflationConfigurations(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance
        );

        feed1 = bytes8("feed1");
        feed2 = bytes8("feed2");
        feeds = bytes.concat(feed1, feed2);
        secondaryBands = bytes.concat(bytes3(uint24(10000)), bytes3(uint24(20000)));
        vm.startPrank(governance);
    }

    function testAddConfigRevertInvalidThreshold() public {
        config = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds,
            10,
            MAX_BIPS + 1,
            3000000,
            secondaryBands,
            0
        );
        vm.expectRevert("invalid minRewardedTurnoutBIPS value");
        inflationConfigs.addFtsoConfiguration(config);
    }

    function testAddConfigRevertInvalidPrimary() public {
        config = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds,
            10,
            5000,
            3000000,
            secondaryBands,
            0
        );
        vm.expectRevert("invalid primaryBandRewardSharePPM value");
        inflationConfigs.addFtsoConfiguration(config);
    }

    function testAddConfigRevertInvalidFeedNamesLength() public {
        feeds = bytes.concat(feed1, feed2, bytes9("feed3"));
        config = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds,
            10,
            5000,
            30000,
            secondaryBands,
            0
        );
        vm.expectRevert("invalid feedNames length");
        inflationConfigs.addFtsoConfiguration(config);
    }

    function testAddConfigRevertInvalidSecondaryLength() public {
        secondaryBands = bytes.concat(bytes3(uint24(10000)), bytes4(uint32(20000)));
        config = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds,
            10,
            5000,
            30000,
            secondaryBands,
            0
        );
        vm.expectRevert("invalid secondaryBandWidthPPMs length");
        inflationConfigs.addFtsoConfiguration(config);
    }

    function testAddConfigRevertLengthsDontMatch() public {
        secondaryBands = bytes.concat(bytes3(uint24(10000)), bytes3(uint24(20000)), bytes3(uint24(20000)));
        config = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds,
            10,
            5000,
            30000,
            secondaryBands,
            0
        );
        vm.expectRevert("array lengths do not match");
        inflationConfigs.addFtsoConfiguration(config);
    }

    function testAddConfigRevertSecondaryValueInvalid() public {
        secondaryBands = bytes.concat(bytes3(uint24(10000)), bytes3(uint24(2000000)));
        config = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds,
            10,
            5000,
            30000,
            secondaryBands,
            0
        );
        vm.expectRevert("invalid secondaryBandWidthPPMs value");
        inflationConfigs.addFtsoConfiguration(config);
    }

    function testAddFtsoConfiguration() public {
        IFtsoInflationConfigurations.FtsoConfiguration[] memory ftsoConfigurations;

        config = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds,
            10,
            5000,
            30000,
            secondaryBands,
            0
        );
        inflationConfigs.addFtsoConfiguration(config);

        vm.expectRevert("invalid index");
        inflationConfigs.getFtsoConfiguration(3);

        feeds = bytes.concat(bytes8("feed3"), bytes8("feed4"));
        config = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds,
            10,
            6000,
            40000,
            secondaryBands,
            0
        );
        inflationConfigs.addFtsoConfiguration(config);

        ftsoConfigurations = inflationConfigs.getFtsoConfigurations();
        assertEq(ftsoConfigurations.length, 2);
        assertEq(ftsoConfigurations[1].feedNames, feeds);
        assertEq(ftsoConfigurations[0].minRewardedTurnoutBIPS, 5000);
        assertEq(ftsoConfigurations[1].minRewardedTurnoutBIPS, 6000);
        assertEq(ftsoConfigurations[0].primaryBandRewardSharePPM, 30000);
        assertEq(ftsoConfigurations[1].primaryBandRewardSharePPM, 40000);
    }

    function testReplaceFtsoConfiguration() public {
        IFtsoInflationConfigurations.FtsoConfiguration memory getConfig;
        testAddFtsoConfiguration();
         // replace ftso configuration on index 2 -> should revert
        config = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds,
            10,
            8000,
            50000,
            secondaryBands,
            0
        );
        vm.expectRevert("invalid index");
        inflationConfigs.replaceFtsoConfiguration(2, config);

        // replace ftso configuration on index 1
        getConfig = inflationConfigs.getFtsoConfiguration(1);
        assertEq(getConfig.minRewardedTurnoutBIPS, 6000);
        assertEq(getConfig.primaryBandRewardSharePPM, 40000);
        inflationConfigs.replaceFtsoConfiguration(1, config);
        getConfig = inflationConfigs.getFtsoConfiguration(1);
        assertEq(getConfig.minRewardedTurnoutBIPS, 8000);
        assertEq(getConfig.primaryBandRewardSharePPM, 50000);
    }

    function testRemoveFtsoConfiguration() public {
        IFtsoInflationConfigurations.FtsoConfiguration memory getConfig;
        IFtsoInflationConfigurations.FtsoConfiguration[] memory ftsoConfigurations;
        testAddFtsoConfiguration();
        // remove ftso configuration on index 2 -> should revert
        vm.expectRevert("invalid index");
        inflationConfigs.removeFtsoConfiguration(2);

        // remove ftso configuration on index 0
        getConfig = inflationConfigs.getFtsoConfiguration(0);
        assertEq(getConfig.primaryBandRewardSharePPM, 30000);
        inflationConfigs.removeFtsoConfiguration(0);
        // configuration from index 1 is now on index 0
        getConfig = inflationConfigs.getFtsoConfiguration(0);
        assertEq(getConfig.primaryBandRewardSharePPM, 40000);
        ftsoConfigurations = inflationConfigs.getFtsoConfigurations();
        assertEq(ftsoConfigurations.length, 1);

        // remove new ftso configuration on index 0
        inflationConfigs.removeFtsoConfiguration(0);
        ftsoConfigurations = inflationConfigs.getFtsoConfigurations();
        assertEq(ftsoConfigurations.length, 0);
    }

}
