# Relay owner governance and deterministic deployment

This document describes the current Relay governance, upgrade, and deployment
model. Security limitations are recorded in
[`relay-security-review.md`](relay-security-review.md).
Normative finalization, verification-fee, and randomness behavior is documented
in [`specs/FSP/Finalization.md`](specs/FSP/Finalization.md) and
[`specs/FSP/RandomNumber.md`](specs/FSP/RandomNumber.md); this file is the
owner/deployment/upgrade runbook.

## 1. Governance authority and timelock

Every Relay proxy has one per-chain owner. The owner operates Relay through
[`OwnableWithTimelock`](../contracts/utils/implementation/OwnableWithTimelock.sol).

For a method protected by `onlyOwnerWithTimelock`:

- with a zero duration, the owner's call executes immediately;
- with a nonzero duration, the owner's call queues the exact calldata and emits
  `CallTimelocked` without applying the requested change;
- after the ETA, anyone may execute that exact calldata through
  `executeTimelockedCall`;
- execution is one-shot after success; a reverted execution leaves the queue
  entry available;
- re-queuing identical calldata restarts its delay;
- only the owner may cancel a queued call; and
- queuing with value is rejected because execution replays a zero-value
  self-call.

The timelock duration is itself timelocked and capped at seven days.
`renounceOwnership` is disabled; ownership moves atomically through
`transferOwnership`.

Queued entries are keyed by calldata and timestamp. They are not bound to an
owner generation or implementation generation and do not expire. Before an
ownership transfer or implementation change, enumerate and cancel every queued
operation that must not remain executable.

## 2. Owner-controlled Relay surface

The owner/timelock controls:

| Method | Available mode | Effect |
| --- | --- | --- |
| `setProtocolFees(address,FeeConfig[])` | relay mode | replaces the complete fee configuration — the fee token (zero = native coin) and the entire per-protocol fee table — in one atomic call |
| `setFeeExemptions(FeeExemption[])` | relay mode | grants or revokes account fee exemptions |
| `setFeeCollectionAddress(address)` | relay mode | changes the nonzero fee recipient |
| `setSigningPolicySetter(address)` | setter mode | changes the trusted nonzero signing-policy setter |
| `upgradeToAndCall(address,bytes)` | both | upgrades the UUPS implementation and optionally runs migration calldata |

`setProtocolFees` is a full replace: the previous fee table is cleared before the
supplied one is applied, so a protocol not listed in the call is free (fee 0)
afterwards, and fees can never be silently carried over as amounts in a different
denomination after a token switch. Every listed protocol ID must be greater than
`1`, unique (`DuplicateProtocolId`), and paired with a nonzero fee
(`ProtocolFeeZero`) — a free protocol is expressed by omission. Each call (and each
relay-mode initialization) emits one self-contained `ProtocolFeesSet(feeToken,
feeConfigs)` event whose latest occurrence fully describes the current fee state.
The configured token must be a standard exact-transfer ERC-20 with conventional
`transferFrom` behavior. Fee-on-transfer and rebasing tokens are unsupported,
and callers need sufficient balance and allowance. The live table is enumerable
via `getFeeConfigs()`.

Deployment mode is immutable:

- **setter mode** configures a nonzero signing-policy setter and does not permit
  Relay verification-fee administration; and
- **relay mode** has no signing-policy setter and permits fee configuration and
  exemptions.

Initialization and every owner setter fail closed when used in the wrong mode.

## 3. UUPS upgrade semantics

[`RelayProxy`](../contracts/protocol/implementation/RelayProxy.sol) is an ERC-1967
proxy and Relay is its UUPS implementation. Relay overrides
`upgradeToAndCall` with `onlyOwnerWithTimelock`; `_authorizeUpgrade` contains no
second authorization check because the public entry is the guarded operation.

With a nonzero timelock, the exact implementation address and migration calldata
are queued together. Execution occurs as a proxy self-call. A migration function
that must be callable from `upgradeToAndCall` must explicitly support that
self-call context without opening an arbitrary external route.

An upgrade can change every Relay security property. Review storage layout,
initializer/reinitializer guards, owner/timelock behavior, and the formal proof
target before queueing it.

### Current sequential storage baseline

This version is the first-deployment sequential Solidity storage baseline. Relay
proxies initialize this layout directly; deployment includes no proxy-storage
migration. The optional `oldRelay` is a read-delegation source and does not
populate or mutate the current proxy's storage.

The artifact-parity gate recompiles Relay with the manifest-pinned compiler,
normalizes its compiler-emitted sequential Solidity storage layout, and compares
it with
[`relay_storage_layout.json`](../test-forge/fv/relay_storage_layout.json). A
future slot, offset, declaration-order, or type change in that layout fails the
gate until the baseline is deliberately updated after compatibility review.
The snapshot does not enumerate state addressed through ERC-7201 namespace
constants, including OpenZeppelin `Initializable`, or EIP-1153 transient slots.
Those require separate review. This guard detects scoped layout drift; it does
not prove that an unknown future implementation is upgrade-compatible.

## 4. Atomic initialization

