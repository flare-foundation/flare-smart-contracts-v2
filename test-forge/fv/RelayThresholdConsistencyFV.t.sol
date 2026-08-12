// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {IIRelay} from "../../contracts/protocol/interface/IIRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Phase 3 Step 4 (AC-6 core / threshold consistency): a signing policy with an out-of-band threshold is
// REJECTED. setSigningPolicy enforces (Relay.sol:351-358):
//     threshold*THRESHOLD_BIPS >= totalWeight*MIN_THRESHOLD_BIPS   ("too small threshold")
//     threshold*THRESHOLD_BIPS <= totalWeight*MAX_THRESHOLD_BIPS   ("too big threshold")
// (THRESHOLD_BIPS=10000, MIN=5000, MAX=6600). This is the SAME formula the Mode-1 relay path applies via
// checkThresholdConsistency (Relay.sol:621-667, "too small threshold" @666) before storing a relayed new
// policy — so verifying it on the setter path covers AC-6's security content (a quorum cannot install a
// signing policy whose threshold is too small to be safe, nor an unreachably-large one) by formula
// equivalence; the full Mode-1 message-construction harness is scoped separately (see
// docs/relay-phase3-documented-items.md).
//
// Single-voter policy with SYMBOLIC weight W and threshold T (both uint16), so the theorem quantifies over
// all weight/threshold combinations. Setter mode; epoch 2 (== lastInitialized+1) so the epoch guard passes
// and the threshold band is the decisive check.
contract RelayThresholdConsistencyFV is RelayTestBase {
    uint256 internal constant THRESHOLD_BIPS = 10000;
    uint256 internal constant MIN_THRESHOLD_BIPS = 5000;
    uint256 internal constant MAX_THRESHOLD_BIPS = 6600;

    function setUp() public override {}

    function _deploy() internal returns (Relay r) {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.feeCollectionAddress = payable(address(0));
        r = deployRelay(cfg, address(this), IRelay(address(0)));
    }

    function _policy(uint16 w, uint16 t) internal pure returns (IIRelay.SigningPolicy memory sp) {
        sp.rewardEpochId = uint24(REWARD_EPOCH_ID) + 1; // 2 == lastInitialized+1 (epoch guard passes)
        sp.startVotingRoundId = START_VOTING_ROUND_ID;
        sp.threshold = t;
        sp.seed = SEED;
        sp.voters = new address[](1);
        sp.voters[0] = address(uint160(0x1001));
        sp.weights = new uint16[](1);
        sp.weights[0] = w;
    }

    function _try(uint16 w, uint16 t) internal returns (bool ok) {
        Relay r = _deploy();
        try r.setSigningPolicy(_policy(w, t)) returns (bytes32) {
            ok = true;
        } catch {
            ok = false;
        }
    }

    // AC-6a — a threshold below the MIN band (threshold*BIPS < totalWeight*MIN_BIPS) is rejected.
    // EXPECT: PASS (proof).
    function check_thresholdTooSmall_rejected(uint16 w, uint16 t) external {
        vm.assume(w > 0);
        vm.assume(uint256(t) * THRESHOLD_BIPS < uint256(w) * MIN_THRESHOLD_BIPS);
        assert(!_try(w, t));
    }

    // AC-6b — a threshold above the MAX band (threshold*BIPS > totalWeight*MAX_BIPS) is rejected.
    // EXPECT: PASS (proof).
    function check_thresholdTooBig_rejected(uint16 w, uint16 t) external {
        vm.assume(uint256(t) * THRESHOLD_BIPS > uint256(w) * MAX_THRESHOLD_BIPS);
        assert(!_try(w, t));
    }

    // Anti-vacuity: an in-band threshold is accepted (the validation is not trivially always-revert).
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_inBand_accepted(uint16 w, uint16 t) external {
        vm.assume(w > 0 && w < 2 ** 15); // keep totalWeight < 2**16
        vm.assume(uint256(t) * THRESHOLD_BIPS >= uint256(w) * MIN_THRESHOLD_BIPS);
        vm.assume(uint256(t) * THRESHOLD_BIPS <= uint256(w) * MAX_THRESHOLD_BIPS);
        assert(!_try(w, t)); // EXPECT counterexample: an in-band policy is accepted
    }
}
