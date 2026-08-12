/*
 * Relay.sol — threshold-override fail-fast and arithmetic properties.
 *
 * The production wrapper is called directly. Values at or above 100% must
 * revert before the wrapper can touch persistent or transient storage or make
 * its relay() self-call. Persistent ghosts are load-bearing here: ordinary
 * ghosts roll back together with an expected Solidity revert and therefore
 * cannot show whether an opcode was reached before that revert.
 *
 * The successful below-100% path is deliberately not summarized here. Its
 * address(this).call(_relayMessage) has raw, non-ABI calldata and solc via-IR
 * does not retain enough pointer information for a pessimistic Certora
 * dispatcher to prove the dynamic selector match. Assuming that match with an
 * optimistic dispatcher would turn the key self-call into a proof assumption.
 */

persistent ghost bool thresholdFailFastPersistentStoreTouched;
persistent ghost bool thresholdFailFastTransientStoreTouched;
persistent ghost bool thresholdFailFastCallTouched;

hook ALL_SSTORE(uint256 slot, uint256 value) {
    if (executingContract == currentContract) {
        thresholdFailFastPersistentStoreTouched = true;
    }
}

hook ALL_TSTORE(uint256 slot, uint256 value) {
    if (executingContract == currentContract) {
        thresholdFailFastTransientStoreTouched = true;
    }
}

hook CALL(
    uint256 gasAmount,
    address target,
    uint256 value,
    uint256 argsOffset,
    uint256 argsLength,
    uint256 retOffset,
    uint256 retLength
) uint256 result {
    if (executingContract == currentContract) {
        thresholdFailFastCallTouched = true;
    }
}

/// The wrapper's strict upper bound is checked before its first TSTORE and
/// before the raw-calldata relay() self-call. The zero-value precondition rules
/// out the unrelated Solidity nonpayable guard as the reason for the revert.
rule thresholdAtOrAbove100PercentRevertsBeforeEffects(
    env e,
    bytes relayMessage,
    bytes32 messageHash,
    uint16 thresholdBIPS
) {
    require e.msg.value == 0;
    require thresholdBIPS >= 10000;

    thresholdFailFastPersistentStoreTouched = false;
    thresholdFailFastTransientStoreTouched = false;
    thresholdFailFastCallTouched = false;

    verifyCustomSignatureWithThreshold@withrevert(e, relayMessage, messageHash, thresholdBIPS);
    bool reverted = lastReverted;

    assert reverted,
        "thresholds at or above 100 percent must revert";
    assert !thresholdFailFastPersistentStoreTouched,
        "the rejected threshold must not reach a persistent store";
    assert !thresholdFailFastTransientStoreTouched,
        "the rejected threshold must not reach a transient store";
    assert !thresholdFailFastCallTouched,
        "the rejected threshold must not reach the relay self-call";
}

/// Pure mathematical lemma for the documented strict comparison. This establishes
/// the floor/cross-product identity only; it deliberately does not claim that CVL can
/// observe relay()'s Yul-local `threshold` value. The production-code link remains a
/// separate source/concrete-symbolic obligation.
rule thresholdFloorCrossProductArithmeticLemma(
    uint256 totalWeight,
    uint256 signedWeight,
    uint16 thresholdBIPS
) {
    require totalWeight > 0;
    require totalWeight <= 19660500; // MAX_VOTERS * max_uint16
    require signedWeight <= totalWeight;
    require thresholdBIPS < 10000;

    mathint product = to_mathint(totalWeight) * to_mathint(thresholdBIPS);
    mathint threshold = product / 10000;
    mathint signed = to_mathint(signedWeight);

    assert threshold * 10000 <= product
        && product < (threshold + 1) * 10000,
        "threshold must be the mathematical floor of totalWeight * BIPS / 10000";
    assert (signed > threshold) <=> (signed * 10000 > product),
        "strict floor comparison must equal the exact BIPS cross-product comparison";
}
