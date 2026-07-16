# Plain-words concepts — working draft (FAQ / explanation pages)

> **Purpose:** collect the plain-language explanations produced during the Relay.sol
> verification engagement, one concept per section. At the end this becomes an FAQ /
> set of explanation pages (likely under `docs/relay-verification/`, linked from the
> ladder's tutorial track).
> **Status:** working draft, now maintained in-repo (`docs/relay-verification/`, moved 2026-07-15).
> Started 2026-07-07. Add new entries at the bottom; keep the index current.
> **Linked from:** the ladder docs point here at each concept's first load-bearing mention —
> [L1 §1.3](01-big-picture.md), [L2 §2.3](02-strategy-and-the-fidelity-ladder.md),
> [L4](04-R2-bounded-symbolic-halmos.md), [L5](05-R3-unbounded-attempts.md),
> [L6](06-R4a-abstract-proof.md), and the FV suite primer
> [`test-forge/fv/README.md`](../../test-forge/fv/README.md). When you add an entry, add the link at its
> first mention in the relevant doc too (and keep the cross-references between entries current).

## Index

1. [What is an SMT solver?](#1-what-is-an-smt-solver)
2. [Why two symbolic tools? (the bounded model-fidelity bridge)](#2-why-two-symbolic-tools-the-bounded-model-fidelity-bridge)
3. ["Verified on the real bytecode" — which bytecode, exactly?](#3-verified-on-the-real-bytecode--which-bytecode-exactly)
4. [What is KEVM?](#4-what-is-kevm)
5. [What is k-induction?](#5-what-is-k-induction)
6. [What is psAt? (the prefix sum at the heart of the proofs)](#6-what-is-psat-the-prefix-sum-at-the-heart-of-the-proofs)
7. [What is a CEX? (counterexamples, and why half the suite celebrates them)](#7-what-is-a-cex-counterexamples-and-why-half-the-suite-celebrates-them)
- [Candidate topics (not yet written)](#candidate-topics-not-yet-written)

---

## 1. What is an SMT solver?

An **SMT solver** is a program that answers one kind of question: *"Here is a set of
mathematical constraints — does there exist any assignment of values that satisfies all
of them at once?"* And it gives one of two answers:

- **"Yes"** — plus a concrete example (actual numbers that satisfy everything), called a *model*.
- **"No"** — meaning it has *proved* no such values exist, anywhere in the entire
  (astronomically large) search space.

The name unpacks as **Sat**isfiability **M**odulo **T**heories: "satisfiability" is the
yes/no question above, and "modulo theories" means it doesn't just handle true/false
logic — it natively understands richer *theories* like integer arithmetic, 256-bit
machine words (bitvectors), arrays/memory, and uninterpreted functions. So you can hand
it constraints like "`x + y` overflows 256 bits AND `x < 100` AND the array at index `y`
equals 0" and it reasons about all of that together.

**A good mental model:** a tireless, superhuman Sudoku solver — but for arbitrary math
puzzles. You write the rules; it either fills in the grid (here's a solution) or comes
back with "this puzzle has *no* solution, guaranteed." The magic is that "no" is not
"I didn't find one" — it's a logical proof of impossibility, without trying the ~2²⁵⁶
possibilities one by one. Clever deduction and pruning (the practical descendants of the
DPLL/CDCL algorithms) make this feasible surprisingly often.

**Why verification tools are built on it** — the trick is to ask for a *bug*:

1. Take the code and a property, e.g. *"relay() accepts ⟹ signer weight exceeds the threshold."*
2. Translate an execution path of the code into constraints, and add the **negation** of
   the property: "accept happened AND weight ≤ threshold."
3. Ask the solver.

Now the two answers flip meaning: **"No solution exists" = the property holds** on that
path for *every possible input* — a proof. **"Yes, here's a model" = a counterexample** —
concrete inputs (an actual signature list, an actual policy) that break the property,
which you can replay as a failing test.

That's literally what runs in this project's CI: **Halmos** executes `relay()`'s real
bytecode symbolically — inputs are unknowns, not concrete values — and turns each path
into a giant formula over 256-bit bitvectors, which **z3** (the SMT solver underneath)
then checks. The 60 green proofs are z3 saying "no violating input exists (up to the
bound)"; the 29 anti-vacuity controls are checks where we *expect* a "yes, here's a
model" — proving the interesting states are actually reachable, so the proofs aren't
vacuously true. Certora and Kontrol sit on SMT solvers the same way.

**The honest limits** (which shaped this whole engagement):

- **It needs finite formulas** — loops must be unrolled to a bound. That's why Halmos
  results are "for all inputs *up to* K≤3 signatures, N≤5 voters," and why crossing to
  *unbounded* ∀N needed induction in Lean instead — SMT can't do induction on its own.
- **It can answer "unknown"** or run forever — the problems are NP-hard in the best
  case, undecidable in general; solvers are heuristic engines that usually win but
  never promise to.
- **Some things it can't model, only assume** — `ecrecover` is real elliptic-curve
  crypto; no solver reasons about that, so it's treated as an *uninterpreted function*
  (an opaque box where the only known fact is: same input ⟹ same output). That's
  exactly the MC-2 trust boundary in our ledger.

In one line: **an SMT solver is an automated logician that either finds a concrete
scenario satisfying your constraints or proves none exists — and verification is the
art of phrasing "is there a bug?" as exactly that question.**

---

## 2. Why two symbolic tools? (the bounded model-fidelity bridge)

Verification tools trade off along two axes: **what object** they reason about, and **over
what input range**. In this engagement the two symbolic tools sit at opposite corners:

- **Halmos** symbolically executes the **real deployed bytecode** — perfect object fidelity,
  no storage model to break on hand-written assembly — but it must unroll loops, so every
  result is **bounded** (here: up to 3 signatures).
- **Kontrol/KEVM** can do **induction** (base case + inductive step ⟹ all K), so its results
  are **unbounded** — but running the real ~1747-line assembly `relay()` through KEVM is
  intractable, so its ∀K theorem is proven about a faithful **Solidity model** of the loop
  body instead.

That leaves the obvious question: *is the model faithful to the deployed bytecode?* If not,
the unbounded proof is about the wrong thing. The fix is the **bridge pattern**: state the
*same invariant* in a shared vocabulary — here the prefix-sum function `psAt(k) = w₀+…+w₋₁`,
copied verbatim-in-meaning from the Kontrol model into a Halmos harness
(`RelayModelBridgeFV`) — and prove, on the **real bytecode**, that *acceptance implies the
model's invariant* for every checkable K (1, 2, 3), plus an anti-vacuity control showing the
bytecode really can accept where the model predicts it. Composition:

```
Halmos:  real bytecode ⊨ psAt invariant   (K ≤ 3)
Kontrol: model         ⊨ psAt invariant   (all K)
────────────────────────────────────────────────
the model is a faithful abstraction where checkable, and the ∀K property
it proves is the property the bytecode demonstrably satisfies
```

Each tool covers the other's blind spot: Halmos brings object fidelity, Kontrol brings
unboundedness. It's the same "prove abstractly, tie to the real machine" shape that the Lean
bytecode refinement later executes in full strength (a validated EVM semantics actually
*running* the unbounded loop) — the bridge is the cheap bounded version of a refinement
proof, and knowing the pattern lets you combine tools instead of waiting for one tool that
does everything.

---

## 3. "Verified on the real bytecode" — which bytecode, exactly?

Not bytes fetched from the chain: the **locally compiled artifact** — what the project's
pinned toolchain produces from the sources under verification. In this engagement that is
solc **0.8.27+commit.40a35a09**, optimizer 200, `evm_version = cancun`: the optimizer/EVM
target are pinned in `foundry.toml`, and the solc *version* is pinned by an **exact**
`pragma solidity 0.8.27` in the test base — a Solidity compilation unit resolves to one
compiler satisfying *all* its pragmas, so the harness's exact pragma fixes the version for
Relay too (its own pragma is a floating `^0.8.20`). The build directory can even hold
artifacts from *several* solc versions at once; "the bytecode" is only a well-defined object
because the toolchain is pinned.

Mechanically: the harness executes `new Relay(config)`, which embeds Relay's **creation
bytecode** inside the harness's own artifact; the symbolic engine runs that constructor and
then symbolically executes the resulting **runtime bytecode** — every opcode of the
hand-written assembly exactly as that solc emitted it.

The link to production is **deterministic compilation**: same source + same compiler + same
settings ⇒ byte-identical output, which is exactly what on-chain source verification (the
metadata hash) certifies for a deployment. One real difference: **immutables** are baked
into runtime code at deployment from constructor arguments — the harnesses deploy with
their own, usually *symbolic*, configs, so the proofs quantify over configurations (a
stronger statement than checking one production instance).

The trust nuance: at the bytecode rung, **the compiler is inside the verified object** — we
check solc's *output*, so a miscompilation of a checked property (within bound) would
surface as a counterexample; no compiler trust is needed. At the Yul-level Lean rung the
profile inverts: the object is the Yul IR, and solc's Yul→bytecode backend *is* trusted —
which is precisely the gap a formally verified Yul→EVM compiler (e.g. powdr's) would close.
Different rungs, opposite compiler-trust profiles — another way stacked layers cover each
other.

---

## 4. What is KEVM?

**KEVM is the Ethereum Virtual Machine written down as an executable mathematical
definition** — a formal semantics of the EVM in the **K framework** (Runtime Verification /
UIUC). It powers the Kontrol rung (R3) of the stack.

**The idea behind K: write the rulebook once, get the tools for free.** Normally an
ecosystem builds an interpreter, a debugger, a symbolic executor and a verifier separately —
each re-encoding the language's rules, each able to drift from the others. K inverts this:
you define the language once, as *rewrite rules* over a structured machine state
("configuration"), and the framework mechanically derives the tools from that one
definition — a concrete interpreter, a symbolic executor, and a deductive program verifier.
One rulebook, many tools, no drift.

**What KEVM concretely is:** every EVM opcode as a rewrite rule over a configuration holding
stack, memory, storage, gas, call frames. `ADD` is literally *"if the instruction is ADD and
the stack top is W0 : W1 : rest, replace with (W0 +ᵂ W1) : rest and charge gas"*. The rule
set **passes the official Ethereum conformance test suites** — the same validation standard
EVMYulLean is held to — so it is an executable, validated definition of the real machine,
not a paper model.

**How verification works on it:** properties are **reachability claims** — "from *any*
state matching P, execution *always* reaches a state matching Q" — discharged by symbolic
rewriting plus SMT (z3) for side conditions. Being a deductive prover, it can do
**induction** (base + step ⟹ all K) — the capability a bounded symbolic executor lacks.
**Kontrol** is the Foundry-native front end: `prove_*` functions like Foundry tests,
compiled with forge, handed to KEVM.

**Role in this engagement (R3):** crossed the induction barrier — the signature-loop weight
invariant proven by k-induction, hence for **all K** signatures, plus random-pointer
monotonicity. Honest limits: the ∀K proof is over a faithful Solidity *model* at fixed voter
counts (full symbolic-N on the real ~1747-line assembly state-explodes — the assembly wall);
hence the Halmos bridge ties the model to the real bytecode, and Lean takes over for ∀N.
Pinned: Kontrol 1.0.248, K 7.1.334, reproducible Docker image.

**Among its neighbors:** Halmos = symbolic executor on real bytecode, bounded, small trusted
base. KEVM/Kontrol = full semantics + derived prover, unbounded induction, but you trust K's
rewriting engine + prover + z3. Lean + EVMYulLean = semantics inside a proof assistant,
manual effort, but every proof re-checked by a few-thousand-line kernel. In one line: **K
gives a validated semantics with heavy automation; Lean gives a validated semantics with a
minimal trusted kernel.**

---

## 5. What is k-induction?

**The trick that turns a bounded checker into an unbounded prover: prove a property holds
for the first k steps, prove that any k consecutive good steps force a good (k+1)-th — and
you've proven it for all steps, forever.**

**Ordinary induction, and why it fails.** To prove an invariant P throughout an execution:
(1) *base* — P at the start; (2) *step* — from **any** state satisfying P, one transition
preserves P. Dominoes: the first falls, each knocks over the next. The catch is "any": the
step must hold even in bizarre states no real execution reaches, so many true properties are
**not inductive** — some unreachable P-state has a successor violating P, the step proof
fails, and the prover reports a *counterexample to induction* ("the property is true but the
induction doesn't go through"). Escapes: **strengthen the invariant** (add facts until it is
preserved — precise, but you must invent them), or **k-induction** (give the step memory).

**The k-induction shape.** Assume P held in the last **k consecutive states**, prove it in
the next: (1) base — P in the first k states (a bounded check, exactly what BMC does);
(2) step — any k consecutive P-satisfying transitions are followed by a P-satisfying state.
Longer memory = stronger hypothesis, so properties failing 1-induction often pass at
k = 2, 3, … without hand-crafted strengthening. Dominoes again: you can't show "each knocks
the next" in isolation, but you can show "if the last k all fell, the momentum topples the
next." Both obligations are *finite* checks an SMT-backed engine can discharge — yet the
conclusion is unbounded, because the step's symbolic pre-state ranges over ALL states
satisfying the hypothesis: iteration one million is just another instance. (Origin: the
bounded-model-checking world — Sheeran–Singh–Stålmarck, 2000.)

**In this engagement (R3, Kontrol).** The signature-loop proof is exactly this shape with a
hand-strengthened invariant `INV(weight, nui) := weight ≤ psAt(nui) ∧ nui ≤ N`:
`prove_base_invariant` (INV at loop entry) + `prove_step_preserves_invariant` (one iteration
from a fully symbolic INV-state preserves INV — the ∀K discharge); acceptance + INV forces
"registered weight exceeds threshold". Two honesty notes (documented in L5): strictly this is
the **k = 1** shape (the invariant was strengthened until 1-inductive — `psAt` monotonicity
is what makes it work); and Kontrol 1.0.248 has no native loop-invariant rule, so base and
step are each machine-checked but their **composition to ∀K is meta-level** — which is
precisely what the Lean rungs close: `loop_inv`/`loop_accL` run the same induction with the
induction principle applied *inside* the checked proof.

**The neighborhood in one line.** BMC/Halmos = base only (exhaustive to a bound, silent
beyond). k-induction/Kontrol = base + symbolic step ⟹ unbounded, *if* you find the invariant
(the creative act). Proof assistant/Lean = the same induction with the glue checked too, and
invariants strengthened with arbitrary mathematics rather than what an SMT solver happens to
swallow.

---

## 6. What is psAt? (the prefix sum at the heart of the proofs)

**`psAt(k)` — "prefix sum at k" — is the total registered weight of the first k voters in
the signing policy:** `psAt(k) = w₀ + … + w₍ₖ₋₁₎`. With weights `[100, 250, 50]`:
`psAt(0)=0, psAt(1)=100, psAt(2)=350, psAt(3)=400 (= the total)`. In the Kontrol harness it
is `_psAt` (an if-chain over scalar weights — the tool can't take symbolic array parameters);
the Halmos bridge restates it verbatim-in-meaning; the Lean development calls it `sumTake`.
One concept, three spellings.

**Why this function is the spine of the accounting argument.** The signature loop enforces
strictly increasing voter indices, so it consumes the voter list left-to-right — like a
prefix — and each voter counts at most once. After advancing past index `nui`, the most
weight the loop could honestly hold is "everyone below `nui` signed" = `psAt(nui)`. That is
the loop invariant: `weight ≤ psAt(nextUnusedIndex)`. Add two trivial prefix-sum facts —
monotonicity (`psAt(k) ≤ psAt(k+1)`) and `psAt(N) = total registered weight` — and the
soundness theorem is a three-link chain at the accept gate:

```
threshold < weight ≤ psAt(nui) ≤ psAt(N)
```

⟹ acceptance implies the total registered weight genuinely exceeds the threshold; read
backwards, insufficient total weight pins the accumulator below the threshold forever (the
contrapositive). The invariant is true *only because* of the strictly-increasing-index
guard — delete it and `weight` can exceed `psAt(nui)` (the harness proves the guard is
load-bearing by doing exactly that and exhibiting the breakage). So `psAt` is the precise
mathematical expression of "no double counting."

**The same object at every rung** — Halmos bridge `_psAt` (bytecode accept ⟹ model prefix
sum exceeds threshold), Kontrol `_psAt` (the ∀K invariant), Lean `sumTake` (∀N ∀K theorem).
It is the shared vocabulary in which all three toolchains state the same truth — the honest
maximum weight after k voters — which is what lets the bounded, the inductive, and the ∀N
proofs corroborate each other rather than proving three unrelated things.

---

## 7. What is a CEX? (counterexamples, and why half the suite celebrates them)

**CEX = counterexample** — a concrete input that makes an asserted property false. When a
solver checks an assertion it tries to satisfy its *negation*; if it succeeds, the satisfying
assignment (the **model**) is the counterexample: not "this might fail" but *"here are exact
values that fail it."* In this suite that means concrete calldata — actual `v/r/s` signature
bytes, indices, weights, a threshold — replayable as an ordinary failing test. A CEX is a bug
report you can execute.

**A CEX means opposite things in the suite's two halves.** On a **proof** check it is the
bad outcome: the property is violated, a verified fact regressed — hard failure. On a
**reachability control** it is the *required* outcome: the control deliberately asserts the
negation of something that should be possible ("acceptance can never happen"), so the solver
must refute it with a witness. If a control ever *passes* — no counterexample exists — the
interesting path became unreachable and every proof guarding it is true only **vacuously**.
Hence the unusual spectacle of CI celebrating counterexamples: "29/29 reachability controls
have validated counterexamples" is a green line; a *missing* CEX is the alarm. (This is the
anti-vacuity discipline — born of the `--loop 2` incident, where a too-small loop bound
silently cut off the accept path and negative properties passed for the wrong reason.)

**Not every failure is a CEX.** The hardened gate credits a counterexample only with a
**validated model** (`is_valid=true`): a solver timeout, stuck path, exception, all-revert
result, or loop-bound truncation is never accepted as a witness. Halmos reports an unsolved
assertion the same way as a refuted one — the gate separates "genuinely refuted with
concrete inputs" from "gave up," and only the former satisfies a control.

**Why Lean has no CEXes.** A proof assistant constructs proofs rather than searching for
refutations — a false theorem simply cannot be proven (you get stuck, not a witness). The
trade: SMT tools hand you automatic counterexamples when you're wrong; Lean hands you
certainty when you're right. The suite uses each where it shines — the bounded rungs carry
the anti-vacuity controls, the Lean rung carries the axiom audit.

---

## Candidate topics (not yet written)

Concepts from the engagement that deserve the same treatment, roughly in dependency order:

- **Formal verification vs testing** — trying inputs vs proving over all inputs.
- **Symbolic execution** — what Halmos actually does with the bytecode; path conditions.
- **Bounded vs unbounded proofs** — loop unrolling, why ∀N needs induction, the R2→R3 barrier.
- **Theorem prover (Lean 4)** — interactive proof vs automatic SMT; what the kernel checks.
- **"Hole-free" and `#print axioms`** — what the axiom audit certifies; `sorry`/`sorryAx`/`native_decide`.
- **Uninterpreted functions & the ecrecover boundary** — what MC-2 assumes, what determinism buys.
- **The fidelity ladder (R0–R5)** — one page, the two barriers (induction, assembly).
- **Validated semantics (A-EVM)** — what "EVMYulLean is validated" means; execution-spec suites vs Yul tests.
- **Fuel and fuel-genericity** — why the interpreter takes a step budget and why proofs quantify over it.
- **Refinement / simulation relation** — how an abstract theorem transfers to the real machine.
- **The two extra axioms** (`zeroes_data`, `toByteArray_size`) — why they exist, why they're harmless, how they discharge.
- **Verified compilation** (powdr's Yul→EVM compiler) — what `compile_correct` would buy: closing the solc-backend trust gap.
