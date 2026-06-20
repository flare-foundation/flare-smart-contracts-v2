# Lean 4 — machine-checked signature-loop soundness

Two Lean developments prove the Relay signature-loop threshold soundness, fully universally quantified,
where the bounded tools (Halmos: fixed K; Kontrol: fixed N) cannot reach:

| File | Result | Object | Coverage |
|------|--------|--------|----------|
| `RelaySigLoop.lean` | **the abstract proof** | the accounting algorithm (no EVM) | **∀N ∀K** |
| `bytecode-refinement/RelayBytecodeRefinement.lean` | **the bytecode refinement** | a loop run by validated EVM/Yul semantics | **∀N** |

Both are hole-free: no `sorry`/`admit`/`axiom`, `#print axioms` ⊆ `{propext, Classical.choice, Quot.sound}`.

## `RelaySigLoop.lean` — the abstract proof (∀N ∀K)

For an arbitrary list of voter weights `w` (so `N = w.length` is arbitrary) and an arbitrary signature
stream `idxs` (so `K` is arbitrary):

- `loop_inv` — the loop maintains `weight ≤ prefixSum(nextUnusedIndex)` and `nextUnusedIndex ≤ N`.
- `threshold_sound` — **accept ⟹ enough genuine weight**: if the loop accepts (final weight > threshold),
  the total registered weight exceeds the threshold.
- `insufficient_weight_cannot_accept` — the contrapositive.

No voter is double-counted: the strictly-increasing-index discipline is encoded in the `ValidRun`
predicate, so `prefixSum(N)` counts each weight at most once.

```bash
lean RelaySigLoop.lean        # Lean 4, core only (no mathlib) — checks in seconds
#print axioms RelaySigLoop.threshold_sound   # [propext, Quot.sound]
```

## `bytecode-refinement/RelayBytecodeRefinement.lean` — the bytecode refinement (∀N)

Lifts the abstract result onto a loop executed by NethermindEth's validated EVMYulLean operational
semantics, for all N: `bytecode_loop_correct` (the interpreter runs the loop to completion and computes
the accumulator) and `bytecode_threshold_sound` (accept ⟹ total > threshold, on the validated semantics).
The encoded loop is memory-free; the data-layer, overflow-bound, and encoding assumptions are stated in
the claims ledger. Build/check instructions and the assumption boundary are in
`bytecode-refinement/README.md` and `../../../docs/relay-verification/`.

## Trust boundary

The abstract proof owns the accounting; the bytecode refinement connects it to validated EVM semantics for
the loop mechanism; the deployed-bytecode link at bounded K is the Halmos bridge
(`../RelayModelBridgeFV.t.sol`, K≤3); cryptography (`ecrecover`/`keccak`) and the boundary-call
operational contracts are stated assumptions. Full ledger: `../../../docs/relay-verification/`.
