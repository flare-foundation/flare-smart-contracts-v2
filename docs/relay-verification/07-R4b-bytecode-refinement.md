# L7 — R4b: the bytecode refinement

> **What you get from this level.** The top rung: lifting the abstract proof's ∀N∀K soundness onto a loop
> executed by a **validated model of the EVM**, for all N — crossing the assembly barrier. §7.2 establishes the
> loop *mechanism* (memory-free); §7.3 then discharges the **data layer (BR-1)** — the body becomes the
> deployed contract's real `mload(slot) & 0xffff` read — and composes the full simulation relation
> `relay_loop_sound` (accept ⟹ total registered weight > threshold), with the external call (`ecrecover`) as
> the stated assumption. The overview, the results, and the honest residual. The mathematics is
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

**Artifact:** [`test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean) — self-contained (it
re-proves every supporting lemma locally, so one `lake env lean` checks it). See
[`test-forge/fv/lean/bytecode-refinement/README.md`](../../test-forge/fv/lean/bytecode-refinement/README.md).

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

## 7.3 Discharging the data layer (BR-1): the memory-reading loop and the full relation `R`

§7.2's loop is *memory-free* — its body adds the index `i`, which establishes the loop **mechanism**. The
data layer (BR-1) — that each addend is the *registered weight* `mload(weights[i]) & 0xffff` — was originally
left as a stated assumption. It is now **proven against the validated semantics**, in two committed, hole-free
files.

**The data layer, brick by brick ([`DataLayer.lean`](../../test-forge/fv/lean/bytecode-refinement/DataLayer.lean)).** Each fact is proved about EVMYulLean's *actual*
`ByteArray` / `MachineState` / `UInt256` operations. (Lean 4.22 has no `ByteArray` lemma layer, so the proofs
descend to the `Array.data` level — see [L9](09-the-formal-detail.md).)

| Lemma | What it proves (against the real EVM model) |
|---|---|
| `fromBytesBigEndian_toBytesBigEndian` | the big-endian byte encode/decode round-trips |
| `mem_roundtrip` | `readWithPadding (write src 0 mem d 32) d 32 = src` — write-a-word-then-read is the identity |
| `fromByteArray_toByteArray` | `fromByteArrayBigEndian (v.toByteArray) = v.toNat` (value decode) |
| `mstore_mload` | `(mstore a v).mload a = v` — operational round-trip, with the `activeWords`/size guard discharged |
| `mask16_toNat` / `mask16_of_lt` | `and(x, 0xffff)` extracts the low 16 bits; identity on a 16-bit weight |
| `weight_read` | the capstone: `mload(slot) & 0xffff = w` for a 16-bit weight stored at a 32-byte slot |

These add exactly **two** documented, upstream-dischargeable axioms beyond the standard three — `zeroes_data`
(the `opaque` `memset_zero`) and `toByteArray_size` (blocked only by a `private` upstream bound). Both are
*access-modifier* limitations, not semantic assumptions; each becomes a theorem with a one-line upstream edit.

**The memory-reading loop, ∀N ([`RelayLoopMemRead.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopMemRead.lean)).** §7.2's body is replaced by the deployed contract's
*actual* masked read `w := w + (mload(i·32) & 0xffff)`, executed by the validated Yul `exec`:

- `body_effM` — one iteration of the real `mload`+`and` body (the `mload` is state-preserving once the slot
  is active, so it does not perturb `activeWords`);
- `loop_accM` / `bytecode_threshold_sound_mem` (and its integer form `_int`) — the `3N+15`-fuel induction:
  **∀N**, accept ⟹ the total of the masked *memory reads* exceeds the threshold.

**The full simulation relation `relay_loop_sound`.** Composing the EVM accumulation with the abstract
accounting — `bridge` identifies the masked-read sum with `RelaySigLoop.sigLoop`'s accumulated weight, and the
abstract `threshold_sound` is restated in-file (so one `lake env lean` checks the whole chain):

> **∀N: if the deployed signature loop accepts (final weight > threshold), the total registered voting weight
> exceeds the threshold — no voter double-counted — on the validated EVM.**

All hole-free (`[propext, Classical.choice, Quot.sound]`).

**The assumption boundary.** The behaviour of the external call is an assumption, by design (cryptography is
out of scope, MC-2). `ecrecover` (the `0x01` staticcall) is *not* modeled; its effect and the strict-index
discipline are the *stated hypotheses* of `relay_loop_sound`:

