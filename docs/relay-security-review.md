# Relay security review

## Scope and verdict

This review covers the current implementation of
[`Relay.sol`](../contracts/protocol/implementation/Relay.sol). Inherited owner,
timelock, proxy, and `oldRelay` read-delegation behavior is considered only where
it changes the security of Relay.

Normative protocol behavior is in
[`specs/FSP/Finalization.md`](specs/FSP/Finalization.md); owner and deployment
operations are in [`relay-governance.md`](relay-governance.md). This document
records findings, assumptions, impact, and remediation rather than redefining
those interfaces.

No unconditional permissionless Critical or High vulnerability was identified.
The contract nevertheless has one conditional high-impact policy-integrity
failure, two quorum/migration state-machine failures, and lower-severity
availability and integration risks. These findings are part of the current
security boundary and must not be hidden by a passing formal-verification gate.

| ID | Severity | Finding | Required capability or condition |
| --- | --- | --- | --- |
| RLY-SEC-01 | Conditional High | Duplicate voter identities can contribute multiple policy-slot weights | A malformed policy is admitted |
| RLY-SEC-02 | Medium | A terminal future random round can freeze the live-random pointer | An increased-threshold quorum signs the value |
| RLY-SEC-03 | Medium/Low | Initial-policy start metadata can disagree with the migration read boundary | Inconsistent initialization inputs |
| RLY-SEC-04 | Low | Current randomness is discontinuous across an `oldRelay` cutover | Consumers switch before a local random is finalized |
| RLY-SEC-05 | Low | Zero-total-weight policies are accepted but cannot finalize | A malformed policy is admitted |
| RLY-SEC-06 | Low | Nonmonotonic policy starts can preserve overlapping policy authority | A malformed policy sequence is admitted |
| RLY-SEC-07 | Low | Queued privileged calls survive owner and implementation changes | A call was queued before the change |
| RLY-SEC-08 | Informational | A secure random finalized at voting round zero is reported insecure by the live getter | The first valid round is zero |
| RLY-SEC-09 | Informational | Token-fee accounting assumes exact-transfer ERC-20 semantics | The owner configures a fee-on-transfer, rebasing, callback-capable, or otherwise nonstandard token |

Severity is conditional on the stated prerequisite. A trusted setter, a valid
quorum, or a migration operator is not treated as an arbitrary attacker; the
finding records how an input error or partial compromise can exceed the intended
invariant.

## RLY-SEC-01 — duplicate voter identities count more than once

The signature loop prevents reuse of a policy **index** by requiring strictly
increasing indices. It does not prevent several indices from containing the same
address. The same canonical signature can therefore satisfy each duplicate
entry, and Relay adds every indexed weight.

For example, a policy with voters `[A, A, C, D, E]`, weights
`[150, 150, 67, 67, 66]`, and threshold `260` can be finalized by repeating
`A`'s signature at indices 0 and 1. The accumulated policy-slot weight is 300,
but only one distinct key signed.

The affected admission paths are:

- the initial policy, represented only by an opaque hash at initialization;
- `setSigningPolicy`, which trusts the configured setter; and
- policy rotation through `relay()` mode 1.

Impact includes finalizing arbitrary protocol and random roots, approving a
custom message, and installing a subsequent signing policy once a malformed
policy is active.

Required remediation: validate every complete policy before it becomes active.
Require a nonzero, unique address for each voter, a positive bounded total
weight, and valid threshold metadata. Runtime recovered-address deduplication is
useful defense in depth for policies admitted through a hash-only interface.

## RLY-SEC-02 — terminal future random freezes the live pointer

Relay rejects stale signed messages but permits arbitrarily far-future voting
rounds after applying the increased future-message threshold. A random message
for `type(uint32).max` can therefore be finalized by a sufficiently large valid
quorum.

The live random pointer advances monotonically. Once it reaches the terminal
round, no later `uint32` round can replace it. In addition, the live getter adds
one to the stored `uint32` before widening to `uint256`, so the getter reverts on
the terminal value.

Required remediation:

- impose a small time-derived future horizon;
- reject `type(uint32).max` explicitly;
- widen before arithmetic; and
- verify the invariant that every accepted live pointer is readable and can be
  superseded by a later representable round.

## RLY-SEC-03 — migration write and read partitions can overlap or gap

Initialization stores an opaque initial-policy hash and a separate
`startingVotingRoundIdForInitialRewardEpochId`. The policy bytes supplied later
to `relay()` carry their own start round. The encoded start controls whether a
message may be finalized locally; the initialization value controls whether
read functions consult local storage or `oldRelay`.

If the encoded policy start is lower than the read boundary, Relay can finalize
a root locally and then hide it behind delegation to `oldRelay`. If it is
higher, an interval can exist in which the intended policy cannot finalize a
root. The implementation does not establish equality between the two values.

Required remediation: initialize from the complete policy, validate it, derive
the read boundary from its metadata, and compute the canonical hash on-chain.
At minimum, require equality when the initial policy is revealed.

## RLY-SEC-04 — current randomness is not migrated

