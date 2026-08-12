# Verifying `Relay.sol` — the complete proving process

A guided, multi-resolution account of the entire formal-verification effort on Flare Network's
`Relay.sol`: from concrete tests, through bounded and unbounded symbolic execution, to machine-checked
theorem proving against a validated model of the EVM. It is written to serve **three roles at once**:

1. **A tutorial.** Readable top-to-bottom, high-level-first with analogies, descending gradually into full
   rigor. It teaches not just _what_ we proved but _how_ and _why_ — a template for similar work.
2. **Audit-ready documentation.** Every claim is traceable to an artifact (a test, a theorem, a check)
   with its scope, its assumptions, and its evidence location. The proven-vs-assumed boundary is explicit
   everywhere. The claims ledger ([L10](10-claims-ledger-trust-and-residual.md)) is the auditor's index.
3. **A reproducibility record.** Exact toolchains, versions, commands, and expected outputs for every
   rung ([L11](11-reproducibility.md)), so any result can be independently re-checked.

These three are not in tension: an audit that cannot be reproduced is hearsay, and a tutorial that is not
precise teaches the wrong thing. The same precision serves all three.

> **Evidence boundary (updated 2026-08-12).** Relay governance is now a per-chain owner
> plus timelock. [`CURRENT-STATUS.md`](CURRENT-STATUS.md) is the sole current
> verdict page and records only commands actually run for this revision. This
> long-form ladder preserves the earlier research narrative; Safe/GSS material,
> old check counts, old compiler pins, old CI colors and old cloud links are
> historical context unless the current-status page explicitly re-attests them.
> The latest source is `d5af7136…`. All six local constituents now pass against
> manifest `7ae2208f…`, including the transient-threshold rebaseline, but are
> development-only because they were generated in a dirty tree. The aggregate
> bundle also passes as development-only (SHA-256 `be386d63…`). Supplemental
> Certora cloud evidence is PARTIAL: threshold passes, while scalar and
> write-once retain sanity failures.

> **The engagement had two goals.** (1) **Verify** `Relay.sol`'s accounting — this ladder. (2) **Harden**
> `Relay.sol` against the audit findings — the RLY-\* robustness fixes, documented in
> [`docs/relay-fixes.md`](../relay-fixes.md) (issue-by-issue changes + tests) and
> [`docs/relay-security-review.md`](../relay-security-review.md) (the post-fix review). This ladder is the
> verification half; those two docs are the hardening half. They meet in the claims ledger
> ([L10](10-claims-ledger-trust-and-residual.md)), where several fixes appear as the operational-boundary
> contracts (OP-1/3/4) and trust assumptions (RLY-06/07) the proofs rely on.

---

## The result in one paragraph

> **Historical engagement summary.** The paragraph below explains the layered
> proof strategy and its earlier results. It is not a current release
> attestation; use [`CURRENT-STATUS.md`](CURRENT-STATUS.md) for that.

[`Relay.sol`](../../contracts/protocol/implementation/Relay.sol)'s
security-critical accounting is addressed by a five-rung stack: concrete and
fuzz tests, bounded symbolic execution of real bytecode, inductive models, an
abstract Lean theorem, and a conditional refinement over validated EVM/Yul
semantics. The current owner/timelock/UUPS re-baseline uses one solc 0.8.35
compiler/settings profile and a manifest of 123 Halmos checks across 27 harness
contracts; the local gate passes 86 proofs and 37 validated reachability
controls. The Lean gate passes nine files and 183 declared axiom audits.
Certora's three current configs and 15 rules compile and CVL-typecheck locally,
which is front-end evidence rather than a proof verdict. The supplemental cloud
report is PARTIAL: its threshold configuration passes, while scalar and
write-once are partial because 24 sanity nodes fail. Exact current observations, bounds, and
report requirements are in [`CURRENT-STATUS.md`](CURRENT-STATUS.md).

The central theorem boundary remains explicit: increasing indices prevents
duplicate **policy slots**, but all threshold claims require voter addresses to
be unique at policy admission. The implementation does not currently enforce
that premise. Cryptography, external-call ABI assumptions, arbitrary future
UUPS implementation semantics, and the remaining refinement seams are likewise
outside the claimed theorem unless a specific artifact says otherwise.

---

## How to read this (progressive disclosure)

Each level is self-contained and honest at its own resolution; simplifications are flagged where made and
discharged deeper. Read only as deep as you need.

