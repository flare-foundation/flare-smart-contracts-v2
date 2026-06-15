// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // reuse RelayTestBase + encoding helpers

// Phase-1 symbolic proofs of the relay() signature/threshold accounting. See docs/relay-fv.md.
//
// CRITICAL CONFIG: Halmos unrolls loops only `--loop` times (DEFAULT 2). relay()'s signature loop
// runs once per signature, so with the default bound any test with 3+ signatures has its accepting
// iteration TRUNCATED -> the accept path looks unreachable and negative properties pass VACUOUSLY.
// halmos.toml sets `loop = 6` for this project; the reachability control below guards against
// regressions to a too-small bound.
//
// Harness shape: CONCRETE signing policy (N=5 voters, weight 100 each, threshold 260); only the
// SIGNATURES are symbolic. ecrecover is uninterpreted, so the solver may freely set
// recovered == voters[index] (the conservative worst case) and no real keypairs are needed.
contract RelaySigFV is RelayTestBase {
    bytes internal policy;
    bytes32 internal constant ROOT = keccak256("fv-root"); // concrete, non-zero (passes RLY-04)

    // Fully-concrete setUp (no vm.addr/vm.sign/sorting) so the deploy is a single deterministic path.
    function setUp() public override {
        for (uint256 i = 0; i < N; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 100 each; N=5 -> total 500, threshold 260
            pks.push(0); // unused
        }
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = new Relay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
    }

    function _sig(uint8 v, bytes32 r, bytes32 s, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(v, r, s, index);
    }

    function _relayCall(bytes memory sigs) internal returns (bool ok) {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, ROOT); // Mode-2, protocolId 3
        (ok, ) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs));
    }

    // P2 — Threshold soundness (bounded, 2 signers). Two voters carry 200 <= threshold 260, so NO pair
    // of signatures can make relay() accept. EXPECT: PASS.
    function check_threshold_twoVoters_cannotAccept(
        uint8 v0, bytes32 r0, bytes32 s0,
        uint8 v1, bytes32 r1, bytes32 s1
    ) external {
        bytes memory sigs = abi.encodePacked(uint16(2), _sig(v0, r0, s0, 0), _sig(v1, r1, s1, 1));
        assert(!_relayCall(sigs));
    }

    // P1 — No-double-count (bounded, 3 slots, indices [0,1,1]). The repeated index is rejected
    // ("Index out of order"), so a voter cannot be counted twice; max honest weight is 200 <= 260.
    // EXPECT: PASS.
    function check_noDoubleCount_duplicateIndex_cannotAccept(
        uint8 v0, bytes32 r0, bytes32 s0,
        uint8 v1, bytes32 r1, bytes32 s1,
        uint8 v2, bytes32 r2, bytes32 s2
    ) external {
        bytes memory sigs = abi.encodePacked(
            uint16(3), _sig(v0, r0, s0, 0), _sig(v1, r1, s1, 1), _sig(v2, r2, s2, 1)
        );
        assert(!_relayCall(sigs));
    }

    // Non-vacuity control: 3 distinct voters (300 > 260) MUST be able to finalize, so this asserts
    // !ok expecting a COUNTEREXAMPLE. If it ever PASSES, the loop bound is too small (or the accept
    // path is otherwise unreachable) and the two proofs above are vacuous. EXPECT: COUNTEREXAMPLE.
    function check_reachability_threeVoters_canAccept(
        uint8 v0, bytes32 r0, bytes32 s0,
        uint8 v1, bytes32 r1, bytes32 s1,
        uint8 v2, bytes32 r2, bytes32 s2
    ) external {
        bytes memory sigs = abi.encodePacked(
            uint16(3), _sig(v0, r0, s0, 0), _sig(v1, r1, s1, 1), _sig(v2, r2, s2, 2)
        );
        assert(!_relayCall(sigs));
    }
}
