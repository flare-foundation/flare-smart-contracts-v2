# L5 — Limits, trust & residual

> **What you get from this level.** The exact boundary of the result: a ledger of what is *proven* vs
> *assumed*, each item placed on the fidelity ladder, with the assumptions justified or flagged as open.
> This is the level a skeptic should read first and challenge hardest. It discharges every "⚠ caveat"
> raised in L1–L4. **If you cite this work, cite it from here.**

The governing rule (restated): *"proven"* = a Lean theorem whose statement is the claim and whose
`#print axioms` is exactly `[propext, Classical.choice, Quot.sound]`. *"Assumed"* = a hypothesis not
discharged in Lean, justified by other evidence named below.

---

## 5.1 The ledger

| # | Statement | Status | Rung | Where |
|---|-----------|--------|------|-------|
| P1 | Abstract accounting is threshold-sound, ∀N ∀K, no double-count | **Proven** | R3-grade, hole-free | `threshold_sound` |
| P2 | Validated EVM/Yul interpreter runs the counting loop to completion and `w = absAcc(0,N,0)`, ∀N | **Proven** | R4 | `bytecode_loop_correct` |
| P3 | On that interpreter, accept (`thr < w`) ⟹ `thr < absAcc(0,N,0)`, ∀N | **Proven** | R4 | `bytecode_threshold_sound` |
| A1 | The per-iteration addend is the registered weight `w[i]` (not the index) | **Assumed** (data layer) | R4→R5 gap | §5.3 |
| A2 | Weights are small enough that the 256-bit accumulator does not wrap | **Assumed** (overflow bound) | side condition | §5.4 |
| A3 | Our `For(cond,post,body)` faithfully encodes the deployed loop's control structure | **Assumed** (encoding fidelity) | R4→R5 gap | §5.5 |
| A4 | A valid signature identifies its signer (`ecrecover`/keccak correctness) | **Assumed** (cryptography) | out of scope by design | §5.6 |
| A5 | EVMYulLean *is* the EVM | **Validated** (external test suites), not proven here | basis of R4 | §5.7 |

P1–P3 are machine-checked. A1–A5 are the trusted surface. The engineering value of the work is that this
surface is **small, named, and individually checkable** — instead of "trust the 930-line assembly
routine."

---

## 5.2 What is genuinely proven — stated without softening

- **P1 (Phase A).** For every list of voter weights `w` (so every voter count `N = |w|`), every signature
  stream `idxs` (so every length `K`) satisfying the strictly-increasing-in-range discipline `ValidRun`,
  and every threshold `thr`: if the abstract loop's final tally exceeds `thr`, then `sumTake(w, N)` (the
  total registered weight) exceeds `thr`. No voter is counted twice (this is forced by `ValidRun`, not
  assumed about the input). This is the complete, unbounded *mathematics* of the property.

- **P2 (Gap B refinement).** For every `N < 2²⁵⁶`, NethermindEth's validated Lean EVM/Yul interpreter,
  given the exact fuel `3N+10` and a start state with `i = 0, w = 0`, **terminates in `.ok`** (no
  `OutOfFuel`, no exception) with final `w` equal to `absAcc(0, N, 0) = Σ_{a<N} ofNat a` in `𝕌`. The
  machine state is untouched. This is a *refinement*: the real-machine execution matches the abstract
  accumulator, for all N.

- **P3 (Gap B transfer).** On that same validated execution, for all `N`, *accept ⟹ enough accumulated
  total* (in `𝕌`). This is P1's logical shape, transported to the real-machine model.

All three carry the clean axiom list (L4 §F). None uses `native_decide`, `sorry`, or any extra axiom.

---

## 5.3 The data layer (A1) — the central residual

**The claim we did not prove.** The deployed loop body executes (morally) `w := w + mload(weights[i])` —
add the weight stored in memory at the slot for voter `i`. Our verified body executes `w := w + i` — add
the index. We replaced the memory load by the index.

**Why this is the honest crux.** Two things had to be separated to make either tractable:

