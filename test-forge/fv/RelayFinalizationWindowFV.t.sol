// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {IIRelay} from "../../contracts/protocol/interface/IIRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Phase 3 Step 4 (L3): message FINALIZATION WINDOW gate (Relay.sol:929-947), MULTI-STEP.
// To bound the influence of participants in OLD signing policies, relay() rejects a message that is more
// than `messageFinalizationWindowInRewardEpochs` reward epochs behind lastInitialized:
//     if (messageRewardEpochId + finalizationWindow < lastInitializedRewardEpoch) revert "Message too old"
// (MESSAGE_FINALIZATION_WINDOW = 5 here.)
//
// SETUP (setter mode): deploy with epoch-1 policy P1 (lastInitialized = 1), then advance lastInitialized
// to 7 by initialising epochs 2..7 via setSigningPolicy. With lastInitialized = 7 and window = 5, an
// epoch-1 message (messageRewardEpochId = 1) is too old: 1 + 5 = 6 < 7. The epoch-7 policy P7 is kept so
// the anti-vacuity control can finalize a RECENT (not-too-old) message and show acceptance is reachable in
// this same state. Advance policies use threshold 180 (valid band for totalWeight 300: 180*10000 ∈
// [300*5000, 300*6600]); P1's constructor threshold (260) is irrelevant since the too-old gate fires first.
contract RelayFinalizationWindowFV is RelayTestBase {
    bytes internal policy1; // epoch-1 policy (too-old when relayed)
    bytes internal policy7; // epoch-7 policy (recent; for the reachability control)
    uint256 internal constant NV = 3;
    uint24 internal constant LAST_EPOCH = 7; // lastInitialized after the advance loop
    uint16 internal constant ADV_THR = 180; // valid threshold for 3*100 = 300
    bytes32 internal constant ROOT = keccak256("fv-root");

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function _epochStart(uint24 epoch) internal pure returns (uint32) {
        return uint32(START_VOTING_ROUND_ID + uint256(epoch - 1) * REWARD_EPOCH_DURATION);
    }

    function _structPolicy(uint24 epoch) internal view returns (IIRelay.SigningPolicy memory sp) {
        sp.rewardEpochId = epoch;
        sp.startVotingRoundId = _epochStart(epoch);
        sp.threshold = ADV_THR;
        sp.seed = SEED;
        sp.voters = voters; // same 3 voters/weights as P1
        sp.weights = weights;
    }

    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            // forge-lint: disable-next-line(unsafe-typecast)
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 100 each
            pks.push(0);
        }
        policy1 = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED); // thr 260
        IRelay.RelayInitialConfig memory cfg = _initialConfig(_signingPolicyHash(policy1));
        cfg.feeCollectionAddress = payable(address(0));
        relay = deployRelay(cfg, address(this), IRelay(address(0)));
        // advance lastInitialized 1 -> 7 by initialising epochs 2..7
        for (uint24 e = uint24(REWARD_EPOCH_ID) + 1; e <= LAST_EPOCH; e++) {
            relay.setSigningPolicy(_structPolicy(e));
        }
        // epoch-7 policy bytes (must encode the same fields as _structPolicy(7) so hashes match)
        policy7 = _buildSigningPolicy(LAST_EPOCH, _epochStart(LAST_EPOCH), ADV_THR, SEED);
    }

    function _sig(Sig calldata x, uint16 i) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, i);
    }

    function _relay(bytes memory pol, uint32 vrid, Sig calldata a, Sig calldata b, Sig calldata c)
        internal
        returns (bool ok)
    {
        bytes memory message = _protocolMessage(3, vrid, false, ROOT); // Mode-2 message
        bytes memory sigs = abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
        (ok,) = address(relay).call(abi.encodePacked(Relay.relay.selector, pol, message, sigs));
    }

    // L3 — an epoch-1 message (6 = 1+window < lastInitialized 7) is rejected as too old, with the epoch-1
    // policy. EXPECT: PASS (relay cannot finalize a too-old message).
    function check_messageTooOld_rejected(Sig calldata a, Sig calldata b, Sig calldata c) external {
        assert(!_relay(policy1, START_VOTING_ROUND_ID, a, b, c)); // votingRound 3360 => epoch 1, too old
    }

    // Anti-vacuity: a RECENT epoch-7 message (7 + window not < 7) is finalizable in this same state, so the
    // rejection above is specific to the window gate (not a broken setup). EXPECT: COUNTEREXAMPLE.
    function check_reach_recentNotTooOld(Sig calldata a, Sig calldata b, Sig calldata c) external {
        assert(!_relay(policy7, _epochStart(LAST_EPOCH), a, b, c)); // epoch-7 message, not too old
    }
}
