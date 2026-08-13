# Relay Forge-deploy chain configs

**One config per SOURCE chain** for the owner-timelock-governed Relay Forge scripts in
[`deployment/scripts/relay/`](../../scripts/relay/): `flare.json`, `songbird.json`,
`coston.json`, `coston2.json`. Each file holds that source's own **home** deployment plus a
**`mirrors`** map listing every target chain that mirrors it — a single reviewed inventory, so a
mirror deployment cannot drift from a shared base and every field is required.

Each file declares `"$schema": "./relay-parameters.json"`. That schema is **generated** from the
[`relay-parameters.ts`](./relay-parameters.ts) interface — mirroring the top-level
`chain-parameters.ts` → `chain-parameters.json` setup — via:

```bash
pnpm generate-relay-parameter-schema
```

Re-run it whenever `relay-parameters.ts` changes and commit the regenerated
`relay-parameters.json`.

**No protocol addresses live in the home section.** On a Flare network every home address is read
from the on-chain **FlareContractRegistry** (`0xaD67FE…6019`, uniform on all Flare networks), the
single source of truth. `expectedDeployer` is shared once at the top level (home + every mirror of
the source use the same EOA, so the source's Relay address matches across chains). Secrets are
never stored here — the deployer key is read from `DEPLOYER_PRIVATE_KEY`.

## Structure

```jsonc
{
  "$schema": "./relay-parameters.json",
  "expectedDeployer": "0x…",              // shared address authority (home + every mirror)
  "home": {                                // this source's home (setter-mode) deployment
    "timelockDurationSeconds": 3600         // the ONLY home field; epoch/protocol params are
  },                                        // read from the deployed Relay's stateData()
  "mirrors": {                             // relay-mode targets of this source, keyed by name
    "arbitrum": {
      "chainId": 42161,                    // asserted against block.chainid at deploy
      "relayOwner": "0x…",                 // the chain's multisig
      "feeCollectionAddress": "0x…",       // nonzero
      "timelockDurationSeconds": 3600,     // owner-timelock for fee setters + upgrades
      "feeConfigs": [ { "protocolId": 100, "fee": "1000000" } ],  // fee > 0; omit a protocol to make it free
      "feeToken": "0x…",                   // REQUIRED: ERC-20 the fee is paid in (zero = native)
      "feeExemptAddresses": [ "0x…" ]      // e.g. DVN adapters, seeded fee-exempt (may be empty)
    }
  }
}
```

Only `flare.json` and `coston2.json` carry `mirrors` today (coston2 for DVN testing);
`songbird.json` / `coston.json` are home-only.

## Running

You only pass a **name**; the RPC is derived from it. Keep the per-network RPC URLs in `.env`
once (`FLARE_RPC`, `COSTON2_RPC`, `ARBITRUM_RPC`, `ARBITRUM_SEPOLIA_RPC`, …) — no per-invocation
env vars. The wrapper broadcasts and records every deployed address (Create3Factory, Relay proxy,
implementation) into `deployment/deploys/<name>.json` and `.../all/<name>.json` via
`save-deployed-addresses.ts`, where `<name>` is the source name (home) or the mirror name (mirror):

A run is a **dry run (simulation) by default**; add `--broadcast` to deploy for real. Any other
flag is a hard error, so a typo can never silently deploy.

```bash
pnpm deploy_relay home     coston2               # DRY RUN (simulate)
pnpm deploy_relay home     coston2 --broadcast   # real deployment
pnpm deploy_relay factory  coston2 --broadcast   # canonical Create3Factory (idempotent)
pnpm deploy_relay prepare-snapshot flare         # read-only, writes source-snapshot-flare.json
pnpm deploy_relay mirror   flare arbitrum --broadcast  # flare mirror on arbitrum (uses ARBITRUM_RPC)
```

For `mirror`, the arg is the **mirror name** — a key under the source config's `mirrors` map. The
source itself is taken from the snapshot (`prepare-snapshot` writes its `sourceChainId`), so the
deploy loads that source's config, reads `mirrors["<name>"]`, and **asserts its `chainId` equals
the live chain** (a wrong RPC fails fast). RPC is resolved from `${NAME^^}_RPC` (e.g.
`arbitrum-sepolia` → `ARBITRUM_SEPOLIA_RPC`). A
relay-specific manifest (governance generation, salts) is also written to
`deployment/deploys/relay/`.

## Home vs mirror

Each Flare-family network runs its own protocol instance (own FlareSystemsManager, own
governance), so **flare / songbird / coston / coston2 are each a home** (setter-mode) deployment
binding `sourceChainId` to their own chain. Every home address (the Relay owner via
`GovernanceSettings.getGovernanceAddress()`, `FlareSystemsManager`, the old `Relay`,
`AddressUpdater`) is read from the registry.

Every mirror target (USDT0 chains, DVN-test chains) has no local protocol and is a **mirror**
(relay-mode) deployment from the source snapshot; its per-chain `relayOwner`,
`feeCollectionAddress`, `timelockDurationSeconds`, `feeConfigs`, `feeToken` and
`feeExemptAddresses` come from its `mirrors` entry, and its
protocol parameters from the snapshot — so mirrors of one source cannot drift from each other. The
CREATE3 salt is source-scoped, so a source's home + all its mirrors share one address, and a chain
can host both its own home and a cross-source mirror (e.g. a Flare mirror on coston2).

## Fields

### top level
| Field | Required | Meaning |
|-------|----------|---------|
| `expectedDeployer` | ✓ | The designated address-authority EOA. Must be present, nonzero, and equal to the broadcasting key — schema-required and re-checked at runtime. Shared by home + every mirror. |
| `home` | ✓ | The source's own home deployment (below). |
| `mirrors` | — | Map of mirror targets keyed by name (below). Absent/empty for home-only sources. |

### `home` (DeployRelayHome)
| Field | Meaning |
|-------|---------|
| `timelockDurationSeconds` | Initial owner-timelock duration (≤ 7 days; 0 = immediate owner calls). |

`timelockDurationSeconds` is the **only** home field. All home addresses come from the
FlareContractRegistry, and every epoch/protocol param (`randomNumberProtocolId`,
`firstVotingRoundStartTs`, `votingEpochDurationSeconds`, `firstRewardEpochStartVotingRoundId`,
`rewardEpochDurationInVotingEpochs`, `thresholdIncreaseBIPS`,
`messageFinalizationWindowInRewardEpochs`) is inherited from the currently deployed Relay's
`stateData()` — four are handshake-enforced to match it anyway, the rest are preserved across the
redeploy — so nothing is duplicated in config. The initial signing-policy hash is not configured
either: it is always reconstructed from chain state (VoterRegistry + EntityManager +
FlareSystemsManager), verified byte-exactly against the old Relay's stored hash (legacy chained
fold or single-keccak — either must match), and seeded as
`keccak256(sourceChainId ‖ encoded policy)`. See `docs/relay-governance.md` §6. The Relay
constructor re-validates ranges authoritatively.

