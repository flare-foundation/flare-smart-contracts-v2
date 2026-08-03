# Relay.sol — formal verification summary

> The authoritative, complete write-up is **[`docs/relay-verification/`](relay-verification/00-README.md)**
> (audit + tutorial + reproducibility, all rungs). This file is a brief one-page map; for the claims
> ledger, the assumption register, and reproducibility, use that set.
>
> **GSS boundary (2026-07-26):** Halmos now proves 13 bounded properties of the
> post-recovery GSS signer/action state machines, backed by 2 reachability
> controls and an exact 36-test real-Safe/stateful gate. It does not prove ECDSA,
> canonical source execution, or the complete Safe digest algorithm. Existing
> Certora cloud links predate GSS; the current rules pass only the local
> compile/typecheck gate. See [`gss-governance.md`](gss-governance.md).

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
- **GSS remote-authority model:** a valid Safe-owner threshold signature is the
  remote authorization event; canonical execution by the Safe on Flare is not
  required. Targets are intentionally asynchronous, and the threshold is trusted
  not to sign contradictory or destructive actions. This is an accepted design
  boundary, not a property supplied by the formal tools.

See `docs/relay-assembly-review.md` (mutation surface, no delegatecall/fallback, memory layout) and
`docs/relay-phase3-documented-items.md` (the assumption-class obligations: AC-3, R1/R2, M4, R6/R7).

## 2. The verification stack

| Layer | Tool | What it gives | Scope |
|------|------|---------------|-------|
| Symbolic execution on **real bytecode** | **Halmos** | 26 harnesses / 102 checks (`test-forge/fv/*.t.sol`) | bounded; relay core K≤3/N≤5, GSS at fixed owner shape and exposed post-recovery boundaries |
| Unbounded-in-K via k-induction | **Kontrol/KEVM** | sig-loop weight invariant + random monotonicity (`test-forge/fv/kontrol/`) | ∀K, on a faithful Solidity **model**, N∈{3,5} |
| Unbounded **algorithm** proof | **Lean 4** | sig-loop threshold soundness (`test-forge/fv/lean/RelaySigLoop.lean`) | **∀N ∀K**, abstract algorithm, machine-checked (no `sorry`) |
| Model↔bytecode bridge | **Halmos** | `RelayModelBridgeFV` — real bytecode obeys the Kontrol model's `psAt` invariant | K=1,2,3 |
| Global storage invariants | **Certora** | 8 current rules; 2/2 local configs compile/typecheck (`certora/`) | current GSS cloud proof pending |

## 3. What is proven (by area)

- **Signature/threshold accounting (the core):** accept ⟹ enough distinct registered weight, no
  double-count — tight per-prefix (Halmos `RelaySig*FV`), unbounded-in-K (Kontrol `RelaySigLoopFV`), and
  **∀N∀K** at the algorithm level (Lean). `RelayModelBridgeFV` ties the Kontrol model's invariant to the
  real bytecode at K≤3.
- **The entire relay() epoch decision matrix** (Relay.sol:743–754) — all five gates:
  wrong-epoch (`RelayWrongEpochFV`), delayed-policy (`RelayDelayedPolicyFV`), too-old/finalization-window
  (`RelayFinalizationWindowFV`), threshold-increase (`RelayCrossEpochFV` + `RelayThresholdScalingFV`),
  must-use-new-policy (`RelayMustUseNewPolicyFV`).
- **Access control & lifecycle:** only the setter rotates policy
  (`RelayAccessControlFV`); the constructor fail-closes on the proved baseline
  configuration (`RelayConstructorFV`, incl. L4/RLY-11); threshold consistency
  is checked on the setter path and the **live Mode-1 relay path**
  (`RelayThresholdConsistencyFV`, `RelayModeOneFV`).
- **GSS governance, bounded post-recovery:** distinct ordered owners must exceed
  threshold; owner generations cannot be self-installed by the wrong hash;
  conflicting nonces are consumed once; local fee updates are canonical,
  atomic, target-specific, and globally monotone across delayed rotations
  (`GSSGovernanceFV`). Real-Safe differential and stateful tests cover the
  surrounding digest, execution, and multi-target integration boundaries.
- **Lifecycle:** strict +1 epoch advance + monotonic `lastInitialized` state-effect (`RelayEpochAdvanceFV`);
  random-pointer monotonicity over arbitrary sequences (`RelayRandomMonotonicityFV` + Kontrol
  `RelayRandomMonoFV`).
- **Merkle & randomness:** random value binding (`RelayRandomBindingFV`), proof-element + alignment
  soundness (`RelayMerkleProofFV`), and fold injectivity along a fixed sibling/path sequence
  (`RelayMerkleFoldFV`). Full membership soundness against arbitrary alternate proof sequences and typed
  leaf/internal-node domain separation remains outside that fold harness.
- **Fees:** conservation in `relay()` (`RelayFeeConservationFV`) and `verify()` (`RelayVerifyFeeFV`).
- **Encoding/return/secure-bit:** P3/P5/P6/P8 (`RelayCanonicalityFV`, `RelayIsSecureNormFV`,
  `RelayReturnDiscriminatorFV`, `RelayPolicyHashFV`).

Every harness pairs a positive proof with an **anti-vacuity control** that must produce a counterexample —
so a proof that is trivially/vacuously true is caught. For the multi-step harnesses, that counterexample
also confirms the elaborate setup genuinely reaches acceptance.

