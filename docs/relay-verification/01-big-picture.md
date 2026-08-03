# L1 — The big picture

> **What you get from this level.** A correct, honest mental model of the problem and the toolbox, using
> analogies, with no formal background assumed. Every analogy is *deliberately* simplified; each
> simplification carries a "⚠ caveat" that a later level discharges.

---

## 1.1 What `Relay.sol` does, and why correctness matters

Flare is a blockchain. It advances by having a set of validators **vote** on the next piece of
agreed-upon data — a new "signing policy", a random number, or a Merkle root summarizing a batch of
facts. Each validator carries a **weight** (roughly, stake-proportional voting power). A proposal is
**accepted** only if the combined weight of its signers exceeds a **threshold** (a supermajority).

[`Relay.sol`](../../contracts/protocol/implementation/Relay.sol) is the smart contract that performs this check on-chain. Given a proposal and a bundle of
signatures, its core job is to:

1. recover which validator produced each signature,
2. add up the weights of those validators,
3. accept iff the running total exceeds the threshold.

If this accounting is wrong, the damage is severe. Two failure shapes dominate:

- **Forgery / under-counting the threshold** — making the contract accept a proposal whose signers do not
  actually command enough weight lets an attacker push fraudulent data onto the chain.
- **Double-counting** — counting one validator's signature twice lets a minority manufacture an apparent
  supermajority.

So the property at the heart of the engagement is: **acceptance genuinely requires enough distinct voter
weight.** The on-chain analogue of a returning officer who must never declare a motion carried unless the
people who actually voted for it really hold a majority — and must never count one ballot twice.

`Relay.sol` does more than this core (three operating modes: signing-policy rotation, custom-signature
mode, and Merkle-root publishing; plus epoch lifecycle, fees, randomness). The verification covers all of
it; this core is the spine.

> ⚠ **Caveat (discharged in L4/L10):** "recover which validator produced each signature" is elliptic-curve
> cryptography (`ecrecover`). We verify the *accounting*, not the cryptography. "A valid signature
> identifies its signer" is a standing assumption, as in the whole engagement.

> **The other half of the engagement.** Alongside verification, `Relay.sol` was **hardened** against the
> audit findings (the RLY-* issues) — those fixes, issue-by-issue with tests, are in
> [`docs/relay-fixes.md`](../relay-fixes.md), and the post-fix review in
> [`docs/relay-security-review.md`](../relay-security-review.md). This ladder is the verification half; the
> two efforts meet where a fix becomes a proof's boundary contract (L10, OP-1/3/4).

---

## 1.2 What "verification" means, by analogy

Suppose you built a coin-sorting machine and want confidence it never miscounts. There is a *ladder* of
increasingly strong ways to gain that confidence:

