# L10 — Claims ledger, trust & residual

> **What you get from this level — the audit core.** A single, traceable register of *everything*: each
> claim → the tool/rung that establishes it → its object and coverage → proven/assumed/blocked → the exact
> evidence artifact → the assumptions it relies on. Plus the standing **modeling contract**, the **trust
> chain**, the **residual** (with a leverage-ordered checklist), and an explicit **"what is not claimed."**
> If you cite this engagement, cite it from here. This level discharges every "⚠ caveat" raised above.

**Convention.** *Proven* = a machine-checked artifact whose statement is the claim, at the bar its tool
defines (§10.1). *Assumed* = a hypothesis not discharged by the tool, justified separately and registered
in §10.2. *Blocked* = specified but not dischargeable by the chosen tool (with the reason).

---

## 10.1 The per-tool "proven" bar

| Rung | "Proven" means |
|------|----------------|
| R0/R1 Foundry | test passes (concrete) / no counterexample over the fuzz budget (random) |
| R2 Halmos | `check_*` proof passes with **no counterexample** AND its paired `reach` control **produces** a counterexample (non-vacuous), under `loop=6`; judged by `verify_fv.py` |
| R3 Kontrol | every manifest-listed proof passes and every listed reachability control has a concrete counterexample model in Kontrol's JUnit report, under Kontrol 1.0.248; exact inventory and process status enforced by `verify_kontrol.py` |
| R3 Certora | rule passes on the cloud prover **non-vacuously** (`rule_sanity basic`); reached 2026-07 for every function except `relay()` (C-1, narrowed) |
| R4 Lean | manifest-listed theorem whose statement *is* the claim; exact file/audit inventory; no `sorry`/`admit`/`native_decide`; `#print axioms` limited to the standard three plus the three named local declarations in §11.8 |

---

## 10.2 The assumption register (the trusted surface)

Four groups: the **modeling contract** (cryptographic / trust, by design), the **operational boundary-call
contracts** (the EVM-level behavior of every external/precompile call), the **bytecode-refinement
residuals**, and the **tool-coverage limits**.

### Modeling contract — cryptographic & trust (MC)

| ID | Assumption | Justification |
|----|-----------|---------------|
| **MC-1** | `keccak256` is an injective uninterpreted function (collision-resistance) | curve/hash math is not an EVM-level fact; proving it would be circular |
| **MC-2** | `ecrecover` recovery is *mathematically* unforgeable: one cannot produce `(v,r,s)` recovering to an address whose key one does not hold (ECDSA security) | cryptographic assumption outside the EVM; the on-chain half (weight credited to `voters[i]` only when the recovered signer equals `voters[i]`, each index once) is **proven** |
| **MC-3** | the signing-policy setter (FlareSystemsManager) supplies distinct, non-zero, canonically-ordered voters with normalized weights; `startingVotingRoundId` non-decreasing (**RLY-06**) | documented, not on-chain-enforced; [`docs/relay-phase3-documented-items.md`](../relay-phase3-documented-items.md) |
| **MC-4** | OZ `MerkleProof.verifyCalldata` internals are correct (call-site in scope) | audited library |
| **MC-5** | `oldRelay` is a trusted, audited prior deployment; its return values are honest | deployment assumption |

### Operational boundary-call contracts (OP) — the EVM-level behavior of each external call

Each row states the **operational contract** of a boundary call, the **code-side obligation** that makes
the contract safe, and **how that obligation is verified**. These are distinct from the mathematical
assumptions above: they are about *EVM/ABI behavior*, not cryptography.