1. *That the loop iterates N times and folds a per-step quantity into `w`, faithfully, on the real
   machine* — this is what the assembly barrier (Enemy 2) threatens, and it is exactly what P2 proves.
2. *That the per-step quantity is the right number* — this is a statement about the contract's **memory
   layout**: that `mload` at the computed slot returns the registered weight.

Substituting `i` for `mload(weights[i])` keeps (1) intact — same iteration count, same fold shape, same
control flow — while removing (2) from the Lean obligation. (2) is then the assumption A1.

**Why substituting is sound as a *mechanism* proof.** `absAcc` is parametric in the addend only through
the value added each step; the proof of P2 never uses any property of "the addend is `i`" beyond its
being the value present. The identical induction goes through with `mload(...)` in place of `i` *provided
the memory read reduces to a value* — which, in EVMYulLean, routes through the FFI byte-array memory
model (Caveat C1) and so cannot be *concretely evaluated* in a plain proof file. A1 is precisely the
statement that this read yields `w[i]`.

**How A1 is justified (not proven).** By differential validation of the memory layout: the loop's
slot arithmetic and the `mload` offsets are checked against the contract's documented calldata/storage
layout and against the reference encoder (`scripts/libs/protocol/RelayMessage.ts`). This is rung-R0/R1
evidence (concrete + reference oracle), not a proof. **This is the single most valuable target for future
work**: discharging A1 inside Lean — by either (a) a runtime EVMYulLean test executable that links the
FFI and checks `mload` concretely on representative layouts, or (b) an axiomatization of the relevant
memory fragment and a symbolic proof that the slot arithmetic hits it — would move A1 from *assumed* to
*proven* and collapse most of the R4→R5 gap.

> **For a challenger:** the sharp question to press is *"is the substitution `i ↦ mload(weights[i])`
> conservative for the property, or does it hide a layout bug?"* The answer is: P2 is agnostic to the
> addend's *value*, so it proves the *folding*; the *value* is A1. A layout bug would be a false A1, not a
> false P2. That is the right place to apply pressure, and §5.8 lists the concrete checks.

---

## 5.4 The overflow bound (A2)

P1 lives in `ℕ` (true integer sums). P3 lives in `𝕌` (sums mod 2²⁵⁶). To identify `absAcc(0,N,0)` (and
the on-chain tally) with the integer total `sumTake(w,N)`, the running sum must never wrap 2²⁵⁶.

For Relay this holds with enormous margin: the engagement established `totalWeight < 2¹⁶` (voter weights
are bounded; the Kontrol/Foundry harnesses use `SUM_MAX < 2³²`, and the real bound is tighter still — see
the vacuity review in the engagement checkpoint). With the total below 2¹⁶ ≪ 2²⁵⁶, no addition in the
loop can overflow, so `𝕌`-addition agrees with `ℕ`-addition throughout and the `𝕌`-order comparison in
P3 coincides with the integer comparison in P1.

A2 is therefore a *quantitative side condition that is comfortably true*, but it is stated explicitly
because the modular/integer identification is not free. (It could itself be folded into Lean by carrying
a `Σ < 2²⁵⁶` hypothesis through the induction and proving `ofNat`-additivity under it; we left it as a
named side condition because the margin is so large that the integer reading is unambiguous.)

---

## 5.5 Encoding fidelity (A3)

P2/P3 prove things about *our* `For(cond, post, body)`. A3 is the claim that this AST faithfully mirrors
the **control structure** of the loop the Solidity/Yul compiler actually emits for the signature scan:
a guarded loop with a monotone counter and a single accumulation into the tally.

