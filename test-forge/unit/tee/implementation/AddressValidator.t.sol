// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Test } from "forge-std/Test.sol";
import { AddressValidator } from "../../../../contracts/tee/implementation/AddressValidator.sol";
import { AddressValidatorProxy } from "../../../../contracts/tee/proxy/AddressValidatorProxy.sol";
import { IAddressValidator } from "../../../../contracts/userInterfaces/tee/IAddressValidator.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract AddressValidatorTest is Test {

    bytes32 private constant SRC_BTC = bytes32("BTC");
    bytes32 private constant SRC_DOGE = bytes32("DOGE");
    bytes32 private constant SRC_XRP = bytes32("XRP");
    bytes32 private constant SRC_ETH = bytes32("ETH");
    bytes32 private constant SRC_UNCONFIGURED = bytes32("NOPE");

    string private constant BTC_MAIN = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4";
    string private constant DOGE_MAIN = "DFpN6QqFfUm3gKNaxN6tNcab1FArL9cZLE";
    string private constant XRP_CLASSIC = "rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpf";
    string private constant XRP_XADDR_MAIN = "XVLhHMPHU98es4dbozjVtdWzVrDjtVoUhWS5SgMMoLoBzqQ";
    string private constant XRP_XADDR_TEST = "TVE26TYGhfLC7tQDno7G8dGtxSkYQnTNrgQwkM2tPvGzJRR";
    string private constant EVM_CHK = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed";

    AddressValidator private validator;
    address private governance;

    function setUp() public {
        governance = makeAddr("governance");
        AddressValidator impl = new AddressValidator();
        AddressValidatorProxy proxy = new AddressValidatorProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            makeAddr("addressUpdater"),
            address(impl)
        );
        validator = AddressValidator(address(proxy));

        IAddressValidator.SourceConfig[] memory configs = new IAddressValidator.SourceConfig[](4);
        configs[0] = IAddressValidator.SourceConfig(
            SRC_BTC, IAddressValidator.ChainKind.Bitcoin, IAddressValidator.Network.Mainnet);
        configs[1] = IAddressValidator.SourceConfig(
            SRC_DOGE, IAddressValidator.ChainKind.Dogecoin, IAddressValidator.Network.Mainnet);
        configs[2] = IAddressValidator.SourceConfig(
            SRC_XRP, IAddressValidator.ChainKind.Xrpl, IAddressValidator.Network.Mainnet);
        configs[3] = IAddressValidator.SourceConfig(
            SRC_ETH, IAddressValidator.ChainKind.Evm, IAddressValidator.Network.Mainnet);
        vm.prank(governance);
        validator.setSourceConfigs(configs);
    }

    function testDispatchesPerChain() public view {
        assertTrue(validator.isValidAddress(SRC_BTC, BTC_MAIN));
        assertTrue(validator.isValidAddress(SRC_DOGE, DOGE_MAIN));
        assertTrue(validator.isValidAddress(SRC_XRP, XRP_CLASSIC));
        assertTrue(validator.isValidAddress(SRC_ETH, EVM_CHK));
    }

    function testRejectsCrossChainAddress() public view {
        // A Bitcoin address is not valid for the Dogecoin source, and vice-versa.
        assertFalse(validator.isValidAddress(SRC_DOGE, BTC_MAIN));
        assertFalse(validator.isValidAddress(SRC_BTC, DOGE_MAIN));
        assertFalse(validator.isValidAddress(SRC_BTC, XRP_CLASSIC));
    }

    function testEnforcesNetwork() public {
        // Reconfigure BTC source as testnet: a mainnet address must now be rejected.
        IAddressValidator.SourceConfig[] memory configs = new IAddressValidator.SourceConfig[](1);
        configs[0] = IAddressValidator.SourceConfig(
            SRC_BTC, IAddressValidator.ChainKind.Bitcoin, IAddressValidator.Network.Testnet);
        vm.prank(governance);
        validator.setSourceConfigs(configs);
        assertFalse(validator.isValidAddress(SRC_BTC, BTC_MAIN));
        assertTrue(validator.isValidAddress(SRC_BTC, "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"));
    }

    function testUnconfiguredSourceFailsClosed() public view {
        assertFalse(validator.isValidAddress(SRC_UNCONFIGURED, BTC_MAIN));
        (, , bool configured) = validator.getSourceConfig(SRC_UNCONFIGURED);
        assertTrue(!configured);
    }

    function testXrplXAddressNetworkEnforced() public {
        // XRP source configured as mainnet (setUp): classic accepted, X-mainnet accepted,
        // X-testnet rejected.
        assertTrue(validator.isValidAddress(SRC_XRP, XRP_CLASSIC));
        assertTrue(validator.isValidAddress(SRC_XRP, XRP_XADDR_MAIN));
        assertFalse(validator.isValidAddress(SRC_XRP, XRP_XADDR_TEST));

        // Reconfigure XRP source as testnet: X-testnet accepted, X-mainnet rejected, classic still
        // accepted (classic addresses carry no network).
        IAddressValidator.SourceConfig[] memory configs = new IAddressValidator.SourceConfig[](1);
        configs[0] = IAddressValidator.SourceConfig(
            SRC_XRP, IAddressValidator.ChainKind.Xrpl, IAddressValidator.Network.Testnet);
        vm.prank(governance);
        validator.setSourceConfigs(configs);
        assertTrue(validator.isValidAddress(SRC_XRP, XRP_XADDR_TEST));
        assertFalse(validator.isValidAddress(SRC_XRP, XRP_XADDR_MAIN));
        assertTrue(validator.isValidAddress(SRC_XRP, XRP_CLASSIC));
    }

    function testGetSourceConfig() public view {
        (IAddressValidator.ChainKind kind, IAddressValidator.Network network, bool configured) =
            validator.getSourceConfig(SRC_BTC);
        assertEq(uint8(kind), uint8(IAddressValidator.ChainKind.Bitcoin));
        assertEq(uint8(network), uint8(IAddressValidator.Network.Mainnet));
        assertTrue(configured);
    }

    function testSetSourceConfigsOnlyGovernance() public {
        IAddressValidator.SourceConfig[] memory configs = new IAddressValidator.SourceConfig[](1);
        configs[0] = IAddressValidator.SourceConfig(
            SRC_BTC, IAddressValidator.ChainKind.Bitcoin, IAddressValidator.Network.Mainnet);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        vm.prank(makeAddr("notGovernance"));
        validator.setSourceConfigs(configs);
    }

    function testSetSourceConfigsEmptyReverts() public {
        IAddressValidator.SourceConfig[] memory configs = new IAddressValidator.SourceConfig[](0);
        vm.expectRevert(IAddressValidator.EmptyArray.selector);
        vm.prank(governance);
        validator.setSourceConfigs(configs);
    }

    function testSetSourceConfigsEmitsEvent() public {
        IAddressValidator.SourceConfig[] memory configs = new IAddressValidator.SourceConfig[](1);
        configs[0] = IAddressValidator.SourceConfig(
            SRC_ETH, IAddressValidator.ChainKind.Evm, IAddressValidator.Network.Mainnet);
        vm.expectEmit();
        emit IAddressValidator.SourceConfigSet(
            SRC_ETH, IAddressValidator.ChainKind.Evm, IAddressValidator.Network.Mainnet);
        vm.prank(governance);
        validator.setSourceConfigs(configs);
    }
}