### `mirrors["<name>"]` (DeployRelayMirror)
| Field | Meaning |
|-------|---------|
| `chainId` | The target chain id; asserted against `block.chainid` at deploy. |
| `relayOwner` | Per-chain owner: authorizes fee setters and UUPS upgrades through the owner-timelock (the chain's multisig). Nonzero. |
| `feeCollectionAddress` | Recipient of collected `verify()` fees. Nonzero (a zero recipient burns fees). |
| `timelockDurationSeconds` | Initial owner-timelock duration (≤ 7 days; 0 = immediate owner calls). |
| `feeConfigs` | `[{ "protocolId": <uint8 > 1>, "fee": "<uint256 > 0>" }]`. Native wei, or `feeToken` base units when one is set. A free protocol is expressed by omission (zero fees are rejected). |
| `feeToken` | ERC-20 the `verify()` fee is paid in (allowance + `transferFrom`, pulled straight to `feeCollectionAddress`). For chains without a spendable native token (e.g. Tempo, where `msg.value` is always 0). Required — state the zero address explicitly for native-coin fees. Must be a standard exact-transfer ERC-20 — fee-on-transfer or rebasing tokens are unsupported. |
| `feeExemptAddresses` | Accounts seeded fee-exempt at deploy (e.g. DVN adapters). May be empty. |

The epoch anchors and source-bound initial signing-policy hash are NOT in
the mirror entry — they come from the live source snapshot written by `PrepareRelaySourceSnapshot`.
