# L4 — R2: bounded symbolic execution (Halmos)

> **What you get from this level.** The workhorse rung: 26 harnesses / 89 checks that **symbolically
> execute the real `Relay.sol` bytecode** and prove properties over *all* inputs up to a fixed size. The
> suite design (including the anti-vacuity tripwire and the loop-bound subtlety that makes the whole thing
> trustworthy), the full property catalog, the modeling assumptions, and how to reproduce.

---

## 4.1 What Halmos is, and why it is the bounded floor *on the real bytecode*

Halmos runs the compiled contract with **symbolic** inputs: instead of one concrete calldata, it explores
*all* calldata at once via an SMT solver, reporting any input that violates an `assert`. Crucially it
**executes the actual bytecode** — it does not reconstruct a model from Solidity structure — so it is
**immune to the assembly barrier** (Enemy 2): Relay's hand-rolled storage is just bytecode being run.

**Which bytecode, precisely.** The artifact this repo's toolchain compiles from source — **solc
0.8.27+commit.40a35a09, optimizer 200, `evm_version=cancun`** (settings pinned in
[`foundry.toml`](../../foundry.toml); the solc version pinned by the test base's exact
`pragma solidity 0.8.27`, which fixes the whole verified compilation unit — Relay.sol's own pragma is
`^0.8.20`). Each harness deploys `new Relay(config)`, embedding Relay's creation code in the harness
artifact; Halmos runs that constructor and then symbolically executes the resulting **runtime** bytecode.
Deterministic compilation ties this artifact to a deployment (same source + compiler + settings ⇒ identical
bytes, checkable via the on-chain metadata/source verification); deployment-baked **immutables** come from
the harness's — usually symbolic — constructor config, so proofs quantify over configurations. Note the
trust profile: at this rung **solc is inside the verified object** (we check its *output*; a miscompilation
of a checked property within bound would surface as a counterexample) — the inverse of R4b, which models
the Yul IR and *trusts* solc's Yul→bytecode backend (L7 §7.4).

Its limit is the **induction barrier** (Enemy 1): loops are unrolled to a fixed depth, so coverage is
bounded — here **K ≤ 3 signatures** and **N ≤ 5 voters**. Within that bound the guarantee is exhaustive
(all inputs, not samples). This is why R2 is the bounded floor: maximal object-fidelity (real bytecode),
exhaustive-but-bounded coverage. The unbounded extension is R3/R4.

---

## 4.2 Suite design — the gate, the tripwire, the loop bound

The suite is not just a pile of `assert`s; it is engineered so that a *vacuous* pass cannot masquerade as a
proof. Three design elements:

**(a) The gate — [`test-forge/fv/verify_fv.py`](../../test-forge/fv/verify_fv.py).** Halmos's raw exit code is not a usable CI signal (the
anti-vacuity controls fail by design). The gate runs one Halmos invocation over all `check_*` functions in
`test-forge/fv/**` (for a how-to-read-the-suite primer, see [`test-forge/fv/README.md`](../../test-forge/fv/README.md)), reads the JSON, and judges each check against the exact committed manifest:

- a declared **proof** must return Halmos `PASS`;
- a declared **reachability** control must return `COUNTEREXAMPLE` with a validated model;
- the observed and declared check sets must be identical, with zero bounded loops.

It prints a per-check table and the summary line, and exits non-zero on any violation. Current CI output:

```
[fv] 89/89 checks observed: 60/60 proofs hold, 29/29 reachability controls have validated counterexamples. 0 violation(s).
[fv] OK - exact proof inventory holds and every reachability control has a valid witness.
```

**(b) The anti-vacuity tripwire.** Every property harness pairs each positive proof with a **reachability
control** that asserts the *negation* of "the interesting thing can happen" and must therefore be refuted
by a counterexample. If a control ever *passes*, the interesting path is unreachable — the proofs guarding
it have gone **vacuous** — and the gate raises a "VACUITY ALARM" (a hard failure). This is what makes a
green suite meaningful: it certifies the proofs are not trivially true.

**(c) The loop bound — [`halmos.toml`](../../halmos.toml).** The single most important config:

```toml
[global]
forge-build-out = "artifacts-forge"
loop = 6                       # NOT the default 2
solver-timeout-assertion = 0   # let valid nonlinear proofs finish
```

