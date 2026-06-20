# L1 — The big picture

> **What you get from this level.** A correct, honest mental model of the problem and the tools, using
> analogies, with no formal background assumed. Every analogy here is *deliberately* simplified; each
> simplification is flagged with a "⚠ caveat" that a later level discharges.

---

## 1.1 What `Relay.sol` does, and why correctness matters

Flare is a blockchain. A blockchain advances by having a set of validators **vote** on what the next
piece of agreed-upon data is (a new "signing policy", a random number, or a Merkle root summarizing a
batch of facts). Each validator has a **weight** — think of it as the number of votes they control,
proportional to their stake. A proposal is **accepted** only if the total weight of the validators who
signed it exceeds a **threshold** (a supermajority).

`Relay.sol` is the smart contract that performs this check on-chain. Its central job, given a proposal
and a bundle of signatures, is to:

1. recover which validator produced each signature,
2. add up the weights of those validators,
3. accept iff the running total exceeds the threshold.

If this accounting is wrong, the consequences are severe. Two failure shapes matter most:

- **Forgery / under-counting the threshold.** If the contract can be made to accept a proposal whose
  signers do *not* actually command enough weight, an attacker can push fraudulent data onto the chain.
- **Double-counting.** If one validator's signature can be counted twice, a minority can manufacture an
  apparent supermajority.

The property we care about is therefore: **acceptance genuinely requires enough distinct voter
weight.** This is the on-chain analogue of a returning officer who must never declare a motion carried
unless the people who actually voted for it really do hold a majority — and must never count the same
person's ballot twice.

> ⚠ **Caveat (discharged in L3/L5):** "recover which validator produced each signature" involves
> elliptic-curve cryptography (`ecrecover`). We do **not** verify the cryptography; we verify the
> *accounting* that sits on top of it. The standard assumption "a valid signature identifies its
> signer" is taken as given, exactly as in the rest of this engagement.

---

## 1.2 What "verification" means, by analogy

Imagine you have built a machine — say, a coin-sorting machine — and you want to be sure it never
miscounts. You have a ladder of increasingly strong ways to gain confidence:

1. **Try some coins (testing).** Feed in a handful of known batches, check the totals. Cheap, but it
   only tells you about the batches you tried. Bugs hide in the cases you didn't think to feed it.

2. **Try *lots* of random coins (fuzzing).** Throw thousands of random batches at it. Better coverage,
   still no guarantee: the one adversarial batch that breaks it may never come up by chance.

3. **Reason about *every* batch up to some size (bounded symbolic checking).** Instead of concrete
   coins, feed in a "symbolic" batch — a placeholder standing for *all* batches of, say, ≤ 5 coins at
   once — and let a solver check the machine against all of them simultaneously. Now you have a
   guarantee, but only up to size 5. This is what tools like **Halmos** do on real contract bytecode.

4. **Reason about batches of *every* size (unbounded verification).** Prove, by an argument that does
   not care how many coins there are, that the machine is correct for batches of *any* size. This needs
   *induction* — "if it's correct for n coins, it's correct for n+1" — which a solver cannot discover on
   its own; it needs either a clever automated prover (a **theorem prover**) or human-guided structure.
   Tools like **Kontrol/KEVM** and **Certora** attempt this on a *model* of the contract.

5. **Prove it about the *actual physical machine*, not a drawing of it.** Even an unbounded proof is
   only as good as the description of the machine it reasons about. If you proved a property of a tidy
   blueprint, but the real machine has hand-soldered wiring the blueprint glossed over, your proof might
   not apply. The strongest result proves the property about a faithful model of the *real hardware*.

This ladder — from "tried a few" to "proved it about the real machine for all inputs" — is the spine of
the whole project. The destination is rung 5.

> ⚠ **Caveat (discharged in L2/L5):** "the real machine" for a smart contract is the **EVM bytecode**
> as executed by the network. We reach rung 5 by reasoning against a *validated model of the EVM* (a
> mathematical description of EVM execution that has itself been tested against the official Ethereum
> test suites). "Validated model of the real machine" is therefore the honest phrase, and L5 is precise
> about the gap between it and the literal deployed bytes.

---

## 1.3 The two enemies

Two distinct difficulties make this contract hard, and it helps to name them separately because
*different tools defeat different enemies*.

### Enemy 1 — The unbounded-input problem

The number of validators N and the number of signatures K are not fixed. A real assurance must hold for
all of them. Testing and fuzzing (rungs 1–2) cannot reach "all"; bounded symbolic checking (rung 3)
reaches "all up to a fixed size" and then stops. Only an *inductive* argument (rungs 4–5) covers every
size. This enemy is defeated by **proof by induction**, which is the mathematical heart of everything
here.

