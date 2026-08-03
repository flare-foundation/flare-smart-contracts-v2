// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // reuse RelayTestBase

// Phase-2 (bounded multi-transaction, Halmos): random monotonicity across a SEQUENCE of relay() calls.
// The live random pointer stateData.randomVotingRoundId only advances for a strictly-newer round
// (Relay.sol monotonic guard ~1462), so relaying an OLDER round after a NEWER one must NOT regress the
// "current" random. We prove the 2-call instance for both orders and that both rounds stay retrievable
// historically. This is the bounded version of the Phase-2 monotonicity obligation; the unbounded
// (any-length sequence) form is a Kontrol/inductive task — see docs/relay-fv.md.
//
// Two concrete same-epoch rounds R_HI > R_LO (both in reward epoch 1, both >= startVotingRoundId, so no
// threshold-increase: 3 signatures suffice). Signatures are symbolic; ecrecover is uninterpreted, so the
// SAME (v,r,s) triple can match the voters for BOTH messages (f_ecrecover(h1,..) and f_ecrecover(h2,..)
// are independent), which keeps the harness within the stack limit. The live ROUND is pinned via the
// returned _randomTimestamp = firstTs + (round+1)*votingEpochDuration, so the assertions constrain the
// pointer's round regardless of the (symbolic) values. halmos.toml loop = 6 covers each 3-signature loop.
contract RelayRandomMonotonicityFV is RelayTestBase {
    bytes internal policy;
    uint256 internal constant NV = 3;
    uint32 internal constant R_HI = START_VOTING_ROUND_ID + 5; // newer round
    uint32 internal constant R_LO = START_VOTING_ROUND_ID + 2; // older round
    uint256 internal constant V_HI = 0xA11CE;                  // concrete relayed values (distinct)
    uint256 internal constant V_LO = 0xB0B;
    bytes32 internal constant SIBLING = keccak256("fv-sib");

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 100 each (300 > 260)
            pks.push(0);
        }
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = new Relay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
    }

    function _sp(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _leaf(uint32 vrid, uint256 val) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(vrid), val, uint256(1))); // isSecure = true (byte 1)
    }

    function _sig(Sig calldata x, uint16 i) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, i);
    }

    function _three(Sig calldata a, Sig calldata b, Sig calldata c) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
    }

    function _relay(uint32 vrid, uint256 val, bytes memory sigs) internal returns (bool ok) {
        bytes32 root = _sp(_leaf(vrid, val), SIBLING);
        bytes memory message = abi.encodePacked(RANDOM_PROTOCOL_ID, vrid, uint8(1), root); // 38 bytes
        bytes memory trailer = abi.encodePacked(val, SIBLING);
        (ok, ) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer));
    }

    // live pointer's timestamp for a given round (encodes the round)
    function _ts(uint32 round) internal pure returns (uint256) {
        return uint256(FIRST_VOTING_ROUND_TS) + (uint256(round) + 1) * uint256(VOTING_EPOCH_DURATION);
    }

    // Relay R_HI then R_LO: the older second relay must NOT regress the live pointer. EXPECT: PASS.
    function check_staleDoesNotRegress(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bool ok1 = _relay(R_HI, V_HI, _three(a, b, c));
        bool ok2 = _relay(R_LO, V_LO, _three(a, b, c));
        if (ok1 && ok2) {
            (uint256 val, , uint256 ts) = relay.getRandomNumber();
            assert(ts == _ts(R_HI) && val == V_HI); // live pointer stays at the higher round
        }
    }

    // Relay R_LO then R_HI: the live pointer advances to the newer round. EXPECT: PASS.
    function check_advances(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bool ok1 = _relay(R_LO, V_LO, _three(a, b, c));
        bool ok2 = _relay(R_HI, V_HI, _three(a, b, c));
        if (ok1 && ok2) {
            (uint256 val, , uint256 ts) = relay.getRandomNumber();
            assert(ts == _ts(R_HI) && val == V_HI);
        }
    }

    // Both rounds remain retrievable historically regardless of order (relay R_HI then R_LO). EXPECT: PASS.
    function check_bothHistoricalRetained(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bool ok1 = _relay(R_HI, V_HI, _three(a, b, c));
        bool ok2 = _relay(R_LO, V_LO, _three(a, b, c));
        if (ok1 && ok2) {
            (uint256 vh, , ) = relay.getRandomNumberHistorical(R_HI);
            (uint256 vl, , ) = relay.getRandomNumberHistorical(R_LO);
            assert(vh == V_HI && vl == V_LO);
        }
    }

    // Non-vacuity: two successful random relays in sequence are reachable. EXPECT: COUNTEREXAMPLE.
    function check_reachability_twoRelays(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bool ok1 = _relay(R_HI, V_HI, _three(a, b, c));
        bool ok2 = _relay(R_LO, V_LO, _three(a, b, c));
        assert(!(ok1 && ok2));
    }
}
