// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // reuse RelayTestBase + encoding helpers

// Phase-1 symbolic proof of OBLIGATION P6 — the 35-byte return discriminator. See docs/relay-fv.md §4 (P6).
//
// CLAIM: among relay()'s accepting paths, ONLY the protocolId==1 (custom-signature) path returns 35 bytes
// (32-byte merkleRoot/hash + 3-byte rewardEpochId, Relay.sol:1352-1362, `return(memPtrFor, add(32,
// REWARD_EPOCH_ID_BYTES))` = 32+3 = 35). The protocolId>1 path (Mode-2, here protocolId==3) returns 0 bytes
// on success (`return(0,0)` at Relay.sol:1432, the non-random-protocol branch since 3 != randomNumberProtocolId
// = RANDOM_PROTOCOL_ID = 2) or reverts. This is exactly the length `_verifyCustomSignature` relies on as the
// discriminator (Relay.sol:1736 `require(returnData.length == 35)`, anchor RLY-07 at :1352-1356 / :1734).
//
// HOW WE PROVE IT (returndata-length capture): each check calls relay() via a low-level `call` so it can read
// the raw returndata length. The properties are of the form `success => returndatalen == L`, asserted as
// `assert(!ok || rdlen == L)`. A PASS means: on EVERY accepting path of that protocolId, the returndata length
// is exactly L. Because the assertion only constrains the success branch, it is VACUOUS unless the accept path
// is reachable — so every such check is PAIRED with a reachability control `assert(!ok)` at the SAME config,
// which is EXPECTED TO PRODUCE A COUNTEREXAMPLE (proving acceptance fires). If a reachability control ever
// PASSES, the loop bound is too small (or the accept path is otherwise unreachable) and the paired proof is
// vacuous — treat an unexpected reachability PASS as a hard failure.
//
// CONFIG: fully-concrete signing policy (no vm.addr/vm.sign/sorting -> single deterministic setUp path under
// Halmos), N=3 voters weight 100 each (total 300) > threshold 260, so 3 distinct signatures suffice to accept.
// Only the SIGNATURES (v,r,s) are symbolic; ecrecover is the uninterpreted function E (assumption A2), so the
// solver may freely set E(h,v_i,r_i,s_i) = voters[i] (the conservative worst case) and no real keypairs are
// needed. The signature loop runs once per signature; with 3 signatures we stay within halmos.toml `loop = 6`
// (loopBoundNeeded = 3). For protocolId==1 the message is (1, votingRoundId=0, isSecure=0, ROOT) as required by
// Relay.sol:894-910 (both votingRoundId and isSecureRandom must be 0). For protocolId==3 the message uses
// votingRoundId = START_VOTING_ROUND_ID, which maps to the policy's own reward epoch via
// rewardEpochIdFromVotingRoundId ((3360-0)/3360 = 1 = REWARD_EPOCH_ID), so the same-epoch path is taken: the
// "Wrong sign policy reward epoch"/"Message too old"/"Delayed sign policy" guards (Relay.sol:925/931/956) pass
// and the messageRewardEpochId > rewardEpochId threshold-increase block (Relay.sol:960) is never entered.
contract RelayReturnDiscriminatorFV is RelayTestBase {
    bytes internal policy;
    bytes32 internal constant ROOT = keccak256("fv-root"); // concrete, non-zero (RLY-04; only matters for pid>1)
    uint256 internal constant NV = 3;

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

    function _sig(Sig calldata x, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, index);
    }

    // Three signatures at strictly-increasing indices 0,1,2 (so the strict-index guard at Relay.sol:1261
    // passes and all three weights are counted -> 300 > 260 -> accept on the third signature).
    function _threeSigs(Sig calldata a, Sig calldata b, Sig calldata c) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
    }

    // Low-level relay() call for an arbitrary 38-byte message; returns (ok, returndata length).
    function _call(bytes memory message, bytes memory sigs) internal returns (bool ok, uint256 rdlen) {
        bytes memory cd = abi.encodePacked(Relay.relay.selector, policy, message, sigs);
        bytes memory rd;
        (ok, rd) = address(relay).call(cd);
        rdlen = rd.length;
    }

    // ===================== protocolId == 1 (custom-signature) path =====================

    // P6.a — protocolId==1 success => returndata length is EXACTLY 35.
    // EXPECT: PASS. (Anchors Relay.sol:1352-1362 / RLY-07 :1734; underpins _verifyCustomSignature :1736.)
    function check_protocolId1_successReturns35(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bytes memory message = _protocolMessage(1, 0, false, ROOT); // (pid=1, votingRoundId=0, isSecure=0)
        (bool ok, uint256 rdlen) = _call(message, _threeSigs(a, b, c));
        assert(!ok || rdlen == 35);
    }

    // Reachability control for P6.a — acceptance on the protocolId==1 path MUST be reachable.
    // EXPECT: COUNTEREXAMPLE (an `ok == true` witness). If this PASSES, P6.a is vacuous.
    function check_reach_protocolId1_canAccept(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bytes memory message = _protocolMessage(1, 0, false, ROOT);
        (bool ok, ) = _call(message, _threeSigs(a, b, c));
        assert(!ok);
    }

    // ===================== protocolId == 3 (Mode-2, protocolId>1) path =====================

    // P6.b — protocolId==3 success => returndata length is EXACTLY 0.
    // EXPECT: PASS. (Anchors Relay.sol:1432 `return(0,0)` on the non-random-protocol branch, 3 != 2.)
    function check_protocolId3_successReturns0(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, ROOT); // same-epoch votingRoundId
        (bool ok, uint256 rdlen) = _call(message, _threeSigs(a, b, c));
        assert(!ok || rdlen == 0);
    }

    // P6.c — the load-bearing discriminator fact: protocolId==3 success => length is NOT 35
    // (so _verifyCustomSignature's 35-byte length check cannot be satisfied by a Mode-2 message).
    // Subsumed by P6.b but stated explicitly to mirror the discriminator usage at Relay.sol:1736.
    // EXPECT: PASS.
    function check_protocolId3_isNot35(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, ROOT);
        (bool ok, uint256 rdlen) = _call(message, _threeSigs(a, b, c));
        assert(!ok || rdlen != 35);
    }

    // Reachability control for P6.b / P6.c — acceptance on the protocolId==3 path MUST be reachable.
    // EXPECT: COUNTEREXAMPLE (an `ok == true` witness). If this PASSES, P6.b/P6.c are vacuous.
    function check_reach_protocolId3_canAccept(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, ROOT);
        (bool ok, ) = _call(message, _threeSigs(a, b, c));
        assert(!ok);
    }
}
