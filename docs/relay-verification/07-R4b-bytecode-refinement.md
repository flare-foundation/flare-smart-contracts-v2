# L7 — R4b: the bytecode refinement

> **Evidence note.** The refinement construction below is the historical design record. Current source/Yul
> fidelity and the executable Lean verdict are in [`CURRENT-STATUS.md`](CURRENT-STATUS.md).

> **What you get from this level.** Conditional ∀N refinement statements for a hand-modeled loop executed
> by a **validated model of the EVM**. §7.2 establishes the
> loop _mechanism_ (memory-free); §7.3 then discharges the **data layer (BR-1)** — the body becomes the
> deployed contract's real `mload(slot) & 0xffff` read — and composes the simulation-relation capstone
> `relay_loop_sound` (accept ⟹ total registered policy-slot weight > threshold): the **accounting core** of the relation
> `R`. §7.3 further builds the **literal** model (`RelayBodyEff`, a 17-statement hand transcription executed
> by the validated `exec`), which _derives_ `hcov`/`hcorr` and the index-range/strict-increase guards —
> leaving only the cryptographic `ecrecover` facts assumed (`relay_loop_sound_literal_derived_tight`). The overview, the results, and the honest residual. The mathematics is
> [L8 §C](08-the-mathematics.md); the verbatim Lean, fuel-genericity, and axiom audit are
> [L9 §C–F](09-the-formal-detail.md).

---

## 7.1 The gap the bytecode refinement closes

The abstract proof proves the _algorithm_ is sound (R4a) but says nothing about the EVM. Halmos runs the _real
bytecode_ but only at bounded size (R2). Kontrol/Certora cannot reach the unbounded real machine because of
the assembly barrier (R3). The missing connection — the "abstract-vs-real-machine" gap — is: _does a
validated model of the real machine genuinely run the unbounded loop the way the abstract proof assumes?_

The bytecode refinement answers yes, for all N, by **refinement against a validated EVM semantics**.

**Validated semantics:** NethermindEth's **EVMYulLean** — a Lean 4 formalization of EVM/Yul execution that
is itself **validated against the official Ethereum execution-spec test suites**. So "the EVM model
computes X" inherits the cross-client conformance corpus (the trust chain is [L2 §2.5](02-strategy-and-the-fidelity-ladder.md)).

**Artifact:** [`test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean) — self-contained (it
re-proves every supporting lemma locally, so one `lake env lean` checks it). See
[`test-forge/fv/lean/bytecode-refinement/README.md`](../../test-forge/fv/lean/bytecode-refinement/README.md).

---

## 7.2 What the bytecode refinement proves

A counting accumulation loop is encoded in the **real Yul AST** — `for { } lt(i,N) { i := add(i,1) } { w
:= add(w,i) }` — and run by the validated interpreter. The theorems are all **hole-free** (`#print axioms` ⊆
`[propext, Classical.choice, Quot.sound]`, no `sorryAx`):

| Theorem                                       | Statement (informal)                                                                                                                                                                             |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `loop_acc`                                    | the induction engine: for all iteration counts, the validated `exec` drives the loop and accumulates the abstract accumulator `absAcc`                                                           |
| `bytecode_loop_correct`                       | **∀N**: the validated interpreter runs the loop to completion (exact fuel `3N+10`, no `OutOfFuel`/exception) and the final accumulator equals `absAcc(0,N,0)`                                    |
| `bytecode_threshold_sound`                    | **∀N**: on that validated execution, _accept_ (final weight > `thr`) ⟹ total accumulation > `thr` (in `𝕌`, mod 2²⁵⁶)                                                                             |
| `absAcc_val` / `bytecode_threshold_sound_int` | **∀N**: under the explicit no-overflow hypothesis `Σ < 2²⁵⁶`, the modular accumulator equals the _integer_ accumulator, so _accept_ ⟹ the **integer** total > `thr` (discharges BR-2 — see §7.3) |

`bytecode_threshold_sound` is the abstract proof's `threshold_sound` shape — _accept ⟹ enough accumulated total_ — now
holding of a loop run by a **validated model of the real machine**, for every N. That is the rung-R4
statement.

