// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Bounded Halmos proofs of no-repeat-index and indexed-weight soundness on the cross-epoch path, where the
// threshold-INCREASE applies. relay() enters this path when messageRewardEpochId > policy rewardEpochId
// and multiplies the threshold by thresholdIncreaseBIPS/THRESHOLD_BIPS (here 12000/10000 = x1.2) when
// lastInitializedRewardEpoch == policy rewardEpochId (no newer policy relayed yet). The same-epoch
// harnesses (RelaySigParamFV, RelaySigFV) do not exercise this path. The proof uses the effective increased
// threshold, not the policy's base threshold.
//
// Setup mirrors the concrete test_random_monotonicity_acrossRewardEpochs: an epoch-2 message
// (votingRoundId = START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION) finalized by the epoch-1 policy, so the
// effective threshold is thr * 1.2 (e.g. 260 -> 312, needing 4 signers). SYMBOLIC weights + threshold;
// signatures symbolic; ecrecover uninterpreted. halmos.toml loop = 6 covers the 3-signature loop.
contract RelayCrossEpochFV is RelayTestBase {
    bytes32 internal constant ROOT = keccak256("fv-root");
    uint256 internal constant NV = 3;
    // reward epoch 2 (policy is epoch 1) => messageRewardEpochId 2 > 1 => increased-threshold path.
    uint32 internal constant VRID_E2 = START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION;

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {}

    function _policy(uint16 w0, uint16 w1, uint16 w2, uint16 thr) internal pure returns (bytes memory p) {
        p = abi.encodePacked(uint16(NV), uint24(REWARD_EPOCH_ID), uint32(START_VOTING_ROUND_ID), thr, bytes32(SEED));
        p = abi.encodePacked(p, address(uint160(0x1001)), w0);
        p = abi.encodePacked(p, address(uint160(0x1002)), w1);
        p = abi.encodePacked(p, address(uint160(0x1003)), w2);
    }

    function _deploy(uint16 w0, uint16 w1, uint16 w2, uint16 thr) internal returns (Relay r, bytes memory p) {
        p = _policy(w0, w1, w2, thr);
        r = deployRelay(_initialConfig(_signingPolicyHash(p)), address(0), IRelay(address(0)));
    }

    function _sig(Sig calldata x, uint16 i) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, i);
    }

    function _call(Relay r, bytes memory p, bytes memory sigs) internal returns (bool ok) {
        bytes memory message = _protocolMessage(3, VRID_E2, false, ROOT); // epoch-2 Mode-2 message
        (ok, ) = address(r).call(abi.encodePacked(Relay.relay.selector, p, message, sigs));
    }

    // effective (increased) threshold on the cross-epoch path: floor(thr * thresholdIncreaseBIPS / 10000).
    function _eff(uint16 thr) internal pure returns (uint256) {
        return uint256(thr) * uint256(THRESHOLD_INCREASE_BIPS) / uint256(10000); // THRESHOLD_BIPS = 10000
    }

    // Cross-epoch no-repeat-index: the distinct-address fixture's slots 0,1 are insufficient vs the
    // increased threshold, so duplicate index [0,1,1] cannot finalize (the strict-increase guard rejects it).
    // EXPECT: PASS.
    function check_crossEpoch_noDoubleCount(
        uint16 w0, uint16 w1, uint16 w2, uint16 thr, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(uint256(w0) + uint256(w1) <= _eff(thr));
        (Relay r, bytes memory p) = _deploy(w0, w1, w2, thr);
        bytes memory sigs = abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 1));
        assert(!_call(r, p, sigs));
    }

    // Cross-epoch threshold soundness: 3 signatures whose total weight <= the INCREASED threshold cannot
    // accept. (Also confirms the x1.2 increase is actually applied: if it were not, configs with
    // thr < sum <= thr*1.2 would accept and refute this.) EXPECT: PASS.
    function check_crossEpoch_threshold(
        uint16 w0, uint16 w1, uint16 w2, uint16 thr, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(uint256(w0) + uint256(w1) + uint256(w2) <= _eff(thr));
        (Relay r, bytes memory p) = _deploy(w0, w1, w2, thr);
        bytes memory sigs = abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
        assert(!_call(r, p, sigs));
    }

    // Non-vacuity: above the increased threshold, acceptance is reachable. EXPECT: COUNTEREXAMPLE.
    function check_crossEpoch_reachability(
        uint16 w0, uint16 w1, uint16 w2, uint16 thr, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(w0 > 0 && w1 > 0 && w2 > 0);
        vm.assume(_eff(thr) < uint256(w0) + uint256(w1) + uint256(w2));
        (Relay r, bytes memory p) = _deploy(w0, w1, w2, thr);
        bytes memory sigs = abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
        assert(!_call(r, p, sigs));
    }
}
