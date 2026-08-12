// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// solhint-disable func-name-mixedcase

// Phase 3 Step 4 (R5): cross-epoch threshold-increase SCALING soundness.
// Faithful to Relay.sol:977-987 — on the cross-epoch path (relaying with the OLD signing policy for a
// not-yet-initialized newer epoch) the gate threshold is replaced by:
//     threshold := div(mul(threshold, thresholdIncreaseBIPS), THRESHOLD_BIPS)
// with thresholdIncreaseBIPS a 16-bit field required >= THRESHOLD_BIPS (Relay.sol:235).
// SAFETY: this rescale (which uses truncating EVM division) must NEVER weaken the threshold and must not
// overflow — otherwise the cross-epoch path could accept on LESS indexed policy weight than the same-epoch path.
// Self-contained (pure arithmetic with the real constants); models EVM truncating div faithfully.
// RUN: halmos --contract RelayThresholdScalingFV --solver-timeout-assertion 0
//      (the symbolic 16-bit product in check_scaling_neverWeakens needs ~73s — above the 60s default.)
// Verified verdicts: neverWeakens PASS, noOverflow PASS, identityAtBoundary PASS, reach_canIncrease CEX.

interface IVm { function assume(bool) external; }

contract RelayThresholdScalingFV {
    // solhint-disable-next-line const-name-snakecase
    IVm internal constant vm = IVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 internal constant THRESHOLD_BIPS = 10000; // Relay.sol:64
    uint256 internal constant WEIGHT_MASK = 0xffff;   // 16-bit field mask (Relay.sol:98)

    // Exact replica of Relay.sol:977-987 (truncating integer division, as EVM div).
    function _eff(uint256 threshold, uint256 tib) internal pure returns (uint256) {
        return (threshold * tib) / THRESHOLD_BIPS;
    }

    // R5a — THE safety property: the cross-epoch increase never WEAKENS the threshold (eff >= threshold).
    // Asserted in its division-free EQUIVALENT form: for non-negative integers, the truncating-division
    // identity  floor(x/d) >= t  <=>  x >= t*d  makes  eff = floor(threshold*tib/10000) >= threshold
    // exactly equivalent to  threshold*tib >= threshold*THRESHOLD_BIPS. (The post-division form makes Z3
    // time out on the /10000; this equivalent is the same theorem and solves instantly.)
    // EXPECT: PASS (proof).
    function check_scaling_neverWeakens(uint16 threshold, uint16 tib) external {
        vm.assume(tib >= THRESHOLD_BIPS);      // Relay.sol:235: thresholdIncreaseBIPS >= 10000 (uint16 => <=0xffff)
        assert(uint256(threshold) * uint256(tib) >= uint256(threshold) * THRESHOLD_BIPS);
    }

    // R5a' — corroborate the floor identity on the ACTUAL division at the boundary tib == THRESHOLD_BIPS
    // (1.0x): there the rescale is the identity, eff == threshold exactly (no truncation loss). This anchors
    // the equivalence used above to the real _eff() at the one point where it must hold with equality.
    // EXPECT: PASS (proof).
    function check_scaling_identityAtBoundary(uint16 threshold) external pure {
        assert(_eff(threshold, uint16(THRESHOLD_BIPS)) == threshold);
    }

    // R5b — no overflow / no wrap: the truncated result never exceeds the (fitting) product.
    // EXPECT: PASS (proof).
    function check_scaling_noOverflow(uint16 threshold, uint16 tib) external {
        uint256 prod = uint256(threshold) * uint256(tib); // <= 0xffff*0xffff < 2^32
        assert(_eff(threshold, tib) <= prod);  // div result <= dividend
    }

    // ANTI-VACUITY: the increase CAN strictly exceed the base threshold (the path is live) => CEX expected.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_scaling_canIncrease(uint16 threshold, uint16 tib) external {
        vm.assume(tib > THRESHOLD_BIPS);       // strictly above 1.0x (uint16 => <=0xffff)
        assert(_eff(threshold, tib) <= threshold); // claim "never strictly increases" -> FALSE => CEX
    }
}
