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
| R3 Kontrol | each `prove_*` passes under Kontrol 1.0.248; controls counterexample by design |
| R3 Certora | rule passes on the cloud prover (here: **not reached** — see C-1) |
| R4 Lean | theorem whose statement *is* the claim, `#print axioms` ⊆ `{propext, Classical.choice, Quot.sound}`, **no `sorry`/`sorryAx`/`native_decide`/extra axiom** |

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
| **MC-3** | the signing-policy setter (FlareSystemsManager) supplies distinct, non-zero, canonically-ordered voters with normalized weights; `startingVotingRoundId` non-decreasing (**RLY-06**) | documented, not on-chain-enforced; `docs/relay-phase3-documented-items.md` |
| **MC-4** | OZ `MerkleProof.verifyCalldata` internals are correct (call-site in scope) | audited library |
| **MC-5** | `oldRelay` is a trusted, audited prior deployment; its return values are honest | deployment assumption |

### Operational boundary-call contracts (OP) — the EVM-level behavior of each external call

Each row states the **operational contract** of a boundary call, the **code-side obligation** that makes
the contract safe, and **how that obligation is verified**. These are distinct from the mathematical
assumptions above: they are about *EVM/ABI behavior*, not cryptography.

| ID | Boundary (site) | Operational contract | Required code-side obligation | Verified by |
|----|-----------------|----------------------|-------------------------------|-------------|
| **OP-1** | `ecrecover` precompile `0x01` — raw `staticcall` (`Relay.sol:1284`) | **does not revert on a bad signature**: the `staticcall` returns *success* with **empty** return data (`returndatasize()==0`) and leaves the output buffer **unmodified** (stale-read hazard); returns 32 bytes only on a valid recovery | the call site **must** check (a) `staticcall` success, (b) **`returndatasize()==32`**, and (c) recovered signer `≠ 0` — all three are present (`"ecrecover error"`, `"ecrecover returned bad data"`, `"Zero signer"`). **Load-bearing: must never be removed.** | **`test-forge/fv/RelayEcrecoverABI.t.sol`** — a real-EVM regression that pins the empty-return/stale-buffer ABI and that the `returndatasize()==32` guard rejects a bad signature — plus Foundry/Hardhat failure-path tests + assembly review (`docs/relay-assembly-review.md`). **Not** exercised by the symbolic FV — see the note below. |
| **OP-2** | `keccak256` (`SHA3` opcode) | total & deterministic; cannot return malformed output or "fail" (only out-of-gas) | none beyond gas | inherent (opcode); MC-1 supplies the algebraic model |
| **OP-3** | `oldRelay.*` external calls, incl. value-bearing `oldRelay.verify{value: oldFee}(…)` (`Relay.sol:1567`) | a real cross-contract call that **may revert** and **may re-enter** `Relay`; forwards value | revert is propagated (`require(success,…)` on the relayed path); re-entrancy is benign (re-entered paths write no fee/nonce/root state — R1/R2); fee is forwarded exactly (M-1) | code review (`docs/relay-security-review.md`) + Foundry (`RelayVerifyFeeFV`, fee/old-relay tests); MC-5 supplies return-value trust |
| **OP-4** | self-call `address(this).call(_relayMessage)` (`Relay.sol:1730`, `_verifyCustomSignature`) | ordinary external call to self: returns `(success, returnData)`; re-enters the `relay()` path | `require(success)` + `require(returnData.length == 35)` (the RLY-07 mode-1 discriminator) | Foundry custom-signature tests + review |
| **OP-5** | precompile **surface bound** | the **only** precompile used is `0x01`; no `sha256 (0x02)`, identity, modexp, or EC ops are called | n/a (bounds which OP-contracts are in play) | assembly review (`docs/relay-assembly-review.md`) |

> **FV blind spot (stated explicitly).** The symbolic suite models `ecrecover` as a *total* function that
> always returns a well-formed 32-byte address (`E(hash,v,r,s) → address`, `returndatasize()==32`). It
> therefore **does not exercise the OP-1 failure mode** (empty return / stale buffer). The OP-1 obligation
> is what makes reality conform to that model; it is discharged by **tests + assembly review**, not by the
> symbolic proofs. Any change to the `ecrecover` block must re-establish OP-1.

### Bytecode-refinement residuals (BR) — the R4b model-to-deployment gap

