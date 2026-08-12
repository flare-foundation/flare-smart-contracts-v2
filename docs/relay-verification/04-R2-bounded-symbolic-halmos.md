# L4 — R2: bounded symbolic execution (Halmos)

> **Evidence note.** This chapter describes the current manifest inventory,
> while the actual run verdict is recorded only in
> [`CURRENT-STATUS.md`](CURRENT-STATUS.md). Safe/GSS text is historical and
> confers no result on the owner/timelock/UUPS architecture.

> **What you get from this level.** The workhorse rung: a manifest of 27 harness
> contracts / 123 checks that **symbolically execute real Relay/proxy
> bytecode** and prove properties over _all_ inputs up to a fixed size. The
> suite design (including the anti-vacuity tripwire and the loop-bound subtlety that makes the whole thing
> trustworthy), the full property catalog, the modeling assumptions, and how to reproduce.

---

## 4.1 What Halmos is, and why it is the bounded floor _on the real bytecode_

Halmos runs the compiled contract with **[symbolic](CONCEPTS.md#9-symbolic-execution)** inputs: instead of one concrete calldata, it explores
_all_ calldata at once via an [SMT solver](CONCEPTS.md#1-what-is-an-smt-solver), reporting any input that violates an `assert`. Crucially it
**executes the actual bytecode** — it does not reconstruct a model from Solidity structure — so it is
**immune to the assembly barrier** (Enemy 2): Relay's hand-rolled storage is just bytecode being run.

**Which bytecode, precisely** ([which bytecode, exactly?](CONCEPTS.md#3-verified-on-the-real-bytecode--which-bytecode-exactly))**.** The current toolchain compiles with **solc
0.8.35+commit.47b9dedd, optimizer 200, `evm_version=cancun`** (settings pinned in
[`foundry.toml`](../../foundry.toml) and the machine-readable manifest). Current
harnesses normally deploy `RelayProxy`, initialize Relay through the proxy, and
call the resulting runtime; the owner/timelock/UUPS harnesses also exercise the
implementation lock and queued proxy upgrades. The initializer-guard harness is
the deliberate exception: it inherits the real Relay implementation and clears
only OpenZeppelin's verification-instance initialization lock, avoiding a
Halmos-unsupported dynamic deployment rewrite. Concrete proxy-constructor tests
and the proxy-aware owner-upgrade harness cover atomic deployment and one-shot
proxy initialization separately. Artifact parity binds this FV build to the
deployment build. Note the
trust profile: at this rung **solc is inside the verified object** (we check its _output_; a miscompilation
of a checked property within bound would surface as a counterexample) — the inverse of R4b, which models
the Yul IR and _trusts_ solc's Yul→bytecode backend (L7 §7.4; [verified compilation](CONCEPTS.md#19-verified-compilation)).

Its limit is the **induction barrier** (Enemy 1): loops are unrolled to a fixed depth, so coverage is
bounded — here **K ≤ 3 signatures** and **N ≤ 5 voters**. Within that bound the guarantee is exhaustive
(all inputs, not samples). This is why R2 is the bounded floor: maximal object-fidelity (real bytecode),
exhaustive-but-bounded coverage. The unbounded extension is R3/R4.

---

## 4.2 Suite design — the gate, the tripwire, the loop bound

The suite is not just a pile of `assert`s; it is engineered so that a _vacuous_ pass cannot masquerade as a
proof. Three design elements:

**(a) The gate — [`test-forge/fv/verify_fv.py`](../../test-forge/fv/verify_fv.py).** Halmos's raw exit code is not a usable CI signal (the
anti-vacuity controls fail by design). The gate runs one Halmos invocation over all `check_*` functions in
`test-forge/fv/**` (for a how-to-read-the-suite primer, see [`test-forge/fv/README.md`](../../test-forge/fv/README.md)), reads the JSON, and judges each check against the exact committed manifest:

- a declared **proof** must return Halmos `PASS`;
- a declared **reachability** control must return `COUNTEREXAMPLE` with a validated model;
- the observed and declared check sets must be identical, with zero bounded loops.

The gate also checks the pinned Foundry/Halmos/Z3 versions and first forces a
Forge rebuild with AST and storage-layout output. This closes an incremental-build
hazard in Halmos 0.3.3: its own `forge build --ast` does not use `--force`, so a
fresh AST-less artifact from an earlier ordinary Forge command could otherwise be
silently skipped. It prints a per-check table and the summary line, and exits
non-zero on any violation. A successful run of the current manifest must print:

```
[fv] 123/123 checks observed: 86/86 proofs hold, 37/37 reachability controls have validated counterexamples. 0 violation(s).
[fv] OK - exact proof inventory holds and every reachability control has a valid witness.
```

**(b) The anti-vacuity tripwire.** Every property harness pairs each positive proof with a **reachability
control** that asserts the _negation_ of "the interesting thing can happen" and must therefore be refuted
by a [counterexample](CONCEPTS.md#7-what-is-a-cex-counterexamples-and-why-half-the-suite-celebrates-them). If a control ever _passes_, the interesting path is unreachable — the proofs guarding
it have gone **vacuous** — and the gate raises a "VACUITY ALARM" (a hard failure). This is what makes a
green suite meaningful: it certifies the proofs are not trivially true.

**(c) The loop bound — [`halmos.toml`](../../halmos.toml).** The single most important config:

```toml
[global]
forge-build-out = "artifacts-forge"
solver = "z3"                 # explicit; Halmos 0.3.3 otherwise defaults to Yices
loop = 6                       # NOT the default 2
solver-timeout-assertion = 0   # let valid nonlinear proofs finish
```

The default `loop = 2` _silently truncates_ `relay()`'s signature loop, making any 3+-signature test pass
**vacuously**. The bound must be ≥ the maximum loop iterations a proof exercises (signer count, Merkle
depth); `loop = 6` covers the suite. The reachability controls are precisely the tripwire that catches a
too-small bound (a control that _passes_ signals an unreachable accept path, i.e. vacuity).
`solver-timeout-assertion = 0` lets a few valid-but-nonlinear proofs (e.g. [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L20))
solve to completion rather than being cut off and misreported as counterexamples (see L11 and the CI-gate
memory).

---

## 4.3 The property catalog (27 harness contracts)

Grouped by area. Each harness pairs proof checks with ≥1 reachability control. "Models" notes whether the
harness drives the real compiled `Relay` or a self-contained model (see §4.4).

### Signature / threshold accounting — the core

| Harness                                                                  | Property                                                                                                                                                                          | Notes                                                                                                                             |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [`RelaySigFV`](../../test-forge/fv/RelaySigFV.t.sol#L27)                 | accept ⟹ enough registered policy-slot weight; **no repeated slot index** (`noDoubleCount_duplicateIndex_cannotAccept`); threshold rejection (`threshold_twoVoters_cannotAccept`) | tight per-prefix; unique voter addresses are a separate admission premise                                                         |
| [`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol#L29)       | the same, **parametric** at K≤3 on real bytecode: `threshold_1/2/3sig_param`, `noDoubleCount_headDup/tailDup_param`                                                               | the **bytecode** side of the loop                                                                                                 |
| [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L37) | the real bytecode obeys the Kontrol model's [`psAt`](CONCEPTS.md#6-what-is-psat-the-prefix-sum-at-the-heart-of-the-proofs) prefix-sum invariant: `bridge_1/2/3sig`                | **ties R3's model to the bytecode** ([the bridge](CONCEPTS.md#2-why-two-symbolic-tools-the-bounded-model-fidelity-bridge)) at K≤3 |

These three are the bounded, real-bytecode counterpart of the historical R3
Kontrol model (∀K) and the current R4 Lean statements (∀N∀K).
`RelayModelBridgeFV` is the bounded bridge obligation; its current verdict is
not implied by the manifest entry.

These threshold claims are conditional on distinct voter **addresses** in the
policy. Increasing signature indices prevents reuse of one policy slot, but the
contract does not currently reject the same address in two different slots; see
[`CURRENT-STATUS.md`](CURRENT-STATUS.md#security-boundary-the-proofs-do-not-remove).

### The `relay()` epoch-decision matrix (Relay.sol:743–754, all five gates)

| Harness                                                                                                                                                     | Gate                                                                                |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [`RelayWrongEpochFV`](../../test-forge/fv/RelayWrongEpochFV.t.sol#L24)                                                                                      | wrong-epoch rejected (`wrongEpoch_rejected`; `reach_correctEpoch`)                  |
| [`RelayDelayedPolicyFV`](../../test-forge/fv/RelayDelayedPolicyFV.t.sol#L23)                                                                                | delayed-policy gate                                                                 |
| [`RelayFinalizationWindowFV`](../../test-forge/fv/RelayFinalizationWindowFV.t.sol#L25)                                                                      | too-old / finalization-window gate                                                  |
| [`RelayCrossEpochFV`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L23) + [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L20) | threshold-increase (cross-epoch) gate                                               |
| [`RelayMustUseNewPolicyFV`](../../test-forge/fv/RelayMustUseNewPolicyFV.t.sol#L30)                                                                          | must-use-new-policy (`mustUseNewPolicy_afterStart`; `reach_oldPolicyOkBeforeStart`) |

`RelayThresholdScalingFV` deserves note: it proves the cross-epoch rescale `threshold := threshold *
thresholdIncreaseBIPS / 10000` **never weakens** the threshold (`neverWeakens`), is the identity at the
boundary (`identityAtBoundary`), and does not overflow (`noOverflow`). Its `neverWeakens`/`identityAtBoundary`
are nonlinear and need `solver-timeout-assertion = 0` (§4.2).

### Threshold consistency on the live paths

| Harness                                                                                    | Property                                                                                                                      |
| ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| [`RelayThresholdConsistencyFV`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L27) | threshold consistency on the **setter path** (`thresholdTooBig/TooSmall_rejected`; `reach_inBand_accepted`)                   |
| [`RelayModeOneFV`](../../test-forge/fv/RelayModeOneFV.t.sol#L29)                           | threshold consistency on the **live Mode-1 relay path** (`modeOne_thresholdTooSmall_rejected`; `reach_modeOne_validInstalls`) |

### Access control and lifecycle

| Harness                                                                      | Property                                                                                                                                                                 |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`RelayAccessControlFV`](../../test-forge/fv/RelayAccessControlFV.t.sol#L19) | only the signing-policy setter rotates the policy                                                                                                                        |
| [`RelayConstructorFV`](../../test-forge/fv/RelayConstructorFV.t.sol#L23)     | the real Relay initializer **fail-closes** on bad config in a CREATE-free verification instance (historical contract name; incl. L4/RLY-11 and source-domain home-force) |
| [`RelayEpochAdvanceFV`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L21)   | strict **+1** epoch advance + monotonic `lastInitialized` state-effect                                                                                                   |

The removed `RelayGovernanceNonceFV` and `SafeGovernanceFV` harnesses proved
deleted governance paths. No result is inherited from them.

### Owner, timelock, modes, and UUPS

| Harness contract                                                              | Property group                                                                                                                                                                      |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`RelayOwnerTimelockFV`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L118) | owner-only queue/cancel, exact-calldata identity, recorded ETA, permissionless one-shot execution, and rollback on failed execution                                                 |
| [`RelayOwnerModesFV`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L270)    | relay-mode fee setters, immutable mode split, setter rotation, and rejection of the wrong mode's guarded surface                                                                    |
| [`RelayOwnerUpgradeFV`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L401)  | implementation lock and one-shot proxy initialization, exact queued UUPS upgrade, selected storage preservation, nested-guard atomicity, and ERC-7201/ERC-1967 namespace separation |

These three contracts contribute 16 checks (13 proofs and 3 reachability
controls). They do not prove the behavior of arbitrary future implementation
bytecode.

### Merkle & randomness

| Harness                                                                                | Property                                                                                                                              |
| -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| [`RelayRandomBindingFV`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L35)           | random value binding / no-forgery (`p4_storedEqualsCommitted`, `p4_uncommittedValue_cannotStore`)                                     |
| [`RelayRandomMonotonicityFV`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L25) | random-pointer monotonicity over arbitrary sequences (`advances`, `bothHistoricalRetained`, `staleDoesNotRegress`; `reach_twoRelays`) |
| [`RelayMerkleProofFV`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L24)               | proof-element + alignment soundness (`m2_wrongSibling_cannotStore`, `m3_misalignedProof_rejected`)                                    |
| [`RelayMerkleFoldFV`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L24)                 | injectivity for the same sibling/path sequence (base, one-step, depth-2 checks; not arbitrary-proof membership soundness)             |

### Fees

| Harness                                                                          | Property                                                                                                                                                                           |
| -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`RelayFeeConservationFV`](../../test-forge/fv/RelayFeeConservationFV.t.sol#L43) | P7 — fee conservation in `verify()` as **real balance movements** (collector +fee, caller net −fee, none stuck) on the new-relay branch                                            |
| [`RelayVerifyFeeFV`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L18)             | fee conservation in `verify()` as **arithmetic**, both branches incl. `oldRelay` delegation (`fee_conserved`, `fee_noOverpayKept`, `fee_underpaymentImpossible`; `reach_exactFee`) |

### Encoding / return / secure-bit (P3/P5/P6/P8)

| Harness                                                                                  | Property                                                                                          |
| ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [`RelayCanonicalityFV`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L35)               | P3 — encoding canonicality                                                                        |
| [`RelayIsSecureNormFV`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L61)               | P5 — `isSecureRandom` normalization                                                               |
| [`RelayReturnDiscriminatorFV`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L41) | P6 — return discriminator (`protocolId1_successReturns35`, `protocolId3_successReturns0/isNot35`) |
| [`RelayPolicyHashFV`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L63)                   | P8 — policy-hash equivalence (`policyHash_equiv_NV1/2/3`; `policyHash_mismatchReachable_NV3`)     |

**Current manifest totals:** 27 harness contracts, **123 checks = 86 proofs +
37 reachability controls**. The current local normalized run passes all 123
with zero violations; it is development-only because its generation tree was
dirty.
`RelayEcrecoverSymbolicFV` is grouped in the inventory below and described in
section 4.4.

### The complete check inventory (one line per check)

Every symbolic obligation in the suite, one line each — what each check is
intended to **prove**, or which reachable event it is intended to **witness**.
✅ = declared proof (must PASS); 🔍 = declared reachability control (must produce a counterexample —
the anti-vacuity tripwire; see §4.2 and the normative naming rules in
[`test-forge/fv/README.md`](../../test-forge/fv/README.md)). Groups mirror the catalog above, plus the
OP-1 `ecrecover` harness described in section 4.4; rows follow source order
within each harness. The inventory totals **123 checks = 86 proofs + 37
reachability controls**.

**Setter-mode constructor exactness added in the rebaseline**

| Harness                                                                  | Check                                                                                                   | Kind     | Proves / witnesses                                            |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------- |
| [`RelayConstructorFV`](../../test-forge/fv/RelayConstructorFV.t.sol#L23) | [`check_ctor_setterMode_rejectsFeeCollectorExactly`](../../test-forge/fv/RelayConstructorFV.t.sol#L131) | ✅ proof | setter mode rejects a nonzero fee collector at initialization |
|                                                                          | [`check_ctor_setterMode_rejectsFeeConfigExactly`](../../test-forge/fv/RelayConstructorFV.t.sol#L143)    | ✅ proof | setter mode rejects nonempty protocol fee configuration       |
|                                                                          | [`check_ctor_setterMode_rejectsFeeExemptionExactly`](../../test-forge/fv/RelayConstructorFV.t.sol#L155) | ✅ proof | setter mode rejects nonempty fee exemptions                   |

**Protocol-1 BIPS override and transient storage added in the rebaseline**

| Harness                                                                              | Check                                                                                                                   | Kind     | Proves / witnesses                                                             |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------ |
| [`RelayThresholdOverrideFV`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L47) | [`check_override_twoSignerAcceptanceImpliesExactBips`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L159)         | ✅ proof | bounded acceptance implies the exact floor-plus-strict cross-product predicate |
|                                                                                      | [`check_override_exact4000Boundary_rejects`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L169)                   | ✅ proof | equality at 4000 BIPS rejects under the strict comparison                      |
|                                                                                      | [`check_reach_override_3999_twoSignersCanAccept`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L176)              | 🔍 reach | witnesses the 3999-BIPS fractional boundary accepting two of five equal voters |
|                                                                                      | [`check_override_9999_rejectsFourOfFive`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L183)                      | ✅ proof | 9999 BIPS rejects a four-of-five prefix                                        |
|                                                                                      | [`check_reach_override_9999_allWeightCanAccept`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L192)               | 🔍 reach | witnesses full weight accepting at 9999 BIPS                                   |
|                                                                                      | [`check_successfulOverride_clearsTransient`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L269)                   | ✅ proof | a successful wrapper call clears the override slot                             |
|                                                                                      | [`check_reach_manualOverride_lowersProtocolIdOne`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L297)             | 🔍 reach | witnesses a nonzero override affecting protocol ID 1                           |
|                                                                                      | [`check_overrideAtOrAbove100Percent_rejectedExactly`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L225)          | ✅ proof | the public wrapper rejects every override at or above 10000 BIPS               |
|                                                                                      | [`check_protocolIdZero_ignoresOverride`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L234)                       | ✅ proof | protocol ID 0 retains the policy threshold                                     |
|                                                                                      | [`check_reach_protocolIdZero_policyQuorumCanAccept`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L241)           | 🔍 reach | witnesses the ordinary protocol-ID-0 quorum path remains live                  |
|                                                                                      | [`check_protocolIdGreaterThanOne_ignoresOverride`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L252)             | ✅ proof | protocol IDs above 1 retain the policy threshold                               |
|                                                                                      | [`check_reach_protocolIdGreaterThanOne_policyQuorumCanAccept`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L259) | 🔍 reach | witnesses a non-protocol-1 quorum path remains live                            |
|                                                                                      | [`check_zeroOverride_matchesLegacy`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L205)                           | ✅ proof | zero override matches the legacy policy-threshold result                       |
|                                                                                      | [`check_caughtRevert_rollsBackTransient`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L278)                      | ✅ proof | catching an inner revert observes the transient write rolled back              |
|                                                                                      | [`check_caughtRevert_preservesLegacyThreshold`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L287)                | ✅ proof | a caught failure cannot poison the next legacy verification                    |
|                                                                                      | [`check_reach_zeroOverride_policyQuorumCanAccept`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L218)             | 🔍 reach | witnesses the zero-override fallback path remains live                         |
|                                                                                      | [`check_transientStorage_isAddressScoped`](../../test-forge/fv/RelayThresholdOverrideFV.t.sol#L306)                     | ✅ proof | the transient slot is scoped to the contract address                           |

**Signature / threshold accounting — the core**

| Harness                                                                  | Check                                                                                         | Kind     | Proves / witnesses                                                                                    |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------- |
| [`RelaySigFV`](../../test-forge/fv/RelaySigFV.t.sol#L27)                 | [`check_threshold_twoVoters_cannotAccept`](../../test-forge/fv/RelaySigFV.t.sol#L56)          | ✅ proof | two voters carrying 200 ≤ threshold 260 can never make `relay()` accept                               |
|                                                                          | [`check_noDoubleCount_duplicateIndex_cannotAccept`](../../test-forge/fv/RelaySigFV.t.sol#L69) | ✅ proof | a duplicated policy-slot index `[0,1,1]` cannot be counted twice to clear the threshold               |
|                                                                          | [`check_reachability_threeVoters_canAccept`](../../test-forge/fv/RelaySigFV.t.sol#L86)        | 🔍 reach | witnesses: three slots carrying 300 > 260 CAN finalize; distinct addresses are assumed by the fixture |
| [`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol#L29)       | [`check_threshold_1sig_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L69)                 | ✅ proof | for **all** weights/thresholds: one signature with `w0 ≤ thr` can never accept                        |
|                                                                          | [`check_threshold_2sig_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L78)                 | ✅ proof | for all weights/thresholds: two signatures with `w0+w1 ≤ thr` can never accept                        |
|                                                                          | [`check_threshold_3sig_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L87)                 | ✅ proof | for all weights/thresholds: three signatures with `w0+w1+w2 ≤ thr` can never accept                   |
|                                                                          | [`check_noDoubleCount_tailDup_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L107)         | ✅ proof | a trailing duplicate index `[0,1,1]` cannot double-count one policy slot past the threshold           |
|                                                                          | [`check_noDoubleCount_headDup_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L126)         | ✅ proof | a leading duplicate index `[0,0,1]` cannot double-count one policy slot past the threshold            |
|                                                                          | [`check_reachability_param`](../../test-forge/fv/RelaySigParamFV.t.sol#L142)                  | 🔍 reach | witnesses: weights summing above the threshold CAN finalize (parametric accept path live)             |
| [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L37) | [`check_bridge_1sig`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L79)                       | ✅ proof | the real bytecode accepts at K=1 only if the Kontrol model's `psAt(1)` exceeds the threshold          |
|                                                                          | [`check_bridge_2sig`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L87)                       | ✅ proof | same at K=2: bytecode accept ⟹ `psAt(2) > threshold`                                                  |
|                                                                          | [`check_bridge_3sig`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L95)                       | ✅ proof | same at K=3: bytecode accept ⟹ `psAt(3) > threshold`                                                  |
|                                                                          | [`check_reach_bridge_canAccept`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L107)           | 🔍 reach | witnesses: where the model predicts acceptance, the real bytecode DOES accept                         |

**The `relay()` epoch-decision matrix**

| Harness                                                                                | Check                                                                                         | Kind     | Proves / witnesses                                                                                |
| -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------- |
| [`RelayWrongEpochFV`](../../test-forge/fv/RelayWrongEpochFV.t.sol#L24)                 | [`check_wrongEpoch_rejected`](../../test-forge/fv/RelayWrongEpochFV.t.sol#L59)                | ✅ proof | an epoch-1 message can never be finalized by the epoch-2 signing policy                           |
|                                                                                        | [`check_reach_correctEpoch`](../../test-forge/fv/RelayWrongEpochFV.t.sol#L65)                 | 🔍 reach | witnesses: a same-epoch message CAN be finalized                                                  |
| [`RelayDelayedPolicyFV`](../../test-forge/fv/RelayDelayedPolicyFV.t.sol#L23)           | [`check_delayedPolicy_rejected`](../../test-forge/fv/RelayDelayedPolicyFV.t.sol#L55)          | ✅ proof | a same-epoch round before the policy's validity start is always rejected as delayed               |
|                                                                                        | [`check_reach_atStart`](../../test-forge/fv/RelayDelayedPolicyFV.t.sol#L60)                   | 🔍 reach | witnesses: a round at/after the policy start CAN be finalized                                     |
| [`RelayFinalizationWindowFV`](../../test-forge/fv/RelayFinalizationWindowFV.t.sol#L25) | [`check_messageTooOld_rejected`](../../test-forge/fv/RelayFinalizationWindowFV.t.sol#L86)     | ✅ proof | a message older than the finalization window (here 5 epochs behind `lastInitialized`) is rejected |
|                                                                                        | [`check_reach_recentNotTooOld`](../../test-forge/fv/RelayFinalizationWindowFV.t.sol#L92)      | 🔍 reach | witnesses: a recent message CAN still be finalized in the same state                              |
| [`RelayCrossEpochFV`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L23)                 | [`check_crossEpoch_noDoubleCount`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L62)           | ✅ proof | cross-epoch: a duplicate policy-slot index cannot be counted past the **increased** threshold     |
|                                                                                        | [`check_crossEpoch_threshold`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L74)               | ✅ proof | cross-epoch: total weight ≤ the ×1.2-increased threshold can never accept                         |
|                                                                                        | [`check_crossEpoch_reachability`](../../test-forge/fv/RelayCrossEpochFV.t.sol#L84)            | 🔍 reach | witnesses: weight above the increased threshold CAN finalize cross-epoch                          |
| [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L20)     | [`check_scaling_neverWeakens`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L38)         | ✅ proof | the cross-epoch rescale never lowers the threshold (proved in its division-free equivalent form)  |
|                                                                                        | [`check_scaling_identityAtBoundary`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L47)   | ✅ proof | at `tib = 10000` (×1.0) the actual division is the exact identity — no truncation loss            |
|                                                                                        | [`check_scaling_noOverflow`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L53)           | ✅ proof | the rescale never overflows: the truncated result never exceeds the 16-bit product                |
|                                                                                        | [`check_reach_scaling_canIncrease`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L60)    | 🔍 reach | witnesses: with `tib > 10000` the rescale CAN strictly raise the threshold                        |
| [`RelayMustUseNewPolicyFV`](../../test-forge/fv/RelayMustUseNewPolicyFV.t.sol#L30)     | [`check_mustUseNewPolicy_afterStart`](../../test-forge/fv/RelayMustUseNewPolicyFV.t.sol#L81)  | ✅ proof | once epoch 2 is initialized, the epoch-1 policy cannot finalize rounds at/after its start         |
|                                                                                        | [`check_reach_oldPolicyOkBeforeStart`](../../test-forge/fv/RelayMustUseNewPolicyFV.t.sol#L87) | 🔍 reach | witnesses: before the new epoch's (delayed) start, the old policy CAN still finalize              |

**Threshold consistency on the live paths**

| Harness                                                                                    | Check                                                                                           | Kind     | Proves / witnesses                                                                 |
| ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- | -------- | ---------------------------------------------------------------------------------- |
| [`RelayThresholdConsistencyFV`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L27) | [`check_thresholdTooSmall_rejected`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L62) | ✅ proof | `setSigningPolicy` rejects any threshold below 50% of total voter weight           |
|                                                                                            | [`check_thresholdTooBig_rejected`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L70)   | ✅ proof | `setSigningPolicy` rejects any threshold above 66% of total voter weight           |
|                                                                                            | [`check_reach_inBand_accepted`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol#L77)      | 🔍 reach | witnesses: an in-band threshold IS accepted — the validation is not always-revert  |
| [`RelayModeOneFV`](../../test-forge/fv/RelayModeOneFV.t.sol#L29)                           | [`check_modeOne_thresholdTooSmall_rejected`](../../test-forge/fv/RelayModeOneFV.t.sol#L79)      | ✅ proof | a Mode-1-relayed new policy with a below-MIN-band threshold can never be installed |
|                                                                                            | [`check_reach_modeOne_validInstalls`](../../test-forge/fv/RelayModeOneFV.t.sol#L88)             | 🔍 reach | witnesses: an in-band Mode-1 new policy CAN be installed by the old quorum         |

**Access control and lifecycle**

| Harness                                                                      | Check                                                                                            | Kind     | Proves / witnesses                                                                           |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | -------- | -------------------------------------------------------------------------------------------- |
| [`RelayAccessControlFV`](../../test-forge/fv/RelayAccessControlFV.t.sol#L19) | [`check_setSigningPolicy_onlySetter`](../../test-forge/fv/RelayAccessControlFV.t.sol#L40)        | ✅ proof | for ANY setter address other than the caller, `setSigningPolicy` always reverts              |
|                                                                              | [`check_reach_setter_canCall`](../../test-forge/fv/RelayAccessControlFV.t.sol#L50)               | 🔍 reach | witnesses: the registered setter CAN rotate the policy                                       |
| [`RelayConstructorFV`](../../test-forge/fv/RelayConstructorFV.t.sol#L23)     | [`check_ctor_rejectsLowThresholdIncrease`](../../test-forge/fv/RelayConstructorFV.t.sol#L83)     | ✅ proof | Relay initialization rejects any `thresholdIncreaseBIPS` below 10000 (×1.0)                  |
|                                                                              | [`check_ctor_rejectsZeroRewardEpochDuration`](../../test-forge/fv/RelayConstructorFV.t.sol#L93)  | ✅ proof | Relay initialization rejects a zero reward-epoch duration (RLY-11, div-by-zero)              |
|                                                                              | [`check_ctor_rejectsZeroVotingEpochDuration`](../../test-forge/fv/RelayConstructorFV.t.sol#L102) | ✅ proof | Relay initialization rejects a zero voting-epoch duration (RLY-11)                           |
|                                                                              | [`check_ctor_rejectsZeroPolicyHash`](../../test-forge/fv/RelayConstructorFV.t.sol#L111)          | ✅ proof | Relay initialization rejects a zero initial signing-policy hash (L-4, would brick the epoch) |
|                                                                              | [`check_ctor_homeForce_rejectsForeignSource`](../../test-forge/fv/RelayConstructorFV.t.sol#L120) | ✅ proof | initialization with a live signing-policy setter rejects a foreign source-chain domain       |
|                                                                              | [`check_reach_ctor_validDeploys`](../../test-forge/fv/RelayConstructorFV.t.sol#L166)             | 🔍 reach | witnesses: the valid base config DOES initialize                                             |
| [`RelayEpochAdvanceFV`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L21)   | [`check_epochAdvance_requiresSequential`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L44)     | ✅ proof | any epoch other than `lastInitialized+1` is rejected — no skip, replay, or regress           |
|                                                                              | [`check_reach_epochAdvance_correctSucceeds`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L54)  | 🔍 reach | witnesses: the exact next epoch IS accepted                                                  |
|                                                                              | [`check_epochAdvance_incrementsByOne`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L67)        | ✅ proof | a successful `setSigningPolicy` advances `lastInitialized` by exactly +1 (the monotone step) |

**Owner, timelock, modes, and UUPS**

| Harness                                                                       | Check                                                                                                   | Kind     | Proves / witnesses                                                                                 |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------- |
| [`RelayOwnerTimelockFV`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L118) | [`check_timelock_queueRequiresOwner`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L126)              | ✅ proof | a non-owner cannot queue a guarded call or change its target state                                 |
|                                                                               | [`check_timelock_exactCalldataHash`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L142)               | ✅ proof | a queue entry authorizes only the exact calldata, not another argument under the same selector     |
|                                                                               | [`check_timelock_enforcesRecordedEta`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L165)             | ✅ proof | execution before the recorded ETA fails without consuming the entry                                |
|                                                                               | [`check_timelock_permissionlessOneShotExecution`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L184)  | ✅ proof | any caller can execute at ETA, exactly once                                                        |
|                                                                               | [`check_timelock_cancelRequiresOwner`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L207)             | ✅ proof | a non-owner cannot cancel or consume the queued call                                               |
|                                                                               | [`check_timelock_failedExecutionIsAtomic`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L229)         | ✅ proof | a reverting target restores the queue entry and does not leak execution authorization              |
|                                                                               | [`check_reach_timelock_permissionlessExecution`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L256)   | 🔍 reach | witnesses successful execution by a distinct caller at ETA                                         |
| [`RelayOwnerModesFV`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L270)    | [`check_timelock_relayModeFeeSetters`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L283)             | ✅ proof | relay-mode fee operations wait for the timelock and then apply                                     |
|                                                                               | [`check_timelock_relayModeCannotEnableSetter`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L315)     | ✅ proof | relay mode cannot be switched into signing-policy-setter mode                                      |
|                                                                               | [`check_timelock_setterModeGuardedSurface`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L333)        | ✅ proof | setter mode permits setter rotation and rejects fee-control execution                              |
|                                                                               | [`check_reach_timelock_setterRotation`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L371)            | 🔍 reach | witnesses a matured setter rotation                                                                |
| [`RelayOwnerUpgradeFV`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L401)  | [`check_timelock_proxyInitializerInvariants`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L404)      | ✅ proof | the proxy initializes once and the implementation stays locked                                     |
|                                                                               | [`check_timelock_upgradeExactAndPreservesStorage`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L429) | ✅ proof | only the exact queued implementation/data pair upgrades and selected Relay/timelock state survives |
|                                                                               | [`check_timelock_nestedGuardIsSingleUseAndAtomic`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L461) | ✅ proof | migration data cannot reuse the one-shot guard; failure rolls the upgrade back                     |
|                                                                               | [`check_timelock_storageNamespaceDisjoint`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L483)        | ✅ proof | the timelock ERC-7201 root is aligned and differs from the three ERC-1967 slots                    |
|                                                                               | [`check_reach_timelock_upgradeCanExecute`](../../test-forge/fv/RelayOwnerTimelockFV.t.sol#L499)         | 🔍 reach | witnesses a real queued proxy upgrade at ETA                                                       |

**Merkle & randomness**

| Harness                                                                                | Check                                                                                         | Kind     | Proves / witnesses                                                                        |
| -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------- |
| [`RelayRandomBindingFV`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L35)           | [`check_p4_uncommittedValue_cannotStore`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L91) | ✅ proof | a trailer random value differing from the root-committed one can never finalize           |
|                                                                                        | [`check_p4_storedEqualsCommitted`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L101)       | ✅ proof | on every accepting run the stored random (live + historical) equals the committed value   |
|                                                                                        | [`check_p4_reachability`](../../test-forge/fv/RelayRandomBindingFV.t.sol#L114)                | 🔍 reach | witnesses: the committed value CAN finalize and be stored                                 |
| [`RelayRandomMonotonicityFV`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L25) | [`check_staleDoesNotRegress`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L75)        | ✅ proof | relaying an older round after a newer one never regresses the live random pointer         |
|                                                                                        | [`check_advances`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L85)                   | ✅ proof | relaying a newer round after an older one advances the live pointer to it                 |
|                                                                                        | [`check_bothHistoricalRetained`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L95)     | ✅ proof | after both relays, both rounds' random values remain retrievable historically             |
|                                                                                        | [`check_reachability_twoRelays`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol#L106)    | 🔍 reach | witnesses: two successful random relays in sequence ARE reachable                         |
| [`RelayMerkleProofFV`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L24)               | [`check_m2_wrongSibling_cannotStore`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L73)       | ✅ proof | a proof sibling differing from the committed one can never reproduce the signed root      |
|                                                                                        | [`check_m3_misalignedProof_rejected`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L82)       | ✅ proof | a misaligned trailer (not a whole number of 32-byte words) is always rejected             |
|                                                                                        | [`check_reach_matchingProof`](../../test-forge/fv/RelayMerkleProofFV.t.sol#L89)               | 🔍 reach | witnesses: the matching, aligned proof CAN finalize                                       |
| [`RelayMerkleFoldFV`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L24)                 | [`check_fold_base_injective`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L34)                | ✅ proof | induction base: the empty-proof fold is the identity, so distinct leaves stay distinct    |
|                                                                                        | [`check_fold_step_injective`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L43)                | ✅ proof | induction step: one sorted-pair fold with the same sibling never merges distinct hashes   |
|                                                                                        | [`check_fold_depth2_injective`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L50)              | ✅ proof | corroboration: an equal depth-2 root with the same proof forces equal leaves (no forgery) |
|                                                                                        | [`check_reach_fold_distinguishes`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L59)           | 🔍 reach | witnesses: distinct inputs DO produce distinct folds                                      |

**Fees**

| Harness                                                                          | Check                                                                                | Kind     | Proves / witnesses                                                                                  |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | -------- | --------------------------------------------------------------------------------------------------- |
| [`RelayFeeConservationFV`](../../test-forge/fv/RelayFeeConservationFV.t.sol#L43) | [`check_p7_feeConservation`](../../test-forge/fv/RelayFeeConservationFV.t.sol#L116)  | ✅ proof | a succeeding `verify()` (real balances) moves exactly the fee: collector +fee, caller −fee, relay 0 |
|                                                                                  | [`check_p7_reachability`](../../test-forge/fv/RelayFeeConservationFV.t.sol#L135)     | 🔍 reach | witnesses: a successful `verify()` exists at this config — the fee path is live                     |
| [`RelayVerifyFeeFV`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L18)             | [`check_fee_conserved`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L31)              | ✅ proof | forwarded + refund always equals `msg.value` — no ETH created or destroyed                          |
|                                                                                  | [`check_fee_noOverpayKept`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L39)          | ✅ proof | exactly the fee is forwarded and the refund never exceeds `msg.value`                               |
|                                                                                  | [`check_fee_underpaymentImpossible`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L48) | ✅ proof | under-payment (`msg.value < fee`) can never satisfy the `require` guard                             |
|                                                                                  | [`check_reach_exactFee`](../../test-forge/fv/RelayVerifyFeeFV.t.sol#L56)             | 🔍 reach | witnesses: paying exactly the fee yields a zero refund (a conserving split is reachable)            |

**Encoding / return / secure-bit (P3/P5/P6/P8)**

| Harness                                                                                  | Check                                                                                            | Kind     | Proves / witnesses                                                                                                                                                                                                                                                                          |
| ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`RelayCanonicalityFV`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L35)               | [`check_p3_badV_cannotAccept`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L80)                | ✅ proof | a signature with `v ∉ {27,28}` can never accept, even at winning weight                                                                                                                                                                                                                     |
|                                                                                          | [`check_p3_highS_cannotAccept`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L91)               | ✅ proof | a high-`s` (above secp256k1n/2) signature can never accept, even at winning weight                                                                                                                                                                                                          |
|                                                                                          | [`check_p3_reachability_canonicalAccepts`](../../test-forge/fv/RelayCanonicalityFV.t.sol#L105)   | 🔍 reach | witnesses: a canonical winning-weight signature CAN accept                                                                                                                                                                                                                                  |
| [`RelayIsSecureNormFV`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L61)               | [`check_historicalSecure_eq_byteNonZero`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L144)    | ✅ proof | accept ⟹ the stored historical isSecure bit equals `(raw byte != 0)`                                                                                                                                                                                                                        |
|                                                                                          | [`check_liveSecure_eq_byteNonZero`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L157)          | ✅ proof | accept ⟹ the live `isSecureRandom` flag equals `(raw byte != 0)`                                                                                                                                                                                                                            |
|                                                                                          | [`check_liveAndHistorical_agree`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L169)            | ✅ proof | on every accepting run the live flag and the historical bit agree                                                                                                                                                                                                                           |
|                                                                                          | [`check_leafNorm_machineChecked`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L187)            | ✅ proof | the Merkle-leaf isSecure rule is exactly `(byte != 0)`, for all 256 byte values                                                                                                                                                                                                             |
|                                                                                          | [`check_reach_insecure_canAccept`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L203)           | 🔍 reach | witnesses: the insecure normalization (byte 0) CAN finalize                                                                                                                                                                                                                                 |
|                                                                                          | [`check_reach_secure_canAccept`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L209)             | 🔍 reach | witnesses: the secure normalization (byte 1) CAN finalize                                                                                                                                                                                                                                   |
|                                                                                          | [`check_reach_highByte_canAccept`](../../test-forge/fv/RelayIsSecureNormFV.t.sol#L217)           | 🔍 reach | witnesses: a high byte (> 1) CAN finalize, pinning the leaf rule over 2..255                                                                                                                                                                                                                |
| [`RelayReturnDiscriminatorFV`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L41) | [`check_protocolId1_successReturns35`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L82) | ✅ proof | a successful protocolId-1 (custom-signature) relay returns exactly 35 bytes                                                                                                                                                                                                                 |
|                                                                                          | [`check_reach_protocolId1_canAccept`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L90)  | 🔍 reach | witnesses: the protocolId-1 accept path is reachable                                                                                                                                                                                                                                        |
|                                                                                          | [`check_protocolId3_successReturns0`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L100) | ✅ proof | a successful protocolId-3 (Mode-2) relay returns exactly 0 bytes                                                                                                                                                                                                                            |
|                                                                                          | [`check_protocolId3_isNot35`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L110)         | ✅ proof | a Mode-2 success can never return 35 bytes — the discriminator cannot be spoofed                                                                                                                                                                                                            |
|                                                                                          | [`check_reach_protocolId3_canAccept`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol#L118) | 🔍 reach | witnesses: the protocolId-3 accept path is reachable                                                                                                                                                                                                                                        |
| [`RelayPolicyHashFV`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L63)                   | [`check_policyHash_equiv_NV1`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L121)                 | ✅ proof | the assembly policy hash equals the reference fold — now the **RLY-23 chain-bound** fold `keccak256(sourceChainId ‖ contentFold)` — for **all** symbolic 1-voter policies (so the on-chain chain-domain wrap in `calculateSigningPolicyHash` is symbolically confirmed to match the oracle) |
|                                                                                          | [`check_policyHash_equiv_NV2`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L130)                 | ✅ proof | the same equivalence over all symbolic 2-voter policies                                                                                                                                                                                                                                     |
|                                                                                          | [`check_policyHash_equiv_NV3`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L141)                 | ✅ proof | the same at 3 voters — multiple full chunks plus a 13-byte remainder fold                                                                                                                                                                                                                   |
|                                                                                          | [`check_policyHash_mismatchReachable_NV3`](../../test-forge/fv/RelayPolicyHashFV.t.sol#L159)     | 🔍 reach | witnesses: a bit-flipped stored hash DOES fire the mismatch revert — the detector is live                                                                                                                                                                                                   |

**Historical Safe/GSS inventory.** Its checks were retired with that design and
are absent from the current manifest. Consult Git history only; they are not
current Relay evidence.

**The `ecrecover` ABI (OP-1 — the §4.4 harness, not in the catalog above)**

| Harness                                                                              | Check                                                                                               | Kind     | Proves / witnesses                                                                            |
| ------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------- |
| [`RelayEcrecoverSymbolicFV`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L55) | [`check_emptyReturn_rejected`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L84)              | ✅ proof | an empty precompile return (bad signature) is never accepted, whatever the stale buffer holds |
|                                                                                      | [`check_zeroSigner_rejected`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L91)               | ✅ proof | a well-formed 32-byte zero signer is always rejected                                          |
|                                                                                      | [`check_accepted_usesFreshReturn_notStale`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L99) | ✅ proof | an accepting guard uses the fresh return, never the stale buffer; accepts iff the signer ≠ 0  |
|                                                                                      | [`check_reach_validSigner_accepted`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol#L109)       | 🔍 reach | witnesses: a genuine non-zero signer IS accepted — the accept path is live                    |

---

## 4.4 Modeling approach & assumptions

- **Real bytecode vs. self-contained model.** Most harnesses drive the **real compiled `Relay`** through
  symbolic calldata (the high-value ones: [`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol#L29), [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L37), [`RelayModeOneFV`](../../test-forge/fv/RelayModeOneFV.t.sol#L29), the
  gate harnesses). A few isolate a piece of pure arithmetic/logic into a self-contained model where that is
  the faithful unit of the property (e.g. [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol#L20) replicates the exact rescale formula
  and EVM truncating division; [`RelayMerkleFoldFV`](../../test-forge/fv/RelayMerkleFoldFV.t.sol#L24) reasons about the fold structure). Each harness header
  states which it is.
- **The modeling contract (standing assumptions).** `keccak256` is an injective uninterpreted function;
  `ecrecover` is uninterpreted (ECDSA unforgeability assumed) — we verify accounting, not cryptography. The
  signing-policy setter is trusted to supply distinct, non-zero, canonically-ordered voters with normalized
  weights (RLY-06). OZ `MerkleProof.verifyCalldata` internals are assumed correct (call-site in scope).
  `oldRelay` is a trusted prior deployment. These are enumerated in [L10](10-claims-ledger-trust-and-residual.md).
- **Precompile modeling — the `ecrecover` ABI, and how OP-1 is internalized.** Halmos's _built-in_ `0x01` is
  a _total_ function returning a well-formed 32-byte address (`returndatasize()==32` always), so the
  whole-`relay()` symbolic runs use the adversary-conservative uninterpreted recovery and do not, by
  themselves, exercise the real failure ABI — on a bad signature the precompile returns _success with empty
  return data_ and leaves the output buffer **unmodified**. The contract's `staticcall`-success,
  `returndatasize()==32`, and zero-signer checks are what make reality conform to that model
  (assumption/obligation **OP-1** in [L10](10-claims-ledger-trust-and-residual.md)). OP-1 is discharged two
  ways: a real-EVM regression ([`test-forge/fv/RelayEcrecoverABI.t.sol`](../../test-forge/fv/RelayEcrecoverABI.t.sol)) that pins the actual precompile's
  empty-return/stale-buffer ABI, **and** a symbolic harness ([`test-forge/fv/RelayEcrecoverSymbolicFV.t.sol`](../../test-forge/fv/RelayEcrecoverSymbolicFV.t.sol))
  that reaches the empty-return branch via a mock reproducing that ABI and proves — over ALL stale-buffer
  contents — the guard rejects it (plus Foundry/Hardhat failure-path tests and assembly review). The guard is
  load-bearing and must never be removed.
- **Bound rationale.** K≤3, N≤5 are chosen to exercise every branch and the double-count/threshold
  boundaries while staying solver-tractable; the unbounded dimensions are escalated to R3/R4.
- **Historical Safe/GSS boundary.** The retired harness began after EIP-712
  digest construction and signer recovery. It is absent from the source tree
  and current manifest, so its results do not apply to this architecture.

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

Expected: the gate prints the per-check table and `[fv] OK - exact proof inventory holds and every reachability control has a valid witness.`.

---

## 4.6 What R2 establishes and does not

- **Establishes, only after a current successful run:** the listed
  signing-policy accounting, epoch matrix, access control, lifecycle,
  owner/timelock/UUPS, Merkle, randomness, and fee properties at their stated
  bounds. Every proof must be paired with the declared reachability result.
- **Does not:** reach arbitrary K or N. The signature loop beyond K=3 and voter sets beyond N=5 are the
  induction barrier, handled at R3 (Kontrol, ∀K) and R4 (Lean, ∀N∀K), with [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L37) connecting
  R3's model back to this bytecode. It also does not prove ECDSA, uniqueness of
  voter addresses, or the semantics of arbitrary future implementation code.

**Next:** [L5 — R3: unbounded attempts](05-R3-unbounded-attempts.md) — crossing the induction barrier with
Kontrol, and the honest assembly wall that Kontrol's symbolic-N and Certora both hit.
