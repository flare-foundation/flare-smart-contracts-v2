# Verifying `Relay.sol` — the complete proving process

A guided, multi-resolution account of the entire formal-verification effort on Flare Network's
`Relay.sol`: from concrete tests, through bounded and unbounded symbolic execution, to machine-checked
theorem proving against a validated model of the EVM. It is written to serve **three roles at once**:

1. **A tutorial.** Readable top-to-bottom, high-level-first with analogies, descending gradually into full
   rigor. It teaches not just *what* we proved but *how* and *why* — a template for similar work.
2. **Audit-ready documentation.** Every claim is traceable to an artifact (a test, a theorem, a check)
   with its scope, its assumptions, and its evidence location. The proven-vs-assumed boundary is explicit
   everywhere. The claims ledger ([L10](10-claims-ledger-trust-and-residual.md)) is the auditor's index.
3. **A reproducibility record.** Exact toolchains, versions, commands, and expected outputs for every
   rung ([L11](11-reproducibility.md)), so any result can be independently re-checked.

These three are not in tension: an audit that cannot be reproduced is hearsay, and a tutorial that is not
precise teaches the wrong thing. The same precision serves all three.

---

## The result in one paragraph

`Relay.sol`'s security-critical accounting is verified by a **five-rung stack**, each rung covering what
the one below cannot. Concrete and fuzz tests (R0/R1) exercise the deployed contract. **Halmos** (R2)
symbolically executes the **real bytecode** across 25 harnesses / 85 checks, proving the signature/
threshold accounting, the full `relay()` epoch-decision matrix, access control, lifecycle, Merkle and
randomness, and fees — bounded in size but on the actual deployed code, each proof guarded by an
anti-vacuity control. **Kontrol/KEVM** (R3) lifts the signature-loop weight invariant and random
monotonicity to **∀K** (unbounded signatures) by k-induction on a faithful Solidity *model*, at voter
counts N∈{3,5}. **Lean 4** (R4a) proves the signature-loop threshold soundness **∀N ∀K** as an abstract
algorithm, hole-free. The **bytecode-refinement step** (R4b — code-named *"Gap B"* in the engagement, the
name its Lean files carry) then lifts that soundness onto a loop executed by NethermindEth's
**validated EVMYulLean** semantics, for all N — closing the abstract-vs-real-machine gap for the loop
mechanism. Two unbounded approaches — Kontrol at full symbolic-N and **Certora** at all-functions storage
invariants — hit the *same* wall: Relay's ~90% hand-written inline-assembly storage defeats automated
storage analysis. That convergent failure is itself a finding, and it is exactly the gap the Lean/Gap-B
rungs step over. The residual trusted surface is small and named: cryptography (`ecrecover`/`keccak`, by
design), a trusted signing-policy setter, and the Gap-B data layer. Everything else is machine-checked.

---

## How to read this (progressive disclosure)

Each level is self-contained and honest at its own resolution; simplifications are flagged where made and
discharged deeper. Read only as deep as you need.

