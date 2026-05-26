# FCC Governance

FCC has its own governance system, distinct from system-wide [`Governor`](../Governance.md). The diamond holds two governance layers:

- **Diamond governance** — controls the diamond itself: `diamondCut` (add / replace / remove facets), update diamond-init-time settings, governance-only setters on every facet that has them. Implemented by [`DiamondGovernanceFacet`](../../../contracts/tee/facets/DiamondGovernanceFacet.sol) (inherits [`FlareGovernedBase`](../../../contracts/governance/implementation/FlareGovernedBase.sol) for the public API) + [`FlareGovernedAccess`](../../../contracts/governance/implementation/FlareGovernedAccess.sol) (modifiers-only base for the other facets) + [`FlareGovernance`](../../../contracts/governance/lib/FlareGovernance.sol) library (ERC-7201 namespaced storage, hash-based timelock).
- **Extension governance** — per-extension governance signer sets that approve TEE software upgrades and pausing-address records for that extension. The signer-set + threshold management lives in [`ExtensionGovernanceFacet`](../../../contracts/tee/facets/ExtensionGovernanceFacet.sol) + [`library/ExtensionGovernance`](../../../contracts/tee/library/ExtensionGovernance.sol). Pausing-addresses (multi-hash-pinned approval records signed by those signers) live in the separate later facet [`ExtensionPausingFacet`](../../../contracts/tee/facets/ExtensionPausingFacet.sol) + [`library/ExtensionPausing`](../../../contracts/tee/library/ExtensionPausing.sol).

Plus a related upgrade flow:

