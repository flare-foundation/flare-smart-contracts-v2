// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {RelayProxy} from "../../contracts/protocol/implementation/RelayProxy.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {IIRelay} from "../../contracts/protocol/interface/IIRelay.sol";

/// Calls Relay through a distinct msg.sender without depending on prank semantics in the
/// symbolic executor. The returned status lets proofs reason about both success and revert.
contract RelayTimelockCallerFV {
    function callTarget(address _target, bytes calldata _data) external returns (bool, bytes memory) {
        return _target.call(_data);
    }
}

/// Upgrade target whose migration is deliberately owner-or-self, which is the supported
/// pattern for migrations executed by OwnableWithTimelock's proxy self-call.
contract RelayTimelockV2FV is Relay {
    uint256 public migrationValue;

    function initializeV2(uint256 _value) external {
        // solhint-disable-next-line gas-custom-errors, custom-errors
        require(msg.sender == owner() || msg.sender == address(this), "only owner or self");
        migrationValue = _value;
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}

/// Upgrade target whose migration attempts a second guarded call. The outer guarded
/// self-call must consume the one-shot `executing` authorization before this runs.
contract RelayNestedTimelockV2FV is Relay {
    function initializeNested(address _account) external {
        IIRelay.FeeExemption[] memory exemptions = new IIRelay.FeeExemption[](1);
        exemptions[0] = IIRelay.FeeExemption(_account, true);
        this.setFeeExemptions(exemptions);
    }
}

/// Shared deployment and queue-inspection helpers. This contract intentionally declares no
/// `check_` functions so inherited Halmos suites cannot duplicate proof results.
abstract contract RelayOwnerTimelockFVBase is Test {
    uint256 internal constant TIMELOCK = 1 days;
    address internal constant INITIAL_FEE_COLLECTION = address(0xFEE);

    function setUp() public virtual {}

    function _deployRelay(address signingPolicySetter) internal returns (Relay relay, Relay implementation) {
        implementation = new Relay();
        relay = Relay(
            address(
                new RelayProxy(
                    address(implementation),
                    _config(signingPolicySetter != address(0)),
                    signingPolicySetter,
                    IRelay(address(0)),
                    address(this)
                )
            )
        );
    }

    function _config(bool setterMode) internal view returns (IRelay.RelayInitialConfig memory c) {
        c.initialRewardEpochId = 1;
        c.startingVotingRoundIdForInitialRewardEpochId = 1;
        c.initialSigningPolicyHash = bytes32(uint256(1));
        c.randomNumberProtocolId = 2;
        c.firstVotingRoundStartTs = 1;
        c.votingEpochDurationSeconds = 1;
        c.firstRewardEpochStartVotingRoundId = 0;
        c.rewardEpochDurationInVotingEpochs = 1;
        c.thresholdIncreaseBIPS = 10_000;
        c.messageFinalizationWindowInRewardEpochs = 1;
        c.feeCollectionAddress = setterMode ? payable(address(0)) : payable(INITIAL_FEE_COLLECTION);
        c.feeConfigs = new IRelay.FeeConfig[](0);
        c.feeExemptAddresses = new address[](0);
        c.sourceChainId = block.chainid;
        c.timelockDurationSeconds = TIMELOCK;
    }

    function _exemptions(address account, bool exempt) internal pure returns (IIRelay.FeeExemption[] memory result) {
        result = new IIRelay.FeeExemption[](1);
        result[0] = IIRelay.FeeExemption(account, exempt);
    }

    function _queuedAt(Relay relay, bytes memory encodedCall) internal view returns (bool queued, uint256 eta) {
        (bool ok, bytes memory result) =
            address(relay).staticcall(abi.encodeCall(relay.getExecuteTimelockedCallTimestamp, (encodedCall)));
        if (ok) {
            queued = true;
            eta = abi.decode(result, (uint256));
        }
    }

    /// Read the contract's recorded ETA instead of reconstructing it from block.timestamp.
    /// This also keeps the model faithful when a symbolic executor implements `vm.warp` by
    /// updating the TIMESTAMP opcode rather than snapshotting earlier Solidity expressions.
    function _recordedEta(Relay relay, bytes memory encodedCall) internal view returns (uint256 eta) {
        bool queued;
        (queued, eta) = _queuedAt(relay, encodedCall);
        assert(queued);
    }
}

/**
 * Formal owner-timelock lifecycle properties over the real Relay proxy bytecode.
 *
 * Every deployment in this file starts with a nonzero one-day duration. Consequently none
 * of these checks accidentally exercises only the immediate (duration-zero) branch. The
 * `check_reach_*` functions are anti-vacuity controls and must be refuted by Halmos.
 */
contract RelayOwnerTimelockFV is RelayOwnerTimelockFVBase {
    /// Concrete Foundry smoke for the symbolic atomic-rollback path.
    function test_fvTimelockFailedExecutionIsAtomic() external {
        this.check_timelock_failedExecutionIsAtomic(address(0xA11CE));
    }

    /// Concrete lifecycle checks use the same helpers and assertions as the symbolic proofs.
    function test_fvTimelockOwnershipLifecycle() external {
        this.check_timelock_queuedCallSurvivesOwnershipTransfer(address(0xA11CE));
        this.check_timelock_transferOwnershipRequiresOwner(address(0xB0B));
        this.check_timelock_transferOwnershipCancellation(address(0xB0B));
        this.check_timelock_transferOwnershipZeroRejectedAtExecution();
    }

    /// Only the current owner can create a queue entry.
    // EXPECT: PASS (proof).
    function check_timelock_queueRequiresOwner(address recipient) external {
        vm.assume(recipient != address(0));
        (Relay relay,) = _deployRelay(address(0));
        RelayTimelockCallerFV stranger = new RelayTimelockCallerFV();
        bytes memory encodedCall = abi.encodeCall(relay.setFeeCollectionAddress, (recipient));

        (bool ok,) = stranger.callTarget(address(relay), encodedCall);

        assert(!ok);
        assert(relay.feeCollectionAddress() == INITIAL_FEE_COLLECTION);
        (bool queued,) = _queuedAt(relay, encodedCall);
        assert(!queued);
    }

    /// Queue identity commits to all calldata, not merely the function selector.
    // EXPECT: PASS (proof).
    function check_timelock_exactCalldataHash(address queuedRecipient, address substituteRecipient) external {
        vm.assume(queuedRecipient != address(0));
        vm.assume(substituteRecipient != address(0));
        vm.assume(queuedRecipient != substituteRecipient);
        (Relay relay,) = _deployRelay(address(0));
        bytes memory queuedCall = abi.encodeCall(relay.setFeeCollectionAddress, (queuedRecipient));
        bytes memory substituteCall = abi.encodeCall(relay.setFeeCollectionAddress, (substituteRecipient));

        relay.setFeeCollectionAddress(queuedRecipient);
        uint256 recordedEta = _recordedEta(relay, queuedCall);
        vm.warp(recordedEta);
        (bool substituteOk,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (substituteCall)));

        assert(!substituteOk);
        assert(relay.feeCollectionAddress() == INITIAL_FEE_COLLECTION);
        (bool queued, uint256 eta) = _queuedAt(relay, queuedCall);
        assert(queued && eta == recordedEta);
        (bool substituteQueued,) = _queuedAt(relay, substituteCall);
        assert(!substituteQueued);
    }

    /// Re-queuing identical calldata replaces its single stored ETA. This also
    /// applies after the first ETA matures: the replacement starts a full new
    /// delay, cannot execute at the replaced ETA, and executes at the new ETA.
    // EXPECT: PASS (proof).
    function check_timelock_duplicateQueueReplacesEta(address recipient) external {
        vm.assume(recipient != address(0));
        vm.assume(recipient != INITIAL_FEE_COLLECTION);
        (Relay relay,) = _deployRelay(address(0));
        bytes memory encodedCall = abi.encodeCall(relay.setFeeCollectionAddress, (recipient));

        (bool firstQueueOk,) = address(relay).call(encodedCall);
        assert(firstQueueOk);
        uint256 firstEta = _recordedEta(relay, encodedCall);
        vm.warp(firstEta);

        // A direct guarded call queues; only executeTimelockedCall consumes a
        // matured entry. The identical hash therefore receives a replacement ETA.
        (bool replacementQueueOk,) = address(relay).call(encodedCall);
        assert(replacementQueueOk);
        uint256 replacementEta = _recordedEta(relay, encodedCall);
        (bool replacedEtaOk,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));
        (bool queuedAfterEarlyAttempt, uint256 preservedEta) = _queuedAt(relay, encodedCall);

        assert(replacementEta == firstEta + TIMELOCK);
        assert(!replacedEtaOk);
        assert(queuedAfterEarlyAttempt && preservedEta == replacementEta);
        assert(relay.feeCollectionAddress() == INITIAL_FEE_COLLECTION);

        vm.warp(replacementEta);
        (bool replacementOk,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));
        (bool stillQueued,) = _queuedAt(relay, encodedCall);

        assert(replacementOk);
        assert(!stillQueued);
        assert(relay.feeCollectionAddress() == recipient);
    }

    /// The recorded ETA is inclusive: execution one second earlier fails and preserves the entry.
    // EXPECT: PASS (proof).
    function check_timelock_enforcesRecordedEta(address recipient) external {
        vm.assume(recipient != address(0));
        (Relay relay,) = _deployRelay(address(0));
        bytes memory encodedCall = abi.encodeCall(relay.setFeeCollectionAddress, (recipient));

        relay.setFeeCollectionAddress(recipient);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        assert(recordedEta > 0);
        vm.warp(recordedEta - 1);
        (bool ok,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));

        assert(!ok);
        assert(relay.feeCollectionAddress() == INITIAL_FEE_COLLECTION);
        (bool queued, uint256 eta) = _queuedAt(relay, encodedCall);
        assert(queued && eta == recordedEta);
    }

    /// Anyone can execute after ETA, but the exact entry can succeed only once.
    // EXPECT: PASS (proof).
    function check_timelock_permissionlessOneShotExecution(address recipient) external {
        vm.assume(recipient != address(0));
        (Relay relay,) = _deployRelay(address(0));
        RelayTimelockCallerFV executor = new RelayTimelockCallerFV();
        bytes memory encodedCall = abi.encodeCall(relay.setFeeCollectionAddress, (recipient));

        relay.setFeeCollectionAddress(recipient);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        vm.warp(recordedEta);
        (bool firstOk,) =
            executor.callTarget(address(relay), abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));
        (bool secondOk,) =
            executor.callTarget(address(relay), abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));

        assert(firstOk);
        assert(!secondOk);
        assert(relay.feeCollectionAddress() == recipient);
        (bool queued,) = _queuedAt(relay, encodedCall);
        assert(!queued);
    }

    /// Cancellation is owner-only and an unauthorized attempt cannot consume the queue entry.
    // EXPECT: PASS (proof).
    function check_timelock_cancelRequiresOwner(address recipient) external {
        vm.assume(recipient != address(0));
        (Relay relay,) = _deployRelay(address(0));
        RelayTimelockCallerFV stranger = new RelayTimelockCallerFV();
        bytes memory encodedCall = abi.encodeCall(relay.setFeeCollectionAddress, (recipient));

        relay.setFeeCollectionAddress(recipient);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        (bool strangerOk,) =
            stranger.callTarget(address(relay), abi.encodeCall(relay.cancelTimelockedCall, (encodedCall)));
        (bool stillQueued, uint256 eta) = _queuedAt(relay, encodedCall);
        relay.cancelTimelockedCall(encodedCall);
        (bool queuedAfterCancel,) = _queuedAt(relay, encodedCall);

        assert(!strangerOk);
        assert(stillQueued && eta == recordedEta);
        assert(!queuedAfterCancel);
        assert(relay.feeCollectionAddress() == INITIAL_FEE_COLLECTION);
    }

    /// Ownership transfer first queues and only applies at its own ETA. Applying
    /// the transfer consumes that entry once, preserves unrelated queue state,
    /// and removes the old owner's cancellation authority.
    // EXPECT: PASS (proof).
    function check_timelock_queuedCallSurvivesOwnershipTransfer(address recipient) external {
        vm.assume(recipient != address(0));
        vm.assume(recipient != INITIAL_FEE_COLLECTION);
        (Relay relay,) = _deployRelay(address(0));
        RelayTimelockCallerFV newOwner = new RelayTimelockCallerFV();
        RelayTimelockCallerFV executor = new RelayTimelockCallerFV();
        bytes memory encodedCall = abi.encodeCall(relay.setFeeCollectionAddress, (recipient));

        (bool queueOk,) = address(relay).call(encodedCall);
        assert(queueOk);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        bytes memory transferCall = abi.encodeCall(relay.transferOwnership, (address(newOwner)));
        (bool transferQueueOk,) = address(relay).call(transferCall);
        assert(transferQueueOk);
        uint256 transferEta = _recordedEta(relay, transferCall);
        assert(transferEta == recordedEta);
        assert(relay.owner() == address(this));

        vm.warp(transferEta - 1);
        (bool earlyTransferOk,) =
            executor.callTarget(address(relay), abi.encodeCall(relay.executeTimelockedCall, (transferCall)));
        assert(!earlyTransferOk);
        assert(relay.owner() == address(this));
        assert(_recordedEta(relay, transferCall) == transferEta);

        vm.warp(transferEta);
        (bool transferExecuteOk,) =
            executor.callTarget(address(relay), abi.encodeCall(relay.executeTimelockedCall, (transferCall)));
        assert(transferExecuteOk);
        (bool transferStillQueued,) = _queuedAt(relay, transferCall);
        assert(!transferStillQueued);
        (bool transferReplayOk,) =
            executor.callTarget(address(relay), abi.encodeCall(relay.executeTimelockedCall, (transferCall)));
        assert(!transferReplayOk);

        (bool oldOwnerCancelOk,) = address(relay).call(abi.encodeCall(relay.cancelTimelockedCall, (encodedCall)));
        (bool queuedAfterTransfer, uint256 preservedEta) = _queuedAt(relay, encodedCall);

        assert(relay.owner() == address(newOwner));
        assert(!oldOwnerCancelOk);
        assert(queuedAfterTransfer && preservedEta == recordedEta);

        vm.warp(recordedEta);
        (bool executeOk,) =
            executor.callTarget(address(relay), abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));
        (bool stillQueued,) = _queuedAt(relay, encodedCall);

        assert(executeOk);
        assert(!stillQueued);
        assert(relay.owner() == address(newOwner));
        assert(relay.feeCollectionAddress() == recipient);
    }

    /// A stranger cannot queue any ownership target, including a target that
    /// would be invalid only when an authorized queued call executes.
    // EXPECT: PASS (proof).
    function check_timelock_transferOwnershipRequiresOwner(address recipient) external {
        (Relay relay,) = _deployRelay(address(0));
        RelayTimelockCallerFV stranger = new RelayTimelockCallerFV();
        bytes memory transferCall = abi.encodeCall(relay.transferOwnership, (recipient));
        (bool ok,) = stranger.callTarget(address(relay), transferCall);
        (bool queued,) = _queuedAt(relay, transferCall);
        assert(!ok);
        assert(!queued);
        assert(relay.owner() == address(this));
    }

    /// Nonowners have no cancellation authority before execution. The current
    /// owner can cancel the transfer and prevent later execution.
    // EXPECT: PASS (proof).
    function check_timelock_transferOwnershipCancellation(address recipient) external {
        (Relay relay,) = _deployRelay(address(0));
        RelayTimelockCallerFV stranger = new RelayTimelockCallerFV();
        bytes memory transferCall = abi.encodeCall(relay.transferOwnership, (recipient));
        relay.transferOwnership(recipient);
        uint256 transferEta = _recordedEta(relay, transferCall);
        (bool strangerCancelOk,) =
            stranger.callTarget(address(relay), abi.encodeCall(relay.cancelTimelockedCall, (transferCall)));
        assert(!strangerCancelOk);
        assert(_recordedEta(relay, transferCall) == transferEta);
        assert(relay.owner() == address(this));

        relay.cancelTimelockedCall(transferCall);
        (bool stillQueued,) = _queuedAt(relay, transferCall);
        vm.warp(transferEta);
        (bool executeOk,) =
            stranger.callTarget(address(relay), abi.encodeCall(relay.executeTimelockedCall, (transferCall)));
        assert(!stillQueued);
        assert(!executeOk);
        assert(relay.owner() == address(this));
    }

    /// Zero-recipient validation runs when the queued body executes, and its
    /// revert restores the queue entry and leaves ownership intact.
    // EXPECT: PASS (proof).
    function check_timelock_transferOwnershipZeroRejectedAtExecution() external {
        (Relay relay,) = _deployRelay(address(0));
        bytes memory transferCall = abi.encodeCall(relay.transferOwnership, (address(0)));
        relay.transferOwnership(address(0));
        uint256 transferEta = _recordedEta(relay, transferCall);
        vm.warp(transferEta);
        (bool executeOk,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (transferCall)));
        assert(!executeOk);
        assert(relay.owner() == address(this));
        assert(_recordedEta(relay, transferCall) == transferEta);
        // A subsequent guarded owner action must still queue rather than
        // inheriting execution privilege from the reverted transfer.
        bytes memory laterCall = abi.encodeCall(relay.setFeeCollectionAddress, (address(0xA11CE)));
        relay.setFeeCollectionAddress(address(0xA11CE));
        assert(_recordedEta(relay, laterCall) == transferEta + TIMELOCK);
        assert(relay.feeCollectionAddress() == INITIAL_FEE_COLLECTION);
    }

    /// Anti-vacuity: a matured transfer can move ownership to the requested
    /// distinct account through permissionless execution.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_timelock_ownershipTransfer() external {
        (Relay relay,) = _deployRelay(address(0));
        RelayTimelockCallerFV newOwner = new RelayTimelockCallerFV();
        RelayTimelockCallerFV executor = new RelayTimelockCallerFV();
        bytes memory transferCall = abi.encodeCall(relay.transferOwnership, (address(newOwner)));
        relay.transferOwnership(address(newOwner));
        vm.warp(_recordedEta(relay, transferCall));
        (bool ok,) =
            executor.callTarget(address(relay), abi.encodeCall(relay.executeTimelockedCall, (transferCall)));
        assert(!(ok && relay.owner() == address(newOwner)));
    }

    /// A target revert rolls back the optimistic delete and the one-shot execution flag.
    // EXPECT: PASS (proof).
    function check_timelock_failedExecutionIsAtomic(address laterRecipient) external {
        vm.assume(laterRecipient != address(0));
        vm.assume(laterRecipient != INITIAL_FEE_COLLECTION);
        (Relay relay,) = _deployRelay(address(0));
        IIRelay.FeeExemption[] memory invalid = _exemptions(address(0), true);
        bytes memory invalidCall = abi.encodeCall(relay.setFeeExemptions, (invalid));

        relay.setFeeExemptions(invalid);
        uint256 recordedEta = _recordedEta(relay, invalidCall);
        vm.warp(recordedEta);
        (bool executeOk,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (invalidCall)));
        (bool invalidStillQueued, uint256 eta) = _queuedAt(relay, invalidCall);

        // If the reverted execution leaked `executing == true`, this new owner call would
        // execute immediately. It must instead create a second queue entry.
        bytes memory laterCall = abi.encodeCall(relay.setFeeCollectionAddress, (laterRecipient));
        relay.setFeeCollectionAddress(laterRecipient);
        (bool laterQueued, uint256 laterEta) = _queuedAt(relay, laterCall);

        assert(!executeOk);
        assert(invalidStillQueued && eta == recordedEta);
        assert(laterQueued && laterEta == recordedEta + TIMELOCK);
        assert(relay.feeCollectionAddress() == INITIAL_FEE_COLLECTION);
    }

    /// Anti-vacuity: a distinct caller really can execute a matured owner-queued call.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_timelock_permissionlessExecution(address recipient) external {
        vm.assume(recipient != address(0));
        (Relay relay,) = _deployRelay(address(0));
        RelayTimelockCallerFV executor = new RelayTimelockCallerFV();
        bytes memory encodedCall = abi.encodeCall(relay.setFeeCollectionAddress, (recipient));
        relay.setFeeCollectionAddress(recipient);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        vm.warp(recordedEta);
        (bool ok,) = executor.callTarget(address(relay), abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));
        assert(!ok); // EXPECT counterexample: the permissionless execution succeeds
    }
}

