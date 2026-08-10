# L2 — Strategy & the fidelity ladder

> **What you get from this level.** Why the engagement is shaped the way it is: the research-first
> decision process, the **fidelity ladder** that classifies every claim, the mapping of each tool to a
> rung, the *refinement* idea that powers the top rung, and an **executive results table** summarizing
> what every rung delivered. This is the bridge from the analogies of L1 to the per-rung detail of
> L3–L9, and (with L10/L11) the auditor's overview.

---

## 2.1 The strategy: research first, then a layered stack

The engagement was run **research-first**: before writing proofs, survey the verification landscape and
the contract, then choose a strategy deliberately. The survey covered the Act framework (Act spec →
Coq/Rocq with hevm proving bytecode-refines-spec), the broader EVM-FV landscape (Halmos, Kontrol/KEVM,
Certora, Echidna/Medusa), and the existing audit reports for the live issue inventory.

**The pivotal finding that shaped tool choice.** Relay's core property is about *signature recovery*, and
the verification must treat `ecrecover` as an uninterpreted function (modeling contract MC-2). The survey
found that **hevm — Act's automatic backend — does not model `ecrecover` (precompile `0x01`) symbolically**
(it forces the input concrete; only SHA-256 is available uninterpreted). So a pure Act/hevm bytecode proof
of the signature path is *blocked today*. The tools that **do** model `ecrecover` as uninterpreted are
**Halmos, Kontrol/KEVM, and Certora** — which is precisely why the stack is built from those three, with
Act/Rocq noted as a north-star spec layer to revisit once hevm gains `ecrecover` support.

The four researched paths, presented as a decision menu, were: **(A) Halmos** (Foundry-native symbolic,
uninterpreted `ecrecover`, fast bounded proofs — recommended first); **(B) Kontrol/KEVM** (deductive,
unbounded-K via k-induction); **(C) Act + Rocq** (human-readable spec → machine-checked proof, north-star,
gated on hevm); **(D) Certora** (industrial, ghost `ecrecover`, risk: inline-assembly storage analysis).
The chosen strategy was the **hybrid staged stack**: Halmos first, escalate to Kontrol, add Lean for the
unbounded algorithm, and keep Act as the aspirational spec layer.

Two facts from that survey drove everything:

1. **The property is unbounded.** Soundness must hold for all validator counts N and signature counts K —
   so testing and bounded tools alone can never be the whole answer; an inductive argument is required.
2. **The contract is ~90% hand-written inline assembly.** So any tool that reconstructs a model from
   high-level Solidity structure is at risk on the storage layout, and the result of highest fidelity must
   reason at the bytecode / EVM-semantics level.

The conclusion was not "pick one tool" but **a layered stack**: use each tool exactly where its strengths
land on the fidelity ladder, and make the layers cover each other's gaps. The rest of this document makes
that precise.

---

## 2.2 The fidelity ladder

