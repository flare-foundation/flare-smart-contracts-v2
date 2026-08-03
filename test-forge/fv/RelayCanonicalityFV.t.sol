// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // reuse RelayTestBase + encoding helpers

// Phase-1 PARAMETRIC proof of OBLIGATION P3 — Canonicality gating. See docs/relay-fv.md §4 (P3).
//
// Claim: a SINGLE signature whose registered weight w0 > threshold (i.e. it WOULD on its own suffice
// to finalize) must NOT let relay() accept if it is non-canonical:
//   - v not in {27,28}                      -> revert "Bad v"      (Relay.sol:1269-1273)
//   - s > secp256k1n/2 (high-s, EIP-2)       -> revert "Bad s"      (Relay.sol:1275-1280)
// Both guards fire BEFORE ecrecover and BEFORE the weight add at Relay.sol:1325, so the non-canonical
// signature contributes zero weight and the accept test (weight > threshold, Relay.sol:1330) is never
// reached. We prove this even though ecrecover is uninterpreted (assumption A2): the solver may freely
// set the recovered signer == voters[0] (the conservative worst case), yet acceptance is still
// impossible because the canonicality revert precedes the recovery entirely.
//
// HARNESS SHAPE (RelaySigParamFV in-check-deploy pattern): NV=1 voter, SYMBOLIC weight w0 and threshold
// thr, deployed INSIDE each check (empty setUp; the base setUp uses vm.addr/sorting -> multiple paths
// under Halmos). The single signature means the signature loop runs exactly ONCE (loopBoundNeeded = 1,
// well within halmos.toml loop = 6). Message is same-epoch (votingRoundId = START_VOTING_ROUND_ID) so
// the Relay.sol:976 threshold-increase path is inert. The reachability control is the anti-vacuity
// tripwire: a CANONICAL (v=27, low-s) single signature with w0 > thr MUST be able to accept, asserted
// as !accept EXPECTING A COUNTEREXAMPLE — if it ever PASSES the two negative proofs are vacuous.
//
// New to Halmos? See test-forge/fv/README.md §2 — a `check_` function is a ∀-proof over its symbolic
// arguments; `vm.assume` is a hypothesis, `assert` is the goal, and `check_p3_reachability_*` is the
// anti-vacuity control that verify_fv.py requires to be REFUTED by a counterexample.
contract RelayCanonicalityFV is RelayTestBase {
    bytes32 internal constant ROOT = keccak256("fv-root"); // concrete, non-zero (RLY-04)
    uint256 internal constant NV = 1;

    // secp256k1n / 2 (EIP-2 low-s bound). s STRICTLY GREATER than this is "Bad s" (Relay.sol:1277).
    uint256 internal constant HALF_N =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {}

    // Single-voter signing policy: prefix (43 bytes) then one (address, weight=w0) record.
    function _policy(uint16 w0, uint16 thr) internal pure returns (bytes memory p) {
        p = abi.encodePacked(
            uint16(NV), uint24(REWARD_EPOCH_ID), uint32(START_VOTING_ROUND_ID), thr, bytes32(SEED)
        );
        p = abi.encodePacked(p, address(uint160(0x1001)), w0);
    }

    function _deploy(uint16 w0, uint16 thr) internal returns (Relay r, bytes memory p) {
        p = _policy(w0, thr);
        r = new Relay(_initialConfig(_signingPolicyHash(p)), address(0), IRelay(address(0)));
    }

    function _sig(uint8 v, bytes32 r, bytes32 s, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(v, r, s, index);
    }

    // One symbolic signature at index 0, count = 1.
    function _oneSig(Sig calldata a) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(1), _sig(a.v, a.r, a.s, 0));
    }

    function _call(Relay r, bytes memory p, bytes memory sigs) internal returns (bool ok) {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, ROOT); // Mode-2, protocolId 3
        (ok, ) = address(r).call(abi.encodePacked(Relay.relay.selector, p, message, sigs));
    }

    // ---- P3.a — bad v: v not in {27,28} cannot accept, even when w0 > thr. EXPECT: PASS. ----
    // The "Bad v" revert (Relay.sol:1269) precedes the weight add (:1325), so no acceptance is possible.
    // w0 > thr supplies the "would otherwise suffice" premise; v is fully symbolic, ASSUMED non-canonical.
    // Reads as: ∀ w0,thr,a . (v∉{27,28} ∧ w0>thr) ⟹ ¬accept. The first assume restricts the ∀ to
    // non-canonical v (the case under test); the second supplies the "would otherwise suffice" premise
    // so a PASS is not vacuous by weight. PASS ⟹ no bad-v signature can finalize even at winning weight.
    function check_p3_badV_cannotAccept(uint16 w0, uint16 thr, Sig calldata a) external {
        vm.assume(a.v != 27 && a.v != 28); // v & 0xff == v for uint8, so this is the exact bad-v set
        vm.assume(uint256(w0) > uint256(thr)); // single signature alone exceeds the threshold
        (Relay r, bytes memory p) = _deploy(w0, thr);
        assert(!_call(r, p, _oneSig(a)));
    }

    // ---- P3.b — high s: s > secp256k1n/2 cannot accept, even with canonical v and w0 > thr. PASS. ----
    // The "Bad s" revert (Relay.sol:1275) precedes the weight add (:1325). v is pinned canonical (27)
    // so ONLY the s-malleability gate can be responsible for rejection; s is symbolic, ASSUMED high.
    // EXPECT: PASS (proof).
    function check_p3_highS_cannotAccept(uint16 w0, uint16 thr, bytes32 s) external {
        vm.assume(uint256(s) > HALF_N); // EIP-2 high-s half: rejected by Relay.sol:1277
        vm.assume(uint256(w0) > uint256(thr));
        (Relay r, bytes memory p) = _deploy(w0, thr);
        bytes memory sigs = abi.encodePacked(uint16(1), _sig(27, bytes32(uint256(0xa11ce)), s, 0));
        assert(!_call(r, p, sigs));
    }

    // ---- Non-vacuity control — a CANONICAL single signature with w0 > thr CAN accept. ----
    // v = 27 (canonical), s <= secp256k1n/2 (low-s, here a small concrete value), w0 > thr. ecrecover is
    // uninterpreted so the solver may match recovered == voters[0]; the canonicality gates pass, the
    // weight add fires, weight = w0 > thr accepts. Asserting !accept must therefore yield a
    // COUNTEREXAMPLE. If this PASSES, the loop bound is too small or the accept path is otherwise
    // unreachable and P3.a/P3.b are vacuous. EXPECT: COUNTEREXAMPLE.
    function check_p3_reachability_canonicalAccepts(uint16 w0, uint16 thr, bytes32 r_) external {
        vm.assume(uint256(w0) > uint256(thr));
        (Relay r, bytes memory p) = _deploy(w0, thr);
        // v=27 canonical; s = 1 is well below secp256k1n/2 (low-s); r symbolic so ecrecover can match.
        // Inverted contract: this assert MUST be refuted. Because ecrecover is uninterpreted the solver is
        // free to set recovered == voters[0], so a canonical winning-weight sig reaches acceptance and the
        // witness (a concrete r_) proves the two P3 negatives above rule out something actually reachable.
        bytes memory sigs = abi.encodePacked(uint16(1), _sig(27, r_, bytes32(uint256(1)), 0));
        assert(!_call(r, p, sigs)); // EXPECT counterexample (canonical acceptance is reachable)
    }
}
