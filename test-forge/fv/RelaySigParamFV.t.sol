// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import "../unit/protocol/implementation/Relay.t.sol"; // reuse RelayTestBase
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Phase-1 PARAMETRIC proofs of the relay() signature/threshold accounting (see docs/relay-fv.md).
// Symbolic weights + threshold, so the theorems quantify over all weight distributions and thresholds.
//
// Threshold soundness is proved in the TIGHT per-prefix contrapositive form: provide exactly K
// signatures, ASSUME their total weight <= threshold, and prove relay() cannot accept — for K=1,2,3.
// Because relay() accepts on the FIRST prefix whose running weight exceeds the threshold (Relay.sol:1330),
// this rules out premature-accept at every prefix (not just the over-approximate total-sum bound).
//
// Weights/threshold are symbolic check_ args, so the policy + relay are deployed INSIDE each check
// (no-op setUp; base setUp uses vm.addr/sorting -> multiple paths under Halmos). ecrecover is
// uninterpreted; voters are concrete distinct addresses (A4 by construction); message is same-epoch so
// the Relay.sol:976 threshold-increase does not apply. halmos.toml sets loop = 6 (>= signer count);
// the reachability control is the anti-vacuity tripwire (must produce a counterexample).
//
// New to Halmos? See test-forge/fv/README.md §2 — a `check_` function is a ∀-proof over its symbolic
// arguments; `vm.assume` restricts that ∀ (a hypothesis), `assert` is the goal, and `check_reachability_*`
// is the anti-vacuity control that verify_fv.py requires to be REFUTED by a counterexample.
contract RelaySigParamFV is RelayTestBase {
    bytes32 internal constant ROOT = keccak256("fv-root"); // concrete, non-zero (RLY-04)
    uint256 internal constant NV = 3;

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {}

    function _policy(uint16 w0, uint16 w1, uint16 w2, uint16 thr) internal pure returns (bytes memory p) {
        p = abi.encodePacked(
            uint16(NV), uint24(REWARD_EPOCH_ID), uint32(START_VOTING_ROUND_ID), thr, bytes32(SEED)
        );
        p = abi.encodePacked(p, address(uint160(0x1001)), w0);
        p = abi.encodePacked(p, address(uint160(0x1002)), w1);
        p = abi.encodePacked(p, address(uint160(0x1003)), w2);
    }

    function _deploy(uint16 w0, uint16 w1, uint16 w2, uint16 thr) internal returns (Relay r, bytes memory p) {
        p = _policy(w0, w1, w2, thr);
        r = deployRelay(_initialConfig(_signingPolicyHash(p)), address(0), IRelay(address(0)));
    }

    function _sig(uint8 v, bytes32 r, bytes32 s, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(v, r, s, index);
    }

    function _call(Relay r, bytes memory p, bytes memory sigs) internal returns (bool ok) {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, ROOT);
        (ok, ) = address(r).call(abi.encodePacked(Relay.relay.selector, p, message, sigs));
    }

    // ---- P2 (parametric, TIGHT) — threshold soundness, per prefix length K=1,2,3 ----
    // For each K: provide K signatures at distinct indices 0..K-1, assume their total weight <= thr,
    // and prove relay() cannot accept. This pins the contract's actual (prefix) accept condition.

    // Reads as: ∀ w0,thr,a . (w0 ≤ thr) ⟹ ¬accept. The weight w0 and threshold thr are now themselves
    // symbolic (unlike RelaySigFV's concrete 100/260), so a PASS is the parametric theorem over ALL
    // single-voter weight/threshold pairs, not one instance. vm.assume(w0 ≤ thr) is the hypothesis that
    // restricts the ∀ to the "below threshold" region — the only region where soundness must hold.
    // EXPECT: PASS (proof).
    function check_threshold_1sig_param(uint16 w0, uint16 thr, Sig calldata a) external {
        vm.assume(uint256(w0) <= uint256(thr));
        (Relay r, bytes memory p) = _deploy(w0, 0, 0, thr);
        bytes memory sigs = abi.encodePacked(uint16(1), _sig(a.v, a.r, a.s, 0));
        assert(!_call(r, p, sigs));
    }

    // Parametric threshold soundness, K=2: for ALL weights w0,w1, threshold, and signatures — if
    // w0+w1 <= thr, relay() cannot accept. EXPECT: PASS (proof).
    function check_threshold_2sig_param(uint16 w0, uint16 w1, uint16 thr, Sig calldata a, Sig calldata b) external {
        vm.assume(uint256(w0) + uint256(w1) <= uint256(thr));
        (Relay r, bytes memory p) = _deploy(w0, w1, 0, thr);
        bytes memory sigs = abi.encodePacked(uint16(2), _sig(a.v, a.r, a.s, 0), _sig(b.v, b.r, b.s, 1));
        assert(!_call(r, p, sigs));
    }

    // Parametric threshold soundness, K=3: for ALL weights w0..w2, threshold, and signatures — if
    // w0+w1+w2 <= thr, relay() cannot accept. EXPECT: PASS (proof).
    function check_threshold_3sig_param(uint16 w0, uint16 w1, uint16 w2, uint16 thr, Sig calldata a, Sig calldata b, Sig calldata c)
        external
    {
        vm.assume(uint256(w0) + uint256(w1) + uint256(w2) <= uint256(thr));
        (Relay r, bytes memory p) = _deploy(w0, w1, w2, thr);
        bytes memory sigs = abi.encodePacked(
            uint16(3), _sig(a.v, a.r, a.s, 0), _sig(b.v, b.r, b.s, 1), _sig(c.v, c.r, c.s, 2)
        );
        assert(!_call(r, p, sigs));
    }

    // ---- P1 (parametric) — no-double-count, two duplicate layouts ----
    // A repeated voter index cannot inflate weight past the threshold. We assume single-counting the
    // non-repeated prefix is insufficient, so the only way to clear the threshold would be to count a
    // voter twice; the strict-increase guard rejects the repeat, so relay() cannot accept.

    // duplicate in the trailing slot: indices [0,1,1]
    // EXPECT: PASS (proof).
    function check_noDoubleCount_tailDup_param(uint16 w0, uint16 w1, uint16 thr, Sig calldata a, Sig calldata b, Sig calldata c)
        external
    {
        // Hypothesis: counting voters 0 and 1 ONCE each (w0+w1) does not clear thr. So the only route to
        // acceptance would be to count voter 1 a SECOND time via the repeated index — which the contract's
        // strict-increase index guard forbids. A PASS shows that double-counting escape is impossible.
        vm.assume(uint256(w0) + uint256(w1) <= uint256(thr));
        (Relay r, bytes memory p) = _deploy(w0, w1, 0, thr);
        bytes memory sigs = abi.encodePacked(
            uint16(3), _sig(a.v, a.r, a.s, 0), _sig(b.v, b.r, b.s, 1), _sig(c.v, c.r, c.s, 1)
        );
        assert(!_call(r, p, sigs));
    }

    // duplicate adjacent at the start: indices [0,0,1]
    // EXPECT: PASS (proof).
    function check_noDoubleCount_headDup_param(uint16 w0, uint16 thr, Sig calldata a, Sig calldata b, Sig calldata c)
        external
    {
        vm.assume(uint256(w0) <= uint256(thr));
        (Relay r, bytes memory p) = _deploy(w0, 0, 0, thr);
        bytes memory sigs = abi.encodePacked(
            uint16(3), _sig(a.v, a.r, a.s, 0), _sig(b.v, b.r, b.s, 0), _sig(c.v, c.r, c.s, 1)
        );
        assert(!_call(r, p, sigs));
    }

    // ---- Non-vacuity control: acceptance MUST be reachable (3 distinct voters, thr below the sum). ----
    // Mirror image of the proofs above: here thr is BELOW the honest sum, so acceptance ought to be
    // possible; asserting ¬accept must therefore be REFUTED. A counterexample witnesses that the accept
    // path is live (loop bound large enough) — without it every "cannot accept" proof would be vacuous.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reachability_param(uint16 w0, uint16 w1, uint16 w2, uint16 thr, Sig calldata a, Sig calldata b, Sig calldata c)
        external
    {
        vm.assume(w0 > 0 && w1 > 0 && w2 > 0);
        vm.assume(uint256(thr) < uint256(w0) + uint256(w1) + uint256(w2));
        (Relay r, bytes memory p) = _deploy(w0, w1, w2, thr);
        bytes memory sigs = abi.encodePacked(
            uint16(3), _sig(a.v, a.r, a.s, 0), _sig(b.v, b.r, b.s, 1), _sig(c.v, c.r, c.s, 2)
        );
        assert(!_call(r, p, sigs)); // EXPECT counterexample (acceptance reachable)
    }
}
