# Relay owner governance and deterministic deployment

Status: current design on this branch. This document replaces `docs/safe-governance.md`
(the retired cross-chain Safe-signature governance design; see git history) — the Safe
machinery was removed before any deployment, and Relay governance is now a per-chain
**owner + timelock**. A future governance hub contract can take over by becoming the owner
via `transferOwnership`, with no Relay change.

## 1. Governance model

Every Relay deployment (home and mirror alike) has exactly one governance authority: its
**owner**, held per chain (on Flare-family home deployments the governance multisig read
from `GovernanceSettings.getGovernanceAddress()`; on mirror chains the designated multisig
from the deploy config). The owner administers the deployment through the
[`OwnableWithTimelock`](../contracts/utils/implementation/OwnableWithTimelock.sol) base
([`IOwnableWithTimelock`](../contracts/userInterfaces/IOwnableWithTimelock.sol)), which
[`Relay`](../contracts/protocol/implementation/Relay.sol) inherits:

- **Guarded calls either apply or queue.** Every governance method is annotated
  `onlyOwnerWithTimelock`. With the timelock duration at `0`, an owner call applies
  immediately. With a nonzero duration, the owner's call **queues** the exact calldata
  (hash-keyed) and emits `CallTimelocked`; it applies nothing yet. Callers must read state
  back (or `getExecuteTimelockedCallTimestamp`) rather than assume application.
- **Execution is permissionless after the ETA.** Anyone may call
  `executeTimelockedCall(encodedCall)` once the recorded timestamp passes; it self-calls
  the proxy with the queued calldata and emits `TimelockedCallExecuted`. A failed
  execution reverts atomically, leaving the queue entry live. Re-queueing the identical
  call restarts its delay; distinct queued calls mature independently (cancel superseded
  queues — an older matured intent remains executable).
- **Only the owner cancels.** `cancelTimelockedCall(encodedCall)` removes a queued entry.
- **The duration is self-guarded.** `setTimelockDuration` goes through the same timelock
  and is capped at 7 days. The initial value is deploy-configured
  (`RelayInitialConfig.timelockDurationSeconds`, validated in `initialize`), so a multisig
  owner needs no post-deploy ceremony call.
- **Queued calls must not target another guarded function.** Execution consumes the
  single-use `executing` flag before the target body runs, so a queued payload (e.g. an
  upgrade migration) that internally invokes a second `onlyOwnerWithTimelock` function
  falls through to the queue path and reverts on the owner check. A zero duration takes
  the immediate branch instead — rehearse migrations against a timelocked deployment.
- **Queuing with value reverts** (`TimelockValueNotAllowed`): execution replays only
  calldata via a zero-value self-call, so value sent when queuing would be trapped.
- **`renounceOwnership` is disabled** (`RenounceDisabled`): ownership only moves via
  `transferOwnership` (one step, atomic — the deploy pre-flight's owner checks are the
  guard against a wrong target).

## 2. Owner surface

Declared on [`IIRelay`](../contracts/protocol/interface/IIRelay.sol) (which extends
`IOwnableWithTimelock`); events and public getters on
[`IRelay`](../contracts/userInterfaces/IRelay.sol). All five are `onlyOwnerWithTimelock`:

| Method | Mode | Effect |
|--------|------|--------|
| `setProtocolFees(FeeConfig[])` | relay mode only | Sets `protocolFeeInWei[protocolId]` per entry (`protocolId > 1`); emits `ProtocolFeeSet`. |
| `setFeeExemptions(FeeExemption[])` | relay mode only | Grants/revokes verify() fee exemptions per `(account, exempt)` entry (nonzero accounts); emits `FeeExemptionSet`. |
| `setFeeCollectionAddress(address)` | relay mode only | Points collected fees at a new nonzero recipient (zero would burn fees); emits `FeeCollectionAddressSet`. |
| `setSigningPolicySetter(address)` | setter mode only | Repoints the trusted signing-policy setter (e.g. after a FlareSystemsManager redeployment); emits `SigningPolicySetterSet`. |
| `upgradeToAndCall(address,bytes)` | both | UUPS upgrade through the timelock (see §3). |

Mode is fixed at `initialize` and never changes: a **setter-mode (home)** deployment
(`signingPolicySetter != 0`) charges no verify() fee, so the three fee setters fail closed
there (`FeeConfigNotAllowed` / `FeeExemptionsNotAllowed`), exactly like the `initialize`
seeding rules; a **relay-mode** deployment can never gain a signing-policy setter
(`SigningPolicySetterNotAllowed`) and a setter-mode one can never clear it
(`SigningPolicySetterZero`).

Fee exemptions (e.g. DVN adapter contracts) can additionally be **seeded at deployment**
via `RelayInitialConfig.feeExemptAddresses` (relay mode only), so verifier infrastructure
is exempt from block one with no owner round-trip.

## 3. Upgradeability