What supports A3: the encoding follows the optimized Yul shape (note the no-init `For`, matching the
optimizer's `ForLoopInitRewriter`), and the optimized IR is available alongside the proof
(`test-forge/fv/lean/relay_ir_optimized.yul`) for comparison. What A3 does *not* claim: that our three
AST nodes are a byte-for-byte transcription of the entire signature routine (which also contains the
`ecrecover` call, the strict-increase index check, and the memory loads). The *index discipline* that
prevents double-counting is verified abstractly in P1 (`ValidRun`), not re-encoded in the Gap-B loop;
the *cryptography* is A4. A3 is specifically about the loop's *iteration-and-accumulate skeleton*
matching, which is the part P2 is about.

Tightening A3 would mean parsing the actual emitted Yul for the loop and proving the parsed AST equals
(or refines) our `For` node — mechanical but worthwhile; listed in §5.8.

---

## 5.6 Cryptography (A4) — out of scope by design

The entire engagement verifies *accounting*, not *cryptography*. A "signature" in Phase A is just the
index it carries; we assume a valid signature reliably identifies its signer (the standard `ecrecover`
+ keccak soundness assumption). This is a deliberate, conventional scoping choice — verifying ECDSA
recovery is a separate discipline — and is flagged wherever signatures appear. It is not a gap we claim
to have closed.

---

## 5.7 The semantics itself (A5) — validated, not proven here

P2/P3 are only as meaningful as the claim *EVMYulLean = the EVM*. We do not prove that (it is not a
provable statement — it relates a formal artifact to a real network). It is **validated**: EVMYulLean is
run against the official Ethereum execution-spec test suites, the same conformance corpus EVM clients
use. This is strong, standard evidence, and it is the foundation our R4 results stand on. A residual risk
remains exactly to the extent the test suites are incomplete or EVMYulLean diverges on untested behavior
— the same residual every semantics-based verification carries, and far smaller than trusting a bespoke
model. The Lean kernel checking our proofs is itself small and heavily scrutinized.

---

## 5.8 What a skeptic should still check (the open checklist)

Ordered by leverage. Each item, if done, moves a row of the ledger from *assumed* toward *proven*.

1. **Discharge A1 in Lean (highest value).** Either a runtime EVMYulLean test exe that links the FFI and
   confirms `mload(weights[i]) = w[i]` on representative layouts, or a symbolic memory-fragment
   axiomatization + a proof that the loop's slot arithmetic addresses it. Collapses most of R4→R5.
2. **Tighten A3.** Parse the emitted optimized Yul for the signature loop and prove the parsed loop AST
   refines our `For(cond,post,body)`. Removes the "is this the real loop's skeleton?" doubt.
3. **Internalize A2.** Carry a `Σ < 2²⁵⁶` hypothesis through `loop_acc` and prove `ofNat`-additivity
   under it, so the `𝕌`→`ℕ` identification is itself a theorem rather than a side remark.
4. **Glue P1 and P3 explicitly.** Add a Lean lemma transporting `bytecode_threshold_sound` (modular,
   index-addend) to `threshold_sound` (integer, weight-addend) *under A1+A2*, making the composition a
   single checked statement with its assumptions as visible hypotheses.
5. **Re-run the rung-3 tools as regression.** Periodically re-confirm the Kontrol/Certora stalls are
   unchanged, so the justification for climbing to R4 stays current.

None of these is required for the result *as stated* (P1–P3 are complete on their own terms); they are
the path from "small named trusted surface" toward "nothing trusted but the kernel and the EVM test
suites."

---

## 5.9 What is *not* claimed (to forestall over-reading)

- **Not claimed:** "the deployed `Relay.sol` bytecode is fully formally verified." It is not. P1–P3 +
  A1–A5 is the real statement.
- **Not claimed:** the Gap-B loop is a verbatim copy of the signature routine. It is the
  iteration-and-accumulate skeleton (A3), with the addend abstracted (A1) and the crypto out of scope
  (A4).
- **Not claimed:** the cryptography is verified. It is assumed (A4).
- **Not claimed:** correctness in `𝕌` *equals* correctness in `ℕ` for free. It requires A2 (true with
  vast margin, but stated).
- **What *is* claimed, fully:** the unbounded accounting is mathematically sound (P1); a validated model
  of the real machine genuinely runs the unbounded loop and the soundness step survives onto it (P2/P3);
  and the gap between this and the literal deployment is exactly A1–A5, each small and individually
  attackable.

**Next:** [L6 — Reproduce & lessons](06-reproduce-and-lessons.md): exact commands to re-check everything,
then the transferable method.
