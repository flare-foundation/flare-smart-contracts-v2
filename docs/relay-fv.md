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
- **Assumptions:** A2, A3, A5. **Tool:** Halmos. **Status:** _planned._

### P4 — Random-proof binding (second-preimage / value binding)
- **Formal:** `toRandomNumberPrivate[vrid]` can be set to `val` only if `keccak256(abi.encode(vrid, val, isSecure))` is a leaf reproducing the **signed** `merkleRoot` via the provided proof. Equivalently: no accepting run sets the stored random to a value not committed under the signed root.
- **Assumptions:** A1 (injective keccak ⇒ binding), A3 (depth ≤ D), A5. **Tool:** Halmos. **Status:** _planned._

### P5 — `isSecure` normalization
- **Formal:** the `isSecure` used in the leaf hash, the stored `isSecureRandomMap` bit, and the emitted event are all equal to `(messageByte != 0)` (RLY-14). **Tool:** Halmos. **Status:** _planned._

### P6 — 35-byte return discriminator
- **Formal:** only the `protocolId==1` path returns 35 bytes; Mode-0 returns 0 / Mode-2 returns 0 or reverts — so `_verifyCustomSignature`'s length check cannot be confused. **Tool:** Halmos. **Status:** _planned._

### P7 — Fee conservation (verify(), new-relay path)
- **Formal:** for `msg.value ≥ fee`, after `verify()` succeeds: `feeCollection` balance += `fee`, caller net −`fee`, contract retains 0. **Tool:** Halmos. **Status:** _planned._

### P8 — Signing-policy-hash equivalence
- **Formal:** the assembly `calculateSigningPolicyHash` equals the reference fold (lift the harness's dynamic cross-check to symbolic input). **Tool:** Halmos. **Status:** _planned._

**Deferred to Phase 2 (Kontrol, unbounded/inductive):** random monotonicity across `relay()` sequences; threshold soundness for unbounded K via loop invariant; `M_0..M_8` non-collision as machine-checked lemmas.

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