- [`UpgradeManagerFacet`](../../../contracts/tee/facets/UpgradeManagerFacet.sol) + [`library/UpgradeManager`](../../../contracts/tee/library/UpgradeManager.sol) — the upgrade lifecycle for TEE software (collect threshold of governance signatures over an upgrade announcement, schedule the activation, propagate to TEE machines).
- [`MachinePathManagerFacet`](../../../contracts/tee/facets/MachinePathManagerFacet.sol) + [`library/MachinePathManager`](../../../contracts/tee/library/MachinePathManager.sol) — per-extension governance-signed allow-list of authorized `(sourceTeeIds[], destinationTeeIds[])` paths. A *generic* primitive (no protocol semantics of its own); currently gates [`WalletBackupManagerFacet.directBackup` / `directRestore`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol).
- [`OwnerAllowlistFacet`](../../../contracts/tee/facets/OwnerAllowlistFacet.sol) + [`library/OwnerAllowlist`](../../../contracts/tee/library/OwnerAllowlist.sol) — per-extension allowlist of TEE machine owners. Maintained by extension owners.
- [`WalletProjectPauseFacet`](../../../contracts/tee/facets/WalletProjectPauseFacet.sol) + [`library/WalletProjectPause`](../../../contracts/tee/library/WalletProjectPause.sol) — per-project pauser/unpauser delegation lists (project-owner-gated). Members of these lists can pause / unpause wallets in the project alongside the project owner. See [Wallet Management](./WalletManagement.md).
- [`MachineEmergencyPauseFacet`](../../../contracts/tee/facets/MachineEmergencyPauseFacet.sol) + [`library/MachineEmergencyPause`](../../../contracts/tee/library/MachineEmergencyPause.sol) — per-extension emergency-pause overlay (extension-owner-gated, with delegated pauser/unpauser lists) + a governance-tunable post-unpause grace window that blocks third-party expired-availability `pause()` calls. See [Machine Lifecycle](./MachineLifecycle.md#emergency-pause).
- [`ExternalAddressesFacet`](../../../contracts/tee/facets/ExternalAddressesFacet.sol) + [`library/ExternalAddresses`](../../../contracts/tee/library/ExternalAddresses.sol) — the diamond's `AddressUpdatable` plug-in. Holds addresses of external contracts (FlareSystemsManager, RewardManager, Relay, etc.) that the diamond's libraries reach into.

This page walks through each.

## Diamond governance

The diamond's governance state lives in the `FlareGovernance` library — an ERC-7201-namespaced variant of the standard `GovernedBase` pattern (see [Governance / `Governor` & `Governed`](../Governance.md)). It is shared project-wide: the same library backs `FlareUpgradeableBase` (the UUPS base used by FDC2 + TEE non-Diamond contracts) and the TEE Diamond facets. Initialized once in `FlareTeeManagerInit.init`:

```solidity
FlareGovernance.initialise(_governanceSettings, _initialGovernance);
```

`FlareGovernedAccess` provides the `onlyGovernance` modifier (and `onlyImmediateGovernance`) for any facet that needs it — every method tagged `onlyGovernance` reaches `FlareGovernance.governance()` to verify the caller. `FlareGovernedAccess` deliberately exposes **no** public functions, so non-governance facets don't pollute the diamond ABI with duplicate governance selectors. The seven public governance functions (`executeGovernanceCall`, `cancelGovernanceCall`, `switchToProductionMode`, `governance`, `governanceSettings`, `productionMode`, `isExecutor`) live on `FlareGovernedBase`, which `DiamondGovernanceFacet` inherits.

`FlareGovernedAccess` also inherits OpenZeppelin's `Initializable` and calls `_disableInitializers()` in its constructor — the implementation-side anti-selfdestruct. The diamond's runtime init guard lives on [`FlareTeeManagerInit.init(...)`](../../../contracts/tee/facets/FlareTeeManagerInit.sol), which carries the `initializer` modifier; subsequent diamond migrations would use their own init contracts marked with `reinitializer(uint64)` for OZ-tracked versioned migration steps. The FlareGovernance library keeps its own `bool initialised` flag as a defense-in-depth layer that also fires on in-place upgrade scenarios where OZ's slot is virgin but the namespaced state is already set.

`DiamondGovernanceFacet` provides:

- `diamondCut(FacetCut[], address init, bytes calldata)` — the standard EIP-2535 cut entry. Adds, replaces, or removes selectors. The optional `init` argument is `delegatecall`ed for migration logic. Both [`FlareTeeManagerInit`](../../../contracts/tee/facets/FlareTeeManagerInit.sol) and [`ReplicationInit`](../../../contracts/tee/facets/ReplicationInit.sol) are designed to be passed as the `init` argument during specific cut events.
- `transferGovernance` / `claimGovernance` — two-step governance transfer (the `Governed` propose/confirm pattern, with timelocks where applicable).

The governance settings contract (`IGovernanceSettings`) provides the timelock and the executor list; the diamond's governance respects it just like any other `Governed` contract.

## Extension governance

Each extension can configure a set of **governance signers** authorized to approve TEE upgrades for that extension. The set has:

- Addresses of the signers.
- A threshold (how many of them must sign).

Stored in `ExtensionGovernance.State.governanceSets[extensionId]`, with a hash of the current set tracked separately (used to bind specific TEE versions to the governance-set-at-time-of-version-add — see [Extensions / Configuring versions](./Extensions.md#configuring-versions)).

Setting the signer set:

```solidity
function setNewTeeGovernance(
    uint256 _extensionId,
    address[] calldata _signers,
    uint64 _threshold,
    /* additional fields per the live interface */
) external;
```

Only the extension owner can call. The previous signer set is replaced atomically.

Approving an upgrade:

```solidity
function signTeeUpgrade(
    uint256 _extensionId,
    bytes32 _upgradeHash,
    Signature calldata _signature
) external;
```

Each governance signer calls this independently. The contract recovers the signer's address from the signature, checks it's in the current set, accumulates. When the threshold of distinct signers is reached, the upgrade is marked signed and the upgrade-manager flow can proceed.

`NewGovernanceSet`, `TeeUpgradeSigned`, and related events are emitted.

### Pausing addresses

A second use of the extension's governance signer set, run by the separate later facet [`ExtensionPausingFacet`](../../../contracts/tee/facets/ExtensionPausingFacet.sol) + [`library/ExtensionPausing`](../../../contracts/tee/library/ExtensionPausing.sol). The extension owner posts a record consisting of:

- An array of **pausing addresses** (off-chain consumers act on these to pause TEE machinery).
- An array of **governance hashes** to which the record is bound. The hashes must be known to the extension (validated via `isGovernanceHashValid`) and must be distinct. Each bound hash gets its own *approval* (signers, signatures, and a per-hash `thresholdMet` flag).

The signed `messageHash` includes `block.chainid`, `extensionId`, the record nonce, the bound hash list, and the pausing addresses — preventing cross-chain, cross-extension, and cross-governance signature replay. A single `signTeePausingAddresses(extensionId, nonce, signature)` call iterates the bound hash list and deposits the signature into **every** approval the signer is valid under (a signer in two hashes contributes to both). When any approval's signature count first reaches its hash-specific threshold, `TeePausingAddressesThresholdMet(extensionId, nonce, governanceHash)` fires; signature collection continues across all approvals regardless.

Because each record's bound hash list is immutable once set, "old signers can still sign" is preserved automatically: if governance rotates to a new hash after a record is created, the rotated-out signers from the bound hash can still sign that record indefinitely.

## Upgrade manager

`UpgradeManagerFacet` orchestrates the multi-stage TEE software upgrade flow:

1. **Announce** — extension owner declares an upgrade: target `(codeHash, platform)` pair, scheduled activation time, list of TEE machines that will be upgraded. The upgrade is in **pending** state.
2. **Collect signatures** — extension governance signers `signTeeUpgrade(extensionId, upgradeHash, sig)`. Once threshold is reached, the upgrade is **signed**.
3. **Activate** — at the scheduled activation time, the upgrade transitions to **active**. TEE machines on the old version go through `PRODUCTION → PAUSED_FOR_UPGRADE`. New machines registered after activation must be on the new version.
4. **Migrate** — owners of paused machines either upgrade them (re-attest with the new code hash) or replace them with replicating siblings on the new version (see [Replication](./Replication.md)).
5. **Cleanup** — once all machines are migrated, the old version can be `disableCodeHashPlatform`'d so it can never be used again.

The activation time is measured from when the upgrade is signed, with a configurable minimum delay (so signers cannot front-run the network with a sudden upgrade). Specific timing parameters are in `UpgradeManager.State` and tunable by extension governance.

## Machine path manager

[`MachinePathManagerFacet`](../../../contracts/tee/facets/MachinePathManagerFacet.sol) is a *generic* governance-signed allow-list of authorized `(sourceTeeIds[], destinationTeeIds[])` paths. It carries no protocol semantics of its own — it just records which TEE machine pairs an extension's governance has approved for some downstream flow. The first consumer is [`WalletBackupManagerFacet.directBackup` / `directRestore`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol), but the primitive is reusable for any future "governance-attested TEE-to-TEE authorization" need.

### Shape

A **path list** lives at `(extensionId, nonce)`. Storage is per-extension: each extension has its own array of lists, the list at array index `N - 1` is the list with nonce `N`. Nonces start at 1 per extension. A list contains:

- **Paths** — an array of `MachinePath { address[] sourceTeeIds; address[] destinationTeeIds; }`. Semantics within one path are many-to-many: any source ∈ A may authorize the action against any destination ∈ B.
- **Involved governance hashes** — the union of the derived governance hash of every teeId ever added to any path on this list, regardless of role. Each teeId's hash is derived from its codeHash via [`ExtensionManager.getTeeGovernanceHash(extensionId, codeHash)`](../../../contracts/tee/facets/ExtensionManagerFacet.sol). Note that a single path may mix multiple governances within its source list, its destination list, or both — the primitive treats a list-wide set; no per-path hash tracking.
- **Signatures** — collected from every involved governance, stored once per unique signer in a global array. A signature counts toward every involved governance the signer belongs to (a signer in two governances contributes to both with a single submission).
- **`messageHash`** — set when the list is finalized; binds `(bytes32("TEE_MACHINE_PATH_LIST"), block.chainid, extensionId, nonce, paths)`. Signers EIP-191 sign this hash. The same content with a different `(extensionId, nonce)` produces a different hash, preventing cross-chain, cross-extension, and cross-list signature replay.

### Lifecycle

1. **Create** — extension owner calls `createNewMachinePathList(extensionId)`. A fresh nonce is allocated; the list is empty.
2. **Add paths** — extension owner calls `addMachinePaths(extensionId, nonce, paths)` (potentially across multiple calls). For each teeId in each path, the library:
   - Verifies the teeId belongs to this extension (`ExtensionIdMismatch` from `ITeeCommonErrors` otherwise).
   - Verifies the teeId is **not in INITIALIZED status** — i.e. it has been attested at least once (`TeeIdNotEligible` otherwise). The check is intentionally loose (any post-attestation status is accepted) because path-list creation can run in advance of an actual operation, and the operation-side facet (`directBackup` / `directRestore`) re-checks status at trigger time.
   - Derives the governance hash from the teeId's codeHash and adds it to the list's involved-governance set.
   - Rejects duplicate teeIds within a single path (`SourceTeeIdAlreadyExists`, `DestinationTeeIdAlreadyExists`).
3. **Finalize** — extension owner calls `finalizeMachinePathList(extensionId, nonce)`. The library computes `messageHash` and emits `MachinePathListFinalized` with the involved-governance hashes so off-chain signers know which sets need to sign. After this, no further paths can be added.
4. **Sign** — anyone may relay a signature. `signMachinePathList(extensionId, nonce, signature)` recovers the signer (EIP-191), iterates the involved-governance set, and increments the per-governance count for every governance the signer is a member of. The same signer cannot be counted twice — `signerHasSigned[signer]` dedup. A signature that recovers to nobody-in-any-governance reverts `UnrecognizedSigner`.
5. **Activate** — the list automatically transitions to active once every involved governance has reached its threshold (each governance's threshold comes from `ExtensionGovernance.getTeeGovernanceThreshold`). `MachinePathListSigned` fires, and if the nonce strictly exceeds the extension's current active nonce, `extensionActiveListNonce[extensionId]` is updated.

### Replay / deprecation model

Only the **latest-nonce signed list** per extension is active. Older signed lists are deprecated automatically:

- The active pointer is `extensionActiveListNonce[extensionId]`, set during sign-completion when `_nonce > current`.
- Signing an older-nonce list *after* a newer one is already active does **not** demote the newer one — the older list becomes "signed but not active".
- Consumers (`directBackup` / `directRestore`) look up paths via [`MachinePathManager.requireActiveListNonceForPath`](../../../contracts/tee/library/MachinePathManager.sol), which reverts `NoActiveMachinePathList` if the extension has none yet and `InvalidMachinePath` if the pair isn't present in the currently-active list.

The nonce binding (in `messageHash`) and the latest-wins activation rule together produce a clean "rotate-by-replacement" pattern: extension governance signs a new list, and the old paths are immediately superseded.

## Owner allowlist

`OwnerAllowlistFacet` maintains, **per extension**, the set of addresses authorized to register TEE machines for that extension. Implemented by `OwnerAllowlist` library with one storage namespace.

Entry points:

- `addAllowedTeeMachineOwner(extensionId, ownerAddress)` — add to allowlist.
- `removeAllowedTeeMachineOwner(extensionId, ownerAddress)` — remove. Existing machines owned by the address are unaffected; only future registrations are blocked.
- `isAllowedTeeMachineOwner(extensionId, ownerAddress)` — view.

Only the extension owner can mutate (or for `extensionId == 0`, system governance).

The allowlist is separate from the **governance signers** because an extension may want different administrative roles for different actions: the governance signers approve software upgrades; the allowlist controls who can register hardware. Both are extension-scoped.

## External addresses

`ExternalAddressesFacet` is the diamond's `AddressUpdatable` plug-in. The `AddressUpdater` (the system contract) calls into it when it pushes new external-contract addresses; the facet writes them into the `ExternalAddresses.State` slot.

The diamond reads from this slot whenever a library needs an external contract:

```solidity
// example from Instructions.sendInstructions
ExternalAddresses.State storage ext = ExternalAddresses.getState();
uint24 currentRewardEpochId = IFlareSystemsManager(ext.flareSystemsManager).getCurrentRewardEpochId();
IIRewardManager(ext.rewardManager).receiveRewards{value: msg.value}(currentRewardEpochId, false);
```

`ext.flareSystemsManager`, `ext.rewardManager`, `ext.relay` and friends are kept fresh by `AddressUpdater`. When governance updates one of them across the system, FCC sees the new address on the next call.

## Why split governance like this

Different concerns, different threat models, different tempos:

- **Diamond governance** is the highest-trust, lowest-frequency layer. A `diamondCut` rewrites contract logic; the timelock is generous, the operator small. It's the system governance for everything FCC.
- **Extension governance** is per-extension, mid-trust, faster. It approves TEE software updates within the bounds the diamond defined. Each extension can have its own signer set so e.g. the FCC team controls the system extension, while a third-party application's extension is controlled by that application's team.
- **Owner allowlist** is per-extension operational. It changes regularly as TEE operators come and go — putting it under diamond governance would be operationally untenable.

The split lets the system governance focus on rare, high-impact changes (cut a new facet, change verification parameters, add a new system-supported platform) while extension owners self-administer the day-to-day. The diamond's libraries enforce isolation: a poorly-administered extension can damage *its own* machines and wallets but cannot escape into the system extension or another extension.