**The one clever step — _fuel-genericity_.** The interpreter is defined by recursion on a "fuel" step
budget, and EVMYulLean has no fuel-monotonicity lemma, so reasoning at the symbolic fuel arising in the
induction looks blocked. The resolution: prove each statement's effect at fuel `fuel + K` with `fuel` a
free variable and `K` the _exact_ unfolding cost; the simplifier peels exactly `K` steps regardless of
`fuel`. This converts a missing meta-theorem about someone else's interpreter into local, decidable
per-statement facts, and is what made the whole induction routine. Full treatment: [L8 §C.3](08-the-mathematics.md),
[L9 §D](09-the-formal-detail.md). It is reusable on any fuel-indexed interpreter ([L12](12-lessons.md)).

---

## 7.3 Discharging the data layer (BR-1): the memory-reading loop and the full relation `R`

§7.2's loop is _memory-free_ — its body adds the index `i`, which establishes the loop **mechanism**. The
data layer (BR-1) — that each addend is the _registered weight_ `mload(weights[i]) & 0xffff` — was originally
left as a stated assumption. It is now **proven against the validated semantics**, in two committed, hole-free
files.

**The data layer, brick by brick ([`DataLayer.lean`](../../test-forge/fv/lean/bytecode-refinement/DataLayer.lean)).** Each fact is proved about EVMYulLean's _actual_
`ByteArray` / `MachineState` / `UInt256` operations. (Lean 4.22 has no `ByteArray` lemma layer, so the proofs
descend to the `Array.data` level — see [L9](09-the-formal-detail.md).)

| Lemma                                 | What it proves (against the real EVM model)                                                       |
| ------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `fromBytesBigEndian_toBytesBigEndian` | the big-endian byte encode/decode round-trips                                                     |
| `mem_roundtrip`                       | `readWithPadding (write src 0 mem d 32) d 32 = src` — write-a-word-then-read is the identity      |
| `fromByteArray_toByteArray`           | `fromByteArrayBigEndian (v.toByteArray) = v.toNat` (value decode)                                 |
| `mstore_mload`                        | `(mstore a v).mload a = v` — operational round-trip, with the `activeWords`/size guard discharged |
| `mask16_toNat` / `mask16_of_lt`       | `and(x, 0xffff)` extracts the low 16 bits; identity on a 16-bit weight                            |
| `weight_read`                         | the capstone: `mload(slot) & 0xffff = w` for a 16-bit weight stored at a 32-byte slot             |

These add exactly **two specification shapes** beyond the standard three — `zeroes_data` (the `opaque`
`memset_zero`) and `toByteArray_size` (blocked only by a `private` upstream bound). They appear as three
qualified local declarations because the data and window namespaces each declare `zeroes_data`. All are
_access-modifier_ limitations, not semantic assumptions; each becomes a theorem with a one-line upstream edit.

