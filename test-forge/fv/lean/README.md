# Lean 4 — abstract ∀N ∀K proof of the signature-loop invariant (Phase A)

`RelaySigLoop.lean` is a **theorem-prover** proof of the Relay signature-loop weight invariant that is
**genuinely universally quantified in both dimensions** — over all voter-set sizes N *and* all signature
counts K — which neither Halmos (bounded K) nor Kontrol (bounded N; symbolic-N is state-explosive) could
achieve. It is the "Phase A" deliverable of the theorem-prover track (see `../../../docs/relay-t1-bridge.md`
and `../../../docs/relay-phase3-documented-items.md`).

## What is proved

For an **arbitrary** list of voter weights `w` (so N = `w.length` is arbitrary) and an **arbitrary**
signature stream `idxs` (so K is arbitrary):

- `loop_inv` — the loop maintains the invariant `weight ≤ prefixSum(nextUnusedIndex)` and
  `nextUnusedIndex ≤ N`, for every step (by induction on the signature stream).
- `threshold_sound` — **accept ⟹ enough genuine weight**: if the loop accepts (final weight > threshold),
  the *total registered weight* exceeds the threshold.
- `insufficient_weight_cannot_accept` — the contrapositive: if total registered weight ≤ threshold, the
  loop can never accept, for any N and any K.

No voter is double-counted: the strictly-increasing-index discipline (G1+G2 on-chain) is encoded in the
`ValidRun` predicate, so the bound `prefixSum(N)` counts each weight at most once.

This mirrors the Kontrol model (`../kontrol/RelaySigLoopFV.t.sol`) exactly — same invariant
`weight ≤ psAt(nextUnusedIndex)` — but with real ∀N ∀K induction instead of fixed N ∈ {3,5}.

## Scope / trust boundary

This proves the **abstract algorithm** (the accounting). It does *not* by itself connect to the EVM
bytecode — that is the separate, expensive "Gap B" (bytecode refinement). The bytecode link is established
at bounded K by the Halmos bridge (`../RelayModelBridgeFV.t.sol`, K=1,2,3) and the modeling contract
(ecrecover/keccak assumed). Composition: abstract algorithm proven ∀N∀K (here) + algorithm matches the
deployed bytecode where checkable (Halmos, K≤3).

## Checking it

Lean 4 (tested with 4.31.0), **core only — no mathlib**, so it checks in seconds:

```bash
lean RelaySigLoop.lean        # exit 0, no output = proved
```

Integrity (no holes): the source contains no `sorry`/`admit`/`axiom`, and

```
#print axioms RelaySigLoop.threshold_sound
  -- depends on axioms: [propext, Quot.sound]      (Lean's standard foundational axioms; NO sorryAx)
```

confirms the proof is complete — it does not even use `Classical.choice`.
