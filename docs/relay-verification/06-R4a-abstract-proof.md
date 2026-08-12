# R4a — unbounded abstract signature-accounting proof

[`RelaySigLoop.lean`](../../test-forge/fv/lean/RelaySigLoop.lean) models the
signature loop as a pure algorithm over arbitrary lists. Both the policy length
`N` and signature-list length `K` are universally quantified.

## Core invariant

For `nextUnusedIndex` and accumulated `weight`, the loop maintains:

```text
weight <= prefixSum(weights, nextUnusedIndex)
nextUnusedIndex <= weights.length
```

Strictly increasing accepted indices ensure that a policy slot contributes at
most once. From the invariant, the proof derives:

```text
acceptance -> accumulated weight > threshold
           -> total policy-slot weight > threshold
```

The contrapositive states that a policy whose total slot weight does not exceed
the threshold cannot accept.

## Threshold override arithmetic

The same development proves the integer-arithmetic relation used by the
protocol-1 BIPS threshold:

```text
signedWeight > floor(totalWeight * thresholdBIPS / 10000)
```

is equivalent, for the stated nonnegative bounds, to:

```text
signedWeight * 10000 > totalWeight * thresholdBIPS
```

It also proves the configured product cannot overflow a 256-bit word under the
parser-wide total-weight and BIPS bounds, that a zero override preserves the
policy threshold, and that other protocol IDs do not select the override.

## Exact theorem boundary

The proof establishes indexed policy-slot accounting. Addresses and ECDSA are
not part of the abstract state. A statement about distinct signers additionally
requires all voter addresses to be nonzero and unique at policy admission.

The theorem also assumes that the abstract run corresponds to the indices and
weights parsed by the implementation. That connection is the subject of
[`07-R4b-bytecode-refinement.md`](07-R4b-bytecode-refinement.md).

## Evidence bar

The Lean gate requires:

- the exact file inventory declared by the manifest;
- successful checking with the pinned Lean/EVMYulLean toolchain;
- a declared `#print axioms` audit for every exported result;
- no `sorry`, `admit`, `native_decide`, or undeclared axiom; and
- normalized source and generation provenance.

See [`CURRENT-STATUS.md`](CURRENT-STATUS.md) for whether the generated current
report satisfies that bar.
