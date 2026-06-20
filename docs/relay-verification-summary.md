# Relay.sol — formal verification summary (audit entry point)

> **Superseded for navigation by [`docs/relay-verification/`](relay-verification/00-README.md)** — the
> consolidated audit + tutorial + reproducibility set, which is current. In particular, **Gap B (§5 limit
> #2 below) is now CLOSED** (the bytecode-level ∀N refinement is hole-free); see
> [`relay-verification/07-R4b-bytecode-refinement.md`](relay-verification/07-R4b-bytecode-refinement.md)
> and the claims ledger [`relay-verification/10-claims-ledger-trust-and-residual.md`](relay-verification/10-claims-ledger-trust-and-residual.md).
> This file remains as the original concise map; where it and the new set differ, the new set is current.

This is the map of the whole verification effort on `contracts/protocol/implementation/Relay.sol`. It
states what is proven, by which tool, at what scope, under what assumptions, and — just as importantly —
what is **not** proven and why. Per-area detail lives in the linked docs.

## 1. The modeling contract (assumptions — what FV is *not* asked to prove)

All results below hold relative to these standing assumptions; they are where formal methods are the wrong
tool, by design:

- **A1/A2 — cryptography:** `keccak256` is an injective uninterpreted function; `ecrecover` is
  uninterpreted (ECDSA unforgeability assumed). We prove the on-chain **accounting**, not the cryptography.
- **RLY-06 — trusted setter:** the signing-policy setter (FlareSystemsManager) supplies distinct, non-zero,
  canonically-ordered voters with normalised weights; `startingVotingRoundId` is non-decreasing across
  epochs. Documented, not on-chain-enforced.
- **OZ `MerkleProof.verifyCalldata`** internals are assumed correct (only the call-site is in scope).
- **`oldRelay`** is a trusted, audited prior deployment.

See `docs/relay-assembly-review.md` (mutation surface, no delegatecall/fallback, memory layout) and
`docs/relay-phase3-documented-items.md` (the assumption-class obligations: AC-3, R1/R2, M4, R6/R7).

## 2. The verification stack

| Layer | Tool | What it gives | Scope |
|------|------|---------------|-------|
| Symbolic execution on **real bytecode** | **Halmos** | 25 harnesses (`test-forge/fv/*.t.sol`) | bounded (K≤3, N≤5), but the actual deployed bytecode |
| Unbounded-in-K via k-induction | **Kontrol/KEVM** | sig-loop weight invariant + random monotonicity (`test-forge/fv/kontrol/`) | ∀K, on a faithful Solidity **model**, N∈{3,5} |
| Unbounded **algorithm** proof | **Lean 4** | sig-loop threshold soundness (`test-forge/fv/lean/RelaySigLoop.lean`) | **∀N ∀K**, abstract algorithm, machine-checked (no `sorry`) |
| Model↔bytecode bridge | **Halmos** | `RelayModelBridgeFV` — real bytecode obeys the Kontrol model's `psAt` invariant | K=1,2,3 |
| Global storage invariants | **Certora** | specs written + typechecked (`certora/`) | **blocked** — see §5 |

## 3. What is proven (by area)

- **Signature/threshold accounting (the core):** accept ⟹ enough distinct registered weight, no
  double-count — tight per-prefix (Halmos `RelaySig*FV`), unbounded-in-K (Kontrol `RelaySigLoopFV`), and
  **∀N∀K** at the algorithm level (Lean). `RelayModelBridgeFV` ties the Kontrol model's invariant to the
  real bytecode at K≤3.
- **The entire relay() epoch decision matrix** (Relay.sol:743–754) — all five gates:
  wrong-epoch (`RelayWrongEpochFV`), delayed-policy (`RelayDelayedPolicyFV`), too-old/finalization-window
  (`RelayFinalizationWindowFV`), threshold-increase (`RelayCrossEpochFV` + `RelayThresholdScalingFV`),
  must-use-new-policy (`RelayMustUseNewPolicyFV`).
- **Access control & governance:** only the setter rotates policy (`RelayAccessControlFV`); constructor
  fail-closes on bad config (`RelayConstructorFV`, incl. L4/RLY-11); governance-fee nonce replay protection
  for all nonces (`RelayGovernanceNonceFV`); fee-setup mode-gating (AC-2, same file); threshold consistency
  on the setter path and the **live Mode-1 relay path** (`RelayThresholdConsistencyFV`, `RelayModeOneFV`).
- **Lifecycle:** strict +1 epoch advance + monotonic `lastInitialized` state-effect (`RelayEpochAdvanceFV`);
  random-pointer monotonicity over arbitrary sequences (`RelayRandomMonotonicityFV` + Kontrol
  `RelayRandomMonoFV`).
- **Merkle & randomness:** random value binding / no-forgery (`RelayRandomBindingFV`), proof-element +
  alignment soundness (`RelayMerkleProofFV`), and **unbounded-depth** fold injectivity / anti-forgery
  (`RelayMerkleFoldFV`).
- **Fees:** conservation in `relay()` (`RelayFeeConservationFV`) and `verify()` (`RelayVerifyFeeFV`).
- **Encoding/return/secure-bit:** P3/P5/P6/P8 (`RelayCanonicalityFV`, `RelayIsSecureNormFV`,
  `RelayReturnDiscriminatorFV`, `RelayPolicyHashFV`).

Every harness pairs a positive proof with an **anti-vacuity control** that must produce a counterexample —
so a proof that is trivially/vacuously true is caught. For the multi-step harnesses, that counterexample
also confirms the elaborate setup genuinely reaches acceptance.

## 4. Reproducing

- **Halmos:** `halmos --contract <Name>` (a few need `--solver-timeout-assertion 0`; see the note in
  `docs/relay-phase3-plan.md`).
- **Kontrol:** reproducible Docker image (`test-forge/fv/kontrol/Dockerfile` + `run.sh`); see that dir.
- **Lean:** `lean test-forge/fv/lean/RelaySigLoop.lean` (Lean 4, core only — checks in seconds;
  `#print axioms` = `[propext, Quot.sound]`, no `sorryAx`).
- **Certora:** `certoraRun certora/Relay.conf --solc <solc-0.8.27>` (needs `CERTORAKEY`).

## 5. Honest limits (what is NOT proven, and why)

1. **Global all-functions/all-sequences storage invariants** (nonce/epoch monotonicity, setter
   immutability, hash/root write-once) — **not dischargeable by Certora on this contract.** Two cloud runs
   confirmed the failures are *spurious*: Relay is ~90% hand-rolled inline assembly with bit-packed storage
   written via `sstore` to scratch-memory-computed slots, which defeats Certora's storage-slot analysis →
   it havocs all storage. This is the **same wall Kontrol hit** (the N=10 model ran 12 h / 0 proofs). A
   tool-vs-contract-style mismatch, **not a vulnerability**. The per-sequence forms of these properties
   *are* proven (Halmos/Kontrol). Detail: `certora/README.md`.
2. **Bytecode-level ∀N (Gap B)** — lifting the Lean ∀N∀K algorithm proof to the real bytecode via a
   refinement against validated EVM semantics (EVMYulLean) is scoped and founded but **not completed**
   (person-weeks–months). Detail + plan: `docs/relay-gapB-bytecode-refinement.md`.
3. **Full symbolic-N in Kontrol** — empirically state-explosive; mitigated by verified N∈{3,5} + the Lean
   ∀N proof + the bounded model↔bytecode bridge. Detail: `docs/relay-phase3-documented-items.md`.

### Why the stack is sound despite these
The convergence in (1)+(3) — two independent state-of-the-art provers blocked by the same inline-assembly
storage modeling — is itself the finding: it validates the chosen strategy. Halmos works because it
symbolically *executes* the real bytecode (no storage analysis); Lean gives the unbounded guarantee at the
algorithm level (no EVM model needed); the bridge + the assumptions connect them. The deployed contract's
security-critical surface is machine-checked; the residuals are unbounded-N *over raw assembly storage*,
which is incremental assurance over an already-strong, multi-tool stack.

## 6. Document index

- `docs/relay-fv.md` — Phases 1–2 (P1–P8 + bounded cross-epoch/monotonicity), modeling contract detail.
- `docs/relay-phase3-plan.md` — Phase-3 plan + the live per-obligation verified-status table.
- `docs/relay-assembly-review.md` — assembly mutation surface / memory / arithmetic review (Step 2).
- `docs/relay-phase3-documented-items.md` — assumption-class obligations + deferred-item resolutions.
- `docs/relay-t1-bridge.md` — the model↔bytecode bridge (T1) analysis.
- `docs/relay-gapB-bytecode-refinement.md` — the bytecode-level ∀N refinement foundation + plan.
- `certora/README.md` — Certora specs, cloud-run result, and the assembly-wall diagnosis.
- `.claude/skills/kontrol-fv/SKILL.md` — the reusable FV methodology.
