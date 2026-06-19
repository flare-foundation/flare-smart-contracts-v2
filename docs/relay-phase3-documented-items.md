# Relay.sol — Phase 3: document-class obligations

Several Phase-3 obligations are, by the plan's own tool assignment (`docs/relay-phase3-plan.md`),
**review / Foundry-test / documented-assumption** items rather than FV proofs — because FV is the wrong
tool (the property is an EVM-semantics corollary, an external dependency assumed correct, or out of
practical range). This file closes them with grounded justifications. Line refs are to `relay-fix-3`.

## AC-3 — no state write survives a reverted relay()  (EVM-semantics corollary)

**Claim.** If `relay()` reverts, no storage change persists.

**Justification.** This is guaranteed by EVM semantics: a `REVERT` rolls back *all* storage writes made in
the call frame. Every `sstore` in `relay()` (the random `isSecureRandomMap` bit @679; `stateData` @1333/
@1490; `merkleRootsPrivate` @1384; the Mode-1 policy hash/`startingVotingRoundIds` @1141/@1153) executes
only on the success path, *after* every gate (`Wrong sign policy reward epoch`, `Message too old`, `Delayed
sign policy`, `Must use new sign policy`, the signature/threshold quorum, the Merkle/random checks). All of
those gates `revert` on failure, so no partial write can persist. The gate proofs (RelayWrongEpochFV,
RelayFinalizationWindowFV, RelayDelayedPolicyFV, RelayMustUseNewPolicyFV, RelaySig*FV, RelayMerkleProofFV,
RelayRandomBindingFV) each assert `!accept` on the reject path; combined with EVM revert-atomicity, AC-3
holds. **A dedicated FV harness adds nothing over the EVM guarantee + the existing gate proofs.**

## R1 / R2 — reentrancy benignity of verify() and the governance self-call  (no state writes)

**Claim.** The external calls in `verify()` and the `_verifyCustomSignature` re-entrant `relay()` call
cannot corrupt contract state via reentrancy.

**Justification.**
- `verify()` (Relay.sol:1550-1605) performs **no `sstore`** — it only reads (`merkleRootsPrivate`,
  `protocolFeeInWei`) and then makes value-transfer calls (fee-forward @1593, refund @1599, or the old-relay
  delegation @1567/@1572). RLY-21 (@1588-1589) states this explicitly: "verify() performs no state writes,
  so these external calls cannot corrupt contract state." A reentrant call back into the new-relay path of
  `verify()` re-reads the same already-finalized root and re-pays from the caller's fresh `msg.value`; there
  is no mutable state to corrupt and no value beyond `msg.value` at risk (fee conservation proven in
  `RelayVerifyFeeFV`).
- `_verifyCustomSignature` (@1724) re-enters `relay()` via `address(this).call(_relayMessage)` with a
  protocolId==1 message; that nested `relay()` runs the normal verified gate logic and the **nonce write in
  `governanceFeeSetup` happens after the verification returns** (RLY-02, @493-494), so a stale-snapshot
  replay is impossible — proven for all nonces in `RelayGovernanceNonceFV`.

