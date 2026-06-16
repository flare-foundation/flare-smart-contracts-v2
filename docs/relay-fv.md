# Relay.sol — Formal Verification (Phase 0 modeling contract + Phase 1 plan)

**Target:** `contracts/protocol/implementation/Relay.sol` @ `relay-fix-3`.
**Primary focus (per author):** the `relay()` function and signature verification.
**Tooling:** Halmos (bounded symbolic execution on the Foundry harness) for Phase 1; Kontrol (KEVM, inductive) reserved for Phase 2.
**Substrate:** `test-forge/unit/protocol/implementation/Relay.t.sol` (52 concrete tests) is reused as the symbolic harness.

This document is the **modeling contract**: it fixes *exactly* what we prove and what we assume, so that every Phase-1 "PASS" has a precise meaning. Read this before trusting any proof.

---

## 1. Why this tooling

`relay()` is ~930 lines of hand-written inline assembly (manual calldata parsing, manual memory slots `M_0..M_8`, two loops). Consequences:

- **Source-level / refinement tools (Act, solc-verify) are a poor fit** — they bind to Solidity structure that the assembly does not expose. (This is the conclusion the research phase reached.)
- **Bytecode-level symbolic execution is the right fit** — it executes the compiled EVM directly and is indifferent to whether the body is assembly or Solidity. Two such tools:
  - **Halmos** (a16z) — symbolic executor that *reuses Foundry tests*: a `check_*` function with symbolic inputs is explored over all paths, each path's feasibility + assertion discharged by an SMT solver (z3). Loops are **bounded** (unrolled). Fast to iterate; reuses our deploy/encode helpers verbatim. → **Phase 1**.
  - **Kontrol** (Runtime Verification, KEVM) — full K semantics of the EVM; supports **unbounded** reasoning via loop invariants and multi-transaction induction. Heavier, needs K lemmas. → **Phase 2** (monotonicity across call sequences; unbounded signer count; memory-slot non-collision).

### Bounded vs. inductive — what "bounded" means here
Halmos unrolls each loop to a fixed iteration count. So a Phase-1 theorem reads:

> **For a fixed signer count K (and Merkle depth ≤ D)**, *for all* inputs (weights, threshold, signatures, addresses, calldata layout consistent with the harness), the asserted property holds.

This is a genuine ∀-over-inputs proof **at each fixed shape K** — not example-based testing — but it does **not** by itself cover all K up to `MAX_VOTERS = 300`. We run K = 1..K_max (K_max ≈ 4–6, solver-time permitting) and argue the loop body is uniform; the fully unbounded statement is the Phase-2 obligation. Each result below is annotated with its bound.

---

## 2. The central abstraction: separate cryptography from accounting

The signature loop does two kinds of work. We treat them differently **on purpose**.

| Work | Examples | How we model it | Why |
|---|---|---|---|
| Cryptographic | `keccak256`, `ecrecover` | **Uninterpreted functions** | Curve math / collision-resistance are not EVM-level facts; "proving" them would be vacuous or circular. |
| Accounting | index monotonicity & range, `v∈{27,28}`, low-`s`, `signer==voters[index]`, `weight+=weights[index]`, `accept ⟺ weight>threshold` | **Proved exactly** (symbolic, bounded) | This is the security-relevant logic the contract actually owns. |

### 2.1 `keccak256` — injective uninterpreted function (assumption **A1**)
Modeled as a function with no algebraic content except *injectivity* (distinct preimages ⇒ distinct images). Sound **given** collision-resistance. Used for: the signed-message hash, the signing-policy hash, the Merkle leaf/node hashes.

### 2.2 `ecrecover` — uninterpreted function (assumption **A2**) — the subtle one
Halmos models precompile `0x01` as an uninterpreted function `E(hash,v,r,s) → address`: **functional** (same args → same result) but otherwise **unconstrained** (the solver may return *any* address).

