# L6 — Reproduce & lessons

> **What you get from this level.** First, the exact toolchain and commands to independently re-check
> every theorem (including the axiom audit). Second, the transferable method — the parts of this approach
> that generalize to other hard verification targets, especially assembly-heavy contracts.

---

## Part 1 — Reproduce

### 1.1 Toolchain

| Component | Version / source |
|-----------|------------------|
| Lean | 4.22.0 (via `elan`; `lean-toolchain` pins it, `elan` auto-fetches) |
| mathlib | 4.22.0 (matching) |
| EVMYulLean | NethermindEth/EVMYulLean (validated EVM/Yul semantics), with FFI for keccak/sha2/`ByteArray.zeroes` |
| Host tools | `elan`/`lean` on `PATH`; `openjdk` (for some EVMYulLean tooling); `solc 0.8.27` (for IR regeneration, optional) |

Phase A (`RelaySigLoop.lean`) needs **only Lean + mathlib** — no EVMYulLean. Gap B needs EVMYulLean.

### 1.2 Build the validated semantics

```bash
cd /tmp
git clone --depth 1 https://github.com/NethermindEth/EVMYulLean evmyul2
cd evmyul2
lake exe cache get      # fetch prebuilt mathlib (avoids a long compile)
lake build              # builds EVMYulLean incl. EvmYul.Yul.Interpreter (~1000 modules)
```

`elan` reads `evmyul2/lean-toolchain` and fetches Lean 4.22.0 automatically on first invocation.

### 1.3 Check the Gap-B proof and audit its axioms

Place the committed file in the built project's root and check it:

```bash
cp <repo>/test-forge/fv/lean/gapB/GapB_close.lean /tmp/evmyul2/GapB_close.lean
cd /tmp/evmyul2
export PATH="$HOME/.elan/bin:/usr/local/opt/openjdk/bin:$PATH"
lake env lean GapB_close.lean
```

