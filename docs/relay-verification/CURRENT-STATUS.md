# Current Relay verification status

## Authority

The current verification target is
[`contracts/protocol/implementation/Relay.sol`](../../contracts/protocol/implementation/Relay.sol).
The exact compiler, toolchain, source, harness, theorem, rule, and ABI inventories
are defined by
[`test-forge/fv/verification-manifest.json`](../../test-forge/fv/verification-manifest.json).
The target includes Relay's native/token fee branches and the current
first-deployment sequential Solidity storage layout. ERC-7201 namespaces and
transient slots are outside the layout snapshot. No proxy-storage migration is
part of this baseline.

This page does not duplicate commit IDs, manifest hashes, report hashes, or proof
counts. Those values change whenever the source or inventory changes and are
recorded in the normalized JSON reports.

## Current evidence rule

The formal-verification package is release-qualified only when
the generated `verification-reports/relay-fv-bundle.json` reports:

```text
status = pass
release_eligible = true
```

and the bundle binds every mandatory constituent to:

- the current Git commit;
- the SHA-256 of the current manifest;
- a clean and unchanged worktree for the duration of every run; and
- the required in-process execution mode and pinned toolchain.

Evidence applies only to the source, manifest, harness, specification, compiler
settings, committed optimized-Yul, and committed sequential storage layout bound
by the relevant reports. Changed inputs require regeneration of every affected
gate. A
report with `release_eligible = false` is development evidence, even when
`status = pass`.

## Required local reports

The bundle validator defines the authoritative list. The current package uses
normalized evidence for:

- production deployment artifact provenance;
- Relay custom-error ABI consistency;
- deployment/FV artifact and optimized-Yul parity;
- compiler-normalized sequential-storage-layout parity against the committed baseline;
- the exact Halmos proof/reachability manifest;
- the Lean theorem and axiom-audit manifest; and
- the Certora local compiler/config/CVL front-end gate.

Certora cloud evidence is supplemental unless the current manifest/bundle makes
it mandatory. It may be described as a proof result only when every submitted
job is current, complete, normalized, and free of disqualifying sanity or solver
outcomes.

## Security interpretation

Even a release-qualified bundle proves only the claims in
[`10-claims-ledger-trust-and-residual.md`](10-claims-ledger-trust-and-residual.md).
The current claim-to-evidence map is
[`AUDIT-TRAIL.md`](AUDIT-TRAIL.md).

The package must model these current implementation boundaries:

- Ownership transfer uses the same owner timelock as the other guarded calls.
  With positive delay it queues first, and the owner changes only on successful
  execution. Unrelated queued calls retain their original ETA after transfer.
- A random-protocol message accepts only security bytes `0` and `1`; every
  other protocol requires `0`. There is no nonzero-byte normalization path.
- Pre-boundary verification requires the configured source's `isFinalized()`
  to return true before delegating `verify()` with zero native value.
- Custom-signature wrappers require the supplied call to select `relay()`;
  inputs shorter than four bytes or different selectors fail with `NotRelayCall`.
  The successful protocol-1 return must still have the expected digest and
  35-byte format.

The security review distinguishes correctness edges from trusted-input and
integration requirements. Terminal-round timestamp arithmetic and first-round-
zero live-state handling remain explicit random-getter limits. Unique policy
identities, usable weights, policy start metadata, migration configuration, and
consumer freshness remain admission or integration assumptions unless a listed
property establishes them. See
[`../relay-security-review.md`](../relay-security-review.md).
Token-mode fee evidence assumes a standard exact-transfer ERC-20, and Lean's
fee model is native-only. A fixture that assumes an input condition proves only
the corresponding conditional claim.

Lean's literal-loop acceptance bridge remains unverified. The pinned Yul
`STATICCALL` handler neither models the address-1 precompile nor preserves
caller calldata on an ordinary-account return. Conditional recovery premises
therefore cannot be read as an established executable precompile model. The
abstract accounting theorem and bounded bytecode checks are separate evidence.
See [`07-R4b-bytecode-refinement.md`](07-R4b-bytecode-refinement.md).

## How to obtain the verdict

Run the clean-checkout procedure in
[`11-reproducibility.md`](11-reproducibility.md), then inspect the aggregate
bundle and its constituent reports. Do not infer status from checked-in prose,
terminal excerpts, CI badges, or a standalone verifier exit code.