/// Mode-specific owner setters, all exercised through a nonzero timelock.
contract RelayOwnerModesFV is RelayOwnerTimelockFVBase {
    address internal constant CURRENT_SETTER = address(0x515E77E2);

    /// Concrete Foundry replay for the symbolic guarded-surface path.
    function test_fvTimelockSetterModeGuardedSurface() external {
        // Exercise each symbolic surface branch with fully aliased role addresses.
        this.check_timelock_setterModeGuardedSurface(address(3), address(3), 0);
        this.check_timelock_setterModeGuardedSurface(address(4), address(4), 1);
        this.check_timelock_setterModeGuardedSurface(address(5), address(5), 2);
    }

    /// Relay mode allows the three fee controls, but none applies before its ETA.
    // EXPECT: PASS (proof).
    function check_timelock_relayModeFeeSetters(address recipient, address account, uint96 fee) external {
        vm.assume(recipient != address(0));
        vm.assume(account != address(0));
        vm.assume(fee > 0); // configured zero fees are rejected; free means omitted
        (Relay relay,) = _deployRelay(address(0));
        IRelay.FeeConfig[] memory fees = _fees(3, fee);
        IIRelay.FeeExemption[] memory exemptions = _exemptions(account, true);
        bytes memory feeCall = abi.encodeCall(relay.setProtocolFees, (address(0), fees));
        bytes memory exemptionCall = abi.encodeCall(relay.setFeeExemptions, (exemptions));
        bytes memory recipientCall = abi.encodeCall(relay.setFeeCollectionAddress, (recipient));

        relay.setProtocolFees(address(0), fees);
        relay.setFeeExemptions(exemptions);
        relay.setFeeCollectionAddress(recipient);
        uint256 recordedEta = _recordedEta(relay, feeCall);
        assert(_recordedEta(relay, exemptionCall) == recordedEta);
        assert(_recordedEta(relay, recipientCall) == recordedEta);
        assert(relay.protocolFeeInWei(3) == 0);
        assert(!relay.feeExemptAddress(account));
        assert(relay.feeCollectionAddress() == INITIAL_FEE_COLLECTION);

        vm.warp(recordedEta);
        relay.executeTimelockedCall(feeCall);
        relay.executeTimelockedCall(exemptionCall);
        relay.executeTimelockedCall(recipientCall);

        assert(relay.protocolFeeInWei(3) == fee);
        assert(relay.feeExemptAddress(account));
        assert(relay.feeCollectionAddress() == recipient);
    }

    /// Token denomination and its complete fee table change atomically only after the ETA.
    // EXPECT: PASS (proof).
    function check_timelock_relayModeTokenTransition(address nextToken, uint96 fee) external {
        vm.assume(nextToken != address(0));
        vm.assume(fee > 0);
        (Relay relay,) = _deployRelay(address(0));
        IRelay.FeeConfig[] memory fees = _fees(3, fee);
        bytes memory encodedCall = abi.encodeCall(relay.setProtocolFees, (nextToken, fees));

        relay.setProtocolFees(nextToken, fees);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        assert(relay.feeToken() == address(0));
        assert(relay.protocolFee(3) == 0);
        assert(relay.getFeeConfigs().length == 0);

        vm.warp(recordedEta);
        relay.executeTimelockedCall(encodedCall);

        IRelay.FeeConfig[] memory installed = relay.getFeeConfigs();
        assert(relay.feeToken() == nextToken);
        assert(relay.protocolFee(3) == fee);
        assert(installed.length == 1);
        assert(installed[0].protocolId == 3 && installed[0].fee == fee);
    }

    /// Relay mode is immutable: even a correctly queued owner call cannot add a setter.
    // EXPECT: PASS (proof).
    function check_timelock_relayModeCannotEnableSetter(address proposedSetter) external {
        vm.assume(proposedSetter != address(0));
        (Relay relay,) = _deployRelay(address(0));
        bytes memory encodedCall = abi.encodeCall(relay.setSigningPolicySetter, (proposedSetter));
        relay.setSigningPolicySetter(proposedSetter);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        vm.warp(recordedEta);
        (bool ok,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));
        (bool queued, uint256 eta) = _queuedAt(relay, encodedCall);

        assert(!ok);
        assert(relay.signingPolicySetter() == address(0));
        assert(queued && eta == recordedEta);
    }

    /// Setter mode permanently rejects every fee-control surface; the reachability
    /// control below independently demonstrates that setter rotation remains live.
    // EXPECT: PASS (proof).
    function check_timelock_setterModeGuardedSurface(address recipient, address account, uint8 surface) external {
        vm.assume(recipient != address(0));
        vm.assume(account != address(0));
        vm.assume(surface < 3);
        (Relay relay,) = _deployRelay(CURRENT_SETTER);
        IRelay.FeeConfig[] memory fees = _fees(3, 1);
        IIRelay.FeeExemption[] memory exemptions = _exemptions(account, true);
        bytes memory feeCall = abi.encodeCall(relay.setProtocolFees, (address(0), fees));
        bytes memory exemptionCall = abi.encodeCall(relay.setFeeExemptions, (exemptions));
        bytes memory recipientCall = abi.encodeCall(relay.setFeeCollectionAddress, (recipient));

        // One symbolic branch per forbidden surface keeps failed-call rollback paths
        // independent while universally covering all three selectors in this check.
        if (surface == 0) {
            relay.setProtocolFees(address(0), fees);
            _executeAndReject(relay, feeCall);
        } else if (surface == 1) {
            relay.setFeeExemptions(exemptions);
            _executeAndReject(relay, exemptionCall);
        } else {
            relay.setFeeCollectionAddress(recipient);
            _executeAndReject(relay, recipientCall);
        }

        assert(relay.signingPolicySetter() == CURRENT_SETTER);
        assert(relay.protocolFeeInWei(3) == 0);
        assert(!relay.feeExemptAddress(account));
        assert(relay.feeCollectionAddress() == address(0));
    }

    /// Anti-vacuity: a matured setter-mode rotation can execute successfully.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_timelock_setterRotation(address nextSetter) external {
        vm.assume(nextSetter != address(0));
        (Relay relay,) = _deployRelay(CURRENT_SETTER);
        bytes memory encodedCall = abi.encodeCall(relay.setSigningPolicySetter, (nextSetter));
        relay.setSigningPolicySetter(nextSetter);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        vm.warp(recordedEta);
        (bool ok,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));
        assert(!ok); // EXPECT counterexample: the queued rotation succeeds
    }

    function _fees(uint8 protocolId, uint96 fee) internal pure returns (IRelay.FeeConfig[] memory result) {
        result = new IRelay.FeeConfig[](1);
        result[0] = IRelay.FeeConfig(protocolId, fee);
    }

    function _executeAndReject(Relay relay, bytes memory forbiddenCall) internal {
        uint256 recordedEta = _recordedEta(relay, forbiddenCall);
        vm.warp(recordedEta);

        (bool forbiddenOk,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (forbiddenCall)));
        (bool forbiddenQueued, uint256 eta) = _queuedAt(relay, forbiddenCall);

        assert(!forbiddenOk);
        assert(forbiddenQueued && eta == recordedEta);
    }
}