| ID | Assumption | Status |
|----|-----------|--------|
| **BR-1** | data layer: each loop iteration's addend is the registered weight `mload(weights[i])` (the verified loop adds the index `i`) | assumed; validated vs. documented layout + reference encoder. **Highest-leverage open item** (§10.5) |
| **BR-2** | overflow bound: sums don't wrap 2²⁵⁶ (so `𝕌`-results = integer results) | **internalized in Lean** (`absAcc_val` / `bytecode_threshold_sound_int`): under the explicit hypothesis `Σ < 2²⁵⁶`, the modular accumulator equals the integer accumulator and accept ⟹ *integer* total > thr. The hypothesis holds with vast margin (`totalWeight < 2¹⁶`). |
| **BR-3** | encoding fidelity: the `For` node mirrors the deployed loop's iterate-and-accumulate *skeleton*, not the whole signature routine | the no-double-count discipline is proven abstractly (`ValidRun`); cryptography is MC-2 |

### Tool-coverage limits

| ID | Limitation | Status |
|----|-----------|--------|
| **K-1** | Kontrol base+step compose to ∀K at the *meta* level (no native loop-invariant rule in 1.0.248) | each piece machine-checked; composition by standard induction. Subsumed by the abstract Lean proof (internal induction) |
| **K-2** | Kontrol checks a faithful Solidity *model*, not the inline-assembly bytecode | bytecode side at K≤3 via Halmos `RelaySigParamFV`; tied by `RelayModelBridgeFV`; full bridge = future bmc-depth-1 obligation (`docs/relay-t1-bridge.md`) |
| **C-1** | Certora storage invariants not cloud-dischargeable (assembly storage-havoc) | **blocked**, not a bug; per-sequence forms proven at R2; ghost/hook re-modeling possible but re-introduces faithfulness risk |
| **A-EVM** | EVMYulLean *is* the EVM | validated against Ethereum execution-spec test suites (not provable; standard residual) |

---

## 10.3 The master claims ledger

Each row: the property, the strongest rung that establishes it, the object/coverage there, the evidence
artifact, and the assumptions it leans on. Lower rungs often corroborate the same property at higher
fidelity / lower coverage (noted).

