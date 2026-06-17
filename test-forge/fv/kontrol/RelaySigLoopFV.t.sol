// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// ============================================================================================
//  Relay.sol signature-loop weight accounting — UNBOUNDED-in-K (∀ number of signatures) proof
//  for Kontrol, via k-induction (base + single fully-symbolic preservation step) over a
//  GROUNDED prefix-sum invariant.
//
//  Faithful to Relay.relay()'s inline-assembly loop (contracts/.../Relay.sol:1217-1330):
//    loop state = (weight, nextUnusedIndex)            (:1225 weight:=0, :1227 nextUnusedIndex:=0)
//    per matched signature, in order:
//      G1  idx + 1 <= numberOfVoters      "Index out of range"     (:1257)
//      G2  idx >= nextUnusedIndex ; nextUnusedIndex := idx+1       (:1261,:1264)  [strict advance]
//      G3  weight := weight + (mload(..) & WEIGHT_MASK)            (:1325-1327, WEIGHT_MASK=0xffff)
//      G4  ACCEPT iff weight > threshold                          (:1330)        [first crossing]
//    ecrecover/keccak UNINTERPRETED (prove accounting, assume cryptography).
//
//  Voter weights are modeled as uint16 (= Relay's 16-bit WEIGHT_MASK at :1327): the type bounds each
//  to [0,65535] BY CONSTRUCTION, so the uint256 prefix sums are nonneg and never overflow — no assume,
//  no spurious overflow branch. psAt(k)=sum_{i<k} w_i is COMPUTED via conditional scalar logic (no
//  array => no symbolic-memory indexing). Monotonicity/recurrence are THEOREMS; the order guard G2 is
//  load-bearing (prove_reach_stepNeedsGuard removes it and genuinely counterexamples).
//
//  INVARIANT:  INV(weight, nextUnusedIndex) := weight <= psAt(nextUnusedIndex) && nextUnusedIndex <= N
//
//  HONEST CAVEATS: (1) N (voter count) concrete (model bound; structure parametric) — K (signatures)
//  is genuinely unbounded (the step's symbolic pre-state ranges over every INV-state, so one discharge
//  covers all iteration counts). (2) base+step => ∀K by the standard induction PRINCIPLE at the meta
//  level; Kontrol 1.0.248 has no native loop-invariant, so the composition itself is not machine-checked
//  (each piece is). (3) Checks a faithful Solidity MODEL of the loop body; the bytecode side at K<=3 is
//  covered by the Halmos suite (RelaySigParamFV).
// ============================================================================================

interface IVm { function assume(bool) external; }

contract RelaySigLoopFV {
    IVm constant vm = IVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 constant N = 3; // modeled voter count (concrete; structure parametric)

    // GROUNDED prefix sum at boundary k. uint16 weights => bounded, no overflow, no array.
    function _psAt(uint256 k, uint16 w0, uint16 w1, uint16 w2) internal pure returns (uint256) {
        if (k == 0) return 0;
        if (k == 1) return uint256(w0);
        if (k == 2) return uint256(w0) + uint256(w1);
        return uint256(w0) + uint256(w1) + uint256(w2); // k >= 3 == N
    }

    // ---- GROUNDED FACT: prefix sums of nonneg weights are monotone. Derived, not assumed. ----
    function prove_lemma_prefix_monotone(uint16 w0, uint16 w1, uint16 w2, uint256 i, uint256 j) external {
        vm.assume(j <= N);
        vm.assume(i <= j);
        assert(_psAt(i, w0, w1, w2) <= _psAt(j, w0, w1, w2));
    }

    // ---- BASE CASE ----
    function prove_base_invariant(uint16 w0, uint16 w1, uint16 w2) external {
        uint256 weight = 0;
        uint256 nextUnusedIndex = 0;
        assert(nextUnusedIndex <= N);
        assert(weight <= _psAt(nextUnusedIndex, w0, w1, w2)); // 0 <= psAt(0) == 0
    }

    // ---- INDUCTIVE STEP: one signature preserves INV, over a fully-symbolic pre-state ----
    function prove_step_preserves_invariant(
        uint16 w0, uint16 w1, uint16 w2,
        uint256 weight, uint256 nextUnusedIndex, uint256 idx
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2));
        vm.assume(idx < N);                 // G1
        vm.assume(idx >= nextUnusedIndex);  // G2 strict order => no double count
        uint256 added = _psAt(idx + 1, w0, w1, w2) - _psAt(idx, w0, w1, w2); // = w_idx by construction
        uint256 newWeight = weight + added;
        uint256 newNext = idx + 1;
        assert(newNext <= N);
        assert(newWeight <= _psAt(newNext, w0, w1, w2));
    }

    // ---- CONCLUSION: accept => total genuine weight exceeded threshold (threshold arbitrary uint256) ----
    function prove_accept_implies_threshold_exceeded(
        uint16 w0, uint16 w1, uint16 w2,
        uint256 weight, uint256 nextUnusedIndex, uint256 threshold
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2));
        vm.assume(weight > threshold);                      // G4 accept gate
        assert(_psAt(N, w0, w1, w2) > threshold);           // totalWeight > threshold
    }

    // ---- CONTRAPOSITIVE: insufficient registered weight => can never accept, for ANY K ----
    function prove_insufficientWeight_cannotAccept(
        uint16 w0, uint16 w1, uint16 w2,
        uint256 weight, uint256 nextUnusedIndex, uint256 threshold
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2));
        vm.assume(_psAt(N, w0, w1, w2) <= threshold);
        assert(weight <= threshold);
    }

    // ================= ANTI-VACUITY CONTROLS (each MUST produce a counterexample) =================

    // Step WITHOUT G2 must FAIL: re-counting a passed voter breaks the bound => G2 is load-bearing.
    function prove_reach_stepNeedsGuard(
        uint16 w0, uint16 w1, uint16 w2,
        uint256 weight, uint256 nextUnusedIndex, uint256 idx
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2));
        vm.assume(idx < N);
        // G2 REMOVED
        uint256 added = _psAt(idx + 1, w0, w1, w2) - _psAt(idx, w0, w1, w2);
        uint256 newWeight = weight + added;
        assert(newWeight <= _psAt(idx + 1, w0, w1, w2)); // FALSE when idx < nextUnusedIndex, w_idx>0 => CEX
    }

    // Acceptance is reachable: with enough total weight, weight can exceed threshold => no-accept claim false.
    function prove_reach_acceptIsPossible(
        uint16 w0, uint16 w1, uint16 w2,
        uint256 weight, uint256 nextUnusedIndex, uint256 threshold
    ) external {
        vm.assume(nextUnusedIndex <= N);
        vm.assume(weight <= _psAt(nextUnusedIndex, w0, w1, w2));
        vm.assume(_psAt(N, w0, w1, w2) > threshold);
        assert(weight <= threshold); // claim no-accept -> FALSE => CEX
    }
}
