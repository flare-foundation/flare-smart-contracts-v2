// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";

// Signing-policy digest equivalence (Halmos, bounded symbolic).
//
// Relay commits to an encoded policy with exactly one digest:
//
//     keccak256(abi.encodePacked(sourceChainId, encodedPolicy))
//
// `sourceChainId` occupies one full 32-byte word and the policy follows immediately without
// padding. The production assembly implements this in `calculateSigningPolicyHash`: it writes the
// source id into the dedicated M_9 scratch region, copies the raw policy bytes after it, and hashes
// exactly `32 + policy.length` bytes. The reference below uses Solidity's `abi.encodePacked`.
//
// The production helper is internal to `relay()`, so the observable oracle is its exact
// `SigningPolicyHashMismatch()` failure. Each proof initializes Relay with the Solidity reference
// digest for symbolic policy bytes P, then submits P. The assembly digest is checked before protocol
// parsing and signature verification. If the assembly and reference preimages differ at any byte or
// length, Halmos can assign different results to the corresponding uninterpreted-keccak terms and
// reach the mismatch failure. A proof therefore establishes byte-for-byte and length equivalence for
// the stated policy shape; it does not assume collision resistance.
//
// The three shapes cover policy lengths 65, 87, and 109 bytes. Their seed, threshold, voter addresses,
// and weights are symbolic. Reward epoch, starting round, and voter count remain concrete so the
// initializer lookup and calldata shape are fixed. Deployment happens inside each check because the
// stored digest depends on symbolic bytes. `setUp()` is empty to avoid symbolic branching in the base
// fixture.
//
// The reachability control flips one bit of the reference digest. Once equivalence holds, the stored
// and computed words are necessarily different, so Relay must emit the exact mismatch selector. This
// demonstrates that the oracle and hash-check path are live.
contract RelayPolicyHashFV is RelayTestBase {
    // True iff the call result is EXACTLY the SigningPolicyHashMismatch() revert. Any other
    // revert reason, or success, returns false — so the assertions speak only about THIS revert.
    function _isHashMismatch(bool ok, bytes memory ret) internal pure returns (bool) {
        if (ok) return false;
        if (ret.length != 4) return false;
        bytes4 actual;
        assembly {
            actual := mload(add(ret, 0x20))
        }
        return actual == IRelay.SigningPolicyHashMismatch.selector;
    }

    function setUp() public override {}

    function _referencePolicyHash(bytes memory policy) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(block.chainid, policy));
    }

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
    // The hash check is reached before signature processing, so zero signatures suffice; any later
    // failure is intentionally distinguished from SigningPolicyHashMismatch().
    function _callRelay(bytes32 storedHash, bytes memory p) internal returns (bool ok, bytes memory ret) {
        Relay r = deployRelay(_initialConfig(storedHash), address(0), IRelay(address(0)));
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("fv-root"));
        bytes memory sigs = abi.encodePacked(uint16(0)); // zero signatures: count prefix only
        (ok, ret) = address(r).call(abi.encodePacked(Relay.relay.selector, p, message, sigs));
    }

    // ============================ EQUIVALENCE PROOFS (EXPECT: PASS) ============================
    // Stored hash = the Solidity reference digest of the SAME symbolic bytes. The contract recomputes
    // it in assembly; any source-prefix, content, or length disagreement can trigger the mismatch.

    // Hash equivalence at NV=1: the assembly-recomputed policy hash equals the reference digest for ALL
    // symbolic 1-voter policy bytes (seed/threshold/address/weight). EXPECT: PASS (proof).
    function check_policyHash_equiv_NV1(bytes32 seed, uint16 thr, address a0, uint16 w0) external {
        bytes memory p = _policy1(seed, thr, a0, w0);
        bytes32 stored = _referencePolicyHash(p);
        vm.assume(stored != bytes32(0)); // initialize rejects a zero policy commitment
        (bool ok, bytes memory ret) = _callRelay(stored, p);
        assert(!_isHashMismatch(ok, ret));
    }

    // Hash equivalence at NV=2: same equivalence over all symbolic 2-voter policies. EXPECT: PASS (proof).
    function check_policyHash_equiv_NV2(
        bytes32 seed, uint16 thr, address a0, uint16 w0, address a1, uint16 w1
    ) external {
        bytes memory p = _policy2(seed, thr, a0, w0, a1, w1);
        bytes32 stored = _referencePolicyHash(p);
        vm.assume(stored != bytes32(0));
        (bool ok, bytes memory ret) = _callRelay(stored, p);
        assert(!_isHashMismatch(ok, ret));
    }

    // Hash equivalence at NV=3: same equivalence over all symbolic 3-voter policies. EXPECT: PASS (proof).
    function check_policyHash_equiv_NV3(
        bytes32 seed, uint16 thr, address a0, uint16 w0, address a1, uint16 w1, address a2, uint16 w2
    ) external {
        bytes memory p = _policy3(seed, thr, a0, w0, a1, w1, a2, w2);
        bytes32 stored = _referencePolicyHash(p);
        vm.assume(stored != bytes32(0));
        (bool ok, bytes memory ret) = _callRelay(stored, p);
        assert(!_isHashMismatch(ok, ret));
    }

    // =================== ANTI-VACUITY TRIPWIRE (EXPECT: COUNTEREXAMPLE) ========================
    // Stored hash = reference digest XOR 1 — provably distinct from the assembly result once the
    // equivalence proofs hold. The exact mismatch failure must therefore be reachable.

    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_policyHash_mismatchReachable_NV3(
        bytes32 seed, uint16 thr, address a0, uint16 w0, address a1, uint16 w1, address a2, uint16 w2
    ) external {
        bytes memory p = _policy3(seed, thr, a0, w0, a1, w1, a2, w2);
        bytes32 stored = bytes32(uint256(_referencePolicyHash(p)) ^ 1);
        vm.assume(stored != bytes32(0));
        (bool ok, bytes memory ret) = _callRelay(stored, p);
        assert(!_isHashMismatch(ok, ret)); // EXPECT counterexample (mismatch revert IS reachable)
    }
}