| # | Property | Strongest rung | Object · coverage | Status | Evidence | Relies on |
|---|----------|----------------|-------------------|--------|----------|-----------|
| 1 | **Threshold soundness** (accept ⟹ enough distinct weight, no double-count) | R4a Lean | abstract algorithm · **∀N∀K** | **proven** (`[propext,Quot.sound]`) | `RelaySigLoop.lean:threshold_sound` | MC-1,2,3 |
| 1b | same, on **validated EVM semantics** (loop mechanism) | R4b Lean | validated EVM · **∀N** | **proven** (`[propext,choice,Quot.sound]`) | `bytecode-refinement/RelayBytecodeRefinement.lean:bytecode_threshold_sound` | + BR-1,2,3, A-EVM |
| 1c | same, **∀K** | R3 Kontrol | Solidity model · ∀K, N∈{3,5} | **proven** | `kontrol/RelaySigLoopFV.t.sol` | + K-1,2 |
| 1d | same, on **real bytecode**, bounded | R2 Halmos | bytecode · K≤3,N≤5 | **proven** | `RelaySigFV`, `RelaySigParamFV` | MC-1,2,3, OP-1 |
| 1e | model↔bytecode bridge (`psAt` invariant) | R2 Halmos | bytecode · K≤3 | **proven** | `RelayModelBridgeFV` | MC-1,2, OP-1 |
| 2 | `relay()` **epoch-decision matrix** (all 5 gates) | R2 Halmos | bytecode · bounded | **proven** | `RelayWrongEpochFV`, `RelayDelayedPolicyFV`, `RelayFinalizationWindowFV`, `RelayCrossEpochFV`, `RelayThresholdScalingFV`, `RelayMustUseNewPolicyFV` | MC-1..5, OP-1 |
| 3 | **threshold-increase rescale never weakens / no overflow** | R2 Halmos | arithmetic model · all 16-bit | **proven** | `RelayThresholdScalingFV` | — |
| 4 | threshold consistency (setter + live Mode-1) | R2 Halmos | bytecode · bounded | **proven** | `RelayThresholdConsistencyFV`, `RelayModeOneFV` | MC-1,2,3, OP-1 |
| 5 | **access control** (only setter rotates policy) | R2 Halmos | bytecode · bounded | **proven** | `RelayAccessControlFV` | MC-3 |
| 6 | constructor **fail-closes** on bad config | R2 Halmos | bytecode | **proven** | `RelayConstructorFV` (L4/RLY-11) | — |
| 7 | governance-fee **nonce replay protection** | R2 Halmos | bytecode · all nonces | **proven** | `RelayGovernanceNonceFV` (AC-2) | MC-1 |
| 7b | nonce monotonic **∀ function** | R3 Certora | model · ∀ seq | **blocked (C-1)** | `RelayInvariants.spec:nonceMonotonic` | — |
| 8 | epoch **+1 advance** + `lastInitialized` monotone (state-effect) | R2 Halmos | bytecode | **proven** | `RelayEpochAdvanceFV` | — |
| 8b | `lastInitialized` monotone **∀ function** | R3 Certora | model · ∀ seq | **blocked (C-1)** | `RelayInvariants.spec:lastInitializedMonotonic` | — |
| 9 | random-pointer **monotonicity** | R3 Kontrol + R2 Halmos | model ∀K / bytecode bounded | **proven** | `kontrol/RelayRandomMonoFV.t.sol`, `RelayRandomMonotonicityFV` | MC-1 |
| 10 | random value **binding / no-forgery** | R2 Halmos | bytecode | **proven** | `RelayRandomBindingFV` | MC-1 |
| 11 | Merkle proof-element + alignment soundness | R2 Halmos | bytecode | **proven** | `RelayMerkleProofFV` | MC-1,4 |
| 12 | Merkle fold injectivity / anti-forgery (**unbounded depth**) | R2 Halmos | fold model · ∀ depth | **proven** | `RelayMerkleFoldFV` | MC-1 |
| 13 | **fee conservation** (`relay()` + `verify()`, incl. old-relay forwarding) | R2 Halmos | bytecode | **proven** | `RelayFeeConservationFV`, `RelayVerifyFeeFV` | OP-3, OP-4 |
| 14 | encoding canonicality / secure-bit / return discriminator / policy hash (P3/P5/P6/P8) | R2 Halmos | bytecode | **proven** | `RelayCanonicalityFV`, `RelayIsSecureNormFV`, `RelayReturnDiscriminatorFV`, `RelayPolicyHashFV` | MC-1 |
| 15 | functional behavior, all modes | R0/R1 Foundry | bytecode · concrete+fuzz | **proven** (tests) | `Relay.t.sol` (52 tests) | — |
| 16 | setter immutable / hash & root write-once **∀ function** | R3 Certora | model · ∀ seq | **blocked (C-1)** | `RelayInvariants.spec` | — |

**Reading the ledger.** The security core (row 1) is established at four fidelities: ∀N∀K abstract (R4a),
∀N on validated semantics (R4b), ∀K on a model (R3), and bounded on the real bytecode (R2) with an explicit
bridge (1e). The blocked rows (7b/8b/16) are the all-functions *storage* invariants — their **per-sequence**
forms are proven (rows 7/8), so the residual is coverage breadth over assembly storage, not the property.

---

## 10.4 The trust chain

For the strongest claims (rows 1/1b), every link is machine-checked or independently validated:

```
  Lean proof correct          ← Lean kernel (small, well-scrutinized; no native_decide used)
   on EVMYulLean (R4b)         ← validated vs Ethereum execution-spec test suites      [A-EVM]
    on Lean's axioms           ← propext, Classical.choice, Quot.sound (standard, consistent)
  + data layer / overflow / encoding                                          [BR-1, BR-2, BR-3]
  + cryptography / trusted setter / OZ / oldRelay                             [MC-1..5]
```

(The deployed-bytecode rows additionally rely on the operational boundary contracts [OP-1..5] — e.g. the
`ecrecover` `returndatasize`/zero-signer checks — which the symbolic tools do not exercise; see §10.2.)

Outside the chain are exactly the registered assumptions. The engineering value of the stack is that this
trusted surface is **small, named, and individually attackable** — instead of "trust 930 lines of assembly
by eye."

---

## 10.5 The residual roadmap (permanent vs. addressable)

The residual splits into assumptions that are **permanent** (irreducible, or a deliberate trust/design
boundary — pushing them is not "more verification") and ones that are **addressable** by further work.
Status reflects the current tree.

