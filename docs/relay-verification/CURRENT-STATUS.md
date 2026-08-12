# Current Relay verification status

## Authority

The current verification target is
[`contracts/protocol/implementation/Relay.sol`](../../contracts/protocol/implementation/Relay.sol).
The exact compiler, toolchain, source, harness, theorem, rule, and ABI inventories
are defined by
[`test-forge/fv/verification-manifest.json`](../../test-forge/fv/verification-manifest.json).

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

Any source, manifest, harness, specification, compiler setting, or committed
optimized-Yul change invalidates earlier reports until all affected gates are
regenerated. A report with `release_eligible = false` is development evidence,
even when `status = pass`.

## Required local reports

The bundle validator defines the authoritative list. The current package uses
normalized evidence for:

- production deployment artifact provenance;
- Relay custom-error ABI consistency;
- deployment/FV artifact and optimized-Yul parity;
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
The current implementation has open security boundaries documented in
[`../relay-security-review.md`](../relay-security-review.md), including duplicate
voter identities, terminal future randomness, migration-boundary mismatch, and
current-random discontinuity. Proof fixtures that assume those inputs are valid
only under the corresponding assumption; they do not close the finding.

## How to obtain the verdict

Run the clean-checkout procedure in
[`11-reproducibility.md`](11-reproducibility.md), then inspect the aggregate
bundle and its constituent reports. Do not infer status from checked-in prose,
terminal excerpts, CI badges, or a standalone verifier exit code.
