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

Two groups: the **modeling contract** (suite-wide, by design) and the **rung-specific** residuals.

### Modeling contract (suite-wide — where formal methods are the wrong tool, by design)

| ID | Assumption | Justification |
|----|-----------|---------------|
| **MC-1** | `keccak256` is an injective uninterpreted function | standard; collision-resistance assumed |
| **MC-2** | `ecrecover` is uninterpreted (ECDSA unforgeability) | we verify accounting, not cryptography |
| **MC-3** | the signing-policy setter (FlareSystemsManager) supplies distinct, non-zero, canonically-ordered voters with normalized weights; `startingVotingRoundId` non-decreasing (**RLY-06**) | documented, not on-chain-enforced; `docs/relay-phase3-documented-items.md` |
| **MC-4** | OZ `MerkleProof.verifyCalldata` internals are correct (call-site in scope) | audited library |
| **MC-5** | `oldRelay` is a trusted, audited prior deployment | deployment assumption |

### Rung-specific residuals

| ID | Assumption / limitation | Where | Status |
|----|--------------------------|-------|--------|
| **GB-1** | Gap-B data layer: each loop iteration's addend is the registered weight `mload(weights[i])` (the verified loop adds the index `i`) | R4b | assumed; validated vs. documented layout + reference encoder. **Highest-leverage open item** (§10.5) |
| **GB-2** | Gap-B overflow bound: sums don't wrap 2²⁵⁶ (so `𝕌`-results = integer results) | R4b | true with vast margin (`totalWeight < 2¹⁶`); stated, not yet internalized in Lean |
| **GB-3** | Gap-B encoding fidelity: the `For` node mirrors the loop's iterate-and-accumulate *skeleton*, not the whole signature routine | R4b | the no-double-count discipline is Phase A's `ValidRun`; crypto is MC-2 |
| **K-1** | Kontrol base+step compose to ∀K at the *meta* level (no native loop-invariant rule in 1.0.248) | R3 | each piece machine-checked; composition by standard induction. Subsumed by Lean R4a (internal induction) |
| **K-2** | Kontrol checks a faithful Solidity *model*, not the inline-assembly bytecode | R3 | bytecode side at K≤3 via Halmos `RelaySigParamFV`; tied by `RelayModelBridgeFV`; full bridge = future bmc-depth-1 obligation (`docs/relay-t1-bridge.md`) |
| **C-1** | Certora storage invariants not cloud-dischargeable (assembly storage-havoc) | R3 | **blocked**, not a bug; per-sequence forms proven at R2; ghost/hook re-modeling possible but re-introduces faithfulness risk |
| **A-EVM** | EVMYulLean *is* the EVM | R4b | validated against Ethereum execution-spec test suites (not provable; standard residual) |

---

## 10.3 The master claims ledger

Each row: the property, the strongest rung that establishes it, the object/coverage there, the evidence
artifact, and the assumptions it leans on. Lower rungs often corroborate the same property at higher
fidelity / lower coverage (noted).

