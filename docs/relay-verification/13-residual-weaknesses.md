# Residual weaknesses and attack surface

This page is the current residual-risk index. Detailed impact and remediation are
in [`../relay-security-review.md`](../relay-security-review.md); exact proof gaps
are in [`10-claims-ledger-trust-and-residual.md`](10-claims-ledger-trust-and-residual.md).

## Correctness edges and conditional invariants

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
8. **Timelock lifecycle.** Ownership transfer is delayed when the timelock is
   armed, but unrelated queued calls intentionally survive transfer, are not
   automatically invalidated by a compatible implementation change, and have
   no expiry. Operational handover must review and cancel unwanted calls; the
   proof must not assume an owner-generation invalidation rule.

Policy identity, viability, ordering, and migration partition checks are
trusted-admission/configuration requirements. Their absence from every Relay
entry point does not establish a permissionless authorization bypass. The
security review distinguishes these assumptions from the terminal-round and
round-zero correctness edges.

## Environmental and integration residuals

- Custom-message consumers must supply their own destination, purpose, nonce,
  and freshness domain. An accepted policy epoch is not a signature timestamp;
  signatures can remain eligible under a later policy with sufficient retained
  signing weight.
- ECDSA and keccak security are trusted cryptographic assumptions.
- `oldRelay`, the configured owner, signing-policy setter, fee recipient, and
  future implementation are trusted within their documented capability.
- Cancun/EIP-1153 support is a deployment prerequisite for paths that execute
  transient-storage opcodes.
- Value-transfer recipients can cause availability failures by reverting.
- Token-fee correctness assumes a reviewed standard exact-transfer ERC-20.
  Fee-on-transfer, rebasing, callback-capable, adversarial, or later-upgraded
  token behavior is outside the transfer claim.

## Formal-method residuals

- Halmos proofs cover manifest-declared bounded shapes.
- Lean's distinct-signer interpretation depends on unique policy addresses.
- Lean's fee layer covers only local native-coin verification; delegated and
  token value-flow claims come from bounded compiled-bytecode/CVL evidence
  under their stated assumptions.
- The EVM/Yul refinement is conditional on declared setup and composition
  premises and the pinned semantics. Its literal accepting-execution bridge is
  unverified: the pinned Yul `STATICCALL` handler does not dispatch the
  address-1 precompile and clears caller calldata on an ordinary-account
  return. Recovery-output premises do not establish that this call is
  executable with Relay's required caller frame. See
  [open gap RLY-FV-GAP-01 and its closure criteria](07-R4b-bytecode-refinement.md#open-gap-rly-fv-gap-01-recovery-call-execution).
- solc's Yul-to-bytecode lowering is not verified unboundedly; artifact parity
  and bounded bytecode execution narrow this seam.
- Certora local evidence is front-end validation only. Cloud claims require a
  current normalized complete job set.
- Formal verification covers stated properties, not the absence of all bugs.
- The committed sequential-storage-layout comparison detects compiler-emitted
  drift from the first-deployment baseline. ERC-7201 namespaces and transient
  slots are outside it, and it does not prove future upgrade compatibility.

## Release interpretation

A passing formal bundle does not waive any item above. Release review must either
remove the corresponding contract/integration risk or explicitly accept it with
the exact assumption retained in the claims ledger.