### Enemy 2 — The opaque-machine problem (inline assembly)

`Relay.sol`'s hot path is roughly 930 lines of **hand-written EVM assembly** (Yul/inline-assembly),
not ordinary Solidity. The contract manages its own memory and storage layout by hand, for gas
efficiency.

The analogy: most verification tools expect a machine described in a *high-level blueprint* (structured
Solidity), from which they reconstruct a clean model. Hand-written assembly is like a machine whose
maker bypassed the blueprint and soldered the wires directly. The tools that reconstruct a model from
the blueprint — **Kontrol** (works from a Solidity model) and **Certora** (reasons about storage
variables it can name) — lose their footing: they cannot see the hand-soldered storage as the structured
variables they rely on, so they either time out or report spurious problems. (We document this
convergent failure of *both* tools in L2; it is a genuine finding, not a tooling mishap.)

The only tools that are immune to Enemy 2 are those that reason about the machine *at the level of the
actual instructions* — the bytecode/Yul itself. That is exactly what a **theorem prover working against
a model of the EVM** does, and it is why the deepest result here is built in **Lean 4** on top of a
validated EVM semantics.

---

## 1.4 The plan in one picture

We split the work along the two enemies and conquer them on separate layers, then join the layers.

```
                          THE PROPERTY
        "acceptance requires enough distinct voter weight"

   ┌─────────────────────────────────────────────────────────────┐
   │  PHASE A  (defeats Enemy 1 — the unbounded-input problem)     │
   │                                                               │
   │  Prove the ACCOUNTING ALGORITHM sound for ALL N and ALL K,    │
   │  as an abstract mathematical object, by induction.            │
   │  Tool: Lean 4 (core).   Result: threshold_sound.              │
   └─────────────────────────────────────────────────────────────┘
                               │  lift onto the real machine
                               ▼
   ┌─────────────────────────────────────────────────────────────┐
   │  GAP B  (defeats Enemy 2 — the opaque-machine problem)        │
   │                                                               │
   │  Show a loop, executed by a VALIDATED MODEL OF THE EVM,       │
   │  faithfully performs the unbounded accumulation for ALL N,    │
   │  and transfer the threshold step onto that execution.         │
   │  Tool: Lean 4 + EVMYulLean.   Result: bytecode_threshold_sound│
   └─────────────────────────────────────────────────────────────┘
                               │
                               ▼
        Residual, explicitly ASSUMED (not proven), validated by other means:
        the data layer — the byte read each iteration is the right weight,
        and the weights are small enough not to overflow 256 bits.
```

- **Phase A** is pure mathematics: it never mentions the EVM. It proves the *idea* is sound.
- **Gap B** is the bridge to reality: it proves a *validated model of the actual machine* really does
  run an unbounded accumulating loop correctly, and that "accept ⟹ enough weight" survives the trip
  from idea to machine.
- The **residual** is the small, clearly-fenced set of facts we did not prove in Lean and instead
  justified separately. Naming it precisely is the whole point of L5.

> ⚠ **Caveat (discharged in L3/L5 — the most important one).** The loop we run inside the validated EVM
> model in Gap B is a *counting accumulation loop* (it iterates a known number of times and sums a
> per-step quantity). This captures the **loop mechanism** — the part Enemy 2 attacks — but it is not a
> bit-for-bit copy of the full signature loop with its cryptography, its gap-skipping discipline, and
> its memory loads. The signature-specific accounting (no double-counting, weights from arbitrary
> streams) is what **Phase A** handles in full generality. The seam where the two meet, and exactly what
> is and isn't covered there, is laid out honestly in L5. Keep this in mind: "Gap B closed" means *the
> abstract-vs-real bridge for the unbounded loop mechanism is machine-checked*, not "the entire deployed
> contract is proven equivalent to Phase A."

---

## 1.5 Why this is worth the trouble

A skeptic might ask: if you had to assume the data layer anyway, why go to rung 5 at all?

Because the two enemies are where real exploits live. Unbounded reasoning (Enemy 1) catches the
off-by-one that only manifests at large N. Real-machine reasoning (Enemy 2) catches the cases where the
hand-written assembly does something the high-level blueprint never said — precisely the cases automated
tools went blind to. By pushing those two frontiers as far as a machine-checked proof can go, we shrink
the trusted, unverified surface down to a single, *small, and independently-checkable* claim about
memory contents and magnitude — instead of trusting the entire 930-line assembly routine by eye. That
shrinkage is the deliverable.

**Next:** [L2 — Strategy & architecture](02-strategy-and-architecture.md), where we make "fidelity
ladder", "refinement", and "validated semantics" precise, and show the evidence that the automated tools
really do hit the assembly wall.
