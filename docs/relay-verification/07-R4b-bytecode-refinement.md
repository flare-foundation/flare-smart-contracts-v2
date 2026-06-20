# L7 — R4b: the bytecode refinement

> **What you get from this level.** The top rung: lifting the abstract proof's ∀N∀K abstract soundness onto a loop
> executed by a **validated model of the EVM**, for all N — crossing the assembly barrier for the loop
> mechanism. The overview, the result, and the honest residual. The mathematics is
> [L8 §C](08-the-mathematics.md); the verbatim Lean, fuel-genericity, and axiom audit are
> [L9 §C–F](09-the-formal-detail.md).

---

## 7.1 The gap the bytecode refinement closes

The abstract proof proves the *algorithm* is sound (R4a) but says nothing about the EVM. Halmos runs the *real
bytecode* but only at bounded size (R2). Kontrol/Certora cannot reach the unbounded real machine because of
the assembly barrier (R3). The missing connection — the "abstract-vs-real-machine" gap — is: *does a
validated model of the real machine genuinely run the unbounded loop the way the abstract proof assumes?*

The bytecode refinement answers yes, for all N, by **refinement against a validated EVM semantics**.

**Validated semantics:** NethermindEth's **EVMYulLean** — a Lean 4 formalization of EVM/Yul execution that
is itself **validated against the official Ethereum execution-spec test suites**. So "the EVM model
computes X" inherits the cross-client conformance corpus (the trust chain is [L2 §2.5](02-strategy-and-the-fidelity-ladder.md)).

**Artifact:** `test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean` — self-contained (it
re-proves every supporting lemma locally, so one `lake env lean` checks it). See
`test-forge/fv/lean/bytecode-refinement/README.md`.

---

## 7.2 What the bytecode refinement proves

A counting accumulation loop is encoded in the **real Yul AST** — `for { } lt(i,N) { i := add(i,1) } { w
:= add(w,i) }` — and run by the validated interpreter. The theorems are all **hole-free** (`#print axioms` ⊆
`[propext, Classical.choice, Quot.sound]`, no `sorryAx`):

| Theorem | Statement (informal) |
|---------|----------------------|
| `loop_acc` | the induction engine: for all iteration counts, the validated `exec` drives the loop and accumulates the abstract accumulator `absAcc` |
| `bytecode_loop_correct` | **∀N**: the validated interpreter runs the loop to completion (exact fuel `3N+10`, no `OutOfFuel`/exception) and the final accumulator equals `absAcc(0,N,0)` |
| `bytecode_threshold_sound` | **∀N**: on that validated execution, *accept* (final weight > `thr`) ⟹ total accumulation > `thr` (in `𝕌`, mod 2²⁵⁶) |
| `absAcc_val` / `bytecode_threshold_sound_int` | **∀N**: under the explicit no-overflow hypothesis `Σ < 2²⁵⁶`, the modular accumulator equals the *integer* accumulator, so *accept* ⟹ the **integer** total > `thr` (discharges BR-2 — see §7.3) |

`bytecode_threshold_sound` is the abstract proof's `threshold_sound` shape — *accept ⟹ enough accumulated total* — now
holding of a loop run by a **validated model of the real machine**, for every N. That is the rung-R4
statement.

**The one clever step — *fuel-genericity*.** The interpreter is defined by recursion on a "fuel" step
budget, and EVMYulLean has no fuel-monotonicity lemma, so reasoning at the symbolic fuel arising in the
induction looks blocked. The resolution: prove each statement's effect at fuel `fuel + K` with `fuel` a
free variable and `K` the *exact* unfolding cost; the simplifier peels exactly `K` steps regardless of
`fuel`. This converts a missing meta-theorem about someone else's interpreter into local, decidable
per-statement facts, and is what made the whole induction routine. Full treatment: [L8 §C.3](08-the-mathematics.md),
[L9 §D](09-the-formal-detail.md). It is reusable on any fuel-indexed interpreter ([L12](12-lessons.md)).

---

## 7.3 The honest residual (what the bytecode refinement does *not* claim)

This is the most important part of the rung for an auditor; the full ledger is [L10](10-claims-ledger-trust-and-residual.md).

- **The loop is memory-free.** Its body adds the loop *index* `i`, not `mload(weights[i])`. So the bytecode
  refinement proves the **loop mechanism** — iterate ∀N, faithfully fold a per-step quantity, threshold
  transfers — which is the part the assembly barrier attacks. That the per-step quantity is the *registered
  weight* is the **data layer (BR-1)**: assumed, validated separately (the slot arithmetic matches the
  documented layout and the reference encoder). The refinement is agnostic to the addend's *value*, so a
  layout bug would falsify BR-1, not the proof; BR-1 is the right place for a skeptic to push.
- **Modular vs. integer arithmetic (BR-2) — now internalized.** The bytecode refinement reasons in
  `𝕌 = Fin 2²⁵⁶` (mod 2²⁵⁶); the abstract proof in `ℕ`. `bytecode_threshold_sound_int` carries an explicit
  `Σ < 2²⁵⁶` hypothesis and proves (via `absAcc_val`) that the modular accumulator equals the integer
  accumulator, so accept ⟹ the integer total > thr. The hypothesis itself holds for Relay with vast margin
  (`totalWeight < 2¹⁶ ≪ 2²⁵⁶`).
- **Encoding fidelity (BR-3).** The `For` node mirrors the loop's iterate-and-accumulate *skeleton* (note
  the no-init form, matching the optimizer); it is not a verbatim transcription of the whole signature
  routine (cryptography is out of scope, MC-2; the no-double-count discipline is the abstract proof's
  `ValidRun`).

The bytecode refinement therefore establishes: *the abstract-vs-real bridge for the unbounded loop
mechanism, machine-checked against validated semantics, for all N* — not "the deployed contract is fully
verified."

---

## 7.4 Status and reproduce

- **Hole-free**, axioms `[propext, Classical.choice, Quot.sound]`, re-verified from the git-committed copy
  from scratch (`lake env lean`, exit 0).

```bash
# Build the validated semantics (one-time), then check the capstone. See L11 for full detail.
cd /tmp && git clone --depth 1 https://github.com/NethermindEth/EVMYulLean evmyul2
cd evmyul2 && lake exe cache get && lake build
cp <repo>/test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean .
lake env lean RelayBytecodeRefinement.lean
# expect exit 0 and, for loop_acc / bytecode_loop_correct / bytecode_threshold_sound:
#   depends on axioms: [propext, Classical.choice, Quot.sound]
```

---

## 7.5 Where this leaves the stack

With the bytecode refinement in place, the chain is complete end-to-end at the loop-mechanism level:

```
Halmos: the real bytecode obeys the model's prefix-sum invariant (RelayModelBridgeFV), K≤3      [R2]
Abstract proof:        the abstract algorithm is threshold-sound                              ∀N ∀K            [R4a]
Bytecode refinement:   a validated EVM semantics runs the unbounded loop & soundness transfers ∀N              [R4b]
─────────────────────────────────────────────────────────────────────────────────────────────
residual (assumed, validated separately): data layer (BR-1), overflow bound (BR-2), encoding (BR-3), crypto (MC-2), ecrecover ABI (OP-1)
```

Everything from loop control flow through accumulation through threshold soundness is machine-checked; the
residual is small and named.

**Next:** the deep dives — [L8 — the mathematics](08-the-mathematics.md) and
[L9 — the formal detail](09-the-formal-detail.md); or the audit core,
[L10 — claims ledger, trust & residual](10-claims-ledger-trust-and-residual.md).
