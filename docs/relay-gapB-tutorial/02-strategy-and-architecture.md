# L2 — Strategy & architecture

> **What you get from this level.** The reasoning behind the two-layer plan: a precise version of the
> *fidelity ladder*, the evidence that the automated tools genuinely stall on this contract, what
> *refinement* and *validated semantics* mean, and how Phase A and Gap B fit together. Still mostly
> prose; the objects themselves arrive in L3.

---

## 2.1 The fidelity ladder

In L1 we sketched a ladder from "tested a few inputs" to "proved it about the real machine for all
inputs." Here is the version we actually use to classify every claim in this project. Each rung says
*what is being reasoned about* and *over what range of inputs*.

| Rung | What is reasoned about | Input coverage | Representative tool |
|------|------------------------|----------------|---------------------|
| R0 | The deployed bytecode | a few concrete inputs | Foundry unit tests |
| R1 | The deployed bytecode | random inputs | Foundry fuzzing |
| R2 | The deployed bytecode | **all** inputs up to a fixed bound | **Halmos** (bounded symbolic) |
| R3 | A *model* of the contract | **all** inputs, unbounded (by induction) | **Kontrol/KEVM**, **Certora** |
| R4 | A **validated model of the EVM** running the contract's loop | **all** inputs, unbounded | **Lean + EVMYulLean** (this work) |
| R5 | The literal deployed bytes, end to end, incl. cryptography & memory | all inputs | *not attained by anyone here; the honest aspiration* |

Two independent axes are moving as you climb:

- **Input coverage** (a few → random → bounded-all → unbounded-all). Crossing from R2 to R3 is the
  *induction barrier*: it requires an argument no solver can find unaided.
- **Fidelity of the object** (a tidy model → the real machine). Crossing from R3 to R4 is the
  *assembly barrier*: a model reconstructed from high-level structure can silently diverge from
  hand-written assembly; reasoning against a validated EVM semantics does not.

The project's destination is **R4**, reached for the loop mechanism. R5 — proving the literal bytes
including cryptography and the exact memory layout — is named honestly as out of reach (and largely
out of reach for *anyone* today on a contract like this); the gap between R4 and R5 is exactly the
residual fenced off in L5.

---

## 2.2 The evidence: automated tools really do hit the wall

This is not a hypothetical. We ran the rung-3 tools and watched them fail in the way the assembly
barrier predicts. Recording this is important: it is *why* we climbed to R4, and it is a genuine finding
about the contract, not a tooling accident.

- **Kontrol/KEVM (unbounded, on a Solidity model).** Kontrol proves properties by k-induction over a
  K-framework model of the EVM. On the signature loop at **N = 10** it ran for **~12 hours and produced
  0 completed proofs**. The cause is structural: Relay's hand-rolled assembly storage does not present
  to KEVM as the structured storage it needs to drive the induction, so the proof obligations do not
  close.

- **Certora (unbounded, parametric storage invariants).** Certora reasons about named storage slots.
  Relay's assembly writes storage at hand-computed slots, so Certora's storage abstraction *havocs*
  (treats as arbitrary) the very state the invariant is about. The runs produced **spurious
  "violations"** — e.g. `setSigningPolicy` reported as violating an immutability invariant despite making
  no external call — and the standard mitigations (`HAVOC_ECF`) did not help. The "violations" are
  artifacts of the storage abstraction breaking on inline assembly, not real bugs.

That *two different rung-3 tools, with different internals, fail on the same obstacle* is the tell. It
is the assembly barrier (R3→R4) showing up twice. The lesson, generalized in L6: **when independent
unbounded tools converge on the same stall against hand-written assembly, that is the signal to switch
to theorem-proving against a validated low-level semantics.**

> ⚠ **Caveat (discharged in L5):** "the tools failed" means *they could not establish the property*, not
> *the property is false*. Their failure is about the model–reality mismatch, and it is exactly the
> mismatch R4 is designed to step over.

---

## 2.3 The key idea: refinement (prove once, lift once)

Trying to prove the full property *directly* on the real-machine semantics — cryptography, memory
layout, gap-skipping, and unbounded induction all at once — is intractable and conflates the two
enemies. The standard discipline that separates them is **refinement**.

Refinement, in one sentence: *prove your property about a clean abstract model, then prove the concrete
system faithfully implements that abstract model, and conclude the property holds of the concrete
system.* The two proofs are independent and each is tractable on its own.

```
   abstract model  ⊨  PROPERTY            (Phase A: the math, R3-style but in a full theorem prover)
   concrete system  ⊑  abstract model     (Gap B: refinement against validated EVM semantics, R4)
   ─────────────────────────────────────
   concrete system  ⊨  PROPERTY           (by composition)
```

