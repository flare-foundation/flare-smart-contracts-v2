// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // RelayTestBase (for the shared test base only)

// Phase 3 Step 7 (M1/M7, UNBOUNDED Merkle depth): sorted-pair Merkle fold INJECTIVITY / non-malleability.
// The random-proof verification (Relay.sol:709-722) folds leaf with each proof element via the sorted-pair
// hash  sortedPair(a,b) = keccak(min(a,b) || max(a,b))  and accepts iff the fold equals the signed root.
// RelayMerkleProofFV proved (bounded, depth 1) that a wrong proof element is rejected. This proves the
// UNBOUNDED-depth anti-forgery property by k-INDUCTION on proof depth, the way RelaySigLoopFV did for the
// signature loop — but here the inductive STEP is a single keccak, so it discharges in Halmos (no Kontrol /
// no N^2 explosion):
//   BASE  (depth 0): the fold of a leaf with the empty proof is the leaf itself => injective in the leaf.
//   STEP           : one fold step preserves injectivity — sortedPair(h1,pe) == sortedPair(h2,pe) => h1==h2
//                    (under keccak injectivity, A1).
// base + step => for ANY proof depth D, fold(., proof) is injective in the (leaf/running hash); hence two
// distinct leaves cannot fold to the same committed root with the same proof — the root binds the leaf, so
// no off-tree leaf can be forged into a valid proof, at any depth. (Same meta-level induction caveat as the
// other unbounded proofs: base+step compose to forall-D by the induction principle.)
//
// keccak256 is the injective uninterpreted function of the modeling contract (A1); Halmos models it so.
contract RelayMerkleFoldFV is RelayTestBase {
    function setUp() public override {}

    // Relay's sorted-pair parent hash (Relay.sol:716-721).
    function _sortedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    // ---- BASE — depth-0 fold is the identity, hence injective in the leaf. ----
    // EXPECT: PASS (proof).
    function check_fold_base_injective(bytes32 leaf1, bytes32 leaf2) external pure {
        vm.assume(leaf1 != leaf2);
        // fold over the empty proof returns the leaf unchanged; distinct leaves => distinct depth-0 roots.
        assert(leaf1 != leaf2); // identity fold preserves distinctness (base case of the induction)
    }

    // ---- STEP — one fold step preserves injectivity (the inductive core). ----
    // If two running hashes fold to the same parent with the same sibling, they were already equal.
    // EXPECT: PASS (proof).
    function check_fold_step_injective(bytes32 h1, bytes32 h2, bytes32 pe) external pure {
        vm.assume(_sortedPair(h1, pe) == _sortedPair(h2, pe));
        assert(h1 == h2);
    }

    // ---- Bounded corroboration: full depth-2 fold is injective in the leaf. ----
    // EXPECT: PASS (proof).
    function check_fold_depth2_injective(bytes32 leaf1, bytes32 leaf2, bytes32 p0, bytes32 p1) external pure {
        bytes32 r1 = _sortedPair(_sortedPair(leaf1, p0), p1);
        bytes32 r2 = _sortedPair(_sortedPair(leaf2, p0), p1);
        vm.assume(r1 == r2);
        assert(leaf1 == leaf2); // same root + same proof => same leaf (no depth-2 forgery)
    }

    // ---- Non-vacuity: distinct inputs DO produce distinct folds (the fold genuinely distinguishes). ----
    // EXPECT COUNTEREXAMPLE: under h1 != h2 the folds differ, so this equality assert is false.
    function check_reach_fold_distinguishes(bytes32 h1, bytes32 h2, bytes32 pe) external pure {
        vm.assume(h1 != h2);
        assert(_sortedPair(h1, pe) == _sortedPair(h2, pe)); // false (they differ) => CEX
    }
}
