# L8 — The mathematics

> **What you get from this level.** The actual objects, in mathematical notation, with theorem
> statements and proof *sketches* you could in principle reconstruct by hand. Prose still carries the
> argument; the verbatim Lean is L9. Three parts: **§A** the abstract model and its soundness theorem;
> **§B** the EVM as an operational semantics; **§C** the refinement that links them, including the one
> non-obvious technical device (*fuel-genericity*). Caveats raised here are discharged in L10.

Throughout, `ℕ` is the naturals and `𝕌 := Fin 2²⁵⁶` is the type of EVM machine words ("UInt256"),
with arithmetic performed **modulo 2²⁵⁶**. Keep the distinction `ℕ` vs `𝕌` in view; it is the source of
one of the two residual caveats.

---

## §A. The abstract model and threshold soundness

### A.1 Objects

We model the on-chain accounting over `ℕ` (no overflow at this layer — see the caveat at the end of §A).

**Weights.** A validator set is a list `w : List ℕ`; `w[j]` is voter `j`'s weight and `N := w.length`.

**Prefix sum.** The total weight of the first `k` voters:
$$
\mathrm{sumTake}(w, 0) = 0, \qquad
\mathrm{sumTake}([], k{+}1) = 0, \qquad
\mathrm{sumTake}(x{::}xs, k{+}1) = x + \mathrm{sumTake}(xs, k).
$$
This is the on-chain `psAt(k)`. It is **monotone** in `k`: `i ≤ j ⟹ sumTake(w,i) ≤ sumTake(w,j)`
(proved from the one-step fact `sumTake(w, k+1) = sumTake(w,k) + w.getD k 0`, where `getD` returns 0
past the end of the list).

**The accounting loop.** State is a pair `(weight, nui)` — the running tally and the *next unused index*
(the smallest voter index not yet consumed). One signature carrying index `idx` does:
$$
\mathrm{loop}(w,\,\textit{weight},\,\textit{nui},\,[]) = (\textit{weight},\,\textit{nui}), \qquad
\mathrm{loop}(w,\,\textit{weight},\,\textit{nui},\,\textit{idx}{::}\textit{rest})
   = \mathrm{loop}\big(w,\ \textit{weight} + w.\mathrm{getD}\,\textit{idx}\,0,\ \textit{idx}{+}1,\ \textit{rest}\big).
$$
So each signature adds the weight at its index and advances the boundary to `idx+1`.

**Valid signature streams.** The crucial anti-double-counting discipline: signature indices must be
**strictly increasing and in range**. As an inductive predicate `ValidRun w nui idxs`:

- `ValidRun w nui []` always holds;
- `ValidRun w nui (idx :: rest)` holds iff `nui ≤ idx`, `idx < N`, and `ValidRun w (idx+1) rest`.

Because each step requires the *next* index to be at least the *current* boundary `nui`, and the
boundary is set to `idx+1` after consuming `idx`, no index can be used twice. This is the formal content
of "no voter counted twice."

### A.2 The invariant and the theorem

The single load-bearing fact is an **invariant** maintained by the whole loop, for *any* stream and
*any* weights:

> **Lemma (`loop_inv`).** If `weight ≤ sumTake(w, nui)` and `nui ≤ N` and `ValidRun w nui idxs`, then
> after the loop, `result.weight ≤ sumTake(w, result.nui)` and `result.nui ≤ N`.

*Proof sketch.* Induction on `idxs`. Empty: the hypotheses are the conclusion. Cons `idx :: rest` with
`nui ≤ idx`, `idx < N`: the new tally is `weight + w[idx]`, the new boundary `idx+1`. We must feed the
induction hypothesis `weight + w[idx] ≤ sumTake(w, idx+1)`. Now
`sumTake(w, nui) ≤ sumTake(w, idx)` (monotonicity, since `nui ≤ idx`) and
`sumTake(w, idx) + w[idx] = sumTake(w, idx+1)` (the one-step recurrence), so from `weight ≤ sumTake(w,
nui)` we get `weight + w[idx] ≤ sumTake(w, idx) + w[idx] = sumTake(w, idx+1)`. And `idx+1 ≤ N` from `idx
< N`. Apply the IH. ∎

The invariant says: **the tally never runs ahead of the prefix sum at the current boundary, and the
boundary never passes the last voter.** Threshold soundness is then immediate:

> **Theorem (`threshold_sound`, ∀N ∀K).** If `ValidRun w 0 idxs` and `thr < (loop w 0 0 idxs).weight`,
> then `thr < sumTake(w, N)`.

