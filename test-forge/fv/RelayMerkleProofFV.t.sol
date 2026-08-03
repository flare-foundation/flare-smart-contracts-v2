// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // RelayTestBase

// Phase 3 Step 5 (M2 + M3/M8): Merkle PROOF-PATH soundness for the random-number proof
// (processRandomMerkleProof, Relay.sol:700-730). P4 (RelayRandomBindingFV) proved the LEAF VALUE cannot be
// forged; this proves the PROOF ELEMENTS cannot be forged either, and the calldata-alignment guard.
//   M2 — a proof element (sibling) different from the one committed under the signed root cannot reproduce
//        the root, so relay() rejects: the sorted-pair fold (Relay.sol:716-721) binds the proof path, not
//        just the leaf. (Decoupled: the signed root is built from `cs`; the trailer submits `ts`.)
//   M3/M8 — the trailer (randomNumber || proof) must be a whole number of 32-byte words (Relay.sol:701);
//        a misaligned proof is rejected "Incorrect merkle proof", and the fold loop consumes every element.
// Together with P4: neither the random value nor any proof element can be forged.
//
// CONFIG mirrors RelayRandomBindingFV: concrete N=3/weight-100/threshold-260, symbolic signatures, fixed
// same-epoch VRID, isSecure=true; a depth-1 (single-node) proof so the sibling IS the only proof element.
contract RelayMerkleProofFV is RelayTestBase {
    bytes internal policy;
    uint256 internal constant NV = 3;
    uint32 internal constant VRID = START_VOTING_ROUND_ID;

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT);
            pks.push(0);
        }
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = new Relay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
    }

    function _sortedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _leaf(uint256 value) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(VRID), value, uint256(1))); // isSecure = 1
    }

    function _sig(Sig calldata x, uint16 i) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, i);
    }

    function _three(Sig calldata a, Sig calldata b, Sig calldata c) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
    }

    // root committed with sibling `cs`; trailer carries value `val` and submitted sibling `ts`.
    function _relay(uint256 val, bytes32 cs, bytes32 ts, bytes memory extra, Sig calldata a, Sig calldata b, Sig calldata c)
        internal returns (bool ok)
    {
        bytes32 root = _sortedPair(_leaf(val), cs);
        bytes memory message = abi.encodePacked(RANDOM_PROTOCOL_ID, VRID, uint8(1), root);
        bytes memory trailer = abi.encodePacked(val, ts, extra); // randomNumber(32) || sibling(32) || extra
        (ok, ) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, message, _three(a, b, c), trailer));
    }

    // M2 — a submitted sibling different from the committed one cannot reproduce the root => reject.
    // EXPECT: PASS (proof).
    function check_m2_wrongSibling_cannotStore(
        uint256 val, bytes32 cs, bytes32 ts, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(ts != cs);
        assert(!_relay(val, cs, ts, "", a, b, c));
    }

    // M3/M8 — a misaligned trailer (one extra byte => proof not a whole number of 32-byte words) is rejected.
    // EXPECT: PASS (proof).
    function check_m3_misalignedProof_rejected(
        uint256 val, bytes32 cs, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        assert(!_relay(val, cs, cs, hex"00", a, b, c)); // correct sibling but +1 byte => "Incorrect merkle proof"
    }

    // Non-vacuity — the matching sibling (ts == cs), aligned, CAN finalize. EXPECT: COUNTEREXAMPLE.
    function check_reach_matchingProof(
        uint256 val, bytes32 cs, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        assert(!_relay(val, cs, cs, "", a, b, c));
    }
}