Reads below the migration boundary delegate to `oldRelay`. The live
`getRandomNumber()` path always reads local state. Immediately after cutover it
therefore reports a predictable zero with `isSecure = false` until a local
random root is finalized.

Consumers that correctly require `isSecure` can become unavailable. Consumers
that discard the flag can use predictable input.

Required remediation: delegate the live getter until local current-random state
exists, or seed a verified snapshot atomically during migration. Registry
cutover must not precede continuity of the live random value.

## Lower-severity state and governance findings

### RLY-SEC-05 — unusable zero-weight policy

A nonempty policy whose weights and threshold are all zero satisfies the current
threshold-band checks. Finalization remains impossible because acceptance uses
a strict `weight > threshold` comparison. Require a positive total weight and,
preferably, a positive weight for every admitted voter.

### RLY-SEC-06 — policy starts are not monotonic

The implementation assumes that start rounds are nondecreasing across reward
epochs but does not enforce that assumption. A lower later start can leave an
older quorum valid over rounds also covered by a newer policy. Require monotonic
starts or make the invariant an explicit, machine-checked property of every
admission path.

### RLY-SEC-07 — queued calls outlive authority changes

The timelock queue key binds calldata and its execution timestamp. It does not
bind the owner generation, implementation generation, or an expiry. A call
queued by the current owner remains permissionlessly executable after ownership
transfer unless the new owner identifies and cancels it.

Bind queued operations to an authority/implementation generation, invalidate
the generation on transfer or upgrade, and give operations a finite execution
window.

### RLY-SEC-08 — round-zero security disagreement

The live random pointer updates only when the accepted round is strictly greater
than its zero-initialized value. A valid secure random at round zero is stored in
the per-round mappings, but the live security flag remains false. Use an explicit presence
bit, or update the pointer when the first local random is stored.

### RLY-SEC-09 — token-fee accounting trusts token semantics

In token mode, `verify()` uses `SafeERC20.safeTransferFrom` after successful
Merkle verification. SafeERC20 checks call success and supported return
conventions; Relay does not measure the collector's balance delta. A
fee-on-transfer or rebasing token can therefore deliver an amount different
from `protocolFee[protocolId]`, and a callback-capable or adversarial token can
add availability and reentrancy behavior outside Relay's internal model.

Configure only a reviewed, standard exact-transfer ERC-20. Treat the token
contract and its upgrade authority as part of Relay's trusted environment.
Changing the token and fee table in one owner-timelocked full-replace call avoids
mixed denominations, but does not validate the selected token's semantics.

## Integration boundary for custom messages

`verifyCustomSignature` is intentionally stateless. A valid signature set can be
reused anywhere that interprets the same message hash and source domain. Every
consumer must bind, in the signed preimage:

- the destination chain and consuming contract;
- the operation or protocol purpose;
- a nonce or unique request identifier;
- an expiry or freshness condition; and
- any policy epoch or threshold semantics required by that consumer.

Relay proves only that the submitted digest has enough accepted policy-slot
weight under its selected policy. It does not supply consumer replay protection.

## Reviewed mechanisms with no additional finding

The current source-domain single-keccak encoding is structurally unambiguous:
the source prefix is fixed-width, protocol messages are fixed-width, and signing
policy length is determined by voter count. The high-level and assembly signing
policy encoders use the same byte layout.

The ECDSA gate checks canonical `v`, low `s`, successful precompile execution,
exact 32-byte return data, a nonzero signer, the selected voter address, and
strictly increasing policy indices. Those checks do not address duplicate
addresses in the policy itself.

The transient protocol-1 threshold override is selected only for protocol 1,
uses the strict comparison consistently, clears on success, and is rolled back
with the call frame on revert. No callback window was identified between setup
and consumption.

The current UUPS surface exposes no unguarded upgrade route: the public upgrade
entry is timelocked and proxy-context checks remain active. This conclusion does
not cover the semantics of a future implementation selected by the owner.

This version is the first-deployment sequential Solidity storage baseline and
requires no proxy storage migration. The artifact gate compares the pinned
compiler's normalized `storageLayout` output with the committed baseline so an
unreviewed sequential slot, order, offset, or type change fails. The snapshot
does not enumerate ERC-7201 namespaced state, including OpenZeppelin
`Initializable`, or EIP-1153 transient slots. That scoped drift check is not a
proof that future implementation code is storage-compatible.

## Formal-verification consequence

The formal claims must preserve the distinction between unique policy slots and
unique signer identities. A proof that constructs voter addresses as distinct,
assumes positive weights, restricts rounds to an ordinary bounded range, or
aligns migration boundaries has assumed away the corresponding finding.
Lean's fee layer covers only the native-coin branch; token-fee claims require
compiled-bytecode or CVL evidence and retain the standard exact-transfer token
assumption.

Required proof obligations and counterexample regressions are listed in
[`relay-verification/10-claims-ledger-trust-and-residual.md`](relay-verification/10-claims-ledger-trust-and-residual.md).
The evidence status is defined by
[`relay-verification/CURRENT-STATUS.md`](relay-verification/CURRENT-STATUS.md),
not by prose pass counts in this document.
