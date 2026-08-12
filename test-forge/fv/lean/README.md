# Lean 4 — machine-checked signature-loop soundness

Two Lean developments prove the Relay signature-loop threshold soundness, fully universally quantified,
where the bounded tools (Halmos: fixed K; Kontrol: fixed N) cannot reach:

| File | Result | Object | Coverage |
|------|--------|--------|----------|
| `RelaySigLoop.lean` | **the abstract proof** | the accounting algorithm (no EVM) | **∀N ∀K** |
| `bytecode-refinement/RelayBytecodeRefinement.lean` | **the bytecode refinement** | a loop run by validated EVM/Yul semantics | **∀N** |

Both are hole-free: no `sorry`/`admit`/`native_decide`. Most results use only
`{propext, Classical.choice, Quot.sound}`; the data/window layer declares exactly three
upstream-dischargeable specifications (`RelayDataLayer.zeroes_data`,
`RelayDataLayer.toByteArray_size`, `RelayWindows.zeroes_data`), all explicitly allowlisted and reported.

## `RelaySigLoop.lean` — the abstract proof (∀N ∀K)

For an arbitrary list of voter weights `w` (so `N = w.length` is arbitrary) and an arbitrary signature
stream `idxs` (so `K` is arbitrary):

- `loop_inv` — the loop maintains `weight ≤ prefixSum(nextUnusedIndex)` and `nextUnusedIndex ≤ N`.
- `threshold_sound` — **accept ⟹ enough indexed policy weight**: if the loop accepts (final weight > threshold),
  the total registered weight exceeds the threshold.
- `insufficient_weight_cannot_accept` — the contrapositive.
- `bips_floor_strict_iff_cross` — floor division followed by the contract's strict comparison is exactly
  `signedWeight * 10000 > totalWeight * overrideBIPS`.
- `override_product_noOverflow` — the threshold product cannot wrap `UInt256` under the parser-wide
  total-weight bound and the production `overrideBIPS < 10000` guard.
- `selectThreshold_zero` / `selectThreshold_nonProtocolOne` — zero preserves the policy threshold, and
  no transient value changes a protocol other than protocol ID 1.
- `protocolOne_override_loop_sound` — composes the protocol-1 floor threshold with the existing strict
  signature-loop theorem.

No policy slot is counted twice: the strictly-increasing-index discipline is encoded in the `ValidRun`
predicate, so `prefixSum(N)` counts each indexed weight at most once. Addresses are not modeled; a
distinct-voter conclusion is conditional on policy admission enforcing unique voter addresses.

```bash
lean RelaySigLoop.lean        # Lean 4, core only (no mathlib) — checks in seconds
#print axioms RelaySigLoop.threshold_sound   # [propext, Quot.sound]
```

## `bytecode-refinement/RelayBytecodeRefinement.lean` — the bytecode refinement (∀N)

Lifts the abstract result onto a loop executed by NethermindEth's validated EVMYulLean operational
semantics, for all N: `bytecode_loop_correct` (the interpreter runs the loop to completion and computes
the accumulator) and `bytecode_threshold_sound` (accept ⟹ total > threshold, on the validated semantics).
The original encoded loop is memory-free. The later data/window developments discharge the masked-read and
overflow layers under their stated hypotheses, while the literal-body and dispatch theorems remain a
hand-transliterated, conditional refinement rather than extraction of the entire compiled program.
`RelayStorageLayer.tstore_tload` validates EVMYulLean's transient write/read semantics, and
`RelayBodyEff.protocolOne_tload_override_loop_sound` composes that value with the literal strict-loop
theorem. Its `hsetupThreshold` premise names the remaining unextracted setup seam across Relay's
`TSTORE -> self-call -> TLOAD -> threshold-local` path; call rollback and transaction-end clearing are
therefore not claimed.
Build/check instructions and the exact assumption boundary are in
`bytecode-refinement/README.md` and `../../../docs/relay-verification/`.

## Trust boundary

The abstract proof owns the accounting under `ValidRun`; the bytecode refinement connects that accounting
to validated EVM semantics for the modeled loop mechanism. The artifact gate binds the FV compiler output
and committed optimized Yul to the Hardhat deployment bytecode; the bounded behavioral link is the Halmos bridge
(`../RelayModelBridgeFV.t.sol`, K≤3); cryptography (`ecrecover`/`keccak`) and the boundary-call
operational contracts are stated assumptions. Full ledger: `../../../docs/relay-verification/`.