The default `loop = 2` *silently truncates* `relay()`'s signature loop, making any 3+-signature test pass
**vacuously**. The bound must be ≥ the maximum loop iterations a proof exercises (signer count, Merkle
depth); `loop = 6` covers the suite. The reachability controls are precisely the tripwire that catches a
too-small bound (a control that *passes* signals an unreachable accept path, i.e. vacuity).
`solver-timeout-assertion = 0` lets a few valid-but-nonlinear proofs (e.g. [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L18))
solve to completion rather than being cut off and misreported as counterexamples (see L11 and the CI-gate
memory).

---

## 4.3 The property catalog (26 harnesses)

Grouped by area. Each harness pairs proof checks with ≥1 reachability control. "Models" notes whether the
harness drives the real compiled `Relay` or a self-contained model (see §4.4).

### Signature / threshold accounting — the core

| Harness | Property | Notes |
|---------|----------|-------|
| [`RelaySigFV`](../../test-forge/fv/RelaySigFV.t.sol#L21) | accept ⟹ enough distinct registered weight; **no double-count** (`noDoubleCount_duplicateIndex_cannotAccept`); threshold rejection (`threshold_twoVoters_cannotAccept`) | tight per-prefix |
| [`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol#L23) | the same, **parametric** at K≤3 on real bytecode: `threshold_1/2/3sig_param`, `noDoubleCount_headDup/tailDup_param` | the **bytecode** side of the loop |
| [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L31) | the real bytecode obeys the Kontrol model's `psAt` prefix-sum invariant: `bridge_1/2/3sig` | **ties R3's model to the bytecode** at K≤3 |

These three are the bounded, real-bytecode counterpart of the unbounded soundness proven at R3 (Kontrol,
∀K) and R4 (Lean, ∀N∀K). `RelayModelBridgeFV` is the explicit bridge that justifies trusting the model.

### The `relay()` epoch-decision matrix (Relay.sol:743–754, all five gates)

| Harness | Gate |
|---------|------|
| [`RelayWrongEpochFV`](../../test-forge/fv/RelayWrongEpochFV.t.sol#L18) | wrong-epoch rejected (`wrongEpoch_rejected`; `reach_correctEpoch`) |
| [`RelayDelayedPolicyFV`](../../test-forge/fv/RelayDelayedPolicyFV.t.sol#L17) | delayed-policy gate |
| [`RelayFinalizationWindowFV`](../../test-forge/fv/RelayFinalizationWindowFV.t.sol#L19) | too-old / finalization-window gate |
| [`RelayCrossEpochFV`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L17) + [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L18) | threshold-increase (cross-epoch) gate |
| [`RelayMustUseNewPolicyFV`](../../test-forge/fv/RelayMustUseNewPolicyFV.t.sol#L24) | must-use-new-policy (`mustUseNewPolicy_afterStart`; `reach_oldPolicyOkBeforeStart`) |

`RelayThresholdScalingFV` deserves note: it proves the cross-epoch rescale `threshold := threshold *
thresholdIncreaseBIPS / 10000` **never weakens** the threshold (`neverWeakens`), is the identity at the
boundary (`identityAtBoundary`), and does not overflow (`noOverflow`). Its `neverWeakens`/`identityAtBoundary`
are nonlinear and need `solver-timeout-assertion = 0` (§4.2).

### Threshold consistency on the live paths

| Harness | Property |
|---------|----------|
| [`RelayThresholdConsistencyFV`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L21) | threshold consistency on the **setter path** (`thresholdTooBig/TooSmall_rejected`; `reach_inBand_accepted`) |
| [`RelayModeOneFV`](../../test-forge/fv/RelayModeOneFV.t.sol#L23) | threshold consistency on the **live Mode-1 relay path** (`modeOne_thresholdTooSmall_rejected`; `reach_modeOne_validInstalls`) |

### Access control, governance, lifecycle

| Harness | Property |
|---------|----------|
| [`RelayAccessControlFV`](../../test-forge/fv/RelayAccessControlFV.t.sol#L13) | only the signing-policy setter rotates the policy |
| [`RelayConstructorFV`](../../test-forge/fv/RelayConstructorFV.t.sol#L14) | constructor **fail-closes** on bad config (incl. L4/RLY-11) |
| [`RelayGovernanceNonceFV`](../../test-forge/fv/RelayGovernanceNonceFV.t.sol#L18) | governance-fee **nonce replay protection** for all nonces; fee-setup mode-gating (AC-2) |
| [`RelayEpochAdvanceFV`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L15) | strict **+1** epoch advance + monotonic `lastInitialized` state-effect |

### Merkle & randomness

| Harness | Property |
|---------|----------|
| [`RelayRandomBindingFV`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L29) | random value binding / no-forgery (`p4_storedEqualsCommitted`, `p4_uncommittedValue_cannotStore`) |
| [`RelayRandomMonotonicityFV`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L19) | random-pointer monotonicity over arbitrary sequences (`advances`, `bothHistoricalRetained`, `staleDoesNotRegress`; `reach_twoRelays`) |
| [`RelayMerkleProofFV`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L18) | proof-element + alignment soundness (`m2_wrongSibling_cannotStore`, `m3_misalignedProof_rejected`) |
| [`RelayMerkleFoldFV`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L22) | injectivity for the same sibling/path sequence (base, one-step, depth-2 checks; not arbitrary-proof membership soundness) |

### Fees

| Harness | Property |
|---------|----------|
| [`RelayFeeConservationFV`](../../test-forge/fv/RelayFeeConservationFV.t.sol#L37) | P7 — fee conservation in `verify()` as **real balance movements** (collector +fee, caller net −fee, none stuck) on the new-relay branch |
| [`RelayVerifyFeeFV`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L16) | fee conservation in `verify()` as **arithmetic**, both branches incl. `oldRelay` delegation (`fee_conserved`, `fee_noOverpayKept`, `fee_underpaymentImpossible`; `reach_exactFee`) |

### Encoding / return / secure-bit (P3/P5/P6/P8)

| Harness | Property |
|---------|----------|
| [`RelayCanonicalityFV`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L29) | P3 — encoding canonicality |
| [`RelayIsSecureNormFV`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L55) | P5 — `isSecureRandom` normalization |
| [`RelayReturnDiscriminatorFV`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L35) | P6 — return discriminator (`protocolId1_successReturns35`, `protocolId3_successReturns0/isNot35`) |
| [`RelayPolicyHashFV`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L57) | P8 — policy-hash equivalence (`policyHash_equiv_NV1/2/3`; `policyHash_mismatchReachable_NV3`) |

**Totals:** 26 harnesses, **89 checks = 60 proofs + 29 reachability controls** (cross-checked against the
CI gate output; the 26th harness, `RelayEcrecoverSymbolicFV`, is grouped in the inventory below and
described in §4.4).

### The complete check inventory (one line per check)

Every symbolic obligation in the suite, one line each — what each check **proves**, or which reachable
event it **witnesses**. ✅ = proof (must PASS); 🔍 = reachability control (must produce a counterexample —
the anti-vacuity tripwire; see §4.2 and the normative naming rules in
[`test-forge/fv/README.md`](../../test-forge/fv/README.md)). Groups mirror the catalog above, plus the
OP-1 `ecrecover` harness described in §4.4; rows follow source order within each harness. The inventory
totals **89 checks = 60 proofs + 29 reachability controls** — the 25 catalog harnesses' 85 plus
[`RelayEcrecoverSymbolicFV`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L50)'s 4.

**Signature / threshold accounting — the core**

| Harness | Check | Kind | Proves / witnesses |
|---------|-------|------|--------------------|
| [`RelaySigFV`](../../test-forge/fv/RelaySigFV.t.sol#L21) | [`check_threshold_twoVoters_cannotAccept`](../../test-forge/fv/RelaySigFV.t.sol#L50) | ✅ proof | two voters carrying 200 ≤ threshold 260 can never make `relay()` accept |
| | [`check_noDoubleCount_duplicateIndex_cannotAccept`](../../test-forge/fv/RelaySigFV.t.sol#L63) | ✅ proof | a duplicated voter index `[0,1,1]` cannot be counted twice to clear the threshold |
| | [`check_reachability_threeVoters_canAccept`](../../test-forge/fv/RelaySigFV.t.sol#L80) | 🔍 reach | witnesses: three distinct voters (300 > 260) CAN finalize — the accept path is live |
| [`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol#L23) | [`check_threshold_1sig_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L63) | ✅ proof | for **all** weights/thresholds: one signature with `w0 ≤ thr` can never accept |
| | [`check_threshold_2sig_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L72) | ✅ proof | for all weights/thresholds: two signatures with `w0+w1 ≤ thr` can never accept |
| | [`check_threshold_3sig_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L81) | ✅ proof | for all weights/thresholds: three signatures with `w0+w1+w2 ≤ thr` can never accept |
| | [`check_noDoubleCount_tailDup_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L99) | ✅ proof | a trailing duplicate index `[0,1,1]` cannot double-count a voter past the threshold |
| | [`check_noDoubleCount_headDup_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L115) | ✅ proof | a leading duplicate index `[0,0,1]` cannot double-count a voter past the threshold |
| | [`check_reachability_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L131) | 🔍 reach | witnesses: weights summing above the threshold CAN finalize (parametric accept path live) |
| [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L31) | [`check_bridge_1sig`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L73) | ✅ proof | the real bytecode accepts at K=1 only if the Kontrol model's `psAt(1)` exceeds the threshold |
| | [`check_bridge_2sig`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L81) | ✅ proof | same at K=2: bytecode accept ⟹ `psAt(2) > threshold` |
| | [`check_bridge_3sig`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L89) | ✅ proof | same at K=3: bytecode accept ⟹ `psAt(3) > threshold` |
| | [`check_reach_bridge_canAccept`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L99) | 🔍 reach | witnesses: where the model predicts acceptance, the real bytecode DOES accept |

**The `relay()` epoch-decision matrix**

| Harness | Check | Kind | Proves / witnesses |
|---------|-------|------|--------------------|
| [`RelayWrongEpochFV`](../../test-forge/fv/RelayWrongEpochFV.t.sol#L18) | [`check_wrongEpoch_rejected`](../../test-forge/fv/RelayWrongEpochFV.t.sol#L53) | ✅ proof | an epoch-1 message can never be finalized by the epoch-2 signing policy |
| | [`check_reach_correctEpoch`](../../test-forge/fv/RelayWrongEpochFV.t.sol#L58) | 🔍 reach | witnesses: a same-epoch message CAN be finalized |
| [`RelayDelayedPolicyFV`](../../test-forge/fv/RelayDelayedPolicyFV.t.sol#L17) | [`check_delayedPolicy_rejected`](../../test-forge/fv/RelayDelayedPolicyFV.t.sol#L49) | ✅ proof | a same-epoch round before the policy's validity start is always rejected as delayed |
| | [`check_reach_atStart`](../../test-forge/fv/RelayDelayedPolicyFV.t.sol#L54) | 🔍 reach | witnesses: a round at/after the policy start CAN be finalized |
| [`RelayFinalizationWindowFV`](../../test-forge/fv/RelayFinalizationWindowFV.t.sol#L19) | [`check_messageTooOld_rejected`](../../test-forge/fv/RelayFinalizationWindowFV.t.sol#L72) | ✅ proof | a message older than the finalization window (here 5 epochs behind `lastInitialized`) is rejected |
| | [`check_reach_recentNotTooOld`](../../test-forge/fv/RelayFinalizationWindowFV.t.sol#L78) | 🔍 reach | witnesses: a recent message CAN still be finalized in the same state |
| [`RelayCrossEpochFV`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L17) | [`check_crossEpoch_noDoubleCount`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L55) | ✅ proof | cross-epoch: a duplicate index cannot double-count past the **increased** threshold |
| | [`check_crossEpoch_threshold`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L67) | ✅ proof | cross-epoch: total weight ≤ the ×1.2-increased threshold can never accept |
| | [`check_crossEpoch_reachability`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L77) | 🔍 reach | witnesses: weight above the increased threshold CAN finalize cross-epoch |
| [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L18) | [`check_scaling_neverWeakens`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L35) | ✅ proof | the cross-epoch rescale never lowers the threshold (proved in its division-free equivalent form) |
| | [`check_scaling_identityAtBoundary`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L44) | ✅ proof | at `tib = 10000` (×1.0) the actual division is the exact identity — no truncation loss |
| | [`check_scaling_noOverflow`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L50) | ✅ proof | the rescale never overflows: the truncated result never exceeds the 16-bit product |
| | [`check_reach_scaling_canIncrease`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L57) | 🔍 reach | witnesses: with `tib > 10000` the rescale CAN strictly raise the threshold |
| [`RelayMustUseNewPolicyFV`](../../test-forge/fv/RelayMustUseNewPolicyFV.t.sol#L24) | [`check_mustUseNewPolicy_afterStart`](../../test-forge/fv/RelayMustUseNewPolicyFV.t.sol#L68) | ✅ proof | once epoch 2 is initialized, the epoch-1 policy cannot finalize rounds at/after its start |
| | [`check_reach_oldPolicyOkBeforeStart`](../../test-forge/fv/RelayMustUseNewPolicyFV.t.sol#L74) | 🔍 reach | witnesses: before the new epoch's (delayed) start, the old policy CAN still finalize |

**Threshold consistency on the live paths**

| Harness | Check | Kind | Proves / witnesses |
|---------|-------|------|--------------------|
| [`RelayThresholdConsistencyFV`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L21) | [`check_thresholdTooSmall_rejected`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L50) | ✅ proof | `setSigningPolicy` rejects any threshold below 50% of total voter weight |
| | [`check_thresholdTooBig_rejected`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L58) | ✅ proof | `setSigningPolicy` rejects any threshold above 66% of total voter weight |
| | [`check_reach_inBand_accepted`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L65) | 🔍 reach | witnesses: an in-band threshold IS accepted — the validation is not always-revert |
| [`RelayModeOneFV`](../../test-forge/fv/RelayModeOneFV.t.sol#L23) | [`check_modeOne_thresholdTooSmall_rejected`](../../test-forge/fv/RelayModeOneFV.t.sol#L72) | ✅ proof | a Mode-1-relayed new policy with a below-MIN-band threshold can never be installed |
| | [`check_reach_modeOne_validInstalls`](../../test-forge/fv/RelayModeOneFV.t.sol#L81) | 🔍 reach | witnesses: an in-band Mode-1 new policy CAN be installed by the old quorum |

**Access control, governance, lifecycle**

| Harness | Check | Kind | Proves / witnesses |
|---------|-------|------|--------------------|
| [`RelayAccessControlFV`](../../test-forge/fv/RelayAccessControlFV.t.sol#L13) | [`check_setSigningPolicy_onlySetter`](../../test-forge/fv/RelayAccessControlFV.t.sol#L29) | ✅ proof | for ANY setter address other than the caller, `setSigningPolicy` always reverts |
| | [`check_reach_setter_canCall`](../../test-forge/fv/RelayAccessControlFV.t.sol#L39) | 🔍 reach | witnesses: the registered setter CAN rotate the policy |
| [`RelayConstructorFV`](../../test-forge/fv/RelayConstructorFV.t.sol#L14) | [`check_ctor_rejectsLowThresholdIncrease`](../../test-forge/fv/RelayConstructorFV.t.sol#L26) | ✅ proof | the constructor rejects any `thresholdIncreaseBIPS` below 10000 (×1.0) |
| | [`check_ctor_rejectsZeroRewardEpochDuration`](../../test-forge/fv/RelayConstructorFV.t.sol#L35) | ✅ proof | the constructor rejects a zero reward-epoch duration (RLY-11, div-by-zero) |
| | [`check_ctor_rejectsZeroVotingEpochDuration`](../../test-forge/fv/RelayConstructorFV.t.sol#L43) | ✅ proof | the constructor rejects a zero voting-epoch duration (RLY-11) |
| | [`check_ctor_rejectsZeroPolicyHash`](../../test-forge/fv/RelayConstructorFV.t.sol#L51) | ✅ proof | the constructor rejects a zero initial signing-policy hash (L-4, would brick the epoch) |
| | [`check_reach_ctor_validDeploys`](../../test-forge/fv/RelayConstructorFV.t.sol#L58) | 🔍 reach | witnesses: the valid base config DOES deploy |
| [`RelayGovernanceNonceFV`](../../test-forge/fv/RelayGovernanceNonceFV.t.sol#L18) | [`check_nonce_mustStrictlyIncrease`](../../test-forge/fv/RelayGovernanceNonceFV.t.sol#L51) | ✅ proof | after nonce `n1` is accepted, any `n2 ≤ n1` is rejected — no replay, for all nonces |
| | [`check_reach_nonce_increasing`](../../test-forge/fv/RelayGovernanceNonceFV.t.sol#L63) | 🔍 reach | witnesses: two strictly-increasing nonces are BOTH accepted in sequence |
| | [`check_feeSetup_rejectedInSetterMode`](../../test-forge/fv/RelayGovernanceNonceFV.t.sol#L76) | ✅ proof | `governanceFeeSetup` always reverts in setter mode, for any non-zero setter (AC-2) |
| [`RelayEpochAdvanceFV`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L15) | [`check_epochAdvance_requiresSequential`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L36) | ✅ proof | any epoch other than `lastInitialized+1` is rejected — no skip, replay, or regress |
| | [`check_reach_epochAdvance_correctSucceeds`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L46) | 🔍 reach | witnesses: the exact next epoch IS accepted |
| | [`check_epochAdvance_incrementsByOne`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L59) | ✅ proof | a successful `setSigningPolicy` advances `lastInitialized` by exactly +1 (the monotone step) |

**Merkle & randomness**

| Harness | Check | Kind | Proves / witnesses |
|---------|-------|------|--------------------|
| [`RelayRandomBindingFV`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L29) | [`check_p4_uncommittedValue_cannotStore`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L79) | ✅ proof | a trailer random value differing from the root-committed one can never finalize |
| | [`check_p4_storedEqualsCommitted`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L89) | ✅ proof | on every accepting run the stored random (live + historical) equals the committed value |
| | [`check_p4_reachability`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L102) | 🔍 reach | witnesses: the committed value CAN finalize and be stored |
| [`RelayRandomMonotonicityFV`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L19) | [`check_staleDoesNotRegress`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L69) | ✅ proof | relaying an older round after a newer one never regresses the live random pointer |
| | [`check_advances`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L79) | ✅ proof | relaying a newer round after an older one advances the live pointer to it |
| | [`check_bothHistoricalRetained`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L89) | ✅ proof | after both relays, both rounds' random values remain retrievable historically |
| | [`check_reachability_twoRelays`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L100) | 🔍 reach | witnesses: two successful random relays in sequence ARE reachable |
| [`RelayMerkleProofFV`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L18) | [`check_m2_wrongSibling_cannotStore`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L63) | ✅ proof | a proof sibling differing from the committed one can never reproduce the signed root |
| | [`check_m3_misalignedProof_rejected`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L72) | ✅ proof | a misaligned trailer (not a whole number of 32-byte words) is always rejected |
| | [`check_reach_matchingProof`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L79) | 🔍 reach | witnesses: the matching, aligned proof CAN finalize |
| [`RelayMerkleFoldFV`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L22) | [`check_fold_base_injective`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L32) | ✅ proof | induction base: the empty-proof fold is the identity, so distinct leaves stay distinct |
| | [`check_fold_step_injective`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L41) | ✅ proof | induction step: one sorted-pair fold with the same sibling never merges distinct hashes |
| | [`check_fold_depth2_injective`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L48) | ✅ proof | corroboration: an equal depth-2 root with the same proof forces equal leaves (no forgery) |
| | [`check_reach_fold_distinguishes`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L57) | 🔍 reach | witnesses: distinct inputs DO produce distinct folds |

**Fees**

| Harness | Check | Kind | Proves / witnesses |
|---------|-------|------|--------------------|
| [`RelayFeeConservationFV`](../../test-forge/fv/RelayFeeConservationFV.t.sol#L37) | [`check_p7_feeConservation`](../../test-forge/fv/RelayFeeConservationFV.t.sol#L109) | ✅ proof | a succeeding `verify()` (real balances) moves exactly the fee: collector +fee, caller −fee, relay 0 |
| | [`check_p7_reachability`](../../test-forge/fv/RelayFeeConservationFV.t.sol#L128) | 🔍 reach | witnesses: a successful `verify()` exists at this config — the fee path is live |
| [`RelayVerifyFeeFV`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L16) | [`check_fee_conserved`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L28) | ✅ proof | forwarded + refund always equals `msg.value` — no ETH created or destroyed |
| | [`check_fee_noOverpayKept`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L36) | ✅ proof | exactly the fee is forwarded and the refund never exceeds `msg.value` |
| | [`check_fee_underpaymentImpossible`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L45) | ✅ proof | under-payment (`msg.value < fee`) can never satisfy the `require` guard |
| | [`check_reach_exactFee`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L53) | 🔍 reach | witnesses: paying exactly the fee yields a zero refund (a conserving split is reachable) |

**Encoding / return / secure-bit (P3/P5/P6/P8)**

| Harness | Check | Kind | Proves / witnesses |
|---------|-------|------|--------------------|
| [`RelayCanonicalityFV`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L29) | [`check_p3_badV_cannotAccept`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L74) | ✅ proof | a signature with `v ∉ {27,28}` can never accept, even at winning weight |
| | [`check_p3_highS_cannotAccept`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L85) | ✅ proof | a high-`s` (above secp256k1n/2) signature can never accept, even at winning weight |
| | [`check_p3_reachability_canonicalAccepts`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L99) | 🔍 reach | witnesses: a canonical winning-weight signature CAN accept |
| [`RelayIsSecureNormFV`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L55) | [`check_historicalSecure_eq_byteNonZero`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L135) | ✅ proof | accept ⟹ the stored historical isSecure bit equals `(raw byte != 0)` |
| | [`check_liveSecure_eq_byteNonZero`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L148) | ✅ proof | accept ⟹ the live `isSecureRandom` flag equals `(raw byte != 0)` |
| | [`check_liveAndHistorical_agree`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L160) | ✅ proof | on every accepting run the live flag and the historical bit agree |
| | [`check_leafNorm_machineChecked`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L178) | ✅ proof | the Merkle-leaf isSecure rule is exactly `(byte != 0)`, for all 256 byte values |
| | [`check_reach_insecure_canAccept`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L194) | 🔍 reach | witnesses: the insecure normalization (byte 0) CAN finalize |
| | [`check_reach_secure_canAccept`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L200) | 🔍 reach | witnesses: the secure normalization (byte 1) CAN finalize |
| | [`check_reach_highByte_canAccept`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L208) | 🔍 reach | witnesses: a high byte (> 1) CAN finalize, pinning the leaf rule over 2..255 |
| [`RelayReturnDiscriminatorFV`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L35) | [`check_protocolId1_successReturns35`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L76) | ✅ proof | a successful protocolId-1 (custom-signature) relay returns exactly 35 bytes |
| | [`check_reach_protocolId1_canAccept`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L84) | 🔍 reach | witnesses: the protocolId-1 accept path is reachable |
| | [`check_protocolId3_successReturns0`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L94) | ✅ proof | a successful protocolId-3 (Mode-2) relay returns exactly 0 bytes |
| | [`check_protocolId3_isNot35`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L104) | ✅ proof | a Mode-2 success can never return 35 bytes — the discriminator cannot be spoofed |
| | [`check_reach_protocolId3_canAccept`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L112) | 🔍 reach | witnesses: the protocolId-3 accept path is reachable |
| [`RelayPolicyHashFV`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L57) | [`check_policyHash_equiv_NV1`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L116) | ✅ proof | the assembly policy hash equals the reference fold for **all** symbolic 1-voter policies |
| | [`check_policyHash_equiv_NV2`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L125) | ✅ proof | the same equivalence over all symbolic 2-voter policies |
| | [`check_policyHash_equiv_NV3`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L136) | ✅ proof | the same at 3 voters — multiple full chunks plus a 13-byte remainder fold |
| | [`check_policyHash_mismatchReachable_NV3`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L154) | 🔍 reach | witnesses: a bit-flipped stored hash DOES fire the mismatch revert — the detector is live |

**The `ecrecover` ABI (OP-1 — the §4.4 harness, not in the catalog above)**

| Harness | Check | Kind | Proves / witnesses |
|---------|-------|------|--------------------|
| [`RelayEcrecoverSymbolicFV`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L50) | [`check_emptyReturn_rejected`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L79) | ✅ proof | an empty precompile return (bad signature) is never accepted, whatever the stale buffer holds |
| | [`check_zeroSigner_rejected`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L86) | ✅ proof | a well-formed 32-byte zero signer is always rejected |
| | [`check_accepted_usesFreshReturn_notStale`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L94) | ✅ proof | an accepting guard uses the fresh return, never the stale buffer; accepts iff the signer ≠ 0 |
| | [`check_reach_validSigner_accepted`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L104) | 🔍 reach | witnesses: a genuine non-zero signer IS accepted — the accept path is live |

---

## 4.4 Modeling approach & assumptions

- **Real bytecode vs. self-contained model.** Most harnesses drive the **real compiled `Relay`** through
  symbolic calldata (the high-value ones: [`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol#L23), [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L31), [`RelayModeOneFV`](../../test-forge/fv/RelayModeOneFV.t.sol#L23), the
  gate harnesses). A few isolate a piece of pure arithmetic/logic into a self-contained model where that is
  the faithful unit of the property (e.g. [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L18) replicates the exact rescale formula
  and EVM truncating division; [`RelayMerkleFoldFV`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L22) reasons about the fold structure). Each harness header
  states which it is.
- **The modeling contract (standing assumptions).** `keccak256` is an injective uninterpreted function;
  `ecrecover` is uninterpreted (ECDSA unforgeability assumed) — we verify accounting, not cryptography. The
  signing-policy setter is trusted to supply distinct, non-zero, canonically-ordered voters with normalized
  weights (RLY-06). OZ `MerkleProof.verifyCalldata` internals are assumed correct (call-site in scope).
  `oldRelay` is a trusted prior deployment. These are enumerated in [L10](10-claims-ledger-trust-and-residual.md).
- **Precompile modeling — the `ecrecover` ABI, and how OP-1 is internalized.** Halmos's *built-in* `0x01` is
  a *total* function returning a well-formed 32-byte address (`returndatasize()==32` always), so the
  whole-`relay()` symbolic runs use the adversary-conservative uninterpreted recovery and do not, by
  themselves, exercise the real failure ABI — on a bad signature the precompile returns *success with empty
  return data* and leaves the output buffer **unmodified**. The contract's `staticcall`-success,
  `returndatasize()==32`, and zero-signer checks are what make reality conform to that model
  (assumption/obligation **OP-1** in [L10](10-claims-ledger-trust-and-residual.md)). OP-1 is discharged two
  ways: a real-EVM regression ([`test-forge/fv/RelayEcrecoverABI.t.sol`](../../test-forge/fv/RelayEcrecoverABI.t.sol)) that pins the actual precompile's
  empty-return/stale-buffer ABI, **and** a symbolic harness ([`test-forge/fv/RelayEcrecoverSymbolicFV.t.sol`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol))
  that reaches the empty-return branch via a mock reproducing that ABI and proves — over ALL stale-buffer
  contents — the guard rejects it (plus Foundry/Hardhat failure-path tests and assembly review). The guard is
  load-bearing and must never be removed.
- **Bound rationale.** K≤3, N≤5 are chosen to exercise every branch and the double-count/threshold
  boundaries while staying solver-tractable; the unbounded dimensions are escalated to R3/R4.

---

## 4.5 Reproduce

Full toolchain in [L11](11-reproducibility.md). The suite is the CI gate `test-fv-halmos`:

```bash
# from repo root (halmos.toml supplies loop=6 + solver-timeout-assertion=0 + forge-build-out):
forge build
HALMOS=halmos python3 test-forge/fv/verify_fv.py        # the exact CI gate
# a single harness:
halmos --contract RelaySigParamFV
# demonstrate the tripwire firing on a too-small bound (expect FAIL / vacuity alarms):
python3 test-forge/fv/verify_fv.py --loop 2
```

Expected: the gate prints the per-check table and `[fv] OK — all proofs hold and every reachability
control is live`.

---

## 4.6 What R2 establishes and does not

- **Establishes:** the security-critical surface — sig/threshold accounting, the full epoch matrix, access
  control, lifecycle, Merkle, randomness, fees — holds for **all inputs up to K≤3, N≤5**, on the **real
  deployed bytecode**, with every proof certified non-vacuous.
- **Does not:** reach arbitrary K or N. The signature loop beyond K=3 and voter sets beyond N=5 are the
  induction barrier, handled at R3 (Kontrol, ∀K) and R4 (Lean, ∀N∀K), with [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L31) connecting
  R3's model back to this bytecode.

**Next:** [L5 — R3: unbounded attempts](05-R3-unbounded-attempts.md) — crossing the induction barrier with
Kontrol, and the honest assembly wall that Kontrol's symbolic-N and Certora both hit.
