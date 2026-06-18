// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // RelayTestBase

// Phase 3 Step 4 (decision matrix, final gate): "WRONG SIGN POLICY REWARD EPOCH" (Relay.sol:925-927).
// A signing policy for reward epoch R can sign messages in epoch R or LATER, never earlier:
//     if (messageRewardEpochId < rewardEpochId) revert "Wrong sign policy reward epoch"
// (decision-matrix row exp(v) < r => REVERT, Relay.sol:744). Prevents an old message being finalized by a
// newer signing policy. Together with the already-verified gates this completes the relay() epoch decision
// matrix: exp(v)<r (here), exp(v)==r & v<s (RelayDelayedPolicyFV), exp(v)>r & i==r threshold-increase
// (RelayCrossEpochFV/RelayThresholdScalingFV), exp(v)>r & i>r must-use-new-policy (RelayMustUseNewPolicyFV),
// plus the finalization window (RelayFinalizationWindowFV).
//
// CONFIG: deploy with an EPOCH-2 policy (initialRewardEpochId = 2). Epoch 2 starts at voting round 6720; a
// message for a round in epoch 1 ([3360, 6720)) has messageRewardEpochId 1 < policyEpoch 2 => rejected.
// 3 voters weight 100, threshold 260; symbolic signatures, ecrecover uninterpreted.
contract RelayWrongEpochFV is RelayTestBase {
    bytes internal policy;
    uint256 internal constant NV = 3;
    uint24 internal constant POLICY_EPOCH = 2;
    uint32 internal constant E2_START = START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION; // 6720, epoch-2 start
    uint32 internal constant EPOCH1_ROUND = START_VOTING_ROUND_ID + 100; // 3460, an epoch-1 round
    bytes32 internal constant ROOT = keccak256("fv-root");

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT);
            pks.push(0);
        }
        policy = _buildSigningPolicy(POLICY_EPOCH, E2_START, THRESHOLD, SEED); // epoch-2 policy
        IRelay.RelayInitialConfig memory cfg = _initialConfig(_signingPolicyHash(policy));
        cfg.initialRewardEpochId = uint32(POLICY_EPOCH);            // lastInitialized = 2, hash stored at [2]
        cfg.startingVotingRoundIdForInitialRewardEpochId = E2_START; // satisfies ctor: 0 + 2*3360 <= 6720
        relay = new Relay(cfg, address(0), IRelay(address(0)));
    }

    function _sig(Sig calldata x, uint16 i) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, i);
    }

    function _relay(uint32 vrid, Sig calldata a, Sig calldata b, Sig calldata c) internal returns (bool ok) {
        bytes memory message = _protocolMessage(3, vrid, false, ROOT); // Mode-2
        bytes memory sigs = abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
        (ok, ) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs));
    }

    // exp(v) < r — an epoch-1 message cannot be finalized by the epoch-2 policy.
    function check_wrongEpoch_rejected(Sig calldata a, Sig calldata b, Sig calldata c) external {
        assert(!_relay(EPOCH1_ROUND, a, b, c)); // round 3460 => epoch 1 < policy epoch 2 => rejected
    }

    // Non-vacuity: an epoch-2 message (exp(v) == r, v >= s) IS finalizable with the epoch-2 policy. EXPECT: CEX.
    function check_reach_correctEpoch(Sig calldata a, Sig calldata b, Sig calldata c) external {
        assert(!_relay(E2_START, a, b, c)); // round 6720 => epoch 2 == policy epoch => finalizable
    }
}