*Proof.* Start the invariant from `weight=0`, `nui=0` (`0 ≤ sumTake(w,0)=0`, `0 ≤ N`). It gives
`result.weight ≤ sumTake(w, result.nui)` and `result.nui ≤ N`, and monotonicity gives
`sumTake(w, result.nui) ≤ sumTake(w, N)`. Chain: `thr < result.weight ≤ sumTake(w, result.nui) ≤
sumTake(w, N)`. ∎

`sumTake(w, N)` is the total registered weight. So **acceptance forces the genuine total to exceed the
threshold** — for every voter count `N` and every signature stream length `K`, with no double-counting
(carried by `ValidRun`). The contrapositive (`insufficient_weight_cannot_accept`) is a one-liner: if the
total is within the threshold, the loop can never accept.

> ⚠ **Caveat A (discharged in L10).** the abstract proof works over `ℕ`. The on-chain tally lives in `𝕌` (mod
> 2²⁵⁶). Identifying the two requires that the sums never wrap — i.e. the **overflow bound**. This is a
> real side condition, established outside the abstract proof (in this engagement, `totalWeight < 2¹⁶`, far below
> 2²⁵⁶). The abstract proof is the *integer* truth; L10 states what is needed to import it into `𝕌`.

---

## §B. The EVM as an operational semantics

To reach rung R4 we need to *run* code inside Lean. EVMYulLean provides this as a computable function.

### B.1 An interpreter is a function

The Yul interpreter has (essentially) the shape
$$
\mathrm{exec} : \mathbb{N} \to \mathrm{Stmt} \to \mathrm{Option\ Contract} \to \mathrm{State} \to
  \mathrm{Except\ Exception\ State}.
