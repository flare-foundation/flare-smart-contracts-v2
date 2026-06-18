# FCC Governance

FCC has its own governance system, distinct from system-wide [`Governor`](../Governance.md). The diamond holds two governance layers:

- **Diamond governance** — controls the diamond itself: `diamondCut` (add / replace / remove facets), update diamond-init-time settings, governance-only setters on every facet that has them. Implemented by [`DiamondGovernanceFacet`](../../../contracts/tee/facets/DiamondGovernanceFacet.sol) (inherits [`FlareGovernedBase`](../../../contracts/governance/implementation/FlareGovernedBase.sol) for the public API) + [`FlareGovernedAccess`](../../../contracts/governance/implementation/FlareGovernedAccess.sol) (modifiers-only base for the other facets) + [`FlareGovernance`](../../../contracts/governance/lib/FlareGovernance.sol) library (ERC-7201 namespaced storage, hash-based timelock).
- **Extension governance** — per-extension governance signer sets that approve TEE software upgrades and pausing-address records for that extension. The signer-set + threshold management lives in [`ExtensionGovernanceFacet`](../../../contracts/tee/facets/ExtensionGovernanceFacet.sol) + [`library/ExtensionGovernance`](../../../contracts/tee/library/ExtensionGovernance.sol). Pausing-addresses (multi-hash-pinned approval records signed by those signers) live in the separate later facet [`ExtensionPausingFacet`](../../../contracts/tee/facets/ExtensionPausingFacet.sol) + [`library/ExtensionPausing`](../../../contracts/tee/library/ExtensionPausing.sol).

Plus related authorization primitives:

- [`MachinePathManagerFacet`](../../../contracts/tee/facets/MachinePathManagerFacet.sol) + [`library/MachinePathManager`](../../../contracts/tee/library/MachinePathManager.sol) — per-extension governance-signed allow-list of authorized `(sourceTeeIds[], destinationTeeIds[])` paths. A *generic* primitive (no protocol semantics of its own); currently gates [`WalletBackupManagerFacet.directBackup` / `directRestore`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol) and [`ReplicationFacet.replicateFrom`](../../../contracts/tee/facets/ReplicationFacet.sol). This is the *only* per-extension governance-signed authorization primitive.
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
- the public governance API inherited from `FlareGovernedBase` (the seven functions listed above): `executeGovernanceCall` / `cancelGovernanceCall` run or drop a pending timelocked call, `switchToProductionMode` locks in the timelock, and `governance` / `governanceSettings` / `productionMode` / `isExecutor` are views. There is **no** governance transfer/claim entry point — the effective governance address comes from the central `IGovernanceSettings` (`getGovernanceAddress()`), and rotating it is a settings-level action, not a diamond method.

The governance settings contract (`IGovernanceSettings`) provides the timelock and the executor list; the diamond's governance respects it just like any other `Governed` contract.

## Extension governance

Each extension can configure a set of **governance signers** authorized to approve TEE upgrades for that extension. The set has:

- Addresses of the signers.
- A threshold (how many of them must sign).

