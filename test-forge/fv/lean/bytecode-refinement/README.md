# Bytecode-level ∀N refinement (validated EVM/Yul semantics)

`RelayBytecodeRefinement.lean` lifts the abstract signature-loop threshold soundness
(`../RelaySigLoop.lean`, ∀N ∀K) onto a loop executed by NethermindEth's **validated** EVMYulLean
operational semantics, for all N. It is self-contained — every supporting lemma is proved locally, so one
`lake env lean` checks the whole development.

The module has since grown to a full **data layer** and a **literal hand-transliterated body model**:

| File | Role |
|------|------|
| `RelayBytecodeRefinement.lean` | loop *mechanism*, memory-free body, ∀N |
| `DataLayer.lean` | the byte/memory/value/mask data layer (`weight_read`) against EVMYulLean's real `ByteArray`/`MachineState` |
| `RelayLoopMemRead.lean` | abstract memory-reading loop + `relay_loop_sound` (accept ⟹ total registered weight > thr, ∀N; assumes `hcov`/`hcorr`) |
| `RelayLoopLiteral.lean` | the hand-transliterated body model sourced from the optimized-Yul loop beginning at `relay_ir_optimized.yul:2008`, with deviations D1-D4 documented in the file, + reusable interpreter atoms and abstract accounting |
| `RelayLoopWindows.lean` | the calldata byte-window decode layer |
| `RelayBodyEff.lean` | composes the literal model into `relay_loop_sound_literal_derived_tight`; reads and structural guards are derived from explicit model preconditions, while ecrecover and model-to-deployment fidelity remain boundaries |
| `RelayStorageLayer.lean` | storage round-trip and accept-write components |
| `RelayFeeLayer.lean` | fee and balance-transfer conservation components |

`RelayBodyEff.lean` is the one file that `import`s its siblings; checking it needs them compiled into the
package lib first (see *Checking it*). The rest are each self-contained (`lake env lean <file>`).

## What is proved (all hole-free)

Every audited result is hole-free. Its `#print axioms` output is a subset of
`[propext, Classical.choice, Quot.sound]`, except for the three explicitly allowlisted and
upstream-dischargeable data/window specifications (no `sorry`/`sorryAx` or `native_decide`):

- `loop_acc` — induction on the iteration count: the validated `exec` drives the encoded `for` loop and
  accumulates `absAcc`.
- `bytecode_loop_correct` — ∀N < 2²⁵⁶: the interpreter runs the loop to completion with exact fuel
  `3N+10` (no `OutOfFuel`, no exception) and the final accumulator equals `absAcc 0 N ⟨0⟩`.
- `bytecode_threshold_sound` — ∀N: on that validated execution, accept (final weight > `thr`) ⟹ total
  accumulated weight > `thr` (in `𝕌`, mod 2²⁵⁶).
- `absAcc_val` / `bytecode_threshold_sound_int` — ∀N: under the explicit no-overflow hypothesis
  `Σ < 2²⁵⁶`, the modular accumulator equals the *integer* accumulator, so accept ⟹ the **integer** total
  > `thr`. This discharges the BR-2 (overflow-bound) assumption inside Lean.

## Scope and assumptions

The `RelayBytecodeRefinement.lean` loop is **memory-free**: its body adds the loop index, not a value
loaded from memory. This establishes the loop *mechanism* — that the validated semantics iterates ∀N and
faithfully folds a per-step quantity, and that threshold soundness transfers — on the real-machine
semantics. For that file alone the remaining facts below are stated assumptions. The sibling files discharge
important pieces inside their stated models; connecting the hand-transliterated model to every accepted
compiled execution remains BR-3. All boundaries are registered in the claims ledger
(`../../../../docs/relay-verification/10-claims-ledger-trust-and-residual.md`):

- the **data layer** — each addend is the registered weight `mload(weights[i])` — **discharged**
  (`DataLayer.weight_read`; derived end-to-end in the literal model, `mload_masked_voter`);