| Level   | File                                                                               | Role             | For whom                                                                                                                                                         |
| ------- | ---------------------------------------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **L1**  | [`01-big-picture.md`](01-big-picture.md)                                           | tutorial         | What Relay does, what "verification" means, the two enemies — by analogy. No background needed.                                                                  |
| **L2**  | [`02-strategy-and-the-fidelity-ladder.md`](02-strategy-and-the-fidelity-ladder.md) | tutorial + audit | The research-first strategy, the **fidelity ladder (R0–R5)**, and the executive results table across all rungs.                                                  |
| **L3**  | [`03-R0R1-foundation-tests.md`](03-R0R1-foundation-tests.md)                       | all              | Foundry concrete + fuzz tests: the base of the stack.                                                                                                            |
| **L4**  | [`04-R2-bounded-symbolic-halmos.md`](04-R2-bounded-symbolic-halmos.md)             | all              | The bounded Halmos methodology, current manifest inventory, historical context, and vacuity tripwire. Current verdict: [`CURRENT-STATUS.md`](CURRENT-STATUS.md). |
| **L5**  | [`05-R3-unbounded-attempts.md`](05-R3-unbounded-attempts.md)                       | all              | Historical Kontrol (∀K on a model), the current Certora local gate, and explicit bounds for any future owner-timelock cloud proofs.                              |
| **L6**  | [`06-R4a-abstract-proof.md`](06-R4a-abstract-proof.md)                             | all              | The abstract proof: the ∀N ∀K threshold-soundness theorem in Lean.                                                                                               |
| **L7**  | [`07-R4b-bytecode-refinement.md`](07-R4b-bytecode-refinement.md)                   | all              | The bytecode refinement: lifting the abstract proof onto validated EVM semantics, ∀N.                                                                            |
| **L8**  | [`08-the-mathematics.md`](08-the-mathematics.md)                                   | deep dive        | The objects in math notation: abstract model, operational semantics, refinement, fuel-genericity.                                                                |
| **L9**  | [`09-the-formal-detail.md`](09-the-formal-detail.md)                               | deep dive        | Verbatim Lean (the abstract proof + the bytecode refinement), the EVMYulLean API, the gotchas, the axiom audit.                                                  |
| **L10** | [`10-claims-ledger-trust-and-residual.md`](10-claims-ledger-trust-and-residual.md) | **audit core**   | Every claim → tool → rung → proven/assumed → evidence. The trust chain. What is **not** claimed.                                                                 |
| **L11** | [`11-reproducibility.md`](11-reproducibility.md)                                   | **repro core**   | Every tool, version, command, expected output, per rung.                                                                                                         |
| **L12** | [`12-lessons.md`](12-lessons.md)                                                   | tutorial         | The transferable method for verifying assembly-heavy contracts.                                                                                                  |
| **L13** | [`13-residual-weaknesses.md`](13-residual-weaknesses.md)                           | **audit core**   | Proof-grounded review of what could still go wrong — residual weaknesses & attack surface, tiered by attention.                                                  |

Two companions sit alongside the numbered ladder: [`CHECKPOINT.md`](CHECKPOINT.md) (the raw engagement log)
and [`CONCEPTS.md`](CONCEPTS.md) (plain-words FAQ for the concepts used throughout).

**Fast paths.** Auditor: L2 → L10 → **L13** → L11, then drill into any rung (L3–L9). Mathematician: L8 → L9
(then L10 §residual). Engineer reproducing: L11, with each rung doc alongside. Newcomer: L1 → L2 → onward.
Security reviewer: **L13** (residual weaknesses) → L10 (the formal register behind it).

---

## The standing convention (used everywhere)

- **"Proven"** = a machine-checked artifact whose statement _is_ the claim: a Lean theorem with a clean
  `#print axioms` (only `propext`, `Classical.choice`, `Quot.sound` — no `sorry`/`sorryAx`), or a Halmos
  check that passes with no counterexample and a live anti-vacuity control, or a Kontrol proof that passes.
  The exact bar per tool is in each rung's doc.
- **"Assumed"** = a hypothesis not discharged by the tool, justified by other evidence and named in
  [L10](10-claims-ledger-trust-and-residual.md). The standing assumptions (the _modeling contract_) are:
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
- **Code links are symbol-addressed and machine-maintained.** A mention of a check/proof/theorem links to
  its defining file at a single-line anchor (`#L<n>` — the one form both GitLab and GitHub render).
  [`verify_links.py`](verify_links.py) recomputes every anchor from the sources; CI (`test-doc-links`)
  fails on any stale link, so line numbers in these docs never rot. After renaming or moving an artifact:
  `python3 docs/relay-verification/verify_links.py --fix`.

---

## Relationship to the other engagement docs

This set is the authoritative, consolidated audit + tutorial + reproducibility view. Deeper
tool-specific references live alongside it: [`certora/README.md`](../../certora/README.md), [`test-forge/fv/kontrol/README.md`](../../test-forge/fv/kontrol/README.md),
[`test-forge/fv/lean/bytecode-refinement/README.md`](../../test-forge/fv/lean/bytecode-refinement/README.md), [`docs/relay-assembly-review.md`](../../docs/relay-assembly-review.md),
[`docs/relay-phase3-documented-items.md`](../../docs/relay-phase3-documented-items.md), and [`docs/relay-t1-bridge.md`](../../docs/relay-t1-bridge.md).
The **hardening half** of the engagement (goal 2) is documented in [`docs/relay-fixes.md`](../relay-fixes.md)
(the RLY-\* robustness fixes, issue-by-issue, with tests) and [`docs/relay-security-review.md`](../relay-security-review.md)
(the post-fix security review). Two engagement-log companions live alongside this ladder:
[`CHECKPOINT.md`](CHECKPOINT.md) — the raw chronological engineering log behind these docs — and
[`CONCEPTS.md`](CONCEPTS.md) — plain-words explanations of the concepts used here (SMT solvers, k-induction,
CEXes, psAt, …), a draft of future FAQ pages.