The proxy constructor invokes `Relay.initialize` atomically, so the proxy is not
externally observable in an uninitialized state. Initialization fixes:

- source chain/domain;
- initial reward-epoch and voting-round anchors;
- nonzero initial signing-policy hash;
- setter or relay operating mode;
- fee configuration, fee token, and exemptions where permitted;
- owner and timelock duration; and
- optional `oldRelay` migration configuration where permitted.

For migration, the complete initial policy supplied to finalizers must encode the
same start round as the initialization read boundary. The current contract stores
the policy hash and boundary independently, so deployment tooling and review must
enforce this equality.

## 5. Chain-invariant proxy address

Relay uses a deterministic three-stage deployment path:

1. the canonical keyless CREATE2 deployer installs
   [`Create3Factory`](../contracts/utils/implementation/Create3Factory.sol) from
   frozen initcode and salt;
2. `Create3Factory` derives a deployer-scoped, source-scoped salt; and
3. the factory deploys the Relay proxy at the address determined by factory,
   designated deployer, and source-chain identity.

The resulting address is independent of target-chain ID, implementation address,
and initializer bytes. Every mirror of one source can therefore use the same
Relay address, while different source networks receive different address
namespaces.

The designated deployer controls the official address on chains where the proxy
has not yet been deployed. Protect that key and verify it against the source
configuration before broadcast.

## 6. Deployment and migration procedure

### Configuration

Relay deployment configuration is stored per source under
[`deployment/chain-config/relay/`](../deployment/chain-config/relay/README.md).
Each source entry defines home settings and a map of mirror targets. The scripts
enforce the designated deployer, source identity, target chain ID, owner,
timelock, fee settings (including the per-mirror fee token), and
deterministic address inputs.

### Home deployment

The home script reads protocol addresses from the on-chain registry and deploys
setter mode with the current systems manager as signing-policy setter. It
reconstructs the complete initial policy from source-chain state and verifies
that reconstruction against the source Relay's stored commitment before
computing the canonical target commitment:

```text
keccak256(sourceChainId || encodedSigningPolicy)
```

The deployment is valid only while the policy selected as the target initial
epoch is already available from source state and has not become stale for the
target initializer. Run the script's preflight immediately before broadcast.

### Mirror deployment

`PrepareRelaySourceSnapshot` captures the source-domain policy commitment and
epoch anchors. `DeployRelayMirror` checks that the snapshot identifies the
configured source, that the live target chain matches its mirror entry, and that
relay mode does not configure `oldRelay` or a signing-policy setter.

### Required post-deployment checks

Before publishing the address or switching consumers, compare the deployment
manifest and on-chain getters for:

- proxy and implementation address;
- owner and timelock duration;
- source chain ID;
- operating mode and signing-policy setter;
- initial reward epoch, policy hash, and start round;
- fee recipient, fees, fee token, and exemptions; and
- deterministic salt/factory/deployer inputs.

The manifest records the complete fee surface — recipient, token, fee table and
exemption list — and the mirror deploy script additionally asserts each of these
against the live contract before writing it.

Also reveal the complete initial policy off-chain and independently confirm:

- canonical encoding and source-domain hash;
- unique nonzero voters;
- positive bounded weights and valid threshold;
- monotonic start metadata; and
- equality between the policy start and migration read boundary.

### Digest and consumer cutover

All signers, finalizers, and consumers must switch atomically to the canonical
source-domain digest at the configured voting-round boundary. For FDC/TEE paths:

- deploy signer/enclave software that computes the canonical digest;
- repoint Relay references to the new proxy;
- upgrade any consumer whose bytecode inlines the digest library; and
- regenerate signatures/proofs created for a different digest.

Consumers that delegate digest verification to Relay need only the Relay pointer
change. Consumers containing an `internal` digest helper need new bytecode.

### Randomness continuity

Do not switch a consumer that requires live randomness until the target Relay
has a verified local current random or the consumer implements an explicit
trusted fallback. Delegation for rounds below the `oldRelay` boundary does not
make `getRandomNumber()` continuous by itself.

## 7. Verification and tests

The current behavior is exercised by:

- [`RelayOwnableWithTimelock.t.sol`](../test-forge/unit/governance/RelayOwnableWithTimelock.t.sol);
- [`RelayUpgrade.t.sol`](../test-forge/unit/governance/RelayUpgrade.t.sol);
- [`Relay.t.sol`](../test-forge/unit/protocol/implementation/Relay.t.sol);
- [`RelayDeployAddress.t.sol`](../test-forge/unit/deployment/RelayDeployAddress.t.sol);
- [`RelayDeployFlow.t.sol`](../test-forge/unit/deployment/RelayDeployFlow.t.sol); and
- [`RelayConfigParsing.t.sol`](../test-forge/unit/deployment/RelayConfigParsing.t.sol).

Formal owner/timelock/UUPS claims and their limitations are listed in
[`relay-verification/10-claims-ledger-trust-and-residual.md`](relay-verification/10-claims-ledger-trust-and-residual.md).
Use [`relay-verification/CURRENT-STATUS.md`](relay-verification/CURRENT-STATUS.md)
to determine whether current normalized evidence is release-qualified.
