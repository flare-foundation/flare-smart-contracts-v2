// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // RelayTestBase

// Phase 3 Step 1 (AC-11 + L4 + RLY-11): CONSTRUCTOR config validation (Relay.sol:235-246).
// The constructor fail-closes on malformed initial config — each guard proven to reject:
//   thresholdIncreaseBIPS >= THRESHOLD_BIPS         (no sub-1.0x increase)      [Relay.sol:235]
//   rewardEpochDurationInVotingEpochs > 0           (RLY-11, no div-by-zero)    [Relay.sol:237]
//   votingEpochDurationSeconds > 0                  (RLY-11)                    [Relay.sol:238]
//   initialSigningPolicyHash != 0                   (L-4, would brick epoch)    [Relay.sol:240]
// Each check builds the otherwise-valid base config and corrupts exactly one field, then asserts the
// deploy reverts; the reachability control confirms the valid config deploys.
contract RelayConstructorFV is RelayTestBase {
    uint256 internal constant THRESHOLD_BIPS = 10000;

    function setUp() public override {}

    function _tryDeploy(IRelay.RelayInitialConfig memory cfg) internal returns (bool ok) {
        try new Relay(cfg, address(this), IRelay(address(0))) returns (Relay) { ok = true; }
        catch { ok = false; }
    }

    // thresholdIncreaseBIPS below 1.0x (THRESHOLD_BIPS) is rejected.
    function check_ctor_rejectsLowThresholdIncrease(uint16 tib) external {
        vm.assume(uint256(tib) < THRESHOLD_BIPS);
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.thresholdIncreaseBIPS = tib;
        assert(!_tryDeploy(cfg));
    }

    // zero reward-epoch duration is rejected (RLY-11).
    function check_ctor_rejectsZeroRewardEpochDuration() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.rewardEpochDurationInVotingEpochs = 0;
        assert(!_tryDeploy(cfg));
    }

    // zero voting-epoch duration is rejected (RLY-11).
    function check_ctor_rejectsZeroVotingEpochDuration() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.votingEpochDurationSeconds = 0;
        assert(!_tryDeploy(cfg));
    }

    // zero initial signing-policy hash is rejected (L-4).
    function check_ctor_rejectsZeroPolicyHash() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(0));
        assert(!_tryDeploy(cfg));
    }

    // Anti-vacuity: the valid base config deploys successfully.
    function check_reach_ctor_validDeploys() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        assert(!_tryDeploy(cfg)); // EXPECT counterexample: valid config deploys
    }
}