- the **overflow bound** — sums stay below 2²⁵⁶ — **discharged under `hnoovf`** (`bytecode_threshold_sound_int`);
- **encoding fidelity** — does the modeled loop match the deployed one? — **partially closed**: compiler
  artifacts and optimized Yul are provenance-gated, and early return is modeled, but `bodyL` remains a hand
  transcription with D1-D4 deviations and no AST-equivalence proof;
- **EVMYulLean is the EVM** — validated against the Ethereum execution-spec test suites (permanent A-EVM).

## Checking it

```bash
# build the validated semantics once, PINNED to the commit these proofs were checked against:
git clone https://github.com/NethermindEth/EVMYulLean /tmp/evmyul2
cd /tmp/evmyul2 && git checkout 047f63070309f436b66c61e276ab3b6d1169265a   # 2025-09-24 (not HEAD)
lake exe cache get && lake build                         # Lean 4.22.0 (from lean-toolchain)
# check the files against it:
B=<repo>/test-forge/fv/lean/bytecode-refinement
cp $B/RelayBytecodeRefinement.lean $B/DataLayer.lean $B/RelayLoopMemRead.lean \
   $B/RelayLoopWindows.lean $B/RelayLoopLiteral.lean $B/RelayBodyEff.lean \
   $B/RelayStorageLayer.lean $B/RelayFeeLayer.lean /tmp/evmyul2/
cd /tmp/evmyul2
lake env lean RelayBytecodeRefinement.lean               # exit 0; prints the clean axiom lists
lake env lean DataLayer.lean
lake env lean RelayLoopMemRead.lean
lake env lean RelayLoopWindows.lean
lake env lean RelayLoopLiteral.lean
lake env lean RelayStorageLayer.lean
lake env lean RelayFeeLayer.lean
# RelayBodyEff.lean imports the three siblings, so compile them into the package lib first
# (a plain LEAN_PATH prepend does NOT work — Lean won't fall through to it):
LIB=.lake/build/lib/lean
for f in DataLayer RelayLoopWindows RelayLoopLiteral; do lake env lean -o $LIB/$f.olean $f.lean; done
lake env lean RelayBodyEff.lean                          # literal model + relay_loop_sound_literal_derived_tight
```

**Automated, and CI-gated.** [`../verify_lean.py`](../verify_lean.py) runs all of the above and enforces
hole-freeness — it fails on any `lake` error, any `sorry`/`admit`/`native_decide`, an inventory mismatch, or
any `#print axioms` result outside the exact manifest allowlist. The only local declarations allowed are
`RelayDataLayer.zeroes_data`, `RelayDataLayer.toByteArray_size`, and `RelayWindows.zeroes_data`; a proof that
still builds but acquired a new assumption therefore fails independently of Lake's own reporting. CI
runs it in the `test-fv-lean` job (`.gitlab-ci.yml`, gated on changes under this directory), the Lean
counterpart of `test-fv-halmos`:

```bash
# after building the pinned EVMYulLean at $EVMYUL_DIR (as above):
EVMYUL_DIR=/tmp/evmyul2 python3 test-forge/fv/lean/verify_lean.py   # exit 0 = all hole-free
```

Full narrative, the fuel-genericity technique, and the verbatim walk-through:
`../../../../docs/relay-verification/` (levels 07–09).

## Discharging the data-layer assumption (BR-1) inside the stated models

The `RelayBytecodeRefinement.lean` proof is memory-free (its body adds the loop index). Replacing the index
with the modeled memory read and proving `mload(weights[i]) = w[i]` discharges the data-layer obligation
inside the stated model. It does not close BR-3, which still requires connecting the hand transcription to
compiled accepted executions. The trail below records how the model was built; two concrete starting points
opened it:

