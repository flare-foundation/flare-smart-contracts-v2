// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";
import {RelayProxy} from "../../../contracts/protocol/implementation/RelayProxy.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {IIRelay} from "../../../contracts/protocol/interface/IIRelay.sol";
import {IOwnableWithTimelock} from "../../../contracts/userInterfaces/IOwnableWithTimelock.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// V2 implementation for migration tests: carries a guarded reinitializer-style entry point
/// (owner-or-self, per the IOwnableWithTimelock guidance) and a probe selector.
contract RelayV2Mock is Relay {
    uint256 public newField;

    function initializeV2(uint256 _value) external {
        // solhint-disable-next-line gas-custom-errors, custom-errors
        require(msg.sender == address(this) || msg.sender == owner(), "only owner or self");
        newField = _value;
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}

/// V2 implementation whose migration tries to ride the consumed `executing` flag into a
/// second guarded call (must fail: the flag is single-use).
contract RelayNestedMigrationMock is Relay {
    function initializeV2(address _account) external {
        IIRelay.FeeExemption[] memory exemptions = new IIRelay.FeeExemption[](1);
        exemptions[0] = IIRelay.FeeExemption(_account, true);
        // External self-call: msg.sender becomes the proxy, executing is already consumed.
        this.setFeeExemptions(exemptions);
    }
}

/**
 * Owner-timelock semantics of Relay's OwnableWithTimelock base, with Relay's guarded
 * functions — the fee setters, upgradeToAndCall, setTimelockDuration and transferOwnership —
 * as the timelocked surface.
 * The test contract is the Relay owner, so guarded calls are direct.
 */
contract RelayOwnableWithTimelockTest is Test {
    uint256 internal constant TIMELOCK = 1 days;

    Relay internal relay;
    Relay internal relayImplementation;

    function setUp() public {
        relayImplementation = new Relay();
        // Relay mode (no signing-policy setter) so the fee setters are live; owner = this.
        relay = Relay(
            address(
                new RelayProxy(
                    address(relayImplementation),
                    _relayConfig(0),
                    address(0),
                    IRelay(address(0)),
                    address(this)
                )
            )
        );
    }

    // ── Duration management ───────────────────────────────────────────────────

    function test_timelockDurationInitiallyZero() public view {
        assertEq(relay.getTimelockDurationSeconds(), 0);
    }

    function test_initializeSeedsTimelockDuration() public {
        Relay seeded = _deployRelay(_relayConfig(TIMELOCK));
        assertEq(seeded.getTimelockDurationSeconds(), TIMELOCK);
    }

    function test_initializeRevertsTimelockDurationTooLong() public {
        IRelay.RelayInitialConfig memory cfg = _relayConfig(7 days + 1);
        vm.expectRevert(IOwnableWithTimelock.TimelockDurationTooLong.selector);
        new RelayProxy(address(relayImplementation), cfg, address(0), IRelay(address(0)), address(this));
    }

    function test_setTimelockDurationDirectWhenZero() public {
        // With duration 0 the timelock is off, so the call executes directly.
        relay.setTimelockDuration(TIMELOCK);
        assertEq(relay.getTimelockDurationSeconds(), TIMELOCK);
    }

    function test_setTimelockDurationRevertTooLong() public {
        vm.expectRevert(IOwnableWithTimelock.TimelockDurationTooLong.selector);
        relay.setTimelockDuration(7 days + 1);
    }

    function test_setTimelockDurationRevertNonOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(0xBEEF))
        );
        relay.setTimelockDuration(TIMELOCK);
    }

    function test_setTimelockDurationQueuedOnceActive() public {
        relay.setTimelockDuration(TIMELOCK);

        // Changing the duration is itself timelocked now.
        relay.setTimelockDuration(2 days);
        assertEq(relay.getTimelockDurationSeconds(), TIMELOCK, "applied without delay");

        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        relay.executeTimelockedCall(abi.encodeCall(relay.setTimelockDuration, (2 days)));
        assertEq(relay.getTimelockDurationSeconds(), 2 days);
    }

    function test_supersededTimelockDurationCallsExecuteInAnyOrder() public {
        // Two matured setTimelockDuration queues stay independently executable in arbitrary
        // order — the superseded one can still be executed last (runbook: cancel superseded
        // queues).
        uint256 start = vm.getBlockTimestamp();
        relay.setTimelockDuration(TIMELOCK);

        bytes memory toTwoDays = abi.encodeCall(relay.setTimelockDuration, (2 days));
        bytes memory toThreeDays = abi.encodeCall(relay.setTimelockDuration, (3 days));
        relay.setTimelockDuration(2 days); // queues
        relay.setTimelockDuration(3 days); // queues

        vm.warp(start + TIMELOCK);
        relay.executeTimelockedCall(toThreeDays);
        assertEq(relay.getTimelockDurationSeconds(), 3 days);

        // The older, superseded intent still applies afterwards.
        relay.executeTimelockedCall(toTwoDays);
        assertEq(relay.getTimelockDurationSeconds(), 2 days, "superseded queue was not executable");
    }

    // ── Ownership transfer ────────────────────────────────────────────────────

    function test_transferOwnershipDirectWhenZero() public {
        // Duration 0: applies immediately, like every other guarded setter.
        relay.transferOwnership(address(0xA11CE));
        assertEq(relay.owner(), address(0xA11CE));
    }

    function test_transferOwnershipRevertZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        relay.transferOwnership(address(0));
    }

    function test_transferOwnershipRevertNonOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(0xBEEF))
        );
        relay.transferOwnership(address(0xA11CE));
    }

    // The point of the change: with the timelock armed, taking the owner role is no longer a
    // single atomic transaction — it queues publicly and waits like everything else.
    function test_transferOwnershipQueuedOnceActive() public {
        relay.setTimelockDuration(TIMELOCK);

        relay.transferOwnership(address(0xA11CE));
        assertEq(relay.owner(), address(this), "ownership moved without the delay");

        bytes memory call = abi.encodeCall(relay.transferOwnership, (address(0xA11CE)));
        assertEq(relay.getExecuteTimelockedCallTimestamp(call), vm.getBlockTimestamp() + TIMELOCK);

        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        relay.executeTimelockedCall(call);
        assertEq(relay.owner(), address(0xA11CE), "ownership did not move on execution");
    }

    // Cancelling is what the waiting window is for.
    function test_transferOwnershipQueueCanBeCancelled() public {
        relay.setTimelockDuration(TIMELOCK);
        relay.transferOwnership(address(0xA11CE));

        bytes memory call = abi.encodeCall(relay.transferOwnership, (address(0xA11CE)));
        relay.cancelTimelockedCall(call);

        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.expectRevert(IOwnableWithTimelock.TimelockInvalidSelector.selector);
        relay.executeTimelockedCall(call);
        assertEq(relay.owner(), address(this), "cancelled transfer still applied");
    }

    // After the transfer the role really has moved: the new owner governs, the old one cannot.
    function test_transferOwnershipMovesTheOwnerRole() public {
        relay.setTimelockDuration(TIMELOCK);
        relay.transferOwnership(address(0xA11CE));
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        relay.executeTimelockedCall(abi.encodeCall(relay.transferOwnership, (address(0xA11CE))));

        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this))
        );
        relay.setTimelockDuration(2 days);

        vm.prank(address(0xA11CE));
        relay.setTimelockDuration(2 days); // queues under the new owner
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        relay.executeTimelockedCall(abi.encodeCall(relay.setTimelockDuration, (2 days)));
        assertEq(relay.getTimelockDurationSeconds(), 2 days);
    }

    // A zero target is only rejected when the queued call executes — queueing validates nothing,
    // exactly as for every other guarded setter.
    function test_transferOwnershipZeroAddressRejectedAtExecution() public {
        relay.setTimelockDuration(TIMELOCK);
        relay.transferOwnership(address(0)); // queues without complaint

        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        relay.executeTimelockedCall(abi.encodeCall(relay.transferOwnership, (address(0))));
        assertEq(relay.owner(), address(this));
    }

    // ── Queue / execute / cancel ──────────────────────────────────────────────

    function test_setterRevertNonOwnerWhenTimelockActive() public {
        // With the timelock armed, even queueing must be owner-only.
        relay.setTimelockDuration(TIMELOCK);
        vm.prank(address(0xBEEF));
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(0xBEEF))
        );
        relay.setFeeExemptions(_exemptions(address(0xDA0), true));
    }

    function test_setFeeExemptionsTimelockQueueAndExecute() public {
        relay.setTimelockDuration(TIMELOCK);
        bytes memory encodedCall =
            abi.encodeCall(relay.setFeeExemptions, (_exemptions(address(0xDA0), true)));

        // The owner's call only queues.
        vm.expectEmit(true, true, true, true);
        emit IOwnableWithTimelock.CallTimelocked(
            encodedCall,
            keccak256(encodedCall),
            vm.getBlockTimestamp() + TIMELOCK
        );
        relay.setFeeExemptions(_exemptions(address(0xDA0), true));

        assertFalse(relay.feeExemptAddress(address(0xDA0)), "exemption applied without delay");
        assertEq(
            relay.getExecuteTimelockedCallTimestamp(encodedCall),
            vm.getBlockTimestamp() + TIMELOCK
        );

        // After the delay anyone can execute.
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.expectEmit(true, true, true, true);
        emit IRelay.FeeExemptionSet(address(0xDA0), true);
        vm.expectEmit(true, true, true, true);
        emit IOwnableWithTimelock.TimelockedCallExecuted(keccak256(encodedCall));
        vm.prank(address(0xD00D));
        relay.executeTimelockedCall(encodedCall);

        assertTrue(relay.feeExemptAddress(address(0xDA0)), "exemption not applied after execute");
    }

    function test_setProtocolFeesTimelockQueueAndExecuteTokenAtomically() public {
        // Fee token and fee table travel in ONE queued call, so the token switch and the
        // re-denominated fees become visible in the same executeTimelockedCall.
        relay.setTimelockDuration(TIMELOCK);
        IRelay.FeeConfig[] memory fees = new IRelay.FeeConfig[](1);
        fees[0] = IRelay.FeeConfig(3, 5_000_000);
        bytes memory encodedCall = abi.encodeCall(relay.setProtocolFees, (address(0x70CE2), fees));

        // The owner's call only queues.
        vm.expectEmit(true, true, true, true);
        emit IOwnableWithTimelock.CallTimelocked(
            encodedCall,
            keccak256(encodedCall),
            vm.getBlockTimestamp() + TIMELOCK
        );
        relay.setProtocolFees(address(0x70CE2), fees);
        assertEq(relay.feeToken(), address(0), "token applied without delay");
        assertEq(relay.protocolFee(3), 0, "fee applied without delay");

        // After the delay anyone can execute; token + fee land together in one
        // self-contained event carrying the complete new fee state.
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.expectEmit(true, true, true, true);
        emit IRelay.ProtocolFeesSet(address(0x70CE2), fees);
        vm.expectEmit(true, true, true, true);
        emit IOwnableWithTimelock.TimelockedCallExecuted(keccak256(encodedCall));
        vm.prank(address(0xD00D));
        relay.executeTimelockedCall(encodedCall);

        assertEq(relay.feeToken(), address(0x70CE2), "token not applied after execute");
        assertEq(relay.protocolFee(3), 5_000_000, "fee not applied after execute");
    }

    function test_executeTimelockedCallRevertTooEarly() public {
        relay.setTimelockDuration(TIMELOCK);
        bytes memory encodedCall =
            abi.encodeCall(relay.setFeeExemptions, (_exemptions(address(0xDA0), true)));
        relay.setFeeExemptions(_exemptions(address(0xDA0), true));

        vm.warp(vm.getBlockTimestamp() + TIMELOCK - 1);
        vm.expectRevert(IOwnableWithTimelock.TimelockNotAllowedYet.selector);
        relay.executeTimelockedCall(encodedCall);
    }

    function test_executeTimelockedCallRevertUnknownCall() public {
        vm.expectRevert(IOwnableWithTimelock.TimelockInvalidSelector.selector);
        relay.executeTimelockedCall(hex"12345678");
    }

    function test_executeTimelockedCallRevertAlreadyExecuted() public {
        relay.setTimelockDuration(TIMELOCK);
        bytes memory encodedCall =
            abi.encodeCall(relay.setFeeExemptions, (_exemptions(address(0xDA0), true)));
        relay.setFeeExemptions(_exemptions(address(0xDA0), true));

        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        relay.executeTimelockedCall(encodedCall);
        vm.expectRevert(IOwnableWithTimelock.TimelockInvalidSelector.selector);
        relay.executeTimelockedCall(encodedCall);
    }

    function test_queueSameCallAgainResetsDelay() public {
        uint256 start = vm.getBlockTimestamp();
        relay.setTimelockDuration(TIMELOCK);
        bytes memory encodedCall =
            abi.encodeCall(relay.setFeeExemptions, (_exemptions(address(0xDA0), true)));
        relay.setFeeExemptions(_exemptions(address(0xDA0), true));

        // Re-queueing the identical call restarts its delay.
        vm.warp(start + TIMELOCK / 2);
        relay.setFeeExemptions(_exemptions(address(0xDA0), true));
        assertEq(relay.getExecuteTimelockedCallTimestamp(encodedCall), start + TIMELOCK / 2 + TIMELOCK);

        // At the original deadline the restarted delay has not passed yet.
        vm.warp(start + TIMELOCK);
        vm.expectRevert(IOwnableWithTimelock.TimelockNotAllowedYet.selector);
        relay.executeTimelockedCall(encodedCall);
    }

    function test_getExecuteTimelockedCallTimestampRevertUnknownCall() public {
        vm.expectRevert(IOwnableWithTimelock.TimelockInvalidSelector.selector);
        relay.getExecuteTimelockedCallTimestamp(hex"12345678");
    }

    function test_executeTimelockedCallBubblesRevert() public {
        // Validations run at execution time, not at queueing: a zero exemption account queues
        // cleanly and reverts with the underlying error later.
        relay.setTimelockDuration(TIMELOCK);
        bytes memory encodedCall =
            abi.encodeCall(relay.setFeeExemptions, (_exemptions(address(0), true)));
        relay.setFeeExemptions(_exemptions(address(0), true));

        uint256 eta = vm.getBlockTimestamp() + TIMELOCK;
        vm.warp(eta);
        vm.expectRevert(IRelay.FeeExemptAddressZero.selector);
        relay.executeTimelockedCall(encodedCall);
        // EVM atomicity restores the deleted queue entry, so a failed execution leaves the
        // call live rather than consuming it.
        assertEq(
            relay.getExecuteTimelockedCallTimestamp(encodedCall),
            eta,
            "failed execution consumed the queue entry"
        );
    }

    function test_cancelTimelockedCall() public {
        relay.setTimelockDuration(TIMELOCK);
        bytes memory encodedCall =
            abi.encodeCall(relay.setFeeExemptions, (_exemptions(address(0xDA0), true)));
        relay.setFeeExemptions(_exemptions(address(0xDA0), true));

        vm.expectEmit(true, true, true, true);
        emit IOwnableWithTimelock.TimelockedCallCanceled(keccak256(encodedCall));
        relay.cancelTimelockedCall(encodedCall);

        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.expectRevert(IOwnableWithTimelock.TimelockInvalidSelector.selector);
        relay.executeTimelockedCall(encodedCall);
    }

    function test_cancelTimelockedCallRevertNonOwner() public {
        relay.setTimelockDuration(TIMELOCK);
        bytes memory encodedCall =
            abi.encodeCall(relay.setFeeExemptions, (_exemptions(address(0xDA0), true)));
        relay.setFeeExemptions(_exemptions(address(0xDA0), true));

        vm.prank(address(0xBEEF));
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(0xBEEF))
        );
        relay.cancelTimelockedCall(encodedCall);
    }

    function test_cancelTimelockedCallRevertUnknownCall() public {
        vm.expectRevert(IOwnableWithTimelock.TimelockInvalidSelector.selector);
        relay.cancelTimelockedCall(hex"12345678");
    }

    // ── Owner setters: validation and mode restrictions ───────────────────────

    function test_setProtocolFeesAppliesAndEmits() public {
        IRelay.FeeConfig[] memory fees = new IRelay.FeeConfig[](1);
        fees[0] = IRelay.FeeConfig(3, 1234);
        vm.expectEmit(true, true, true, true);
        emit IRelay.ProtocolFeesSet(address(0), fees);
        relay.setProtocolFees(address(0), fees);
        assertEq(relay.protocolFee(3), 1234);
        assertEq(relay.protocolFeeInWei(3), 1234);
    }

    function test_setProtocolFeesTokenAndFeesApplyAtomically() public {
        // Token switch and fee re-denomination are one full-replace call: both are visible
        // immediately after it, announced by one self-contained event, and the deprecated
        // wei-named getter fails closed from that same moment.
        IRelay.FeeConfig[] memory fees = new IRelay.FeeConfig[](1);
        fees[0] = IRelay.FeeConfig(3, 5_000_000); // e.g. 5 tokens at 6 decimals
        vm.expectEmit(true, true, true, true);
        emit IRelay.ProtocolFeesSet(address(0x70CE2), fees);
        relay.setProtocolFees(address(0x70CE2), fees);
        assertEq(relay.feeToken(), address(0x70CE2));
        assertEq(relay.protocolFee(3), 5_000_000);
        vm.expectRevert(IRelay.FeeTokenActive.selector);
        relay.protocolFeeInWei(3);
    }

    function test_setProtocolFeesRevertInvalidProtocolId() public {
        IRelay.FeeConfig[] memory fees = new IRelay.FeeConfig[](1);
        fees[0] = IRelay.FeeConfig(1, 1234);
        vm.expectRevert(IRelay.InvalidProtocolId.selector);
        relay.setProtocolFees(address(0), fees);
    }

    function test_setFeeCollectionAddressAppliesAndEmits() public {
        vm.expectEmit(true, true, true, true);
        emit IRelay.FeeCollectionAddressSet(address(0xFEE2));
        relay.setFeeCollectionAddress(address(0xFEE2));
        assertEq(relay.feeCollectionAddress(), address(0xFEE2));
    }

    function test_setFeeCollectionAddressRevertZero() public {
        vm.expectRevert(IRelay.FeeCollectionAddressZero.selector);
        relay.setFeeCollectionAddress(address(0));
    }

    function test_feeSettersRevertOnSetterModeDeploy() public {
        // A setter-mode (home) deployment charges no verify() fee, so every fee-related
        // setter fail-closes there (mirrors the initialize() seeding rules).
        IRelay.RelayInitialConfig memory cfg = _relayConfig(0);
        cfg.feeCollectionAddress = payable(address(0));
        Relay home = Relay(
            address(
                new RelayProxy(
                    address(relayImplementation), cfg, address(0xF5), IRelay(address(0)), address(this)
                )
            )
        );

        IRelay.FeeConfig[] memory fees = new IRelay.FeeConfig[](1);
        fees[0] = IRelay.FeeConfig(3, 1234);
        vm.expectRevert(IRelay.FeeConfigNotAllowed.selector);
        home.setProtocolFees(address(0), fees);

        vm.expectRevert(IRelay.FeeExemptionsNotAllowed.selector);
        home.setFeeExemptions(_exemptions(address(0xDA0), true));

        vm.expectRevert(IRelay.FeeConfigNotAllowed.selector);
        home.setFeeCollectionAddress(address(0xFEE2));
    }

    // ── Upgrades through the timelock ─────────────────────────────────────────

    function test_upgradeExecutesOnlyQueuedImplementation() public {
        address queued = address(new RelayV2Mock());
        address other = address(new RelayV2Mock());
        uint256 start = vm.getBlockTimestamp();
        relay.setTimelockDuration(TIMELOCK);

        // Queue an upgrade to `queued`, then after the delay try to execute a different
        // implementation. Only the exact queued calldata was recorded, so the substitute
        // reverts and the queued one still applies.
        relay.upgradeToAndCall(queued, "");
        vm.warp(start + TIMELOCK);

        vm.expectRevert(IOwnableWithTimelock.TimelockInvalidSelector.selector);
        relay.executeTimelockedCall(abi.encodeCall(relay.upgradeToAndCall, (other, "")));

        relay.executeTimelockedCall(abi.encodeCall(relay.upgradeToAndCall, (queued, "")));
        assertEq(RelayV2Mock(address(relay)).version(), 2, "queued upgrade did not apply");
    }

    function test_queuedTimelockedMigrationExecutesViaSelfCall() public {
        // Timelocked upgrade carrying migration data: the owner queues it, then a stranger
        // executes it after the delay. The migration runs as a proxy self-call, so the
        // owner-or-self reinitializer accepts it.
        uint256 start = vm.getBlockTimestamp();
        relay.setTimelockDuration(TIMELOCK);

        address v2 = address(new RelayV2Mock());
        bytes memory data = abi.encodeCall(RelayV2Mock.initializeV2, (42));
        bytes memory encodedCall = abi.encodeCall(relay.upgradeToAndCall, (v2, data));
        relay.upgradeToAndCall(v2, data); // owner's call only queues

        vm.warp(start + TIMELOCK);
        vm.prank(address(0x5732A)); // executed by a stranger, not the owner
        relay.executeTimelockedCall(encodedCall);

        assertEq(RelayV2Mock(address(relay)).newField(), 42, "queued migration did not run");
        assertEq(relay.sourceChainId(), block.chainid, "sequential state lost");
    }

    function test_queuedMigrationCannotChainASecondTimelockedCall() public {
        // The executing flag must be single-use: consumed before the target body runs, so a
        // migration cannot ride it into a second privileged call. Without that consumption an
        // attacker-chosen address would gain a fee exemption through a queued upgrade,
        // bypassing both the timelock and onlyOwner.
        address attacker = address(0xA77ACC);
        uint256 start = vm.getBlockTimestamp();
        relay.setTimelockDuration(TIMELOCK);

        address v2 = address(new RelayNestedMigrationMock());
        bytes memory data = abi.encodeCall(RelayNestedMigrationMock.initializeV2, (attacker));
        bytes memory encodedCall = abi.encodeCall(relay.upgradeToAndCall, (v2, data));
        relay.upgradeToAndCall(v2, data); // owner's call only queues

        vm.warp(start + TIMELOCK);
        // The nested setFeeExemptions sees executing == false, falls through to the queue
        // path, and _checkOwner reverts because msg.sender is the proxy.
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(relay))
        );
        relay.executeTimelockedCall(encodedCall);

        assertFalse(relay.feeExemptAddress(attacker), "attacker gained an exemption through a queued migration");
    }

    function test_migrationReinitializerRejectsStranger() public {
        // An upgrade accidentally executed WITHOUT migration data leaves the reinitializer
        // unspent; the owner-or-self guard still stops a stranger from seizing it.
        address v2 = address(new RelayV2Mock());
        relay.upgradeToAndCall(v2, "");
        vm.prank(address(0x5732A));
        vm.expectRevert(bytes("only owner or self"));
        RelayV2Mock(address(relay)).initializeV2(99);
    }

    function test_queuingUpgradeWithValueReverts() public {
        // Queuing replays only calldata via a zero-value self-call, so a payable
        // upgradeToAndCall queued with value would trap that value.
        relay.setTimelockDuration(TIMELOCK);
        address v2 = address(new RelayV2Mock());
        vm.deal(address(this), 1 ether);
        vm.expectRevert(IOwnableWithTimelock.TimelockValueNotAllowed.selector);
        relay.upgradeToAndCall{value: 1}(v2, "");
    }

    // ── ERC-7201 namespace layout ─────────────────────────────────────────────

    /// @dev Swapping `executing` and `timelockDurationSeconds` would make a stale duration
    ///      read as `executing` and bypass the timelock outright.
    function test_timelockNamespaceFieldLayout() public {
        relay.setTimelockDuration(TIMELOCK);
        bytes memory encodedCall =
            abi.encodeCall(relay.setFeeExemptions, (_exemptions(address(0xDA0), true)));
        relay.setFeeExemptions(_exemptions(address(0xDA0), true));
        uint256 eta = vm.getBlockTimestamp() + TIMELOCK;

        uint256 root = uint256(_erc7201("utils.OwnableWithTimelock.State"));

        // executing: root offset 0 — false at rest, with 31 free trailing bytes.
        assertEq(uint256(vm.load(address(relay), bytes32(root))), 0, "executing must be false at rest");

        assertEq(
            uint256(vm.load(address(relay), bytes32(root + 1))),
            TIMELOCK,
            "timelockDurationSeconds: root + 1"
        );

        assertEq(uint256(vm.load(address(relay), bytes32(root + 2))), 0, "timelockedCalls mapping root: root + 2");
        assertEq(
            uint256(vm.load(address(relay), keccak256(abi.encode(keccak256(encodedCall), root + 2)))),
            eta,
            "timelockedCalls entry: derived from root + 2"
        );

        // No collision with the ERC-1967 proxy slots.
        assertTrue(bytes32(root) != _erc1967("eip1967.proxy.implementation"), "collides with implementation slot");
        assertTrue(bytes32(root) != _erc1967("eip1967.proxy.admin"), "collides with admin slot");
        assertTrue(bytes32(root) != _erc1967("eip1967.proxy.beacon"), "collides with beacon slot");
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _erc7201(string memory _id) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(_id))) - 1)) & ~bytes32(uint256(0xff));
    }

    function _erc1967(string memory _id) internal pure returns (bytes32) {
        return bytes32(uint256(keccak256(bytes(_id))) - 1);
    }

    function _exemptions(address _account, bool _exempt)
        internal pure
        returns (IIRelay.FeeExemption[] memory _list)
    {
        _list = new IIRelay.FeeExemption[](1);
        _list[0] = IIRelay.FeeExemption(_account, _exempt);
    }

    function _deployRelay(IRelay.RelayInitialConfig memory _cfg) internal returns (Relay) {
        return Relay(
            address(
                new RelayProxy(
                    address(relayImplementation), _cfg, address(0), IRelay(address(0)), address(this)
                )
            )
        );
    }

    function _relayConfig(uint256 _timelockDurationSeconds)
        internal view
        returns (IRelay.RelayInitialConfig memory c)
    {
        c.initialRewardEpochId = 1;
        c.startingVotingRoundIdForInitialRewardEpochId = 1;
        c.initialSigningPolicyHash = bytes32(uint256(1));
        c.randomNumberProtocolId = 2;
        c.firstVotingRoundStartTs = 1;
        c.votingEpochDurationSeconds = 1;
        c.firstRewardEpochStartVotingRoundId = 0;
        c.rewardEpochDurationInVotingEpochs = 1;
        c.thresholdIncreaseBIPS = 10000;
        c.messageFinalizationWindowInRewardEpochs = 1;
        c.feeCollectionAddress = payable(address(0xFEE));
        c.feeConfigs = new IRelay.FeeConfig[](0);
        c.sourceChainId = block.chainid; // the source-network id is mandatory
        c.timelockDurationSeconds = _timelockDurationSeconds;
    }
}