| ID | Boundary (site) | Operational contract | Required code-side obligation | Verified by |
|----|-----------------|----------------------|-------------------------------|-------------|
| **OP-1** | `ecrecover` precompile `0x01` — raw `staticcall` ([`Relay.sol:1284`](../../contracts/protocol/implementation/Relay.sol#L1284)) | **does not revert on a bad signature**: the `staticcall` returns *success* with **empty** return data (`returndatasize()==0`) and leaves the output buffer **unmodified** (stale-read hazard); returns 32 bytes only on a valid recovery | the call site **must** check (a) `staticcall` success, (b) **`returndatasize()==32`**, and (c) recovered signer `≠ 0` — all three are present (`"ecrecover error"`, `"ecrecover returned bad data"`, `"Zero signer"`). **Load-bearing: must never be removed.** | **[`test-forge/fv/RelayEcrecoverABI.t.sol`](../../test-forge/fv/RelayEcrecoverABI.t.sol)** — a real-EVM regression that pins the empty-return/stale-buffer ABI and that the `returndatasize()==32` guard rejects a bad signature — **and [`test-forge/fv/RelayEcrecoverSymbolicFV.t.sol`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol)**, which internalizes the same obligation *symbolically* (Halmos, over all stale-buffer contents) — plus Foundry/Hardhat failure-path tests + assembly review ([`docs/relay-assembly-review.md`](../relay-assembly-review.md)); and **cross-checked against the pinned client precompile source** (go-flare → coreth → libevm `1bccf4f2ddb2`) in [L13 §13.8](13-residual-weaknesses.md#138-appendix--op-1-cross-checked-against-the-deployed-client-ecrecover-precompile). |
| **OP-2** | `keccak256` (`SHA3` opcode) | total & deterministic; cannot return malformed output or "fail" (only out-of-gas) | none beyond gas | inherent (opcode); MC-1 supplies the algebraic model |
| **OP-3** | `oldRelay.*` external calls, incl. value-bearing `oldRelay.verify{value: oldFee}(…)` (`Relay.sol:1567`) | a real cross-contract call that **may revert** and **may re-enter** `Relay`; forwards value | revert is propagated (`require(success,…)` on the relayed path); re-entrancy is benign (re-entered paths write no fee/nonce/root state — R1/R2); fee is forwarded exactly (M-1) | code review ([`docs/relay-security-review.md`](../relay-security-review.md)) + Foundry (`RelayVerifyFeeFV`, fee/old-relay tests); MC-5 supplies return-value trust |
| **OP-4** | self-call `address(this).call(_relayMessage)` (`Relay.sol:1730`, `_verifyCustomSignature`) | ordinary external call to self: returns `(success, returnData)`; re-enters the `relay()` path | `require(success)` + `require(returnData.length == 35)` (the RLY-07 mode-1 discriminator) | Foundry custom-signature tests + review |
| **OP-5** | precompile **surface bound** | the **only** precompile used is `0x01`; no `sha256 (0x02)`, identity, modexp, or EC ops are called | n/a (bounds which OP-contracts are in play) | assembly review (`docs/relay-assembly-review.md`) |

> **FV modelling note (OP-1).** Halmos's *built-in* `0x01` is a *total* function that always returns a
> well-formed 32-byte address (`E(hash,v,r,s) → address`, `returndatasize()==32`), so the whole-`relay()`
> symbolic runs do not, by themselves, exercise the OP-1 failure mode (empty return / stale buffer) — using
> the adversary-conservative uninterpreted recovery for the *accounting* proofs. The failure mode is now
> **internalized symbolically** by `RelayEcrecoverSymbolicFV.t.sol`: it reaches the empty-return branch via a
> mock that reproduces the precompile's failure ABI and proves — over ALL stale-buffer contents — that the
> `staticcall`-success / `returndatasize()==32` / non-zero-signer guard rejects a bad signature and never
> reads the stale buffer. Together with the real-EVM regression (`RelayEcrecoverABI.t.sol`, which pins that
> the *actual* `0x01` exhibits this ABI), OP-1 is discharged both symbolically and concretely.
> **Scope precision:** the symbolic harness proves the guard **pattern** — a faithful *mirror* of
> `Relay.sol:1283-1302`, re-implemented in the harness — not Relay's deployed guard bytes themselves; the
> identification "Relay's assembly implements exactly this pattern" rests on the assembly review
> ([`docs/relay-assembly-review.md`](../relay-assembly-review.md)) and the concrete failure-path tests. Any
> change to the `ecrecover` block must re-establish OP-1.

### Bytecode-refinement residuals (BR) — the R4b model-to-deployment gap

| ID | Assumption | Status |
|----|-----------|--------|
| **BR-1** | data layer: each modeled iteration's addend is the registered weight of the selected voter | **derived inside the literal model.** [`RelayLoopMemRead.relay_loop_sound`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopMemRead.lean#L454) assumes read/weight correspondence; [`RelayBodyEff.relay_loop_sound_literal_derived_tight`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean#L1674) derives the masked read from its raw-calldata/memory preconditions. Residual: connect those preconditions, `ValidRun`, and acceptance to every accepted compiled execution, plus ecrecover (MC-2/OP-1). |
| **BR-2** | overflow bound: sums don't wrap 2²⁵⁶ (so `𝕌`-results = integer results) | **internalized in Lean** (`absAcc_val` / `bytecode_threshold_sound_int`): under the explicit hypothesis `Σ < 2²⁵⁶`, the modular accumulator equals the integer accumulator and accept ⟹ *integer* total > thr. The hypothesis holds with vast margin (`totalWeight < 2¹⁶`). |
| **BR-3** | encoding fidelity: does the modeled loop match the deployed one? | **partially closed and provenance-gated.** The optimized Yul snapshot is now regenerated byte-for-byte from pinned solc 0.8.27 and its metadata-stripped bytecode matches the Hardhat deployment artifact. `bodyL` remains a hand transcription with D1–D4 deviations; no parser/extractor proves AST equivalence, and successful accepted-execution premises remain hypotheses. |

### Tool-coverage limits

| ID | Limitation | Status |
|----|-----------|--------|
| **K-1** | Kontrol base+step compose to ∀K at the *meta* level (no native loop-invariant rule in 1.0.248) | each piece machine-checked; composition by standard induction. Subsumed by the abstract Lean proof (internal induction) |
| **K-2** | Kontrol checks a faithful Solidity *model*, not the inline-assembly bytecode | bytecode side at K≤3 via Halmos `RelaySigParamFV`; tied by `RelayModelBridgeFV`; full bridge = future bmc-depth-1 obligation ([`docs/relay-t1-bridge.md`](../relay-t1-bridge.md)) |
| **C-1** | Certora storage invariants vs. assembly storage (historically: analysis-failure havoc → spurious violations) | **narrowed (2026-07)**: with the storage-splitting analysis disabled, all 5 invariants are cloud-proven for every function except `relay()` (legacy codegen; via-ir also excepts `setSigningPolicy`) — `relay()` is vacuous in that model (visible no-coverage, not false alarms) and stays covered per-sequence at R2 + by the Lean literal model. Mechanics + run matrix: [`certora/README.md`](../../certora/README.md) |
| **A-EVM** | EVMYulLean *is* the EVM | two parts of different strength ([L2 §2.5](02-strategy-and-the-fidelity-ladder.md)): the **opcode/memory layer** the proofs use (shared `step` dispatch, `MachineState`) sits on the path validated against the Ethereum execution-spec suites; the **Yul control-flow layer** (`Yul.exec`/`loop`, fuel) that drives the R4b proofs is Yul-specific, validated separately by Yul semantic tests (not provable; standard residual) |

---

## 10.3 The master claims ledger

Each row: the property, the strongest rung that establishes it, the object/coverage there, the evidence
artifact, and the assumptions it leans on. Lower rungs often corroborate the same property at higher
fidelity / lower coverage (noted).

| # | Property | Strongest rung | Object · coverage | Status | Evidence | Relies on |
|---|----------|----------------|-------------------|--------|----------|-----------|
| 1 | **Threshold soundness** (accept ⟹ enough distinct weight, no double-count) | R4a Lean | abstract algorithm · **∀N∀K** | **proven** (`[propext,Quot.sound]`) | [`RelaySigLoop.lean:threshold_sound`](../../test-forge/fv/lean/RelaySigLoop.lean) | MC-1,2,3 |
| 1b | same, on **validated EVM semantics** (loop mechanism) | R4b Lean | validated EVM · **∀N** | **proven** (`[propext,choice,Quot.sound]`) | [`bytecode-refinement/RelayBytecodeRefinement.lean:bytecode_threshold_sound`](../../test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean) | + BR-1,2,3, A-EVM |
| 1b′ | same, on the **literal hand-transliterated 17-statement body model**; memory reads and index guards derived | R4b Lean | validated EVM · **∀N**, conditional execution | **proven as stated** (`[propext,choice,Quot.sound]`) | [`bytecode-refinement/RelayBodyEff.lean:relay_loop_sound_literal_derived_tight`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean) | + ecrecover (MC-2/OP-1), `ValidRun`, successful modeled execution/acceptance, A-EVM |
| 1c | same, **∀K** | R3 Kontrol | Solidity model · ∀K, N∈{3,5} | **proven** | [`kontrol/RelaySigLoopFV.t.sol`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol) | + K-1,2 |
| 1d | same, on **real bytecode**, bounded | R2 Halmos | bytecode · K≤3,N≤5 | **proven** | `RelaySigFV`, `RelaySigParamFV` | MC-1,2,3, OP-1 |
| 1e | model↔bytecode bridge (`psAt` invariant) | R2 Halmos | bytecode · K≤3 | **proven** | `RelayModelBridgeFV` | MC-1,2, OP-1 |
| 2 | `relay()` **epoch-decision matrix** (all 5 gates) | R2 Halmos | bytecode · bounded | **proven** | `RelayWrongEpochFV`, `RelayDelayedPolicyFV`, `RelayFinalizationWindowFV`, `RelayCrossEpochFV`, `RelayThresholdScalingFV`, `RelayMustUseNewPolicyFV` | MC-1..5, OP-1 |
| 3 | **threshold-increase rescale never weakens / no overflow** | R2 Halmos | arithmetic model · all 16-bit | **proven** | `RelayThresholdScalingFV` | — |
| 4 | threshold consistency (setter + live Mode-1) | R2 Halmos | bytecode · bounded | **proven** | `RelayThresholdConsistencyFV`, `RelayModeOneFV` | MC-1,2,3, OP-1 |
| 5 | **access control** (only setter rotates policy) | R2 Halmos | bytecode · bounded | **proven** | `RelayAccessControlFV` | MC-3 |
| 6 | constructor **fail-closes** on bad config | R2 Halmos | bytecode | **proven** | `RelayConstructorFV` (L4/RLY-11) | — |
| 7 | governance-fee **nonce replay protection** | R2 Halmos | bytecode · all nonces | **proven** | `RelayGovernanceNonceFV` (AC-2) | MC-1 |
| 7b | nonce monotonic **∀ function** | R3 Certora | source · ∀ seq | **proven 20/21 fns** (legacy; 19/21 via-ir) — `relay()` vacuous (C-1 residual) | [`RelayInvariants.spec:nonceMonotonic`](../../certora/specs/RelayInvariants.spec) + `certora/Relay-rawstorage*.conf` | MC-1 |
| 8 | epoch **+1 advance** + `lastInitialized` monotone (state-effect) | R2 Halmos | bytecode | **proven** | `RelayEpochAdvanceFV` | — |
| 8b | `lastInitialized` monotone **∀ function** | R3 Certora | source · ∀ seq | **proven 20/21 fns** (legacy; 19/21 via-ir) — `relay()` vacuous (C-1 residual) | `RelayInvariants.spec:lastInitializedMonotonic` | MC-1 |
| 9 | random-pointer **monotonicity** | R3 Kontrol + R2 Halmos | model ∀K / bytecode bounded | **proven** | [`kontrol/RelayRandomMonoFV.t.sol`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol), `RelayRandomMonotonicityFV` | MC-1 |
| 10 | random value **binding / no-forgery** | R2 Halmos | bytecode | **proven** | `RelayRandomBindingFV` | MC-1 |
| 11 | Merkle proof-element + alignment soundness | R2 Halmos | bytecode | **proven** | `RelayMerkleProofFV` | MC-1,4 |
| 12 | Merkle fold injectivity for a **fixed sibling/path sequence** (base, step, depth-2 machine checks; arbitrary-depth induction at meta level) | R2 Halmos | fold model | **proven as stated** | `RelayMerkleFoldFV` | MC-1; not full arbitrary-proof membership soundness |
| 13 | **fee conservation** (`relay()` + `verify()`, incl. old-relay forwarding) | R2 Halmos | bytecode | **proven** | `RelayFeeConservationFV`, `RelayVerifyFeeFV` | OP-3, OP-4 |
| 14 | encoding canonicality / secure-bit / return discriminator / policy hash (P3/P5/P6/P8) | R2 Halmos | bytecode | **proven** | `RelayCanonicalityFV`, `RelayIsSecureNormFV`, `RelayReturnDiscriminatorFV`, `RelayPolicyHashFV` | MC-1 |
| 15 | functional behavior, all modes | R0/R1 Foundry | bytecode · concrete+fuzz | **proven** (tests) | [`Relay.t.sol`](../../test-forge/unit/protocol/implementation/Relay.t.sol) (59 tests) | — |
| 16 | setter immutable / hash & root write-once **∀ function** | R3 Certora | source · ∀ seq | **proven** — setter 20/21 (legacy); write-once **22/23** (legacy, over the munge-verified harness, with the in-spec reachable-state link) — `relay()` vacuous (C-1 residual) | `RelayInvariants.spec` + [`RelayWriteOnce.spec`](../../certora/specs/RelayWriteOnce.spec) | MC-1 |

**Reading the ledger.** The security core (row 1) is established at four complementary fidelities: ∀N∀K
abstract under `ValidRun` (R4a), conditional ∀N statements on validated semantics (R4b), ∀K on a fixed-N
model (R3), and bounded on real bytecode (R2) with an explicit bridge (1e). These results corroborate one
another but are not a single whole-program refinement theorem. The `relay()`-residual rows (7b/8b/16) are the
all-functions *storage* invariants — their **per-sequence**
forms are proven (rows 7/8), so the residual is coverage breadth over assembly storage, not the property.

---

## 10.4 The trust chain

For the strongest claims (rows 1/1b), the proof-internal links are machine-checked or independently
validated; the model-to-deployment relation remains the registered BR-3 boundary:

```
  Lean proof correct          ← Lean kernel (small, well-scrutinized; no native_decide used)
   on EVMYulLean (R4b)         ← opcode/memory: vs Ethereum execution-spec suites;
                                  Yul control-flow: Yul semantic tests (weaker half)   [A-EVM]
    on Lean's axioms           ← propext, Classical.choice, Quot.sound (standard, consistent)
  + data layer / overflow / encoding                                          [BR-1, BR-2, BR-3]
  + cryptography / trusted setter / OZ / oldRelay                             [MC-1..5]
```

(The deployed-bytecode rows additionally rely on the operational boundary contracts [OP-1..5] — e.g. the
`ecrecover` `returndatasize`/zero-signer checks; the whole-`relay()` symbolic runs use Halmos's total
built-in `0x01`, but the OP-1 guard itself is now proven symbolically in isolation
(`RelayEcrecoverSymbolicFV`) as well as by real-EVM regression. See §10.2.)

Outside the chain are exactly the registered assumptions. The engineering value of the stack is that this
trusted surface is **small, named, and individually attackable** — instead of "trust 930 lines of assembly
by eye."

---

## 10.5 The residual roadmap (permanent vs. addressable)

The residual splits into assumptions that are **permanent** (irreducible, or a deliberate trust/design
boundary — pushing them is not "more verification") and ones that are **addressable** by further work.
Status reflects the current tree.

> For a reader-facing, tiered walk-through of these residuals *as weaknesses / attack surface* — what each
> would mean if it went wrong, which are code-local vs. trust boundaries vs. coverage gaps, and a few cheap
> hardening suggestions — see **[L13 — Residual weaknesses & attack surface](13-residual-weaknesses.md)**. This
> section remains the formal register behind it.

| Assumption(s) | Class | Status / cost |
|---------------|-------|---------------|
| **MC-1, MC-2** (keccak / ECDSA hardness) | Permanent — irreducible | leave; cannot be proven unconditionally |
| **A-EVM** (EVMYulLean = the EVM) | Permanent — irreducible | leave; validated by conformance tests, not provable (hardenable by cross-validation) |
| **MC-3** (trusted setter), **MC-5** (oldRelay) | Permanent — trust boundary by design | leave; on-chain enforcement would be a *contract change*, not verification |
| **MC-4** (OZ `MerkleProof`) | Borderline | conventionally assumed; cheaply verifiable if an audit demands zero library trust |
| **BR-2** (overflow bound) | Addressable | ✅ **done** — `bytecode_threshold_sound_int` |
| **OP-1** (ecrecover failure ABI) | Addressable | ✅ **done** — real-EVM regression ([`RelayEcrecoverABI.t.sol`](../../test-forge/fv/RelayEcrecoverABI.t.sol)) **and** symbolic internalization ([`RelayEcrecoverSymbolicFV.t.sol`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol): the guard proven against the empty-return/stale-buffer ABI over all stale contents) |
| **BR-3 / K-2** (encoding fidelity, model↔bytecode) | Addressable | **partially closed** — compiler artifact and optimized-Yul provenance are exact; `bodyL` is still a hand transcription with D1–D4 deviations and no AST-extraction/equivalence proof. Early return is modeled, while deriving the modeled premises and D3 accept-write from one compiled accepted execution remains open. |
| **BR-1** (data layer, `mload = w[i]`) | **Proven inside the stated models** | `DataLayer`, `RelayLoopMemRead`, and `RelayBodyEff` machine-check byte decoding, memory round-trip, masking, the memory-reading loop, and the literal body's read extraction. `relay_loop_sound_literal_derived_tight` derives `hcov`/`hcorr` and guards from its preconditions, but `ValidRun`, successful execution/acceptance, and ecrecover remain explicit; transporting them from every compiled accepted execution is still BR-3. Three local declarations implement the two upstream-dischargeable data/window spec shapes. |
| `relay()` breadth model, **OP-3/4** | Addressable — **components landed; composition remains conditional** | R4b's literal loop statements are hole-free under their explicit execution, `ValidRun`, and acceptance hypotheses. R5 adds independently checked storage round-trip/accept-write, mode dispatch, conditional dispatch→loop→accept composition, and fee-conservation components. **Remaining:** derive setup, valid-run, early-return acceptance, and accept-write from one accepted compiled execution; wire exec-level `.CALL`; reconcile D3 (modeled return vs deployed break→write→return). These are breadth/linkage residuals, not additional abstract accounting lemmas. |
| **C-1** (Certora all-functions storage) | Addressable — **largely discharged (2026-07)** | splitting-off + hashing model proves all 5 invariants for every function except `relay()` (see the run matrix in [`certora/README.md`](../../certora/README.md)); the `relay()` vacuity is intrinsic to the no-splitting model (the ghost/hook route inherits it) and stays covered per-sequence at R2 + by the Lean literal model |

The addressable items, leverage-ordered — each, if done, moves a row from *assumed/blocked* toward *proven*:

1. **Discharge BR-1 in Lean — ✅ DONE (was: highest value, ~1–2 months).** Replace the index addend with a
   memory read and prove `mload(weights[i]) = w[i]`; then model the *whole* body literally. Both halves are
   now complete — the bounded data-layer foundation (below) and the literal end-to-end model
   (`RelayBodyEff.lean`, final bullet). **Decomposed to the foundation (investigated 2026-06-20):**
   - **Byte-decode layer — ✅ DONE (committed).** `test-forge/fv/lean/bytecode-refinement/DataLayer.lean`
     proves `fromBytesBigEndian_toBytesBigEndian` (the big-endian round-trip is the identity) about
     EVMYulLean's actual public functions, hole-free — it reuses EVMYulLean's existing `@[simp]
     fromBytes'_toBytes'`, which fires downstream despite being `private`. The padding/bounds lemmas
     (`extend_bytes_zero`, `fromBytes'_zeroPadBytes_32_eq`) also already exist upstream. No new number
     theory needed.
   - **Memory layer — ✅ DONE (committed).** `DataLayer.lean` proves, against EVMYulLean's *actual*
     `ByteArray` ops: `keystone` (the `copySlice→extract` round-trip; **no axioms beyond the standard
     three**) and **`mem_roundtrip`**: `readWithPadding (write src 0 mem d 32) d 32 = src` — writing a
     32-byte word into a large-enough buffer and reading it back is the identity. This is the heart of
     `mload∘mstore`. Since Lean 4.22 has no ByteArray lemma layer, the proofs reduce via `ByteArray.ext`
     to the `Array.data` level. The only assumption added is one documented axiom, `zeroes_data` (the
     minimal spec for the `opaque ffi.ByteArray.zeroes`/`memset_zero`; dischargeable upstream by
     `opaque → def … @[implemented_by]`). The hard ByteArray-grind risk is fully retired.
   - **Value-decode — ✅ DONE (committed).** `ofNat_toNat` (`ofNat ∘ toNat = id`), `size_append`
     (`(a++b).size = a.size + b.size`, absent on 4.22), `toList_data` (`ByteArray.toList = data.toList`, via
     the `toList.loop` invariant), and the capstone **`fromByteArray_toByteArray`**:
     `fromByteArrayBigEndian (v.toByteArray) = v.toNat` — decoding the 32-byte big-endian word (leading
     zero-pad) recovers the value, against EVMYulLean's *actual* `fromByteArrayBigEndian`/`UInt256.toByteArray`
     (hole-free, `zeroes_data` only). The leading-zero argument is re-proved locally (`fromBytes'_append_zeros`,
     `fromBytesBigEndian_replicate_append`) since the upstream `extend_bytes_zero` is `private`.
   - **MachineState `mstore`/`mload` wrapping — ✅ DONE (committed).** `DataLayer.lean` proves
     `mstore_lookupMemory` and `mstore_mload`: on EVMYulLean's validated `MachineState`,
     `(mstore a v).mload a = v` whenever the buffer has room (`a+32 ≤ memory.size`) and the active-word count
     does not overflow. This discharges the `lookupMemory` guard (`addr ≥ memory.size ∨ addr ≥ activeWords*32`
     — proved false from the write's size-preservation and the `M`-activeWords arithmetic `M_lb`, with
     `mul32_toNat` handling the `UInt256` modular product) and composes `mem_roundtrip` +
     `fromByteArray_toByteArray` + `ofNat_toNat`. The conditional core rests on `zeroes_data` alone; the
     unconditional `mstore_mload` adds the second documented spec `toByteArray_size`
     (`(v.toByteArray).size = 32` — verified provable against a locally-patched EVMYulLean, blocked downstream
     only because the upstream bound `toBytes'_UInt256_le` is `private`).
   - **`& 0xffff` weight mask — ✅ DONE (committed).** `DataLayer.lean` proves `mask16_toNat`
     (`and(x, 0xffff) = x mod 2¹⁶` on EVMYulLean's `UInt256.land`, via a bit-by-bit `testBit` argument) and
     `mask16_of_lt` (the mask is the identity on a 16-bit registered weight, `totalWeight < 2¹⁶`,
     [`Relay.sol:350`](../../contracts/protocol/implementation/Relay.sol#L350)). This is the masked weight read at `Relay.sol:1327`. **No** axioms beyond the standard
     three.
   - **Data-layer capstone — ✅ DONE (committed).** `DataLayer.lean:weight_read` composes the whole bounded
     stack into BR-1's data-layer claim for one slot: a 16-bit weight written to a 32-byte memory slot is
     recovered by the deployed read pattern `and(mload(slot), 0xffff)` under EVMYulLean's validated
     `MachineState` — `mload(weights[i]) & 0xffff = w[i]`. Hole-free modulo the two documented specs.
   - **Memory-reading loop refinement — ✅ DONE (committed).** `RelayLoopMemRead.lean` lifts the bytecode
     loop refinement from the memory-free body (`w := w + i`) to the deployed contract's **actual masked
     weight read** `w := w + (mload(i·32) & 0xffff)`, executed by the validated Yul `exec` for **all N**.
     `bytecode_threshold_sound_mem` / `bytecode_threshold_sound_mem_int`: accept ⟹ the total of the masked
     memory reads (modular / integer) exceeds the threshold — hole-free, *no* axioms beyond the standard
     three. New brick `body_effM` proves one iteration of the real `mload`+`and` body (the `mload` is
     state-preserving once the slot is active, so `activeWords` is unperturbed); `loop_accM` runs the
     `3N+15`-fuel induction. This is the **data-flow core of the simulation relation `R`**: the per-iteration
     addend is now a genuine `MLOAD`, not the loop index. The read-content hypothesis `hcov` is BR-1's
     data-layer invariant, discharged per-slot by `weight_read`, so `absAccMNat rdv 0 N 0 = sumTake w N`.
   - **Simulation relation `R`, accounting core — ✅ DONE (committed); selection/validity assumed *here*, derived in the literal model below.** `RelayLoopMemRead.lean:relay_loop_sound` composes
     the EVM accumulation with the abstract accounting: ∀N, **if the deployed loop accepts (final weight >
     threshold), the total registered voting weight exceeds the threshold** — no voter double-counted — on the
     validated EVM semantics. The `bridge` lemma identifies the integer masked-read accumulator with the
     abstract `sigLoop` accumulated weight (under the data-layer correspondence `mrd rdv k = w[idxs[k]]`); the
     abstract `sumTake`/`sigLoop`/`ValidRun`/`threshold_sound` are restated in the same file (identical to
     `../RelaySigLoop.lean`) so one `lake env lean` checks the whole chain. Hole-free
     (`{propext, Classical.choice, Quot.sound}`).
   - **The external-call behaviour is an assumption** (as throughout the engagement). `ecrecover` (the `0x01`
     staticcall) is not modeled; its effect — signature `k` selects voter `idxs[k]`, whose registered weight
     is the iteration's addend — and the strict-index discipline are the stated hypotheses of
     `relay_loop_sound`: `hcov` (the memory holds the selected weight at slot `k`; BR-1 data layer,
     dischargeable per-slot by `weight_read`), `hcorr` (`mrd rdv k = w[idxs[k]]`; this is where
     ecrecover→recovered-signer→voter and the calldata decode enter — MC-2 / OP-1), `hvalid` (`ValidRun`:
     strict-increasing in-range indices = the deployed guards passed = no double-count), and `hnoovf` (BR-2,
     no overflow). Within this abstract model, the loop mechanism, `mload`, mask, accumulation, accept gate,
     and accounting soundness are proved against the validated semantics. (These are the
     hypotheses of the *abstract* body `body_effM`; in the literal model below, `hcov`/`hcorr` and the
     structural half of `hvalid` become *theorems*, leaving only the ecrecover facts assumed as `IterPremiseT`.)
   - **Literal conditional body model — ✅ machine-checked as stated (committed; 2026-07-02/03).**
     [`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean)
     (with [`RelayLoopLiteral.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopLiteral.lean) and
     [`RelayLoopWindows.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopWindows.lean)) executes a
     17-statement hand transcription `bodyL`, sourced from the optimized-Yul signature loop beginning at
     `relay_ir_optimized.yul:1563`, through EVMYulLean's validated Yul `exec`, threading modeled
     `mstore`/`calldatacopy`/`mload` state. The chain, all hole-free (`{propext, Classical.choice, Quot.sound}`;
     the accounting-extraction lemmas need only `{propext, Quot.sound}`): `body_effL` (one iteration executed) →
     `s16_ww_advance`/`s16_ii_preserved` (the body adds exactly the selected voter's registered weight and
     preserves the counter) → `iter_advance` (the per-iteration advance, i.e. `hstep`, **derived** from
     `body_effL` + the extraction) → `range_guard_pass`/`order_guard_pass`/`iter_advance_tight` (the two
     **structural** index guards — range `idx<nVot`, strict-increase `nui≤idx` — derived from `ValidRun`) →
     `loop_accL` (the ∀N induction over the literal body, threading the evolving memory) →
     `relay_loop_sound_literal` → `relay_loop_sound_literal_derived` (`hstep` discharged) →
     **`relay_loop_sound_literal_derived_tight`** (the tightened top theorem). The effect: `hcov`/`hcorr` are
     **no longer assumed** — the masked read = the selected voter's registered weight is *derived*
     (`mload_masked_voter`) from a raw-calldata memory precondition; and the structural half of `hvalid`
     (index in range, strictly increasing) is *derived* from `ValidRun`. The only per-iteration hypothesis
     that survives (`IterPremiseT`) is the **cryptographic ecrecover facts** (`v ∈ {27,28}`, low-`s`,
     `staticcall` success, `returndatasize()==32`, signer ≠ 0, recovered signer = registered voter) plus the
     accept gate — i.e. exactly `ecrecover` (MC-2 — uninterpreted by design), stated explicitly. The accounting
     conclusion is identical to the abstract `relay_loop_sound`; what shrinks is the assumption surface, down to
     the ecrecover boundary. This *is* the boundary between the validated-EVM accounting proof and the
     cryptographic trust base.
   - **Early-return path — ✅ DONE (committed; 2026-07-03).** The one prior idealization (the literal loop was
     modeled running to completion; the deployed loop early-returns at the first threshold crossing) is now
     modeled directly: `body_effL_accept` executes the body's accept branch (statement 17's
     `if gt(weight,thr) { return(0,0) }` fires → `.error (YulHalt _ ⟨1⟩)`), `loop_step_accept` propagates the
     halt out of the `For`, `loop_accL_early` runs `t` advancing iterations then the accepting one, and
     `relay_loop_sound_literal_early` concludes both that the loop **genuinely early-returns** and that the
     total registered weight exceeds `thr` (via `threshold_sound` on the accepted `(t+1)`-prefix). No
     monotonicity hand-wave. Hole-free. See [L7 §7.4](07-R4b-bytecode-refinement.md).
   - **Upstream-dischargeable specs** (two shapes, three qualified local declarations; access-modifier
     limitations rather than intended semantic assumptions): `zeroes_data` (spec/de-opaque `memset_zero`) and
     `toByteArray_size` (expose the `private`
     `toBytes'_UInt256_le`). Starting points + the `R` sketch:
     [`test-forge/fv/lean/bytecode-refinement/README.md`](../../test-forge/fv/lean/bytecode-refinement/README.md).
2. **Internalize OP-1 in the symbolic model — ✅ DONE.** The OP-1 ABI is pinned by a real-EVM regression
   (`test-forge/fv/RelayEcrecoverABI.t.sol`) and now *also* internalized symbolically by
   `test-forge/fv/RelayEcrecoverSymbolicFV.t.sol`. Because Halmos's built-in `0x01` is a total clean-address
   function (`returndatasize()==32` always) and cannot produce the empty-return failure, that harness reaches
   the branch via a **mock** reproducing the precompile's failure ABI, then proves — symbolically, over ALL
   stale-buffer contents — that the `staticcall`-success / `returndatasize()==32` / non-zero-signer guard
   (i) rejects an empty return, (ii) rejects a zero signer, and (iii) when it accepts, uses the fresh return
   and never the stale buffer. The FV manifest lists its proof/control pair explicitly and `verify_fv.py`
   requires the observed inventory to match exactly, so a regression that weakened or silently removed the
   guard would fail the symbolic gate, not just the
   regression test.
3. **Tighten BR-3 / K-2.** Parse the emitted optimized Yul for the signature loop and prove the parsed AST
   refines the bytecode-refinement `For` node; and discharge the bmc-depth-1 model↔bytecode equivalence for
   Kontrol ([`docs/relay-t1-bridge.md`](../relay-t1-bridge.md)). Removes "is this the real loop?" for both R3 and R4b.
4. **Internalize BR-2 — done.** `absAcc_val` + `bytecode_threshold_sound_int` carry the `Σ < 2²⁵⁶`
   hypothesis and make the `𝕌`→`ℕ` identification a theorem (the modular accumulator provably equals the
   integer accumulator, so accept ⟹ *integer* total > thr).
5. **Glue rows 1 and 1b explicitly.** A Lean lemma transporting `bytecode_threshold_sound` (modular,
   index-addend) to `threshold_sound` (integer, weight-addend) **under BR-1+BR-2**, with the assumptions as
   visible hypotheses.
6. **If an audit requires C-1.** Re-model Relay's storage in CVL with ghost vars + raw `Sstore`/`Sload`
   hooks mirroring the assembly writes, then state the invariants over ghosts — substantial, and it
   re-introduces the faithfulness risk the engagement otherwise avoids. Only if all-functions storage
   invariants are a hard requirement.
7. **Regression-watch the walls.** Periodically re-confirm the Kontrol symbolic-N / Certora storage-havoc
   stalls are unchanged, keeping the justification for R4 current.

None is required for the result *as stated* (the ledger is complete on its own terms); they are the path
from "small named trusted surface" toward "nothing trusted but the kernel, the EVM test suites, and the
cryptography."

---

## 10.6 What is *not* claimed (to forestall over-reading)

- **Not claimed:** "the deployed `Relay.sol` bytecode is fully formally verified." The real statement is the
  ledger §10.3 + the assumptions §10.2.
- **Not claimed:** the bytecode-refinement loop is a *verbatim byte-for-byte* copy of the signature routine.
  The abstract row (1b) models the iterate-and-accumulate skeleton with the addend abstracted; the **literal
  row (1b′) is a hand transcription** sourced from the optimized-Yul loop (4 registered deviations D1-D4),
  with the memory-read addend modeled explicitly. No parser or refinement theorem establishes AST equivalence
  to the compiled block. Crypto is out of scope (MC-2) in both.
- **Not claimed:** the cryptography is verified. It is assumed (MC-1, MC-2).
- **Not claimed:** the whole-`relay()` symbolic suite exercises the `ecrecover` failure ABI. It models a
  clean-address return; a dedicated symbolic mirror and real-EVM regression check the empty-return/stale-buffer
  obligation, while identification with Relay's deployed assembly still relies on review (§10.2).
- **Not claimed:** correctness in `𝕌` equals correctness in `ℕ` for free. It needs BR-2 (true with vast
  margin, but stated).
- **Not claimed:** the all-functions storage invariants are proven *for `relay()` itself*. They are now
  cloud-proven for every **other** function (2026-07, C-1 narrowed); on `relay()` the no-splitting model is
  vacuous, and coverage there is the per-sequence R2 proofs + the Lean literal model.
- **Not claimed:** the whole-`relay()` extension (R5) is *byte-complete*. `relay_dispatch_loop_accept` ties
  the mode dispatch to the signature-loop accept as one machine-checked theorem, but the calldata-decode setup
  between them is carried as an explicit hypothesis (`dispatch_setup_loop_accept`), the accept-*write* stays a
  separately-verified piece across the D3 deviation, and the exec-level `.CALL` value-transfer wiring is a
  documented boundary (§10.5). The R5 storage/dispatch/write/composition/fee results are hole-free, but each is a
  **breadth** extension, not a new soundness fact — the accounting soundness is the loop's.
- **What *is* claimed:** the abstract accounting theorem is sound for all N and K under `ValidRun`; the
  Kontrol fixed-N models establish their inductive pieces for all K; the EVMYulLean files establish their
  conditional statements for all N on validated semantics; and the bounded Halmos suite checks the actual
  bytecode across the declared matrix, lifecycle, Merkle, randomness, and fee properties. R5's dispatch,
  accept-write, and fee components are individually hole-free breadth results. The compiler artifacts and
  committed optimized Yul are now mechanically hash-bound, but deriving every R4/R5 execution premise from
  a whole accepted compiled execution remains an explicit residual rather than an implied theorem.

**Next:** [L11 — Reproducibility](11-reproducibility.md): exact tools, versions, commands, and expected
outputs to re-check every row above.
