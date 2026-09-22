# Extensions

FCC is **multi-tenant**. The default tenant is the **system extension** (extension ID `0`); around it, the **reserved range** (IDs `1..65535`) is for Flare-managed extensions minted only by governance, and the **public range** (IDs `65536+`) is for application-specific use cases — wallets and signing schemes, custom attestation flows, third-party VRF use, anything that benefits from TEE custody.

The on-chain pieces:

- [`ExtensionManagerFacet`](../../../contracts/tee/facets/ExtensionManagerFacet.sol) + [`library/ExtensionManager`](../../../contracts/tee/library/ExtensionManager.sol) — extension registry, supported versions, owner allowlist linkage.
- [`ExtensionGovernanceFacet`](../../../contracts/tee/facets/ExtensionGovernanceFacet.sol) + [`library/ExtensionGovernance`](../../../contracts/tee/library/ExtensionGovernance.sol) — per-extension governance signer-set + threshold management.

This page covers the extension system itself. For the applications that Flare currently offers *within* the system extension (FDC2, PMW), see the per-application sections at the end.

## What an extension is

An extension is a tuple of:

- **Extension ID** — assigned at registration. ID `0` is the **system extension**. IDs `1..65535` are the **reserved range** (minted only by governance via `registerReserved`). IDs `65536+` are the **public range** (minted via `register()`; the `nextPublicExtensionId` counter is initialised to `65536` at diamond init).
- **Owner** — the Flare address authorized to administer the extension.
- **State verifier** — the address of an `ITeeExtensionStateVerifier` contract that can verify extension-specific TEE-signed messages. (Optional / `address(0)` if the extension doesn't need stateful verification.)
- **Instructions sender** — the **single** authorized address that can call `InstructionsFacet.sendInstructions` on this extension's behalf. Typically a contract.
- **Supported `(codeHash, platform)` pairs** — the TEE software versions (and the hardware platforms each version is allowed on) that the extension's TEE machines may run.
- **Supported key types** — the `(keyType, signingAlgo)` pairs the extension's wallets are allowed to use.
- **Owner allowlist** — addresses authorized to register TEE machines for this extension. Maintained per-extension on `OwnerAllowlistFacet`.
- **Governance signers** — addresses authorized to sign TEE upgrade decisions for this extension (separate from the system governance). See [Governance](./Governance.md).

## Registration

### Public registration

Allowlisted addresses register a public extension by calling `ExtensionManagerFacet.register(stateVerifier, instructionsSender)`:

```solidity
function register(
    ITeeExtensionStateVerifier _teeExtensionStateVerifier,
    address _teeExtensionInstructionsSender
) external returns (uint256 _extensionId);
```

The caller becomes the extension owner. The new ID is the current value of `nextPublicExtensionId` (initialised to `65536`), which is then incremented; the new ID is returned. Both the state verifier (or zero) and the instructions sender are recorded.

Registration is gated by the **global extension-owner allowlist** on `OwnerAllowlistFacet` (governance-controlled). The caller must either be on `allowedExtensionOwners` or the global `allExtensionOwnersAllowed` flag must be true. The flag's initial value comes from the `teePublicExtensionCreationEnabled` chain parameter — `true` on testnets / scdev (open at launch), `false` on flare / songbird (closed at launch; governance must seed the allowlist or flip the flag). The same allowlist also gates ownership transfer (see *Ownership transfer* below).

Further gates that matter later:

- The system-supported platform list (settable only by system governance) restricts which TEE platforms an extension can require for its software versions.
- The system-supported key types and signing algorithms (also system governance) restrict which keys extension wallets can use.
- The TEE machines themselves — the people willing to run extension-specific TEE software — are an off-chain market problem.

### Reserved registration

Governance can mint an extension in the reserved range `[1, 65535]` for Flare-managed extensions:

```solidity
function registerReserved(uint256 _extensionId, address _owner) external;  // onlyImmediateGovernance
```

Governance picks both the id and the initial owner. The verifier and instructions-sender are not set at mint time; the owner sets them later via `setExtensionContracts`. The reserved owner is **not** required to be on the global extension-owner allowlist — governance can mint to any address. Ownership transfer afterwards follows the same allowlist gating as public extensions.

## Configuring versions

Once registered, the extension owner controls which TEE software is acceptable:

```solidity
function addTeeVersion(
    uint256 _extensionId,
    bytes32 _version,                    // UTF-8 encoded label, e.g. "1.2.0", for off-chain use only
    bytes32 _codeHash,                   // hash of the TEE binary
    bytes32[] calldata _platforms        // hardware platforms this version supports
) external;
```

Each version is identified by `_codeHash`. The `_platforms` array enumerates the TEE platforms (e.g. `bytes32("INTEL_SGX_TDX")`, `bytes32("AMD_SEV_SNP")`) the version is approved on. Only platforms on the system-supported list can be added — `UnsupportedPlatform()` if not.

`addTeeVersion` does **not** carry a governance hash. The governance binding for a TEE is committed at machine **registration time**, not at version-add time: see [Machine Lifecycle / Registration](./MachineLifecycle.md#registration). The same `(codeHash, platform)` pair can host machines registered under different governance configurations as the extension's governance rotates over time.

A version once added stays unless explicitly disabled:

```solidity
function disableCodeHashPlatforms(uint256 _extensionId, bytes32 _codeHash, bytes32[] calldata _platforms) external;
```

`_platforms` must be a non-empty list; each entry must belong to the code-hash version and must not already be disabled (`NoPlatforms()`, `InvalidPlatform()`, `CodeHashPlatformAlreadyDisabled()` otherwise). To disable a version on *all* its platforms, pass them all explicitly — there is no "empty means all" shortcut, which removes the footgun of accidentally disabling every platform by passing a zero value. Disabled versions cannot be used to register *new* TEE machines, and — in the **same transaction** — every currently-active (`PRODUCTION`) machine of the extension running one of the disabled `(codeHash, platform)` pairs is moved to `PAUSED` and dropped from both active sets (see [Machine Lifecycle / Pausing](./MachineLifecycle.md#pausing)). Each such pause emits a `TeeMachineStatusChanged` event alongside the single `CodeHashPlatformsDisabled`.

Because the disable retires machines by iterating the extension's active set, a very large active set can push a single `disableCodeHashPlatforms` call past the block gas limit — in which case the whole transaction reverts and nothing is disabled. To disable a version at that scale, the extension owner first shrinks the active set: `ban()` some machines (each `ban` removes a machine from the active sets) and/or call `removeAllowedTeeMachineOwners` / `disallowAllTeeMachineOwners` so that no new machine can register and front-run (re-inflate the set ahead of) the disable, then retry. Machines that are not active at disable time (`INITIALIZED`, `SUSPENDED`, `PAUSED`, `BANNED`) are left as-is; they can never reach `PRODUCTION` on a disabled version because `toProduction` re-checks support.

## Configuring key types

```solidity
function addSupportedKeyTypes(uint256 _extensionId, bytes32[] calldata _keyTypes) external;
function removeSupportedKeyTypes(uint256 _extensionId, bytes32[] memory _keyTypes) external;
```

Both extension-owner-only. Adding a key type requires it to be on the system-supported list (`KeyTypeNotSupported(keyType)` if not). Removing a key type doesn't affect existing keys of that type — they still work — but no new keys of that type can be generated for the extension's wallets going forward.

## Ownership transfer

Two-step:

```solidity
function proposeNewOwner(uint256 _extensionId, address _newOwner) external;  // current owner
function confirmOwnership(uint256 _extensionId) external;                    // proposed owner
```

The system extension (`extensionId == 0`) cannot be transferred — `SystemOwnedExtensionId()` reverts on the proposal. System extension administration goes through diamond governance.

`proposeNewOwner` requires `_newOwner` to be on the global extension-owner allowlist (or `address(0)` to clear a pending proposal). `confirmOwnership` re-checks that the proposed owner is still allowed at confirmation time — this defends against an address being removed from the allowlist between propose and confirm. This gate applies uniformly to public and reserved extensions (the initial reserved mint by governance is exempt; transfers after the mint follow the same rule).

## Optional prep-helper: the extension operator

```solidity
function setExtensionOperator(uint256 _extensionId, address _operator) external;  // owner only
function getExtensionOperator(uint256 _extensionId) external view returns (address);
```

The owner may install one **operator** address per extension, or clear it by passing `address(0)`. The operator is not a co-owner — it can only drive prep steps whose real security gate is a downstream governance threshold signature: the machine-path-list lifecycle (`createNewMachinePathList`, `addMachinePaths`, `finalizeMachinePathList`). Everything else — `setExtensionContracts`, version configuration, allowlists, emergency-pauser delegation, ban/unban, `setNewTeeGovernance`, `proposeNewOwner` — remains owner-only.

The setter works for every extension, including `extensionId == 0`. For id 0, the caller must be the FlareGovernance governance address (a direct tx from the governance multisig). Operators cannot rotate themselves. See [FCC Governance / Extension operator](./Governance.md#extension-operator) for the full rationale.

## System-extension-specific configuration (governance)

Two governance-only methods:

```solidity
function addSystemSupportedPlatforms(bytes32[] calldata _platforms) external;
function removeSystemSupportedPlatforms(bytes32[] calldata _platforms) external;
function addSystemSupportedKeyTypesAndSigningAlgos(
    bytes32[] calldata _keyTypes,
    bytes32[][] calldata _signingAlgosByKeyType
) external;
function removeSystemSupportedKeyTypesAndSigningAlgos(
    bytes32[] calldata _keyTypes,
    bytes32[][] calldata _signingAlgosByKeyType
) external;
```

These set the *system-wide* superset of supported platforms and key types. Extension owners then opt into subsets via `addTeeVersion` / `addSupportedKeyTypes`.

The remove methods are deliberately scoped to **block only new creation**, never existing flows:

- `removeSystemSupportedPlatforms` — each platform must currently be system-supported (`PlatformNotFound(platform)` otherwise). Removing a platform only blocks `addTeeVersion` from referencing it for *new* versions; existing versions keep their own stored platform set and the machines running them are unaffected.
- `removeSystemSupportedKeyTypesAndSigningAlgos` — mirrors the add method's shape. For each key type the listed signing algorithms are removed (`SigningAlgoNotFound(keyType, signingAlgo)` if one isn't present, `NoSigningAlgos(keyType)` if the per-key-type list is empty), and once a key type has no remaining signing algorithm it is dropped from the system-supported key types. Removal only blocks `createProject` from using that `(keyType, signingAlgo)` combination for *new* projects; existing projects store their own `signingAlgo` and their backup, restore and key operations read that stored value, so they are unaffected.

There is no usage check on removal — a platform / key type / signing algo can be removed even while existing versions or projects still reference it, by design, because the consumers only gate creation.

## The system extension

Extension ID `0` is special:

- Reserved permanently — the `nextPublicExtensionId` counter starts at `65536`, and the reserved-range mint via `registerReserved` rejects `_extensionId == 0`.
- Owner is the diamond governance itself (not transferable).
- Hosts the Flare-operated **applications** that ship in the FCC base distribution — currently FDC2 and PMW. These applications share extension ID `0`, share the same TEE machines (system-extension TEEs), and share governance, but are otherwise independent protocols offered by Flare. They are *not* separate extensions in the on-chain sense — there is one system extension hosting many applications.
- Instructions originating from the system extension can have `opType` starting with `F_` (the system prefix); other extensions cannot.
- Its instructionsSender is system-governance-controlled.

`Fdc2Hub.requestAttestation`, when it picks random TEEs via `getRandomTeeIds(0, count)`, is asking specifically for system-extension TEEs.

## Applications offered by the system extension

The system extension currently hosts two applications. Both share `extensionId == 0` and the same pool of system-extension TEE machines; what distinguishes them is their `opType` namespace and the on-chain hub that dispatches their instructions.

### FDC2 (Flare Data Connector v2)

A TEE-based attestation service. Application opType is `F_FDC2`; the only command currently is `"PROVE"`. Implemented by [`Fdc2Hub`](../../../contracts/fdc2/implementation/Fdc2Hub.sol) — a UUPS-upgradeable contract outside the diamond — which is registered as a system instructions sender so it can dispatch under the `F_` prefix. From the user's perspective, the request goes to `Fdc2Hub.requestAttestation`; under the hood that becomes a `(F_FDC2, "PROVE")` instruction on system-extension TEEs. See [FDC / FDC2](../FDC/Fdc2.md).

### PMW (Protocol-Managed Wallet)

A multisig-wallet service for XRPL. PMW provides XRPL multisig accounts whose private-key shares are hosted on system-extension TEE machines, with on-chain bookkeeping for the wallet, the key admins, and the per-wallet payment stream. Application opType is `F_WALLET`; commands include:

- `MULTISIG_CONFIGURE` — configure an XRPL account's signer set + threshold.
- `PAY` — sign and broadcast a payment from the multisig.
- `REISSUE` — reissue a payment that failed to confirm.
- `KEY_GENERATE`, `KEY_DELETE`, `VRF` — the wallet-key primitives shared with [Key Management](./KeyManagement.md) and [Wallet Management](./WalletManagement.md).

PMW lives partly inside the diamond (the wallet machinery, key management facets — `WalletManagerFacet`, `WalletKeyManagerFacet`, etc.) and partly as separate off-chain components (the XRPL relay logic, payment scheduling, fee accounting via the `TeePayments*` suite).

### Why both share extension ID 0

FDC2 and PMW are both Flare-operated, both depend on the same set of registered system-extension TEE machines, both share the same governance lifecycle (system governance), and both rely on the same registered owner allowlist of TEE operators willing to run system-extension software. Putting them under separate `extensionId`s would force separate machine pools, separate allowlists, and separate governance — none of which is desirable. Sharing extension `0` keeps the operational model unified; the `opType` namespace (`F_FDC2`, `F_WALLET`, `F_VRF`, `F_REG`, `F_GET`, `F_POLICY`) is what distinguishes the applications from each other.

### Future applications

Other Flare-operated applications can be added to the system extension in the future without registering a new extension — the dispatch contract just needs to be added to the registered system instructions senders set, and a new `F_*` opType assigned. This is a low-friction path for protocol-level features that require TEE custody but don't justify their own extension lifecycle.

A third-party application that needs its own TEE pool, its own governance, its own allowlist, or its own version cadence registers as a separate extension (extension ID ≥ 1). Inside that extension, the third party can host one application or many — the same application-vs-extension separation applies recursively.

## Custom extensions

A typical custom extension flow:

1. **Register** via `ExtensionManagerFacet.register`. Receive an extension ID.
2. **Configure** TEE versions (`addTeeVersion`) for the platforms the extension's TEE software runs on. The TEE software itself has to be built and the binary's code hash known in advance.
3. **Configure** supported key types if the extension's wallets need anything beyond default.
4. **Allowlist owners** via `OwnerAllowlistFacet.addAllowedTeeMachineOwners(extensionId, owners)` for the TEE operators the extension wants to permit.
5. **Configure governance signers** via `ExtensionGovernanceFacet.setNewTeeGovernance(extensionId, signers, threshold)` — the addresses authorized to sign extension upgrades and machine-path lists. `signers` must contain no `address(0)` entries and no duplicates. See [Governance](./Governance.md).
6. **Operators register their TEE machines** via `MachineManagerFacet.register` with the extension's ID. The machines run the registered code hash on registered platforms.
7. **The instructions sender contract** (configured at registration via `setExtensionContracts` later if needed) is the single address that calls `InstructionsFacet.sendInstructions` on behalf of users. Application contracts call into this gateway, which validates application-level access and then forwards to FCC.

Custom extensions are completely opaque to the rest of the system — their operations have non-`F_` opTypes, their TEE machines are isolated from system-extension machines (different `extensionId`), their governance is separate. The only shared resource is the diamond itself (the same `OperationFees` table; the same machine-lifecycle facets).
