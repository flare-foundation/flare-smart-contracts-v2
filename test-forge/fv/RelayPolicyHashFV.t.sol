// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";

// ============================================================================================
// P8 — Signing-policy-hash equivalence (Halmos, bounded symbolic). See docs/relay-fv.md §4 (P8).
//
// OBLIGATION. The contract computes the signing-policy hash in inline assembly via
// `calculateSigningPolicyHash` (Relay.sol:574-602): h = policy[0:32], then fold each subsequent
// 32-byte calldata chunk (h = keccak(h || chunk)), then fold the final partial chunk zero-padded
// on the right. The harness base has a Solidity reference reimplementation `_signingPolicyHash`
// (Relay.t.sol:111-128) cross-checked DYNAMICALLY (single concrete policy) by
// `test_signingPolicyHash_matchesContract`. P8 LIFTS that to a SYMBOLIC proof: for symbolic
// policy content (symbolic seed / threshold / voter addresses / weights, fixed small voter count)
// prove `calculateSigningPolicyHash(packedBytes) == _signingPolicyHash(packedBytes)`.
//
// ORACLE (no contract change; assembly fn, not the setSigningPolicy Solidity fold). In `relay()`
// the contract computes `calculateSigningPolicyHash` over the calldata signing policy
// (Relay.sol:802) and compares it to the stored hash `toSigningPolicyHashPrivate[rewardEpochId]`
// (Relay.sol:822), reverting EXACTLY "Signing policy hash mismatch" (Relay.sol:828) iff they
// differ. We deploy with the constructor's `initialSigningPolicyHash` set to the REFERENCE fold
// `_signingPolicyHash(P)` of the same symbolic policy bytes P (constructor stores it verbatim at
// Relay.sol:258, no threshold validation on this path — `checkThresholdConsistency` is Mode-1
// only). Then we call `relay()` with P in calldata. The hash check (Relay.sol:822) is reached
// BEFORE protocolId parsing / any signature work, so it is exercised regardless of the rest of
// the message. Hence:
//     relay() can revert "Signing policy hash mismatch"  <=>  calculateSigningPolicyHash(P) != _signingPolicyHash(P).
// Proving the mismatch revert is UNREACHABLE proves the equivalence.
//
// WHY NON-VACUOUS UNDER UNINTERPRETED keccak (A1). Both folds invoke the SAME uninterpreted
// keccak. By functional consistency, equal inputs through an identical sequence of keccak calls
// give equal outputs; if the assembly and reference folds disagreed on ANY byte or in the
// chunking / call sequence, the solver (which freely picks keccak outputs) would exhibit a
// counterexample. So PASS <=> the two folds are byte- and call-identical. Injectivity of keccak
// (A1) makes "returndata == the exact mismatch blob" a faithful test of hash inequality.
//
// ANTI-VACUITY (pitfall 4). `check_policyHash_mismatchReachable_*` deploys with the stored hash
// set to `_signingPolicyHash(P) ^ 1` (one bit flipped) so the stored hash provably differs from
// the assembly hash (given the equivalence the other checks establish, calc == ref != ref^1), and
// asserts `!mismatch` EXPECTING A COUNTEREXAMPLE. This proves the hash-check path (Relay.sol:822)
// is genuinely reached and the "Signing policy hash mismatch" revert fires and is detectable — so
// the equivalence PASSes are not vacuous (e.g. from the path being unreachable).
//
// LOOP BOUND. The assembly chunk-fold loop runs `floor(policyLength/32) - 1` iterations plus one
// remainder fold; the reference loop matches it. For voter counts NV in {1,2,3} the packed length
// is 43 + 22*NV in {65, 87, 109}, so the loop runs at most floor(109/32)-1 = 2 iterations — well
// within halmos.toml `loop = 6`. NV=3 (length 109) exercises BOTH multiple full-chunk folds AND a
// non-trivial 13-byte remainder; NV=1/NV=2 add boundary coverage (1 full-chunk fold + remainder).
//
// SETUP. Empty `setUp()` (base setUp uses vm.addr/sorting -> multiple paths under Halmos); the
// relay is deployed INSIDE each check because the stored hash depends on symbolic policy content.
// rewardEpochId / startVotingRoundId / numberOfVoters are CONCRETE (numberOfVoters drives the
// fixed loop count; rewardEpochId must match the constructor so the stored-hash lookup hits our
// slot). seed, threshold, every voter address and every weight are SYMBOLIC.
// ============================================================================================
contract RelayPolicyHashFV is RelayTestBase {
    // Exact canonical four-byte custom-error payload emitted by relay() assembly.
    // The selector is tied to IRelay.SigningPolicyHashMismatch by the custom-error ABI gate.
    function _mismatchReturndata() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IRelay.SigningPolicyHashMismatch.selector);
    }

    // True iff the call result is EXACTLY the "Signing policy hash mismatch" revert. Any other
    // revert reason, or success, returns false — so the assertions speak only about THIS revert.
    function _isHashMismatch(bool ok, bytes memory ret) internal pure returns (bool) {
        if (ok) return false;
        bytes memory expected = _mismatchReturndata();
        if (ret.length != expected.length) return false;
        return keccak256(ret) == keccak256(expected); // A1: injective keccak => exact-bytes equality
    }

    function setUp() public override {}

    // ----- symbolic policy packers (concrete numVoters, rewardEpochId, startVotingRoundId) -----

    function _policy1(bytes32 seed, uint16 thr, address a0, uint16 w0) internal pure returns (bytes memory p) {
        p = abi.encodePacked(uint16(1), uint24(REWARD_EPOCH_ID), uint32(START_VOTING_ROUND_ID), thr, seed);
        p = abi.encodePacked(p, a0, w0);
    }

    function _policy2(bytes32 seed, uint16 thr, address a0, uint16 w0, address a1, uint16 w1)
        internal pure returns (bytes memory p)
    {
        p = abi.encodePacked(uint16(2), uint24(REWARD_EPOCH_ID), uint32(START_VOTING_ROUND_ID), thr, seed);
        p = abi.encodePacked(p, a0, w0, a1, w1);
    }

    function _policy3(
        bytes32 seed, uint16 thr,
        address a0, uint16 w0, address a1, uint16 w1, address a2, uint16 w2
    ) internal pure returns (bytes memory p) {
        p = abi.encodePacked(uint16(3), uint24(REWARD_EPOCH_ID), uint32(START_VOTING_ROUND_ID), thr, seed);
        p = abi.encodePacked(p, a0, w0, a1, w1, a2, w2);
    }

    // Deploy a relay whose stored hash for REWARD_EPOCH_ID is `storedHash`, then call relay() with
    // the given policy bytes + a same-epoch Mode-2 message (protocolId 3) + an empty signature block.
    // The hash check (Relay.sol:822) is reached before any signature processing, so 0 signatures
    // suffice; any later revert ("Verification failed", etc.) is NOT the mismatch revert.
    function _callRelay(bytes32 storedHash, bytes memory p) internal returns (bool ok, bytes memory ret) {
        Relay r = deployRelay(_initialConfig(storedHash), address(0), IRelay(address(0)));
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("fv-root"));
        bytes memory sigs = abi.encodePacked(uint16(0)); // zero signatures: count prefix only
        (ok, ret) = address(r).call(abi.encodePacked(Relay.relay.selector, p, message, sigs));
    }

    // ============================ EQUIVALENCE PROOFS (EXPECT: PASS) ============================
    // Stored hash = reference fold of the SAME symbolic bytes. The contract recomputes the hash in
    // assembly over the identical calldata bytes; if `calculateSigningPolicyHash != _signingPolicyHash`
    // for any assignment the solver would trigger the mismatch revert. PASS => provable equivalence.

    // Hash equivalence at NV=1: the assembly-recomputed policy hash equals the reference fold for ALL
    // symbolic 1-voter policy bytes (seed/threshold/address/weight). EXPECT: PASS (proof).
    function check_policyHash_equiv_NV1(bytes32 seed, uint16 thr, address a0, uint16 w0) external {
        bytes memory p = _policy1(seed, thr, a0, w0);
        bytes32 stored = _signingPolicyHash(p);
        vm.assume(stored != bytes32(0)); // L-4 constructor guard (Relay.sol:240)
        (bool ok, bytes memory ret) = _callRelay(stored, p);
        assert(!_isHashMismatch(ok, ret));
    }

    // Hash equivalence at NV=2: same equivalence over all symbolic 2-voter policies. EXPECT: PASS (proof).
    function check_policyHash_equiv_NV2(
        bytes32 seed, uint16 thr, address a0, uint16 w0, address a1, uint16 w1
    ) external {
        bytes memory p = _policy2(seed, thr, a0, w0, a1, w1);
        bytes32 stored = _signingPolicyHash(p);
        vm.assume(stored != bytes32(0));
        (bool ok, bytes memory ret) = _callRelay(stored, p);
        assert(!_isHashMismatch(ok, ret));
    }

    // Hash equivalence at NV=3: same equivalence over all symbolic 3-voter policies. EXPECT: PASS (proof).
    function check_policyHash_equiv_NV3(
        bytes32 seed, uint16 thr, address a0, uint16 w0, address a1, uint16 w1, address a2, uint16 w2
    ) external {
        bytes memory p = _policy3(seed, thr, a0, w0, a1, w1, a2, w2);
        bytes32 stored = _signingPolicyHash(p);
        vm.assume(stored != bytes32(0));
        (bool ok, bytes memory ret) = _callRelay(stored, p);
        assert(!_isHashMismatch(ok, ret));
    }

    // =================== ANTI-VACUITY TRIPWIRE (EXPECT: COUNTEREXAMPLE) ========================
    // Stored hash = (reference fold) XOR 1 — provably distinct from the assembly hash (given the
    // equivalence above, calc == ref, and ref != ref^1). The contract MUST revert
    // "Signing policy hash mismatch", so `_isHashMismatch` is true and `assert(!_isHashMismatch)`
    // FAILS. A counterexample here proves the hash-check path is reached and the detector fires;
    // if this ever PASSES the equivalence proofs are vacuous (path unreachable / loop truncated).

    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_policyHash_mismatchReachable_NV3(
        bytes32 seed, uint16 thr, address a0, uint16 w0, address a1, uint16 w1, address a2, uint16 w2
    ) external {
        bytes memory p = _policy3(seed, thr, a0, w0, a1, w1, a2, w2);
        bytes32 stored = bytes32(uint256(_signingPolicyHash(p)) ^ 1); // flip one bit => guaranteed mismatch
        vm.assume(stored != bytes32(0));
        (bool ok, bytes memory ret) = _callRelay(stored, p);
        assert(!_isHashMismatch(ok, ret)); // EXPECT counterexample (mismatch revert IS reachable)
    }
}