| # | Property | Strongest rung | Object · coverage | Status | Evidence | Relies on |
|---|----------|----------------|-------------------|--------|----------|-----------|
| 1 | **Threshold soundness** (accept ⟹ enough distinct weight, no double-count) | R4a Lean | abstract algorithm · **∀N∀K** | **proven** (`[propext,Quot.sound]`) | `RelaySigLoop.lean:threshold_sound` | MC-1,2,3 |
| 1b | same, on **validated EVM semantics** (loop mechanism) | R4b Lean | validated EVM · **∀N** | **proven** (`[propext,choice,Quot.sound]`) | `gapB/GapB_close.lean:bytecode_threshold_sound` | + GB-1,2,3, A-EVM |
| 1c | same, **∀K** | R3 Kontrol | Solidity model · ∀K, N∈{3,5} | **proven** | `kontrol/RelaySigLoopFV.t.sol` | + K-1,2 |
| 1d | same, on **real bytecode**, bounded | R2 Halmos | bytecode · K≤3,N≤5 | **proven** | `RelaySigFV`, `RelaySigParamFV` | MC-1,2,3 |
| 1e | model↔bytecode bridge (`psAt` invariant) | R2 Halmos | bytecode · K≤3 | **proven** | `RelayModelBridgeFV` | MC-1,2 |
| 2 | `relay()` **epoch-decision matrix** (all 5 gates) | R2 Halmos | bytecode · bounded | **proven** | `RelayWrongEpochFV`, `RelayDelayedPolicyFV`, `RelayFinalizationWindowFV`, `RelayCrossEpochFV`, `RelayThresholdScalingFV`, `RelayMustUseNewPolicyFV` | MC-1..5 |
| 3 | **threshold-increase rescale never weakens / no overflow** | R2 Halmos | arithmetic model · all 16-bit | **proven** | `RelayThresholdScalingFV` | — |
| 4 | threshold consistency (setter + live Mode-1) | R2 Halmos | bytecode · bounded | **proven** | `RelayThresholdConsistencyFV`, `RelayModeOneFV` | MC-1,2,3 |
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
| 13 | **fee conservation** (`relay()` + `verify()`) | R2 Halmos | bytecode | **proven** | `RelayFeeConservationFV`, `RelayVerifyFeeFV` | — |
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
  + data layer / overflow / encoding                                          [GB-1, GB-2, GB-3]
  + cryptography / trusted setter / OZ / oldRelay                             [MC-1..5]
```

Outside the chain are exactly the registered assumptions. The engineering value of the stack is that this
trusted surface is **small, named, and individually attackable** — instead of "trust 930 lines of assembly
by eye."

---

## 10.5 The residual, and what would shrink it (leverage-ordered)

Each item, if done, moves a row from *assumed/blocked* toward *proven*.

1. **Discharge GB-1 in Lean (highest value).** Replace the index addend with a memory read and prove
   `mload(weights[i]) = w[i]` — either a runtime EVMYulLean test exe that links the FFI memory model and
   checks representative layouts, or a symbolic memory-fragment axiomatization + a proof that the loop's
   slot arithmetic addresses it. Collapses most of the R4→R5 gap.
2. **Tighten GB-3 / K-2.** Parse the emitted optimized Yul for the signature loop and prove the parsed AST
   refines the Gap-B `For` node; and discharge the bmc-depth-1 model↔bytecode equivalence for Kontrol
   (`docs/relay-t1-bridge.md`). Removes "is this the real loop?" for both R3 and R4b.
3. **Internalize GB-2.** Carry a `Σ < 2²⁵⁶` hypothesis through `loop_acc` and prove `ofNat`-additivity under
   it, making the `𝕌`→`ℕ` identification a theorem rather than a side remark.
4. **Glue rows 1 and 1b explicitly.** A Lean lemma transporting `bytecode_threshold_sound` (modular,
   index-addend) to `threshold_sound` (integer, weight-addend) **under GB-1+GB-2**, with the assumptions as
   visible hypotheses.
5. **If an audit requires C-1.** Re-model Relay's storage in CVL with ghost vars + raw `Sstore`/`Sload`
   hooks mirroring the assembly writes, then state the invariants over ghosts — substantial, and it
   re-introduces the faithfulness risk the engagement otherwise avoids. Only if all-functions storage
   invariants are a hard requirement.
6. **Regression-watch the walls.** Periodically re-confirm the Kontrol symbolic-N / Certora storage-havoc
   stalls are unchanged, keeping the justification for R4 current.

None is required for the result *as stated* (the ledger is complete on its own terms); they are the path
from "small named trusted surface" toward "nothing trusted but the kernel, the EVM test suites, and the
cryptography."

---

## 10.6 What is *not* claimed (to forestall over-reading)

- **Not claimed:** "the deployed `Relay.sol` bytecode is fully formally verified." The real statement is the
  ledger §10.3 + the assumptions §10.2.
- **Not claimed:** the Gap-B loop is a verbatim copy of the signature routine. It is the
  iterate-and-accumulate skeleton (GB-3), addend abstracted (GB-1), crypto out of scope (MC-2).
- **Not claimed:** the cryptography is verified. It is assumed (MC-1, MC-2).
- **Not claimed:** correctness in `𝕌` equals correctness in `ℕ` for free. It needs GB-2 (true with vast
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
