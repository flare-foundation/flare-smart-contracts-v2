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
8. [Formal verification vs testing](#8-formal-verification-vs-testing)
9. [Symbolic execution](#9-symbolic-execution)
10. [Bounded vs unbounded proofs](#10-bounded-vs-unbounded-proofs)
11. [The fidelity ladder (R0-R5)](#11-the-fidelity-ladder-r0-r5)
12. [Theorem prover (Lean 4)](#12-theorem-prover-lean-4)
13. ["Hole-free" and `#print axioms`](#13-hole-free-and-print-axioms)
14. [The two extra axioms (`zeroes_data`, `toByteArray_size`)](#14-the-two-extra-axioms-zeroes_data-tobytearray_size)
15. [Fuel and fuel-genericity](#15-fuel-and-fuel-genericity)
16. [Refinement and the simulation relation](#16-refinement-and-the-simulation-relation)
17. [Uninterpreted functions and the ecrecover boundary](#17-uninterpreted-functions-and-the-ecrecover-boundary)
18. [Validated semantics (A-EVM)](#18-validated-semantics-a-evm)
19. [Verified compilation](#19-verified-compilation)

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

**References:** [SMT-LIB standard](https://smt-lib.org/); de Moura & Bjørner, *Z3: An Efficient SMT Solver*, TACAS 2008 — [Springer](https://link.springer.com/chapter/10.1007/978-3-540-78800-3_24), [z3 source](https://github.com/Z3Prover/z3).

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

**References:** Solidity docs — [metadata / deterministic builds](https://docs.soliditylang.org/en/latest/metadata.html) and [pragma / compiler version](https://docs.soliditylang.org/en/latest/layout-of-source-files.html); the compiler-trust profile contrast is developed in [verified compilation](#19-verified-compilation).

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

**References:** Hildenbrandt et al., *KEVM: A Complete Formal Semantics of the EVM*, CSF 2018 — [paper](https://fsl.cs.illinois.edu/publications/hildenbrandt-saxena-zhu-rodrigues-daian-guth-moore-zhang-park-rosu-2018-csf.html); the executable semantics ([Jello Paper](https://jellopaper.org/)); the [K framework](https://kframework.org/); Kontrol ([Runtime Verification](https://docs.runtimeverification.com/kontrol)).

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

**References:** Sheeran, Singh, Stålmarck, *Checking Safety Properties Using Induction and a SAT-Solver*, FMCAD 2000 — [Springer](https://doi.org/10.1007/3-540-40922-X_8); the not-inductive / counterexample-to-induction (CTI) idea — Bradley, *IC3*, VMCAI 2011 — [Springer](https://doi.org/10.1007/978-3-642-18275-4_7).

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

**References:** the assert-the-negation reduction (a satisfying model = a counterexample) — de Moura & Bjørner, *Satisfiability Modulo Theories: Introduction and Applications*, CACM 2011 — [ACM](https://dl.acm.org/doi/10.1145/1995376.1995394); the anti-vacuity discipline is enforced by [`verify_fv.py`](../../test-forge/fv/verify_fv.py).

---

## 8. Formal verification vs testing

**Testing asks "does it work on these inputs?"; formal verification asks "does it work on *all* inputs?" — and proves the answer.** A unit test runs the code on one concrete scenario; a fuzzer runs thousands of random ones. Both *sample* the input space, so — in Dijkstra's famous line — "program testing can be used to show the presence of bugs, but never to show their absence." Formal verification instead makes a mathematical statement about *every* input at once and discharges it with a proof, so a pass means "no input breaks this, anywhere," not "no input we tried broke this."

The catch is scope: a proof is only about what you actually stated, under the assumptions you actually made. "Verified" is never unconditional — it is "*this* property, under *these* assumptions, for all inputs in *this* range." That is why this engagement pairs every result with an explicit scope (input coverage × object fidelity, the [fidelity ladder](#11-the-fidelity-ladder-r0-r5)) and an assumption register (L10): the value is in the *precision* of the claim, not a blanket "it's correct."

The two are complementary, not rivals. The 59 Foundry tests (R0/R1) pin concrete behaviours and guard against regressions cheaply; the FV suites (R2–R4) prove the security-critical accounting over all inputs. Tests catch the mistake you can imagine; verification catches the one you can't — and they reinforce each other here, since the same `Relay.t.sol` harness that runs as tests is the substrate Halmos executes symbolically.

**In one line:** testing explores, verification proves — a good stack uses testing for breadth of behaviours and verification for depth of guarantee on the parts that must never break.

**References:** Dijkstra, *Notes on Structured Programming* (EWD249, ~1970) — [EWD archive](https://www.cs.utexas.edu/~EWD/transcriptions/EWD02xx/EWD249/EWD249.html).

---

## 9. Symbolic execution

**Run the program on *unknowns* instead of values, and you explore all executions at once.** Concrete execution feeds `v = 27, r = 0x1c…` and follows one path. Symbolic execution feeds *symbols* (`v`, `r` as logical variables) and, at every branch that depends on them, forks — exploring both sides and accumulating a **path condition**, the constraints that must hold to reach that branch. Each leaf is one path with its condition; an [SMT solver](#1-what-is-an-smt-solver) then asks, per path, "is there an input satisfying this condition that also violates the assertion?" (a [counterexample](#7-what-is-a-cex-counterexamples-and-why-half-the-suite-celebrates-them)).

That is exactly what **Halmos** (a16z; Python, z3 by default) does to `relay()`: the `check_` function's parameters become symbols and it walks the compiled EVM opcode by opcode, forking at each symbolic branch. Because it *executes the real bytecode* rather than a reconstruction, it sees the hand-written assembly exactly as deployed — no storage model to break (contrast the Certora wall, C-1).

The fundamental limit is **path explosion**: a loop over a symbolic condition forks unboundedly, so symbolic executors **unroll loops to a fixed bound** ([bounded vs unbounded](#10-bounded-vs-unbounded-proofs)). Hence Halmos results are "all inputs up to K≤3 signatures," and the `--loop` bound is load-bearing — set too low, the accepting iteration is silently truncated and proofs pass vacuously (the anti-vacuity controls are the tripwire).

**References:** King, *Symbolic Execution and Program Testing*, CACM 1976 (the canonical reference; the technique was developed concurrently by several groups) — [ACM](https://dl.acm.org/doi/10.1145/360248.360252); Cadar, Dunbar, Engler, *KLEE*, OSDI 2008 — [USENIX](https://www.usenix.org/conference/osdi-08/klee-unassisted-and-automatic-generation-high-coverage-tests-complex); Cadar & Sen, *Symbolic Execution … Three Decades Later*, CACM 2013 (path explosion) — [ACM](https://dl.acm.org/doi/10.1145/2408776.2408795); Halmos — [github.com/a16z/halmos](https://github.com/a16z/halmos).

---

## 10. Bounded vs unbounded proofs

**"For all inputs up to size K" and "for all inputs, any size" are different theorems — and the gap between them is a barrier no solver crosses on its own.** A bounded proof unrolls every loop a fixed number of times and proves the property for that shape; it is exhaustive *within the bound* (all inputs, not samples) but silent beyond it — this is **bounded model checking** and what Halmos does. An unbounded proof holds for every size, which requires an **inductive argument** ("if it holds after k signatures, it holds after k+1") — and induction is precisely what an SMT solver cannot invent unaided.

This is the engagement's **induction barrier (R2 → R3)**. Below it: Halmos, exhaustive to K≤3 signatures / N≤5 voters on the real bytecode. Crossing it needs a tool that does induction — Kontrol via [k-induction](#5-what-is-k-induction) (∀K on a model), and Lean via ordinary mathematical induction (∀N ∀K, `RelaySigLoop.threshold_sound`).

Why keep the bounded proofs once the unbounded ones exist? Fidelity. The unbounded proofs run on a *model* or an *abstract algorithm*; the bounded ones run on the *deployed bytecode*. Each covers the other's weakness — the point of the [two-tools bridge](#2-why-two-symbolic-tools-the-bounded-model-fidelity-bridge): bounded-real-bytecode + unbounded-model + a bridge tying them = confidence neither delivers alone.

**In one line:** bounded = "checked to the horizon"; unbounded = "checked past every horizon" — and getting past the horizon costs an induction the solver can't supply.

**References:** Biere, Cimatti, Clarke, Zhu, *Symbolic Model Checking without BDDs*, TACAS 1999 (BMC) — [Springer](https://link.springer.com/chapter/10.1007/3-540-49059-0_14); and the [k-induction](#5-what-is-k-induction) entry for crossing to unbounded.

---

## 11. The fidelity ladder (R0-R5)

**One picture organizing the whole engagement: rungs of increasing confidence along *two* axes at once — what you reason about, and over how many inputs.**

| Rung | Object | Coverage | Tool |
|---|---|---|---|
| R0 | deployed bytecode | a few concrete inputs | Foundry tests |
| R1 | deployed bytecode | random inputs | Foundry fuzzing |
| R2 | deployed bytecode | all inputs to a bound | Halmos |
| R3 | a *model* | all inputs, unbounded | Kontrol/KEVM, Certora |
| R4 | a *validated EVM semantics* running the loop | all inputs, unbounded | Lean + EVMYulLean |
| R5 | the whole `relay()` on the validated semantics | all inputs, unbounded | Lean + EVMYulLean |

Higher is not strictly "better" — each rung trades one axis for the other. R2 has perfect object fidelity (real bytecode) but bounded coverage; R3 has unbounded coverage on a reconstructed model. The craft is putting each property on the rung matching its risk, and letting rungs cover each other's gaps.

Two **barriers** separate the rungs, and naming them is half the value: the **induction barrier (R2→R3)** — bounded → unbounded, needs [induction](#10-bounded-vs-unbounded-proofs); and the **assembly barrier (R3→R4)** — a model reconstructed from Solidity structure can silently diverge from hand-written assembly, whereas a [validated EVM semantics](#18-validated-semantics-a-evm) cannot. The engagement's convergent finding is that two independent unbounded tools (Kontrol at symbolic-N, Certora at storage) hit the *same* assembly barrier — the signal to climb to R4.

Above R5 sits an explicit **ceiling**: byte-perfect end-to-end verification *including the cryptography and exact memory* — permanently out of reach (the crypto is [MC-2](#17-uninterpreted-functions-and-the-ecrecover-boundary), irreducible), and named as the residual rather than pretended away.

**References:** the ladder is this engagement's own framing — see [L2 §2.2](02-strategy-and-the-fidelity-ladder.md); it is a two-axis refinement of the classic fidelity/assurance-level idea.

---

## 12. Theorem prover (Lean 4)

**Where an SMT solver *searches* for a proof automatically, a theorem prover *checks* a proof you construct — and checks it with a tiny, trustworthy core.** In Lean 4 you build a proof term (by hand, or via tactics that assemble it) and Lean's **kernel** — a few thousand lines — verifies it type-checks. Nothing is believed unless the kernel accepts it. That is a different trust model from the SMT tools: Halmos/Kontrol trust a large solver + executor; Lean trusts only its kernel (plus the semantics you state the theorem against).

The trade is automation vs. reach. SMT is push-button but bounded and undecidable-in-general (it can time out or say "unknown"); Lean needs a human to guide the proof but can express *anything* — arbitrary induction, quantifiers, custom mathematics — with no bound. That is why the unbounded ∀N ∀K accounting soundness lives in Lean (`RelaySigLoop.threshold_sound`), and why the bytecode refinement (R4b) runs the deployed loop against **EVMYulLean**, a Lean formalization of the EVM, to get an unbounded guarantee on a [validated](#18-validated-semantics-a-evm) machine model.

Two ideas make Lean results auditable and are their own entries: [hole-free / `#print axioms`](#13-hole-free-and-print-axioms) (what the proof rests on) and [refinement](#16-refinement-and-the-simulation-relation) (how an abstract theorem transfers onto the real machine).

**In one line:** an SMT solver answers "is there a proof?" by searching; a theorem prover answers "is *this* a proof?" by checking — and the smaller the checker, the more the "yes" is worth.

**References:** de Moura & Ullrich, *The Lean 4 Theorem Prover and Programming Language*, CADE-28 2021 — [PDF](https://leanprover.github.io/papers/lean4.pdf); *Theorem Proving in Lean 4* — [book](https://leanprover.github.io/theorem_proving_in_lean4/).

---

## 13. "Hole-free" and `#print axioms`

**A machine-checked proof can still secretly rest on a gap or an unproven assumption — Lean's `#print axioms` is the X-ray that shows exactly what it rests on, and "hole-free" is the clean bill of health.** Every Lean theorem depends on some set of axioms; `#print axioms my_theorem` lists them (transitively, across every lemma it uses). The engagement's bar: that list must be a subset of Lean's three standard foundational axioms —

`propext` (propositional extensionality), `Classical.choice` (choice), `Quot.sound` (soundness of quotients)

— which are domain-neutral (accepting them is accepting ordinary classical mathematics; mathlib rests on the same three), **with nothing else**. In particular:

- **No `sorryAx`.** The decisive one: `sorryAx` appears if *any* proof in the dependency tree contains a `sorry` (a hole) or otherwise failed. Its absence certifies the proof is *complete* — no gaps, no admitted lemmas.
- **No `Lean.ofReduceBool`.** This is the axiom `native_decide` introduces — it trusts the Lean *compiler* to evaluate a decision procedure in native code, enlarging the trusted base beyond the kernel (external checkers can't re-verify it). Deliberately avoided; the proofs reduce inside the kernel. (The exact name of the compiler-trusting axiom varies by tactic/Lean version; `native_decide` → `Lean.ofReduceBool` is the case that matters here.)

"Hole-free" = passes exactly this audit. It is not a vibe — it is a mechanical check, enforced in CI by `verify_lean.py`, which fails on any `error`, any forbidden token, or any `#print axioms` line outside the allowlist. So a proof that still *builds* but quietly acquired a `sorry` fails the gate, independent of whether Lake reports success. (Two results carry two *extra* constants beyond the standard three — see [the two extra axioms](#14-the-two-extra-axioms-zeroes_data-tobytearray_size); those are documented, minimal, upstream-dischargeable specs, not holes.)

**References:** Lean reference, *Validating a Lean Proof* (axioms, `#print axioms`, `sorryAx`, native-evaluation trust) — [lean-lang.org](https://lean-lang.org/doc/reference/latest/ValidatingProofs/); *Theorem Proving in Lean 4* — Axioms and Computation — [book](https://leanprover.github.io/theorem_proving_in_lean4/axioms_and_computation.html).

---

## 14. The two extra axioms (`zeroes_data`, `toByteArray_size`)

**Two results in the Lean development list one or two constants beyond the standard three — and the honest thing is to say exactly what they are, why they're harmless, and how they'd be removed.** They are *not* `sorry`s and *not* domain assumptions about Relay; they are minimal specifications of two low-level facts in the upstream EVMYulLean library:

- **`zeroes_data`** — the spec of an `opaque` FFI symbol (`memset_zero`): freshly-allocated memory reads back as zeroes. Opaque because it is implemented in native code the kernel can't unfold; the axiom states the one property of it the proofs need.
- **`toByteArray_size`** — a `private` upstream bound: serializing a 256-bit word yields exactly 32 bytes.

Both are **true, both verified, both reducible to theorems** by a one-line upstream change (un-`private`-ing a lemma / turning the `opaque` into a `def`) — the exact patches and the verified discharge proofs are archived in [`AXIOM_DISCHARGE.md`](../../test-forge/fv/lean/bytecode-refinement/AXIOM_DISCHARGE.md), so they are reproducible, not anecdotal. They are also *scoped*: they appear only on results that use the memory-*write* round-trip (`mstore`/`mload`), and the accounting capstones (`relay_loop_sound`, the threshold-soundness results) do not carry them at all.

Why keep them rather than patch upstream? Pinning. The proofs check against a fixed EVMYulLean commit; carrying two documented, discharge-ready specs is more honest and more stable than maintaining a local fork. If NethermindEth merges the patches, the list collapses to the pure three. This is the whole engagement's philosophy in miniature: name the residual precisely, show it's dischargeable, don't hide it inside a `native_decide`.

**References:** the discharge patches + verified proofs — [`AXIOM_DISCHARGE.md`](../../test-forge/fv/lean/bytecode-refinement/AXIOM_DISCHARGE.md); the upstream semantics — [NethermindEth/EVMYulLean](https://github.com/NethermindEth/EVMYulLean); and the [hole-free](#13-hole-free-and-print-axioms) entry for the bar these sit against.

---

## 15. Fuel and fuel-genericity

**To define an EVM interpreter as a *total* mathematical function, you give it a "fuel" budget — a maximum number of steps — so it always terminates; the trick is then proving your theorem for *every* budget at once.** A real interpreter loops until the program halts, but an unbounded loop is not a definition a proof assistant will accept as total. The standard fix (also called a *clock* or *step counter*): pass a natural-number `fuel` that decrements each step; at `fuel = 0` the interpreter returns `OutOfFuel`. Now it is total by structural recursion on `fuel`, hence definable.

The hazard is that a theorem proved at one specific fuel value says nothing about others — it could be an artefact of running out of budget at just the right moment. **Fuel-genericity** is the discipline of stating and proving effects for a *symbolic* fuel (`fuel + 130`, for arbitrary `fuel`), so the result holds for every sufficiently-large budget — i.e., for any real execution that actually completes. The literal loop-body model (`body_effL` and up in `RelayBodyEff.lean`) is proved fuel-generically: each statement's effect is established at symbolic fuel and the pieces compose without ever pinning a concrete budget.

Two clarifications. "Fuel" here is a *definitional* device, not the EVM's gas — the proofs are about functional behaviour, not gas accounting. And fuel is related to but *distinct* from **step-indexing** (a semantic technique for logical relations over recursive types, due to Appel & McAllester); both use a decreasing nat index for well-foundedness, but they are different constructs.

**References:** Owens, Myreen, Kumar, Tan, *Functional Big-Step Semantics*, ESOP 2016 (the clock/fuel total-interpreter idiom) — [PDF](https://www.cse.chalmers.se/~myreen/esop16.pdf); Appel & McAllester, *An Indexed Model of Recursive Types*, ACM TOPLAS 2001 (step-indexing, the distinct relative) — [ACM](https://doi.org/10.1145/504709.504712).

---

## 16. Refinement and the simulation relation

**Rather than prove the hard property directly on the messy real machine, prove it once on a clean abstract model, prove the machine *refines* the model, and compose — the property transfers for free.** As a diagram:

```
abstract model   ⊨  PROPERTY          (the math: induction is easy here)
concrete system  ⊑  abstract model     (refinement: the machine matches the model)
─────────────────────────────────────
concrete system  ⊨  PROPERTY           (by composition)
```

The `⊑` is witnessed by a **simulation relation** `R` tying concrete states to abstract ones: whenever the concrete machine steps, the abstract model can take a matching step preserving `R`, so the abstract trace mirrors the real one — and any property of the abstract trace holds of the real one.

This is the backbone of R4. The abstract proof (`RelaySigLoop.threshold_sound`) establishes "accept ⟹ enough distinct weight" on a clean algorithm where [induction](#10-bounded-vs-unbounded-proofs) is trivial; the bytecode refinement then shows EVMYulLean's execution of the deployed loop refines that algorithm (the relation ties the loop's memory/locals to the abstract `(weight, nextUnusedIndex, …)`) and transfers the theorem onto the validated machine. Splitting the work this way is what keeps each half tractable: the two enemies (unboundedness and the real machine) are fought *once each*, separately, instead of both at once. The bounded [bridge](#2-why-two-symbolic-tools-the-bounded-model-fidelity-bridge) (`RelayModelBridgeFV`) is the cheap cousin — it checks the relation's key invariant (`psAt`) on the real bytecode at K≤3 without a full simulation argument.

**References:** Klein et al., *seL4: Formal Verification of an OS Kernel*, SOSP 2009 (the landmark refinement proof) — [ACM](https://doi.org/10.1145/1629575.1629596); simulation is due to Milner and coinductive bisimulation to Park — Sangiorgi, *On the Origins of Bisimulation and Coinduction*, TOPLAS 2009 — [PDF](https://www.cs.unibo.it/~sangio/DOC_public/history_bis_coind.pdf).

---

## 17. Uninterpreted functions and the ecrecover boundary

**Some things can't be proven inside an EVM proof — the cryptography chief among them — so you model them as a black box that is *consistent* but otherwise unknown: an *uninterpreted function*.** In SMT this is the theory **EUF** (equality with uninterpreted functions): a function symbol with no definition, constrained *only* by congruence — `x = y ⟹ f(x) = f(y)`. That is exactly **determinism** (same inputs ⟹ same output) and it is the *sole* guarantee. A property proved with `f` left uninterpreted holds *whatever `f` actually computes*, because the prover is free to pick any behaviour consistent with congruence. (The flip side: it is an over-approximation, so it can raise *spurious* counterexamples the real function wouldn't — which is why tools sometimes add axioms, see below.)

`ecrecover` (the ECDSA-recovery precompile at `0x01`) is the canonical case. No tool here — Halmos, Kontrol, Lean — proves elliptic-curve cryptography; all model `ecrecover` as uninterpreted. That draws a precise line between what is *proven* (the on-chain **accounting** — acceptance requires enough distinct authorized weight, no double-count, *for every possible set of recovered signers*) and what is *assumed* (that a valid signature identifies its signer — non-forgeability). Those assumptions are the ledger's **MC-2**, and they are irreducible: proving them would be proving the cryptography, circular at the EVM level. `keccak256` is modeled the same way — but note a subtlety the ledger's shorthand glosses: "uninterpreted" alone gives only determinism; *injectivity/no-collision* (MC-1) is an **added** modelling axiom, and it is an idealization — real Keccak-256 is collision-*resistant* (collisions exist but are infeasible to find), not literally injective.

There is a second, subtler boundary — **OP-1**: the *operational ABI* of the call, not the crypto. On a bad signature the `ecrecover` `staticcall` returns *success* with **empty** return data and a **stale** output buffer (the `CALL` opcode pushes `1` regardless), so the contract must check `returndatasize() == 32` and `recovered != 0`. That is discharged separately by real-EVM regression + symbolic tests, not assumed.

**In one line:** uninterpreted = "I promise nothing about what it computes, only that it's a function" — precisely strong enough to verify the logic *around* the cryptography while honestly assuming the cryptography itself.

**References:** EUF / congruence — [SMT theories notes (CMU 15-414)](https://www.cs.cmu.edu/~15414/s24/lectures/17-smt-theories.pdf); modelling crypto as uninterpreted/assumed — [Certora hashing model](https://docs.certora.com/en/latest/docs/prover/approx/hashing.html); the `ecrecover` ABI — Ethereum Yellow Paper App. E — [paper](https://ethereum.github.io/yellowpaper/paper.pdf) and [execution-specs `ecrecover.py`](https://github.com/ethereum/execution-specs/blob/master/src/ethereum/forks/prague/vm/precompiled_contracts/ecrecover.py); the same ABI is cross-checked against the actual client Flare runs in [L13 §13.8](13-residual-weaknesses.md#138-appendix--op-1-cross-checked-against-the-deployed-client-ecrecover-precompile).

---

## 18. Validated semantics (A-EVM)

**An R4 proof is only as trustworthy as the EVM model it runs against — so the model itself must be *validated*, and "validated" has a precise, honest meaning here.** The proofs use **EVMYulLean**, NethermindEth's formalization of the EVM (and Yul) in Lean 4. The assumption "EVMYulLean *is* the EVM" is ledger item **A-EVM** — permanent and irreducible (you cannot prove a model equals the real thing; you can only cross-check it), but *hardenable* by validation.

The honest nuance is that A-EVM has **two halves of different strength**:

- The **opcode / memory layer** the proofs lean on (the shared `step` dispatch, `MachineState`) sits on the path EVMYulLean validates by running the **standard `ethereum/tests` EVM conformance suite** (GeneralStateTests, which now include EEST-generated fixtures) — the same family of cross-client tests every production client is held to. Strong evidence.
- The **Yul control-flow layer** (`Yul.exec` / `loop` / fuel) that actually drives the R4b proofs is Yul-specific and validated separately, by Yul semantic tests rather than the execution-conformance suite. Weaker evidence — and named as such rather than folded into the stronger claim.

"Validated" also means "validated *at the pinned commit*." Two directions harden A-EVM further: cross-validating the Yul layer against an independent Lean Yul semantics (e.g. powdr's — see [verified compilation](#19-verified-compilation)), and upstreaming the two [axiom patches](#14-the-two-extra-axioms-zeroes_data-tobytearray_size).

**In one line:** A-EVM is where the proof meets reality — unprovable by nature, but validated against the same conformance tests as real clients, with the weaker Yul half flagged, not hidden.

**References:** [NethermindEth/EVMYulLean](https://github.com/NethermindEth/EVMYulLean) (formal EVM+Yul in Lean 4; conformance harness runs `ethereum/tests`); the standard suites — [ethereum/tests](https://github.com/ethereum/tests) and the EEST framework, now under [ethereum/execution-specs](https://github.com/ethereum/execution-specs) (the `execution-spec-tests` repo was archived and migrated in 2025).

---

## 19. Verified compilation

**The deployed contract is *bytecode*, but the R4 Lean proofs reason about *Yul* — and the step from Yul to bytecode is done by solc, which nobody has verified. A verified compiler would close exactly that gap.** The classic precedent is **CompCert** (Xavier Leroy, INRIA): a formally verified C compiler, proved in Coq, carrying a machine-checked *semantic-preservation* theorem (the generated assembly behaves as the source's semantics prescribe, for programs with defined behaviour). "Verified compilation" means a compiler shipping such a theorem.

Where the gap sits in *this* stack — and the trust profiles are *opposite* per rung:

- **R2 (Halmos)** runs the real bytecode, so solc is *inside* the verified object: a miscompilation of a checked property would surface as a counterexample. No compiler trust needed — but bounded.
- **R4b (Lean)** models the Yul IR and *trusts* solc's Yul→bytecode backend to emit faithful bytes. Unbounded — but the backend is an unverified step.

A verified Yul→EVM compiler is the missing bridge for R4b: restate the Yul-level results against the verified compiler's input semantics, push them through its correctness theorem, and the unbounded guarantee lands on the *bytecode* with the compiler no longer trusted. **powdr Labs** published exactly such a compiler in Lean 4 (2026) with a `compile_correct` theorem (a gas-conditioned forward-simulation / semantic-preservation statement). It is not usable here yet — its Yul coverage doesn't include the assembly features `relay()` uses (mstore/calldatacopy/staticcall/keccak256/objects), there is no optimizer, and there's a Lean-toolchain gap — so it is tracked as a watch item. Tellingly, even a peer verified-contract compiler, **Verity** (LFG Labs, Lean 4), currently punts this same Yul→bytecode step to unverified, pinned solc — powdr is targeting precisely the gap nobody else closes.

**In one line:** we prove things about Yul and trust solc to compile it faithfully; a verified compiler would let us *prove* the compilation too, retiring the last silent step between the theorem and the deployed bytes.

**References:** Leroy, *Formal verification of a realistic compiler* (CompCert), CACM 2009 — [PDF](https://xavierleroy.org/publi/compcert-CACM.pdf); powdr's verified Yul→EVM compiler — [blog](https://www.powdr.org/blog/yul-compiler), [powdr-labs/yul-compiler](https://github.com/powdr-labs/yul-compiler); Verity — [veritylang.com](https://veritylang.com/), [TRUST_ASSUMPTIONS.md](https://github.com/lfglabs-dev/verity/blob/main/TRUST_ASSUMPTIONS.md).

---

## Notes

All seeded concepts are now drafted (entries 1–19). When adding a new one: append it at the bottom, add its line to the index, link it from its first load-bearing mention in the ladder docs (see the "Linked from" note at the top), keep the cross-references between entries current, and — where a claim is externally checkable — cite a primary source and verify the prose against it.