**1. Locate the real loop in the compiled Yul (BR-3).** `forge inspect Relay irOptimized` emits the
optimized IR (~3700 lines, with `@src` source-maps back to `Relay.sol`). The signature loop is a
`for { } … { }` block, recognizable by the masked weight read `and(mload(...), 0xffff)` (`Relay.sol:1327`),
the `staticcall(... 0x01 ...)` ecrecover, the strict-index guard, and the accept gate. A snapshot is
committed at `test-forge/fv/lean/relay_ir_optimized.yul`. Proving the encoded `For` node refines that block
closes BR-3.

**2. The full-fidelity simulation relation (BR-1).** Extend the refinement with a relation
`R s (w, sigs, weight, nui)` tying the EVMYulLean `State` to the abstract state:

- the calldata signing-policy region decodes to weights `w` (each lane `& 0xffff`);
- the calldata signature region decodes to the index stream `sigs`;
- the loop locals hold `weight` and `nextUnusedIndex`;
- `ecrecover` (`0x01`) is the uninterpreted matcher (assumptions MC-2 / OP-1).

Then prove `exec` of the loop preserves `R` with `(weight', nui') = RelaySigLoop.loop w weight nui sigs`,
and transfer [`RelaySigLoop.threshold_sound`](../RelaySigLoop.lean#L102) through it. **Progress + feasibility (investigated):**
- *Byte-decode layer — ✅ done.* `DataLayer.lean` proves the big-endian round-trip
  (`fromBytesBigEndian_toBytesBigEndian`) about EVMYulLean's real functions, hole-free (reuses EVMYulLean's
  existing `@[simp] fromBytes'_toBytes'`; the padding/bounds lemmas also exist upstream).
- *Whole ByteArray/memory layer — ✅ done.* `DataLayer.lean` proves `keystone` (the `copySlice→extract`
  round-trip, no axioms beyond the standard three) and `mem_roundtrip`
  (`readWithPadding (write src 0 mem d 32) d 32 = src`) — i.e. write-a-32-byte-word-then-read is the
  identity, against EVMYulLean's actual `ByteArray.write`/`readWithPadding`. The heart of `mload∘mstore`.
  Lean 4.22 has no ByteArray lemma layer, so the proofs reduce via `ByteArray.ext` to `Array.data`. One
  documented axiom: `zeroes_data` (minimal spec for the `opaque` `memset_zero`; dischargeable upstream).
- *Value decode — ✅ done.* `DataLayer.lean` proves `fromByteArray_toByteArray`
  (`fromByteArrayBigEndian (v.toByteArray) = v.toNat`) against EVMYulLean's real `fromByteArrayBigEndian`
  and `UInt256.toByteArray`, hole-free (only `zeroes_data` beyond the standard three).
- *MachineState `mstore`/`mload` wrapping — ✅ done.* `DataLayer.lean` proves `mstore_lookupMemory` and
  `mstore_mload`: on EVMYulLean's validated `MachineState`, `(mstore a v).mload a = v` whenever the buffer
  has room and the active-word count does not overflow. This discharges the `lookupMemory` guard
  (`addr ≥ memory.size ∨ addr ≥ activeWords*32`) and composes the byte layer — the operational
  `mload∘mstore = id` for a 32-byte word. The conditional core rests on `zeroes_data` alone; the
  unconditional form adds one sibling documented axiom `toByteArray_size` (verified provable, blocked
  downstream only by the `private` upstream bound `toBytes'_UInt256_le`). The exact upstream patches and
  the verified discharge proofs for **both** axioms are archived in
  [`AXIOM_DISCHARGE.md`](AXIOM_DISCHARGE.md) — reproducible, not anecdotal.
- *Weight mask — ✅ done.* `DataLayer.lean` proves `mask16_toNat` (`and(x, 0xffff) = x mod 2¹⁶`, the
  masked weight read at `Relay.sol:1327`) and `mask16_of_lt` (the mask is the identity on a 16-bit
  registered weight), hole-free with *no* axioms beyond the standard three.