**The memory-reading loop, ∀N ([`RelayLoopMemRead.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopMemRead.lean)).** §7.2's body is replaced by the deployed contract's
_actual_ masked read `w := w + (mload(i·32) & 0xffff)`, executed by the validated Yul `exec`:

- `body_effM` — one iteration of the real `mload`+`and` body (the `mload` is state-preserving once the slot
  is active, so it does not perturb `activeWords`);
- `loop_accM` / `bytecode_threshold_sound_mem` (and its integer form `_int`) — the `3N+15`-fuel induction:
  **∀N**, accept ⟹ the total of the masked _memory reads_ exceeds the threshold.

**The simulation-relation capstone `relay_loop_sound` (the accounting core of `R`).** Composing the EVM
accumulation with the abstract accounting — `bridge` identifies the masked-read sum with the abstract
loop's accumulated weight (`sigLoop`, the in-file restatement of [`RelaySigLoop.loop`](../../test-forge/fv/lean/RelaySigLoop.lean#L67)), and the abstract
`threshold_sound` is restated in-file too (so one `lake env lean` checks the whole chain):

> **∀N: if the modeled deployed signature loop accepts (final weight >
> threshold), total registered policy-slot weight exceeds the threshold, with no
> slot index reused, on the validated EVM.** Unique voter addresses remain MC-3.

All hole-free (`[propext, Classical.choice, Quot.sound]`).

**The assumption boundary.** The behaviour of the external call is an assumption, by design (cryptography is
out of scope, MC-2). `ecrecover` (the `0x01` staticcall) is _not_ modeled; its effect and the strict-index
discipline are the _stated hypotheses_ of `relay_loop_sound`:

- `hcov` — the memory holds the selected weight at each slot (BR-1 data layer; discharged per-slot by `weight_read`);
- `hcorr` — `mrd rdv k = w[idxs[k]]`: the masked read is the registered weight of the voter that signature `k`
  selects — _this is where_ ecrecover→recovered-signer→voter and the calldata decode enter (MC-2 / OP-1);
- `hvalid` — `ValidRun`: strictly-increasing in-range policy-slot indices (the deployed guards passed = no repeated slot; address uniqueness remains an admission premise);
- `hnoovf` — no overflow (BR-2).

Within this abstract model, the loop mechanism, `mload`, mask, accumulation, accept gate, and accounting
soundness are proved against the validated semantics. Connecting those hypotheses to every compiled accepted
execution remains BR-3.

**The literal loop-body model — `hcov`/`hcorr` derived (2026-07-02/03).** The memory-reading loop above uses
an _abstract_ 2-statement body (`body_effM`) that _assumes_ the read is state-preserving and returns the
selected weight (`hcov`/`hcorr`). A companion model now removes those assumptions:
[`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean) — with
[`RelayLoopLiteral.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopLiteral.lean) (the Yul body
hand-transliterated statement-for-statement from `relay_ir_optimized.yul:2159-2202`) and
[`RelayLoopWindows.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopWindows.lean) (the calldata
byte-window decode) — executes the **17-statement body model** `bodyL` through the validated Yul
`exec`, threading modeled `mstore`/`calldatacopy`/`mload` state. The chain, all hole-free
(`[propext, Classical.choice, Quot.sound]`; the accounting-extraction lemmas need only `[propext, Quot.sound]`):

> `body_effL` (one iteration executed) → `s16_ww_advance` / `s16_ii_preserved` (the body adds exactly the
> selected voter's registered weight and preserves the counter) → `iter_advance` (the per-iteration advance
> `hstep`, **derived** from `body_effL` + the extraction) → `range_guard_pass` / `order_guard_pass` /
> `iter_advance_tight` (the two **structural** index guards — range `idx<nVot`, strict-increase `nui≤idx` —
> **derived** from `ValidRun`) → `loop_accL` (the ∀N induction over the literal body, threading the evolving
> memory) → `relay_loop_sound_literal` → `relay_loop_sound_literal_derived` (`hstep` discharged) →
> **`relay_loop_sound_literal_derived_tight`** (tightened top theorem).

The masked read = the selected voter's registered weight is _derived_ (`mload_masked_voter`) from a
raw-calldata memory precondition, so `hcov`/`hcorr` are **no longer assumed**; the structural half of `hvalid`
(index in range, strictly increasing) is _derived_ from `ValidRun`. The only per-iteration hypothesis that
survives (`IterPremiseT`) is exactly the **cryptographic ecrecover facts** (`v ∈ {27,28}`, low-`s`,
`staticcall` success, `returndatasize()==32`, signer ≠ 0, recovered signer = registered voter) plus the
accept gate — i.e. `ecrecover` itself (MC-2, uninterpreted by design), stated explicitly. The accounting
conclusion is identical to `relay_loop_sound`; the assumption surface is strictly smaller — down to the
ecrecover boundary.

---

## 7.4 The honest residual (what is proven vs. assumed)

This is the most important part of the rung for an auditor; the full ledger is [L10](10-claims-ledger-trust-and-residual.md).

- **The data layer (BR-1) is now proven, not assumed** (§7.3). With the memory-reading loop in place, the
  per-step quantity is a genuine `mload(...) & 0xffff` against the validated `MachineState`, not the loop
  index. And the "fully literal EVM model … would _derive_ `hcov`/`hcorr`/`hvalid`" that this bullet used to
  file under _future engineering_ is now **built as a conditional hand-transliterated model** (§7.3,
  `RelayBodyEff.lean`): the literal 17-statement body
  is executed by the validated `exec`, `hcov`/`hcorr` are derived (`mload_masked_voter`), and the structural
  index guards are derived from `ValidRun`. The residual at this rung is therefore _only_ the **external-call
  boundary**: `ecrecover` is uninterpreted (MC-2 / OP-1), supplied as the explicit per-iteration premise
  `IterPremiseT` (the cryptographic guards). The accounting conclusion is unchanged;
  `ecrecover` itself stays an assumption by design.
- **Model-vs-deployed fidelity, made explicit (two BR-3 items a referee should see).**
  1. _The address map — mirrored in the literal model._ The **abstract** model (§7.3) places weight `j`
     memory-resident at slot `j·32`, read once per iteration (`hcov`). The deployed loop instead
     `calldatacopy`s each voter record **from calldata into one fixed scratch slot** (`memPtr+96`) and re-reads
     that same slot every iteration
     ([`Relay.sol:1306-1319`](../../contracts/protocol/implementation/Relay.sol#L1306)). The **literal** model
     (`RelayBodyEff.bodyL`) mirrors this deployed addressing: `body_effL` threads `calldatacopy`
     into the scratch slot and the `mload` back out, and `mload_masked_voter` derives the read _without_ the
     `hcov`/`hcorr` assumption — so the addressing-discipline gap this item flagged for the abstract model is
     closed inside the model. The remaining BR-3 obligation is equivalence between the hand transcription and
     the compiled Yul. (In the abstract model, `weight_read` discharges the read via an `mstore`-then-`mload` round-trip
     while the deployed primitive is `calldatacopy`; both reduce to the same EVMYulLean `ByteArray.write` /
     `mem_roundtrip`, and the literal model takes the `calldatacopy` path directly.)
  2. _The deployed loop exits early — now modeled faithfully._ On-chain, acceptance **returns inside the
     first iteration whose running weight crosses the threshold** (`Relay.sol:1330`). The `relay_loop_sound`
     / `relay_loop_sound_literal` statements run all `N` iterations and examine the _final_ accumulator; that
     transport is sound (non-negative addends + prefix-robust `threshold_sound`, with the per-prefix form
     proven on the real bytecode at bounded K, [`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol#L29)).
     **The early-return is now also modeled directly** ([`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean),
     `relay_loop_sound_literal_early`): `body_effL_accept` executes the body's accept branch — statement 17's
     `if gt(weight,thr) { return(0,0) }` fires — so the body halts with `.error (YulHalt _ ⟨1⟩)`;
     `loop_step_accept` propagates that halt out of the `For`, and `loop_accL_early` runs `t` advancing
     iterations then the accepting one, so the loop **genuinely early-returns** rather than running to
     completion. The capstone concludes both: the loop returns _and_ the total registered policy-slot weight exceeds
     `thr` (via `threshold_sound` on the accepted `(t+1)`-prefix). So this idealization is discharged — the
     early-exit control flow is executed by the validated semantics, not just argued about.
- **Modular vs. integer arithmetic (BR-2) — internalized.** The bytecode refinement reasons in
  `𝕌 = Fin 2²⁵⁶` (mod 2²⁵⁶); the abstract proof in `ℕ`. `bytecode_threshold_sound_int` carries an explicit
  `Σ < 2²⁵⁶` hypothesis and proves (via `absAcc_val`) that the modular accumulator equals the integer
  accumulator, so accept ⟹ the integer total > thr. The hypothesis itself holds for Relay with vast margin
  (`totalWeight < 2¹⁶ ≪ 2²⁵⁶`).
- **Encoding fidelity (BR-3).** The `For` node mirrors the loop's iterate-and-accumulate _skeleton_ (note
  the no-init form, matching the optimizer); it is not a verbatim transcription of the whole signature
  routine (cryptography is out of scope, MC-2; the no-double-count discipline is the abstract proof's
  `ValidRun`).

The bytecode refinement therefore establishes: _the abstract-vs-real bridge for the unbounded loop
mechanism, machine-checked against validated semantics, for all N_ — not "the deployed contract is fully
verified."

---

## 7.5 Beyond the loop — the `relay()` breadth model (R5)

R4b proves conditional properties of the security-critical signature-loop model. **R5** extends the same
validated-EVM method with `relay()` components — **breadth**, not a whole-program refinement theorem.
All results are hole-free and CI-gated with the loop proofs by `verify_lean.py` (§7.6):

- **R5.1 storage round-trip** ([`RelayStorageLayer.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayStorageLayer.lean) `sstore_sload`): `(sstore k v).sload k = v` on EVMYulLean's real `State` — the storage analog of `DataLayer.mem_roundtrip` (needed transferring `TransCmp` for the RBMap key comparators from `Fin`/`Nat` and deriving `find?_erase` on `RBNode`).
- **R5.2 mode dispatch** ([`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean) `dispatch_routes_verify`): `relay()`'s protocolId branching (Relay.sol:894/916) routes faithfully — the modes don't cross-contaminate.
- **R5.3 accept-write** (`RelayStorageLayer.lean` `sstore_eff` + `sstore_reads_back`): the deployed `sstore(merkleRootsPrivate[protocolId][votingRoundId], merkleRoot)` (Relay.sol:1394) stores a value that reads back, under the `perm = true` static-mode guard.
- **R5.3b protocol-1 transient threshold seam** (`RelayStorageLayer.lean`, `RelayBodyEff.lean`): `tstore_tload`, zero clear, address isolation, and opcode dispatch are proved on EVMYulLean's state; `protocolOne_tload_override_loop_sound` composes the loaded nonzero `<10000` BIPS value with the literal strict loop, exact cross-product arithmetic, and no-wrap bound. Its `hsetupThreshold` premise is the explicit, unextracted `TSTORE -> self-call -> TLOAD -> threshold-local` seam; call-frame propagation/rollback is not claimed by Lean.
- **brick 48 — end-to-end composition** (`RelayBodyEff.lean` `CompositionLayer` `relay_dispatch_loop_accept`): from the mode dispatch, `protocolId ≠ 1` routes into the verify branch and — under the loop's ecrecover premises plus a valid policy-slot prefix crossing the threshold — `relay()` halts with the accept `return(0,0)` **and** total registered slot weight > threshold. Unique voter addresses are still MC-3. Combinators `dispatch_then_loop_accept` (verify = the loop) and `dispatch_setup_loop_accept` (verify = `[setupStmt, loopStmt]`, the setup's aggregate state transition carried as an explicit hypothesis — faithful since `setupStmt := Stmt.Block realSetup`).
- **R5.4 fee conservation** ([`RelayFeeLayer.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayFeeLayer.lean)): `fee_conservation` / `fee_conservation_toNat` (`fee + (msg.value − fee) = msg.value`, no under/overflow), `transfer_conservation` (the value-conserving `transferBalance` primitive the Yul `.CALL` performs — the balance analog of `sstore_sload`), `two_transfer_caller_net_zero` (the caller is value-neutral across the two forwards).

Two boundaries are documented, neither touching the core accounting soundness: the exec-level `.CALL` wiring
(`primCall`/`callDispatcher`, the fuel-carrying analog of `sstore_eff`; value conservation is also Halmos-covered
at bounded scope by `RelayVerifyFeeFV`), and reconciling the loop model's D3 deviation (accept → `return` vs. the
deployed break→write→return) so the accept-write folds into the composition. Full walk: [L9 §F.5](09-the-formal-detail.md).

**RLY-23 note (chain-domain binding).** The digest the loop verifies against enters the model as an input
(`prefixedHash` in memory), and the RLY-23 chain-binding keccaks (`keccak256(sourceChainId ‖ ·)` for the policy hash
and the message hash) live in the **pre-loop setup region** — inside `realSetup`, whose aggregate state
transition `dispatch_setup_loop_accept` carries as an explicit hypothesis. The literal loop-body model
(`RelayLoopLiteral`) is therefore **unchanged** — the 17-statement source body is represented by the current
snapshot at `relay_ir_optimized.yul:1518-1632`. The chain-binding of the stored policy hash is instead pinned at R2 by
`RelayPolicyHashFV` (it proves the on-chain `keccak256(sourceChainId ‖ contentFold)` equals the oracle for all symbolic
policies); cross-chain _rejection_ is a cryptographic property proved concretely at R0 (`RelayChainDomain.t.sol`).

---

## 7.6 Status and reproduce

- **Hole-free**, axioms within the manifest allowlist (the data/window files add the three named
  upstream-dischargeable declarations), re-verified from the
  git-committed copies from scratch (`lake env lean`, exit 0).

```bash
# Build the validated semantics (one-time), pinned to the checked commit. See L11 for full detail.
cd /tmp && git clone https://github.com/NethermindEth/EVMYulLean evmyul2
cd evmyul2 && git checkout 047f63070309f436b66c61e276ab3b6d1169265a   # 2025-09-24 (not HEAD)
lake exe cache get && lake build
B=<repo>/test-forge/fv/lean/bytecode-refinement
cp $B/RelayBytecodeRefinement.lean $B/DataLayer.lean $B/RelayLoopMemRead.lean \
   $B/RelayLoopWindows.lean $B/RelayLoopLiteral.lean $B/RelayStorageLayer.lean \
   $B/RelayFeeLayer.lean $B/RelayBodyEff.lean .
lake env lean RelayBytecodeRefinement.lean   # loop mechanism (memory-free), ∀N
lake env lean DataLayer.lean                 # the data layer (byte/memory/value/mask/weight_read)
lake env lean RelayLoopMemRead.lean          # abstract memory-reading loop + relay_loop_sound, ∀N
lake env lean RelayLoopWindows.lean          # calldata byte-window decode
lake env lean RelayLoopLiteral.lean          # hand-transliterated body model + interpreter atoms
lake env lean RelayStorageLayer.lean         # R5.1/5.3 storage round-trip + accept-write reads back
lake env lean RelayFeeLayer.lean             # R5.4 fee conservation + transferBalance
# RelayBodyEff.lean imports three siblings, so compile them into the package lib first:
LIB=.lake/build/lib/lean
for f in DataLayer RelayLoopWindows RelayLoopLiteral; do lake env lean -o $LIB/$f.olean $f.lean; done
lake env lean RelayBodyEff.lean              # LITERAL body + literal capstone + R5 composition, ∀N
# expect exit 0; the loop-mechanism / accounting / literal / R5 theorems print
#   depends on axioms: [propext, Classical.choice, Quot.sound]
# and data/window theorems may list the three qualified local declarations for two spec shapes.

# ...or run the abstract proof + all 8 refinement files and 183 audits in one shot:
EVMYUL_DIR=/tmp/evmyul2 python3 <repo>/test-forge/fv/lean/verify_lean.py
```

---

## 7.7 Where this leaves the stack

The layers now provide strong corroborating evidence, with their different scopes kept explicit:

```
Halmos: the real bytecode obeys the model's prefix-sum invariant (RelayModelBridgeFV), K≤3      [R2]
Abstract proof:        the abstract algorithm is threshold-sound                              ∀N ∀K            [R4a]
Bytecode refinement:   a validated EVM semantics runs the unbounded loop & soundness transfers ∀N              [R4b]
Memory-reading loop:   the body is the real mload(slot)&0xffff; accept ⟹ Σ masked reads > thr  ∀N              [R4b′]
R, accounting core:    deployed loop accepts ⟹ total registered policy-slot weight > thr (relay_loop_sound) ∀N [R4b′; MC-3 for unique addresses]
Literal body model:    hand-transliterated 17-statement body; reads/guards derived, execution premises explicit [R4b″]
                       (relay_loop_sound_literal_derived_tight)
Relay breadth (R5):    conditional dispatch → loop → accept statement                                  ∀N      [R5]
                       + storage round-trip / accept-write (sstore_sload, sstore_reads_back, Relay.sol:1394),
                         mode dispatch (dispatch_routes_verify), fee conservation (fee_conservation, …)
─────────────────────────────────────────────────────────────────────────────────────────────
proved as the stated conditional models on the validated EVM (with 3 allowlisted local declarations),
                       incl. the literal memory reads (hcov/hcorr) and index-range/strict-increase guards
remaining assumptions: crypto (MC-2) = ecrecover, as the per-iteration premise IterPremiseT (OP-1);
                       overflow bound (BR-2, discharged under hnoovf)
```

Loop control flow, memory reads, masks, accumulation, and index-discipline lemmas are machine-checked in
the model. Remaining work includes deriving `ValidRun`, successful early-return acceptance, setup, and the
accept-write from one accepted compiled execution, in addition to the external `ecrecover` boundary.

**Next:** the deep dives — [L8 — the mathematics](08-the-mathematics.md) and
[L9 — the formal detail](09-the-formal-detail.md); or the audit core,
[L10 — claims ledger, trust & residual](10-claims-ledger-trust-and-residual.md).