Relay is a UUPS proxy ([`RelayProxy`](../contracts/protocol/implementation/RelayProxy.sol),
ERC1967). The upgrade goes through the owner-timelock: `upgradeToAndCall` is overridden
with `onlyOwnerWithTimelock` and `_authorizeUpgrade` is deliberately empty — the guard
must sit on the public entry, because the modifier's queue branch skips only the function
body and a guarded `_authorizeUpgrade` would fall through into OpenZeppelin's upgrade.
With a nonzero duration the exact `(implementation, data)` call is queued and later
executed permissionlessly; only the exact queued calldata executes. Post-upgrade migration
calldata runs as a proxy self-call — guard migration entry points on **owner-or-self**,
never on the timelock (§1).

`Relay.initialize` configures everything in one atomic call (protocol config, the RLY-23
`sourceChainId`, the timelock duration, the per-chain owner) and runs inside the
`RelayProxy` constructor, so the proxy address is never observable uninitialized and no
post-deploy setup exists. The `oldRelay` handshake in `initialize` remains for migrating
legacy non-proxy relays.

## 4. Chain-invariant Relay address

The Relay proxy must live at the SAME address on every chain, including chains added later,
without a front-running or squatting window. Chain of custody:

1. the canonical keyless CREATE2 deployer (`0x4e59b44847b379578588920cA78FbF26c0B4956C`,
   verified live on Flare, Songbird, Coston, Coston2, Ethereum and Base) — anyone can fund
   and broadcast its presigned deployment on a new chain;
2. [`Create3Factory`](../contracts/utils/implementation/Create3Factory.sol) (ownerless,
   permissionless, wraps OpenZeppelin 5.7 `Create3`), deployed through (1) with a fixed
   salt ⇒ identical factory address everywhere; front-running it is harmless
   (byte-identical, no privileged state);
3. the Relay proxy, deployed through the factory under a **deployer-scoped, source-scoped
   salt** (`keccak256(msg.sender, keccak256(base, sourceChainId))`): only the designated
   deployer account can ever mint the official address on a chain where it is not yet
   deployed. The address depends only on (factory, deployer, source chain id) — NOT on the
   target chain, the implementation or per-chain initializer data.

Because the salt is keyed by the **source** chain rather than a single global constant,
every deployment that mirrors the same source shares one address (the Flare home Relay and
all of its mirrors coincide), while a network's own home Relay (a different source) has its
own address. A single chain can therefore host both its own home Relay and mirrors of other
sources without an address clash — e.g. Songbird can run its home Relay and a mirror of
Flare side by side.

The deployer account is therefore the permanent address authority and must be kept in cold
storage: compromise allows deploying arbitrary code at the official address on
NOT-yet-deployed chains only; loss forfeits address continuity for future chains. Existing
deployments are unaffected by either. No trustless scheme can reserve an address on chains
that do not exist yet.

## 5. Forge deployment scripts

The production deployment path is `forge script`, under
[`deployment/scripts/relay/`](../deployment/scripts/relay/) (the legacy `redeploy-relay.ts`
Truffle path is kept for local simulation only). All scripts share
[`RelayDeployBase`](../deployment/scripts/relay/RelayDeployBase.s.sol), which centralizes
the factory address derivation, the registry address reads, the post-deploy verify suite
(implementation, owner, setter, source chain id, timelock duration, epoch anchors), and
the manifest writer.

Each **Flare-family network runs its own protocol instance (own FlareSystemsManager, own
governance multisig), so flare, songbird, coston and coston2 are each a home deployment** —
not mirrors. On any Flare network every protocol address is read from the on-chain
FlareContractRegistry (the Relay owner via `GovernanceSettings.getGovernanceAddress()`,
`FlareSystemsManager`, the old `Relay`), so no addresses live in config.

Parameters live in **one config per source** —
[`deployment/chain-config/relay/<source>.json`](../deployment/chain-config/relay/README.md)
— holding the source's `home` settings (`oldRelayPolicyHashScheme`,
`timelockDurationSeconds`) plus a `mirrors` map (keyed by chain name) of every target that
mirrors it (`chainId`, `relayOwner`, `feeCollectionAddress`, `timelockDurationSeconds`,
`feeConfigs`, `feeExemptAddresses`), with a shared top-level `expectedDeployer`. This
single inventory keeps mirrors from drifting from a shared base and lets every field be
required. The `deploy-relay.sh` wrapper (`pnpm deploy_relay <step> <arg>`) broadcasts and
records every deployed address into `deployment/deploys/<targetNetwork>.json` and
`.../all/<targetNetwork>.json` via `save-deployed-addresses.ts`.

