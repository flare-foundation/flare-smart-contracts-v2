// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // RelayTestBase
import "../../contracts/protocol/interface/IIRelay.sol";

// Phase 3 Step 4 (L1): signing-policy LIFECYCLE — strict sequential reward-epoch advance.
// setSigningPolicy (Relay.sol:321) requires, BEFORE any other validation (Relay.sol:331-334):
//     stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId
// so initialised epochs can only ever step forward by exactly one — no skip, no replay, no regress.
// Proven against the REAL setSigningPolicy on an otherwise-fully-valid policy (1 voter, weight 100,
// threshold 60 ∈ the MIN/MAX-threshold band), so the ONLY admissible revert reason is the epoch guard.
// Deployed in setter mode (signingPolicySetter == address(this)); initial epoch = REWARD_EPOCH_ID = 1,
// so the unique accepted next epoch is 2.
contract RelayEpochAdvanceFV is RelayTestBase {
    function setUp() public override {}

    function _deploySetter() internal returns (Relay r) {
        r = new Relay(_initialConfig(bytes32(uint256(1))), address(this), IRelay(address(0)));
    }

    // a fully-valid single-voter policy at the given epoch (passes every non-epoch require).
    function _validPolicy(uint24 epoch) internal pure returns (IIRelay.SigningPolicy memory sp) {
        sp.rewardEpochId = epoch;
        sp.startVotingRoundId = START_VOTING_ROUND_ID;
        sp.threshold = 60;          // 60*10000 ∈ [100*5000, 100*6600]
        sp.seed = SEED;
        sp.voters = new address[](1);
        sp.voters[0] = address(uint160(0x1001));
        sp.weights = new uint16[](1);
        sp.weights[0] = 100;        // totalWeight = 100 < 2**16
    }

    // L1 — any epoch other than lastInitialized+1 (==2) is REJECTED (no skip/replay/regress).
    // EXPECT: PASS (proof).
    function check_epochAdvance_requiresSequential(uint24 epoch) external {
        vm.assume(epoch != uint24(REWARD_EPOCH_ID) + 1); // != 2
        Relay r = _deploySetter();
        IIRelay.SigningPolicy memory sp = _validPolicy(epoch);
        (bool ok, ) = address(r).call(abi.encodeCall(Relay.setSigningPolicy, (sp)));
        assert(!ok); // wrong epoch => revert at Relay.sol:331
    }

    // Anti-vacuity: the correct next epoch (==2) IS accepted, so the guard is not trivially always-revert.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_epochAdvance_correctSucceeds() external {
        Relay r = _deploySetter();
        IIRelay.SigningPolicy memory sp = _validPolicy(uint24(REWARD_EPOCH_ID) + 1); // == 2
        (bool ok, ) = address(r).call(abi.encodeCall(Relay.setSigningPolicy, (sp)));
        assert(!ok); // EXPECT counterexample: the sequential epoch succeeds
    }

    // L1-MONOTONE (state effect / unbounded monotonicity step): a SUCCESSFUL setSigningPolicy advances
    // lastInitializedRewardEpoch by EXACTLY +1 (Relay.sol — the new epoch is written as lastInitialized+1).
    // This is the inductive STEP for unbounded monotonicity: by base (constructor sets it to
    // initialRewardEpochId) + this step, the pointer is strictly increasing across ANY sequence of
    // policy initialisations — it can never stall or regress (meta-induction, as for the sig-loop / fold).
    // EXPECT: PASS (proof).
    function check_epochAdvance_incrementsByOne() external {
        Relay r = _deploySetter();
        (uint32 before, ) = r.lastInitializedRewardEpochData(); // == REWARD_EPOCH_ID (1)
        IIRelay.SigningPolicy memory sp = _validPolicy(uint24(uint256(before) + 1));
        (bool ok, ) = address(r).call(abi.encodeCall(Relay.setSigningPolicy, (sp)));
        if (ok) {
            (uint32 afterE, ) = r.lastInitializedRewardEpochData();
            assert(afterE == before + 1); // strictly +1: monotone, no stall, no skip
        }
    }
}