/// UUPS/proxy properties for owner-timelocked upgrades.
contract RelayOwnerUpgradeFV is RelayOwnerTimelockFVBase {
    /// The implementation is locked while the proxy initializes atomically and only once.
    // EXPECT: PASS (proof).
    function check_timelock_proxyInitializerInvariants() external {
        (Relay relay, Relay implementation) = _deployRelay(address(0));
        IRelay.RelayInitialConfig memory cfg = _config(false);

        assert(relay.owner() == address(this));
        assert(relay.implementation() == address(implementation));
        assert(relay.getTimelockDurationSeconds() == TIMELOCK);
        assert(relay.sourceChainId() == block.chainid);

        bytes memory initializeCall =
            abi.encodeCall(relay.initialize, (cfg, address(0), IRelay(address(0)), address(this)));
        (bool proxyReinitOk,) = address(relay).call(initializeCall);
        (bool implementationInitOk,) = address(implementation).call(initializeCall);

        assert(!proxyReinitOk && !implementationInitOk);
        assert(relay.owner() == address(this));
        assert(relay.implementation() == address(implementation));
        assert(relay.getTimelockDurationSeconds() == TIMELOCK);
        assert(relay.sourceChainId() == block.chainid);
    }

    /// Only the exact queued implementation/data pair can upgrade, and Relay/timelock
    /// storage survives the successful delegatecall.
    // EXPECT: PASS (proof).
    function check_timelock_upgradeExactAndPreservesStorage(uint96 migrationValue) external {
        (Relay relay, Relay originalImplementation) = _deployRelay(address(0));
        RelayTimelockV2FV queuedImplementation = new RelayTimelockV2FV();
        RelayTimelockV2FV substituteImplementation = new RelayTimelockV2FV();
        bytes memory migration = abi.encodeCall(RelayTimelockV2FV.initializeV2, (migrationValue));
        bytes memory queuedCall = abi.encodeCall(relay.upgradeToAndCall, (address(queuedImplementation), migration));
        bytes memory substituteCall =
            abi.encodeCall(relay.upgradeToAndCall, (address(substituteImplementation), migration));

        relay.upgradeToAndCall(address(queuedImplementation), migration);
        uint256 recordedEta = _recordedEta(relay, queuedCall);
        assert(relay.implementation() == address(originalImplementation));
        vm.warp(recordedEta);
        (bool substituteOk,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (substituteCall)));
        (bool queuedBeforeExecute, uint256 eta) = _queuedAt(relay, queuedCall);
        relay.executeTimelockedCall(queuedCall);

        assert(!substituteOk);
        assert(queuedBeforeExecute && eta == recordedEta);
        assert(relay.implementation() == address(queuedImplementation));
        assert(RelayTimelockV2FV(address(relay)).migrationValue() == migrationValue);
        assert(relay.owner() == address(this));
        assert(relay.getTimelockDurationSeconds() == TIMELOCK);
        assert(relay.sourceChainId() == block.chainid);
        assert(relay.startingVotingRoundIds(1) == 1);
        (bool queuedAfterExecute,) = _queuedAt(relay, queuedCall);
        assert(!queuedAfterExecute);
    }

    /// The one-shot execution flag cannot authorize a second guarded call from migration
    /// data; failure rolls back both the upgrade and queue deletion.
    // EXPECT: PASS (proof).
    function check_timelock_nestedGuardIsSingleUseAndAtomic(address account) external {
        vm.assume(account != address(0));
        (Relay relay, Relay originalImplementation) = _deployRelay(address(0));
        RelayNestedTimelockV2FV nestedImplementation = new RelayNestedTimelockV2FV();
        bytes memory migration = abi.encodeCall(RelayNestedTimelockV2FV.initializeNested, (account));
        bytes memory encodedCall = abi.encodeCall(relay.upgradeToAndCall, (address(nestedImplementation), migration));

        relay.upgradeToAndCall(address(nestedImplementation), migration);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        vm.warp(recordedEta);
        (bool ok,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));
        (bool queued, uint256 eta) = _queuedAt(relay, encodedCall);

        assert(!ok);
        assert(relay.implementation() == address(originalImplementation));
        assert(!relay.feeExemptAddress(account));
        assert(queued && eta == recordedEta);
        assert(relay.getTimelockDurationSeconds() == TIMELOCK);
    }

    /// The ERC-7201 timelock namespace is aligned and disjoint from all ERC-1967 slots.
    // EXPECT: PASS (proof).
    function check_timelock_storageNamespaceDisjoint() external pure {
        bytes32 root = _erc7201("utils.OwnableWithTimelock.State");
        bytes32 pageMask = ~bytes32(uint256(0xff));
        bytes32 implementationSlot = _erc1967("eip1967.proxy.implementation");
        bytes32 adminSlot = _erc1967("eip1967.proxy.admin");
        bytes32 beaconSlot = _erc1967("eip1967.proxy.beacon");

        assert(uint256(root) & 0xff == 0);
        // ERC-7201 reserves the entire 256-slot page rooted here, not just `root`.
        assert((implementationSlot & pageMask) != root);
        assert((adminSlot & pageMask) != root);
        assert((beaconSlot & pageMask) != root);
    }

    /// Anti-vacuity: the real proxy can complete a queued UUPS upgrade at ETA.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_timelock_upgradeCanExecute(uint96 migrationValue) external {
        (Relay relay,) = _deployRelay(address(0));
        RelayTimelockV2FV nextImplementation = new RelayTimelockV2FV();
        bytes memory migration = abi.encodeCall(RelayTimelockV2FV.initializeV2, (migrationValue));
        bytes memory encodedCall = abi.encodeCall(relay.upgradeToAndCall, (address(nextImplementation), migration));
        relay.upgradeToAndCall(address(nextImplementation), migration);
        uint256 recordedEta = _recordedEta(relay, encodedCall);
        vm.warp(recordedEta);
        (bool ok,) = address(relay).call(abi.encodeCall(relay.executeTimelockedCall, (encodedCall)));
        assert(!ok); // EXPECT counterexample: exact queued upgrade succeeds
    }

    function _erc7201(string memory id) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
    }

    function _erc1967(string memory id) internal pure returns (bytes32) {
        return bytes32(uint256(keccak256(bytes(id))) - 1);
    }
}
