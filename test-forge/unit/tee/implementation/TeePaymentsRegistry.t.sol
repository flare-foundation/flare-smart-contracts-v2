// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeePaymentsRegistry } from "../../../../contracts/tee/implementation/TeePaymentsRegistry.sol";
import { TeePaymentsRegistryProxy } from "../../../../contracts/tee/proxy/TeePaymentsRegistryProxy.sol";
import { ITeePaymentsRegistry } from "../../../../contracts/userInterfaces/tee/ITeePaymentsRegistry.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";

contract TeePaymentsRegistryTest is Test {

    bytes32 private constant SOURCE_ID_1 = bytes32("XRP");
    bytes32 private constant SOURCE_ID_2 = bytes32("BTC");
    bytes32 private constant SOURCE_ID_3 = bytes32("ETH");

    TeePaymentsRegistry private registry;
    TeePaymentsRegistry private registryImpl;

    address private governance;
    address private addressUpdater;
    address private teePaymentsA;
    address private teePaymentsB;
    address private otherUser;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        teePaymentsA = makeAddr("teePaymentsA");
        teePaymentsB = makeAddr("teePaymentsB");
        otherUser = makeAddr("otherUser");
        // Registry enforces that teePayments address has deployed code (not EOA).
        vm.etch(teePaymentsA, hex"01");
        vm.etch(teePaymentsB, hex"01");

        registryImpl = new TeePaymentsRegistry();
        TeePaymentsRegistryProxy proxy = new TeePaymentsRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(registryImpl)
        );
        registry = TeePaymentsRegistry(address(proxy));
    }

    //// registerSources ////
    function testRegisterSourcesGovernanceOnly() public {
        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_1, teePaymentsA);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        registry.registerSources(inputs);
    }

    function testRegisterSourcesNewSourceId() public {
        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_1, teePaymentsA);
        vm.expectEmit();
        emit ITeePaymentsRegistry.SourcesRegistered(inputs);
        vm.prank(governance);
        registry.registerSources(inputs);

        assertEq(registry.getTeePaymentsForSource(SOURCE_ID_1), teePaymentsA);
        assertTrue(registry.isSourceRegistered(SOURCE_ID_1));
        assertEq(registry.getRegisteredSourceIds().length, 1);
        assertEq(registry.getRegisteredSourceIds()[0], SOURCE_ID_1);
        address[] memory contracts = registry.getRegisteredTeePaymentsContracts();
        assertEq(contracts.length, 1);
        assertEq(contracts[0], teePaymentsA);
        bytes32[] memory reverseLookup = registry.getSourceIdsForTeePayments(teePaymentsA);
        assertEq(reverseLookup.length, 1);
        assertEq(reverseLookup[0], SOURCE_ID_1);
    }

    function testRegisterSourcesMultiple() public {
        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](3);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_1, teePaymentsA);
        inputs[1] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_2, teePaymentsA);
        inputs[2] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_3, teePaymentsB);
        vm.prank(governance);
        registry.registerSources(inputs);

        assertEq(registry.getRegisteredSourceIds().length, 3);
        assertEq(registry.getRegisteredTeePaymentsContracts().length, 2);
        bytes32[] memory aSources = registry.getSourceIdsForTeePayments(teePaymentsA);
        assertEq(aSources.length, 2);
        bytes32[] memory bSources = registry.getSourceIdsForTeePayments(teePaymentsB);
        assertEq(bSources.length, 1);
        assertEq(bSources[0], SOURCE_ID_3);
    }

    function testRegisterSourcesRevertAlreadyRegistered() public {
        testRegisterSourcesNewSourceId();

        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_1, teePaymentsB);
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeePaymentsRegistry.SourceAlreadyRegistered.selector,
                SOURCE_ID_1,
                teePaymentsA
            )
        );
        registry.registerSources(inputs);
    }

    function testRegisterSourcesRevertAlreadyRegisteredSameAddress() public {
        testRegisterSourcesNewSourceId();

        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_1, teePaymentsA);
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeePaymentsRegistry.SourceAlreadyRegistered.selector,
                SOURCE_ID_1,
                teePaymentsA
            )
        );
        registry.registerSources(inputs);
    }

    function testRebindViaUnregisterThenRegister() public {
        testRegisterSourcesNewSourceId();

        bytes32[] memory remove = new bytes32[](1);
        remove[0] = SOURCE_ID_1;
        vm.prank(governance);
        registry.unregisterSources(remove);

        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_1, teePaymentsB);
        vm.expectEmit();
        emit ITeePaymentsRegistry.SourcesRegistered(inputs);
        vm.prank(governance);
        registry.registerSources(inputs);

        assertEq(registry.getTeePaymentsForSource(SOURCE_ID_1), teePaymentsB);
        address[] memory contracts = registry.getRegisteredTeePaymentsContracts();
        assertEq(contracts.length, 1);
        assertEq(contracts[0], teePaymentsB);
        assertEq(registry.getSourceIdsForTeePayments(teePaymentsA).length, 0);
        assertEq(registry.getSourceIdsForTeePayments(teePaymentsB).length, 1);
    }

    function testRegisterSourcesRevertSourceIdZero() public {
        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(bytes32(0), teePaymentsA);
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeePaymentsRegistry.SourceIdZero.selector,
                0
            )
        );
        registry.registerSources(inputs);
    }

    function testRegisterSourcesRevertTeePaymentsZero() public {
        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_1, address(0));
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeePaymentsRegistry.TeePaymentsNotContract.selector,
                address(0)
            )
        );
        registry.registerSources(inputs);
    }

    function testRegisterSourcesRevertTeePaymentsEoa() public {
        // EOA (address with no code) — `makeAddr` returns an EOA.
        address eoa = makeAddr("notAContract");
        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID_1, eoa);
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(ITeePaymentsRegistry.TeePaymentsNotContract.selector, eoa)
        );
        registry.registerSources(inputs);
    }

    //// unregisterSources ////
    function testUnregisterSources() public {
        testRegisterSourcesMultiple();

        bytes32[] memory remove = new bytes32[](1);
        remove[0] = SOURCE_ID_3;
        vm.expectEmit();
        emit ITeePaymentsRegistry.SourcesUnregistered(remove);
        vm.prank(governance);
        registry.unregisterSources(remove);

        assertEq(registry.getTeePaymentsForSource(SOURCE_ID_3), address(0));
        assertFalse(registry.isSourceRegistered(SOURCE_ID_3));
        // teePaymentsB had only SOURCE_ID_3 — pruned from distinct-contracts set
        address[] memory contracts = registry.getRegisteredTeePaymentsContracts();
        assertEq(contracts.length, 1);
        assertEq(contracts[0], teePaymentsA);
        assertEq(registry.getSourceIdsForTeePayments(teePaymentsB).length, 0);
    }

    function testUnregisterSourcesRevertNotRegistered() public {
        bytes32[] memory remove = new bytes32[](1);
        remove[0] = SOURCE_ID_1;
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(ITeePaymentsRegistry.SourceNotRegistered.selector, SOURCE_ID_1)
        );
        registry.unregisterSources(remove);
    }

    function testUnregisterSourcesGovernanceOnly() public {
        testRegisterSourcesNewSourceId();
        bytes32[] memory remove = new bytes32[](1);
        remove[0] = SOURCE_ID_1;
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        registry.unregisterSources(remove);
    }

    //// getTeePaymentsForSource ////
    function testGetTeePaymentsForSourceReturnsZeroForUnknown() public view {
        assertEq(registry.getTeePaymentsForSource(SOURCE_ID_1), address(0));
    }

    //// isSourceRegistered ////
    function testIsSourceRegistered() public {
        assertFalse(registry.isSourceRegistered(SOURCE_ID_1));
        testRegisterSourcesNewSourceId();
        assertTrue(registry.isSourceRegistered(SOURCE_ID_1));
        assertFalse(registry.isSourceRegistered(SOURCE_ID_2));
    }

    //// getSourceIdsForTeePayments ////
    function testGetSourceIdsForTeePayments() public {
        testRegisterSourcesMultiple();
        bytes32[] memory sources = registry.getSourceIdsForTeePayments(teePaymentsA);
        assertEq(sources.length, 2);
        // EnumerableSet preserves insertion order (approximately); just verify presence.
        bool has1 = (sources[0] == SOURCE_ID_1 || sources[1] == SOURCE_ID_1);
        bool has2 = (sources[0] == SOURCE_ID_2 || sources[1] == SOURCE_ID_2);
        assertTrue(has1);
        assertTrue(has2);
    }

    //// getRegisteredSourceIds and getRegisteredTeePaymentsContracts ////
    function testGetRegisteredSourceIds() public {
        testRegisterSourcesMultiple();
        bytes32[] memory sources = registry.getRegisteredSourceIds();
        assertEq(sources.length, 3);
    }

    function testGetRegisteredTeePaymentsContracts() public {
        testRegisterSourcesMultiple();
        address[] memory contracts = registry.getRegisteredTeePaymentsContracts();
        assertEq(contracts.length, 2);
    }

    //// Upgrade ////
    function testUpgradeProxy() public {
        assertEq(registry.implementation(), address(registryImpl));
        TeePaymentsRegistry newImpl = new TeePaymentsRegistry();
        vm.prank(governance);
        registry.upgradeToAndCall(address(newImpl), bytes(""));
        assertEq(registry.implementation(), address(newImpl));
    }

    function testUpgradeProxyRevertOnlyGovernance() public {
        TeePaymentsRegistry newImpl = new TeePaymentsRegistry();
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        registry.upgradeToAndCall(address(newImpl), bytes(""));
    }

}
