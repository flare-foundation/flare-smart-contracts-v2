// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Symbolic proof of fee conservation in verify() when oldRelay == address(0).
//
// CLAIM (formal): for a deployed relay with feeCollectionAddress = FEE_COLLECTION and
// protocolFeeInWei[PID] = fee (symbolic), with a finalized non-zero root for (PID, VRID) and an
// empty Merkle proof whose leaf == root, then for any msg.value >= fee a SUCCEEDING verify() satisfies
//   (1) feeCollection.balance increases by exactly `fee`;
//   (2) the caller (this contract) net-pays exactly `fee` (overpayment msg.value-fee is refunded);
//   (3) the relay contract retains 0 wei (no ETH stuck).
//
// WHY THIS HARNESS SHAPE (each choice is load-bearing under Halmos):
//  - This obligation is about ETH accounting in verify() ONLY — it does NOT touch the signature loop
//    or ecrecover. We therefore finalize the root by DIRECT STATE CONSTRUCTION (vm.store into
//    merkleRootsPrivate, base storage slot 1 per the Relay storage layout) rather than a relay()
//    Mode-2 call, which would needlessly drag in the signature loop. PID and VRID are CONCRETE, so the
//    nested-mapping slot keccak(VRID . keccak(PID . 1)) is fully concrete and the value we vm.store is
//    exactly what verify()'s merkleRootsPrivate SLOAD reads back (Halmos keccak is uninterpreted but
//    functional — equal concrete preimages give the same term).
//  - EMPTY Merkle proof (length 0): MerkleProof.processProofCalldata returns the leaf unchanged, so the
//    proof loop runs ZERO iterations (loop bound irrelevant here) and verifyCalldata passes iff
//    leaf == root. We set leaf == ROOT.
//  - `fee` is SYMBOLIC (passed through the constructor feeConfigs), so the theorem quantifies over ALL
//    fees, including fee == 0 (no fee transfer; full refund) — hence the deploy is INSIDE each check and
//    setUp is a no-op (the base setUp uses vm.addr/sorting -> "Multiple paths in setUp" under Halmos).
//  - `msg.value` is SYMBOLIC with fee <= msgValue <= CAP; this contract is dealt CAP and has a
//    receive() so the overpayment refund (msg.sender.call) succeeds.
//  - feeCollection is a concrete code-less EOA (0xFEE...), distinct from this caller and from the relay,
//    so fee + refund land in three distinct accounts and the deltas are unambiguous.
//  - ANTI-VACUITY: check_p7_reachability asserts verify() reverts and EXPECTS A COUNTEREXAMPLE,
//    proving the success path (on which (1)-(3) are asserted) is actually reachable at this config.
contract RelayFeeConservationFV is RelayTestBase {
    // Concrete, distinct accounts so balance deltas are unambiguous.
    address payable internal constant FEE_COLLECTION = payable(address(0xFEE));

    // Concrete (protocolId, votingRoundId): protocolId > 1 (passes the "invalid protocol id" gate),
    // same-epoch round so no epoch/threshold interaction is touched (verify() does no epoch math anyway).
    uint8  internal constant PID  = 3;
    uint256 internal constant VRID = uint256(START_VOTING_ROUND_ID);

    bytes32 internal constant ROOT = keccak256("p7-root"); // concrete, non-zero

    // Large concrete bankroll for the caller; msg.value is bounded by this.
    uint256 internal constant CAP = 1 << 128;

    function setUp() public override {} // no-op: deploy in-check (symbolic fee); base setUp = multiple paths

    receive() external payable {} // accept the overpayment refund

    // Build a relay-only deployment (oldRelay == 0, signingPolicySetter == 0) with feeCollection set and
    // protocolFeeInWei[PID] = fee. The initial signing-policy hash is a concrete non-zero sentinel (only
    // its non-zeroness matters here — verify() never reads it).
    function _deploy(uint256 fee) internal returns (Relay r) {
        IRelay.RelayInitialConfig memory cfg;
        cfg.initialRewardEpochId = uint32(REWARD_EPOCH_ID);
        cfg.startingVotingRoundIdForInitialRewardEpochId = START_VOTING_ROUND_ID;
        cfg.initialSigningPolicyHash = keccak256("p7-sp"); // non-zero as initialize requires
        cfg.randomNumberProtocolId = RANDOM_PROTOCOL_ID;
        cfg.firstVotingRoundStartTs = FIRST_VOTING_ROUND_TS;
        cfg.votingEpochDurationSeconds = VOTING_EPOCH_DURATION;
        cfg.firstRewardEpochStartVotingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID;
        cfg.rewardEpochDurationInVotingEpochs = REWARD_EPOCH_DURATION;
        cfg.thresholdIncreaseBIPS = THRESHOLD_INCREASE_BIPS;
        cfg.messageFinalizationWindowInRewardEpochs = MESSAGE_FINALIZATION_WINDOW;
        cfg.feeCollectionAddress = FEE_COLLECTION;
        cfg.sourceChainId = block.chainid; // the source id is mandatory
        cfg.feeConfigs = new IRelay.FeeConfig[](1);
        cfg.feeConfigs[0] = IRelay.FeeConfig(PID, fee); // protocolFeeInWei[PID] = fee
        r = deployRelay(cfg, address(0), IRelay(address(0)));
    }

    // Directly construct the finalized-root state: merkleRootsPrivate is at base slot 1; the value for
    // [PID][VRID] sits at keccak(VRID . keccak(PID . 1)). PID/VRID concrete => concrete slot.
    function _finalizeRoot(Relay r, bytes32 root) internal {
        bytes32 inner = keccak256(abi.encode(uint256(PID), uint256(1)));
        bytes32 slot  = keccak256(abi.encode(VRID, inner));
        vm.store(address(r), slot, root);
    }

    // Common setup for every check: deploy, finalize root, fund the caller, snapshot balances.
    function _arrange(uint256 fee)
        internal
        returns (Relay r, uint256 feeCollBefore, uint256 selfBefore, uint256 relayBefore)
    {
        r = _deploy(fee);
        _finalizeRoot(r, ROOT);
        // Start every account from a clean, concrete baseline so deltas are exact.
        vm.deal(address(this), CAP);
        vm.deal(FEE_COLLECTION, 0);
        vm.deal(address(r), 0);
        feeCollBefore = FEE_COLLECTION.balance; // == 0
        selfBefore = address(this).balance;     // == CAP
        relayBefore = address(r).balance;        // == 0
    }

    function _callVerify(Relay r, uint256 msgValue) internal returns (bool ok) {
        // Empty proof => verifyCalldata passes iff leaf == root; leaf := ROOT.
        (ok, ) = address(r).call{value: msgValue}(
            abi.encodeWithSelector(Relay.verify.selector, uint256(PID), VRID, ROOT, new bytes32[](0))
        );
    }

    // ---- Fee-conservation proof on the succeeding new-relay verify() path. EXPECT: PASS. ----
    // For all fee and all msg.value >= fee, IF verify() succeeds THEN (1)-(3) hold exactly.
    function check_p7_feeConservation(uint256 fee, uint256 msgValue) external {
        vm.assume(fee <= msgValue);
        vm.assume(msgValue <= CAP); // caller can fund the call
        (Relay r, uint256 feeCollBefore, uint256 selfBefore, uint256 relayBefore) = _arrange(fee);

        bool ok = _callVerify(r, msgValue);
        vm.assume(ok); // reason about the SUCCESS path (reachability proved separately)

        // (1) feeCollection received exactly the fee.
        assert(FEE_COLLECTION.balance - feeCollBefore == fee);
        // (2) caller net-paid exactly the fee (overpayment refunded).
        assert(selfBefore - address(this).balance == fee);
        // (3) the relay contract retains nothing.
        assert(address(r).balance == relayBefore); // relayBefore == 0
    }

    // ---- Reachability / anti-vacuity control. EXPECT: COUNTEREXAMPLE. ----
    // verify() MUST be able to succeed at this config (else the main proof is vacuous: a never-true
    // `vm.assume(ok)` would let every assert pass trivially). Asserting !ok must therefore be refuted.
    function check_p7_reachability(uint256 fee, uint256 msgValue) external {
        vm.assume(fee <= msgValue);
        vm.assume(msgValue <= CAP);
        (Relay r, , , ) = _arrange(fee);
        bool ok = _callVerify(r, msgValue);
        assert(!ok); // EXPECT counterexample: a successful verify() exists
    }
}
