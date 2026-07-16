// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// ============================================================================================
//  N=5 re-validation of the Relay.sol signature-loop weight-accounting proof (see RelaySigLoopFV.t.sol
//  for the full commentary). IDENTICAL structure and invariant, with the modeled voter count bumped to
//  N=5 and the grounded prefix sum `_psAt` extended to five uint16 weights. K (signature count) remains
//  genuinely unbounded — the inductive step's symbolic pre-state ranges over every INV-state.
//
//  This exists so the "also re-validated at N=5" claim in docs/relay-verification/05 and the kontrol
//  README is a COMMITTED, REPRODUCIBLE artifact (via test-forge/fv/kontrol/run.sh + the manifest), not a
//  one-off manual re-run. Expected verdicts under kontrol-local:ready (1.0.248): 5 PROVE PASSED + 2
//  anti-vacuity controls FAILED (counterexample by design). The stronger fully-unbounded ∀N∀K statement
//  is the Lean proof (test-forge/fv/lean/RelaySigLoop.lean:threshold_sound).
//
//  INVARIANT:  INV(weight, nextUnusedIndex) := weight <= psAt(nextUnusedIndex) && nextUnusedIndex <= N
// ============================================================================================

interface IVm { function assume(bool) external; }

contract RelaySigLoopFV_N5 {
    IVm constant vm = IVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 constant N = 5; // modeled voter count (concrete; structure parametric)

    // GROUNDED prefix sum at boundary k. uint16 weights => bounded, no overflow, no array.
    function _psAt(uint256 k, uint16 w0, uint16 w1, uint16 w2, uint16 w3, uint16 w4)
        internal pure returns (uint256)
    {
        if (k == 0) return 0;
        if (k == 1) return uint256(w0);
        if (k == 2) return uint256(w0) + uint256(w1);
        if (k == 3) return uint256(w0) + uint256(w1) + uint256(w2);
        if (k == 4) return uint256(w0) + uint256(w1) + uint256(w2) + uint256(w3);
        return uint256(w0) + uint256(w1) + uint256(w2) + uint256(w3) + uint256(w4); // k >= 5 == N
    }

    // ---- GROUNDED FACT: prefix sums of nonneg weights are monotone. Derived, not assumed. ----
    function prove_lemma_prefix_monotone(
        uint16 w0, uint16 w1, uint16 w2, uint16 w3, uint16 w4, uint256 i, uint256 j
    ) external {
        vm.assume(j <= N);
        vm.assume(i <= j);
        assert(_psAt(i, w0, w1, w2, w3, w4) <= _psAt(j, w0, w1, w2, w3, w4));
    }

    // ---- BASE CASE ----
    function prove_base_invariant(uint16 w0, uint16 w1, uint16 w2, uint16 w3, uint16 w4) external {
        uint256 weight = 0;
        uint256 nextUnusedIndex = 0;
        assert(nextUnusedIndex <= N);
        assert(weight <= _psAt(nextUnusedIndex, w0, w1, w2, w3, w4)); // 0 <= psAt(0) == 0
    }

    // ---- INDUCTIVE STEP: one signature preserves INV, over a fully-symbolic pre-state ----
    function prove_step_preserves_invariant(
        uint16 w0, uint16 w1, uint16 w2, uint16 w3, uint16 w4,
        uint256 weight, uint256 nextUnusedIndex, uint256 idx
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2, w3, w4));
        vm.assume(idx < N);                 // G1
        vm.assume(idx >= nextUnusedIndex);  // G2 strict order => no double count
        uint256 added = _psAt(idx + 1, w0, w1, w2, w3, w4) - _psAt(idx, w0, w1, w2, w3, w4); // = w_idx
        uint256 newWeight = weight + added;
        uint256 newNext = idx + 1;
        assert(newNext <= N);
        assert(newWeight <= _psAt(newNext, w0, w1, w2, w3, w4));
    }

    // ---- CONCLUSION: accept => total genuine weight exceeded threshold ----
    function prove_accept_implies_threshold_exceeded(
        uint16 w0, uint16 w1, uint16 w2, uint16 w3, uint16 w4,
        uint256 weight, uint256 nextUnusedIndex, uint256 threshold
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2, w3, w4));
        vm.assume(weight > threshold);                              // G4 accept gate
        assert(_psAt(N, w0, w1, w2, w3, w4) > threshold);           // totalWeight > threshold
    }

    // ---- CONTRAPOSITIVE: insufficient registered weight => can never accept, for ANY K ----
    function prove_insufficientWeight_cannotAccept(
        uint16 w0, uint16 w1, uint16 w2, uint16 w3, uint16 w4,
        uint256 weight, uint256 nextUnusedIndex, uint256 threshold
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2, w3, w4));
        vm.assume(_psAt(N, w0, w1, w2, w3, w4) <= threshold);
        assert(weight <= threshold);
    }

    // ================= ANTI-VACUITY CONTROLS (each MUST produce a counterexample) =================

    // Step WITHOUT G2 must FAIL: re-counting a passed voter breaks the bound => G2 is load-bearing.
    function prove_reach_stepNeedsGuard(
        uint16 w0, uint16 w1, uint16 w2, uint16 w3, uint16 w4,
        uint256 weight, uint256 nextUnusedIndex, uint256 idx
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2, w3, w4));
        vm.assume(idx < N);
        // G2 REMOVED
        uint256 added = _psAt(idx + 1, w0, w1, w2, w3, w4) - _psAt(idx, w0, w1, w2, w3, w4);
        uint256 newWeight = weight + added;
        assert(newWeight <= _psAt(idx + 1, w0, w1, w2, w3, w4)); // FALSE when idx < nextUnusedIndex, w_idx>0
    }

    // Acceptance is reachable: with enough total weight, weight can exceed threshold.
    function prove_reach_acceptIsPossible(
        uint16 w0, uint16 w1, uint16 w2, uint16 w3, uint16 w4,
        uint256 weight, uint256 nextUnusedIndex, uint256 threshold
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2, w3, w4));
        vm.assume(_psAt(N, w0, w1, w2, w3, w4) > threshold);
        assert(weight <= threshold); // claim no-accept -> FALSE => CEX
    }
}
