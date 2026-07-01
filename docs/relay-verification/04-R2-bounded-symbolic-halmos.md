# L4 — R2: bounded symbolic execution (Halmos)

> **What you get from this level.** The workhorse rung: 25 harnesses / 85 checks that **symbolically
> execute the real `Relay.sol` bytecode** and prove properties over *all* inputs up to a fixed size. The
> suite design (including the anti-vacuity tripwire and the loop-bound subtlety that makes the whole thing
> trustworthy), the full property catalog, the modeling assumptions, and how to reproduce.

---

## 4.1 What Halmos is, and why it is the bounded floor *on the real bytecode*

Halmos runs the compiled contract with **symbolic** inputs: instead of one concrete calldata, it explores
*all* calldata at once via an SMT solver, reporting any input that violates an `assert`. Crucially it
**executes the actual bytecode** — it does not reconstruct a model from Solidity structure — so it is
**immune to the assembly barrier** (Enemy 2): Relay's hand-rolled storage is just bytecode being run.

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
`test-forge/fv/**` (for a how-to-read-the-suite primer, see [`test-forge/fv/README.md`](../../test-forge/fv/README.md)), reads the JSON, and judges each check by convention:

- a **proof** check (name without `reach`) must have **no counterexample**;
- a **reachability** control (name contains `reach`) must **produce a counterexample**.

It prints a per-check table and the summary line, and exits non-zero on any violation. Current CI output:

```
[fv] 85 checks: 57 proofs hold, 28 reachability controls live (CEX). 0 violation(s).
[fv] OK — all proofs hold and every reachability control is live (non-vacuous).
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
`solver-timeout-assertion = 0` lets a few valid-but-nonlinear proofs (e.g. [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol))
solve to completion rather than being cut off and misreported as counterexamples (see L11 and the CI-gate
memory).

---

## 4.3 The property catalog (25 harnesses)

Grouped by area. Each harness pairs proof checks with ≥1 reachability control. "Models" notes whether the
harness drives the real compiled `Relay` or a self-contained model (see §4.4).

### Signature / threshold accounting — the core

| Harness | Property | Notes |
|---------|----------|-------|
| [`RelaySigFV`](../../test-forge/fv/RelaySigFV.t.sol) | accept ⟹ enough distinct registered weight; **no double-count** (`noDoubleCount_duplicateIndex_cannotAccept`); threshold rejection (`threshold_twoVoters_cannotAccept`) | tight per-prefix |
| [`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol) | the same, **parametric** at K≤3 on real bytecode: `threshold_1/2/3sig_param`, `noDoubleCount_headDup/tailDup_param` | the **bytecode** side of the loop |
| [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol) | the real bytecode obeys the Kontrol model's `psAt` prefix-sum invariant: `bridge_1/2/3sig` | **ties R3's model to the bytecode** at K≤3 |

These three are the bounded, real-bytecode counterpart of the unbounded soundness proven at R3 (Kontrol,
∀K) and R4 (Lean, ∀N∀K). `RelayModelBridgeFV` is the explicit bridge that justifies trusting the model.

### The `relay()` epoch-decision matrix (Relay.sol:743–754, all five gates)

| Harness | Gate |
|---------|------|
| [`RelayWrongEpochFV`](../../test-forge/fv/RelayWrongEpochFV.t.sol) | wrong-epoch rejected (`wrongEpoch_rejected`; `reach_correctEpoch`) |
| [`RelayDelayedPolicyFV`](../../test-forge/fv/RelayDelayedPolicyFV.t.sol) | delayed-policy gate |
| [`RelayFinalizationWindowFV`](../../test-forge/fv/RelayFinalizationWindowFV.t.sol) | too-old / finalization-window gate |
| [`RelayCrossEpochFV`](../../test-forge/fv/RelayCrossEpochFV.t.sol) + [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol) | threshold-increase (cross-epoch) gate |
| [`RelayMustUseNewPolicyFV`](../../test-forge/fv/RelayMustUseNewPolicyFV.t.sol) | must-use-new-policy (`mustUseNewPolicy_afterStart`; `reach_oldPolicyOkBeforeStart`) |

`RelayThresholdScalingFV` deserves note: it proves the cross-epoch rescale `threshold := threshold *
thresholdIncreaseBIPS / 10000` **never weakens** the threshold (`neverWeakens`), is the identity at the
boundary (`identityAtBoundary`), and does not overflow (`noOverflow`). Its `neverWeakens`/`identityAtBoundary`
are nonlinear and need `solver-timeout-assertion = 0` (§4.2).

### Threshold consistency on the live paths

