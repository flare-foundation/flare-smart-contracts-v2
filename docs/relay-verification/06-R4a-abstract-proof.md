# L6 — R4a: the abstract proof (Lean)

> **Evidence note.** This chapter describes theorem statements and methodology. Whether the checked-in files
> and pinned toolchain currently pass is recorded only in [`CURRENT-STATUS.md`](CURRENT-STATUS.md).

> **What you get from this level.** The rung that fully defeats the induction barrier: a **∀N ∀K**,
> machine-checked, hole-free proof that the signature-counting algorithm is threshold-sound. This is the
> overview — the objects, the key idea, the status. The objects in math notation are
> [L8](08-the-mathematics.md) §A; the verbatim Lean is [L9](09-the-formal-detail.md) §A.

---

## 6.1 What the abstract proof proves, and why it sits above Kontrol

Kontrol (R3) reached **∀K** at fixed voter counts N∈{3,5} on a Solidity model, with the final base+step
composition done at the meta level. The abstract proof removes both limitations: it proves the soundness for **all N
and all K at once**, as an abstract algorithm, with the induction **internal and machine-checked**, and no
`sorry`.

**Artifact:** [`test-forge/fv/lean/RelaySigLoop.lean`](../../test-forge/fv/lean/RelaySigLoop.lean) (Lean 4, core only — no mathlib, no EVM).

**The theorem (`threshold_sound`).** For every list of voter weights `w` (so every voter count
`N = |w|`), every signature stream `idxs` (so every length `K`) that obeys the strictly-increasing-in-range
discipline, and every threshold `thr`:

> if the accounting loop accepts (final tallied weight > `thr`), then the **total registered policy-slot weight**
> `sumTake(w, N)` > `thr`.

In words: **acceptance required enough policy-slot weight, with no slot index
reused** — for any number of slots and signatures. Calling those slots distinct
voters requires the separate MC-3 premise that policy admission supplies unique
voter addresses; the theorem does not establish that premise.

---

## 6.2 The objects (informal)

- **`sumTake(w, k)`** — the prefix sum of the first `k` voter weights (the on-chain [`psAt(k)`](CONCEPTS.md#6-what-is-psat-the-prefix-sum-at-the-heart-of-the-proofs)).
- **`loop`** — the accounting recursion: each signature adds the weight at its index and advances the
  "next unused index" boundary past it.
- **`ValidRun`** — the inductive predicate encoding the anti-double-count discipline: signature indices are
  strictly increasing and in range. Because each new index must be ≥ the current boundary (set to
  `previous+1`), **no index is used twice** — this is _forced by the predicate_, not assumed of the input.

These mirror the on-chain accounting exactly; the cryptography is abstracted (a "signature" is just the
index it carries — modeling contract A1/A2).

## 6.3 The key idea — one invariant

The whole proof rests on a single **invariant** maintained by the loop for _any_ stream and _any_ weights:

> `weight ≤ sumTake(w, nextUnusedIndex)` and `nextUnusedIndex ≤ N`.

i.e. _the tally never runs ahead of the prefix sum at the current boundary, and the boundary never passes
the last voter._ Threshold soundness is then immediate: at acceptance, `thr < weight ≤ sumTake(w, nui) ≤
sumTake(w, N)`. The invariant is preserved across one step using prefix-sum monotonicity (`nui ≤ idx`
because indices increase) plus the one-step recurrence `sumTake(w, idx+1) = sumTake(w, idx) + w[idx]`. The
contrapositive — _insufficient total weight ⟹ can never accept_ — follows in one line. (Full proof:
[L8 §A](08-the-mathematics.md), [L9 §A](09-the-formal-detail.md).)

**The file, itemized.** [`RelaySigLoop.lean`](../../test-forge/fv/lean/RelaySigLoop.lean) is nine public
items — two definitions, one inductive predicate, six theorems:

| Result                              | Kind                       | In plain words                                                                                                                                 |
| ----------------------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `sumTake`                           | def                        | the prefix sum of the first `k` voter weights (the on-chain `psAt(k)`)                                                                         |
| `sumTake_succ`                      | theorem                    | the one-step recurrence: boundary `idx+1` adds exactly `w[idx]`                                                                                |
| `sumTake_le_succ`                   | theorem                    | one more boundary never decreases the prefix sum                                                                                               |
| `sumTake_mono`                      | theorem                    | the prefix sum is monotone in the boundary                                                                                                     |
| `loop`                              | def                        | the accounting loop: add the signature's weight, advance the boundary past its index                                                           |
| `ValidRun`                          | inductive predicate        | the index discipline: strictly increasing, in range — double-counting impossible by construction                                               |
| `loop_inv`                          | theorem                    | the §6.3 invariant is preserved over any whole run, for any stream and any weights                                                             |
| **`threshold_sound`**               | **theorem — the capstone** | **accept ⟹ total registered policy-slot weight exceeds the threshold, with no repeated index, ∀N ∀K; unique addresses are a separate premise** |
| `insufficient_weight_cannot_accept` | theorem                    | the contrapositive: total registered weight ≤ threshold ⟹ no signature stream ever accepts                                                     |

---

## 6.4 Status and axiom audit

- **Hole-free.** `#print axioms threshold_sound` = `[propext, Quot.sound]` — Lean's standard foundational
  axioms only; **no `sorry`, no `sorryAx`, no extra axiom**. (the abstract proof doesn't even need `Classical.choice`.)
- Checks in seconds with Lean 4 core (no mathlib, no EVM semantics).

This is the "definition of done" the engagement uses for a Lean result (see [L9 §F](09-the-formal-detail.md)).

---

## 6.5 Reproduce

```bash
# Lean 4 (core). See L11 for the toolchain.
lean test-forge/fv/lean/RelaySigLoop.lean
# expect: no errors; #print axioms threshold_sound = [propext, Quot.sound]
```

---

## 6.6 What the abstract proof establishes and does not

- **Establishes:** the _algorithm_ is threshold-sound for **all N and all K**, machine-checked, no holes.
  This is the unbounded guarantee that no bounded tool (Halmos) and no fixed-N tool (Kontrol) can give.
- **Does not:** say anything about the **EVM** or the deployed bytecode. It reasons about an abstract
  recursion over lists, not about [`Relay.sol`](../../contracts/protocol/implementation/Relay.sol)'s compiled loop. Bridging "the algorithm is sound" to "a
  validated model of the real machine runs this algorithm" is exactly the job of **the bytecode refinement (R4b)**.

**Next:** [L7 — R4b: the bytecode refinement (the bytecode refinement)](07-R4b-bytecode-refinement.md), which lifts this
result onto a validated EVM semantics for all N.
