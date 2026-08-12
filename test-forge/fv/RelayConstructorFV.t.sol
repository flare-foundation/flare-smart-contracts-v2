// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {Vm} from "forge-std/Vm.sol";
import {RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Phase 3 Step 1 (AC-11 + L4 + RLY-11): INITIALIZER config validation.
// The initializer fail-closes on malformed initial config — these cases are proven rejected:
//   thresholdIncreaseBIPS < THRESHOLD_BIPS          (no sub-1.0x increase)
//   rewardEpochDurationInVotingEpochs == 0          (RLY-11, no div-by-zero)
//   votingEpochDurationSeconds == 0                 (RLY-11)
//   initialSigningPolicyHash == 0                   (L-4, would brick epoch)
//   sourceChainId != block.chainid on setter deploy (RLY-23 home-force)
// Each check builds the otherwise-valid base config and corrupts exactly one field, then asserts that
// the real Relay initializer reverts; the reachability control confirms the valid config initializes.
// Exact RelayProxy constructor atomicity is covered by concrete Foundry tests, while the real-proxy
// initializer/storage behavior is covered by RelayOwnerUpgradeFV. This harness deliberately performs no
// CREATE because Halmos 0.3.3 cannot execute Foundry's dynamic `vm.deployCode` rewrite for Relay bytecode.
contract RelayConstructorFV is Relay {
    uint256 internal constant THRESHOLD_BIPS = 10000;
    uint256 internal constant TIMELOCK = 1 days;
    // solhint-disable-next-line const-name-snakecase
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // OpenZeppelin Contracts 5.7 Initializable's ERC-7201 namespace:
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff)).
    bytes32 internal constant INITIALIZABLE_STORAGE =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /// Relay's production constructor correctly locks the implementation by storing uint64.max
    /// in this namespace. A fresh Halmos harness instance checks that exact lock, then clears only
    /// this verification-only word so each check can exercise the real external initializer once.
    constructor() {
        bytes32 slot = INITIALIZABLE_STORAGE;
        uint256 locked;
        assembly {
            locked := sload(slot)
        }
        assert(locked == type(uint64).max);
        assembly {
            sstore(slot, 0)
        }
    }

    function _initialConfig(bytes32 policyHash) internal view returns (IRelay.RelayInitialConfig memory cfg) {
        cfg.initialRewardEpochId = 1;
        cfg.startingVotingRoundIdForInitialRewardEpochId = 3360;
        cfg.initialSigningPolicyHash = policyHash;
        cfg.randomNumberProtocolId = 2;
        cfg.firstVotingRoundStartTs = 1_700_000_000;
        cfg.votingEpochDurationSeconds = 90;
        cfg.firstRewardEpochStartVotingRoundId = 0;
        cfg.rewardEpochDurationInVotingEpochs = 3360;
        cfg.thresholdIncreaseBIPS = 12000;
        cfg.messageFinalizationWindowInRewardEpochs = 5;
        // Setter-mode deployments do not expose fee verification, so every fee field must be
        // empty. Individual negative properties below corrupt exactly one of these fields.
        cfg.feeCollectionAddress = payable(address(0));
        cfg.feeConfigs = new IRelay.FeeConfig[](0);
        cfg.feeExemptAddresses = new address[](0);
        cfg.sourceChainId = block.chainid;
        cfg.timelockDurationSeconds = TIMELOCK;
    }

    function _tryInitialize(IRelay.RelayInitialConfig memory cfg) internal returns (bool ok, bytes memory returnData) {
        (ok, returnData) = address(this)
            .call(abi.encodeCall(Relay.initialize, (cfg, address(this), IRelay(address(0)), RELAY_TEST_GOVERNANCE)));
    }

    function _revertSelector(bytes memory returnData) internal pure returns (bytes4 selector) {
        if (returnData.length >= 4) {
            assembly {
                selector := mload(add(returnData, 0x20))
            }
        }
    }

    // thresholdIncreaseBIPS below 1.0x (THRESHOLD_BIPS) is rejected.
    // EXPECT: PASS (proof).
    function check_ctor_rejectsLowThresholdIncrease(uint16 tib) external {
        vm.assume(uint256(tib) < THRESHOLD_BIPS);
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.thresholdIncreaseBIPS = tib;
        (bool ok,) = _tryInitialize(cfg);
        assert(!ok);
    }

    // zero reward-epoch duration is rejected (RLY-11).
    // EXPECT: PASS (proof).
    function check_ctor_rejectsZeroRewardEpochDuration() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.rewardEpochDurationInVotingEpochs = 0;
        (bool ok,) = _tryInitialize(cfg);
        assert(!ok);
    }

    // zero voting-epoch duration is rejected (RLY-11).
    // EXPECT: PASS (proof).
    function check_ctor_rejectsZeroVotingEpochDuration() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.votingEpochDurationSeconds = 0;
        (bool ok,) = _tryInitialize(cfg);
        assert(!ok);
    }

    // zero initial signing-policy hash is rejected (L-4).
    // EXPECT: PASS (proof).
    function check_ctor_rejectsZeroPolicyHash() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(0));
        (bool ok,) = _tryInitialize(cfg);
        assert(!ok);
    }

    // RLY-23 home-force: on a home deploy (signing-policy setter present, as _tryInitialize passes) a
    // source chain id that is nonzero and != block.chainid is rejected — a live setter cannot bind a
    // foreign domain. EXPECT: PASS (proof).
    function check_ctor_homeForce_rejectsForeignSource(uint256 src) external {
        vm.assume(src != 0 && src != block.chainid);
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.sourceChainId = src;
        (bool ok,) = _tryInitialize(cfg);
        assert(!ok);
    }

    // Setter mode cannot seed a fee collector. Pin the exact custom error so this property cannot
    // pass merely because an otherwise-valid fixture regressed at an unrelated initializer guard.
    // EXPECT: PASS (proof).
    function check_ctor_setterMode_rejectsFeeCollectorExactly(address collector) external {
        vm.assume(collector != address(0));
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.feeCollectionAddress = payable(collector);
        (bool ok, bytes memory returnData) = _tryInitialize(cfg);
        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.FeeConfigNotAllowed.selector);
    }

    // Setter mode cannot seed protocol fees. The protocol id/value are otherwise valid; the
    // rejection must be the mode-specific FeeConfigNotAllowed error.
    // EXPECT: PASS (proof).
    function check_ctor_setterMode_rejectsFeeConfigExactly(uint256 fee) external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.feeConfigs = new IRelay.FeeConfig[](1);
        cfg.feeConfigs[0] = IRelay.FeeConfig({protocolId: 3, feeInWei: fee});
        (bool ok, bytes memory returnData) = _tryInitialize(cfg);
        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.FeeConfigNotAllowed.selector);
    }

    // Setter mode cannot seed fee exemptions. Pin FeeExemptionsNotAllowed independently of the
    // protocol-fee and collector guards above.
    // EXPECT: PASS (proof).
    function check_ctor_setterMode_rejectsFeeExemptionExactly(address account) external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.feeExemptAddresses = new address[](1);
        cfg.feeExemptAddresses[0] = account;
        (bool ok, bytes memory returnData) = _tryInitialize(cfg);
        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.FeeExemptionsNotAllowed.selector);
    }

    // Anti-vacuity: the valid base config initializes successfully.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_ctor_validDeploys() external {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        (bool ok,) = _tryInitialize(cfg);
        assert(!ok); // EXPECT counterexample: valid config initializes
    }
}