Stored in `ExtensionGovernance.State.governanceSets[extensionId]`, with a hash of the current set tracked separately. The hash a TEE machine commits to at registration time (its `governanceHash` field — see [Machine Lifecycle / Registration](./MachineLifecycle.md#registration)) is later consumed by the machine-path-list flow.

Setting the signer set (on `ExtensionGovernanceFacet`):

```solidity
function setNewTeeGovernance(
    uint256 _extensionId,
    address[] calldata _signers,
    uint64 _signersThreshold
) external;
```

Only the extension owner can call. It sets the extension's *latest* governance hash to `keccak256(abi.encode(_signers, _signersThreshold))` and emits `NewTeeGovernanceSet`. Previously-registered signer sets are retained — a signer of an older set can still sign records bound to that older hash (see Pausing addresses below and the machine-path-list flow).

`NewTeeGovernanceSet` (signer-set changes), `MachinePathListSigned` (a path list fully signed), and similar events are emitted as governance activity progresses.

### Pausing addresses

A second use of the extension's governance signer set, run by the separate later facet [`ExtensionPausingFacet`](../../../contracts/tee/facets/ExtensionPausingFacet.sol) + [`library/ExtensionPausing`](../../../contracts/tee/library/ExtensionPausing.sol). The extension owner — or the extension operator, if set; see [Extension operator](#extension-operator) — posts a record consisting of:

- An array of **pausing addresses** (off-chain consumers act on these to pause TEE machinery).
- An array of **governance hashes** to which the record is bound. The hashes must be known to the extension (validated via `isGovernanceHashValid`) and must be distinct. Each bound hash gets its own *approval* (signers, signatures, and a per-hash `thresholdMet` flag).

The signed `messageHash` is `SignedPayload.messageHash(TEE_PAUSING_ADDRESSES, keccak256(abi.encode(extensionId, nonce, governanceHashes, pausingAddresses)))` — the outer [`SignedPayload`](../../../contracts/utils/lib/SignedPayload.sol) envelope adds the `TEE_PAUSING_ADDRESSES` domain prefix and binds `block.chainid`; the inner `dataHash` binds the record body. Signers EIP-191 sign this hash. A single `signTeePausingAddresses(extensionId, nonce, signature)` call iterates the bound hash list and deposits the signature into **every** approval the signer is valid under (a signer in two hashes contributes to both). When any approval's signature count first reaches its hash-specific threshold, `TeePausingAddressesThresholdMet(extensionId, nonce, governanceHash)` fires; signature collection continues across all approvals regardless.

Because each record's bound hash list is immutable once set, "old signers can still sign" is preserved automatically: if governance rotates to a new hash after a record is created, the rotated-out signers from the bound hash can still sign that record indefinitely.

## Machine path manager

[`MachinePathManagerFacet`](../../../contracts/tee/facets/MachinePathManagerFacet.sol) is a *generic* governance-signed allow-list of authorized `(sourceTeeIds[], destinationTeeIds[])` paths. It carries no protocol semantics of its own — it just records which TEE machine pairs an extension's governance has approved for some downstream flow. Two facets currently consume it: [`WalletBackupManagerFacet.directBackup` / `directRestore`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol) and [`ReplicationFacet.replicateFrom`](../../../contracts/tee/facets/ReplicationFacet.sol). The primitive is reusable for any future "governance-attested TEE-to-TEE authorization" need.

### Shape

A **path list** lives at `(extensionId, nonce)`. Storage is per-extension: each extension keys its lists by 1-based nonce in a `mapping(nonce => MachinePathList)`, and `listCount[extensionId]` is the highest nonce minted. (A nonce-keyed mapping rather than a dynamic array is deliberate: `MachinePathList` / `MachinePathState` carry mappings and could gain fields in a future facet upgrade, and a dynamic array of such structs would shift every element's storage on an in-place upgrade — mapping values stay append-safe.) Nonces start at 1 per extension. A list contains:

- **Paths** — a `mapping(index => MachinePathState)` keyed `0..pathCount` (same append-safe rationale as the list mapping above), each `MachinePathState` wrapping a `MachinePath { address[] sourceTeeIds; address[] destinationTeeIds; }` plus per-path source/destination membership lookups. Semantics within one path are many-to-many: any source ∈ A may authorize the action against any destination ∈ B.
- **Involved governance hashes** — the union of the per-machine `governanceHash` of every teeId ever added to any path on this list, regardless of role. Each teeId's hash is read directly from `MachineManager.TeeMachineState.governanceHash`, which the machine committed to at registration time (and which is updated when a machine is the destination of a replication). The teeId must have a non-zero hash recorded (`GovernanceHashZero(teeId)` otherwise); no status check is enforced — a freshly registered destination in `INITIALIZED` status is eligible, which is what makes the path-list authorization for replication possible. A single path may mix multiple governances within its source list, its destination list, or both — the primitive treats it as a list-wide set; no per-path hash tracking.
- **Signatures** — collected from every involved governance, stored once per unique signer in a global array. A signature counts toward every involved governance the signer belongs to (a signer in two governances contributes to both with a single submission).
- **`messageHash`** — set when the list is finalized; computed as `SignedPayload.messageHash(TEE_MACHINE_PATH_LIST, keccak256(abi.encode(extensionId, nonce, paths)))`. The [`SignedPayload`](../../../contracts/utils/lib/SignedPayload.sol) envelope adds the `TEE_MACHINE_PATH_LIST` domain prefix and binds `block.chainid`; the inner `dataHash` binds `(extensionId, nonce, paths)`. Signers EIP-191 sign this hash. The same content with a different `(extensionId, nonce)` produces a different hash, preventing cross-chain, cross-extension, and cross-list signature replay.

### Lifecycle

Steps 1–3 are the *prep* steps: they record state that is inert until governance signs. They are gated by the extension owner *or* the optional extension operator (see [Extension operator](#extension-operator)). Steps 4–5 are the actual security gate.

1. **Create** — `createNewMachinePathList(extensionId)`. A fresh nonce is allocated; the list is empty.
2. **Add paths** — `addMachinePaths(extensionId, nonce, paths)` (potentially across multiple calls). For each teeId in each path, the library:
   - Verifies the teeId belongs to this extension (`ExtensionIdMismatch` from `ITeeCommonErrors` otherwise).
   - Reads the teeId's stored `governanceHash` from `MachineManager.TeeMachineState` and verifies it is non-zero (`GovernanceHashZero(teeId)` otherwise). Any TEE status — including `INITIALIZED` — is accepted; the consuming facet re-checks status at trigger time (`directBackup` requires `PRODUCTION`, `replicateFrom` requires `PAUSED_FOR_UPGRADE` / `INITIALIZED` / `REPLICATING`).
   - Adds the governance hash to the list's involved-governance set.
   - Rejects duplicate teeIds within a single path (`SourceTeeIdAlreadyExists`, `DestinationTeeIdAlreadyExists`).
3. **Finalize** — `finalizeMachinePathList(extensionId, nonce)`. The library computes `messageHash` and emits `MachinePathListFinalized` with the involved-governance hashes so off-chain signers know which sets need to sign. After this, no further paths can be added.
4. **Sign** — anyone may relay a signature. `signMachinePathList(extensionId, nonce, signature)` recovers the signer (EIP-191), iterates the involved-governance set, and increments the per-governance count for every governance the signer is a member of. The same signer cannot be counted twice — `signerHasSigned[signer]` dedup. A signature that recovers to nobody-in-any-governance reverts `UnrecognizedSigner`.
5. **Activate** — the list automatically transitions to active once every involved governance has reached its threshold (each governance's threshold comes from `ExtensionGovernance.getTeeGovernanceThreshold`). `MachinePathListSigned` fires, and if the nonce strictly exceeds the extension's current active nonce, `extensionActiveListNonce[extensionId]` is updated.

### Replay / deprecation model

Only the **latest-nonce signed list** per extension is active. Older signed lists are deprecated automatically:

- The active pointer is `extensionActiveListNonce[extensionId]`, set during sign-completion when `_nonce > current`.
- Signing an older-nonce list *after* a newer one is already active does **not** demote the newer one — the older list becomes "signed but not active".
- Consumers (`directBackup` / `directRestore`, `replicateFrom`) look up paths via [`MachinePathManager.requireActiveListNonceForPath`](../../../contracts/tee/library/MachinePathManager.sol), which reverts `NoActiveMachinePathList` if the extension has none yet and `InvalidMachinePath` if the pair isn't present in the currently-active list.

The nonce binding (in `messageHash`) and the latest-wins activation rule together produce a clean "rotate-by-replacement" pattern: extension governance signs a new list, and the old paths are immediately superseded.

## Owner allowlist

`OwnerAllowlistFacet` maintains, **per extension**, the set of addresses authorized to register TEE machines for that extension. Implemented by `OwnerAllowlist` library with one storage namespace.

Entry points:

- `addAllowedTeeMachineOwners(extensionId, owners[])` — add addresses to the allowlist.
- `removeAllowedTeeMachineOwners(extensionId, owners[])` — remove them. Existing machines owned by an address are unaffected; only future registrations are blocked.
- `isAllowedTeeMachineOwner(extensionId, ownerAddress)` — view. (There is also an "allow all" toggle pair, `allowAllTeeMachineOwners` / `disallowAllTeeMachineOwners`, per extension.)

Only the extension owner can mutate (or for `extensionId == 0`, system governance).

The allowlist is separate from the **governance signers** because an extension may want different administrative roles for different actions: the governance signers approve software upgrades; the allowlist controls who can register hardware. Both are extension-scoped.

## Extension operator

Each extension can optionally designate one **operator** address. The operator is a *prep helper*: it can drive the multi-step owner-only flows whose effective security gate is a downstream governance threshold signature, but it cannot do anything an owner can do unilaterally.

Concretely, the operator (when set) may call exactly four prep methods:

- `MachinePathManagerFacet.createNewMachinePathList`
- `MachinePathManagerFacet.addMachinePaths`
- `MachinePathManagerFacet.finalizeMachinePathList`
- `ExtensionPausingFacet.setTeePausingAddresses`

All four create records that remain inert until the extension's governance signers sign them on-chain — the operator cannot produce that signature.

The operator is set (and cleared, by passing `address(0)`) by the extension owner via `ExtensionManagerFacet.setExtensionOperator(extensionId, operator)`. It is the *owner*, not the operator, who controls who the operator is — an operator cannot rotate themselves. The setter works for every extension, including the system extension id 0; for id 0 the caller must be the FlareGovernance governance address (i.e. a direct tx from the governance multisig). The current operator is read back via `getExtensionOperator(extensionId)` and may be `address(0)` if no operator is set. The `ExtensionOperatorSet` event carries `(extensionId, oldOperator, newOperator)`.

Motivating use case: when the extension owner is a multisig identical to the governance signer set (common for the id-0 system extension), every prep step would otherwise require the multisig to sign an on-chain tx *and* later the same signers contribute to the on-chain threshold signature — double work for what is, security-wise, a single decision. With an operator installed, prep happens via ordinary EOA transactions; governance only signs once.

The operator's blast radius is bounded: it can create wrong / spammy / unsignable records, but cannot make them take effect. Operations the owner needs to remain fully accountable for (ownership transfer, governance-signer rotation, allowlist management, ban/unban, code-hash configuration, emergency-pauser delegation) stay owner-only.

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
