# L10 — Claims ledger, trust & residual

> **Supersession notice (2026-08-12).** This ledger preserves the engagement's historical claims and
> assumptions. It contains pre-owner-timelock rows and is not a current release attestation. Cite
> [`CURRENT-STATUS.md`](CURRENT-STATUS.md) for executable current evidence; cite this file only as design
> history.

> **What you get from this level — the audit core.** A single, traceable register of _everything_: each
> claim → the tool/rung that establishes it → its object and coverage → proven/assumed/blocked → the exact
> evidence artifact → the assumptions it relies on. Plus the standing **modeling contract**, the **trust
> chain**, the **residual** (with a leverage-ordered checklist), and an explicit **"what is not claimed."**
> It is retained so earlier decisions remain auditable; it no longer controls current verdicts.

**Convention.** _Proven_ = a machine-checked artifact whose statement is the claim, at the bar its tool
defines (§10.1). _Assumed_ = a hypothesis not discharged by the tool, justified separately and registered
in §10.2. _Blocked_ = specified but not dischargeable by the chosen tool (with the reason).

---

## 10.1 The per-tool "proven" bar

| Rung          | "Proven" means                                                                                                                                                                                                                    |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R0/R1 Foundry | test passes (concrete) / no counterexample over the fuzz budget (random)                                                                                                                                                          |
| R2 Halmos     | `check_*` proof passes with **no counterexample** AND its paired `reach` control **produces** a counterexample (non-vacuous), under `loop=6`; judged by `verify_fv.py`                                                            |
| R3 Kontrol    | every manifest-listed proof passes and every listed reachability control has a concrete counterexample model in Kontrol's JUnit report, under Kontrol 1.0.248; exact inventory and process status enforced by `verify_kontrol.py` |
| R3 Certora    | a method/rule assertion has `SUCCESS` and passes the applicable nonvacuity check, or an explicit `satisfy` clause has a validated concrete SAT model; `SANITY_FAIL` leaves that method/rule pair unpromoted                       |
| R4 Lean       | manifest-listed theorem whose statement _is_ the claim; exact file/audit inventory; no `sorry`/`admit`/`native_decide`; `#print axioms` limited to the standard three plus the three named local declarations in §11.8            |

---

## 10.2 The assumption register (the trusted surface)

Five groups: the **modeling contract** (cryptographic / trust, by design), the **operational boundary-call
contracts** (the EVM-level behavior of every external/precompile call), the **bytecode-refinement
residuals**, the **tool-coverage limits**, and the historical **GSS remote-governance boundaries**.

### Modeling contract — cryptographic & trust (MC)

| ID       | Assumption                                                                                                                                                                           | Justification                                                                                                                                                                 |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MC-1** | `keccak256` is an injective uninterpreted function (collision-resistance)                                                                                                            | curve/hash math is not an EVM-level fact; proving it would be circular                                                                                                        |
| **MC-2** | `ecrecover` recovery is _mathematically_ unforgeable: one cannot produce `(v,r,s)` recovering to an address whose key one does not hold (ECDSA security)                             | cryptographic assumption outside the EVM; the on-chain half (weight credited to `voters[i]` only when the recovered signer equals `voters[i]`, each index once) is **proven** |
| **MC-3** | the signing-policy setter (FlareSystemsManager) supplies distinct, non-zero, canonically-ordered voters with normalized weights; `startingVotingRoundId` non-decreasing (**RLY-06**) | documented, not on-chain-enforced; [`docs/relay-phase3-documented-items.md`](../relay-phase3-documented-items.md)                                                             |
| **MC-4** | OZ `MerkleProof.verifyCalldata` internals are correct (call-site in scope)                                                                                                           | audited library                                                                                                                                                               |
| **MC-5** | `oldRelay` is a trusted, audited prior deployment; its return values are honest                                                                                                      | deployment assumption                                                                                                                                                         |

### Operational boundary-call contracts (OP) — the EVM-level behavior of each external call

Each row states the **operational contract** of a boundary call, the **code-side obligation** that makes
the contract safe, and **how that obligation is verified**. These are distinct from the mathematical
assumptions above: they are about _EVM/ABI behavior_, not cryptography.

