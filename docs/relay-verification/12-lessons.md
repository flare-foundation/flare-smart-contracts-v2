# L12 — Lessons for verifying assembly-heavy contracts

> **What you get from this level.** The transferable method — the parts of this engagement that generalize
> to other hard verification targets, especially contracts written in inline assembly where the usual
> automated tools stall. Each lesson is stated as a reusable principle, then tied to where it appeared.

---

### 1. Use the fidelity ladder as a *design* tool, not just a label

Before writing a proof, decide which rung each claim must reach and *why*. Most properties don't need R5;
many are fine at R2. Spend rigor where the *risk* is. Here, risk was concentrated in two places —
unboundedness and hand-written assembly — so those got R4 effort, while the cryptography was deliberately
left "assumed." Mapping risk → rung up front prevents both under-verifying the dangerous parts and
over-verifying the safe ones. ([L2](02-strategy-and-the-fidelity-ladder.md))

### 2. Build a stack, and make the rungs cover each other

No single tool defeats both the induction barrier and the assembly barrier over a whole assembly-heavy
contract. So pick each tool for the rung where its strengths land, and let the layers overlap: Halmos on
the *real bytecode* (bounded), Kontrol/Lean for *all sizes* (on a model / abstract), Gap B to *reconnect*
the unbounded result to a validated machine, and an explicit **bridge** (`RelayModelBridgeFV`) tying the
model back to the bytecode. The overlaps are the assurance.

### 3. Treat convergent tool failure as a *finding*, not a setback

When two independent unbounded tools (Kontrol at symbolic-N, Certora at storage invariants) stalled on the
*same* obstacle — inline-assembly storage — that was diagnostic: it located the difficulty precisely (the
R3→R4 barrier) and justified the jump to theorem proving. **Record failed tool runs as findings**, with the
decisive tell (here: `setSigningPolicy` "violating" an invariant it cannot logically affect). A stall that
is understood is a result. ([L5](05-R3-unbounded-attempts.md))

### 4. Separate the two enemies by refinement

Don't fight unboundedness and real-machine fidelity in the same proof. Prove the property on a clean
abstract model (induction is easy there), and *separately* prove the concrete system refines that model
(no high-level property to also juggle). Compose. Each half stays small because it has one job. This is the
single most important structural decision. ([L2 §2.4](02-strategy-and-the-fidelity-ladder.md), [L7](07-R4b-bytecode-refinement.md))

### 5. Choose a *defensible boundary* and fence the residual explicitly

Full R5 (literal bytes, memory, crypto) is intractable. Rather than fail, pick a boundary — loop mechanism
proven, data layer assumed — and make it *legible*: every assumption named, located, and individually
attackable (the register in [L10 §10.2](10-claims-ledger-trust-and-residual.md)). A proof with a small,
explicit trusted surface is far more useful than an all-or-nothing attempt that never closes. The
discipline: *never hide an assumption inside a proof; promote it to a named hypothesis.*

### 6. Build bottom-up, brick by brick, each independently checkable

Both the Halmos suite and the Gap-B proof were assembled from small, separately-verified pieces (Halmos
harnesses each with a vacuity control; Gap-B lemmas `step_ADD`, `getElem_Ok`, `body_eff`, `loop_step`, …
each `#print axioms`-clean before composition). Failures stay local, progress is measurable, and the final
capstone is a short assembly. The staged `gapB/GapB_*.lean` files double as a tutorial trail.

### 7. Engineer against vacuity from day one

A passing proof that is *trivially* true is worse than no proof — it gives false confidence. Pair every
positive proof with an **anti-vacuity control** that must fail (Halmos `reach_*`, Kontrol `prove_reach_*`),
and gate on both halves (`verify_fv.py`). This caught a real silent truncation here (the default `loop=2`
making 3+-signature proofs vacuous). ([L4 §4.2](04-R2-bounded-symbolic-halmos.md))

### 8. Fuel-genericity: reduce a definitional interpreter at symbolic fuel

The reusable trick for reasoning about a fuel-indexed interpreter *without* a fuel-monotonicity lemma:
prove each statement's effect at fuel `fuel + K` with `fuel` free and `K` the exact unfolding cost; the
simplifier peels exactly `K` successors and leaves `fuel` inert. Then line up symbolic fuels in the
induction with `ring`-style rewrites. Converts a missing meta-theorem about someone else's interpreter into
local, decidable per-statement facts. Applies to *any* fuel-based definitional semantics. ([L8 §C.3](08-the-mathematics.md), [L9 §D](09-the-formal-detail.md))

### 9. Make the axiom list the definition of "done"

Adopt a crisp, machine-checkable completeness bar: every committed theorem must `#print axioms` to exactly
the standard foundational axioms — no `sorry`/`sorryAx`, no `native_decide`/`ofReduceBool`, no bespoke
`axiom`. Unambiguous, automatable in CI, immune to wishful "it basically works." "Bulletproof" became a
grep. ([L9 §F](09-the-formal-detail.md), [L11 §11.8](11-reproducibility.md))

### 10. Build against a *validated* semantics, and inherit its validation honestly

Reasoning about the real machine needs a model of it. Use one that is independently validated (EVMYulLean
vs. the Ethereum execution-spec tests) rather than rolling your own, and state clearly that your R4 result
*inherits* that validation. You convert "trust my EVM model" into "trust the cross-client conformance
corpus" — a much better trade. ([L2 §2.5](02-strategy-and-the-fidelity-ladder.md))

### 11. Make CI reproduce the verification config, not just "run the tool"

A formal result that only holds under a non-default flag must encode that flag where CI reads it. Here a
proof committed as "verified" depended on a local `--solver-timeout-assertion 0` that CI didn't supply, so
it regressed to a false counterexample until the option was moved into `halmos.toml`. **Verification config
belongs in version-controlled config the gate reads**, not in a test's comment. ([L11 §11.3](11-reproducibility.md))

### 12. Keep a resumable engineering log

`PROGRESS.md` (and the out-of-repo `CHECKPOINT.md`) recorded every API fact, every gotcha *with its
reason*, the fuel constants, and the resume commands. On a multi-session proof effort this is what makes
work pickup-able after a context reset and turns hard-won tacit knowledge into reusable documentation.

### 13. On estimation

The Gap-B step was scoped at "weeks" and closed in hours. The honest post-mortem, worth internalizing:

- **Scope settles the estimate.** "Weeks" was for the maximalist R5 reading; choosing the defensible R4
  boundary (lesson 5) is itself most of the speedup.
- **Research tasks are bimodal on the key trick.** Fuel-genericity (lesson 8) was the gate; found early,
  the rest was routine. Estimate as a distribution ("fast if the trick exists, slow if not"), not a scalar.
- **Re-estimate when feasibility gates fall.** Most initial risk was binary unknowns (does the semantics
  build? does it drive symbolically?). Once those resolved in the first hour, the estimate should have
  dropped sharply. Carrying the original number is a planning error.
- **Match the clock to the executor.** "Weeks" is human-calendar time; tight machine-checked
  iterate-compile loops run on a different clock.

---

*End of the tutorial set. Back to [the index](00-README.md). The honest scope lives in
[L10](10-claims-ledger-trust-and-residual.md); the machine-checkable truth lives in the artifacts under
`test-forge/fv/` (Halmos, Kontrol, Lean) and `certora/`, re-checkable via [L11](11-reproducibility.md).*
