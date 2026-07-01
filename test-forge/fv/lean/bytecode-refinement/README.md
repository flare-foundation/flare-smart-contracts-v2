# Bytecode-level ∀N refinement (validated EVM/Yul semantics)

`RelayBytecodeRefinement.lean` lifts the abstract signature-loop threshold soundness
(`../RelaySigLoop.lean`, ∀N ∀K) onto a loop executed by NethermindEth's **validated** EVMYulLean
operational semantics, for all N. It is self-contained — every supporting lemma is proved locally, so one
`lake env lean` checks the whole development.

## What is proved (all hole-free)

`#print axioms` for each is exactly `[propext, Classical.choice, Quot.sound]` (no `sorry`/`sorryAx`, no
`native_decide`, no extra axiom):

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

The encoded loop is **memory-free**: its body adds the loop index, not a value loaded from memory. This
establishes the loop *mechanism* — that the validated semantics iterates ∀N and faithfully folds a
per-step quantity, and that threshold soundness transfers — on the real-machine semantics. The remaining
facts are stated assumptions, discharged by other evidence and registered in the claims ledger
(`../../../../docs/relay-verification/10-claims-ledger-trust-and-residual.md`):

- the **data layer** — each addend is the registered weight `mload(weights[i])`;
- the **overflow bound** — sums stay below 2²⁵⁶ (so the `𝕌` result equals the integer result);
- **encoding fidelity** — the `for` node mirrors the deployed loop's iterate-and-accumulate skeleton;
- **EVMYulLean is the EVM** — validated against the Ethereum execution-spec test suites.

## Checking it

```bash
# build the validated semantics once, PINNED to the commit these proofs were checked against:
git clone https://github.com/NethermindEth/EVMYulLean /tmp/evmyul2
cd /tmp/evmyul2 && git checkout 047f63070309f436b66c61e276ab3b6d1169265a   # 2025-09-24 (not HEAD)
lake exe cache get && lake build                         # Lean 4.22.0 (from lean-toolchain)
# check this file against it:
cp <repo>/test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean /tmp/evmyul2/
lake env lean RelayBytecodeRefinement.lean               # exit 0; prints the three clean axiom lists
```

Full narrative, the fuel-genericity technique, and the verbatim walk-through:
`../../../../docs/relay-verification/` (levels 07–09).

## Future work: discharging the data-layer assumption (BR-1)

The proof above is memory-free (its body adds the loop index). Replacing the index with the real memory
read and proving `mload(weights[i]) = w[i]` would discharge **BR-1** (and most of **BR-3**, encoding
fidelity). Two concrete starting points:

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
and transfer `RelaySigLoop.threshold_sound` through it. **Progress + feasibility (investigated):**
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
  downstream only by the `private` upstream bound `toBytes'_UInt256_le`).
- *Weight mask — ✅ done.* `DataLayer.lean` proves `mask16_toNat` (`and(x, 0xffff) = x mod 2¹⁶`, the
  masked weight read at `Relay.sol:1327`) and `mask16_of_lt` (the mask is the identity on a 16-bit
  registered weight), hole-free with *no* axioms beyond the standard three.
- *Data-layer capstone — ✅ done.* `DataLayer.lean:weight_read` composes the whole bounded stack: a 16-bit
  weight written to a 32-byte slot is recovered by the deployed read pattern `and(mload(slot), 0xffff)`
  under EVMYulLean's validated `MachineState` — i.e. `mload(weights[i]) & 0xffff = w[i]` for one slot, the
  heart of BR-1.
- *Memory-reading loop refinement — ✅ done (`RelayLoopMemRead.lean`).* The `For`-node loop body is the
  deployed contract's **actual masked weight read** `w := w + (mload(slot) & 0xffff)`, executed by the
  validated Yul `exec` for **all N**. `bytecode_threshold_sound_mem` (and its integer form
  `bytecode_threshold_sound_mem_int`): accept ⟹ the total of the masked memory reads exceeds the threshold —
  hole-free, *no* axioms beyond the standard three. The key brick `body_effM` proves one iteration of the
  `mload`+`and` body on the real semantics (the `mload` is state-preserving once the slot is active, so it
  does not perturb `activeWords`); `loop_accM` runs the `3N+15`-fuel induction.
- *Full simulation relation `R` — ✅ done (`RelayLoopMemRead.lean:relay_loop_sound`).* Composes the EVM
  accumulation with the abstract loop: ∀N, **if the deployed loop accepts, the total registered voting weight
  exceeds the threshold** (no voter double-counted), on the validated EVM. The `bridge` lemma identifies the
  integer masked-read accumulator with the abstract `sigLoop` accumulated weight; the abstract
  `sumTake`/`sigLoop`/`ValidRun`/`threshold_sound` are restated here (identical to `../RelaySigLoop.lean`) so
  one `lake env lean` checks the whole chain. The **behaviour of the external call is an assumption**, as
  throughout the engagement: ecrecover (the `0x01` staticcall) is *not* modeled; its effect (signature `k`
  selects voter `idxs[k]`, whose registered weight is the addend) and the strict-index discipline are the
  stated hypotheses `hcov` / `hcorr` / `hvalid` / `hnoovf` (MC-2 / OP-1 / BR-1 / BR-2). `hcorr` is discharged
  per-slot by `DataLayer.weight_read`. Everything else — the loop mechanism, the `mload`, the mask, the
  accumulation, the accept gate, and the accounting soundness — is *proven* against the validated semantics.
- *Remaining (engineering, not new facts):* a fully literal end-to-end EVM model of the *rest* of the body
  (the `staticcall` plumbing, calldatacopy, the per-guard reverts, the early-return) would let `hcov`/`hcorr`/
  `hvalid` be *derived* from a raw-calldata precondition rather than assumed — but ecrecover itself stays an
  assumption (MC-2), and the accounting result above does not change. See L10 §10.5.
