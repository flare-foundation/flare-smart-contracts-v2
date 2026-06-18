# Relay.sol — Phase 3 robustness verification plan

Phases 1–2 proved the signature-accounting core (Halmos bounded P1–P8 + Kontrol unbounded-in-K
signature-loop weight invariant and random-pointer monotonicity, on a faithful Solidity model).
Phase 3 closes the remaining gaps. This plan is grounded in a read of the actual `Relay.sol`.

Gap areas: **(T)** tighten existing proofs (bytecode↔model bridge; symbolic voter count N),
**(A)** access control / governance, **(L)** lifecycle / state-machine, **(M)** Merkle-proof
soundness, **(R)** reentrancy / DoS / arithmetic.

## Sequenced steps (front-loaded by value)

| Step | Title | Tool | Effort | Covers |
|------|-------|------|--------|--------|
| 1 | Regression net: guards, config, mode, arithmetic | Foundry tests | ~2–4 d | AC-1/5/9/10/11, L4/5/9/10/11/12/13, R6/R7 |
| 2 | Manual review of assembly mutation surface, memory layout, unchecked arithmetic | review | ~2 d | AC-4/8, L6, R8, memory-no-collision |
| 3 | **T1**: bmc-depth-1 bytecode↔model single-iteration equivalence (the bridge) | Kontrol | ~1 d + slow prove | T1 |
| 4 | Bounded state-machine + mutation gating | Halmos (loop=6) | ~4–6 d | AC-3/6, L1/2/3/7/8, R5, weight-no-overflow |
| 5 | Bounded Merkle-proof soundness + 2 governance signature-path tests | Halmos / Foundry | ~3–5 d | M2/3/5/6/8, AC-2/7 |
| 6 | Integration / OZ-boundary / reentrancy / DoS | Foundry + Halmos | ~3–4 d | M4, R1/2/3/4/10, cross-epoch no-double-count |
| 7 | Unbounded Kontrol generalizations (run last, slow) | Kontrol | ~1–2 wk wall | symbolic-N + corollaries, Merkle tree-induction M1/M7, cross-epoch AC-12 |

**Order rationale:** cheap high-certainty wins + the load-bearing T1 bridge first (T1 is what makes
every unbounded Kontrol result apply to the real bytecode, not a model); then the bounded Halmos sweep
(fastest real-bug-finding); defer the expensive unbounded Kontrol generalizations (highest cost, only
*incremental* assurance over already-bounded-verified properties). Bulk of assurance lands in steps 1–5.

## Effort

- **Cheap (≈1–1.5 wk):** step 1, step 2, light arithmetic Halmos — most of Phase 3 by obligation count.
- **Moderate (≈1–1.5 wk):** bounded Halmos state-machine + Merkle + integration (steps 4–6).
- **Expensive (≈1–2 wk wall-clock, emulation-bound):** Kontrol (T1 + step 7 generalizations; minutes-to-hours per proof).

## Standing assumptions (FV is the wrong tool, by design)

1. **Cryptography** — keccak injective + ecrecover uninterpreted; ECDSA unforgeability assumed.
2. **Trusted setter (RLY-06)** — distinct/non-zero voters + `startingVotingRoundId` monotonicity are
   FlareSystemsManager's responsibility, documented not proven.
3. **OZ `MerkleProof.verifyCalldata`** internals assumed correct (M4 only checks Relay *calls* it right).
4. **`oldRelay`** is a trusted prior deployment.
5. **Inherited Phase-2 caveat:** base+step ⟹ ∀K composition is sound at the meta level but not
   itself machine-checked (Kontrol 1.0.248 has no native loop-invariant); loop=6 anti-vacuity is a CI
   process control, not a static guarantee.

## Biggest technical risks

- **T1 (the bridge) is the linchpin** — if the assembly↔state isomorphism is too manual, the unbounded
  proofs stay about the model. Sequenced early for this reason.
- **Symbolic-N** can hit Kontrol state explosion → mitigation: no-array `psAt`-via-conditionals;
  fallback to parametric N ∈ {2,3,5,10,300} keeping K unbounded.
- **Truncating EVM division** in threshold-scaling must be modeled exactly in SMT or the proof diverges
  from bytecode → unit-test the scaling formula in isolation first.

## Out of practical scope (document as accepted, not proven)

- `uint32 votingRoundId` wrap (~386 yr out), `rewardEpochId` truncation (~47 yr out).

## Verified status (live)

| Obligation | Harness | Status |
|-----------|---------|--------|
| **R5** cross-epoch threshold scaling never weakens the gate | `RelayThresholdScalingFV` | ✅ verified (Halmos) |
| **L1** `setSigningPolicy` strict +1 epoch advance | `RelayEpochAdvanceFV` | ✅ verified |
| **AC-1** `setSigningPolicy` access control (only setter) | `RelayAccessControlFV` | ✅ verified |
| **AC-11 + L4 + RLY-11** constructor config validation | `RelayConstructorFV` | ✅ verified |
| **Step 2** assembly review | `docs/relay-assembly-review.md` | ✅ delivered |
| **L7** random monotonicity (non-monotone sequences) | `RelayRandomMonotonicityFV` (+ Kontrol) | ✅ already covered |
| cross-epoch threshold soundness | `RelayCrossEpochFV` | ✅ already covered |
| **L3** finalization window | `RelayFinalizationWindowFV` | ✅ verified (multi-step: 6-epoch advance) |
| **L8** cross-epoch must-use-new-policy gate | `RelayMustUseNewPolicyFV` | ✅ verified (multi-step: setSigningPolicy-advance + cross-epoch relay) |
| **AC-3** no state write on reject | — | ⏳ largely an EVM-revert corollary |
| **AC-6** Mode-1 policy-rotation validation | — | ⏳ needs Mode-1 relay setup |
| **AC-10** nonce replay protection (RLY-02) | `RelayGovernanceNonceFV` | ✅ verified (multi-tx, symbolic nonce) |
| **M2 + M3/M8** Merkle proof-path soundness (proof-element + alignment) | `RelayMerkleProofFV` | ✅ verified |
| Step 5 remainder (M5/M6) / Step 6 integration / Step 3+7 Kontrol | — | ⏳ pending |

Note: harnesses with a symbolic 16-bit product (e.g. R5 `neverWeakens`) need
`--solver-timeout-assertion 0` (above Halmos's 60s default).
