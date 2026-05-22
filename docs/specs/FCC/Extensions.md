# Extensions

FCC is **multi-tenant**. The default tenant is the **system extension** (extension ID `0`); around it, extensions can be registered for application-specific use cases — wallets and signing schemes, custom attestation flows, third-party VRF use, anything that benefits from TEE custody.

The on-chain pieces:

- [`ExtensionManagerFacet`](../../../contracts/tee/facets/ExtensionManagerFacet.sol) + [`library/ExtensionManager`](../../../contracts/tee/library/ExtensionManager.sol) — extension registry, supported versions, owner allowlist linkage.
- [`ExtensionGovernanceFacet`](../../../contracts/tee/facets/ExtensionGovernanceFacet.sol) + [`library/ExtensionGovernance`](../../../contracts/tee/library/ExtensionGovernance.sol) — per-extension governance signer-set + threshold management. Day-1 facet.
- [`ExtensionPausingFacet`](../../../contracts/tee/facets/ExtensionPausingFacet.sol) + [`library/ExtensionPausing`](../../../contracts/tee/library/ExtensionPausing.sol) — per-extension pausing-addresses records bound to one or more governance hashes; signed by the governance signers. Later facet.

This page covers the extension system itself. For the applications that Flare currently offers *within* the system extension (FDC2, PMW), see the per-application sections at the end.

## What an extension is

An extension is a tuple of:

- **Extension ID** — assigned at registration. ID `0` is the **system extension** (reserved at diamond init via `extensionsCounter = 1`).
- **Owner** — the Flare address authorized to administer the extension.
- **State verifier** — the address of an `ITeeExtensionStateVerifier` contract that can verify extension-specific TEE-signed messages. (Optional / `address(0)` if the extension doesn't need stateful verification.)
- **Instructions sender** — the **single** authorized address that can call `InstructionsFacet.sendInstructions` on this extension's behalf. Typically a contract.
- **Supported `(codeHash, platform)` pairs** — the TEE software versions (and the hardware platforms each version is allowed on) that the extension's TEE machines may run.
- **Supported key types** — the `(keyType, signingAlgo)` pairs the extension's wallets are allowed to use.
- **Owner allowlist** — addresses authorized to register TEE machines for this extension. Maintained per-extension on `OwnerAllowlistFacet`.
- **Governance signers** — addresses authorized to sign TEE upgrade decisions for this extension (separate from the system governance). See [Governance](./Governance.md).

## Registration

Anyone can register an extension by calling `ExtensionManagerFacet.register(stateVerifier, instructionsSender)`:

```solidity
function register(
    ITeeExtensionStateVerifier _teeExtensionStateVerifier,
    address _teeExtensionInstructionsSender
) external returns (uint256 _extensionId);
```

The caller becomes the extension owner. `extensionsCounter` is incremented; the new ID is returned. Both the state verifier (or zero) and the instructions sender are recorded.

There is no allowlist gating registration itself — anyone willing to operate an extension can register. The gates that matter come later:

- The system-supported platform list (settable only by system governance) restricts which TEE platforms an extension can require for its software versions.
- The system-supported key types and signing algorithms (also system governance) restrict which keys extension wallets can use.
- The TEE machines themselves — the people willing to run extension-specific TEE software — are an off-chain market problem.

## Configuring versions

Once registered, the extension owner controls which TEE software is acceptable:

```solidity
function addTeeVersion(
    uint256 _extensionId,
    string calldata _version,            // human-readable label, e.g. "1.2.0"
    bytes32 _codeHash,                   // hash of the TEE binary
    bytes32[] calldata _platforms,       // hardware platforms this version supports
    bytes32 _governanceHash              // optional: ties this version to a governance configuration
) external;
```

Each version is identified by `_codeHash`. The `_platforms` array enumerates the TEE platforms (e.g. `bytes32("INTEL_SGX_TDX")`, `bytes32("AMD_SEV_SNP")`) the version is approved on. Only platforms on the system-supported list can be added — `UnsupportedPlatform()` if not.

`_governanceHash` is optional. When non-zero, it must match the *current* extension governance hash (the on-chain hash of the extension's governance signer set + threshold). This couples versions to specific governance configurations: if the extension governance changes, old versions still work but new versions added must reference the new configuration. Setting `_governanceHash = 0` skips this binding.

> **Operational note for governance-gated flows.** Setting `_governanceHash = 0` is fine for the legacy upgrade flow (which compares the bound hash directly), but it makes the code hash invisible to any downstream flow that derives the governance hash from a teeId's codeHash via [`ExtensionManager.getTeeGovernanceHash`](../../../contracts/tee/library/ExtensionManager.sol) — including the [`MachinePathManager`](./Governance.md#machine-path-manager) signer-derivation in `addMachinePaths`. If your extension intends to use machine path lists, **pass the actual current governance hash** when adding the TEE version; otherwise the path list will have an empty involved-governance set and no one will be recognized as a valid signer.

A version once added stays unless explicitly disabled:

```solidity
function disableCodeHashPlatform(uint256 _extensionId, bytes32 _codeHash, bytes32 _platform) external;
```

`_platform = 0` disables the version on *all* its platforms. Disabled versions cannot be used to register *new* TEE machines, and TEE machines currently running disabled versions are subject to permissionless pause (see [Machine Lifecycle / Pausing](./MachineLifecycle.md#pausing)).

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

## System-extension-specific configuration (governance)

Two governance-only methods:

```solidity
function addSystemSupportedPlatforms(bytes32[] calldata _platforms) external;
function addSystemSupportedKeyTypesAndSigningAlgos(
    bytes32[] calldata _keyTypes,
    bytes32[][] calldata _signingAlgosByKeyType
) external;
```

These set the *system-wide* superset of supported platforms and key types. Extension owners then opt into subsets via `addTeeVersion` / `addSupportedKeyTypes`.

Adding a new platform or key type is a one-way operation in this code path — there's no `removeSystemSupported*` method. Removing system support would require a diamond cut (replace `ExtensionManagerFacet` with a version that allows it). This conservatism reflects how disruptive removing platform support would be — every extension that uses it would have to migrate.

## The system extension

Extension ID `0` is special:

- Reserved at diamond init (`ExtensionManager.getState().extensionsCounter = 1` in `FlareTeeManagerInit.init`).
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
4. **Allowlist owners** via `OwnerAllowlistFacet.addAllowedTeeMachineOwner(extensionId, ownerAddress)` for each TEE operator the extension wants to permit.
5. **Configure governance signers** via `ExtensionGovernanceFacet.setNewTeeGovernance(extensionId, signers, threshold)` — the addresses authorized to sign extension upgrades and pausing-address records. `signers` must contain no `address(0)` entries and no duplicates. See [Governance](./Governance.md).
6. **Operators register their TEE machines** via `MachineManagerFacet.register` with the extension's ID. The machines run the registered code hash on registered platforms.
7. **The instructions sender contract** (configured at registration via `setExtensionContracts` later if needed) is the single address that calls `InstructionsFacet.sendInstructions` on behalf of users. Application contracts call into this gateway, which validates application-level access and then forwards to FCC.

Custom extensions are completely opaque to the rest of the system — their operations have non-`F_` opTypes, their TEE machines are isolated from system-extension machines (different `extensionId`), their governance is separate. The only shared resource is the diamond itself (the same `OperationFees` table; the same machine-lifecycle facets).
