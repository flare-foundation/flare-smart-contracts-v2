// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // reuse RelayTestBase + encoding helpers

// Phase-1 symbolic proof of OBLIGATION P5 — isSecure normalization (RLY-14). See docs/relay-fv.md §4 (P5).
//
// CLAIM. For the random-number protocol (protocolId == RANDOM_PROTOCOL_ID = 2, a Mode-2 relay carrying the
// random trailer randomNumber||proof), let `b` be the raw isSecureRandom byte in the signed message
// (Relay.sol message layout :103-108: protocolId(1)||votingRoundId(4)||isSecureRandom(1)||merkleRoot(32)).
// The contract normalizes it once, `isSecure := iszero(iszero(b))` (Relay.sol:1450-1456), i.e. isSecure ==
// (b != 0), and then uses that SAME local in every sink:
//   - the Merkle LEAF hash  keccak256(abi.encode(votingRoundId, value, isSecure))  (processRandomMerkleProof
//     :704-708, fed isSecure at :1469),
//   - the historical bit  isSecureRandomMap[vrid/256] bit (vrid%256)  (set iff isSecure, :1473-1475 via
//     setIsSecureRandomBit :674-686),
//   - the live  stateData.isSecureRandom  (assignStruct at :1499-1501, first-round branch),
//   - the emitted ProtocolMessageRelayed / RandomNumberRelayed bool (:1508, :1526).
// We prove the three on-chain SINKS that are externally observable all equal (b != 0):
//   (S1) getRandomNumberHistorical(vrid)._isSecureRandom  — reads the stored isSecureRandomMap bit (:1681-1683),
//   (S2) getRandomNumber()._isSecureRandom               — reads stateData.isSecureRandom (:1653),
//   (S3) the LEAF isSecure — established BY CONSTRUCTION + injective keccak (A1): the message's signed
//        merkleRoot is built here as sortedPair(randomLeaf(vrid, value, b != 0), sibling); relay() recomputes
//        the leaf from ITS normalized isSecure and reverts ("Invalid random number proof", :723) unless the
//        recomputed root equals the signed root. So a NON-reverting (accepting) run forces the contract's leaf
//        to equal randomLeaf(vrid, value, b != 0); under A1 (keccak injective) its leaf-isSecure == (b != 0).
//        We do not read the contract's internal leaf word directly (see CAVEATS) — S3 is the "proof verifies
//        with a root committed to (b != 0)" argument, machine-checked via reachability of the accept path.
//
// HOW WE PROVE IT. The isSecure byte `b` is a SYMBOLIC uint8 (free over 0..255, so 0,1,2,.. are all covered).
// Each proof check executes relay() via a low-level call and asserts  success => sink == (b != 0)  as
// `assert(!ok || sink == (b != 0))`. Because the assertion only constrains the success branch it is VACUOUS
// unless the accept path is reachable for that `b`; so the proofs are PAIRED with reachability controls that
// `assert(!ok)` at the SAME shape, EXPECTED TO PRODUCE A COUNTEREXAMPLE (an ok==true witness) — one for b==0
// (insecure) and one for b!=0 (secure), pinning that BOTH normalization outcomes are reachable. An unexpected
// reachability PASS means the accept path is unreachable (e.g. loop bound too small) and the paired proof is
// vacuous — treat it as a hard failure.
//
// WHY THE PROOF VERIFIES FOR ALL b. The signed merkleRoot here is built with the SAME normalization the
// contract uses (randomLeaf(.., b != 0)). relay()'s leaf recompute uses isSecure == (b != 0) too, so the
// recomputed root equals the signed root for every b and the proof passes — acceptance does not depend on the
// concrete byte, exactly the RLY-14 normalization we are checking. The 2-leaf tree [randomLeaf, sibling] gives
// a 1-node proof, so the Merkle fold loop (:709-722) runs once.
//
// CONFIG. Fully-concrete signing policy (no vm.addr/vm.sign/sorting -> single deterministic setUp path under
// Halmos): N=3 voters weight 100 each (total 300) > threshold 260, so 3 distinct signatures suffice to accept.
// Only the SIGNATURES (v,r,s) and the isSecure byte are symbolic; ecrecover is the uninterpreted function E
// (assumption A2), so the solver may freely set E(h,v_i,r_i,s_i) = voters[i] (the conservative worst case) and
// no real keypairs are needed. votingRoundId = START_VOTING_ROUND_ID maps to the policy's own reward epoch via
// rewardEpochIdFromVotingRoundId ((3360-0)/3360 = 1 = REWARD_EPOCH_ID), so the same-epoch path is taken and the
// threshold-increase block (Relay.sol:960/976) is never entered; this is the FIRST random relay so
// randomVotingRoundId starts at 0 < START_VOTING_ROUND_ID and the live-pointer/stateData.isSecureRandom write
// at :1482-1504 fires (S2 is meaningful). The signature loop runs once per signature (3 sigs) and the Merkle
// fold once (1-node proof): max loop depth 3 <= halmos.toml loop = 6 (loopBoundNeeded = 3).
contract RelayIsSecureNormFV is RelayTestBase {
    bytes internal policy;
    uint256 internal constant NV = 3;

    // Concrete random-relay parameters (only isSecure byte + signatures are symbolic).
    uint32 internal constant VRID = START_VOTING_ROUND_ID; // same-epoch -> reward epoch 1, first random round
    uint256 internal constant VALUE = 0xCAFE;              // concrete relayed random value
    bytes32 internal constant SIBLING = keccak256("fv-sibling"); // concrete proof sibling

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    // Fully-concrete setUp (no vm.addr/vm.sign/sorting) so the deploy is a single deterministic path.
    // N=3 voters, weight 100 each (total 300) > threshold 260: three distinct signatures can finalize.
    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 100 each
            pks.push(0); // unused (ecrecover uninterpreted)
        }
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = new Relay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
    }

    // ---- Merkle helpers mirroring the contract (RelayRandomTest._sortedPair/_randomLeaf), kept local
    //      because they live on RelayRandomTest, not RelayTestBase. ----

    // OpenZeppelin sorted-pair parent hash (matches processRandomMerkleProof :716-721).
    function _sortedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    // leaf = keccak256(abi.encode(votingRoundId, value, isSecure)) — mirrors Relay.sol:704-708
    // (abi.encode left-pads each field to 32 bytes; isSecure encoded as 1/0).
    function _randomLeaf(uint32 vrid, uint256 value, bool isSecure) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(vrid), value, uint256(isSecure ? 1 : 0)));
    }

    function _sig(Sig calldata x, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, index);
    }

    // Three signatures at strictly-increasing indices 0,1,2 (so the strict-index guard at Relay.sol:1261
    // passes and all three weights are counted -> 300 > 260 -> accept on the third signature).
    function _threeSigs(Sig calldata a, Sig calldata b, Sig calldata c) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
    }

    // Build the full relay() calldata for a random-protocol message with raw isSecure byte `isSecureByte`,
    // whose signed merkleRoot is the 2-leaf tree over randomLeaf(VRID, VALUE, leafBit). Decoupling the
    // LEAF bit from the message byte lets us machine-check the contract's leaf normalization (see
    // check_leafNorm_machineChecked): the contract recomputes its leaf from ITS rule (b != 0) and reverts
    // unless that reproduces this root, so acceptance forces (b != 0) == leafBit.
    // Layout: selector || policy || message(38) || sigs || trailer(value||sibling).
    function _randomCalldataLeaf(uint8 isSecureByte, bool leafBit, bytes memory sigs) internal view returns (bytes memory) {
        bytes32 root = _sortedPair(_randomLeaf(VRID, VALUE, leafBit), SIBLING);
        bytes memory message = abi.encodePacked(RANDOM_PROTOCOL_ID, VRID, isSecureByte, root); // 38 bytes
        bytes memory trailer = abi.encodePacked(VALUE, SIBLING); // randomNumber(32) || proof(1 node)
        return abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer);
    }

    // Default: signed root built with the contract's own normalization (b != 0) — for the S1/S2/cross sinks.
    function _randomCalldata(uint8 isSecureByte, bytes memory sigs) internal view returns (bytes memory) {
        return _randomCalldataLeaf(isSecureByte, isSecureByte != 0, sigs);
    }

    function _relay(uint8 isSecureByte, Sig calldata a, Sig calldata b, Sig calldata c) internal returns (bool ok) {
        (ok, ) = address(relay).call(_randomCalldata(isSecureByte, _threeSigs(a, b, c)));
    }

    function _relayLeaf(uint8 isSecureByte, bool leafBit, Sig calldata a, Sig calldata b, Sig calldata c)
        internal returns (bool ok)
    {
        (ok, ) = address(relay).call(_randomCalldataLeaf(isSecureByte, leafBit, _threeSigs(a, b, c)));
    }

    // ===================== P5 proofs: every observable isSecure sink == (b != 0) =====================

    // P5.S1 — historical stored bit: accepting run => getRandomNumberHistorical(VRID)._isSecureRandom == (b != 0).
    // Reads the persisted isSecureRandomMap bit (Relay.sol:1681-1683), set iff isSecure at :1473-1475.
    // EXPECT: PASS.
    function check_historicalSecure_eq_byteNonZero(
        uint8 isSecureByte, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        bool ok = _relay(isSecureByte, a, b, c);
        if (ok) {
            (, bool sec, ) = relay.getRandomNumberHistorical(VRID);
            assert(sec == (isSecureByte != 0));
        }
    }

    // P5.S2 — live flag: accepting run => getRandomNumber()._isSecureRandom == (b != 0).
    // Reads stateData.isSecureRandom (Relay.sol:1653), written from isSecure in the first-round branch
    // :1499-1501 (VRID > 0 = initial randomVotingRoundId, so the branch fires). EXPECT: PASS.
    function check_liveSecure_eq_byteNonZero(
        uint8 isSecureByte, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        bool ok = _relay(isSecureByte, a, b, c);
        if (ok) {
            (, bool sec, ) = relay.getRandomNumber();
            assert(sec == (isSecureByte != 0));
        }
    }

    // P5.cross — the two persisted sinks agree with each other on every accepting run (no path stores the
    // historical bit and the live flag inconsistently). EXPECT: PASS.
    function check_liveAndHistorical_agree(
        uint8 isSecureByte, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        bool ok = _relay(isSecureByte, a, b, c);
        if (ok) {
            (, bool live, ) = relay.getRandomNumber();
            (, bool hist, ) = relay.getRandomNumberHistorical(VRID);
            assert(live == hist);
        }
    }

    // P5.S3 (machine-checked) — LEAF normalization is exactly (b != 0), for all b in 0..255.
    // We build the signed root from an INDEPENDENT symbolic leaf bit `lb` (decoupled from the message byte
    // b). The contract recomputes its leaf from ITS rule and reverts (Relay.sol:723) unless the recomputed
    // root equals this signed root; by injective keccak (A1, same VRID/VALUE) acceptance holds iff the
    // contract's leaf-isSecure equals `lb`. Therefore `accept => (b != 0) == lb` MACHINE-CHECKS that the
    // contract's leaf rule is exactly (b != 0): a divergent rule (e.g. b & 1) would let some (b, lb) accept
    // with lb != (b != 0), refuting the assertion. EXPECT: PASS. (Upgrades the former by-construction S3.)
    function check_leafNorm_machineChecked(
        uint8 isSecureByte, uint8 lb, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(lb <= 1); // lb is an independent leaf bit in {0,1}
        bool ok = _relayLeaf(isSecureByte, lb == 1, a, b, c);
        assert(!ok || ((isSecureByte != 0) == (lb == 1)));
    }

    // ===================== reachability controls (anti-vacuity tripwires) =====================
    // The S1/S2/cross proofs only constrain the success branch, so they are vacuous unless the accept path is
    // reachable. These assert(!ok) and are EXPECTED TO PRODUCE A COUNTEREXAMPLE (ok==true witness). We pin BOTH
    // normalization outcomes: b == 0 (insecure leaf) and b == 1 (secure leaf) must each finalize. If either
    // PASSES, the accept path is unreachable for that branch (loop bound too small / proof obligation broken)
    // and the paired proofs are vacuous — treat an unexpected reachability PASS as a hard failure.

    // Reachability for the INSECURE normalization (b == 0): leaf uses isSecure = false. EXPECT: COUNTEREXAMPLE.
    function check_reach_insecure_canAccept(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bool ok = _relay(0, a, b, c);
        assert(!ok);
    }

    // Reachability for the SECURE normalization (b == 1): leaf uses isSecure = true. EXPECT: COUNTEREXAMPLE.
    function check_reach_secure_canAccept(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bool ok = _relay(1, a, b, c);
        assert(!ok);
    }

    // Reachability at a HIGH byte (b > 1): pins that the secure normalization accept path is reachable for a
    // representative byte where (b != 0) and low-bit rules would DIVERGE — so check_leafNorm_machineChecked
    // cannot pass vacuously over b in 2..255. leaf bit = true = (b != 0). EXPECT: COUNTEREXAMPLE.
    function check_reach_highByte_canAccept(uint8 isSecureByte, Sig calldata a, Sig calldata b, Sig calldata c) external {
        vm.assume(isSecureByte > 1);
        bool ok = _relayLeaf(isSecureByte, true, a, b, c); // leafBit = (b != 0) = true
        assert(!ok);
    }
}