| Assumption(s) | Class | Status / cost |
|---------------|-------|---------------|
| **MC-1, MC-2** (keccak / ECDSA hardness) | Permanent — irreducible | leave; cannot be proven unconditionally |
| **A-EVM** (EVMYulLean = the EVM) | Permanent — irreducible | leave; validated by conformance tests, not provable (hardenable by cross-validation) |
| **MC-3** (trusted setter), **MC-5** (oldRelay) | Permanent — trust boundary by design | leave; on-chain enforcement would be a *contract change*, not verification |
| **MC-4** (OZ `MerkleProof`) | Borderline | conventionally assumed; cheaply verifiable if an audit demands zero library trust |
| **BR-2** (overflow bound) | Addressable | ✅ **done** — `bytecode_threshold_sound_int` |
| **OP-1** (ecrecover failure ABI) | Addressable | ✅ real-EVM regression done (`RelayEcrecoverABI.t.sol`); symbolic-model internalization pending |
| **BR-3 / K-2** (encoding fidelity, model↔bytecode) | Addressable | weeks |
| **BR-1** (data layer, `mload = w[i]`) | Addressable | **months** (FFI memory); **highest leverage** toward R5 |
| whole-`relay()` extension, **OP-3/4** | Addressable | months–years (full end-to-end R5) |
| **C-1** (Certora all-functions storage) | Addressable but **not recommended** | re-introduces the faithfulness risk the engagement avoids; per-sequence forms already proven |

The addressable items, leverage-ordered — each, if done, moves a row from *assumed/blocked* toward *proven*:

1. **Discharge BR-1 in Lean (highest value).** Replace the index addend with a memory read and prove
   `mload(weights[i]) = w[i]` — either a runtime EVMYulLean test exe that links the FFI memory model and
   checks representative layouts, or a symbolic memory-fragment axiomatization + a proof that the loop's
   slot arithmetic addresses it. Collapses most of the R4→R5 gap. Concrete starting points (the IR-extraction
   recipe and the full-fidelity simulation relation `R`) are in
   `test-forge/fv/lean/bytecode-refinement/README.md`.
2. **Internalize OP-1 in the symbolic model.** The OP-1 ABI is now pinned by a real-EVM regression
   (`test-forge/fv/RelayEcrecoverABI.t.sol`). The remaining step is to model `ecrecover` with its real
   failure ABI (empty return / stale buffer) *inside* the symbolic suite — instead of a total
   clean-address function — so the symbolic gate itself would flag a missing `returndatasize`/zero-signer
   check rather than relying on the regression test.
3. **Tighten BR-3 / K-2.** Parse the emitted optimized Yul for the signature loop and prove the parsed AST
   refines the bytecode-refinement `For` node; and discharge the bmc-depth-1 model↔bytecode equivalence for
   Kontrol (`docs/relay-t1-bridge.md`). Removes "is this the real loop?" for both R3 and R4b.
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
- **Not claimed:** the bytecode-refinement loop is a verbatim copy of the signature routine. It is the
  iterate-and-accumulate skeleton (BR-3), addend abstracted (BR-1), crypto out of scope (MC-2).
- **Not claimed:** the cryptography is verified. It is assumed (MC-1, MC-2).
- **Not claimed:** the symbolic suite exercises the `ecrecover` failure ABI. It models a clean-address
  return; the empty-return/stale-buffer safety is the OP-1 obligation, discharged by tests + assembly
  review (§10.2).
- **Not claimed:** correctness in `𝕌` equals correctness in `ℕ` for free. It needs BR-2 (true with vast
  margin, but stated).
- **Not claimed:** the all-functions storage invariants are proven. They are specified + locally
  typechecked but **blocked** on this assembly-heavy contract (C-1); their per-sequence forms are proven.
- **What *is* claimed, fully:** the security-critical accounting is sound for all N and all K (rows 1, 1c,
  1d, 1e); a validated model of the real machine genuinely runs the unbounded loop and the soundness step
  survives onto it (row 1b); the entire `relay()` decision matrix, access control, lifecycle, Merkle,
  randomness, and fees hold on the real bytecode within bound (rows 2–14); and the gap to the literal
  deployment is exactly the registered, individually-attackable assumptions.

**Next:** [L11 — Reproducibility](11-reproducibility.md): exact tools, versions, commands, and expected
outputs to re-check every row above.
