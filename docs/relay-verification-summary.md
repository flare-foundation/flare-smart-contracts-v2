# Relay formal-verification summary

The current verification target, claims, assumptions, residual weaknesses, and
reproduction commands are maintained in
[`relay-verification/`](relay-verification/00-README.md).

Use these entry points:

- [`CURRENT-STATUS.md`](relay-verification/CURRENT-STATUS.md) defines when the
  generated evidence applies to the current source and manifest.
- [`10-claims-ledger-trust-and-residual.md`](relay-verification/10-claims-ledger-trust-and-residual.md)
  maps each claim to its exact artifact and assumption boundary.
- [`11-reproducibility.md`](relay-verification/11-reproducibility.md) contains the
  clean-checkout reproduction procedure.
- [`relay-security-review.md`](relay-security-review.md) records current security
  findings that constrain the interpretation of every proof.

Mutable commit identifiers, proof counts, and job results are intentionally not
copied into this summary. The verification manifest and normalized JSON reports
are the machine-readable sources of truth.