| ID       | Boundary (site)                                                                                                     | Operational contract                                                                                                                 | Required code-side obligation                                                                                                                                                      | Verified by                                                                                                                                                                                                                                                        |
| -------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **OP-1** | `ecrecover` precompile `0x01` — raw `staticcall` ([`Relay.sol`](../../contracts/protocol/implementation/Relay.sol)) | **does not revert on a bad signature**: the `staticcall` can return _success with empty data_ and leave the output buffer unmodified | the call site must check call success, exact 32-byte return data, and a nonzero recovered signer                                                                                   | [`RelayEcrecoverABI.t.sol`](../../test-forge/fv/RelayEcrecoverABI.t.sol), [`RelayEcrecoverSymbolicFV.t.sol`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol), and the custom-error ABI gate; current run status is in [`CURRENT-STATUS.md`](CURRENT-STATUS.md) |
| **OP-2** | `keccak256` (`SHA3` opcode)                                                                                         | total & deterministic; cannot return malformed output or "fail" (only out-of-gas)                                                    | none beyond gas                                                                                                                                                                    | inherent (opcode); MC-1 supplies the algebraic model                                                                                                                                                                                                               |
| **OP-3** | `oldRelay.*` external calls                                                                                         | a real cross-contract call that may revert and re-enter Relay; value may be forwarded                                                | prove failure propagation and fee conservation in the current implementation; do not infer a global "no delegatecall" fact because current UUPS upgrade code does use delegatecall | current tests/manifest reports plus MC-5 return-value trust                                                                                                                                                                                                        |
| **OP-4** | self-call `address(this).call(_relayMessage)` (`Relay.sol:1730`, `_verifyCustomSignature`)                          | ordinary external call to self: returns `(success, returnData)`; re-enters the `relay()` path                                        | `require(success)` + `require(returnData.length == 35)` (the RLY-07 mode-1 discriminator)                                                                                          | Foundry custom-signature tests + review                                                                                                                                                                                                                            |
| **OP-5** | precompile **surface bound**                                                                                        | the **only** precompile used is `0x01`; no `sha256 (0x02)`, identity, modexp, or EC ops are called                                   | n/a (bounds which OP-contracts are in play)                                                                                                                                        | assembly review (`docs/relay-assembly-review.md`)                                                                                                                                                                                                                  |

> **FV modelling note (OP-1).** Halmos's _built-in_ `0x01` is a _total_ function that always returns a
> well-formed 32-byte address (`E(hash,v,r,s) → address`, `returndatasize()==32`), so the whole-`relay()`
> symbolic runs do not, by themselves, exercise the OP-1 failure mode (empty return / stale buffer) — using
> the adversary-conservative uninterpreted recovery for the _accounting_ proofs. The failure mode is now
> **internalized symbolically** by `RelayEcrecoverSymbolicFV.t.sol`: it reaches the empty-return branch via a
> mock that reproduces the precompile's failure ABI and proves — over ALL stale-buffer contents — that the
> `staticcall`-success / `returndatasize()==32` / non-zero-signer guard rejects a bad signature and never
> reads the stale buffer. Together with the real-EVM regression (`RelayEcrecoverABI.t.sol`, which pins that
> the _actual_ `0x01` exhibits this ABI), OP-1 is discharged both symbolically and concretely.
> **Scope precision:** the symbolic harness proves the guard **pattern** — a faithful _mirror_ of
> `Relay.sol:1283-1302`, re-implemented in the harness — not Relay's deployed guard bytes themselves; the
> identification "Relay's assembly implements exactly this pattern" rests on the assembly review
> ([`docs/relay-assembly-review.md`](../relay-assembly-review.md)) and the concrete failure-path tests. Any
> change to the `ecrecover` block must re-establish OP-1.

### Bytecode-refinement residuals (BR) — the R4b model-to-deployment gap