| Script | Chain | Role |
|--------|-------|------|
| `DeployCreate3Factory` | any | Idempotent: deploys the `Create3Factory` through the keyless CREATE2 deployer from the **frozen** initcode ([`deployment/create3/`](../deployment/create3/README.md)); no-op if already present. |
| `DeployRelayHome` | each Flare-family net | Reads the source config's `home`. Relay impl + `RelayProxy` (via factory) in **setter mode** (`signingPolicySetter = FlareSystemsManager`, `oldRelay` handshake, no fee configs, `sourceChainId` forced to `block.chainid`). Owner = `GovernanceSettings.getGovernanceAddress()`; all addresses from the registry. |
| `PrepareRelaySourceSnapshot` | source (read-only) | Snapshots the live home Relay (source chain id, epoch anchors, source-bound policy hash) to `deployment/deploys/relay/source-snapshot-<source>.json` (per source) for the mirrors. |
| `DeployRelayMirror` | every mirror target | Names **both** ends: `RELAY_SOURCE` picks `source-snapshot-<source>.json` + `<source>.json`, `RELAY_MIRROR` picks `mirrors["<name>"]`. Asserts the snapshot's source maps back to `RELAY_SOURCE` and the entry's `chainId` equals the live chain — a wrong-source snapshot or wrong RPC fails before broadcast. Relay impl + `RelayProxy` (via factory) in **relay mode** from the snapshot + the entry's per-chain owner/timelock/fees/`feeExemptAddresses` (no `oldRelay`). Same deployer- and source-scoped salt ⇒ the SAME address as every mirror of that source and its home Relay. |

The frozen factory initcode, canonical factory address, salt labels, and the home/mirror
deploy flow are pinned by
[`RelayDeployAddress.t.sol`](../test-forge/unit/deployment/RelayDeployAddress.t.sol),
[`RelayDeployFlow.t.sol`](../test-forge/unit/deployment/RelayDeployFlow.t.sol) and
[`RelayConfigParsing.t.sol`](../test-forge/unit/deployment/RelayConfigParsing.t.sol)
(config key-paths). Each deployment writes a manifest (addresses, owner, source chain id,
timelock duration, epoch anchors, salt, deployer) to `deployment/deploys/relay/`.

## 6. Deployment and migration timing

The sequence for a new target Relay:

1. deploy (or confirm) the `Create3Factory` on the target chain;
2. for a mirror: run `PrepareRelaySourceSnapshot` against the live source immediately
   before deployment, so the mirror seeds the current source-bound signing-policy hash and
   epoch anchors;
3. deploy the target with the designated per-chain owner and timelock duration from the
   reviewed source config (`expectedDeployer` is enforced on every chain);
4. compare the deployed getters (`owner()`, `sourceChainId()`,
   `getTimelockDurationSeconds()`, `signingPolicySetter()`, `implementation()`, epoch
   anchors) with the deployment manifest — the scripts' post-deploy verify suite asserts
   the same set on-chain;
5. only then publish the Relay address to relayers.

For the separate pre-RLY-23 signing-policy migration on a home deployment, the config
requires an explicit old-hash scheme (`home.oldRelayPolicyHashScheme`):

```text
legacy       — wraps the old Relay's nonzero content hash exactly once with the chain id
chain-bound  — passes an already wrapped hash through
```

Zero hashes, malformed hashes and unknown schemes fail before deployment. There is
intentionally no automatic guess: both forms are indistinguishable nonzero `bytes32`
values. The currently deployed main-branch Relay (and its exact `RelayMainDeployed` test
replica) are pre-RLY-23, so that migration must use `legacy`; `chain-bound` is only for a
source Relay whose deployment provenance confirms it already stores the wrapped form.

## 7. Implemented tests

- [`RelayOwnableWithTimelock.t.sol`](../test-forge/unit/governance/RelayOwnableWithTimelock.t.sol)
  — the owner-timelock lifecycle through Relay's guarded surface: duration management,
  queue/execute/cancel, revert-bubbling, upgrade-through-queue specifics (exact-calldata
  execution, migrations as proxy self-calls, the consumed `executing` flag, value-queuing),
  setter validation + mode fail-close, and the ERC-7201 namespace layout vs the ERC-1967
  proxy slots.
- [`RelayUpgrade.t.sol`](../test-forge/unit/governance/RelayUpgrade.t.sol) — proxy
  upgradeability: immediate path at duration 0, queue → ETA → permissionless execute,
  ownership transfer, reinitialization locks, disabled renounce.
- [`Relay.t.sol`](../test-forge/unit/protocol/implementation/Relay.t.sol) — owner-installed
  and deploy-seeded fee exemptions end-to-end through `verify()`, plus the
  `setSigningPolicySetter` repoint/mode/zero matrix.
- [`RelayDeployAddress.t.sol`](../test-forge/unit/deployment/RelayDeployAddress.t.sol),
  [`RelayDeployFlow.t.sol`](../test-forge/unit/deployment/RelayDeployFlow.t.sol),
  [`RelayConfigParsing.t.sol`](../test-forge/unit/deployment/RelayConfigParsing.t.sol) —
  the deterministic deployment path (frozen initcode pins, source-scoped salts, home +
  mirror flows, post-deploy verify, config key-paths).

## 8. Formal-verification status

The owner-timelock refactor deliberately leaves the Relay FV gates (Halmos manifest pins,
Lean Yul snapshot, artifact parity, revert-ABI inventory, Certora munge, Kontrol) red
pending a dedicated re-baseline: compiler re-pins to solc 0.8.35, proxy-aware harness
setup, and the removal of the retired Safe-governance check inventory from the
verification manifest.
