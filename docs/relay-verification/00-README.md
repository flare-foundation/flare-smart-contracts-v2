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

> **The engagement had two goals.** (1) **Verify** `Relay.sol`'s accounting — this ladder. (2) **Harden**
> `Relay.sol` against the audit findings — the RLY-* robustness fixes, documented in
> [`docs/relay-fixes.md`](../relay-fixes.md) (issue-by-issue changes + tests) and
> [`docs/relay-security-review.md`](../relay-security-review.md) (the post-fix review). This ladder is the
> verification half; those two docs are the hardening half. They meet in the claims ledger
> ([L10](10-claims-ledger-trust-and-residual.md)), where several fixes appear as the operational-boundary
> contracts (OP-1/3/4) and trust assumptions (RLY-06/07) the proofs rely on.

---

## The result in one paragraph

[`Relay.sol`](../../contracts/protocol/implementation/Relay.sol)'s security-critical accounting is verified by a **five-rung stack**, each rung covering what
the one below cannot. Concrete and fuzz tests (R0/R1) exercise the deployed contract. **Halmos** (R2)
symbolically executes the **real bytecode** across 26 harnesses / 89 checks, proving the signature/
threshold accounting, the full `relay()` epoch-decision matrix, access control, lifecycle, Merkle and
randomness, and fees — bounded in size but on the actual deployed code, each proof guarded by an
anti-vacuity control. **Kontrol/KEVM** (R3) lifts the signature-loop weight invariant and random
monotonicity to **∀K** (unbounded signatures) by k-induction on a faithful Solidity *model*, at voter
counts N∈{3,5}. **Lean 4** (R4a) proves the signature-loop threshold soundness **∀N ∀K** as an abstract
algorithm, hole-free. The **bytecode refinement** (R4b) then lifts that soundness onto a loop executed by
NethermindEth's **validated EVMYulLean** semantics, for all N — closing the abstract-vs-real-machine gap
for the loop mechanism. Two unbounded approaches — Kontrol at full symbolic-N and **Certora** at
all-functions storage invariants — hit the *same* wall: Relay's ~90% hand-written inline-assembly storage
defeats automated storage analysis. That convergent failure is itself a finding, and it is exactly the gap
the R4 (Lean) rungs step over. The bytecode refinement now runs the deployed contract's **actual 17-statement
loop body** on the validated EVM (the hole-free [`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean) chain):
`relay_loop_sound_literal_derived_tight` carries *accept ⟹ total registered weight > threshold* for all N with
the memory-read facts (`hcov`/`hcorr`) **derived, not assumed** and the structural index guards discharged from
the accounting discipline — the abstract masked-read statement `relay_loop_sound` (`mload(slot) & 0xffff`, **data
layer BR-1** machine-checked) remains as the simpler corroborating result (L7 §7.3). The same literal method
then extends in **breadth** to the rest of `relay()` (**R5**, all hole-free): the mode dispatch
(`dispatch_routes_verify`), the storage round-trip and accept-write (`sstore_sload` / `sstore_reads_back`), the
end-to-end **dispatch → loop → accept** composition (`relay_dispatch_loop_accept`), and fee conservation
(`fee_conservation` / `transfer_conservation`) — coverage over the core loop soundness, not a new soundness fact
(L7 §7.5, L9 §G.5). The residual trusted surface
is small and named — exactly the ecrecover boundary (MC-2/OP-1), stated per-iteration as `IterPremiseT`:
cryptography (`ecrecover`/`keccak`), the operational ABI of each boundary call, a trusted signing-policy setter,
and the per-iteration *selection/validity* those external calls determine (which voter each signature recovers to,
strictly-increasing). Everything else is machine-checked.

---

## How to read this (progressive disclosure)

Each level is self-contained and honest at its own resolution; simplifications are flagged where made and
discharged deeper. Read only as deep as you need.

| Level | File | Role | For whom |
|-------|------|------|----------|
| **L1** | [`01-big-picture.md`](01-big-picture.md) | tutorial | What Relay does, what "verification" means, the two enemies — by analogy. No background needed. |
| **L2** | [`02-strategy-and-the-fidelity-ladder.md`](02-strategy-and-the-fidelity-ladder.md) | tutorial + audit | The research-first strategy, the **fidelity ladder (R0–R5)**, and the executive results table across all rungs. |
| **L3** | [`03-R0R1-foundation-tests.md`](03-R0R1-foundation-tests.md) | all | Foundry concrete + fuzz tests: the base of the stack. |
| **L4** | [`04-R2-bounded-symbolic-halmos.md`](04-R2-bounded-symbolic-halmos.md) | all | The 26-harness / 89-check Halmos suite on real bytecode + the vacuity tripwire. The property catalog + the complete per-check inventory. |
| **L5** | [`05-R3-unbounded-attempts.md`](05-R3-unbounded-attempts.md) | all | Kontrol (∀K on a model) and Certora (storage invariants) — partial successes and the honest assembly wall. |
| **L6** | [`06-R4a-abstract-proof.md`](06-R4a-abstract-proof.md) | all | The abstract proof: the ∀N ∀K threshold-soundness theorem in Lean. |
| **L7** | [`07-R4b-bytecode-refinement.md`](07-R4b-bytecode-refinement.md) | all | The bytecode refinement: lifting the abstract proof onto validated EVM semantics, ∀N. |
| **L8** | [`08-the-mathematics.md`](08-the-mathematics.md) | deep dive | The objects in math notation: abstract model, operational semantics, refinement, fuel-genericity. |
| **L9** | [`09-the-formal-detail.md`](09-the-formal-detail.md) | deep dive | Verbatim Lean (the abstract proof + the bytecode refinement), the EVMYulLean API, the gotchas, the axiom audit. |
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
- **The two Lean developments.** R4 has two strands: **the abstract proof** — the ∀N ∀K
  threshold-soundness theorem ([`test-forge/fv/lean/RelaySigLoop.lean`](../../test-forge/fv/lean/RelaySigLoop.lean)); and **the bytecode refinement** —
  the step lifting it onto validated EVM semantics
  ([`test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean)), since extended with a **literal
  loop-body model** that executes the deployed 17-statement signature-verification body statement-for-statement
  on the validated EVM ([`test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean)), deriving the
  memory-read facts the masked-read statement assumed.

---

## Relationship to the other engagement docs

This set is the authoritative, consolidated audit + tutorial + reproducibility view. Deeper
tool-specific references live alongside it: [`certora/README.md`](../../certora/README.md), [`test-forge/fv/kontrol/README.md`](../../test-forge/fv/kontrol/README.md),
[`test-forge/fv/lean/bytecode-refinement/README.md`](../../test-forge/fv/lean/bytecode-refinement/README.md), [`docs/relay-assembly-review.md`](../../docs/relay-assembly-review.md),
[`docs/relay-phase3-documented-items.md`](../../docs/relay-phase3-documented-items.md), and [`docs/relay-t1-bridge.md`](../../docs/relay-t1-bridge.md).
The **hardening half** of the engagement (goal 2) is documented in [`docs/relay-fixes.md`](../relay-fixes.md)
(the RLY-* robustness fixes, issue-by-issue, with tests) and [`docs/relay-security-review.md`](../relay-security-review.md)
(the post-fix security review).