1. **Try some coins ([testing](CONCEPTS.md#8-formal-verification-vs-testing)).** Feed known batches, check totals. Cheap; only tells you about the batches
   you tried.
2. **Try lots of random coins (fuzzing).** Thousands of random batches. Better coverage; still no
   guarantee — the one adversarial batch may never come up.
3. **Reason about *every* batch up to some size (bounded symbolic checking).** Feed a *symbolic* batch — a
   placeholder standing for all batches of ≤ 5 coins at once — and let a solver check all of them
   simultaneously. A real guarantee, but only up to size 5. This is **Halmos**, on the real machine.
4. **Reason about batches of *every* size (unbounded verification).** Prove, by an argument that does not
   care how many coins there are, correctness for *any* size. This needs **induction** ("correct for n ⟹
   correct for n+1"), which a solver cannot find unaided. This is **Kontrol/KEVM** and **Certora**, on a
   *model* of the machine. (What is [k-induction](CONCEPTS.md#5-what-is-k-induction)? What is
   [KEVM](CONCEPTS.md#4-what-is-kevm)?)
5. **Prove it about the *real machine*, for all inputs.** Even an unbounded proof is only as good as the
   description it reasons about. If you proved something of a tidy blueprint but the real machine has
   hand-soldered wiring the blueprint glossed over, the proof may not apply. The strongest result proves
   the property about a faithful model of the *real hardware*. This is **Lean + a validated EVM
   semantics** — the bytecode refinement (§1.4).

This ladder — "tried a few" → "proved it about the real machine for all inputs" — is the spine of the
whole engagement, formalized in L2 as the **fidelity ladder**.

> ⚠ **Caveat (discharged in L2/L10):** "the real machine" for a contract is its **EVM bytecode**. Rung 5
> is reached by reasoning against a *validated model of the EVM* (a mathematical description tested against
> Ethereum's official conformance suites). "Validated model of the real machine" is the honest phrase; L10
> is precise about the remaining gap to the literal deployed bytes.

---

## 1.3 The two enemies

Two distinct difficulties make this contract hard. Naming them separately matters, because *different
rungs defeat different enemies.*

### Enemy 1 — The unbounded-input problem

The validator count N and the signature count K are not fixed; a real assurance must hold for all of them.
Testing and fuzzing cannot reach "all"; bounded symbolic checking reaches "all up to a fixed size" and
stops. Only an *inductive* argument covers every size. Defeated by **proof by induction** — the
mathematical heart of the upper rungs (Kontrol for ∀K, Lean for ∀N∀K).

### Enemy 2 — The opaque-machine problem (inline assembly)

[`Relay.sol`](../../contracts/protocol/implementation/Relay.sol)'s hot path is roughly **930 lines of hand-written EVM assembly** (Yul/inline assembly), not
ordinary Solidity. It manages its own memory and storage layout by hand, for gas efficiency.

The analogy: most tools expect a machine described by a high-level blueprint (structured Solidity), from
which they reconstruct a clean model. Hand-written assembly is a machine whose maker bypassed the
blueprint and soldered the wires directly. Tools that reconstruct a model from the blueprint — **Kontrol**
(works from a Solidity model) and **Certora** (reasons about named storage variables) — lose their
footing: they cannot see the hand-soldered storage as the structured state they need, so they time out or
report spurious problems. (We show this convergent failure of *both* tools, with evidence, in L5; it is a
genuine finding.)

The rungs immune to Enemy 2 are those reasoning at the level of the actual instructions: **Halmos**
(symbolically *executes* the real bytecode — no storage model to break) and **Lean against a validated EVM
semantics** (reasons about the bytecode's meaning directly). That immunity is why the bounded floor and
the unbounded ceiling of the stack are exactly these two.

---

## 1.4 The plan in one picture — a stack, each rung covering the gap below

No single tool defeats both enemies over the whole contract. So the engagement built a **stack**, each
rung chosen for what it can reach that the rung below cannot:

```
   PROPERTY: "acceptance requires enough distinct voter weight" (+ the rest of relay())

   R4b  BYTECODE REFINEMENT — Lean + validated EVM semantics ... real machine, ∀N  (loop mechanism)
         ▲   lifts the abstract proof onto the validated bytecode semantics
   R4a  ABSTRACT PROOF — Lean (core) ....................... abstract algorithm, ∀N ∀K
         ▲   the math: induction, no EVM in sight
   R3   KONTROL (∀K on a Solidity model, N∈{3,5})  +  CERTORA (storage invariants)
         ▲   unbounded-in-K by induction; current Certora CVL is locally checked, cloud proof pending
   R2   HALMOS — 26 harnesses / 102 checks on REAL BYTECODE ... bounded; includes GSS state transitions
         ▲   symbolic execution; immune to the assembly wall; each proof anti-vacuity-guarded
   R0/R1 FOUNDRY tests + fuzzing on the deployed contract ........ concrete + random inputs
```

- **R0/R1** anchor the real contract with concrete and random cases.
- **R2 (Halmos)** is the bounded floor *on the real bytecode* — it defeats Enemy 2 but not Enemy 1.
- **R3 (Kontrol)** defeats Enemy 1 in the K dimension (∀K) by induction, but on a *model*, at fixed N;
  **Certora** tries the all-functions storage invariants and runs into Enemy 2 (the honest negative
  result).
- **R4a — the abstract proof** defeats Enemy 1 fully (∀N∀K) — but as an abstract algorithm, not the
  machine.
- **R4b — the bytecode refinement** closes the gap between the abstract proof and the real bytecode: it
  carries the abstract proof's result back down to a validated model of the *real machine*, for all N — the
  part Enemy 2 attacks.

The residual — explicitly *assumed*, validated separately — is small and named: the cryptography (out of
scope by design), the operational ABI of each boundary call, a trusted signing-policy setter, and the
per-iteration *selection/validity* the external calls determine (which voter each signature recovers to, and
that indices are strictly increasing). The **data layer** — that each iteration reads the intended weight from
memory — is no longer simply postulated: the literal model runs a statement-for-statement transcription of
the contract's 17-statement signature-verification body on the validated EVM, so its memory reads are
executed and their correctness is derived inside that model (the
hole-free literal chain, capstone `relay_loop_sound_literal_derived_tight`, in
[`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean); the simpler masked-read
`relay_loop_sound` corroborates — L7 §7.3). L10 fences the residual precisely.

> ⚠ **Caveat (discharged in L7/L10 — the most important one).** The loop run inside the validated EVM
> model at R4b is a *counting accumulation loop*; its body is a hand-transliterated 17-statement model,
> executed statement-for-statement — real `mstore`/`calldatacopy`/`mload`, the
> masked weight read, the tally and the accept gate — so the **loop mechanism, the data layer, and the body's
> memory plumbing** are all captured (the literal chain `relay_loop_sound_literal_derived_tight`; the earlier
> masked-read `relay_loop_sound` remains as the simpler corroborating statement — L7 §7.3). What is still
> abstracted is only the *cryptography*: the `ecrecover` precompile (invoked via `staticcall`) is [uninterpreted](CONCEPTS.md#17-uninterpreted-functions-and-the-ecrecover-boundary)
> by design, so the ecrecover facts (a valid signature recovers to the registered voter) plus the no-double-count
> discipline are stated hypotheses (`IterPremiseT`/`ValidRun`), and successful execution/acceptance remains
> explicit in the capstones. The signature-specific accounting is
> what **the abstract proof** handles in full generality. The result establishes its conditional theorem on
> validated semantics for all N — not whole-program equivalence of every accepted deployed execution.

---

## 1.5 Why the whole stack, and not just one rung

A skeptic might ask: if you assume the cryptography anyway, why climb to rung 5? And if Halmos already runs
the real bytecode, why add Lean?

Because the enemies are where exploits live, and each rung shrinks a different part of the unverified
surface:

- **Halmos** (R2) gives you the *real bytecode*, catching the cases where hand-written assembly does
  something the blueprint never said — but only up to a fixed size.
- **Kontrol/Lean** (R3/R4) give you *all sizes*, catching the off-by-one that only manifests at large N or
  large K — which no bounded tool can reach.
- **The bytecode refinement** (R4b) connects the two: it shows a validated model of the *real machine*
  genuinely runs the unbounded loop, so the ∀N guarantee is not stranded at the abstract level.

Stacked, they reduce the trusted, unverified surface to a single small, independently-checkable claim
about the cryptography (the `ecrecover` boundary) — instead of trusting 930 lines of assembly by eye. That
shrinkage is the deliverable, and L10 measures exactly how small the residual is.

**Next:** [L2 — Strategy & the fidelity ladder](02-strategy-and-the-fidelity-ladder.md), where the ladder
becomes precise, the tool-choices are justified, and an executive results table summarizes every rung.