## 4. Reproducing

- **Halmos:** `python3 test-forge/fv/verify_fv.py` checks an exact 102-check manifest, exact Halmos exit
  classes, validated reachability models, and zero truncated loops.
- **GSS:** `verify_gss_governance.py` requires 36/36 tests, including 256-run
  differential fuzzing and a 16,384-call state machine; the production rehearsal
  deploys exact Safe v1.3.0 release artifacts.
- **Source Safe:** `node scripts/verify-gss-source-safe.js` checks 20 fixed-block
  facts, including code hashes, owners, threshold, nonce, modules, guard, and
  fallback handler. Refresh the snapshot before deployment.
- **Artifact parity:** `verify_relay_artifact.py` binds the pinned FV build and optimized Yul to the
  Hardhat deployment artifact after stripping only Solidity CBOR metadata.
- **Kontrol:** the pinned Docker `run.sh` emits JUnit and `verify_kontrol.py` checks all 9 proofs + 4 controls.
- **Lean:** `verify_lean.py` checks the abstract proof plus all eight refinement files, the exact
  EVMYulLean commit/toolchain, source holes, declared axioms, and 165 `#print axioms` results.
- **Certora:** `verify_certora_local.py` checks the pinned 8.16.1/Java 21/solc
  front end and two configs; `certoraRun ...` with `CERTORAKEY` is still required
  for a proof verdict.
- **Evidence:** `verify_bundle.py` requires eight passing, commit/manifest-bound
  reports and rejects dirty release trees by default.

## 5. Honest limits (what is NOT proven, and why)

1. **Global all-functions/all-sequences storage invariants.** On the pre-GSS
   source, the epoch/setter/hash/root rules were cloud-proven for every function
   except `relay()` (legacy codegen also covered `setSigningPolicy`, which
   via-ir excepted). The current CVL replaces the deleted fee nonce with
   four GSS storage rules and has not yet been cloud-proved. Both current configs
   pass the pinned local compilation/typecheck gate. On
   `relay()` itself the historical model was vacuous (visible no-coverage, not
   false alarms); its storage behavior remains covered by per-sequence Halmos
   proofs and the Lean literal model. Run matrix and current status:
   `certora/README.md`.
2. **Bytecode-level ∀N refinement** — the EVMYulLean files are hole-free and the memory/window/overflow
   layers are substantially discharged, but the literal and early-return capstones still take execution,
   `ValidRun`, and acceptance facts as hypotheses. The model is now hash-bound to freshly generated Yul;
   whole-program accepted-execution refinement remains open. See
   `test-forge/fv/lean/bytecode-refinement/` and `docs/relay-verification/07-R4b-bytecode-refinement.md`.
3. **Full symbolic-N in Kontrol** — empirically state-explosive; mitigated by verified N∈{3,5} + the Lean
   ∀N proof + the bounded model↔bytecode bridge. Detail: `docs/relay-phase3-documented-items.md`.
4. **GSS is authorization, not source consensus.** This is an accepted current
   design choice: threshold-signed calldata can remain remotely valid after source
   failure/cancellation, removed owners remain valid on lagging targets,
   same-nonce conflicts are first-delivery-wins, and an extreme future nonce can
   exhaust fee updates. These behaviors require threshold action or asynchronous
   target lag, not an unprivileged threshold bypass. Acceptance depends on the
   signing, rotation, migration, and single-authoritative-Relay controls in
   [`gss-governance.md` section 16](gss-governance.md#16-accepted-design-risks-and-alternatives).
   That section also details stronger alternatives, including source execution
   proofs, signed deployment domains, nonce bounds, per-protocol sequencing, and
   recoverable owner transitions.

### Why the stack is sound despite these
The convergence in (1)+(3) — two independent state-of-the-art provers blocked by the same inline-assembly
storage modeling — is itself the finding: it validates the chosen strategy. Halmos works because it
symbolically *executes* the real bytecode (no storage analysis); Lean gives the unbounded guarantee at the
algorithm level (no EVM model needed); the bridge + the assumptions connect them. The signing-policy
accounting core and bounded GSS state transitions are machine-checked at their stated scopes. The
remaining model, cryptographic, source-execution, and cloud-proof boundaries are explicit rather than
folded into an overbroad whole-contract claim.

## 6. Document index

- `docs/relay-fv.md` — Phases 1–2 (P1–P8 + bounded cross-epoch/monotonicity), modeling contract detail.
- `docs/relay-phase3-plan.md` — Phase-3 plan + the live per-obligation verified-status table.
- `docs/relay-assembly-review.md` — assembly mutation surface / memory / arithmetic review (Step 2).
- `docs/relay-phase3-documented-items.md` — assumption-class obligations + deferred-item resolutions.
- `docs/relay-t1-bridge.md` — the model↔bytecode bridge (T1) analysis.
- `docs/relay-verification/` — the authoritative full ladder (audit + tutorial + reproducibility), incl. the completed bytecode-level ∀N refinement.
- `test-forge/fv/lean/bytecode-refinement/` — the bytecode-level ∀N refinement proof + README.
- `certora/README.md` — Certora specs, the discharged run matrix, and the `relay()` residual.
- `.claude/skills/kontrol-fv/SKILL.md` — the reusable FV methodology.