- **This gives the adversary strictly more power than reality**: when searching for a counterexample, the solver may freely set `E(h,v_i,r_i,s_i) = voters[i]`. Any accounting invariant that survives this (e.g. "cannot accept with ≤ threshold of distinct registered weight") therefore holds *a fortiori* under real ECDSA. Uninterpreted ecrecover is the **conservative, sound** choice for the threshold/no-double-count theorems.
- **What this deliberately does NOT prove:** "a non-voter cannot contribute weight." That rests on **ECDSA unforgeability** (cannot produce `(v,r,s)` recovering to an address whose key you don't hold), which is a **cryptographic assumption outside the EVM model** (assumption **A2′**, out of scope). FV proves the *on-chain half* — weight is credited to `voters[i]` only on the path where the recovered signer equals `voters[i]`, each index at most once — and A2′ supplies the other half. Together: "only the quorum can finalize." We machine-check the first half and **state** the second.

### 2.3 Bounded loops (assumption **A3**)
K signers, Merkle depth ≤ D, fixed. Stated per result.

### 2.4 Distinct voters (assumption **A4**, = RLY-06)
The loop's strict index-increase proves **no *index* is counted twice**. To upgrade to **no *signer* counted twice** we need `voters[i]` pairwise distinct — exactly the **RLY-06** trusted-setter assumption (FlareSystemsManager guarantees it; documented, not enforced on-chain). In the harness this becomes a literal premise `vm.assume(distinct(voters))`. So FV turns the RLY-06 prose caveat into a **formal hypothesis** of the no-double-count theorem; results that need it are tagged `[A4]`.

### 2.5 Solver / precompile defaults (assumption **A5**)
Halmos's default handling of gas (ignored), `staticcall` to `0x01` (intercepted as `E`), and memory/calldata (fully symbolic byte arrays). EVM `cancun`, optimizer on (200 runs) — proofs run against the **same compiled artifact** the tests use.

---

## 3. The signature loop, as code (what we are reasoning about)

Per provided signature, `relay()` does (`Relay.sol`):

1. `index + 1 > numberOfVoters` → revert `"Index out of range"` — `:1257`
2. `index < nextUnusedIndex` → revert `"Index out of order"`; then `nextUnusedIndex = index + 1` — `:1261`
3. `v ∉ {27,28}` → revert `"Bad v"` — `:1269`
4. `s > secp256k1n/2` → revert `"Bad s"` (EIP-2 low-s) — `:1275`
5. `staticcall(0x01)` (ecrecover); `returndatasize()==32`; recovered `≠ 0` (`"Zero signer"`) — `:1283`, `:1295`, `:1300`
6. recovered `== voters[index]` else revert `"Wrong signature"` — `:1316`
7. `weight += weights[index]` — `:1325`
8. `weight > threshold` ⇒ **accept** (mode-specific return) — `:1330`

**Key structural fact:** step 6 *reverts* on a mismatch — there is no "skip." So a successful `relay()` implies **every** provided signature matched its claimed voter, was canonically formed, and carried a strictly-increasing in-range index. Acceptance fires the first time the running `weight` exceeds `threshold`.

---

## 4. Phase 1 proof obligations (signature/threshold core first)

Each obligation: informal statement; formal statement; assumptions; tool/bound; code anchor. Status filled in as proofs land.

### P1 — No-double-count (weight bound)
- **Informal:** the loop cannot count more weight than the registered voters it actually matched, and never a voter twice.
- **Formal:** on any non-reverting execution with K provided signatures, `weight = Σ_{i∈S} weights[index_i]` where `S` indexes a set of *strictly-increasing* (hence distinct) indices, each `< numberOfVoters`. Hence `weight ≤ Σ_{j ∈ distinct indices} weights[j] ≤ Σ_{all j} weights[j]`. With **[A4]**, distinct indices ⇒ distinct signers ⇒ no signer double-counted.
- **Assumptions:** A1, A3 (K), A5; A4 for the signer-level corollary.
- **Tool/bound:** Halmos, K = 1..K_max. **Status:** ✅ **proved (parametric, bounded)** — `RelaySigParamFV.check_noDoubleCount_{tailDup,headDup}_param`: for ALL weights, with single-counting assumed insufficient, the duplicate index layouts `[0,1,1]` and `[0,0,1]` cannot accept (the strict-increase guard rejects the repeat before the weight add at `Relay.sol:1261` vs `:1325`). Fixed-config instance: `RelaySigFV.check_noDoubleCount_duplicateIndex_cannotAccept`. Caveat: only these duplicate layouts at NV=3 (see §6).

### P2 — Threshold soundness
- **Informal:** you cannot make `relay()` accept without strictly more than `threshold` of matched, distinct registered weight.
- **Formal:** `relay()` returns (does not revert) ⇒ `weight > threshold` at the accept point, where `weight` is as in P1 (all summands matched `voters[index]` via `E`, indices strictly increasing & in range, `v/s` canonical). Contrapositive checked too: a configuration whose maximal matchable distinct weight `≤ threshold` cannot reach a non-reverting return.
- **Assumptions:** A1, A2, A3, A5 (+ A4 to read "distinct signers").
- **Tool/bound:** Halmos, K = 1..K_max. **Status:** ✅ **proved (parametric, bounded, TIGHT per-prefix form)** — `RelaySigParamFV.check_threshold_{1,2,3}sig_param`: for ALL weights/threshold and each prefix length K∈{1,2,3}, providing K signatures whose total weight ≤ thr cannot accept. This pins the contract's actual accept condition (acceptance fires on the first prefix exceeding thr, `Relay.sol:1330`) and rules out premature-accept at every prefix — strictly stronger than the earlier total-sum bound. Fixed-config instance: `RelaySigFV.check_threshold_twoVoters_cannotAccept`. `check_reachability_param` / `check_reachability_threeVoters_canAccept` confirm non-vacuity. Caveats: bounded shape K≤3, same-epoch (un-increased) threshold (see §6).

### P3 — Canonicality gating (malleability / zero-signer)
- **Formal:** any signature with `v ∉ {27,28}` or `s > n/2` or recovered `address(0)` causes a revert *before* its weight is added (no contribution to `weight`).
- **Assumptions:** A2, A3, A5. **Tool:** Halmos. **Status:** ✅ **proved (bounded, K=1)** — `RelayCanonicalityFV.check_p3_{badV,highS}_cannotAccept`: a single signature with `v∉{27,28}` or high-`s` cannot accept even when its weight alone exceeds the threshold (the `"Bad v"`/`"Bad s"` reverts at `Relay.sol:1269/1275` precede the weight add at `:1325`); `check_p3_reachability_canonicalAccepts` confirms a canonical sig accepts. Zero-signer: documented (unreachable to acceptance — recovered must equal the non-zero `voters[index]`). Caveat: single-signature shape.

### P4 — Random-proof binding (second-preimage / value binding)
- **Formal:** `toRandomNumberPrivate[vrid]` can be set to `val` only if `keccak256(abi.encode(vrid, val, isSecure))` is a leaf reproducing the **signed** `merkleRoot` via the provided proof. Equivalently: no accepting run sets the stored random to a value not committed under the signed root.
- **Assumptions:** A1 (injective keccak ⇒ binding), A3 (depth ≤ D), A5. **Tool:** Halmos. **Status:** ✅ **proved (bounded, decoupled-oracle, machine-checked)** — `RelayRandomBindingFV`: `check_p4_uncommittedValue_cannotStore` (a trailer value ≠ the committed/signed value cannot finalize — no forgery) and `check_p4_storedEqualsCommitted` (accept ⟹ live & historical stored random == the committed value `cv`); reachability `check_p4_reachability`. Built with the same independent-oracle method as P5's leaf (committed `cv` decoupled from trailer `tv`, so acceptance forces `tv==cv` by injective keccak A1). Caveat: fixed 2-leaf tree (1-node proof), 3 sigs, same-epoch — deeper proofs / unbounded are Phase 2.

### P5 — `isSecure` normalization
- **Formal:** the `isSecure` fed to the Merkle leaf, the stored `isSecureRandomMap` bit, and the live `stateData.isSecureRandom` flag are all equal to `(messageByte != 0)` (RLY-14). **Tool:** Halmos. **Status:** ✅ **proved (bounded, b∈0..255, 3 sigs, 2-leaf tree)** — `RelayIsSecureNormFV`: `check_leafNorm_machineChecked` (leaf rule is exactly `(b!=0)`, via an INDEPENDENT decoupled leaf bit so a divergent rule like `b&1` is caught), `check_historicalSecure_eq_byteNonZero` (stored map bit), `check_liveSecure_eq_byteNonZero` (live flag), `check_liveAndHistorical_agree`; reachability controls at `b=0`, `b=1`, and `b>1`. **Scope note:** the proven sinks are leaf / stored-map-bit / live-flag. The *emitted event* `isSecure` field (`Relay.sol:1508`/`:1526`) is written from the **same** `isSecure` local (the RLY-14 "one normalization, every sink" fact) but is not separately asserted — verifying the emitted field directly is a small follow-up.

### P6 — 35-byte return discriminator
- **Formal:** only the `protocolId==1` path returns 35 bytes; Mode-0 returns 0 / Mode-2 returns 0 or reverts — so `_verifyCustomSignature`'s length check cannot be confused. **Tool:** Halmos. **Status:** ✅ **proved (bounded, K=3)** — `RelayReturnDiscriminatorFV`: `check_protocolId1_successReturns35`, `check_protocolId3_successReturns0`, `check_protocolId3_isNot35`; reachability for both paths. Caveat: Mode-0 (`protocolId==0`, also returns 0) not separately exercised — irrelevant to `_verifyCustomSignature`, which only issues `protocolId==1` calls.

### P7 — Fee conservation (verify(), new-relay path)
- **Formal:** for `msg.value ≥ fee`, after `verify()` succeeds: `feeCollection` balance += `fee`, caller net −`fee`, contract retains 0. **Tool:** Halmos. **Status:** ✅ **proved (bounded, msg.value/fee ≤ 2¹²⁸)** — `RelayFeeConservationFV.check_p7_feeConservation` (the three balance deltas mirror `Relay.sol:1590-1603`); `check_p7_reachability` confirms a reachable success. Caveats: new-relay path only (oldRelay==0 fallback has its own accounting, unit-tested separately); value cap is non-restrictive (≫ ETH supply).

### P8 — Signing-policy-hash equivalence
- **Formal:** the assembly `calculateSigningPolicyHash` equals the reference fold (lift the harness's dynamic cross-check to symbolic input). **Tool:** Halmos. **Status:** ✅ **proved (bounded, NV∈{1,2,3})** — `RelayPolicyHashFV.check_policyHash_equiv_NV{1,2,3}` (assembly fold `Relay.sol:574-602` ≡ reference fold `Relay.t.sol:111-128` — byte-identical keccak-call sequence under A1); `check_policyHash_mismatchReachable_NV3` is the sensitivity tripwire. Caveat: NV≤3 (covers initial-word + mid-fold + zero-padded-tail cases); up to MAX_VOTERS=300 rests on loop uniformity (Phase 2).

**PHASE 1 COMPLETE (P1–P8 all ✅, bounded).** All eight obligations proved with Halmos on the unmodified contract, each with a non-vacuity reachability control; the signature/threshold core (P1/P2) and the random binding (P4/P5) carry machine-checked (decoupled-oracle) forms. Two adversarial-audit rounds (signature core; P3–P8) returned valid-with-caveats / no false PASS. P4 follows the audit-validated decoupled-oracle pattern (not separately re-audited).

**Deferred to Phase 2 (Kontrol, unbounded/inductive):** random monotonicity across `relay()` sequences; threshold soundness for unbounded K via loop invariant; cross-epoch no-double-count (threshold-increase path); deeper Merkle proofs / NV up to 300; `M_0..M_8` non-collision as machine-checked lemmas. Plus CI wiring of the reachability tripwires.

---

## 4b. Phase 0/1 execution status (2026-06-15)

**Phase 0 — DONE.**
- Halmos 0.3.3 + z3 4.12.6 installed in an isolated venv at `../.venv-halmos` (outside the repo).
- Toolchain proven end-to-end: `test-forge/fv/HalmosSmoke.t.sol` gives one PASS (∀-proof) and one expected counterexample. Repo builds to `artifacts-forge`, so Halmos needs `--forge-build-out artifacts-forge` (persisted in `halmos.toml`).
- This modeling contract (§1–§3) written and reviewed.

**Phase 1 — first valid bounded proofs of the signature/threshold core (2026-06-15).**
- `test-forge/fv/RelaySigFV.t.sol` runs Halmos against the REAL `relay()` (no contract changes): concrete signing policy (N=5, weight 100, threshold 260), symbolic signatures. Result with the correct config: **`check_threshold_twoVoters_cannotAccept` PASS, `check_noDoubleCount_duplicateIndex_cannotAccept` PASS, `check_reachability_threeVoters_canAccept` → counterexample** (non-vacuity confirmed). ~0.7s.
- The deploy under Halmos needs a fully-concrete `setUp` (no `vm.addr`/`vm.sign`/sorting) — voters are arbitrary distinct addresses (sound: ecrecover is uninterpreted, so keypairs are unnecessary).

**ROOT CAUSE of the earlier "accept path unreachable" (RESOLVED): the Halmos loop bound.**
`--loop` defaults to **2**. `relay()`'s signature loop runs once per signature, so at the default bound any test with **3+ signatures has its accepting iteration truncated** → the accept path looks unreachable and negative properties pass **vacuously**. Evidence trail: 1 sig (thr 10) accepts; 2 sigs (thr 150) accept at the bound; 3–4 sigs "can't accept" in 0.3s even with an 8-minute solver budget (i.e. fast UNSAT, not a timeout) — and **flip to a counterexample under `--loop 4`**. Fix: `halmos.toml` now sets `loop = 6`; the in-test `check_reachability_*` control is the standing tripwire against a too-small bound. (Ruled out along the way and recorded for the report: raw `staticcall(0x01)` ecrecover returns a free, fully-matchable word; 3 distinct matches from one digest are jointly SAT; the hash check passes; the `Relay.sol:976` threshold-increase does NOT apply to a same-epoch message; accept-path completion is clean; `"unknown deployed bytecode"` is cosmetic. Also confirmed: relay-only mode does NOT enforce the `setSigningPolicy` minimal-threshold rule on the constructor-set initial policy — only *relayed* policies hit `checkThresholdConsistency` at `:1109` — which is what let a sub-minimal threshold be used to bisect single- vs multi-signature behaviour.)

**PARAMETRIC proofs done + audited (2026-06-15).** `test-forge/fv/RelaySigParamFV.t.sol` generalizes to SYMBOLIC weights + threshold (deployed in-check; empty `setUp`): `check_threshold_{1,2,3}sig_param` PASS (tight per-prefix soundness), `check_noDoubleCount_{tailDup,headDup}_param` PASS (`[0,1,1]`/`[0,0,1]`), `check_reachability_param` → counterexample. **5 passed; 1 failed (=the by-design counterexample).** A 4-lens adversarial audit returned **valid-with-documented-caveats, zero mustFix**; the one Medium (total-sum vs accept-point) was closed by the per-prefix reformulation. Caveats recorded in §6.

- **Next:** P3 (canonicality gating: bad v / high s / zero signer rejected before counting), P5 (isSecure normalization), P6 (35-byte return discriminator), P7 (fee conservation in `verify()`), P8 (signing-policy-hash equivalence). For unbounded signer count / cross-epoch (N) and larger duplicate layouts, use the symbolic-voter pattern (`voters[i] := f_ecrecover(...)`) and/or Kontrol (Phase 2).

## 5. Reading the output
- **PASS** (for obligation P, bound K): no input within the modeling contract (§2) and bound K makes the assertion fail. A real ∀-proof at that shape, *relative to A1–A5*.
- **Counterexample**: Halmos prints a concrete input. Either a genuine bug, or a harness over-approximation (e.g. a missing `vm.assume` that admits an impossible calldata layout). Triage decides which; harness constraints we add are themselves recorded here as part of the modeling contract.

---

## 6. Audit of the P1/P2 proofs + standing caveats (2026-06-15)

A 4-lens adversarial audit (vacuity, faithfulness, hidden-assumptions, modeling-fidelity) + synthesis was run over `RelaySigFV` and `RelaySigParamFV`. **Verdict: valid-with-documented-caveats — zero mustFix.** The proofs are sound for what they assert; the synthesizer re-verified the load-bearing facts against the code (accept fires mid-loop at `Relay.sol:1330`; the strict-increase guard reverts the duplicate before `weight +=` at `:1261`/`:1325`; the same-epoch arithmetic makes the `:976` increase inert; signing-policy-hash byte-layout fidelity is grounded by `test_signingPolicyHash_matchesContract`). The one Medium finding (threshold assertion used the over-approximate total-sum rather than the tight accept-point/prefix weight) was **closed** by reformulating P2 into the per-prefix contrapositive family `check_threshold_{1,2,3}sig_param`.

**Standing caveats — each PASS means the property holds ONLY within these bounds (do not over-read as the unbounded contract guarantee):**
1. **Bounded shape.** Threshold soundness covers K∈{1,2,3} signatures; no-double-count covers the `[0,1,1]` and `[0,0,1]` duplicate layouts at NV=3. The live contract allows up to `MAX_VOTERS=300` and arbitrary duplicate positions/run-lengths. Generality rests on loop-body uniformity (asserted, not machine-checked) — an unbounded proof is the Kontrol/Phase-2 obligation.
2. **Same-epoch only.** The message maps to the policy's own reward epoch, so the threshold-increase path (`Relay.sol:976`) is never exercised. For threshold *soundness* the increased threshold is covered a fortiori (harder to accept); but the no-double-count premise references the un-increased policy threshold, so (N) does **not** transfer to a cross-epoch message without a dedicated instance.
3. **Anti-vacuity is a process control, not a static guarantee.** The PASSes are meaningful only because `check_reachability_*` produces a counterexample at `loop ≥ signer-count` (halmos.toml `loop = 6`). This already failed at the default `loop = 2`. **Required:** run the reachability controls in every CI invocation and treat an unexpected reachability PASS as a hard failure.
4. **Distinct voters (A4 / RLY-06) is constructional.** Voter addresses are hardcoded distinct; the threshold proofs carry no `vm.assume(distinct)`. The signer-level reading ("distinct indices ⇒ distinct signers") therefore relies on the trusted-setter precondition `relay()` does not enforce in relay-only mode.
5. **Cryptography assumed, not proved (A1/A2).** Uninterpreted ecrecover/keccak ⇒ only the on-chain accounting half of "only the quorum can finalize" is established; ECDSA unforgeability and keccak collision-resistance are external assumptions (conservative direction — uninterpreted ecrecover gives the adversary more power).
6. **Conservative input widening.** The parametric harness quantifies over all NV=3 policies, including thresholds (`thr=0`, `thr≥sum`) that the setter-mode `checkThresholdConsistency` (`:1109`, Mode-1 only) would reject — strictly stronger than "for setter-valid policies." Threshold/weight *consistency* is a separate property owned by `checkThresholdConsistency`, NOT established here.

---

## 7. Audit of the P3–P8 proofs (2026-06-15)

A 4-lens adversarial audit (vacuity / faithfulness / over-constraint / harness-fidelity) + synthesis was run over the five new harnesses (`RelayCanonicalityFV`, `RelayReturnDiscriminatorFV`, `RelayFeeConservationFV`, `RelayIsSecureNormFV`, `RelayPolicyHashFV`). **Verdict: valid-with-caveats — no false PASS.** The synthesizer independently re-derived each (P3 reverts precede the weight add `:1269-1280`/`:1325`; P6 length reads hit the real return sites `:1362`/`:1432`; P7 deltas mirror `:1590-1603`; P8 the two folds are byte-identical; P5 S1/S2 machine-checked over symbolic `b`).

Two P5 mustFix items were applied:
1. **Leaf normalization upgraded from by-construction to machine-checked** — `check_leafNorm_machineChecked` builds the signed root from an INDEPENDENT leaf bit decoupled from the message byte, so `accept ⟹ (b!=0) == lb` now proves the contract's leaf rule is exactly `(b!=0)` over all `b` (would catch a `b&1` divergence); added a `b>1` reachability control (`check_reach_highByte_canAccept`).
2. **Docs sink list corrected** — P5 above now lists the *proven* sinks (leaf / stored map bit / live flag) and scopes the emitted-event field honestly.

Per-obligation caveats are recorded inline in §4 (P3 single-sig; P6 Mode-0 not exercised; P7 new-relay-path-only + value cap; P8 NV≤3); the generic bounded-MC caveats of §6 apply throughout. Halmos result across the five: **16 PASS + 9 reachability counterexamples** (`loop = 6`; max loop depth on any path = 3).

---

## 8. CI enforcement (the anti-vacuity gate)

`test-forge/fv/verify_fv.py` makes §6 caveat 3 an **enforced gate** rather than a convention. It runs Halmos over `test-forge/fv` (JSON output) and requires **both** halves of every proof:

- every **proof** check passes (no counterexample), and
- every **reachability / non-vacuity control** (function name contains `reach`) produces a **counterexample**.

An unexpected reachability **PASS** is a hard failure — the *vacuity alarm* — because it means the accept path became unreachable (e.g. `--loop` dropped below a harness's signer count) and the guarded proofs went vacuous. Halmos's own exit code is unusable as a signal (non-zero by design, since the reachability controls produce counterexamples), so the script judges each check from the JSON.

Run locally (from the repo root; `halmos.toml` supplies `loop = 6` + `forge-build-out`):
```
HALMOS=halmos python3 test-forge/fv/verify_fv.py
```
Validated both directions: at `loop = 6` it reports **40 checks — 27 proofs hold, 13 reachability controls live**, exit 0; forced to `--loop 2` it exits 1 with vacuity alarms (the multi-iteration controls flip to PASS), proving the gate catches a real regression.

Wired into GitLab CI as job **`test-fv-halmos`** (`.gitlab-ci.yml`) — **green in the pipeline**. The runner's `foundry:stable` image is non-root with no Python, so the job runs on `python:3.12` (`pip install --user halmos` + `foundryup`), depends on `build-smart-contracts` and pulls the node_modules cache (forge build needs the `@gnosis.pm` remapping), and is `rules`-scoped to changes in `Relay.sol` / its interfaces / `test-forge/fv/**` / `halmos.toml`.

---

## 9. Phase 2 — inductive / unbounded + multi-transaction (2026-06-16)

Phase 2 targets the properties bounded model checking can't reach by itself. They split by tool:

**Done now (bounded, Halmos):** two Phase-2 caveats from §6 are closed with new harnesses, both gated by reachability controls:
- **Cross-epoch** no-double-count + threshold soundness on the threshold-INCREASE path (`RelayCrossEpochFV`): an epoch-2 message finalized by the epoch-1 policy raises the effective threshold to `thr × 1.2` (`Relay.sol:960/976`); proofs hold there, and the threshold check also confirms the ×1.2 increase is actually applied. (Closes §6 caveat 2 for the bounded shape.)
- **Random monotonicity across a 2-call sequence** (`RelayRandomMonotonicityFV`): relaying an older round after a newer one does not regress the live pointer; the pointer advances for a newer round; both rounds stay historically retrievable. The live round is pinned via `_randomTimestamp`. (Bounded instance of the multi-transaction monotonicity obligation.)

Full FV suite now: **10 contracts, 40 checks — 27 proofs + 13 reachability counterexamples**, all green under the CI gate.

**Remaining UNBOUNDED / inductive obligations (need Kontrol/KEVM):**
- **Threshold soundness / no-double-count for unbounded K** (up to `MAX_VOTERS = 300`) via a signature-loop invariant — the Halmos proofs cover K up to 3 and rest on loop uniformity.
- **Arbitrary-length** random monotonicity (any sequence of `relay()` calls) via multi-transaction induction — Halmos covers the 2-call instance.
- **`M_0..M_8` memory-slot non-collision** as a machine-checked KEVM lemma — currently a hand-derived argument (re-verified in the round-1/2 audits).

**Kontrol provisioning is currently blocked by an UPSTREAM packaging bug (2026-06-16).** This is *not* an environment limitation: with Docker available, the daemon up, and a root container (so the RuntimeVerification binary cache is usable via `--accept-flake-config`), the cache serves prebuilt artifacts (downloads, zero source builds) — but **every** install path fails at Nix *evaluation*:
```
error: lib.customisation.callPackageWith: Function called without required argument "solc_0_8_13"
       at .../nix/kontrol/default.nix:25, did you mean "solc_0_8_33", "solc_0_8_31" or "solc_0_8_32"?
```
Kontrol's `solc` input still references `solc_0_8_13`, which current nixpkgs has removed. Reproduced via raw `nix run github:runtimeverification/kontrol` at HEAD, pinned `v1.0.248`, and `v1.0.241`, **and** via the official `kup install kontrol` — all as root with the working cache. A clean machine doing `kup install kontrol` today hits the same error.

**Paths to run the unbounded proofs (pick per environment):**
1. **Kontrol with a working pin** — a Kontrol release predating the nixpkgs solc removal, or a `--override-input` pinning a nixpkgs commit that still has `solc_0_8_13`, or RV's `kontrol` GitHub Action (which pins a tested toolchain). Track the upstream fix to the solc reference, then `kontrol build` + `kontrol prove` the loop-invariant claims (§4) against the existing `test-forge/fv` harnesses.
2. **Certora Prover** — the peer commercial tool for the same unbounded EVM obligations (CVL specs + loop invariants); no Nix/packaging dependency.

`verify_fv.py` / the CI gate continue to guard the bounded proofs in the meantime.