Every claim in the engagement is classified by **two axes at once** (the [fidelity ladder](CONCEPTS.md#11-the-fidelity-ladder-r0-r5), in one page): *what object* it reasons about, and
*over what input range*.

| Rung | Object reasoned about | Input coverage | Tool |
|------|-----------------------|----------------|------|
| **R0** | the deployed bytecode | a few concrete inputs | Foundry unit tests |
| **R1** | the deployed bytecode | random inputs | Foundry fuzzing |
| **R2** | the deployed bytecode | **all** inputs up to a fixed bound | **Halmos** (bounded symbolic) |
| **R3** | a *model* of the contract | **all** inputs, unbounded (induction) | **Kontrol/KEVM**, **Certora** |
| **R4** | a **validated model of the EVM** running a hand-transliterated loop model | **all** model sizes, conditional | **Lean + EVMYulLean** |
| **R5** | separate `relay()` breadth models: mode dispatch, storage/accept-write, conditional composition, fees | **all** modeled inputs | **Lean + EVMYulLean** |
| *(ceiling)* | the literal deployed bytes, end-to-end **incl. cryptography & exact memory** | all inputs | *permanently out of reach — crypto is MC-2; the residual fenced in [L10]* |

Two barriers separate the rungs:

- **The [induction barrier](CONCEPTS.md#10-bounded-vs-unbounded-proofs) (R2 → R3).** Crossing from "all inputs up to a bound" to "all inputs" requires
  an inductive argument no solver finds unaided. This is Enemy 1.
- **The assembly barrier (R3 → R4).** A model reconstructed from high-level structure can silently diverge
  from hand-written assembly; reasoning against a *validated EVM semantics* does not. This is Enemy 2.

The destination is **R4**, reached for the loop mechanism; **R5 then extends the same literal, validated-EVM
method to the rest of `relay()`** — mode dispatch, storage/accept-write, the end-to-end composition
(dispatch → loop → accept), and fee conservation, all hole-free (§2.6; [L7 §7.5](07-R4b-bytecode-refinement.md),
[L9 §F.5](09-the-formal-detail.md)). R5 adds **breadth**, not a new soundness fact — the accounting soundness
is already the loop's (R4). What remains permanently out of reach is *byte-perfect end-to-end verification
including the cryptography (MC-2, irreducible) and the exact memory layout* — the ceiling, fenced as the
residual in [L10](10-claims-ledger-trust-and-residual.md).

---

## 2.3 Mapping the tools to the rungs (and why)

- **Foundry (R0/R1)** runs the *actual* compiled contract on concrete and random inputs. Cheap, highest
  fidelity of object, weakest coverage. The base. → [L3](03-R0R1-foundation-tests.md)

- **Halmos (R2)** *symbolically executes the real bytecode*. Because it executes rather than abstracts, it
  is **immune to the assembly barrier** — there is no storage model to break. Its limit is the *induction
  barrier*: it unrolls loops to a fixed bound, so coverage is bounded (here K≤3, N≤5). This is why the
  bounded floor of the stack runs on the real bytecode. → [L4](04-R2-bounded-symbolic-halmos.md)

- **Kontrol/KEVM (R3)** proves **∀K** by [k-induction](CONCEPTS.md#5-what-is-k-induction) ([what is KEVM?](CONCEPTS.md#4-what-is-kevm)) — crossing the induction barrier — but on a faithful
  Solidity *model*, at fixed voter counts N∈{3,5}. **Certora (R3)** targets all-functions/all-sequences
  *storage* invariants. Both meet the *assembly barrier*: Kontrol at full symbolic-N (state-explosive,
  12h/0 proofs), Certora on storage-slot havoc. The successes (Kontrol's ∀K) and the walls are both
  documented honestly. → [L5](05-R3-unbounded-attempts.md)

- **Lean — the abstract proof (R4a)** proves the signature-loop soundness **∀N ∀K** as an abstract
  algorithm — fully past the induction barrier, in a setting where induction is clean and no EVM model is
  needed. → [L6](06-R4a-abstract-proof.md)

- **Lean + EVMYulLean — the bytecode refinement (R4b)** lifts the abstract proof's result onto a loop run
  by a *validated EVM semantics*, for all N — crossing the assembly barrier for the loop mechanism. →
  [L7](07-R4b-bytecode-refinement.md)

---

## 2.4 The key idea for R4: refinement (prove once, lift once)

Proving the full property *directly* on real-machine semantics — cryptography, memory, gap-skipping, and
unbounded induction at once — is intractable and conflates the two enemies. The discipline that separates
them is **[refinement](CONCEPTS.md#16-refinement-and-the-simulation-relation)**:

```
   abstract model  ⊨  PROPERTY            (the abstract proof: the math; induction is easy here)
   concrete system  ⊑  abstract model     (the bytecode refinement: refinement vs validated EVM semantics)
   ─────────────────────────────────────
   concrete system  ⊨  PROPERTY           (by composition)
```

Enemy 1 (unboundedness) is fought once, in the clean abstract setting (the abstract proof). Enemy 2 (the real
machine) is fought once, with no high-level property to also juggle (the bytecode refinement). Each half stays small because
it has one job. The refinement itself is by *simulation*: each concrete loop iteration reproduces one step
of the abstract function.

> ⚠ **Caveat (discharged in L7/L10):** in this engagement the refinement is established for the **loop
> mechanism** — now with the deployed contract's *actual* 17-statement signature-verification body transliterated
> statement-for-statement and executed on the validated EVM (the literal model,
> [`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean)) — but still not a verbatim
> end-to-end transcription down to the cryptography (`ecrecover` stays uninterpreted, MC-2). The abstract proof is
> *more general* than the concrete loop (it ranges over arbitrary signature streams with a no-double-count
> discipline). The two meet at "an unbounded accumulating loop runs faithfully and threshold-soundness transfers."

---

## 2.5 What "validated semantics" means, and the trust chain

R4 needs a computable, reason-about-able description of EVM execution *inside Lean* (a [validated semantics](CONCEPTS.md#18-validated-semantics-a-evm)). The engagement uses
**EVMYulLean** (NethermindEth) — a Lean 4 formalization of EVM/Yul execution whose **EVM interpreter is
executed against the standard `ethereum/tests` EVM conformance suite** (GeneralStateTests, now including EEST-generated fixtures), the same conformance corpus real EVM
clients pass. So when a bytecode-refinement proof says "the EVM model computes X", the claim *this model is
the EVM* is backed by the cross-client test corpus, not by our say-so.

**One precision, so the inheritance is not overclaimed.** EVMYulLean contains two interpreters that share
their opcode layer: the **EVM interpreter** (the one exercised by the execution-spec conformance corpus) and
the **Yul interpreter** (`Yul.exec`/`loop`/`eval`), which is what the R4b proofs actually drive. The two
share the per-opcode `step` dispatch and the `MachineState` memory operations — so the *opcode-level*
semantics our proofs use (`ADD`/`LT`/`AND`/`MUL`/`MLOAD`/`MSTORE`, the memory model) sit on the
conformance-tested path — but the Yul **control-flow** layer (`For`/`Block`/variable scoping, the fuel
discipline) is Yul-specific and validated separately (Yul semantic tests), not by the execution-spec corpus.
Assumption **A-EVM** in [L10](10-claims-ledger-trust-and-residual.md) therefore has two parts of different
strength: opcode/memory semantics (inherits the conformance corpus) and Yul control flow (weaker, separate
validation).

The resulting trust chain for an R4 claim:

```
  our Lean proof is correct        ← checked by the Lean kernel (small, well-scrutinized)
    on top of EVMYulLean           ← opcode/memory layer: validated vs Ethereum's official test suites
                                     Yul control-flow layer: Yul semantic tests (the weaker half of A-EVM)
      on top of Lean's axioms      ← propext, Classical.choice, Quot.sound (standard, consistent)
```

Every link is machine-checked or independently validated. The data layer (BR-1) and the overflow bound (BR-2)
have since been brought *inside* the chain (the memory-reading loop and `relay_loop_sound`, L7 §7.3; BR-2 via
`bytecode_threshold_sound_mem_int` under an explicit no-overflow hypothesis), and the **literal loop-body model**
([`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean)) goes further still — it runs
the deployed 17-statement body on the validated EVM, so the memory-read facts (`hcov`/`hcorr`) are *derived* rather
than assumed and the index guards follow from the accounting discipline (`relay_loop_sound_literal_derived_tight`).
What now lies *outside* is only the cryptography (`ecrecover`, MC-2) and the per-iteration selection/validity it
determines — the residual, stated per-iteration as `IterPremiseT` (L10).

---

## 2.6 Executive results table (all rungs)

The whole stack at a glance. "Object" and "Coverage" are the two ladder axes. Detail and exact artifact
names are in the per-rung docs and the claims ledger ([L10](10-claims-ledger-trust-and-residual.md)).

| Rung | Tool | What it covers | Object | Coverage | Status |
|------|------|----------------|--------|----------|--------|
| R0/R1 | Foundry | full test tree (the retired 36-test GSS gate went with that design; owner-timelock suites replace it) | real bytecode | concrete + fuzz | ✅ full Forge tree green |
| R2 | Halmos | relay-core accounting/matrix/lifecycle/Merkle/randomness/fees (the bounded GSS harness was retired with that design) | **real bytecode** | bounded; relay K≤3/N≤5 | ⏳ red pending the owner-timelock re-baseline (manifest still pins the retired inventory) |
| R3 | Kontrol | sig-loop weight invariant; random monotonicity — **∀K** (k-induction) | Solidity **model** | ∀K, N∈{3,5} | ✅ proven (Docker-pinned); full symbolic-N intractable (documented) |
| R3 | Certora | 8 current all-functions storage invariants, including GSS high-water, generation, and consumed-nonce properties | model | ∀ functions & sequences | 2/2 current configs compile/typecheck locally; pre-GSS cloud history only, current cloud proof pending ([L5 §5.2](05-R3-unbounded-attempts.md)) |
| R4a | Lean (the abstract proof) | sig-loop **threshold soundness under `ValidRun`** | abstract algorithm | **∀N ∀K** | ✅ hole-free |
| R4b | Lean + EVMYulLean | threshold soundness for the literal hand-transliterated loop model; memory reads and index guards derived, execution/acceptance hypotheses explicit | validated EVM model | **∀N**, conditional | ✅ hole-free; artifact + optimized-Yul provenance gated |
| R5 | Lean + EVMYulLean (`relay()` breadth) | conditional dispatch→loop→accept composition; independent storage round-trip/accept-write and fee-conservation components | validated EVM model | **∀N** (breadth) | ✅ hole-free; not byte-complete; setup, `.CALL` wiring, and D3 reconciliation remain explicit boundaries |

The residual entries are the honest results, not omissions: Kontrol's symbolic-N intractability and the
`relay()` residual of the (since largely discharged) Certora storage wall are the **convergent
assembly-barrier finding** of §2.7.

---

## 2.7 The convergent finding (why the stack is sound despite the walls)

Two independent state-of-the-art unbounded provers — Kontrol at full symbolic-N and Certora at
all-functions storage invariants — are blocked by the **same** obstacle: Relay's hand-rolled inline-assembly
storage (bit-packed `StateData` written via `sstore` to scratch-memory-computed slots) defeats their
storage models. That two different tools fail the same way is the *tell*: it is the assembly barrier
(R3→R4) appearing twice, a real property of the contract, not a tooling mishap.

*(2026-07 baseline update: the Certora half of the wall was subsequently **narrowed** — disabling the failing
storage-splitting analysis (`-enableStorageSplitting false`, with the prover's injective hashing model
deciding aliasing) discharged the pre-GSS invariants for every function except
`relay()` itself, which the model covered only vacuously. The updated GSS rule
set still requires a cloud rerun. See [L5 §5.2](05-R3-unbounded-attempts.md)
and [`certora/README.md`](../../certora/README.md).)*

The stack is sound *because* of how the rungs are chosen around this:

- **Halmos** needs no storage model — it executes the real bytecode — so the security-critical surface is
  machine-checked at bounded size on the actual deployed code.
- **Lean (the abstract proof)** gives the unbounded guarantee at the algorithm level, needing no EVM model.
- **The bytecode refinement** reconnects the unbounded guarantee to a *validated* EVM semantics, stepping over the assembly
  barrier for the loop mechanism.
- The **per-sequence** forms of the core storage invariants are proven on the
  real bytecode (for example,
  [`RelayEpochAdvanceFV`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L19)
  for the epoch pointer). GSS signer and action transitions now have dedicated
  bounded Halmos proofs, while Safe digest equivalence and source execution stay
  outside that symbolic boundary.

For the pre-GSS core, the residual after the full stack is not "the security core
is untested" but "`relay()` itself is covered through per-sequence Halmos proofs
and the Lean model rather than the all-functions Certora result." The GSS
surface has bounded state-machine proofs but still lacks current parametric
Certora cloud evidence and any source-execution proof. The generalizable
lesson is in [L12](12-lessons.md):
*when independent unbounded tools converge on the same stall against hand-written assembly, that is the
signal to switch to theorem-proving against a validated low-level semantics.*

**Next:** [L3 — R0/R1 foundation tests](03-R0R1-foundation-tests.md), the base of the stack; or jump to
any rung via the [README map](00-README.md).