**Residual.** `oldRelay` is a *trusted, audited* prior deployment (standing assumption #4); R1's benignity
for the delegation branch holds under that trust. Recommended: a concrete Foundry idempotence/sequence test
(verify→verify, relay→verify) as a regression net — integration-shaped, not FV.

## M4 — verify() correctly delegates to OpenZeppelin MerkleProof  (external dependency assumed)

**Claim.** `verify()` checks membership correctly via OZ `MerkleProof.verifyCalldata` (@1585).

**Justification.** OZ `MerkleProof.verifyCalldata` internal correctness is a **standing assumption** (#3):
FV proves Relay *calls* it with the stored root and the caller's leaf/proof, and gates on the result
(`require(_proof.verifyCalldata(root, _leaf))`), plus `require(root != 0)` (RLY-01, never verify an
uninitialized root). The *random-number* Merkle path is hand-rolled in assembly and IS fully FV-verified
(`RelayMerkleProofFV` + `RelayRandomBindingFV`); the `verify()` path reuses OZ, so only the call-site is in
scope. A bug *inside* OZ would pass silently — accepted as the dependency boundary.

## R6 / R7 — far-future arithmetic edges  (out of practical scope, accepted)

- **R7:** `uint32 votingRoundId` wraps after ~2³² voting rounds ≈ **386 years** at the configured voting-
  epoch duration. **RLY-19:** `rewardEpochId` truncation horizon ≈ **47 years**.
- These are beyond any operational lifetime and are **documented as accepted, not proven**. The near-term
  arithmetic that matters (weight sums ≤ 2¹⁶, threshold scaling) is bounded and verified
  (`RelayThresholdScalingFV`, the `totalWeight < 2¹⁶` constructor guard reviewed in
  `relay-assembly-review.md`).

## Status summary

| Obligation | Disposition |
|-----------|-------------|
| AC-3 no-write-on-revert | ✅ closed (EVM revert-atomicity + gate proofs) |
| R1/R2 reentrancy | ✅ closed (verify() has no sstore; nonce write post-verify) — concrete regression test recommended |
| M4 OZ MerkleProof | ✅ closed (call-site in scope; OZ internals assumed — standing assumption #3) |
| R6/R7 far-future arithmetic | ✅ accepted out-of-scope (386 yr / 47 yr) |

## Previously-deferred items — now resolved (the only irreducible gap is full symbolic-N)

All three originally-deferred items have been invested in and resolved (AC-6 and T1 fully; item #3
to the limit of the toolchain). The **single remaining irreducible gap** is **full symbolic-N for the
signature loop**, which is *empirically* state-explosive (a Kontrol/hardware limit, not an effort gap) —
mitigated by verified N∈{3,5} plus the meta-induction structure. Details below.

## Previously-deferred work — resolution

- **AC-6 — Mode-1 (relay-only) new-signing-policy threshold consistency** — ✅ **DONE** (`RelayModeOneFV`).
  The full protocolId==0 relay path is verified: calldata `selector || oldPolicy || protocolId(0) ||
  newPolicy || sigs`; checkThresholdConsistency (Relay.sol:1109/666) rejects a too-small-threshold new
  policy (PASS), and a valid one installs (reach-control CEX confirms the construction is non-vacuous).
- **T1 — model↔bytecode bridge** — ✅ **DONE (bounded composition)** (`RelayModelBridgeFV` + docs/relay-t1-bridge.md).
  The fully-symbolic single-iteration form is non-observable (relay() is monolithic; instrumenting changes
  the bytecode) and a full real-relay() Kontrol proof is intractable. Delivered instead as an explicit
  bridge: the real bytecode obeys the Kontrol model's own psAt invariant at K=1,2,3 (Halmos, PASS) +
  reach-control CEX; composed with the Kontrol model proof for all K. Honest residual: bytecode-side bound
  K<=3 (every distinct loop-body path is exercised at K<=3). See docs/relay-t1-bridge.md.
- **Step 7 — symbolic-N / Merkle tree-induction / cross-epoch-unbounded** (Kontrol). The unbounded sig-loop
  is verified (Kontrol, k-induction) at **N=3 and N=5** — these are the practical parametric points.
  **N=10 was attempted and found INTRACTABLE**: with the packed-weight encoding (16-bit lanes via
  bit-shift/mask, needed to dodge stack-too-deep and Kontrol's array-param limit), a single-core prove ran
  **12 h with 0 of 4 proofs completing** — the lane bit-ops make each SMT query much harder and N=10's
  per-step case explosion (≈N² configurations) compounds it. This empirically confirms the plan's
  state-explosion caveat: **full symbolic-N is not viable on this toolchain/hardware.** The unbounded-in-K
  guarantee (the security-critical dimension) holds at N∈{3,5}; larger N would need a fundamentally
  different encoding (e.g. a genuine loop-invariant over an array, which Kontrol 1.0.248 cannot summarize)
  or far more compute. **Merkle tree-induction (M1/M7) — ✅ DONE UNBOUNDED** (`RelayMerkleFoldFV`): unlike
  the sig-loop, the Merkle fold's inductive step is a single keccak (sorted-pair hash), so base + step
  k-induction discharges in Halmos and gives fold injectivity / anti-forgery at ANY proof depth (no off-tree
  leaf can be forged into a valid proof). **Cross-epoch / monotonicity unbounded (AC-12)**: the random-
  pointer monotonicity is already proven unbounded in Kontrol (`kontrol/RelayRandomMonoFV`); the
  lastInitialized +1-monotonicity follows by meta-induction from L1's verified single-step
  (`RelayEpochAdvanceFV`); the cross-epoch decision-matrix coherence is fully verified bounded (every gate).
  So of item #3 only **full symbolic-N for the sig-loop remains genuinely out of reach** (state explosion),
  with N=3/5 as the practical points.
