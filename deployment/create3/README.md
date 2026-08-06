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
| Arachnid CREATE2 deployer | `0x4e59b44847b379578588920cA78FbF26c0B4956C` |
| factory salt | `keccak256("flare.create3-factory.v1")` = `0x48ec9c95fd2bc47a9e50dd7415832c87054ef7f0a9fe2ea09e0513b89cc2f4cd` |
| canonical factory address | `0x51a24B38b2a5793F65258Fd37EE92706FadeFE96` |
| Relay proxy salt base | `keccak256("flare.relay-proxy.v1")` = `0xcda4c1126198a40dac416f4f471df8d06f9f096423da3e1b2d2fdea7eb82d228` |

The Relay proxy salt is **source-chain-scoped**: `keccak256(abi.encode(base, sourceChainId))`.
Every deployment mirroring the same source (the Flare home + all its mirrors) shares one
address; a network's own home (a different source) gets its own, so a chain can host both its
home Relay and cross-source mirrors without an address clash.

The canonical factory address and the pinned keccak are asserted by
`test-forge/unit/deployment/RelayDeployAddress.t.sol`, so an accidental edit to either the
frozen file or the constants fails CI.

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
