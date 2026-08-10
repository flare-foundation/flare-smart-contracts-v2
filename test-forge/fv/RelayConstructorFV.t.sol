// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import "../unit/protocol/implementation/Relay.t.sol"; // RelayTestBase

// Phase 3 Step 1 (AC-11 + L4 + RLY-11): CONSTRUCTOR config validation (Relay.sol:235-246).
// The constructor fail-closes on malformed initial config — each guard proven to reject:
//   thresholdIncreaseBIPS >= THRESHOLD_BIPS         (no sub-1.0x increase)      [Relay.sol:235]
//   rewardEpochDurationInVotingEpochs > 0           (RLY-11, no div-by-zero)    [Relay.sol:237]
//   votingEpochDurationSeconds > 0                  (RLY-11)                    [Relay.sol:238]
//   initialSigningPolicyHash != 0                   (L-4, would brick epoch)    [Relay.sol:240]
//   sourceChainId == block.chainid on setter deploy (RLY-23 home-force)
// Each check builds the otherwise-valid base config and corrupts exactly one field, then asserts the
// deploy reverts; the reachability control confirms the valid config deploys.
contract RelayConstructorFV is RelayTestBase {
    uint256 internal constant THRESHOLD_BIPS = 10000;

    function setUp() public override {}

    function _tryDeploy(IRelay.RelayInitialConfig memory cfg) internal returns (bool ok) {
        Relay implementation = new Relay();
        // No `returns (RelayProxy)` clause on the try: Foundry's dynamic test linking
        // preprocessor rewrites typed try-new deployments through a generated non-payable
        // address-to-contract conversion, which solc rejects for RelayProxy (payable fallback).
        try new RelayProxy(address(implementation), cfg, address(this), IRelay(address(0)), RELAY_TEST_GOVERNANCE)
        { ok = true; }
        catch { ok = false; }
    }

    // thresholdIncreaseBIPS below 1.0x (THRESHOLD_BIPS) is rejected.
    // EXPECT: PASS (proof).
    function check_ctor_rejectsLowThresholdIncrease(uint16 tib) external {
        vm.assume(uint256(tib) < THRESHOLD_BIPS);
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.thresholdIncreaseBIPS = tib;
        assert(!_tryDeploy(cfg));
    }

    // zero reward-epoch duration is rejected (RLY-11).
    // EXPECT: PASS (proof).
    function check_ctor_rejectsZeroRewardEpochDuration() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.rewardEpochDurationInVotingEpochs = 0;
        assert(!_tryDeploy(cfg));
    }

    // zero voting-epoch duration is rejected (RLY-11).
    // EXPECT: PASS (proof).
    function check_ctor_rejectsZeroVotingEpochDuration() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.votingEpochDurationSeconds = 0;
        assert(!_tryDeploy(cfg));
    }

    // zero initial signing-policy hash is rejected (L-4).
    // EXPECT: PASS (proof).
    function check_ctor_rejectsZeroPolicyHash() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(0));
        assert(!_tryDeploy(cfg));
    }

    // RLY-23 home-force: on a home deploy (signing-policy setter present, as _tryDeploy passes) a
    // source chain id that is nonzero and != block.chainid is rejected — a live setter cannot bind a
    // foreign domain. EXPECT: PASS (proof).
    function check_ctor_homeForce_rejectsForeignSource(uint256 src) external {
        vm.assume(src != 0 && src != block.chainid);
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.sourceChainId = src;
        assert(!_tryDeploy(cfg));
    }

    // Anti-vacuity: the valid base config deploys successfully.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_ctor_validDeploys() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        assert(!_tryDeploy(cfg)); // EXPECT counterexample: valid config deploys
    }
}
