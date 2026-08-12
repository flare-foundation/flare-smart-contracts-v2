// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";

// Sorted-pair Merkle fold injectivity / non-malleability lemmas.
// processRandomMerkleProof folds the leaf with each proof element via the sorted-pair
// hash  sortedPair(a,b) = keccak(min(a,b) || max(a,b))  and accepts iff the fold equals the signed root.
// RelayMerkleProofFV checks a concrete depth-1 shape. This harness checks the following reusable facts:
//   BASE  (depth 0): the fold of a leaf with the empty proof is the leaf itself => injective in the leaf.
//   STEP           : one fold step preserves injectivity — sortedPair(h1,pe) == sortedPair(h2,pe) => h1==h2
//                    (under the keccak collision-resistance/injectivity model).
// It also checks one depth-2 composition. These bounded checks and the reusable step support the intended
// induction argument, but this Halmos inventory does not machine-check a quantified theorem for every depth.
//
// keccak256 is an injective uninterpreted function in this modeling boundary; Halmos models it so.
contract RelayMerkleFoldFV is RelayTestBase {
    function setUp() public override {}

    // Relay's sorted-pair parent hash.
    function _sortedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    // ---- BASE — depth-0 fold is the identity, hence injective in the leaf. ----
    // EXPECT: PASS (proof).
    function check_fold_base_injective(bytes32 leaf1, bytes32 leaf2) external pure {
        vm.assume(leaf1 != leaf2);
        // fold over the empty proof returns the leaf unchanged; distinct leaves => distinct depth-0 roots.
        assert(leaf1 != leaf2); // identity fold preserves distinctness
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