| ID       | Assumption                                                                                 | Status                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| -------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **BR-1** | data layer: each modeled iteration's addend is the registered weight of the selected voter | **derived inside the literal model.** [`RelayLoopMemRead.relay_loop_sound`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopMemRead.lean#L455) assumes read/weight correspondence; [`RelayBodyEff.relay_loop_sound_literal_derived_tight`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean#L1678) derives the masked read from its raw-calldata/memory preconditions. Residual: connect those preconditions, `ValidRun`, and acceptance to every accepted compiled execution, plus ecrecover (MC-2/OP-1). |
| **BR-2** | overflow bound: sums don't wrap 2²⁵⁶ (so `𝕌`-results = integer results)                    | **internalized in Lean** (`absAcc_val` / `bytecode_threshold_sound_int`): under the explicit hypothesis `Σ < 2²⁵⁶`, the modular accumulator equals the integer accumulator and accept ⟹ _integer_ total > thr. The hypothesis holds with vast margin (`totalWeight < 2¹⁶`).                                                                                                                                                                                                                                                    |
| **BR-3** | encoding fidelity: does the modeled loop match the deployed one?                           | Current solc 0.8.35 artifact/Yul parity passes locally. `bodyL` remains a hand transcription; no parser/extractor proves AST equivalence. See [`CURRENT-STATUS.md`](CURRENT-STATUS.md).                                                                                                                                                                                                                                                                                                                                        |
| **BR-4** | protocol-1 threshold setup crosses `TSTORE -> self-call -> TLOAD -> threshold-local`       | EVMYulLean operation/state round-trip, clear, isolation, arithmetic, and strict-loop composition are proved. [`RelayBodyEff.protocolOne_tload_override_loop_sound`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean#L1717) retains `hsetupThreshold` for the unextracted call-frame setup; propagation/rollback across that frame is not a Lean claim. Bounded Halmos checks cover concrete cleanup and caught-revert rollback.                                                                                 |

### Tool-coverage limits

| ID        | Limitation                                                                                     | Status                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| --------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **K-1**   | Kontrol base+step compose to ∀K at the _meta_ level (no native loop-invariant rule in 1.0.248) | each piece machine-checked; composition by standard induction. Subsumed by the abstract Lean proof (internal induction)                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **K-2**   | Kontrol checks a faithful Solidity _model_, not the inline-assembly bytecode                   | bytecode side at K≤3 via Halmos `RelaySigParamFV`; tied by `RelayModelBridgeFV`; full bridge = future bmc-depth-1 obligation ([`docs/relay-t1-bridge.md`](../relay-t1-bridge.md))                                                                                                                                                                                                                                                                                                                                                                    |
| **C-1**   | Certora storage/threshold rules vs. assembly and upgrade dispatch                              | The current local front end passes 3/3 configs and 15 rules on `d5af7136…`, but this is not a prover verdict. The supplemental cloud report is PARTIAL: threshold PASS, scalar/write-once PARTIAL, with 308 `SUCCESS`, 2 validated `SATISFIED`, 24 `SANITY_FAIL`, and no semantic CEX/`UNKNOWN`/`TIMEOUT`. Claims remain bounded by `loop_iter=3`, optimistic loops, ≤512-byte optimistic hashing, `viaIR` resolution limits, and explicit initialization/UUPS/queued-upgrade exclusions. Mechanics: [`certora/README.md`](../../certora/README.md). |
| **A-EVM** | EVMYulLean _is_ the EVM                                                                        | two parts of different strength ([L2 §2.5](02-strategy-and-the-fidelity-ladder.md)): the **opcode/memory layer** the proofs use (shared `step` dispatch, `MachineState`) sits on the path validated against the Ethereum execution-spec suites; the **Yul control-flow layer** (`Yul.exec`/`loop`, fuel) that drives the R4b proofs is Yul-specific, validated separately by Yul semantic tests (not provable; standard residual)                                                                                                                    |

### GSS remote-governance acceptance boundaries (GA) — retired

These were deliberate protocol and operational choices bounding what "secure GSS
governance" meant in this engagement. The GSS design and its risk register were
retired before any deployment (git history); Relay governance is now a per-chain
owner + timelock ([`relay-governance.md`](../relay-governance.md)). The rows below
are the historical record.

| ID       | Accepted boundary                                                                                                           | Consequence for security claims                                                                                                                                                                                                 |
| -------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **GA-1** | A Safe-owner threshold signature is remote authorization without proof that the transaction executed successfully on Flare. | Cancellation, failure, non-execution, and source-nonce replacement do not revoke copied signatures. Official relayer receipt checks are defense in depth because Relay submission is permissionless.                            |
| **GA-2** | Target chains progress independently and need not process every Safe nonce.                                                 | Owner generations and fee state may temporarily diverge; first relevant delivery and the global high-water mark determine each target's state. Rotation and migration order are security-relevant operational controls.         |
| **GA-3** | The owner threshold is trusted for governance integrity and liveness, including nonce and fee selection.                    | Contradictory same-nonce signatures, an extreme future nonce, or an uneconomic fee are governance self-harm rather than an unprivileged authorization bypass. The contract intentionally does not make quorum actions harmless. |
| **GA-4** | Production uses EOA EIP-712 owners and one authoritative Relay deployment per target chain.                                 | Other Safe signature modes are rejected, and a second same-chain Relay with the same generation can replay an action unless replacement controls or a deployment-bound message format are used.                                 |

---

## 10.3 The master claims ledger

Each row: the property, the strongest rung that establishes it, the object/coverage there, the evidence
artifact, and the assumptions it leans on. Lower rungs often corroborate the same property at higher
fidelity / lower coverage (noted).

| #   | Property                                                                                                                                                                                                      | Strongest rung                    | Object · coverage                                                               | Status                                                                                                                                                                    | Evidence                                                                                                                                                 | Relies on                                                                                                                  |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Threshold soundness** (accept ⟹ enough policy-slot weight; no slot reused)                                                                                                                                  | R4a Lean                          | abstract algorithm · **∀N∀K**                                                   | **current Lean gate passes as stated** (`[propext,Quot.sound]`); distinct voter addresses remain MC-3                                                                     | [`RelaySigLoop.lean:threshold_sound`](../../test-forge/fv/lean/RelaySigLoop.lean)                                                                        | MC-1,2,3                                                                                                                   |
| 1b  | same, on **validated EVM semantics** (loop mechanism)                                                                                                                                                         | R4b Lean                          | validated EVM · **∀N**                                                          | **current Lean gate passes as stated** (`[propext,choice,Quot.sound]`)                                                                                                    | [`bytecode-refinement/RelayBytecodeRefinement.lean:bytecode_threshold_sound`](../../test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean) | + MC-3, BR-1,2,3, A-EVM                                                                                                    |
| 1b′ | same, on the **literal hand-transliterated 17-statement body model**; memory reads and index guards derived                                                                                                   | R4b Lean                          | validated EVM · **∀N**, conditional execution                                   | **current Lean gate passes as stated** (`[propext,choice,Quot.sound]`)                                                                                                    | [`bytecode-refinement/RelayBodyEff.lean:relay_loop_sound_literal_derived_tight`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean)         | + MC-3, ecrecover (MC-2/OP-1), `ValidRun`, successful modeled execution/acceptance, A-EVM                                  |
| 1c  | same, **∀K**                                                                                                                                                                                                  | R3 Kontrol                        | Solidity model · ∀K, N∈{3,5}                                                    | **historical model result; not rerun for current architecture**                                                                                                           | [`kontrol/RelaySigLoopFV.t.sol`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol)                                                                       | + MC-3, K-1,2                                                                                                              |
| 1d  | same, on **real bytecode**, bounded                                                                                                                                                                           | R2 Halmos                         | bytecode · K≤3,N≤5                                                              | **current development Halmos PASS: 7/7 proofs + 2/2 reachability controls within the stated K/N bounds; 0 solver loop bounds or `STUCK`**                                 | `RelaySigFV`, `RelaySigParamFV`                                                                                                                          | MC-1,2,3, OP-1                                                                                                             |
| 1e  | model↔bytecode bridge (`psAt` invariant)                                                                                                                                                                      | R2 Halmos                         | bytecode · K≤3                                                                  | **current development Halmos PASS: 3/3 proofs + 1/1 reachability control within K≤3; 0 solver loop bounds or `STUCK`**                                                    | `RelayModelBridgeFV`                                                                                                                                     | MC-1,2,3, OP-1                                                                                                             |
| 2   | `relay()` **epoch-decision matrix** (all 5 gates)                                                                                                                                                             | R2 Halmos                         | bytecode · bounded                                                              | **current development Halmos PASS: 9/9 proofs + 6/6 reachability controls across the listed harnesses within their manifest bounds; 0 solver loop bounds or `STUCK`**     | `RelayWrongEpochFV`, `RelayDelayedPolicyFV`, `RelayFinalizationWindowFV`, `RelayCrossEpochFV`, `RelayThresholdScalingFV`, `RelayMustUseNewPolicyFV`      | MC-1..5, OP-1                                                                                                              |
| 3   | **threshold-increase rescale never weakens / no overflow**                                                                                                                                                    | R2 Halmos                         | arithmetic model · all 16-bit                                                   | **current development Halmos PASS: 3/3 proofs + 1/1 reachability control over the stated all-16-bit model; 0 solver loop bounds or `STUCK`**                              | `RelayThresholdScalingFV`                                                                                                                                | —                                                                                                                          |
| 4   | threshold consistency (setter + live Mode-1)                                                                                                                                                                  | R2 Halmos                         | bytecode · bounded                                                              | **current development Halmos PASS: 3/3 proofs + 2/2 reachability controls within the stated harness bounds; 0 solver loop bounds or `STUCK`**                             | `RelayThresholdConsistencyFV`, `RelayModeOneFV`                                                                                                          | MC-1,2,3, OP-1                                                                                                             |
| 5   | **access control** (only setter rotates policy)                                                                                                                                                               | R2 Halmos                         | bytecode · bounded                                                              | **current development Halmos PASS: 1/1 proof + 1/1 reachability control within the stated harness bounds; 0 solver loop bounds or `STUCK`**                               | `RelayAccessControlFV`                                                                                                                                   | MC-3                                                                                                                       |
| 6   | initialization **fail-closes** on bad config                                                                                                                                                                  | R2 Halmos                         | real Relay initializer plus proxy-aware bytecode checks                         | **current development Halmos PASS: constructor harness 5/5 proofs + 1/1 reachability control, plus the proxy-initializer invariant; 0 solver loop bounds or `STUCK`**     | `RelayConstructorFV` (historical name) and `RelayOwnerUpgradeFV`                                                                                         | CREATE-free initializer harness; proxy atomicity corroborated separately                                                   |
| 7   | GSS distinct-owner threshold validation, action/Safe nonce binding, generation-bound owner transitions, global fee monotonicity, canonical atomic fees, irrelevant-target no-op, and consumed-nonce exclusion | R2 Halmos                         | bytecode · bounded post-recovery state machine                                  | **historical — harness retired with the GSS design** (13 proofs + 2 reachability controls at the time)                                                                    | `SafeGovernanceFV.t.sol` (removed; git history)                                                                                                          | recovered-signer/ECDSA and Safe-digest boundary                                                                            |
| 7b  | owner-timelock guarded-surface authorization, queue-not-apply, bounded duration, consumption and flag cleanup                                                                                                 | R3 Certora                        | current source/harness · filtered methods, optimistic loops bounded at 3        | **cloud PARTIAL:** successful rule nodes and two validated SAT witnesses exist, but affected method/rule pairs with `SANITY_FAIL` are not promoted                        | [`RelayWriteOnce.spec`](../../certora/specs/RelayWriteOnce.spec)                                                                                         | reachable external boundary (`executing=false`); optimistic-loop/hash bounds; trusted upgrade; direct-implementation scene |
| 7c  | Complete Safe digest binding, real ECDSA recovery, successful source-Safe calldata, owner rotation, and multi-target fee delivery                                                                             | R0/R1 Foundry                     | bytecode · concrete + 256-run differential fuzz + stateful invariant            | **historical — suites retired with the GSS design**                                                                                                                       | the 36-test GSS gate (`SafeGovernance.t.sol`, `SafeGovernanceProductionRehearsal.t.sol`, `SafeGovernanceInvariant.t.sol`; removed, git history)          | ECDSA, pinned Safe v1.3.0, relayer source-execution policy                                                                 |
| 7d  | source-domain, owner, fee-recipient, mode, delay and epoch scalar preservation                                                                                                                                | R3 Certora                        | current implementation · ordinary filtered calls, optimistic loops bounded at 3 | **cloud PARTIAL:** successful nodes are evidence only where the applicable sanity check passes; 24 scalar/mapping method pairs remain excluded across the cloud suite     | [`RelayInvariants.spec`](../../certora/specs/RelayInvariants.spec)                                                                                       | optimistic-loop/hash bounds; `viaIR` resolution limits; explicit initialization/UUPS/queued-upgrade exclusions             |
| 8   | epoch **+1 advance** + `lastInitialized` monotone (state-effect)                                                                                                                                              | R2 Halmos                         | bytecode                                                                        | **current development Halmos PASS: 2/2 proofs + 1/1 reachability control within the manifest harness; 0 solver loop bounds or `STUCK`**                                   | `RelayEpochAdvanceFV`                                                                                                                                    | —                                                                                                                          |
| 8b  | `lastInitialized` monotone for ordinary current-implementation calls (initialization, direct upgrade, and queued-upgrade dispatch excluded)                                                                   | R3 Certora                        | current source · declared method filter, optimistic loops bounded at 3          | **cloud PARTIAL:** promote only successful method nodes whose applicable sanity nodes pass                                                                                | `RelayInvariants.spec:lastInitializedMonotonic`                                                                                                          | MC-1; optimistic-loop/hash bounds; trusted-upgrade boundary                                                                |
| 9   | random-pointer **monotonicity**                                                                                                                                                                               | R3 Kontrol + R2 Halmos            | model ∀K / bytecode bounded                                                     | **historical Kontrol result; current development Halmos PASS: 3/3 proofs + 1/1 reachability control within the bytecode harness bounds; 0 solver loop bounds or `STUCK`** | [`kontrol/RelayRandomMonoFV.t.sol`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol), `RelayRandomMonotonicityFV`                                    | MC-1                                                                                                                       |
| 10  | random value **binding / no-forgery**                                                                                                                                                                         | R2 Halmos                         | bytecode                                                                        | **current development Halmos PASS: 2/2 proofs + 1/1 reachability control within the manifest harness; 0 solver loop bounds or `STUCK`**                                   | `RelayRandomBindingFV`                                                                                                                                   | MC-1                                                                                                                       |
| 11  | Merkle proof-element + alignment soundness                                                                                                                                                                    | R2 Halmos                         | bytecode                                                                        | **current development Halmos PASS: 2/2 proofs + 1/1 reachability control within the manifest harness; 0 solver loop bounds or `STUCK`**                                   | `RelayMerkleProofFV`                                                                                                                                     | MC-1,4                                                                                                                     |
| 12  | Merkle fold injectivity for a **fixed sibling/path sequence** (base, step, depth-2 machine checks; arbitrary-depth induction at meta level)                                                                   | R2 Halmos                         | fold model                                                                      | **current development Halmos PASS: 3/3 proofs + 1/1 reachability control for the stated base/step/depth-2 model; 0 solver loop bounds or `STUCK`**                        | `RelayMerkleFoldFV`                                                                                                                                      | MC-1; not full arbitrary-proof membership soundness                                                                        |
| 13  | **fee conservation** (`relay()` + `verify()`, incl. old-relay forwarding)                                                                                                                                     | R2 Halmos                         | bytecode                                                                        | **current development Halmos PASS: 4/4 proofs + 2/2 reachability controls across both harnesses; 0 solver loop bounds or `STUCK`**                                        | `RelayFeeConservationFV`, `RelayVerifyFeeFV`                                                                                                             | OP-3, OP-4                                                                                                                 |
| 14  | encoding canonicality / secure-bit / return discriminator / policy hash (P3/P5/P6/P8)                                                                                                                         | R2 Halmos                         | bytecode                                                                        | **current development Halmos PASS: 12/12 proofs + 7/7 reachability controls across the listed harnesses within their manifest bounds; 0 solver loop bounds or `STUCK`**   | `RelayCanonicalityFV`, `RelayIsSecureNormFV`, `RelayReturnDiscriminatorFV`, `RelayPolicyHashFV`                                                          | MC-1                                                                                                                       |
| 15  | functional behavior, all modes                                                                                                                                                                                | R0/R1 Foundry                     | bytecode · concrete+fuzz                                                        | **current development run passes 2,079/2,079 overall; Relay unit file 70/70, exact-BIPS suite 11/11, governance 39/39, deployment suites green, and Hardhat Relay 53/53** | current Relay and owner/timelock/UUPS suites listed in L3 and `relay-governance.md`                                                                      | —                                                                                                                          |
| 15b | RLY-23 chain-domain binding — _structure_: the stored/verified signing-policy hash is `keccak256(sourceChainId ‖ contentFold)`                                                                                | R2 Halmos                         | real bytecode · all symbolic policies (N≤3)                                     | **current development Halmos PASS: 3/3 equivalence proofs + 1/1 mismatch reachability control within N≤3; 0 solver loop bounds or `STUCK`**                               | [`RelayPolicyHashFV`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L63)                                                                                   | MC-1 (keccak)                                                                                                              |
| 15c | RLY-23 chain-domain binding — _effect_: signatures minted for one source are rejected by a Relay bound to a _different_ source, while a mirror of the same source accepts them                                | R0 Foundry (concrete, real ECDSA) | bytecode · concrete                                                             | **current Relay chain-domain suite passes 10/10; the Relay unit file passes 70/70**                                                                                       | [`RelayChainDomain.t.sol`](../../test-forge/unit/protocol/implementation/RelayChainDomain.t.sol)                                                         | MC-2 (ECDSA)                                                                                                               |
| 16  | signing-policy **mode** stable; policy hash and root write-once for ordinary current-implementation calls                                                                                                     | R3 Certora                        | source · declared scope, optimistic loops bounded at 3                          | **cloud PARTIAL:** successful method nodes are scoped by their nonvacuity outcomes; sanity-failed pairs remain unproved                                                   | [`RelayInvariants.spec`](../../certora/specs/RelayInvariants.spec), [`RelayWriteOnce.spec`](../../certora/specs/RelayWriteOnce.spec)                     | MC-1; reachable-state epoch link; optimistic-loop/hash bounds; `viaIR`/trusted-upgrade boundaries                          |

**Reading the ledger.** The security core (row 1) is established at four complementary fidelities: ∀N∀K
abstract under `ValidRun` (R4a), conditional ∀N statements on validated semantics (R4b), ∀K on a fixed-N
model (R3), and bounded on real bytecode (R2) with an explicit bridge (1e). These results corroborate one
another but are not a single whole-program refinement theorem. Rows 7/7c are
historical GSS evidence. Rows 7b/7d, 8b, and 16 describe the
current owner-timelock Certora cloud result. Its threshold configuration passes;
rows 7b/7d, 8b, and 16 remain partial because the scalar/write-once jobs retain
24 exact sanity failures. All cloud claims remain bounded by the configured
loop/hash/UUPS scope.

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

> For a reader-facing, tiered walk-through of these residuals _as weaknesses / attack surface_ — what each
> would mean if it went wrong, which are code-local vs. trust boundaries vs. coverage gaps, and a few cheap
> hardening suggestions — see **[L13 — Residual weaknesses & attack surface](13-residual-weaknesses.md)**. This
> section remains the formal register behind it.

| Assumption(s)                                                                               | Class                                                                | Status / cost                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MC-1, MC-2** (keccak / ECDSA hardness)                                                    | Permanent — irreducible                                              | leave; cannot be proven unconditionally                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **A-EVM** (EVMYulLean = the EVM)                                                            | Permanent — irreducible                                              | leave; validated by conformance tests, not provable (hardenable by cross-validation)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **MC-3** (trusted setter), **MC-5** (oldRelay)                                              | Permanent — trust boundary by design                                 | leave; on-chain enforcement would be a _contract change_, not verification                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **GA-1..4** (GSS authorization, asynchronous targets, quorum authority, production profile) | Historical only                                                      | retired before deployment; not part of the owner-timelock trust model                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **MC-4** (OZ `MerkleProof`)                                                                 | Borderline                                                           | conventionally assumed; cheaply verifiable if an audit demands zero library trust                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **BR-2** (overflow bound)                                                                   | Addressable                                                          | ✅ **done** — `bytecode_threshold_sound_int`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **OP-1** (ecrecover failure ABI)                                                            | Addressable                                                          | ✅ **done** — real-EVM regression ([`RelayEcrecoverABI.t.sol`](../../test-forge/fv/RelayEcrecoverABI.t.sol)) **and** symbolic internalization ([`RelayEcrecoverSymbolicFV.t.sol`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol): the guard proven against the empty-return/stale-buffer ABI over all stale contents)                                                                                                                                                                                                                                                                                                                                                      |
| **BR-3 / K-2** (encoding fidelity, model↔bytecode)                                          | Addressable                                                          | **partially closed** — compiler artifact and optimized-Yul provenance are exact; `bodyL` is still a hand transcription with D1–D4 deviations and no AST-extraction/equivalence proof. Early return is modeled, while deriving the modeled premises and D3 accept-write from one compiled accepted execution remains open.                                                                                                                                                                                                                                                                                                                                                       |
| **BR-4** (protocol-1 transient threshold setup seam)                                        | Addressable — operation/state + arithmetic composition landed        | `TSTORE`/`TLOAD` round-trip, zero clear, address isolation, exact floor/cross-product arithmetic, no wrap, and strict-loop composition are machine-checked. `hsetupThreshold` remains explicit for the complete self-call call-frame setup; bounded Halmos separately covers cleanup and caught-revert rollback.                                                                                                                                                                                                                                                                                                                                                                |
| **BR-1** (data layer, `mload = w[i]`)                                                       | **Proven inside the stated models**                                  | `DataLayer`, `RelayLoopMemRead`, and `RelayBodyEff` machine-check byte decoding, memory round-trip, masking, the memory-reading loop, and the literal body's read extraction. `relay_loop_sound_literal_derived_tight` derives `hcov`/`hcorr` and guards from its preconditions, but `ValidRun`, successful execution/acceptance, and ecrecover remain explicit; transporting them from every compiled accepted execution is still BR-3. Three local declarations implement the two upstream-dischargeable data/window spec shapes.                                                                                                                                             |
| `relay()` breadth model, **OP-3/4**                                                         | Addressable — **components landed; composition remains conditional** | R4b's literal loop statements are hole-free under their explicit execution, `ValidRun`, and acceptance hypotheses. R5 adds independently checked storage round-trip/accept-write, mode dispatch, conditional dispatch→loop→accept composition, and fee-conservation components. **Remaining:** derive setup, valid-run, early-return acceptance, and accept-write from one accepted compiled execution; wire exec-level `.CALL`; reconcile D3 (modeled return vs deployed break→write→return). These are breadth/linkage residuals, not additional abstract accounting lemmas.                                                                                                  |
| **C-1** (Certora current scoped storage/threshold rules)                                    | Addressable — threshold cloud PASS; scalar/write-once cloud PARTIAL  | 3/3 configs and 15 rules compile/CVL-typecheck locally on `d5af7136…`; that local result is not a prover verdict. Cloud normalization records 308 `SUCCESS`, 2 validated `SATISFIED`, 24 `SANITY_FAIL`, and no semantic CEX/`UNKNOWN`/`TIMEOUT`. Threshold proves a pure exact-math lemma and `_thresholdBIPS >= 10000` fail-fast before `SSTORE`/`TSTORE`/external `CALL`; it does not link that lemma to the successful Yul-local path. Successful forwarding/cleanup/rollback/mode isolation are Halmos/Lean claims. Loop/hash optimism, `viaIR` resolution, and direct-implementation/UUPS boundaries remain explicit (see [`certora/README.md`](../../certora/README.md)). |

The addressable items, leverage-ordered — each, if done, moves a row from _assumed/blocked_ toward _proven_:

1. **Discharge BR-1 in Lean — ✅ DONE (was: highest value, ~1–2 months).** Replace the index addend with a
   memory read and prove `mload(weights[i]) = w[i]`; then model the _whole_ body literally. Both halves are
   now complete — the bounded data-layer foundation (below) and the literal end-to-end model
   (`RelayBodyEff.lean`, final bullet). **Decomposed to the foundation (investigated 2026-06-20):**
   - **Byte-decode layer — ✅ DONE (committed).** `test-forge/fv/lean/bytecode-refinement/DataLayer.lean`
     proves `fromBytesBigEndian_toBytesBigEndian` (the big-endian round-trip is the identity) about
     EVMYulLean's actual public functions, hole-free — it reuses EVMYulLean's existing `@[simp]
fromBytes'_toBytes'`, which fires downstream despite being `private`. The padding/bounds lemmas
     (`extend_bytes_zero`, `fromBytes'_zeroPadBytes_32_eq`) also already exist upstream. No new number
     theory needed.
   - **Memory layer — ✅ DONE (committed).** `DataLayer.lean` proves, against EVMYulLean's _actual_
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
     zero-pad) recovers the value, against EVMYulLean's _actual_ `fromByteArrayBigEndian`/`UInt256.toByteArray`
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
     memory reads (modular / integer) exceeds the threshold — hole-free, _no_ axioms beyond the standard
     three. New brick `body_effM` proves one iteration of the real `mload`+`and` body (the `mload` is
     state-preserving once the slot is active, so `activeWords` is unperturbed); `loop_accM` runs the
     `3N+15`-fuel induction. This is the **data-flow core of the simulation relation `R`**: the per-iteration
     addend is now a genuine `MLOAD`, not the loop index. The read-content hypothesis `hcov` is BR-1's
     data-layer invariant, discharged per-slot by `weight_read`, so `absAccMNat rdv 0 N 0 = sumTake w N`.
   - **Simulation relation `R`, accounting core — ✅ DONE (committed); selection/validity assumed _here_, derived in the literal model below.** `RelayLoopMemRead.lean:relay_loop_sound` composes
     the EVM accumulation with the abstract accounting: ∀N, **if the deployed loop accepts (final weight >
     threshold), the total registered policy-slot weight exceeds the threshold** — no slot index reused — on the
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
     strict-increasing in-range policy-slot indices = the deployed guards passed = no repeated slot; unique
     voter addresses remain MC-3), and `hnoovf` (BR-2,
     no overflow). Within this abstract model, the loop mechanism, `mload`, mask, accumulation, accept gate,
     and accounting soundness are proved against the validated semantics. (These are the
     hypotheses of the _abstract_ body `body_effM`; in the literal model below, `hcov`/`hcorr` and the
     structural half of `hvalid` become _theorems_, leaving only the ecrecover facts assumed as `IterPremiseT`.)
   - **Literal conditional body model — ✅ machine-checked as stated (committed; 2026-07-02/03).**
     [`RelayBodyEff.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean)
     (with [`RelayLoopLiteral.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopLiteral.lean) and
     [`RelayLoopWindows.lean`](../../test-forge/fv/lean/bytecode-refinement/RelayLoopWindows.lean)) executes a
     17-statement hand transcription `bodyL`, sourced from the optimized-Yul signature loop beginning at
     `relay_ir_optimized.yul:2157`, through EVMYulLean's validated Yul `exec`, threading modeled
     `mstore`/`calldatacopy`/`mload` state. The chain, all hole-free (`{propext, Classical.choice, Quot.sound}`;
     the accounting-extraction lemmas need only `{propext, Quot.sound}`): `body_effL` (one iteration executed) →
     `s16_ww_advance`/`s16_ii_preserved` (the body adds exactly the selected voter's registered weight and
     preserves the counter) → `iter_advance` (the per-iteration advance, i.e. `hstep`, **derived** from
     `body_effL` + the extraction) → `range_guard_pass`/`order_guard_pass`/`iter_advance_tight` (the two
     **structural** index guards — range `idx<nVot`, strict-increase `nui≤idx` — derived from `ValidRun`) →
     `loop_accL` (the ∀N induction over the literal body, threading the evolving memory) →
     `relay_loop_sound_literal` → `relay_loop_sound_literal_derived` (`hstep` discharged) →
     **`relay_loop_sound_literal_derived_tight`** (the tightened top theorem). The effect: `hcov`/`hcorr` are
     **no longer assumed** — the masked read = the selected voter's registered weight is _derived_
     (`mload_masked_voter`) from a raw-calldata memory precondition; and the structural half of `hvalid`
     (index in range, strictly increasing) is _derived_ from `ValidRun`. The only per-iteration hypothesis
     that survives (`IterPremiseT`) is the **cryptographic ecrecover facts** (`v ∈ {27,28}`, low-`s`,
     `staticcall` success, `returndatasize()==32`, signer ≠ 0, recovered signer = registered voter) plus the
     accept gate — i.e. exactly `ecrecover` (MC-2 — uninterpreted by design), stated explicitly. The accounting
     conclusion is identical to the abstract `relay_loop_sound`; what shrinks is the assumption surface, down to
     the ecrecover boundary. This _is_ the boundary between the validated-EVM accounting proof and the
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
   (`test-forge/fv/RelayEcrecoverABI.t.sol`) and now _also_ internalized symbolically by
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
   integer accumulator, so accept ⟹ _integer_ total > thr).
