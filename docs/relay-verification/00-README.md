# Verifying `Relay.sol`

This directory is the current tutorial, audit trail, and reproduction guide for
formal verification of
[`Relay.sol`](../../contracts/protocol/implementation/Relay.sol).

The documentation describes only the implementation and proof artifacts present
in this tree.

## Normative inputs

The verification claim is defined by these versioned inputs:

1. [`Relay.sol`](../../contracts/protocol/implementation/Relay.sol), the target;
2. [`verification-manifest.json`](../../test-forge/fv/verification-manifest.json),
   the compiler/toolchain pins and exact proof inventory;
3. the harnesses and Lean/Certora specifications referenced by the manifest;
4. the committed optimized-Yul and sequential-storage-layout baselines selected by the
   manifest; and
5. the normalized reports generated under `verification-reports/`.

Prose is explanatory. If prose disagrees with the manifest or a normalized
report, the machine-readable artifact controls.

## Evidence rule

A report applies to the current source only when it:

- has `status: pass`;
- binds the current manifest hash and repository commit;
- was produced by the required in-process verifier mode;
- began and ended on the same clean Git state; and
- has `release_eligible: true`.

The aggregate bundle enforces these conditions across all required reports. A
dirty-tree or imported-input run is useful during development but cannot be
described as release evidence. See [`CURRENT-STATUS.md`](CURRENT-STATUS.md).

## Reading paths

| Reader | Suggested path |
| --- | --- |
| Security reviewer | [Current security review](../relay-security-review.md) → [claims ledger](10-claims-ledger-trust-and-residual.md) → [status](CURRENT-STATUS.md) |
| Engineer | [big picture](01-big-picture.md) → [strategy](02-strategy-and-the-fidelity-ladder.md) → [reproduction](11-reproducibility.md) |
| Formal-methods reviewer | [Halmos](04-R2-bounded-symbolic-halmos.md) → [Lean](06-R4a-abstract-proof.md) → [refinement](07-R4b-bytecode-refinement.md) → [mathematics](08-the-mathematics.md) |
| Auditor | [audit trail](AUDIT-TRAIL.md) → [claims ledger](10-claims-ledger-trust-and-residual.md) → [residual weaknesses](13-residual-weaknesses.md) |

[`CONCEPTS.md`](CONCEPTS.md) is a compact glossary for SMT, symbolic execution,
reachability controls, refinement, and proof assumptions.

## Current proof layers

| Layer | Verified object | Quantification | Role |
| --- | --- | --- | --- |
| Foundry | compiled contract | concrete and fuzzed executions | behavioral and regression foundation |
| Halmos | compiled FV bytecode | all symbolic inputs within explicit loop/shape bounds | bounded security properties and reachability |
| Lean abstract model | signature accounting algorithm | all voter and signature-list lengths | unbounded arithmetic theorem |
| Lean + EVMYulLean | modeled Yul/EVM loop components | unbounded within stated refinement premises | machine-semantics connection |
| Certora local gate | Solidity/CVL inputs | compilation and typechecking only | exact front-end/configuration validation |
| Certora cloud | submitted CVL jobs | rule-specific | supplemental prover evidence when normalized and complete |

No layer by itself proves that Relay is secure. The combined claim is the
intersection of each artifact's statement, input range, verified object, and
assumptions.

## Load-bearing boundaries

- Increasing indices prevent duplicate **policy slots**, not duplicate signer
  identities. Distinct-voter conclusions require unique nonzero addresses at
  policy admission; the current contract does not establish that invariant on
  every path.
- Cryptographic security of ECDSA and collision resistance of keccak are
  assumptions, not theorems in this repository.
- Halmos is bounded by the manifest's loop and fixture shapes.
- Lean refinement covers the modeled loop and declared composition seams; it is
  not an extraction proof of the complete optimized contract. Its fee layer is
  conditional on the local native-fee path and does not model `oldRelay`
  delegation or ERC-20/SafeERC20 behavior.
- Token-fee conclusions assume a standard exact-transfer ERC-20; fee-on-transfer,
  rebasing, callback, and upgrade behavior of the configured token is outside
  Relay's internal proof model.
- Migration configuration, `oldRelay`, owner behavior, and future upgrade
  implementations are environmental trust boundaries unless a listed property
  says otherwise.
- The committed sequential-storage-layout baseline detects drift in Solidity's
  `storageLayout` output. It excludes ERC-7201 namespaces and transient slots
  and does not prove compatibility of an unknown future implementation.
- Ownership transfer is timelocked, but existing queued operations intentionally
  survive it. Handover requires review and cancellation of unwanted queued
  calldata; queue expiry and owner-generation binding are not current invariants.
- A passing inventory does not discharge correctness edges or environmental
  assumptions outside its property statements.

The precise register is in
[`10-claims-ledger-trust-and-residual.md`](10-claims-ledger-trust-and-residual.md).