- *Data-layer capstone — ✅ done.* `DataLayer.lean:weight_read` composes the whole bounded stack: a 16-bit
  weight written to a 32-byte slot is recovered by the deployed read pattern `and(mload(slot), 0xffff)`
  under EVMYulLean's validated `MachineState` — i.e. `mload(weights[i]) & 0xffff = w[i]` for one slot, the
  heart of BR-1.
- *Memory-reading loop refinement — ✅ done (`RelayLoopMemRead.lean`).* The `For`-node loop body uses the
  contract's **masked weight-read pattern** `w := w + (mload(slot) & 0xffff)`, executed by the
  validated Yul `exec` for **all N**. `bytecode_threshold_sound_mem` (and its integer form
  `bytecode_threshold_sound_mem_int`): accept ⟹ the total of the masked memory reads exceeds the threshold —
  hole-free, *no* axioms beyond the standard three. The key brick `body_effM` proves one iteration of the
  `mload`+`and` body on the real semantics (the `mload` is state-preserving once the slot is active, so it
  does not perturb `activeWords`); `loop_accM` runs the `3N+15`-fuel induction.
- *Simulation relation `R`, accounting core — ✅ done (`RelayLoopMemRead.lean:relay_loop_sound`); the
  selection/validity half of `R` is assumed (see below).* Composes the EVM
  accumulation with the abstract loop: ∀N, **if the modeled loop accepts under its hypotheses, the total registered voting weight
  exceeds the threshold** (no voter double-counted), on the validated EVM. The `bridge` lemma identifies the
  integer masked-read accumulator with the abstract `sigLoop` accumulated weight; the abstract
  `sumTake`/`sigLoop`/`ValidRun`/`threshold_sound` are restated here (identical to `../RelaySigLoop.lean`) so
  one `lake env lean` checks the whole chain. The **behaviour of the external call is an assumption**, as
  throughout the engagement: ecrecover (the `0x01` staticcall) is *not* modeled; its effect (signature `k`
  selects voter `idxs[k]`, whose registered weight is the addend) and the strict-index discipline are the
  stated hypotheses `hcov` / `hcorr` / `hvalid` / `hnoovf` (MC-2 / OP-1 / BR-1 / BR-2). `hcorr` is discharged
  per-slot by `DataLayer.weight_read`. Within this model, the loop mechanism, `mload`, mask, accumulation,
  accept gate, and accounting soundness are proved against the validated semantics.
- *Literal conditional body model — ✅ checked as stated (`RelayBodyEff.lean`, with `RelayLoopLiteral.lean` +
  `RelayLoopWindows.lean`; 2026-07-02/03).* The "remaining, optional" item above is built. It executes the
  **17-statement hand-transliterated body model** `bodyL`, sourced from the optimized-Yul signature loop
  beginning at `relay_ir_optimized.yul:2008` — through the validated Yul `exec`, threading modeled
  `mstore`/`calldatacopy`/`mload` state (no `hcov` state-preservation assumption). The chain, all hole-free:
  `body_effL` (one iteration) → `s16_ww_advance`/`s16_ii_preserved` (the body adds exactly the selected
  voter's registered weight, preserves the counter) → `iter_advance` (the per-iteration advance `hstep`,
  **derived**) → `range_guard_pass`/`order_guard_pass`/`iter_advance_tight` (the structural index guards
  **derived** from `ValidRun`) → `loop_accL` (the ∀N induction) → `relay_loop_sound_literal` →
  `relay_loop_sound_literal_derived` → **`relay_loop_sound_literal_derived_tight`**. The masked read = the
  selected voter's registered weight is **derived** (`mload_masked_voter`), so `hcov`/`hcorr` are no longer
  assumed; the structural half of `hvalid` is **derived** from `ValidRun`. The only surviving per-iteration
  hypothesis (`IterPremiseT`) is the cryptographic `ecrecover` facts (MC-2, uninterpreted by design) + the
  accept gate. Same accounting conclusion as `relay_loop_sound`; strictly smaller assumption surface. See
  L7 §7.3–7.4 and L10 §10.5.