5. **Glue rows 1 and 1b explicitly.** A Lean lemma transporting `bytecode_threshold_sound` (modular,
   index-addend) to `threshold_sound` (integer, weight-addend) **under BR-1+BR-2**, with the assumptions as
   visible hypotheses.
6. **If an audit requires C-1.** Re-model Relay's storage in CVL with ghost vars + raw `Sstore`/`Sload`
   hooks mirroring the assembly writes, then state the invariants over ghosts — substantial, and it
   re-introduces the faithfulness risk the engagement otherwise avoids. Only if all-functions storage
   invariants are a hard requirement.
7. **Regression-watch the walls.** Periodically re-confirm the Kontrol symbolic-N / Certora storage-havoc
   stalls are unchanged, keeping the justification for R4 current.

None is required for the result _as stated_ (the ledger is complete on its own terms); they are the path
from "small named trusted surface" toward "nothing trusted but the kernel, the EVM test suites, and the
cryptography."

---

## 10.6 What is _not_ claimed (to forestall over-reading)

- **Not claimed:** "the deployed `Relay.sol` bytecode is fully formally verified." The real statement is the
  ledger §10.3 + the assumptions §10.2.
- **Not claimed:** the bytecode-refinement loop is a _verbatim byte-for-byte_ copy of the signature routine.
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
- **Not claimed:** the current Certora suite has an all-method PASS or proves
  unrestricted loop/hash inputs, proxy-context UUPS behavior, or arbitrary
  replacement semantics. The local front end passes, while the supplemental
  cloud report remains PARTIAL because 24 sanity nodes fail. The passing
  threshold job does not establish successful transient forwarding, cleanup,
  rollback, or mode isolation; those are Halmos/Lean claims.