| Level | File | Role | For whom |
|-------|------|------|----------|
| **L1** | [`01-big-picture.md`](01-big-picture.md) | tutorial | What Relay does, what "verification" means, the two enemies — by analogy. No background needed. |
| **L2** | [`02-strategy-and-the-fidelity-ladder.md`](02-strategy-and-the-fidelity-ladder.md) | tutorial + audit | The research-first strategy, the **fidelity ladder (R0–R5)**, and the executive results table across all rungs. |
| **L3** | [`03-R0R1-foundation-tests.md`](03-R0R1-foundation-tests.md) | all | Foundry concrete + fuzz tests: the base of the stack. |
| **L4** | [`04-R2-bounded-symbolic-halmos.md`](04-R2-bounded-symbolic-halmos.md) | all | The 25-harness / 85-check Halmos suite on real bytecode + the vacuity tripwire. The property catalog. |
| **L5** | [`05-R3-unbounded-attempts.md`](05-R3-unbounded-attempts.md) | all | Kontrol (∀K on a model) and Certora (storage invariants) — partial successes and the honest assembly wall. |
| **L6** | [`06-R4a-abstract-proof.md`](06-R4a-abstract-proof.md) | all | The abstract proof (*"Phase A"*): the ∀N ∀K threshold-soundness theorem in Lean. |
| **L7** | [`07-R4b-bytecode-refinement.md`](07-R4b-bytecode-refinement.md) | all | The bytecode refinement (*"Gap B"*): lifting the abstract proof onto validated EVM semantics, ∀N. |
| **L8** | [`08-the-mathematics.md`](08-the-mathematics.md) | deep dive | The objects in math notation: abstract model, operational semantics, refinement, fuel-genericity. |
| **L9** | [`09-the-formal-detail.md`](09-the-formal-detail.md) | deep dive | Verbatim Lean (Phase A + Gap B), the EVMYulLean API, the gotchas, the axiom audit. |
| **L10** | [`10-claims-ledger-trust-and-residual.md`](10-claims-ledger-trust-and-residual.md) | **audit core** | Every claim → tool → rung → proven/assumed → evidence. The trust chain. What is **not** claimed. |
| **L11** | [`11-reproducibility.md`](11-reproducibility.md) | **repro core** | Every tool, version, command, expected output, per rung. |
| **L12** | [`12-lessons.md`](12-lessons.md) | tutorial | The transferable method for verifying assembly-heavy contracts. |

**Fast paths.** Auditor: L2 → L10 → L11, then drill into any rung (L3–L9). Mathematician: L8 → L9 (then
L10 §residual). Engineer reproducing: L11, with each rung doc alongside. Newcomer: L1 → L2 → onward.

---

## The standing convention (used everywhere)

- **"Proven"** = a machine-checked artifact whose statement *is* the claim: a Lean theorem with a clean
  `#print axioms` (only `propext`, `Classical.choice`, `Quot.sound` — no `sorry`/`sorryAx`), or a Halmos
  check that passes with no counterexample and a live anti-vacuity control, or a Kontrol proof that passes.
  The exact bar per tool is in each rung's doc.
- **"Assumed"** = a hypothesis not discharged by the tool, justified by other evidence and named in
  [L10](10-claims-ledger-trust-and-residual.md). The standing assumptions (the *modeling contract*) are:
  cryptography (`keccak` injective-uninterpreted, `ecrecover` uninterpreted), a trusted signing-policy
  setter (RLY-06), OZ `MerkleProof` correctness, and `oldRelay` trusted.
- **Scope** is always stated: input coverage (a few / random / bounded-all / unbounded-all) **and** object
  fidelity (real bytecode / a model / a validated EVM semantics / an abstract algorithm).
- **The two Lean code-names.** The R4 work was done in two Lean steps whose engagement code-names also name
  their source files; we lead with the descriptive name and keep the code-name as a parenthetical alias so
  the artifacts are recognizable:
  - **the abstract proof** — code-name ***Phase A*** — the ∀N ∀K threshold-soundness theorem
    (`test-forge/fv/lean/RelaySigLoop.lean`).
  - **the bytecode refinement** — code-name ***Gap B*** — the step lifting that proof onto validated EVM
    semantics (`test-forge/fv/lean/gapB/GapB_close.lean`). ("Gap B" was simply the engagement's label for
    *the gap between the abstract proof and the real bytecode*; closing it is what R4b does.)

---

## Relationship to the existing engagement docs

This set is the consolidated, pedagogical, audit+reproducibility view. It draws on and supersedes the
scattered working docs, which remain as detailed references:
`docs/relay-verification-summary.md` (the prior audit entry point — note it **predates the Gap B
closure**, now corrected here), `docs/relay-fv.md`, `docs/relay-phase3-plan.md`,
`docs/relay-assembly-review.md`, `docs/relay-phase3-documented-items.md`, `docs/relay-t1-bridge.md`,
`docs/relay-gapB-bytecode-refinement.md`, `certora/README.md`, `test-forge/fv/kontrol/README.md`. Where
this set and an older doc disagree, **this set is current** (it reflects the Gap-B-closed state).
