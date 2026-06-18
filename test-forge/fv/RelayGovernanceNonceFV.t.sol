// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // RelayTestBase

// Phase 3 Step 4/6 (AC-10 / RLY-02): governance-fee NONCE replay protection, MULTI-TRANSACTION, symbolic.
// governanceFeeSetup (Relay.sol:475) gates fee-config changes behind a custom signature verification and a
// STRICTLY-INCREASING nonce (Relay.sol:492-494): require(_config.nonce > governanceFeeNonce). So once a
// governance message with nonce N is accepted, NO message with nonce <= N can ever be accepted again
// (replay / stale-config protection). The concrete unit tests cover specific nonces; this proves it for
// ALL symbolic nonces over a 2-call sequence.
//
// The relayMessage is a relay() protocolId==1 custom-signature call whose "merkleRoot" field carries the
// governance digest keccak(config, address(relay)); _verifyCustomSignature re-enters relay() and checks the
// returned hash == digest. Signatures are SYMBOLIC and ecrecover is uninterpreted, so the same (v,r,s)
// triple verifies for both (distinct-digest) messages. Relay-only mode (signingPolicySetter == 0), epoch-1
// policy so lastInitializedRewardEpoch == returnRewardEpochId (passes the "too old signing policy" guard).
contract RelayGovernanceNonceFV is RelayTestBase {
    bytes internal policy;
    uint256 internal constant NV = 3;

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 100 each, 300 > 260 threshold
            pks.push(0);
        }
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = new Relay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
    }

    function _sig(Sig calldata x, uint16 i) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, i);
    }

    // build + submit a governanceFeeSetup call for `c` with 3 symbolic signatures; returns success.
    function _gov(IRelay.RelayGovernanceConfig memory c, Sig calldata a, Sig calldata b, Sig calldata cc)
        internal returns (bool ok)
    {
        bytes32 digest = keccak256(abi.encode(c, address(relay)));
        bytes memory message = _protocolMessage(1, 0, false, digest); // protocolId==1 custom-sig message
        bytes memory sigs = abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(cc, 2));
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs);
        try relay.governanceFeeSetup(rm, c) { ok = true; } catch { ok = false; }
    }

    // AC-10 — once nonce n1 is accepted, ANY n2 <= n1 is rejected (no replay, no stale config).
    function check_nonce_mustStrictlyIncrease(
        uint256 n1, uint256 n2, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(n1 > 0);   // n1 above the initial governanceFeeNonce (== 0)
        vm.assume(n2 <= n1); // stale / replayed nonce
        bool ok1 = _gov(_governanceConfig(n1, 2, 1000), a, b, c);
        bool ok2 = _gov(_governanceConfig(n2, 2, 2000), a, b, c);
        if (ok1) assert(!ok2); // after n1 is consumed, n2 <= n1 cannot be accepted
    }

    // Anti-vacuity: two strictly-increasing nonces are BOTH acceptable (the path is live).
    function check_reach_nonce_increasing(
        uint256 n1, uint256 n2, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(n1 > 0 && n2 > n1);
        bool ok1 = _gov(_governanceConfig(n1, 2, 1000), a, b, c);
        bool ok2 = _gov(_governanceConfig(n2, 2, 2000), a, b, c);
        assert(!(ok1 && ok2)); // EXPECT counterexample: both succeed
    }
}