A successful check prints (from the file's trailing `#print axioms`):

```
'GapB.loop_acc' depends on axioms: [propext, Classical.choice, Quot.sound]
'GapB.bytecode_loop_correct' depends on axioms: [propext, Classical.choice, Quot.sound]
'GapB.bytecode_threshold_sound' depends on axioms: [propext, Classical.choice, Quot.sound]
```

and exits `0`, with **no** `error:`, **no** `sorry`, **no** `sorryAx` in the axiom lists. That output is
the whole certificate: statements are in the file, axioms are exactly the three standard ones.

> **Tip — check the *committed* file, not a working copy.** To prove you are checking what is in version
> control, pipe it straight from git:
> ```bash
> git show HEAD:test-forge/fv/lean/gapB/GapB_close.lean > /tmp/evmyul2/GapB_verify.lean
> cd /tmp/evmyul2 && lake env lean GapB_verify.lean
> ```

### 1.4 Check Phase A

Phase A is plain Lean core; check it in any Lean 4.22.0 + mathlib project (or add a `#print axioms
threshold_sound` and confirm `[propext, Classical.choice, Quot.sound]`).

### 1.5 The development bricks

`gapB/GapB_*.lean` (probe, loop, refine, ops, body, bridge, full, loopcorrect) are each self-contained
and checkable with `lake env lean <file>` the same way. They are the staged history — useful to read in
order to see each obligation proven in isolation before assembly into `GapB_close.lean`. The engineering
log with all API facts, gotchas, and the resume protocol is `gapB/PROGRESS.md`.

---

## Part 2 — Lessons for similar endeavors

These are the generalizable takeaways — the reason the second purpose of this document is "a tutorial for
similar work." Each is stated as a reusable principle, then tied to where it appeared here.

### 2.1 Use the fidelity ladder as a *design* tool, not just a classification

Before writing a single proof, decide which rung each claim must reach and *why*. Most properties do not
need R5; many are fine at R3. Spend rigor where the *risk* is. Here, the risk was concentrated in two
places — unboundedness and hand-written assembly — so those got R4 effort, while the cryptography was
left at "assumed" by explicit decision. Mapping risk → rung up front prevents both under-verifying the
dangerous parts and over-verifying the safe ones.

### 2.2 Treat convergent tool failure as a signal, not a setback

When two independent unbounded tools (Kontrol and Certora) stalled on the *same* obstacle (assembly
storage), that was diagnostic: it located the difficulty precisely (the R3→R4 barrier) and justified the
jump to theorem proving. **Record failed tool runs as findings.** A stall that is understood is a result;
it tells you where the model–reality gap lives.

### 2.3 Separate the two enemies by refinement

Do not fight unboundedness and real-machine fidelity in the same proof. Prove the property on a clean
abstract model (Enemy 1, induction is easy there), and *separately* prove the concrete system refines
that model (Enemy 2, no high-level property to also juggle). Compose. Each half stayed small because it
had one job. This is the single most important structural decision.

### 2.4 Choose a *defensible boundary* and fence the residual explicitly

Full R5 (literal bytes, memory, crypto) was intractable. Rather than fail, we picked a boundary —
loop mechanism proven, data layer assumed — and made the boundary *legible*: A1–A5 are named, located,
and each is individually attackable (L5). A proof with a small, explicit trusted surface is far more
useful than an all-or-nothing attempt that never closes. The discipline is: *never hide an assumption
inside a proof; promote it to a named hypothesis.*

### 2.5 Build bottom-up, brick by brick, each independently checkable

The Gap-B proof was assembled from small lemmas (`step_ADD`, `getElem_Ok`, `body_eff`, `loop_step`, …),
each proven and `#print axioms`-clean in its own file before composition. This makes failures local,
progress measurable, and the final capstone a short assembly. It also produced the staged `GapB_*.lean`
files that double as a tutorial trail.

### 2.6 Fuel-genericity: reduce a definitional interpreter at symbolic fuel

The reusable trick (L4 §D): to reason about a fuel-indexed interpreter *without* a fuel-monotonicity
lemma, prove each statement's effect at fuel `fuel + K` with `fuel` free and `K` the exact unfolding
cost; the simplifier peels exactly `K` successors and leaves `fuel` inert. Then line up symbolic fuels in
the induction with `ring`-style rewrites. This converts a missing meta-theorem about someone else's
interpreter into local, decidable per-statement facts. It applies to *any* fuel-based definitional
semantics — not just EVMYulLean.

### 2.7 Make the axiom list the definition of "done"

Adopt a crisp, machine-checkable bar for completeness: every committed theorem must `#print axioms` to
exactly the standard foundational axioms — no `sorry`/`sorryAx`, no `native_decide`/`ofReduceBool`, no
bespoke `axiom`. This is unambiguous, automatable in CI, and immune to wishful "it basically works."
"Bulletproof" became a grep on the build output.

### 2.8 Build against a *validated* semantics, and inherit its validation honestly

Reasoning about the real machine requires a model of it. Use one that is independently validated
(EVMYulLean against the Ethereum execution-spec tests) rather than rolling your own, and state clearly
that your R4 result *inherits* that validation (A5). You convert "trust my EVM model" into "trust the
cross-client conformance corpus" — a much better trade.

### 2.9 Keep a resumable engineering log

`PROGRESS.md` recorded every API fact, every gotcha (with the *reason*), the fuel constants, and the
resume commands. On a multi-session proof effort this is what makes the work pickup-able after a context
reset and what turns hard-won tacit knowledge (E.1–E.6 in L4) into reusable documentation.

### 2.10 On estimation

This effort was scoped at "weeks" and closed in hours. The honest post-mortem (worth internalizing for
planning similar work):

- **Scope settles the estimate.** The "weeks" figure was for the maximalist R5 reading. Choosing the
  defensible R4 boundary (2.4) is *itself* most of the speedup — a smaller, well-chosen target.
- **Research tasks are bimodal on the key trick.** Fuel-genericity (2.6) was the gate; found early, the
  rest was routine. Estimate such tasks as a distribution ("fast if the trick exists, slow if not"), not
  a scalar.
- **Re-estimate when feasibility gates fall.** Most initial risk was binary unknowns (does the semantics
  build? does it drive symbolically?). Once those resolved favorably in the first hour, the estimate
  should have dropped sharply. Carrying the original number is a planning error.
- **Match the clock to the executor.** "Weeks" is human-calendar time; tight machine-checked
  iterate-compile loops run on a different clock. Estimate in the clock the work will actually run in.

---

*End of the tutorial set. Back to [the index](00-README.md). The honest scope lives in
[L5](05-limits-trust-and-residual.md); the machine-checkable truth lives in
`test-forge/fv/lean/RelaySigLoop.lean` and `test-forge/fv/lean/gapB/GapB_close.lean`.*