$$
Read it as: *given a step budget, a statement to run, an optional code override, and a starting state,
either raise an exception or return a new state.* `Except E A` is the sum `A ⊎ E` (Lean's error monad);
we live in the success branch `.ok`.

**State.** `State = Ok (machine) (varstore) | OutOfFuel | Checkpoint (jump)`. The two components of an
`Ok` state are:

- **`machine : SharedState`** — the EVM machine state (memory, calldata, storage, ...). For our purposes
  it is an opaque carrier that the counting loop never touches.
- **`varstore : VarStore := Finmap (Identifier ⇀ Literal)`** — the Yul local variables, a *finite map*
  from identifier names (`Identifier = String`) to machine words (`Literal = 𝕌`).

`Checkpoint` encodes in-flight `break`/`continue`/`leave` control flow; `OutOfFuel` is what you get if
the budget is exhausted.

### B.2 Fuel: turning a possibly-non-terminating interpreter into a total function

EVM code can loop; a faithful interpreter is therefore not obviously a *total* mathematical function.
The standard device is **fuel**: a natural number bounding the number of reduction steps. `exec`
recurses with strictly smaller fuel and returns `OutOfFuel` at zero. This makes `exec` a *total* function
of `(fuel, stmt, state)`, hence definable in Lean.

The semantic reading: a result of the form `exec f stmt s = .ok (Ok s')` for some concrete `f` is the
**genuine** result — enough fuel was supplied to run to completion, and `OutOfFuel` did not occur. If a
program halts in `t` real steps, then for every `f ≥ t` the answer is the same `.ok (Ok s')`. (We will
*not* rely on a general "more fuel ⟹ same answer" lemma — see §C.3 for the subtlety and the way around
it.)

### B.3 The loop construct

A Yul `For c post body` (no init — the optimizer hoists it) runs via an auxiliary `loop`:

> `loop fuel c post body s`: evaluate the condition `c` (via `eval`); if it is `0`, exit, restoring the
> outer variable scope; otherwise `exec body`, handle any `break`/`continue`/`leave`, then `exec post`,
> then recurse on `For c post body`.

`eval : ℕ → Expr → ... → Except Exception (State × Literal)` evaluates an expression to a word, and the
per-opcode meaning (e.g. `ADD`, `LT`) is given by a `step` function. These are the pieces our refinement
drives.

---

## §C. The refinement: a validated EVM faithfully runs the unbounded loop

### C.1 The concrete loop (memory-free encoding)

We encode a counting accumulation loop in the actual Yul AST. With identifiers `i` and `w`:

```
for { } lt(i, N) { i := add(i, 1) }      // cond: i < N ;  post: i := i + 1
{ w := add(w, i) }                        // body: w := w + i
```

i.e. `cond(N) = LT(i, N)`, `post = [ i := ADD(i, 1) ]`, `body = [ w := ADD(w, i) ]`.

This is a **memory-free** loop: the body adds the loop *index* `i`, not a value loaded from memory. Two
deliberate caveats, both discharged in L10:

> ⚠ **Caveat C1 (memory/FFI).** EVMYulLean's memory is backed by a foreign byte-array; memory-touching
> programs cannot be *concretely evaluated* inside a plain proof file. A memory-free encoding sidesteps
> this entirely and lets the refinement reason purely about control flow and the variable store.

> ⚠ **Caveat C2 (addend identity — the central one).** The deployed body adds a *registered weight*
> `mload(weights[i])`; our body adds `i`. Replacing the memory load by `i` yields a *structurally
> identical* accumulation — same iteration count, same "add a per-step quantity to `w`" shape — whose
> faithful execution is what we prove. The identity "the per-step quantity is the right weight" is the
> **data layer (BR-1)** — **since discharged** (§C.5): a second development replaces this body with the
> deployed contract's real `mload(slot) & 0xffff` and proves the analogue, ∀N, on the validated EVM. The
> memory-free encoding here isolates the loop *mechanism* — that *the validated EVM really does iterate N
> times and accumulate the per-step quantity, for all N* — the part the assembly barrier attacks.

### C.2 The abstract accumulator and the refinement theorem

Mirroring the loop, define over `𝕌` (mod 2²⁵⁶), with `a` the current index and `m` the iterations left:
$$
\mathrm{absAcc}(a, 0, w) = w, \qquad
\mathrm{absAcc}(a, m{+}1, w) = \mathrm{absAcc}(a{+}1,\, m,\, w + \mathrm{ofNat}\,a).
$$
So `absAcc(0, N, 0) = \sum_{a<N} \mathrm{ofNat}\,a` in `𝕌`. This is the `𝕌`-valued mirror of a prefix
sum; structurally it plays the role `sumTake` plays in the abstract proof (a fold that adds one term per step).

> **Theorem (`bytecode_loop_correct`, ∀ N < 2²⁵⁶).** For any machine state `ss` and any var-store `vs`
> with `vs[i] = 0` and `vs[w] = 0`, there is a final store `vs'` such that
> $$
> \mathrm{exec}(3N{+}10,\ \texttt{For}(\mathrm{cond}\,N,\ \mathrm{post},\ \mathrm{body}),\ (\mathrm{Ok}\ ss\ vs))
>   \;=\; .\mathrm{ok}\,(\mathrm{Ok}\ ss\ vs')
> \quad\text{and}\quad vs'[w] = \mathrm{absAcc}(0, N, 0).
> $$

In words: **the validated interpreter, given exactly `3N+10` fuel, runs the loop to completion and the
final value of `w` is precisely the abstract accumulator — for every N.** The machine part `ss` is
untouched (the loop is memory-free), so the same `ss` appears on both sides.

The fuel count is exact, not a bound: each iteration costs exactly 3 fuel units (condition + body +
post, at the granularity that matters), plus a fixed `+10` for entry/exit. This exactness is what lets
the induction go through without any fuel-monotonicity lemma (§C.3).

### C.3 The induction, and the *fuel-genericity* device

`bytecode_loop_correct` is the `a=0, m=N` case of a stronger statement proved by induction on the number
of iterations `m`:

> **Lemma (`loop_acc`).** For `N < 2²⁵⁶` and all `m, a` with `a + m = N`, all `w`, and any state with
> `vs[i] = ofNat a`, `vs[w] = w`: `exec(3m+10, For(cond N, post, body), Ok ss vs) = .ok (Ok ss vs')`
> with `vs'[w] = absAcc(a, m, w)`.

*Proof sketch.* Induction on `m`.

- **Base `m = 0`:** then `a = N`, the condition `lt(ofNat N, ofNat N)` is `0`, the loop exits
  immediately, `w` unchanged `= absAcc(a, 0, w)`. Fuel `10` suffices.
- **Step `m+1`:** then `a < N`, so `lt(ofNat a, ofNat N) ≠ 0`; one iteration fires. The body sets
  `w ↦ w + ofNat a`; the post sets `i ↦ ofNat a + 1 = ofNat (a+1)`. The resulting state has
  `i = ofNat(a+1)`, `w = w + ofNat a`, and matches the induction hypothesis at `(a+1, m)` (note
  `(a+1) + m = N`). Apply it; the accumulator unfolds as `absAcc(a, m+1, w) = absAcc(a+1, m, w + ofNat
  a)`. Fuel: `3(m+1)+10 = (3m+10) + 3`. ∎

The mechanism that makes each iteration's effect provable is the one genuinely non-obvious idea, so we
state it carefully even at this level.

**The problem.** `exec` is defined by recursion on fuel. We want to know the *effect* of one statement
(e.g. "`exec` of the body inserts `w ↦ w + i` into the store"). The naive obstacle: in the inductive
step the available fuel is a *symbolic* `3m+10`, not a concrete number, and EVMYulLean offers **no
lemma** of the form "if `exec f s = r` then `exec (f+1) s = r`" (fuel monotonicity). Without it, you
seemingly cannot reduce `exec` at a symbolic fuel.

**The device ([fuel-genericity](CONCEPTS.md#15-fuel-and-fuel-genericity)).** You do not need monotonicity. Prove each statement's effect at fuel
`fuel + K`, where `fuel` is a *universally quantified variable* and `K` is the *exact concrete* number
of recursion layers that statement consumes (here `K = 7` for a single assignment block, `6` for the
condition). The simplifier, unfolding the definition of `exec`/`eval`, peels off exactly `K` successor
layers — `succ (succ (... fuel ...))` — and reduces the statement to its effect, **regardless of what
`fuel` is**. So:

- `body_eff` : `exec (fuel+7) (Block body) (Ok ss vs) = .ok (Ok ss (vs[w ↦ vs[w] + vs[i]]))`, for all
  `fuel`;
- `post_eff` : `exec (fuel+7) (Block post) (Ok ss vs) = .ok (Ok ss (vs[i ↦ vs[i] + 1]))`;
- `cond_eff` : `eval (fuel+6) (cond N) (Ok ss vs) = .ok (Ok ss vs, lt(vs[i], N))`.

In the induction, the symbolic fuel `3m+10` is rewritten as `(3m+3) + 7` (or `+6`) to match, and the
generic lemma fires. **One statement at a time, at symbolic fuel, with no monotonicity lemma in sight.**
This is the crux that turned an apparently-blocked proof into a routine induction; it is reusable on any
fuel-indexed interpreter (L12).

### C.4 Transferring threshold soundness to the bytecode

With the refinement in hand, the soundness step transfers directly:

> **Theorem (`bytecode_threshold_sound`, ∀N).** For `N < 2²⁵⁶`, starting from `i=0, w=0`, if the loop
> executed by the validated interpreter ends in store `vs'` and **accepts** — `thr < vs'[w]` — then
> `thr < absAcc(0, N, 0)`.

*Proof.* `bytecode_loop_correct` gives a final store whose `w` equals `absAcc(0, N, 0)`; `exec` is a
function, so that store *is* `vs'`, whence `vs'[w] = absAcc(0, N, 0)`. Substitute into the hypothesis. ∎

This is `threshold_sound`'s shape — *accept ⟹ the accumulated total exceeds the threshold* — now holding
of a loop run by a **validated model of the real machine**, for all N. That is the rung-R4 statement.

> ⚠ **Caveat C3 (modular order).** `thr < absAcc(0,N,0)` is a comparison in `𝕌` (it compares residues
> mod 2²⁵⁶). To read it as the Phase-A integer statement `thr < sumTake(w, N)` you need both the
> overflow bound (Caveat A) and the data layer (Caveat C2). **Both are now discharged** (§C.5): the
> memory-reading development carries the integer form `bytecode_threshold_sound_mem_int` (under an explicit
> no-overflow hypothesis) and the bridge to `sumTake`, so `relay_loop_sound` is an *integer* inequality.

---

### C.5 Discharging the addend identity: the memory-reading loop and the full relation

Caveat C2 is no longer a standing assumption. A second development ([`RelayLoopMemRead.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopMemRead.lean)) replaces the
memory-free body with the deployed contract's *actual* masked memory read and proves the analogous theorems,
∀N, against the validated semantics — then composes with the abstract proof of §A.

**The body.** With slot `i·32`:
```
{ w := add(w, and(mload(mul(i, 32)), 0xffff)) }   // w := w + (mload(i·32) & 0xffff)
```
each iteration loads a 32-byte word from memory at the per-iteration slot and adds its low 16 bits.

**State-preservation of `mload`.** EVMYulLean's `mload` returns a *pair* — the value and a machine state whose
`activeWords` may have grown. The key observation: once the slot lies within the already-active region
(`M(activeWords, slot, 32) = activeWords`, i.e. `slot + 32 ≤ activeWords·32`), the memory-expansion is a
no-op and `mload` returns the state *unchanged*. Under that hypothesis the body is again `ss`-preserving, and
`body_effM` gives, at the exact fuel `+15`,
$$ \mathrm{exec}(\texttt{Block }body_M,\ \mathrm{Ok}\ ss\ vs) = \mathrm{Ok}\ ss\ \big(vs[w \mapsto vs[w] + (\mathrm{rd}(ss,a)\ \&\ \texttt{0xffff})]\big). $$

**Accumulator and induction.** Mirroring §C.2 with the masked reads `mrd(k) = \mathrm{rd}(ss,k)\ \&\ \texttt{0xffff}`,
`absAccM` folds the masked reads; `loop_accM` runs the same induction (fuel `3N+15`), and
`bytecode_threshold_sound_mem` / `_int` give: ∀N, *accept ⟹ the total of the masked memory reads exceeds the
threshold* (modular; and integer, under no overflow).

**The bridge.** Under the data-layer correspondence `mrd(k) = w[\,idxs[k]\,]` — the masked read at position `k`
is the registered weight of the voter that signature `k` selects — `bridge` proves
$$ \mathrm{absAccMNat}(0,N,0) = (\mathrm{sigLoop}\ w\ 0\ 0\ idxs).1, $$
the abstract loop's accumulated weight (`sigLoop`/`sumTake`/`ValidRun`/`threshold_sound` of §A are restated
in-file so one `lake env lean` checks the whole chain). Composing:

> **Theorem (`relay_loop_sound`, ∀N).** If the deployed loop — with its real masked memory read, on the
> validated EVM — accepts (final `w` > thr), then `thr < sumTake(w, |w|)`: the total registered voting weight
> exceeds the threshold, with no voter double-counted. Hole-free (`[propext, Classical.choice, Quot.sound]`).

**What is now assumed.** Only the *external call*: `ecrecover` is not modeled (MC-2), so the per-iteration
*selection* (`hcorr`: which voter each signature recovers to) and *validity* (`hvalid` = `ValidRun`:
strictly-increasing in-range indices = the guards passed) are stated hypotheses; the per-slot memory invariant
`hcov` is the data layer, discharged by `DataLayer.weight_read`. The data layer (Caveat C2) and the overflow
bound (Caveat A) are discharged. (§C.6 goes further still: the literal loop-body model executes the deployed
contract's *actual* body on the validated EVM, so `hcov` and the mechanical half of `hcorr` are *derived* rather
than assumed, and the index guards follow from `ValidRun`.)

### C.6 The literal loop-body model: eliminating the memory-read assumptions

§C.5's `relay_loop_sound` still *assumes* the per-slot memory invariant `hcov` and the masked-read
correspondence `hcorr`. A third development removes both by transliterating the deployed signature-verification
loop body **statement for statement** and executing it on the validated EVM. It spans three files:
[`RelayLoopLiteral.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopLiteral.lean) (the 17-statement
body `bodyL`, the interpreter atoms, and the calldata decode `sigIdxAt`/`voterWeightAt`/`weightsOf`),
[`RelayLoopWindows.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopWindows.lean) (the byte-window
read/decode lemmas), and the integration file
[`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean).

**The body executed in full.** `body_effL` runs the whole 17-statement `bodyL` through EVMYulLean's real
`exec`/`eval`, threading the genuine `mstore`/`calldatacopy`/`mload` state changes (contrast `body_effM`, which
*assumed* the read was state-preserving). Because the memory is now threaded, there is no `hcov` to posit; and
`mload_masked_voter` *derives* the masked read — clear a scratch slot, `calldatacopy` the voter record, `mload`,
mask ⟹ the record's registered weight — so the mechanical half of `hcorr` becomes a theorem.

**The chain.** `s16_ww_advance`/`s16_ii_preserved` extract the accounting from `body_effL`'s output state (weight
advanced by the selected voter's weight; loop counter preserved); `iter_advance` assembles these into the
per-iteration advance `hstep` the induction consumes; `range_guard_pass`/`order_guard_pass` *derive* the two
structural index guards (range `idx < nVot`, order `nui ≤ idx`) from the `ValidRun` numeric discipline;
`loop_accL` runs the induction (§C.3's template, now threading the evolving memory); and the capstones are

> **Theorem (`relay_loop_sound_literal`, `…_derived`, `…_derived_tight`, ∀N).** If the deployed loop — its
> *actual* transliterated body executed by the validated Yul `exec` — completes with a final tally exceeding the
> threshold, then `thr < sumTake(w, |w|)`: the total registered voting weight exceeds the threshold, with no
> voter double-counted. `…_derived` discharges the per-iteration `hstep` via `iter_advance`; `…_derived_tight`
> discharges the structural guards too, leaving one per-iteration hypothesis `IterPremiseT`.

The accounting conclusion is identical to `relay_loop_sound`; what shrinks is the assumption surface.
`IterPremiseT` bundles exactly the **ecrecover boundary** (MC-2/OP-1): the cryptographic guards (`v ∈ {27,28}`,
low-`s`, `staticcall` success, `returndatasize = 32`, signer ≠ 0, recovered signer matches the registered voter)
and the accept gate, together with the calldata index decode and the `ValidRun` numeric discipline. Everything
mechanical — execution, the memory reads, the mask, the tally, the accumulation, the accept gate, and the
index-range/strict-increase guards — is proved against the validated EVM. The [`RelayLoopMemRead.relay_loop_sound`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopMemRead.lean#L454)
statement of §C.5 remains as the simpler corroborating result; the literal chain is the stronger one. All
literal-chain theorems are hole-free (`[propext, Classical.choice, Quot.sound]`; the two accounting-extraction
lemmas need only `[propext, Quot.sound]`), inheriting the same upstream-dischargeable data/window specs
(`zeroes_data`, `toByteArray_size`) only where the memory *write* round-trip is used.

### Summary of §C

| Object | Role | Rung |
|--------|------|------|
| `cond/post/body` | the counting loop in real Yul AST | — |
| `absAcc` | `𝕌`-valued abstract accumulator (the spec of the loop) | — |
| `body_eff`, `post_eff`, `cond_eff` | per-statement effects at symbolic fuel (fuel-genericity) | R4 bricks |
| `loop_acc` | the induction: interpreter ⊑ accumulator, all m | R4 |
| `bytecode_loop_correct` | refinement at `a=0,m=N`: final `w` = `absAcc(0,N,0)`, all N | R4 |
| `bytecode_threshold_sound` | soundness transferred onto the validated semantics, all N | R4 |
| `body_effM`, `loop_accM` | the **memory-reading** body `w += mload(i·32)&0xffff` and its induction, all N | R4b′ (§C.5) |
| `bytecode_threshold_sound_mem(_int)` | accept ⟹ Σ masked reads > thr (modular; integer under no overflow), all N | R4b′ |
| `bridge`, `relay_loop_sound` | masked-read sum = abstract loop weight; **accept ⟹ total registered weight > thr**, all N | R4b′ |
| `body_effL`, `iter_advance` | the **literal hand-transliterated** 17-statement body model; per-iteration advance derived | R4b″ (§C.6) |
| `range_guard_pass`, `order_guard_pass`, `iter_advance_tight` | structural index guards derived from `ValidRun`; tightened advance | R4b″ |
| `relay_loop_sound_literal_derived_tight` | conditional **accept ⟹ total registered weight > thr**; reads derived, `ValidRun`/execution/acceptance and ecrecover premises explicit, all N | R4b″ |
| `relay_loop_sound_literal_early` | the same, with the accept branch as the deployed `return(0,0)` — the loop halts at the first threshold crossing (early return, faithful) | R4b″ |
| `sstore_sload`, `sstore_reads_back` | storage round-trip; accept-write `merkleRootsPrivate[·][·]` (Relay.sol:1394) reads back | R5 |
| `dispatch_routes_verify` | mode dispatch routes faithfully (`protocolId ≠ 1` → verify); modes don't cross-contaminate | R5 |
| `relay_dispatch_loop_accept` | **end-to-end composition** — dispatch → loop → accept ⟹ registered weight > thr, all N | R5 |
| `fee_conservation`, `transfer_conservation`, `two_transfer_caller_net_zero` | `fee + (msg.value − fee) = msg.value` (no wrap); `transferBalance` conserves value; caller net-zero | R5 |

The last four rows are the **R5** breadth extension — the same literal, validated-EVM method applied beyond the
signature loop to the rest of `relay()` (mode dispatch, storage/accept-write, the dispatch → loop → accept
composition, and fee conservation). All hole-free; R5 adds coverage, not a new soundness fact. Full walk:
[L9 §G.5](09-the-formal-detail.md).

**Next:** [L9 — The formal detail](09-the-formal-detail.md): the verbatim Lean, every tactic, the
EVMYulLean API, the gotchas, and the axiom audit.
