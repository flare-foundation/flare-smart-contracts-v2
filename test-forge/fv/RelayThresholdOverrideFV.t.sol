// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {RelayProxy} from "../../contracts/protocol/implementation/RelayProxy.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
import {RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

/// Verification-only Relay subclass exposing the production threshold-override transient slot.
/// Calls go through RelayProxy, so TLOAD/TSTORE execute in the proxy's address-scoped transient
/// storage exactly as production relay() and verifyCustomSignatureWithThreshold do.
contract RelayThresholdOverrideHarness is Relay {
    // uint256(keccak256("flare.relay.thresholdOverride")); pinned to Relay.TSLOT_THRESHOLD_OVERRIDE.
    uint256 private constant THRESHOLD_OVERRIDE_SLOT =
        0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3;

    function fvStoreThresholdOverride(uint256 value) external {
        uint256 slot = THRESHOLD_OVERRIDE_SLOT;
        assembly {
            tstore(slot, value)
        }
    }

    function fvLoadThresholdOverride() external view returns (uint256 value) {
        uint256 slot = THRESHOLD_OVERRIDE_SLOT;
        assembly {
            value := tload(slot)
        }
    }
}

// FDC2 threshold-override verification on the real Relay bytecode path.
//
// The concrete policy has five voters of weight 100 (totalWeight=500), policy threshold 260.
// Symbolic ECDSA fields let Halmos choose valid recovered voters without assuming forge keys.
// For every nonzero override the intended predicate is exactly:
//
//     signedWeight * 10000 > totalWeight * thresholdBIPS.
//
// Floor division followed by Relay's strict `weight > threshold` check implements that predicate.
// The paired `check_reach_*` controls ensure the accepting paths are genuinely reachable under the
// configured loop bound; proofs cover arithmetic boundaries, the zero sentinel, protocol-id isolation,
// and the EIP-1153 success/revert/address-scoping invariants.
contract RelayThresholdOverrideFV is RelayTestBase {
    bytes internal policy;
    RelayThresholdOverrideHarness internal thresholdRelay;
    RelayThresholdOverrideHarness internal otherRelay;

    bytes32 internal constant ROOT = bytes32(uint256(0xBEEF));
    uint24 internal constant NEW_EPOCH = uint24(REWARD_EPOCH_ID) + 1;
    uint32 internal constant NEW_START = START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION;
    address internal constant NEW_VOTER = address(uint160(0x2001));
    uint16 internal constant NEW_WEIGHT = 100;

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function setUp() public override {
        for (uint256 i = 0; i < N; i++) {
            // forge-lint: disable-next-line(unsafe-typecast)
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT);
            pks.push(0);
        }
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        thresholdRelay = _deployThresholdRelay();
        // Keep all CREATEs in the concrete setup phase. Halmos 0.3.3 can become stuck when a
        // verification function itself dynamically creates a Relay/proxy pair.
        otherRelay = _deployThresholdRelay();
    }

    function _deployThresholdRelay() internal returns (RelayThresholdOverrideHarness target) {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(_signingPolicyHash(policy));
        RelayThresholdOverrideHarness implementation = new RelayThresholdOverrideHarness();
        RelayProxy proxy =
            new RelayProxy(address(implementation), cfg, address(0), IRelay(address(0)), RELAY_TEST_GOVERNANCE);
        target = RelayThresholdOverrideHarness(payable(address(proxy)));
    }

    function _sig(Sig calldata value, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(value.v, value.r, value.s, index);
    }

    function _twoSigs(Sig calldata a, Sig calldata b) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(2), _sig(a, 0), _sig(b, 1));
    }

    function _threeSigs(Sig calldata a, Sig calldata b, Sig calldata c) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
    }

    function _fourSigs(Sig calldata a, Sig calldata b, Sig calldata c, Sig calldata d)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(uint16(4), _sig(a, 0), _sig(b, 1), _sig(c, 2), _sig(d, 3));
    }

    function _fiveSigs(Sig calldata a, Sig calldata b, Sig calldata c, Sig calldata d, Sig calldata e)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(uint16(5), _sig(a, 0), _sig(b, 1), _sig(c, 2), _sig(d, 3), _sig(e, 4));
    }

    function _customRelayMessage(bytes memory sigs) internal view returns (bytes memory) {
        bytes memory message = _protocolMessage(1, 0, false, ROOT);
        return abi.encodePacked(Relay.relay.selector, policy, message, sigs);
    }

    function _modeTwoRelayMessage(bytes memory sigs) internal view returns (bytes memory) {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, ROOT);
        return abi.encodePacked(Relay.relay.selector, policy, message, sigs);
    }

    function _newPolicy() internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(1), NEW_EPOCH, NEW_START, uint16(60), bytes32(SEED), NEW_VOTER, NEW_WEIGHT);
    }

    function _modeOneRelayMessage(bytes memory sigs) internal view returns (bytes memory) {
        return abi.encodePacked(Relay.relay.selector, policy, uint8(0), _newPolicy(), sigs);
    }

    function _callOverride(bytes memory relayMessage, uint16 thresholdBIPS)
        internal
        returns (bool ok, bytes memory returnData)
    {
        (ok, returnData) = address(thresholdRelay)
            .call(abi.encodeCall(IRelay.verifyCustomSignatureWithThreshold, (relayMessage, ROOT, thresholdBIPS)));
    }

    function _callPolicyThreshold(bytes memory relayMessage) internal returns (bool ok, bytes memory returnData) {
        (ok, returnData) =
            address(thresholdRelay).call(abi.encodeCall(IRelay.verifyCustomSignature, (relayMessage, ROOT)));
    }

    function _callRelay(bytes memory relayMessage) internal returns (bool ok) {
        (ok,) = address(thresholdRelay).call(relayMessage);
    }

    function _revertSelector(bytes memory returnData) internal pure returns (bytes4 selector) {
        if (returnData.length >= 4) {
            assembly {
                selector := mload(add(returnData, 0x20))
            }
        }
    }

    /// Concrete smoke for every short-selector length and the non-relay selector boundary.
    function test_fvCustomSelectorGuards() external {
        this.check_customCalls_shortCalldataRejected(0, bytes3(0xabcdef), 0);
        this.check_customCalls_shortCalldataRejected(1, bytes3(0xabcdef), 1);
        this.check_customCalls_shortCalldataRejected(2, bytes3(0xabcdef), 3999);
        this.check_customCalls_shortCalldataRejected(3, bytes3(0xabcdef), 9999);
        this.check_customCalls_nonRelaySelectorRejected(bytes4(0), bytes32(uint256(1)), 1);
        this.check_customCalls_relaySelectorReachesRelay();
    }

    /// Every calldata length below four fails with NotRelayCall in both public
    /// wrappers. Payload bytes and every permitted override remain symbolic.
    /// The exact selector rules out another revert reason, and the override
    /// wrapper must roll back its transient write after rejecting the selector.
    // EXPECT: PASS (proof).
    function check_customCalls_shortCalldataRejected(uint8 length, bytes3 contents, uint16 thresholdBIPS) external {
        vm.assume(length < 4);
        vm.assume(thresholdBIPS < 10000);
        // Branch on the complete short-length domain so every encoding has a
        // concrete size for Halmos while all bytes in that encoding stay symbolic.
        bytes memory relayMessage;
        if (length == 0) {
            relayMessage = bytes("");
        } else if (length == 1) {
            relayMessage = abi.encodePacked(bytes1(contents));
        } else if (length == 2) {
            relayMessage = abi.encodePacked(bytes2(contents));
        } else {
            relayMessage = abi.encodePacked(contents);
        }
        (bool baselineOk, bytes memory baselineData) = _callPolicyThreshold(relayMessage);
        (bool overrideOk, bytes memory overrideData) = _callOverride(relayMessage, thresholdBIPS);
        assert(!baselineOk && !overrideOk);
        assert(baselineData.length == 4 && overrideData.length == 4);
        assert(_revertSelector(baselineData) == IRelay.NotRelayCall.selector);
        assert(_revertSelector(overrideData) == IRelay.NotRelayCall.selector);
        assert(thresholdRelay.fvLoadThresholdOverride() == 0);
    }

    /// All non-relay selectors are rejected before a self-call, for a fixed
    /// 32-byte symbolic tail. The proof covers both wrappers and all permitted
    /// override values; longer arbitrary tails are outside this bounded shape.
    // EXPECT: PASS (proof).
    function check_customCalls_nonRelaySelectorRejected(bytes4 selector, bytes32 tail, uint16 thresholdBIPS) external {
        vm.assume(selector != IRelay.relay.selector);
        vm.assume(thresholdBIPS < 10000);
        bytes memory relayMessage = abi.encodePacked(selector, tail);
        (bool baselineOk, bytes memory baselineData) = _callPolicyThreshold(relayMessage);
        (bool overrideOk, bytes memory overrideData) = _callOverride(relayMessage, thresholdBIPS);
        assert(!baselineOk && !overrideOk);
        assert(baselineData.length == 4 && overrideData.length == 4);
        assert(_revertSelector(baselineData) == IRelay.NotRelayCall.selector);
        assert(_revertSelector(overrideData) == IRelay.NotRelayCall.selector);
        assert(thresholdRelay.fvLoadThresholdOverride() == 0);
    }

    /// The allowed selector passes the outer guard and reaches relay's metadata
    /// check: a selector-only body is wrapped as VerificationFailed, not rejected
    /// as NotRelayCall. Full success is required by the quorum reachability
    /// controls elsewhere in this harness.
    // EXPECT: PASS (proof).
    function check_customCalls_relaySelectorReachesRelay() external {
        bytes memory relayMessage = abi.encodePacked(IRelay.relay.selector);
        (bool baselineOk, bytes memory baselineData) = _callPolicyThreshold(relayMessage);
        (bool overrideOk, bytes memory overrideData) = _callOverride(relayMessage, 1);
        assert(!baselineOk && !overrideOk);
        assert(baselineData.length == 4 && overrideData.length == 4);
        assert(_revertSelector(baselineData) == IRelay.VerificationFailed.selector);
        assert(_revertSelector(overrideData) == IRelay.VerificationFailed.selector);
        assert(thresholdRelay.fvLoadThresholdOverride() == 0);
    }

    // Any accepting two-signature execution satisfies the advertised exact cross-product predicate.
    // EXPECT: PASS (proof).
    function check_override_twoSignerAcceptanceImpliesExactBips(uint16 thresholdBIPS, Sig calldata a, Sig calldata b)
        external
    {
        vm.assume(thresholdBIPS > 0 && thresholdBIPS < 10000);
        (bool ok,) = _callOverride(_customRelayMessage(_twoSigs(a, b)), thresholdBIPS);
        assert(!ok || 2 * uint256(WEIGHT) * 10000 > N * uint256(WEIGHT) * thresholdBIPS);
    }

    // At exactly 4000 BIPS, 200/500 is equality and strict `>` must reject every signature pair.
    // EXPECT: PASS (proof).
    function check_override_exact4000Boundary_rejects(Sig calldata a, Sig calldata b) external {
        (bool ok,) = _callOverride(_customRelayMessage(_twoSigs(a, b)), 4000);
        assert(!ok);
    }

    // Immediately below equality, floor(500*3999/10000)=199, so 200/500 is reachable.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_override_3999_twoSignersCanAccept(Sig calldata a, Sig calldata b) external {
        (bool ok,) = _callOverride(_customRelayMessage(_twoSigs(a, b)), 3999);
        assert(!ok);
    }

    // At 9999 BIPS, floor(499.95)=499; four voters carry only 400 and can never accept.
    // EXPECT: PASS (proof).
    function check_override_9999_rejectsFourOfFive(Sig calldata a, Sig calldata b, Sig calldata c, Sig calldata d)
        external
    {
        (bool ok,) = _callOverride(_customRelayMessage(_fourSigs(a, b, c, d)), 9999);
        assert(!ok);
    }

    // The same 9999-BIPS threshold must be reachable with all 500/500 weight; ceiling would block it.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_override_9999_allWeightCanAccept(
        Sig calldata a,
        Sig calldata b,
        Sig calldata c,
        Sig calldata d,
        Sig calldata e
    ) external {
        (bool ok,) = _callOverride(_customRelayMessage(_fiveSigs(a, b, c, d, e)), 9999);
        assert(!ok);
    }

    // Zero is the no-override sentinel: success/failure and successful return data match the baseline entrypoint.
    // EXPECT: PASS (proof).
    function check_zeroOverride_matchesPolicyThreshold(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bytes memory relayMessage = _customRelayMessage(_threeSigs(a, b, c));
        (bool policyThresholdOk, bytes memory policyThresholdData) = _callPolicyThreshold(relayMessage);
        (bool zeroOk, bytes memory zeroData) = _callOverride(relayMessage, 0);
        assert(policyThresholdOk == zeroOk);
        if (policyThresholdOk) {
            assert(policyThresholdData.length == zeroData.length);
            assert(abi.decode(policyThresholdData, (uint256)) == abi.decode(zeroData, (uint256)));
        }
    }

    // The policy-quorum success branch used by the zero-equivalence proof is reachable.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_zeroOverride_policyQuorumCanAccept(Sig calldata a, Sig calldata b, Sig calldata c) external {
        (bool ok,) = _callOverride(_customRelayMessage(_threeSigs(a, b, c)), 0);
        assert(!ok);
    }

    // Every uint16 value at or above 10000 fails fast with the exact ThresholdTooHigh selector.
    // EXPECT: PASS (proof).
    function check_overrideAtOrAbove100Percent_rejectedExactly(uint16 thresholdBIPS) external {
        vm.assume(thresholdBIPS >= 10000);
        (bool ok, bytes memory returnData) = _callOverride(bytes(""), thresholdBIPS);
        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.ThresholdTooHigh.selector);
    }

    // A raw transient override cannot lower Mode-1's policy quorum: two old-policy voters remain insufficient.
    // EXPECT: PASS (proof).
    function check_protocolIdZero_ignoresOverride(Sig calldata a, Sig calldata b) external {
        thresholdRelay.fvStoreThresholdOverride(1);
        assert(!_callRelay(_modeOneRelayMessage(_twoSigs(a, b))));
    }

    // Mode-1 is not globally disabled in this fixture; three old-policy voters can install the valid policy.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_modeOne_policyQuorumCanAccept(Sig calldata a, Sig calldata b, Sig calldata c) external {
        thresholdRelay.fvStoreThresholdOverride(1);
        assert(!_callRelay(_modeOneRelayMessage(_threeSigs(a, b, c))));
    }

    // A raw transient override cannot lower Mode-2's policy quorum: 200 remains below policy threshold 260.
    // EXPECT: PASS (proof).
    function check_protocolIdGreaterThanOne_ignoresOverride(Sig calldata a, Sig calldata b) external {
        thresholdRelay.fvStoreThresholdOverride(1);
        assert(!_callRelay(_modeTwoRelayMessage(_twoSigs(a, b))));
    }

    // Mode-2's accepting path remains reachable at the real policy quorum while the raw override is present.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_protocolIdGreaterThanOne_policyQuorumCanAccept(Sig calldata a, Sig calldata b, Sig calldata c)
        external
    {
        thresholdRelay.fvStoreThresholdOverride(1);
        assert(!_callRelay(_modeTwoRelayMessage(_threeSigs(a, b, c))));
    }

    // Whenever the 3999-BIPS call succeeds, its explicit post-call TSTORE has cleared the slot.
    // The paired 3999 reachability control above prevents this implication from being vacuous.
    // EXPECT: PASS (proof).
    function check_successfulOverride_clearsTransient(Sig calldata a, Sig calldata b) external {
        (bool ok,) = _callOverride(_customRelayMessage(_twoSigs(a, b)), 3999);
        uint256 afterCall = thresholdRelay.fvLoadThresholdOverride();
        assert(!ok || afterCall == 0);
    }

    // A below-10000 wrapper call stores before invoking relay(); when the inner call reverts and the caller
    // catches it, EIP-1153 rollback restores the slot to zero.
    // EXPECT: PASS (proof).
    function check_caughtRevert_rollsBackTransient() external {
        (bool ok,) = _callOverride(bytes(""), 1);
        assert(!ok);
        assert(thresholdRelay.fvLoadThresholdOverride() == 0);
    }

    // The caught revert cannot weaken a following baseline verification in the same transaction: two voters
    // still fail the policy threshold, which would not hold if the 1-BIPS transient override leaked.
    // EXPECT: PASS (proof).
    function check_caughtRevert_preservesPolicyThreshold(Sig calldata a, Sig calldata b) external {
        (bool failedCallOk,) = _callOverride(bytes(""), 1);
        assert(!failedCallOk);
        (bool policyThresholdOk,) = _callPolicyThreshold(_customRelayMessage(_twoSigs(a, b)));
        assert(!policyThresholdOk);
    }

    // The reachability/sensitivity control: manually placing 1 BIPS in the real slot can make the exact
    // same two-voter baseline call accept. Thus the preceding no-leak proof genuinely observes this slot.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_manualOverride_lowersProtocolIdOne(Sig calldata a, Sig calldata b) external {
        thresholdRelay.fvStoreThresholdOverride(1);
        (bool ok,) = _callPolicyThreshold(_customRelayMessage(_twoSigs(a, b)));
        assert(!ok);
    }

    // Transient storage is scoped by contract address: writes through two Relay proxies at the identical
    // slot remain independently observable and cannot overwrite or leak into one another.
    // EXPECT: PASS (proof).
    function check_transientStorage_isAddressScoped(uint16 firstValue, uint16 secondValue) external {
        vm.assume(firstValue != 0 && secondValue != 0 && firstValue != secondValue);
        thresholdRelay.fvStoreThresholdOverride(firstValue);
        otherRelay.fvStoreThresholdOverride(secondValue);
        assert(thresholdRelay.fvLoadThresholdOverride() == firstValue);
        assert(otherRelay.fvLoadThresholdOverride() == secondValue);
    }
}
