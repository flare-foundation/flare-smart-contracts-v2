// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Bounded model-to-bytecode equivalence for the signature-loop weight invariant.
//
// This harness ties the prefix-sum model `psAt(k) = w_0 + ... + w_{k-1}` to the deployed Relay at
// K = 1, 2, and 3: whenever real `relay()` accepts, the corresponding modeled prefix sum is strictly
// greater than the threshold. `lean/RelaySigLoop.lean` proves the same accounting property for all K,
// while the Lean bytecode-refinement layer states the boundary between the compiled loop and that model.
//
// WHY NOT the fully-symbolic single-iteration form: relay() is monolithic — the loop's intermediate
// (weight, nextUnusedIndex) is not externally observable, and instrumenting the contract would change the
// bytecode under verification. The bounded Relay call and unbounded Lean theorem are therefore reported
// separately; neither is presented as an unbounded end-to-end bytecode proof.
//
// `_psAt` below is the conditional prefix sum of the 16-bit voter weights. Concrete N=3 policy,
// SYMBOLIC weights + threshold, symbolic signatures, ecrecover
// uninterpreted; same-epoch so no threshold-increase. halmos.toml loop=6 covers the 3-signature loop.
//
// New to Halmos? See test-forge/fv/README.md §2 — a `check_` function is a ∀-proof over its symbolic
// arguments; `vm.assume` is a hypothesis, `assert` is the goal, and `check_reach_*` is the anti-vacuity
// control that verify_fv.py requires to be REFUTED by a counterexample.
contract RelayModelBridgeFV is RelayTestBase {
    bytes32 internal constant ROOT = keccak256("fv-bridge-root");
    uint256 internal constant NV = 3;

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {}

    // Prefix-sum model used by the bounded bridge checks.
    function _psAt(uint256 k, uint16 w0, uint16 w1, uint16 w2) internal pure returns (uint256) {
        if (k == 0) return 0;
        if (k == 1) return uint256(w0);
        if (k == 2) return uint256(w0) + w1;
        return uint256(w0) + uint256(w1) + uint256(w2);
    }

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
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, ROOT);
        (ok, ) = address(r).call(abi.encodePacked(Relay.relay.selector, p, message, sigs));
    }

    // BRIDGE K=1 — real bytecode accept => model invariant psAt(1) > threshold.
    // Reads as: ∀ w0,thr,a . accept ⟹ _psAt(1,..) > thr. The `if (ok)` is the antecedent of the
    // implication (not control flow to skip a test): when the REAL bytecode accepts, the pure-Solidity
    // model's prefix sum must already exceed thr. A PASS ties bytecode behavior to the model at K=1.
    // EXPECT: PASS (proof).
    function check_bridge_1sig(uint16 w0, uint16 thr, Sig calldata a) external {
        (Relay r, bytes memory p) = _deploy(w0, 0, 0, thr);
        bool ok = _call(r, p, abi.encodePacked(uint16(1), _sig(a, 0)));
        if (ok) assert(_psAt(1, w0, 0, 0) > thr);
    }

    // BRIDGE K=2 — real bytecode accept => psAt(2) > threshold.
    // EXPECT: PASS (proof).
    function check_bridge_2sig(uint16 w0, uint16 w1, uint16 thr, Sig calldata a, Sig calldata b) external {
        (Relay r, bytes memory p) = _deploy(w0, w1, 0, thr);
        bool ok = _call(r, p, abi.encodePacked(uint16(2), _sig(a, 0), _sig(b, 1)));
        if (ok) assert(_psAt(2, w0, w1, 0) > thr);
    }

    // BRIDGE K=3 — real bytecode accept => psAt(3) > threshold.
    // EXPECT: PASS (proof).
    function check_bridge_3sig(
        uint16 w0, uint16 w1, uint16 w2, uint16 thr, Sig calldata a, Sig calldata b, Sig calldata c
    )
        external
    {
        (Relay r, bytes memory p) = _deploy(w0, w1, w2, thr);
        bool ok = _call(r, p, abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2)));
        if (ok) assert(_psAt(3, w0, w1, w2) > thr);
    }

    // Non-vacuity — the bridge is not trivially satisfied by always-revert: when psAt(3) > threshold the real
    // bytecode CAN accept. EXPECT: COUNTEREXAMPLE (bytecode accepts, so `ok && ...` reachable).
    function check_reach_bridge_canAccept(
        uint16 w0, uint16 w1, uint16 w2, uint16 thr, Sig calldata a, Sig calldata b, Sig calldata c
    )
        external
    {
        // Guards the bridge against a trivial "always reverts" reading: the assume puts us where the model
        // PREDICTS acceptance (psAt(3) > thr), then asserts ¬ok so verify_fv.py demands a counterexample —
        // ecrecover being uninterpreted, the solver can match all three recovered signers and the real
        // bytecode DOES accept. A refutation confirms the bridge implications above are non-vacuous.
        vm.assume(w0 > 0 && w1 > 0 && w2 > 0);
        vm.assume(_psAt(3, w0, w1, w2) > thr);
        (Relay r, bytes memory p) = _deploy(w0, w1, w2, thr);
        bool ok = _call(r, p, abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2)));
        assert(!ok); // EXPECT counterexample: real bytecode accepts when the model predicts it can
    }
}
