# Residual weaknesses and attack surface

This page is the current residual-risk index. Detailed impact and remediation are
in [`../relay-security-review.md`](../relay-security-review.md); exact proof gaps
are in [`10-claims-ledger-trust-and-residual.md`](10-claims-ledger-trust-and-residual.md).

## Contract invariants not established on every input path

1. **Voter identity uniqueness.** The loop proves no policy-slot reuse, while
   policy admission can represent the same address in several slots.
2. **Policy viability.** A nonempty zero-total-weight policy can satisfy the
   metadata checks but can never exceed its threshold.
3. **Policy-start ordering.** Nondecreasing starts are assumed rather than
   enforced.
4. **Migration partition equality.** Initial policy bytes and the read-delegation
   boundary are configured independently.
5. **Random pointer liveness.** Monotonicity does not prevent acceptance of an
   unreadable, terminal future round.
6. **Current-random continuity.** `oldRelay` delegation does not cover the live
   getter before local random initialization.
7. **First-round presence.** Zero-valued initialization state is not enough to
   distinguish absence from an accepted round-zero value/security flag.
8. **Timelock generation binding.** Queued calls survive authority and
   implementation changes and have no expiry.

## Environmental and integration residuals

- Custom-message consumers must supply their own destination, purpose, nonce,
  and freshness domain.
- ECDSA and keccak security are trusted cryptographic assumptions.
- `oldRelay`, the configured owner, signing-policy setter, fee recipient, and
  future implementation are trusted within their documented capability.
- Cancun/EIP-1153 support is a deployment prerequisite for paths that execute
  transient-storage opcodes.
- Value-transfer recipients can cause availability failures by reverting.

## Formal-method residuals

- Halmos proofs cover manifest-declared bounded shapes.
- Lean's distinct-signer interpretation depends on unique policy addresses.
- The EVM/Yul refinement is conditional on declared setup and composition
  premises and the pinned semantics.
- solc's Yul-to-bytecode lowering is not verified unboundedly; artifact parity
  and bounded bytecode execution narrow this seam.
- Certora local evidence is front-end validation only. Cloud claims require a
  current normalized complete job set.
- Formal verification covers stated properties, not the absence of all bugs.

## Release interpretation

A passing formal bundle does not waive any item above. Release review must either
remove the corresponding contract/integration risk or explicitly accept it with
the exact assumption retained in the claims ledger.
