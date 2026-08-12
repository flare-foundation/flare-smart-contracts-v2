// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// The delayed-signing-policy gate.
// In the same-epoch case (messageRewardEpochId == policyEpoch) a Mode-2 message whose votingRoundId is
// BEFORE the policy's own startVotingRoundId is rejected:
//     if (protocolId != 1 && votingRoundId < startingVotingRoundId) revert "Delayed sign policy"
// (decision-matrix row exp(v)==r, v<s => REVERT). This prevents finalizing rounds that
// precede the validity start of the signing policy.
//
// CONFIG (relay-only, single-call). Epoch-1 policy with a DELAYED start: startVotingRoundId = 3410, while
// epoch 1 naturally spans voting rounds [3360, 6720). So a round in [3360, 3410) maps to epoch 1
// (messageRewardEpochId == policyEpoch) yet precedes the policy start => delayed; a round >= 3410 is OK.
// 3 voters weight 100, threshold 260 (3 sigs = 300 > 260), symbolic signatures, ecrecover uninterpreted.
contract RelayDelayedPolicyFV is RelayTestBase {
    bytes internal policy;
    uint256 internal constant NV = 3;
    uint32 internal constant DELAYED_START = START_VOTING_ROUND_ID + 50; // 3410, > epoch-1 natural start 3360
    uint32 internal constant BEFORE = START_VOTING_ROUND_ID;             // 3360, epoch 1 but < DELAYED_START
    bytes32 internal constant ROOT = keccak256("fv-root");

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT);
            pks.push(0);
        }
        // policy validity starts at DELAYED_START (its startVotingRoundId field)
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, DELAYED_START, THRESHOLD, SEED);
        relay = deployRelay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
    }

    function _sig(Sig calldata x, uint16 i) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, i);
    }

    function _relay(uint32 vrid, Sig calldata a, Sig calldata b, Sig calldata c) internal returns (bool ok) {
        bytes memory message = _protocolMessage(3, vrid, false, ROOT); // Mode-2, protocolId 3 != 1
        bytes memory sigs = abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
        (ok, ) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs));
    }

    // L — a round before the policy's validity start (but in the same epoch) is rejected as delayed.
    // EXPECT: PASS (proof).
    function check_delayedPolicy_rejected(Sig calldata a, Sig calldata b, Sig calldata c) external {
        assert(!_relay(BEFORE, a, b, c)); // 3360 < 3410 => "Delayed sign policy"
    }

    // Non-vacuity: at/after the start the policy is usable, so acceptance is reachable. EXPECT: COUNTEREXAMPLE.
    function check_reach_atStart(Sig calldata a, Sig calldata b, Sig calldata c) external {
        assert(!_relay(DELAYED_START, a, b, c)); // 3410 >= 3410 => no delay; finalizable
    }
}