- `hcov` — the memory holds the selected weight at each slot (BR-1 data layer; discharged per-slot by `weight_read`);
- `hcorr` — `mrd rdv k = w[idxs[k]]`: the masked read is the registered weight of the voter that signature `k`
  selects — *this is where* ecrecover→recovered-signer→voter and the calldata decode enter (MC-2 / OP-1);
- `hvalid` — `ValidRun`: strictly-increasing in-range indices (the deployed guards passed = no double-count);
- `hnoovf` — no overflow (BR-2).

Everything *else* — the loop mechanism, the `mload`, the mask, the accumulation, the accept gate, and the
accounting soundness — is *proven* against the validated semantics.

---

## 7.4 The honest residual (what is proven vs. assumed)

This is the most important part of the rung for an auditor; the full ledger is [L10](10-claims-ledger-trust-and-residual.md).

- **The data layer (BR-1) is now proven, not assumed** (§7.3). With the memory-reading loop in place, the
  per-step quantity is a genuine `mload(...) & 0xffff` against the validated `MachineState`, not the loop
  index. The residual at this rung is the **external-call boundary**: `ecrecover` is uninterpreted (MC-2 /
  OP-1) and the per-iteration *selection + validity* is supplied as the stated hypotheses `hcorr` / `hvalid`
  of `relay_loop_sound`. A fully literal EVM model of the `staticcall` / `calldatacopy` / per-guard-revert /
  early-return plumbing would *derive* those hypotheses from a raw-calldata precondition — engineering, not
  new facts — but `ecrecover` itself stays an assumption by design, and the accounting conclusion is unchanged.
- **Modular vs. integer arithmetic (BR-2) — internalized.** The bytecode refinement reasons in
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

## 7.5 Status and reproduce

- **Hole-free**, axioms `[propext, Classical.choice, Quot.sound]` (the data-layer / memory-reading files add
  the two documented upstream-dischargeable axioms `zeroes_data`, `toByteArray_size`), re-verified from the
  git-committed copies from scratch (`lake env lean`, exit 0).

```bash
# Build the validated semantics (one-time), pinned to the checked commit. See L11 for full detail.
cd /tmp && git clone https://github.com/NethermindEth/EVMYulLean evmyul2
cd evmyul2 && git checkout 047f63070309f436b66c61e276ab3b6d1169265a   # 2025-09-24 (not HEAD)
lake exe cache get && lake build
B=<repo>/test-forge/fv/lean/bytecode-refinement
cp $B/RelayBytecodeRefinement.lean $B/DataLayer.lean $B/RelayLoopMemRead.lean .
lake env lean RelayBytecodeRefinement.lean   # loop mechanism (memory-free), ∀N
lake env lean DataLayer.lean                 # the data layer (byte/memory/value/mask/weight_read)
lake env lean RelayLoopMemRead.lean          # memory-reading loop + relay_loop_sound, ∀N
# expect exit 0; the loop-mechanism / accounting theorems print
#   depends on axioms: [propext, Classical.choice, Quot.sound]
# and the data-layer / mstore theorems additionally list zeroes_data (and toByteArray_size).
```

---

## 7.6 Where this leaves the stack

With the bytecode refinement and the memory-reading loop in place, the chain is complete end-to-end at the
loop-accounting level:

```
Halmos: the real bytecode obeys the model's prefix-sum invariant (RelayModelBridgeFV), K≤3      [R2]
Abstract proof:        the abstract algorithm is threshold-sound                              ∀N ∀K            [R4a]
Bytecode refinement:   a validated EVM semantics runs the unbounded loop & soundness transfers ∀N              [R4b]
Memory-reading loop:   the body is the real mload(slot)&0xffff; accept ⟹ Σ masked reads > thr  ∀N              [R4b′]
Full relation R:       deployed loop accepts ⟹ total registered weight > thr (relay_loop_sound) ∀N             [R4b′]
─────────────────────────────────────────────────────────────────────────────────────────────
proven on the validated EVM (modulo 2 upstream-dischargeable axioms): data layer (BR-1)
remaining assumptions: crypto (MC-2), ecrecover→signer + calldata selection/validity (OP-1, hcorr/hvalid),
                       overflow bound (BR-2, discharged under hnoovf)
```

Everything from loop control flow through the real memory read, the mask, accumulation, and threshold
soundness is machine-checked against the validated semantics; the residual is the external-call (ecrecover)
boundary, named and bounded.

**Next:** the deep dives — [L8 — the mathematics](08-the-mathematics.md) and
[L9 — the formal detail](09-the-formal-detail.md); or the audit core,
[L10 — claims ledger, trust & residual](10-claims-ledger-trust-and-residual.md).
