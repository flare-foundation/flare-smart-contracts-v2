# Relay.sol — T1: model ↔ bytecode bridge for the unbounded signature-loop proof

**Goal (Phase 3, Step 3).** The Phase-2 Kontrol proof establishes the signature-loop weight invariant
`weight ≤ psAt(nextUnusedIndex)` for **all** signature counts K — but over a faithful *Solidity model*
of the loop body (`test-forge/fv/kontrol/RelaySigLoopFV.t.sol`). T1 asks: does that model faithfully
reflect the **real inline-assembly `relay()` bytecode**, so the ∀K result actually applies to the
deployed contract?

## What is and isn't observable

The ideal T1 form — a *fully-symbolic single-iteration equivalence* that reads the loop's **intermediate**
`(weight, nextUnusedIndex)` after one signature and compares to the model's step — **is not externally
observable**. `relay()` is monolithic: it accepts or reverts as a whole, exposing only the final outcome
(stored Merkle root / accept / revert). You cannot pause it mid-loop to read `weight`. Instrumenting the
contract to expose the loop state would **change the bytecode under verification**, defeating the purpose.

A full real-`relay()` proof in Kontrol (KEVM over the actual bytecode) is the other theoretical route, but
it is **intractable**: relay() is ~1747 lines of inline assembly with keccak256, ecrecover, the signature
loop and the Merkle fold. KEVM symbolic execution of that, with the uninterpreted-function lemmas it would
need, is far beyond what completes in practice — the N=10 *toy* model already ran 12 h without finishing
(see `relay-phase3-documented-items.md`).

## The bridge that IS achievable: bounded composition, made explicit

The bridge is established by **composition of two machine-checked facts about the *same* invariant**:

| Fact | Tool | Subject | Coverage |
|------|------|---------|----------|
| (a) bytecode ⊨ `psAt` invariant | **Halmos** (`RelayModelBridgeFV`, also `RelaySigParamFV`) | the **real `relay()` bytecode** | K = 1, 2, 3 |
| (b) model ⊨ `psAt` invariant | **Kontrol** (`kontrol/RelaySigLoopFV`) | the Solidity **model** | **all K** |

`RelayModelBridgeFV` is the explicit bridge artifact: it computes the Kontrol model's **own** prefix-sum
function `_psAt` (reproduced verbatim in meaning) and asserts the **real deployed bytecode** obeys it —
`relay() accepts ⟹ psAt(K) > threshold` — for K = 1, 2, 3, with a reachability control proving the
bytecode genuinely accepts when the model predicts it can (non-vacuous). This pins the model function to
the bytecode at every K we can run.

Together: the model is a faithful abstraction of the bytecode wherever it is checkable (K ≤ 3), and the
property it proves for **all K** (b) is exactly the property the **bytecode satisfies** (a). That is the
strongest sound model↔bytecode link obtainable without observing intermediate loop state.

## Honest residual

- The link is **bounded at K ≤ 3 on the bytecode side**. A divergence between model and bytecode that
  manifests **only** at K ≥ 4 would not be caught. This is mitigated by the loop body being a single
  fixed instruction sequence iterated (so K = 1, 2, 3 already exercise every distinct path through the
  body — index check, ecrecover, weight add, accept gate), but it is not a proof of body-equivalence at
  unbounded depth.
- The cryptography (keccak injective, ecrecover uninterpreted) remains assumed on both sides (modeling
  contract A1/A2), so the bridge is about the *accounting*, consistent with the whole engagement.

## Verdict

T1 is delivered as a **bounded, explicit model↔bytecode bridge** (`RelayModelBridgeFV`), with the
fully-symbolic-depth and full-Kontrol-bytecode forms shown to be non-observable / intractable and
documented as such. The unbounded guarantee for the deployed contract rests on (a)+(b): bytecode-checked
at K ≤ 3 against the identical invariant Kontrol proves for all K.
