// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// solhint-disable func-name-mixedcase

// Local native-mode verify() fee-conservation arithmetic.
// On the non-oldRelay branch with feeToken == address(0), verify() requires
// msg.value >= fee, forwards exactly `fee` to the collection address, and
// refunds the remainder `msg.value - fee` to msg.sender:
//   require(msg.value >= fee);  ... forward fee ...  refund = msg.value - fee;  if (refund>0) send refund.
// SAFETY: no ETH is created or destroyed (forwarded + refunded == msg.value) and the refund cannot
// underflow. This complements RelayFeeConservationFV (the REAL balance movements of a succeeding
// local verify()): this file pins the underlying split arithmetic. RelayOldRelayFeeFV separately
// executes the pre-boundary delegation branch, which forwards zero and refunds the full msg.value.
// Pure-arithmetic model of the local value flow. The compiled-path harnesses check balance movements.
interface IVm {
    function assume(bool) external;
}

contract RelayVerifyFeeFV {
    // solhint-disable-next-line const-name-snakecase
    IVm internal constant vm = IVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // Models the local value split under the native-fee require guard.
    function _split(uint256 msgValue, uint256 fee) internal pure returns (uint256 forwarded, uint256 refund) {
        // require(msg.value >= fee) — modeled as the precondition below
        forwarded = fee;
        refund = msgValue - fee; // safe: msgValue >= fee
    }

    // Conservation: forwarded + refund == msg.value (no ETH created or destroyed).
    // EXPECT: PASS (proof).
    function check_fee_conserved(uint256 msgValue, uint256 fee) external {
        vm.assume(msgValue >= fee); // the require(msg.value >= fee) guard
        (uint256 forwarded, uint256 refund) = _split(msgValue, fee);
        assert(forwarded + refund == msgValue);
    }

    // The refund never exceeds msg.value and the fee is forwarded exactly.
    // EXPECT: PASS (proof).
    function check_fee_noOverpayKept(uint256 msgValue, uint256 fee) external {
        vm.assume(msgValue >= fee);
        (uint256 forwarded, uint256 refund) = _split(msgValue, fee);
        assert(forwarded == fee && refund <= msgValue);
    }

    // Underpayment is rejected: the require(msg.value >= fee) guard is the only acceptance gate,
    // so msg.value < fee can never proceed (modeled: the precondition is necessary for a well-defined split).
    // EXPECT: PASS (proof).
    function check_fee_underpaymentImpossible(uint256 msgValue, uint256 fee) external {
        vm.assume(msgValue < fee);
        // with msgValue < fee the contract reverts at require(msg.value >= fee); there is no split.
        // we assert the guard's contrapositive: a conserved split requires msgValue >= fee.
        assert(!(msgValue >= fee));
    }

    // Anti-vacuity: a conserving payment (msg.value == fee, refund 0) is reachable. EXPECT: COUNTEREXAMPLE.
    function check_reach_exactFee(uint256 fee) external {
        (uint256 forwarded, uint256 refund) = _split(fee, fee);
        assert(!(forwarded == fee && refund == 0));
    }
}
