# Frozen Create3Factory initcode

`Create3Factory.initcode.hex` is the **frozen** creation bytecode of
[`Create3Factory`](../../contracts/utils/implementation/Create3Factory.sol), and it is the
source of truth for deploying the factory on every chain — present and future.

## Why it is frozen

The factory must live at **one address everywhere**. That address is

```
CREATE2(Arachnid deployer, FACTORY_CREATE2_SALT, keccak256(initcode))
```

where the Arachnid deployer is `0x4e59b44847b379578588920cA78FbF26c0B4956C` and
`FACTORY_CREATE2_SALT = keccak256("flare.create3-factory.v1")`. The address depends on the
**initcode hash**, so any recompile drift would move the factory to a different address on
chains where it is not yet deployed.

To make that hash robust across time, the factory is compiled **metadata-free**: `foundry.toml`
maps `Create3Factory.sol` to a `no-metadata` compilation profile (`bytecode_hash = "None"`, same
`via_ir`/optimizer as default). solc's default `ipfs` metadata hash folds in the full settings
(all remappings) and every transitive source hash, so an unrelated dependency bump or remappings
reorder would shift it — and with it the factory address — even though the factory code is
unchanged. Stripping it makes the initcode a function of only (factory code, solc version,
optimizer). At a fixed commit the build is already reproducible across machines; metadata-free
extends that stability across *future* commits, which is what a "same address on chains added
years later" factory needs. A deliberate solc/optimizer/code change is still expected to change
the address (and requires a re-freeze).

Deploy scripts read these committed bytes and deploy them verbatim; they never compile the
factory afresh. [`RelayDeployBase`](../scripts/relay/RelayDeployBase.s.sol) pins the hash in
`FACTORY_INITCODE_KECCAK` and refuses to proceed if the file's hash drifts.

## Pinned values

| Value | |
|-------|---|
| initcode file | `Create3Factory.initcode.hex` (metadata-free, 855 bytes) |
| `keccak256(initcode)` | `0x527b93054ed37ffa9db40d5b403b0c72aa7b5c50cd28a0e344a25684fbe0f567` |
| factory runtime codehash | `0x0a117137c9c565cf27bc0aa3041fdac794f8dd6590d76119899ae80b8eae52b4` (keccak of the runtime code the frozen initcode deploys; 829 bytes) |
| Arachnid CREATE2 deployer | `0x4e59b44847b379578588920cA78FbF26c0B4956C` |
| Arachnid runtime codehash | `0x2fa86add0aed31f33a762c9d88e807c475bd51d0f52bd0955754b2608f7e4989` (verified live on Flare, Songbird, Coston, Coston2, Ethereum, Arbitrum — 2026-08-19) |
| factory salt | `keccak256("flare.create3-factory.v1")` = `0x48ec9c95fd2bc47a9e50dd7415832c87054ef7f0a9fe2ea09e0513b89cc2f4cd` |
| canonical factory address | `0x51a24B38b2a5793F65258Fd37EE92706FadeFE96` |
| Relay proxy salt base | `keccak256("flare.relay-proxy.v1")` = `0xcda4c1126198a40dac416f4f471df8d06f9f096423da3e1b2d2fdea7eb82d228` |

Both runtime codehashes are enforced at deploy time: `DeployCreate3Factory` refuses a chain whose
Arachnid address carries unexpected code and re-checks the factory's runtime code on both the
fresh-deploy and already-deployed paths, and every home/mirror deploy re-checks the factory
codehash via `_requireFactory()`. Before deploying on a NEW chain, verify its Arachnid deployer
live: `cast keccak "$(cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url $RPC)"`.

## Relay proxy pins

The expected Relay proxy address is pinned **per source** in
[`RelayDeployBase`](../scripts/relay/RelayDeployBase.s.sol) (`EXPECTED_RELAY_FLARE`,
`EXPECTED_RELAY_SONGBIRD`, `EXPECTED_RELAY_COSTON`, `EXPECTED_RELAY_COSTON2`). One pin covers a
source's home chain and every mirror of that source (same deployer + source-scoped salt +
canonical factory ⇒ identical address on all chains).

Each source has its **own designated deployer EOA** (a per-source Google Cloud KMS key) — the
source's home chain and every mirror of that source share it. Activated 2026-08-26:

| Source | Deployer | Pin |
|--------|----------|-----|
| flare (14) | `0xE5dF05a88d575BB5c86005e1A67C6Af50Ec3a7c1` | `0x5A2Eb0cdB4Aa8253924a488A77EdfD24Bb64407f` |
| songbird (19) | `0x698c017F8bF62d39F450887E4d2072Fbc72F7595` | `0xc1BC89b717Af42AE27497C9FFb996002D3AC5031` |
| coston (16) | `0x209FDc31024BfC55a4293c40678aF9D4443e5A63` | `0xEcD0B60Ea5E01e4D0bFd621c8920B40A32389b83` |
| coston2 (114) | `0x0952Db7ea2dF3EFA545326cC33443AFe00419981` | `0x5017728F117501A24EF9C3756C07f0d564598596` |

While a pin is `address(0)` its source is **not deployable** (dry runs included). Activating a
source — once its designated deployer EOA is chosen — fills, in ONE reviewed commit:

1. the source's `EXPECTED_RELAY_*` constant (`pin = Create3.computeAddress(keccak256(abi.encode(
   deployer, relayProxySalt(sourceChainId))), factory)` — the base's `_predictedRelayAddress`);
2. `expectedDeployer` in the source's `deployment/chain-config/relay/<source>.json`;
3. `CANONICAL_DEPLOYER_<SOURCE>` in `test-forge/unit/deployment/RelayDeployAddress.t.sol` — its
   `test_relayAddressPinsConsistent` binds each pin to its source's deployer in both states;
4. this table.

The Relay proxy salt is **source-chain-scoped**: `keccak256(abi.encode(base, sourceChainId))`.
Every deployment mirroring the same source (the Flare home + all its mirrors) shares one
address; a network's own home (a different source) gets its own, so a chain can host both its
home Relay and cross-source mirrors without an address clash.

The canonical factory address, the pinned keccak, both runtime codehashes and the Relay pin
consistency are asserted by `test-forge/unit/deployment/RelayDeployAddress.t.sol`, so an
accidental edit to either the frozen file or the constants fails CI.

## Regenerating (only on a deliberate factory version bump)

Regenerating changes the factory address and breaks address continuity for chains not yet
deployed. Do it only as an explicit, versioned change (bump the salt label, e.g.
`flare.create3-factory.v2`), never as a side effect of a compiler upgrade:

```bash
forge build
python3 - <<'EOF'
import json
a = json.load(open('artifacts-forge/Create3Factory.sol/Create3Factory.json'))
open('deployment/create3/Create3Factory.initcode.hex','w').write(a['bytecode']['object'] + '\n')
EOF
cast keccak "$(cat deployment/create3/Create3Factory.initcode.hex)"   # update FACTORY_INITCODE_KECCAK + the test
```
