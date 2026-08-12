// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {IIRelay} from "../../contracts/protocol/interface/IIRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Phase 3 Step 1/4 (AC-1): ACCESS CONTROL on setSigningPolicy.
// setSigningPolicy is `onlySigningPolicySetter` (Relay.sol:219-220,325): require(msg.sender ==
// signingPolicySetter, "only sign policy setter"). So ONLY the registered setter (on Flare:
// FlareSystemsManager) can ever rotate the signing policy — no other caller can, for ANY setter address.
// Proven with a SYMBOLIC signingPolicySetter s != msg.sender on an otherwise-fully-valid policy, so the
// guard is the only admissible revert reason. (msg.sender into Relay is this test contract.)
contract RelayAccessControlFV is RelayTestBase {
    function setUp() public override {}

    function _setterConfig() internal view returns (IRelay.RelayInitialConfig memory cfg) {
        cfg = _initialConfig(bytes32(uint256(1)));
        cfg.feeCollectionAddress = payable(address(0));
    }

    function _validPolicy(uint24 epoch) internal pure returns (IIRelay.SigningPolicy memory sp) {
        sp.rewardEpochId = epoch;
        sp.startVotingRoundId = START_VOTING_ROUND_ID;
        sp.threshold = 60;
        sp.seed = SEED;
        sp.voters = new address[](1);
        sp.voters[0] = address(uint160(0x1001));
        sp.weights = new uint16[](1);
        sp.weights[0] = 100;
    }

    // AC-1 — for ANY setter address that is not the caller, setSigningPolicy reverts (caller is not authorised).
    // EXPECT: PASS (proof).
    function check_setSigningPolicy_onlySetter(address s) external {
        vm.assume(s != address(this)); // the caller (this test) is NOT the registered setter
        Relay r = deployRelay(_setterConfig(), s, IRelay(address(0)));
        IIRelay.SigningPolicy memory sp = _validPolicy(uint24(REWARD_EPOCH_ID) + 1); // valid & correct epoch
        (bool ok,) = address(r).call(abi.encodeCall(Relay.setSigningPolicy, (sp)));
        assert(!ok); // non-setter caller => revert at the onlySigningPolicySetter guard
    }

    // Anti-vacuity: when the caller IS the setter, the guard passes and the (valid) policy is accepted.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_setter_canCall() external {
        Relay r = deployRelay(_setterConfig(), address(this), IRelay(address(0)));
        IIRelay.SigningPolicy memory sp = _validPolicy(uint24(REWARD_EPOCH_ID) + 1);
        (bool ok,) = address(r).call(abi.encodeCall(Relay.setSigningPolicy, (sp)));
        assert(!ok); // EXPECT counterexample: the setter can call successfully
    }
}
