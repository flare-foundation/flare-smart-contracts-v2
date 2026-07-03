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

Every claim in the engagement is classified by **two axes at once**: *what object* it reasons about, and
*over what input range*.

| Rung | Object reasoned about | Input coverage | Tool |
|------|-----------------------|----------------|------|
| **R0** | the deployed bytecode | a few concrete inputs | Foundry unit tests |
| **R1** | the deployed bytecode | random inputs | Foundry fuzzing |
| **R2** | the deployed bytecode | **all** inputs up to a fixed bound | **Halmos** (bounded symbolic) |
| **R3** | a *model* of the contract | **all** inputs, unbounded (induction) | **Kontrol/KEVM**, **Certora** |
| **R4** | a **validated model of the EVM** running the contract's loop | **all** inputs, unbounded | **Lean + EVMYulLean** |
| **R5** | the **whole `relay()` body** on the validated EVM — beyond the signature loop: mode dispatch, storage/accept-write, end-to-end composition, fees | **all** inputs, unbounded | **Lean + EVMYulLean** — *largely attained* |
| *(ceiling)* | the literal deployed bytes, end-to-end **incl. cryptography & exact memory** | all inputs | *permanently out of reach — crypto is MC-2; the residual fenced in [L10]* |

Two barriers separate the rungs:

- **The induction barrier (R2 → R3).** Crossing from "all inputs up to a bound" to "all inputs" requires
  an inductive argument no solver finds unaided. This is Enemy 1.
- **The assembly barrier (R3 → R4).** A model reconstructed from high-level structure can silently diverge
  from hand-written assembly; reasoning against a *validated EVM semantics* does not. This is Enemy 2.

The destination is **R4**, reached for the loop mechanism; **R5 then extends the same literal, validated-EVM
method to the rest of `relay()`** — mode dispatch, storage/accept-write, the end-to-end composition
(dispatch → loop → accept), and fee conservation, all hole-free (§2.6; [L7 §7.5](07-R4b-bytecode-refinement.md),
[L9 §G.5](09-the-formal-detail.md)). R5 adds **breadth**, not a new soundness fact — the accounting soundness
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

- **Kontrol/KEVM (R3)** proves **∀K** by k-induction — crossing the induction barrier — but on a faithful
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
them is **refinement**:

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

R4 needs a computable, reason-about-able description of EVM execution *inside Lean*. The engagement uses
**EVMYulLean** (NethermindEth) — a Lean 4 formalization of EVM/Yul execution whose **EVM interpreter is
executed against the official Ethereum execution-spec test suites**, the same conformance corpus real EVM
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
| R0/R1 | Foundry | functional behavior of all modes (incl. signing-policy rotation); coverage 31→59 tests | real bytecode | concrete + fuzz | ✅ green in CI (`test-unit-forge`, `coverage-forge`) |
| R2 | Halmos | sig/threshold accounting; full `relay()` epoch matrix; access control; lifecycle; Merkle; randomness; fees — 25 harnesses / **85 checks (57 proofs, 28 anti-vacuity controls)** | **real bytecode** | bounded (K≤3, N≤5) | ✅ green in CI (`test-fv-halmos`, gated by [`verify_fv.py`](../../test-forge/fv/verify_fv.py)) |
| R3 | Kontrol | sig-loop weight invariant; random monotonicity — **∀K** (k-induction) | Solidity **model** | ∀K, N∈{3,5} | ✅ proven (Docker-pinned); full symbolic-N intractable (documented) |
| R3 | Certora | 5 all-functions storage invariants (nonce/epoch monotonic, setter-immutable, hash/root write-once) | model | ∀ functions & sequences | ⚠ specified + locally typechecked; **not cloud-dischargeable** (assembly storage-havoc wall) |
| R4a | Lean (the abstract proof) | sig-loop **threshold soundness** | abstract algorithm | **∀N ∀K** | ✅ hole-free (`[propext, Quot.sound]`) |
| R4b | Lean + EVMYulLean (the bytecode refinement) | threshold soundness on **validated EVM semantics** — deployed 17-statement loop body run literally (`relay_loop_sound_literal_derived_tight`; memory reads derived), abstract masked-read `relay_loop_sound` corroborating | validated EVM model | **∀N** | ✅ hole-free (`[propext, Classical.choice, Quot.sound]`) |
| R5 | Lean + EVMYulLean (whole-`relay()`) | **breadth beyond the loop:** end-to-end composition — `protocolId ≠ 1` routes dispatch → signature loop → accept ⟹ registered weight > threshold (`relay_dispatch_loop_accept`); mode dispatch (`dispatch_routes_verify`); storage round-trip + accept-write (`sstore_sload` / `sstore_reads_back`, Relay.sol:1394); fee conservation (`fee_conservation` / `transfer_conservation` / `two_transfer_caller_net_zero`) | validated EVM model | **∀N** (breadth) | ✅ hole-free; residual: exec-level `.CALL` wiring + D3 accept-write reconciliation |

The two ⚠ rows are the honest results, not omissions: Kontrol's symbolic-N intractability and Certora's
storage-havoc wall are the **convergent assembly-barrier finding** of §2.7.

---

## 2.7 The convergent finding (why the stack is sound despite the walls)

Two independent state-of-the-art unbounded provers — Kontrol at full symbolic-N and Certora at
all-functions storage invariants — are blocked by the **same** obstacle: Relay's hand-rolled inline-assembly
storage (bit-packed `StateData` written via `sstore` to scratch-memory-computed slots) defeats their
storage models. That two different tools fail the same way is the *tell*: it is the assembly barrier
(R3→R4) appearing twice, a real property of the contract, not a tooling mishap.

The stack is sound *because* of how the rungs are chosen around this:

- **Halmos** needs no storage model — it executes the real bytecode — so the security-critical surface is
  machine-checked at bounded size on the actual deployed code.
- **Lean (the abstract proof)** gives the unbounded guarantee at the algorithm level, needing no EVM model.
- **The bytecode refinement** reconnects the unbounded guarantee to a *validated* EVM semantics, stepping over the assembly
  barrier for the loop mechanism.
- The **per-sequence** forms of the storage invariants Certora could not globally close *are* proven
  (Halmos [`RelayGovernanceNonceFV`](../../test-forge/fv/RelayGovernanceNonceFV.t.sol) for the nonce, [`RelayEpochAdvanceFV`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol) for the epoch pointer, etc.).

So the residual after the full stack is not "the security core is untested" but "all-functions storage
invariants *over raw assembly storage* are not automatically dischargeable" — incremental assurance over an
already-strong, multi-tool, multi-fidelity base. The generalizable lesson is in [L12](12-lessons.md):
*when independent unbounded tools converge on the same stall against hand-written assembly, that is the
signal to switch to theorem-proving against a validated low-level semantics.*

**Next:** [L3 — R0/R1 foundation tests](03-R0R1-foundation-tests.md), the base of the stack; or jump to
any rung via the [README map](00-README.md).