- **Not claimed:** the whole-`relay()` extension (R5) is _byte-complete_. `relay_dispatch_loop_accept` ties
  the mode dispatch to the signature-loop accept as one machine-checked theorem, but the calldata-decode setup
  between them is carried as an explicit hypothesis (`dispatch_setup_loop_accept`), the accept-_write_ stays a
  separately-verified piece across the D3 deviation, and the exec-level `.CALL` value-transfer wiring is a
  documented boundary (§10.5). The R5 storage/dispatch/write/composition/fee results are hole-free, but each is a
  **breadth** extension, not a new soundness fact — the accounting soundness is the loop's.
- **What _is_ claimed:** the current Lean gate checks the abstract accounting
  theorem for all N and K under `ValidRun` and the conditional EVMYulLean
  statements for all N. The Kontrol results are historical. The current Halmos
  manifest declares bounded real-bytecode obligations across the matrix,
  lifecycle, owner/timelock/UUPS, Merkle, randomness, and fees; its actual run
  verdict is not implied by this ledger. R5's dispatch,
  accept-write, and fee components are individually hole-free breadth results. The compiler artifacts and
  committed optimized Yul are now mechanically hash-bound, but deriving every R4/R5 execution premise from
  a whole accepted compiled execution remains an explicit residual rather than an implied theorem.

**Next:** [L11 — Reproducibility](11-reproducibility.md): exact tools, versions, commands, and expected
outputs to re-check every row above.