Here:

- The **abstract model** is the accounting algorithm as a recursive function over lists of weights and
  signature indices (Phase A). The property is *threshold soundness*.
- The **concrete system** is a loop executed step-by-step by the validated EVM/Yul interpreter (Gap B).
- "**⊑** faithfully implements" (refinement) is proven by *simulation*: each iteration of the concrete
  loop reproduces one step of the abstract function, so after the loop the concrete state encodes the
  abstract result.

The payoff: Enemy 1 (unboundedness) is fought once, in the clean setting where induction is easy
(Phase A). Enemy 2 (the real machine) is fought once, in the setting where we don't have to also worry
about the high-level property (Gap B). Neither proof has to do both jobs.

> ⚠ **Caveat (discharged in L3/L5).** In this project the refinement is established for the **loop
> mechanism** (a counting accumulation loop), not for a verbatim transcription of the entire signature
> routine. The abstract model in Phase A is *more general* than the concrete loop in Gap B (it ranges
> over arbitrary signature streams with a no-double-count discipline). The two layers meet at "an
> unbounded accumulating loop runs faithfully and threshold-soundness transfers"; the precise seam, and
> what crosses it vs. what is assumed, is L5's job.

---

## 2.4 What "validated semantics" means, and the trust chain

Reaching R4 requires a mathematical description of how the EVM executes — an **operational semantics** —
that we can compute and reason about *inside Lean*. We use **EVMYulLean** (NethermindEth): a Lean 4
formalization of EVM and Yul execution.

Why "validated" is the load-bearing word: a semantics you wrote yourself is only as trustworthy as your
own understanding of the EVM. EVMYulLean is **executed against the official Ethereum execution-spec test
suites** — the same conformance tests real EVM clients must pass. So when our proof says "the EVM model
computes X", the claim that *this model is the EVM* is backed by the standard cross-client test corpus,
not by our say-so.

The resulting trust chain for an R4 claim is:

```
  our Lean proof  is correct        ← checked by the Lean kernel (small, well-scrutinized)
    on top of EVMYulLean            ← validated against Ethereum's official test suites
      on top of Lean's axioms       ← propext, Classical.choice, Quot.sound (standard, consistent)
```

Every link is either machine-checked or independently validated. The things *outside* this chain — the
data layer and overflow bound — are the residual (L5). This is what "shrinking the trusted surface to a
small, independently-checkable claim" means concretely.

> ⚠ **Caveat (discharged in L4):** EVMYulLean models memory with a foreign-function (FFI) byte-array
> backend. This has a practical consequence — we cannot *concretely evaluate* memory-touching programs
> inside a plain proof file — which shaped the encoding choice in Gap B (a **memory-free** loop). L4
> explains the consequence; L5 explains why it is sound to make this choice and what it costs.

---

## 2.5 The architecture, restated precisely

Putting the pieces together, the development has exactly two theorems that matter, each on its own rung,
plus a named residual.

1. **Phase A — `RelaySigLoop.threshold_sound`** (rung R3-grade rigor, but in a full theorem prover so it
   is unbounded and hole-free). *For all weight lists `w`, all valid signature streams `idxs`, and all
   thresholds: if the abstract loop accepts, the total registered weight exceeds the threshold.* This is
   the math of the property, with no double-counting, for all N and all K. Detailed in L3 §A, L4 §A.

2. **Gap B — `bytecode_threshold_sound`** (rung R4). *For all N, if the counting accumulation loop —
   executed by the validated EVMYulLean interpreter — accepts (its final accumulator exceeds the
   threshold), then the total accumulation exceeds the threshold.* Built on `bytecode_loop_correct`
   (the refinement: the validated interpreter runs N iterations and accumulates exactly the abstract
   accumulator, for all N) and `loop_acc` (the induction engine). Detailed in L3 §C, L4 §C.

3. **The residual** (the R4→R5 gap, *assumed*, validated separately): the **data layer** (each
   iteration's addend is the intended registered weight) and the **overflow bound** (weights are small
   enough — established elsewhere as `totalWeight < 2^16` — that the 256-bit accumulator equals the true
   integer sum). Detailed in L5.

Both theorems are checked to depend on **only** Lean's three standard axioms — no `sorry`, no
`native_decide`, no extra `axiom`. The axiom audit and why it matters is L4 §F.

**Next:** [L3 — The mathematics](03-the-mathematics.md), where the abstract model, the operational
semantics, and the refinement become actual definitions and theorem statements.
