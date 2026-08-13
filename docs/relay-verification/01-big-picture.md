# Relay verification: the big picture

## What Relay decides

Relay accepts a source-domain message when signatures associated with an active
signing policy contribute weight strictly greater than the applicable threshold.
Depending on the message mode, an accepted call can:

- finalize a protocol Merkle root;
- bind and store a random number proven under that root;
- install the next signing policy; or
- attest to a consumer-defined digest.

For a finalized local Merkle root, `verify()` also enforces the configured fee
branch: native coin is forwarded and excess is refunded when `feeToken == 0`;
otherwise `msg.value` must be zero and an exact configured ERC-20 amount is
pulled from a non-exempt caller after proof validation.

The security-critical computation is implemented largely in inline assembly. It
parses calldata, chooses a policy and threshold, verifies an ordered signature
stream, accumulates weight, checks message-specific conditions, and writes state.

## The central accounting property

Let `weights[i]` be the weight of policy slot `i`. If accepted signature indices
are strictly increasing, no slot is counted twice. The desired accounting claim
is:

```text
acceptance implies sum(weights at accepted indices) > effective threshold
```

This is a policy-**slot** theorem. It becomes a distinct-signer theorem only if
policy admission guarantees that each nonzero address occurs once. The current
security review treats that admission invariant as an open issue.

## Why several tools are used

The verification problem has two independent dimensions:

- **implementation fidelity** — does the property hold for the compiled
  assembly-heavy contract; and
- **input generality** — does it hold for arbitrary policy and signature-list
  lengths rather than a fixed unrolling bound.

Bytecode symbolic execution gives high implementation fidelity but must bound
loops. Mathematical induction removes the length bound but reasons about a
model. The verification stack uses both and records the connection between them
as a separate refinement claim.

## What a passing bundle means

A release-eligible bundle means that all manifest-required gates passed against
the same clean source revision, manifest, compiler settings, and generated
artifact. It establishes only the claims actually listed in the manifest and
claims ledger.

It does not establish:

- ECDSA unforgeability or keccak collision resistance;
- unique voter identities when policy admission permits duplicates;
- correctness of arbitrary future upgrades;
- correctness of consumer-defined custom-message semantics;
- availability under every valid quorum-signed future input; or
- safe migration when independently supplied metadata is inconsistent;
- exact fee delivery by a token that violates the standard exact-transfer ERC-20
  assumption; or
- storage compatibility of an arbitrary future UUPS implementation.

This version defines the first-deployment sequential Solidity storage baseline.
Artifact parity detects changes to that compiler-visible `storageLayout` output;
ERC-7201 namespaces and transient slots are outside the snapshot, and no
proxy-storage migration is part of the current deployment model.

The current open risks are documented in
[`../relay-security-review.md`](../relay-security-review.md).
