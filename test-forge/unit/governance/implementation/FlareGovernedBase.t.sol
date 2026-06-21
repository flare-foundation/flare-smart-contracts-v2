// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "forge-std/Test.sol";
import { FlareUpgradeableBase } from
    "../../../../contracts/governance/implementation/FlareUpgradeableBase.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { IIFlareGovernance } from "../../../../contracts/governance/interface/IIFlareGovernance.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * Minimal harness exercising the FlareGovernedBase public API on a non-Diamond
 * UUPS contract. Stores an integer that only governance can mutate.
 */
contract FlareGovernedBaseTestHarness is FlareUpgradeableBase {

    uint256 public value;

    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance
    )
        external
        initializer
    {
        initializeBase(_governanceSettings, _initialGovernance, address(0));
    }

    function setValue(
        uint256 _value
    )
        external
        onlyGovernance
    {
        value = _value;
    }

    function _updateContractAddresses(
        bytes32[] memory,
        address[] memory
    )
        internal pure override
    {
        // no inter-contract dependencies
    }
}


contract FlareGovernedBaseTest is Test {

    uint256 private constant TIMELOCK = 1 hours;

    FlareGovernedBaseTestHarness private harness;
    address private initialGovernance;
    address private productionGovernance;
    address private executor;
    IGovernanceSettings private governanceSettings;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        productionGovernance = makeAddr("productionGovernance");
        executor = makeAddr("executor");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));

        FlareGovernedBaseTestHarness impl = new FlareGovernedBaseTestHarness();
        bytes memory data = abi.encodeCall(impl.initialize, (governanceSettings, initialGovernance));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), data);
        harness = FlareGovernedBaseTestHarness(address(proxy));
    }

    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    function testGovernanceIsInitialGovernanceBeforeProductionMode() public view {
        assertEq(harness.governance(), initialGovernance);
        assertFalse(harness.productionMode());
        assertEq(address(harness.governanceSettings()), address(governanceSettings));
    }

    function testReinitializeRevertsAlreadyInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        harness.initialize(governanceSettings, initialGovernance);
    }

    function testLibraryGuardCatchesInPlaceUpgradeReinit() public {
        // Simulate an in-place UUPS upgrade to new bytecode that adds Initializable:
        // OZ's `_initialized` slot would be virgin (0) on the existing proxy, even
        // though the FlareGovernance state is already initialised. The library's
        // own `bool initialised` guard must catch the re-init attempt and revert
        // with the explicit IFlareGovernance.GovernedAlreadyInitialized error.
        // ozInitializableSlot is the ERC-7201 namespace for OZ's Initializable:
        // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1))
        //   & ~bytes32(uint256(0xff))
        bytes32 ozInitializableSlot =
            0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
        vm.store(address(harness), ozInitializableSlot, bytes32(0));

        vm.expectRevert(IFlareGovernance.GovernedAlreadyInitialized.selector);
        harness.initialize(governanceSettings, initialGovernance);
    }

    // -------------------------------------------------------------------------
    // onlyGovernance (immediate execution before production mode)
    // -------------------------------------------------------------------------

    function testOnlyGovernanceRevertsForNonGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        harness.setValue(42);
    }

    function testInitialGovernanceCanCallImmediately() public {
        vm.prank(initialGovernance);
        harness.setValue(42);
        assertEq(harness.value(), 42);
    }

    // -------------------------------------------------------------------------
    // switchToProductionMode
    // -------------------------------------------------------------------------

    function testSwitchToProductionModeRevertsForNonGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        harness.switchToProductionMode();
    }

    function testSwitchToProductionModeEmitsEventAndFlipsFlag() public {
        vm.expectEmit(true, true, true, true, address(harness));
        emit IFlareGovernance.GovernedProductionModeEntered(address(governanceSettings));
        vm.prank(initialGovernance);
        harness.switchToProductionMode();
        assertTrue(harness.productionMode());
    }

    function testSwitchToProductionModeRevertsTwice() public {
        vm.prank(initialGovernance);
        harness.switchToProductionMode();
        _mockProductionGovernance();
        vm.expectRevert(IFlareGovernance.AlreadyInProductionMode.selector);
        vm.prank(productionGovernance);
        harness.switchToProductionMode();
    }

    // -------------------------------------------------------------------------
    // Hash-based timelocked governance (production mode)
    // -------------------------------------------------------------------------

    function testTimelockedCallRecordedAndExecuted() public {
        _switchToProduction();

        bytes memory call = abi.encodeCall(harness.setValue, (123));
        bytes32 callHash = keccak256(call);

        // Call setValue as the production governance — under production mode this
        // records a timelocked call instead of executing immediately.
        vm.expectEmit(true, true, true, true, address(harness));
        emit IFlareGovernance.GovernanceCallTimelocked(call, callHash, vm.getBlockTimestamp() + TIMELOCK);
        vm.prank(productionGovernance);
        (bool ok,) = address(harness).call(call);
        assertTrue(ok);
        assertEq(harness.value(), 0, "must not execute immediately");

        // Try to execute before timelock has passed.
        _mockIsExecutor(executor, true);
        vm.expectRevert(IFlareGovernance.TimelockNotAllowedYet.selector);
        vm.prank(executor);
        IFlareGovernance(address(harness)).executeGovernanceCall(call);

        // Advance time and execute.
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.expectEmit(true, true, true, true, address(harness));
        emit IFlareGovernance.TimelockedGovernanceCallExecuted(callHash);
        vm.prank(executor);
        IFlareGovernance(address(harness)).executeGovernanceCall(call);
        assertEq(harness.value(), 123);
    }

    function testExecuteRevertsForNonExecutor() public {
        _switchToProduction();
        bytes memory call = abi.encodeCall(harness.setValue, (1));
        vm.prank(productionGovernance);
        (bool ok,) = address(harness).call(call);
        assertTrue(ok);

        _mockIsExecutor(executor, false);
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.expectRevert(IFlareGovernance.OnlyExecutor.selector);
        vm.prank(executor);
        IFlareGovernance(address(harness)).executeGovernanceCall(call);
    }

    function testExecuteRevertsForUnrecordedCall() public {
        _switchToProduction();
        _mockIsExecutor(executor, true);
        bytes memory call = abi.encodeCall(harness.setValue, (7));
        vm.expectRevert(IFlareGovernance.TimelockCallNotFound.selector);
        vm.prank(executor);
        IFlareGovernance(address(harness)).executeGovernanceCall(call);
    }

    function testCancelGovernanceCall() public {
        _switchToProduction();
        bytes memory call = abi.encodeCall(harness.setValue, (9));
        bytes32 callHash = keccak256(call);

        vm.prank(productionGovernance);
        (bool ok,) = address(harness).call(call);
        assertTrue(ok);

        vm.expectEmit(true, true, true, true, address(harness));
        emit IFlareGovernance.TimelockedGovernanceCallCanceled(callHash);
        vm.prank(productionGovernance);
        IIFlareGovernance(address(harness)).cancelGovernanceCall(call);

        // After cancel, execute should revert with TimelockCallNotFound.
        _mockIsExecutor(executor, true);
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.expectRevert(IFlareGovernance.TimelockCallNotFound.selector);
        vm.prank(executor);
        IFlareGovernance(address(harness)).executeGovernanceCall(call);
    }

    function testCancelRevertsForUnrecordedCall() public {
        _switchToProduction();
        bytes memory call = abi.encodeCall(harness.setValue, (99));
        vm.expectRevert(IFlareGovernance.TimelockCallNotFound.selector);
        vm.prank(productionGovernance);
        IIFlareGovernance(address(harness)).cancelGovernanceCall(call);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _switchToProduction() private {
        vm.prank(initialGovernance);
        harness.switchToProductionMode();
        _mockProductionGovernance();
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getTimelock.selector),
            abi.encode(TIMELOCK)
        );
    }

    function _mockProductionGovernance() private {
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getGovernanceAddress.selector),
            abi.encode(productionGovernance)
        );
    }

    function _mockIsExecutor(
        address _executor,
        bool _isExecutor
    )
        private
    {
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.isExecutor.selector, _executor),
            abi.encode(_isExecutor)
        );
    }
}
