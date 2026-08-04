// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import "../unit/protocol/implementation/Relay.t.sol"; // RelayTestBase
import "../../contracts/protocol/interface/IIRelay.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Phase 3 Step 4 (L8): cross-epoch "MUST USE NEW SIGN POLICY" gate (Relay.sol:960-974), MULTI-STEP.
// In the cross-epoch path (messageRewardEpochId > policyEpoch) the contract branches on lastInitialized:
//   - lastInitialized == policyEpoch  -> apply the x1.2 threshold increase   (covered by RelayCrossEpochFV)
//   - lastInitialized  > policyEpoch  -> the NEW epoch is already initialised, so an OLD-policy message for
//     a voting round at/after the new epoch's start is REJECTED: Relay.sol:972
//         if (votingRoundId + 1 > startingVotingRoundIds[policyEpoch+1]) revert "Must use new sign policy"
// i.e. once epoch E+1 is initialised, the epoch-E policy can no longer finalize rounds that belong to E+1.
//
// SETUP (setter mode so we can advance lastInitialized deterministically):
//   1. deploy with epoch-1 policy P1 (constructor stores hash[1], lastInitialized = 1)
//   2. setSigningPolicy(P2 @ epoch 2, startVotingRoundId = START_E2)  -> stores hash[2],
//      startingVotingRoundIds[2] = START_E2, lastInitialized = 2  (> policyEpoch 1 => the L8 branch)
//   3. relay() with P1 for an epoch-2 message (messageRewardEpochId = 2 > 1)
// Epoch 2 spans voting rounds [2*REWARD_EPOCH_DURATION, 3*REWARD_EPOCH_DURATION) = [6720, 10080); the new
// epoch's start is delayed to START_E2 = 6820, so a round in [6720, 6820) may still use P1 but a round
// >= 6820 must not. Signatures symbolic, ecrecover uninterpreted; threshold NOT increased on this branch
// (3*100 = 300 > 260).
contract RelayMustUseNewPolicyFV is RelayTestBase {
    bytes internal policy1; // epoch-1 policy bytes (used to relay)
    uint256 internal constant NV = 3;
    uint32 internal constant E2_START_ROUND = START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION; // 6720, start of epoch 2
    uint32 internal constant START_E2 = E2_START_ROUND + 100; // 6820, delayed epoch-2 start
    bytes32 internal constant ROOT = keccak256("fv-root");

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 100 each, 300 > 260
            pks.push(0);
        }
        policy1 = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        // setter mode so setSigningPolicy can advance lastInitialized to 2
        relay = deployRelay(_initialConfig(_signingPolicyHash(policy1)), address(this), IRelay(address(0)));
        // step 2: initialise epoch 2 (lastInitialized 1 -> 2, startingVotingRoundIds[2] = START_E2)
        IIRelay.SigningPolicy memory p2;
        p2.rewardEpochId = uint24(REWARD_EPOCH_ID) + 1; // 2
        p2.startVotingRoundId = START_E2;
        p2.threshold = 60;             // valid band for totalWeight 100
        p2.seed = SEED;
        p2.voters = new address[](1);
        p2.voters[0] = address(uint160(0x2001));
        p2.weights = new uint16[](1);
        p2.weights[0] = 100;
        relay.setSigningPolicy(p2);
    }

    function _sig(Sig calldata x, uint16 i) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, i);
    }

    function _relayWithP1(uint32 vrid, Sig calldata a, Sig calldata b, Sig calldata c) internal returns (bool ok) {
        bytes memory message = _protocolMessage(3, vrid, false, ROOT); // Mode-2 epoch-2 message
        bytes memory sigs = abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
        (ok, ) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy1, message, sigs));
    }

    // L8 — once epoch 2 is initialised, the epoch-1 policy CANNOT finalize an epoch-2 round at/after the
    // new epoch's start (votingRoundId >= START_E2): relay() reverts "Must use new sign policy".
    // EXPECT: PASS (proof).
    function check_mustUseNewPolicy_afterStart(Sig calldata a, Sig calldata b, Sig calldata c) external {
        assert(!_relayWithP1(START_E2, a, b, c)); // 6820 >= START_E2 => rejected
    }

    // Anti-vacuity / contrast: a round in the gap [E2_START, START_E2) is still finalizable with P1
    // (the L8 gate does not fire), so acceptance is reachable there. EXPECT: COUNTEREXAMPLE.
    function check_reach_oldPolicyOkBeforeStart(Sig calldata a, Sig calldata b, Sig calldata c) external {
        assert(!_relayWithP1(E2_START_ROUND, a, b, c)); // 6720 < START_E2 => old policy still OK
    }
}