| Harness | Property |
|---------|----------|
| [`RelayThresholdConsistencyFV`](../../test-forge/fv/RelayThresholdConsistencyFV.t.sol) | threshold consistency on the **setter path** (`thresholdTooBig/TooSmall_rejected`; `reach_inBand_accepted`) |
| [`RelayModeOneFV`](../../test-forge/fv/RelayModeOneFV.t.sol) | threshold consistency on the **live Mode-1 relay path** (`modeOne_thresholdTooSmall_rejected`; `reach_modeOne_validInstalls`) |

### Access control, governance, lifecycle

| Harness | Property |
|---------|----------|
| [`RelayAccessControlFV`](../../test-forge/fv/RelayAccessControlFV.t.sol) | only the signing-policy setter rotates the policy |
| [`RelayConstructorFV`](../../test-forge/fv/RelayConstructorFV.t.sol) | constructor **fail-closes** on bad config (incl. L4/RLY-11) |
| [`RelayGovernanceNonceFV`](../../test-forge/fv/RelayGovernanceNonceFV.t.sol) | governance-fee **nonce replay protection** for all nonces; fee-setup mode-gating (AC-2) |
| [`RelayEpochAdvanceFV`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol) | strict **+1** epoch advance + monotonic `lastInitialized` state-effect |

### Merkle & randomness

| Harness | Property |
|---------|----------|
| [`RelayRandomBindingFV`](../../test-forge/fv/RelayRandomBindingFV.t.sol) | random value binding / no-forgery (`p4_storedEqualsCommitted`, `p4_uncommittedValue_cannotStore`) |
| [`RelayRandomMonotonicityFV`](../../test-forge/fv/RelayRandomMonotonicityFV.t.sol) | random-pointer monotonicity over arbitrary sequences (`advances`, `bothHistoricalRetained`, `staleDoesNotRegress`; `reach_twoRelays`) |
| [`RelayMerkleProofFV`](../../test-forge/fv/RelayMerkleProofFV.t.sol) | proof-element + alignment soundness (`m2_wrongSibling_cannotStore`, `m3_misalignedProof_rejected`) |
| [`RelayMerkleFoldFV`](../../test-forge/fv/RelayMerkleFoldFV.t.sol) | **unbounded-depth** fold injectivity / anti-forgery |

### Fees

| Harness | Property |
|---------|----------|
| [`RelayFeeConservationFV`](../../test-forge/fv/RelayFeeConservationFV.t.sol) | fee conservation in `relay()` |
| [`RelayVerifyFeeFV`](../../test-forge/fv/RelayVerifyFeeFV.t.sol) | fee conservation in `verify()` (`fee_conserved`, `fee_noOverpayKept`, `fee_underpaymentImpossible`; `reach_exactFee`) |

### Encoding / return / secure-bit (P3/P5/P6/P8)

| Harness | Property |
|---------|----------|
| [`RelayCanonicalityFV`](../../test-forge/fv/RelayCanonicalityFV.t.sol) | P3 — encoding canonicality |
| [`RelayIsSecureNormFV`](../../test-forge/fv/RelayIsSecureNormFV.t.sol) | P5 — `isSecureRandom` normalization |
| [`RelayReturnDiscriminatorFV`](../../test-forge/fv/RelayReturnDiscriminatorFV.t.sol) | P6 — return discriminator (`protocolId1_successReturns35`, `protocolId3_successReturns0/isNot35`) |
| [`RelayPolicyHashFV`](../../test-forge/fv/RelayPolicyHashFV.t.sol) | P8 — policy-hash equivalence (`policyHash_equiv_NV1/2/3`; `policyHash_mismatchReachable_NV3`) |

**Totals:** 25 harnesses, **85 checks = 57 proofs + 28 reachability controls** (cross-checked against the
CI gate output).

---

## 4.4 Modeling approach & assumptions

- **Real bytecode vs. self-contained model.** Most harnesses drive the **real compiled `Relay`** through
  symbolic calldata (the high-value ones: [`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol), [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol), [`RelayModeOneFV`](../../test-forge/fv/RelayModeOneFV.t.sol), the
  gate harnesses). A few isolate a piece of pure arithmetic/logic into a self-contained model where that is
  the faithful unit of the property (e.g. [`RelayThresholdScalingFV`](../../test-forge/fv/RelayThresholdScalingFV.t.sol) replicates the exact rescale formula
  and EVM truncating division; [`RelayMerkleFoldFV`](../../test-forge/fv/RelayMerkleFoldFV.t.sol) reasons about the fold structure). Each harness header
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
  induction barrier, handled at R3 (Kontrol, ∀K) and R4 (Lean, ∀N∀K), with [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol) connecting
  R3's model back to this bytecode.

**Next:** [L5 — R3: unbounded attempts](05-R3-unbounded-attempts.md) — crossing the induction barrier with
Kontrol, and the honest assembly wall that Kontrol's symbolic-N and Certora both hit.