## R5 (`relay()` breadth model) build plan

The signature-loop accounting core is established at R4b under the theorem's hypotheses. R5 adds
storage/dispatch/write breadth, but is not a byte-complete refinement of `relay()`:

- **R5.1 — storage layer — ✅ done** (`RelayStorageLayer.lean`): `sstore_sload` round-trip
  `(sstore k v).sload k = v` on EVMYulLean's real `State` (the storage analog of `DataLayer.mem_roundtrip`).
  The pinned obstacle is discharged: `TransCmp` for the key comparators is transferred from `Fin`/`Nat`
  (the derived `Ord` collapses `(compare a.val b.val).then .eq` to `Fin`'s comparator), and `find?_erase`
  (absent in Batteries) is derived bottom-up on `RBNode`. Hole-free.
- **R5.2 — mode dispatch — ✅ done** (`RelayBodyEff.lean`, `DispatchLayer`): `dispatch_routes_verify` proves
  `relay()`'s protocolId branching (Relay.sol:894/916) routes faithfully — the modes don't cross-contaminate.
- **R5.3 — accept-write reads back — ✅ done** (`RelayStorageLayer.lean`): `sstore_eff` (exec-level `SSTORE`
  with the `perm=true` static-mode guard) + `sstore_reads_back` — executing the accept-branch write
  `sstore(merkleRootsPrivate[protocolId][votingRoundId], merkleRoot)` (Relay.sol:1394) stores a value that
  reads back, via `sstore_sload`.
- **R5.4 — fees — ✅ done** (`RelayFeeLayer.lean`): `verify()` fee conservation. Word- and integer-level
  `fee + (msg.value − fee) = msg.value` with no under/overflow (`fee_conservation` / `fee_conservation_toNat`),
  the `transferBalance` value-conservation primitive (`transfer_conservation` — the balance analog of
  `sstore_sload`, and exactly what the Yul `.CALL` performs at `Interpreter.lean:78`), and the caller
  net-zero across the two forwards (`two_transfer_caller_net_zero`). The exec-level `.CALL` wiring
  (`primCall`/`callDispatcher`, the fuel-carrying analog of `sstore_eff`) is the documented remaining
  boundary; value conservation is also Halmos-covered at bounded scope by `RelayVerifyFeeFV`.
- **brick 48 — end-to-end composition — ✅ done** (`RelayBodyEff.lean`, `CompositionLayer`): stitches R5.2 +
  the loop capstone into a single top-level accept statement. `relay_dispatch_loop_accept` — from the mode
  dispatch, `protocolId ≠ 1` routes into the verify branch, and under the loop's iteration premises
  (ecrecover boundary) plus a valid signer prefix crossing threshold, `relay()` halts with the accept
  `return(0,0)` **and** total registered weight > threshold. Two combinators expose the modeling boundary
  honestly: `dispatch_then_loop_accept` (verify = the loop; setup elided) and `dispatch_setup_loop_accept`
  (verify = `[setupStmt, loopStmt]`, the setup's aggregate state transition carried as an explicit
  hypothesis — faithful since `setupStmt := Stmt.Block realSetup` is one `Stmt`). The accept-*write* (R5.3)
  stays separate because the loop model's D3 deviation returns on accept rather than break-then-write;
  reconciling D3 is the last remaining end-to-end gap.

All landed steps are hole-free (`{propext, Classical.choice, Quot.sound}`) and gated by `../verify_lean.py`.
The accounting-soundness property is already covered by the loop; R5 adds breadth (mode-specific effects),
not a new soundness fact. `ecrecover` stays MC-2 throughout.
