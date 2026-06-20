# Verifying an assembly smart contract by theorem-proving — a layered tutorial

This is a guided, multi-resolution account of how we formally verified a core property of
Flare Network's `Relay.sol` signature-verification loop, all the way down to its execution by a
*validated* model of the Ethereum Virtual Machine. It is written to be read top-to-bottom by anyone
technical, and to remain fully rigorous at the deepest level for a professional mathematician.

It has two purposes:

1. **To teach** — both the specific result and the general method, so that the same approach can be
   reused on other hard verification targets (especially contracts written in inline assembly, where
   the usual automated tools stall).
2. **To be challenged** — every claim is meant to be checkable, by a computer (the Lean proofs) or by a
   capable human (the prose, the caveats, the trust chain). Where a claim rests on an assumption, the
   assumption is named and located, not hidden.

---

## How this document is organized (progressive disclosure)

Concepts are introduced the way understanding is actually built: a true-but-simplified picture first,
then successively higher resolution, with each simplification's caveat flagged where it is made and
discharged later. You can stop at any level and have a coherent, honest mental model; you only pay for
the depth you read.

| Level | File | For whom / what you get |
|-------|------|--------------------------|
| **L1 — The big picture** | [`01-the-big-picture.md`](01-the-big-picture.md) | Anyone. What the contract does, what could go wrong, what "verification" means, and the landscape of tools — by analogy. No formal background needed. |
| **L2 — Strategy & architecture** | [`02-strategy-and-architecture.md`](02-strategy-and-architecture.md) | Why the standard tools hit a wall on this contract, and the two-layer plan that gets around it. Introduces the *fidelity ladder* and *refinement*. |
| **L3 — The mathematics** | [`03-the-mathematics.md`](03-the-mathematics.md) | The actual objects: the abstract algorithm and its soundness theorem; the operational semantics of the EVM as a function; the refinement statement; the induction. Prose-driven but precise. |
| **L4 — The formal detail** | [`04-the-formal-detail.md`](04-the-formal-detail.md) | The Lean 4 development, line by line: every definition, lemma, proof tactic, and the one genuinely clever step (*fuel-genericity*). Fully reproducible. |
| **L5 — Limits, trust & residual** | [`05-limits-trust-and-residual.md`](05-limits-trust-and-residual.md) | The honest boundary. Exactly what is proven, what is assumed, where each claim sits on the fidelity ladder, and what a skeptic must still check. **Read this before citing the result.** |
| **L6 — Reproduce & lessons** | [`06-reproduce-and-lessons.md`](06-reproduce-and-lessons.md) | Exact toolchain and commands to re-check everything; then the transferable lessons for similar work. |

A reader who wants only the result and its honest scope can read L1 then L5. A reader who wants to
*redo* this on another contract should read all six and then L6's checklist.

---

## The one-paragraph contract with the reader

We prove, in Lean 4 with **no `sorry` and no extra axioms** (only Lean's three standard foundational
axioms), two things. **(Phase A)** An abstract model of the signature-counting algorithm is
*threshold-sound* for **all** numbers of voters N and **all** signature streams K: if it accepts (the
tallied weight exceeds the threshold) then the genuinely-registered weight exceeded the threshold, with
no voter counted twice. **(Gap B)** A loop, executed by NethermindEth's *validated* Lean model of the
EVM/Yul semantics, faithfully performs an unbounded accumulation for **all** N, and the same
threshold-soundness step transfers onto that real-execution model. The bridge that we *do not* prove
but explicitly *assume* — and validate by other means — is the **data layer**: that the byte each loop
iteration reads from memory is the registered weight it is meant to be, and that the on-chain weights
are small enough that the 256-bit accumulator does not wrap. These residual assumptions are stated
precisely in [L5](05-limits-trust-and-residual.md). Everything else is machine-checked.

---

## Where the machine-checkable artifacts live

```
test-forge/fv/lean/
├── RelaySigLoop.lean              # Phase A — the abstract ∀N∀K soundness proof (Lean core only)
└── gapB/
    ├── GapB_close.lean            # Gap B — THE capstone: bytecode-level ∀N refinement + transfer
    ├── PROGRESS.md                # the resumable engineering log (status + API facts + gotchas)
    └── GapB_*.lean                # the development bricks, each self-contained and independently checkable
```

The EVM/Yul semantics we build on is the external, validated project **EVMYulLean**
(NethermindEth). [L6](06-reproduce-and-lessons.md) gives the exact commands to fetch it, build it, and
re-verify our files against it, including how to print the axiom list of each theorem.

---

## A note on honesty of scope

Formal verification earns its authority only by being precise about its own boundary. Throughout, a
claim of the form "we proved X" means a Lean theorem whose statement *is* X and whose `#print axioms`
output contains only `[propext, Classical.choice, Quot.sound]`. A claim of the form "we assume Y" means
Y is a hypothesis we did not discharge in Lean and instead justified by other evidence (named in L5).
We are deliberately stricter about this distinction than the result strictly needs, because the second
purpose of this document is to be a template others can trust.
