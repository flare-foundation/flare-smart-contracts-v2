# FCC Architecture

FCC is a single EIP-2535 diamond proxy. One address (`FlareTeeManager`) on Flare; internally, every state-changing call is routed via `delegatecall` to one of around 22 facets, each holding a small slice of behavior. State lives in **ERC-7201 namespaced storage** so facets can be added, replaced, or removed without storage collisions.

This page describes the on-chain layout: how the diamond is constructed, how facets and libraries split responsibilities, the storage model, and how the auxiliary `TeePayments*` contracts plug in around the diamond.

## The diamond pattern

[`Diamond`](../../../contracts/diamond/implementation/Diamond.sol) is a generic EIP-2535 implementation (Nick Mudge's reference). Its `fallback()` looks up the facet for `msg.sig` from `LibDiamond.diamondStorage().facetAddressAndSelectorPosition` and `delegatecall`s into it:

```solidity
fallback() external payable {
    LibDiamond.DiamondStorage storage ds;
    bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
    assembly { ds.slot := position }
    address facet = ds.facetAddressAndSelectorPosition[msg.sig].facetAddress;
    if (facet == address(0)) revert FunctionNotFound(msg.sig);
    assembly {
        calldatacopy(0, 0, calldatasize())
        let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
        returndatacopy(0, 0, returndatasize())
        switch result case 0 { revert(0, returndatasize()) } default { return(0, returndatasize()) }
    }
}
```

[`LibDiamond`](../../../contracts/diamond/libraries/LibDiamond.sol) is the standard library that holds the function-selector → facet-address mapping and the `diamondCut` implementation. [`DiamondLoupeFacet`](../../../contracts/diamond/facets/DiamondLoupeFacet.sol) provides the standard introspection methods (`facets`, `facetFunctionSelectors`, `facetAddresses`, `facetAddress`).

The diamond is initialized via [`FlareTeeManagerInit`](../../../contracts/tee/facets/FlareTeeManagerInit.sol) — a non-facet contract whose `init(...)` is `delegatecall`-invoked once during the diamond's first `diamondCut`. It:

- Marks the standard ERC-165 interfaces (`IERC165`, `IDiamondCut`, `IDiamondLoupe`).
- Initializes `FlareGovernance` storage (the diamond's own governance — separate from system `Governor` for FCC-internal operations).
- Sets the address-updater value used by `ExternalAddressesFacet`.
- Initializes verification settings (availability check / signing policy / challenge validity durations).
- Sets `OperationFees.defaultFee`.
- Initialises `nextPublicExtensionId` to `65536` so public registrations via `register()` start at ID `65536`. IDs `1..65535` are the reserved range (governance-minted via `registerReserved`); ID `0` is the system extension.
- Initialises the global extension-owner allowlist's `allExtensionOwnersAllowed` flag from the `teePublicExtensionCreationEnabled` deploy parameter (open on testnets, closed on mainnets).

## Facets, libraries, interfaces

The on-chain code separates into three layers:

**Facets** (`contracts/tee/facets/*.sol`) — thin entry points. Each facet declares the external selectors that should dispatch to it and contains minimal logic — argument validation, access checks, and a call into the corresponding library.

**Libraries** (`contracts/tee/library/*.sol`) — hold the actual business logic and the namespaced storage struct for that subsystem. Marked with `@custom:storage-location erc7201:tee.<LibName>.State`. Multiple facets can call the same library; the storage layout is owned by the library, not by any single facet.

**Interfaces** — split between two trees:
- `contracts/userInterfaces/tee/I*.sol` — public ABI surface (what consumers and integrators see). Examples: `IFlareTeeManager`, `IInstructions`, `IMachineManager`, `IOperationFees`.
- `contracts/tee/interface/II*.sol` — internal interfaces used between FCC pieces and by other modules (`Fdc2Hub` imports `IIFlareTeeManager`). The `II*` prefix marks these as internal.

The 22 facets and what they expose:

| Facet | Library | What it does |
|-------|---------|--------------|
| [`DiamondGovernanceFacet`](../../../contracts/tee/facets/DiamondGovernanceFacet.sol) | (`LibDiamond`) | The `diamondCut` entry point — adds, replaces, or removes facets. Also exposes `IFlareGovernance` (set initial governance, time-locked governance changes). |
| [`ExtensionGovernanceFacet`](../../../contracts/tee/facets/ExtensionGovernanceFacet.sol) | `ExtensionGovernance` | Per-extension governance: configure signers and threshold, expose the latest governance hash and per-hash signer/threshold getters. Day-1 facet. |
| [`ExtensionPausingFacet`](../../../contracts/tee/facets/ExtensionPausingFacet.sol) | `ExtensionPausing` | Per-extension pausing-addresses records bound to one or more governance hashes; per-approval signature collection; per-hash threshold-met events. Later facet. |
| [`ExtensionManagerFacet`](../../../contracts/tee/facets/ExtensionManagerFacet.sol) | `ExtensionManager` | Register / configure extensions; manage owner allowlists, supported `(codeHash, platform)` versions per extension. |
| [`ExternalAddressesFacet`](../../../contracts/tee/facets/ExternalAddressesFacet.sol) | `ExternalAddresses` | The diamond's `AddressUpdatable` hook. Stores `flareSystemsManager`, `rewardManager`, etc. in the diamond's own ERC-7201 slot. |
| [`FlareGovernedAccess`](../../../contracts/governance/implementation/FlareGovernedAccess.sol) (inherited by every non-governance facet) and [`DiamondGovernanceFacet`](../../../contracts/tee/facets/DiamondGovernanceFacet.sol) (inherits [`FlareGovernedBase`](../../../contracts/governance/implementation/FlareGovernedBase.sol) for the public API) | (`FlareGovernance`) | Diamond-internal `onlyGovernance` modifier (all facets) and the public `Governed` accessors / `diamondCut` (only `DiamondGovernanceFacet`). |
| [`InstructionsFacet`](../../../contracts/tee/facets/InstructionsFacet.sol) | `Instructions` | The main `sendInstructions` entry — fee-validated TEE instruction dispatch. Also: register / unregister system-instructions sender contracts. |
| [`MachineEmergencyPauseFacet`](../../../contracts/tee/facets/MachineEmergencyPauseFacet.sol) | `MachineEmergencyPause` | Per-extension emergency-pause overlay + pauser/unpauser delegation lists. While an extension is emergency-paused, `Instructions.sendInstructions` rejects every dispatch (regular and system opTypes) targeting machines in the paused extension. Statuses and active sets are untouched; off-chain readers should consult `isExtensionEmergencyPaused`. After unpause, a governance-tunable grace window blocks third-party expired-availability `pause()` calls so owners can refresh attestations. Day-1 facet. |
| [`MachineManagerFacet`](../../../contracts/tee/facets/MachineManagerFacet.sol) | `MachineManager` | TEE machine registration, status changes (initialized → production → paused → upgraded), ownership transfers, attestation acceptance. |
| [`MachinePathManagerFacet`](../../../contracts/tee/facets/MachinePathManagerFacet.sol) | `MachinePathManager` | Per-extension governance-signed allow-list of `(sourceTeeIds[], destinationTeeIds[])` paths. Generic primitive; gates [`WalletBackupManagerFacet.directBackup` / `directRestore`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol) and [`ReplicationFacet.replicateFrom`](../../../contracts/tee/facets/ReplicationFacet.sol). Day-1 facet. |
| [`OperationFeesFacet`](../../../contracts/tee/facets/OperationFeesFacet.sol) | `OperationFees` | Per-extension, per-`(opType, opCommand)` fee schedule. Lookup methods used by `InstructionsFacet` to compute the required fee. |
| [`OwnerAllowlistFacet`](../../../contracts/tee/facets/OwnerAllowlistFacet.sol) | `OwnerAllowlist` | Per-extension allowlist of TEE-machine owners. Only allowlisted addresses can register machines for that extension. |
| [`ReplicationFacet`](../../../contracts/tee/facets/ReplicationFacet.sol) | `Replication` | TEE machine replication: pair primary and replicate machines, control replication state. Authorisation is delegated to [`MachinePathManagerFacet`](../../../contracts/tee/facets/MachinePathManagerFacet.sol). |
| (library only) `SystemStateVerifier` | — | Cross-checks the TEE-attested `TeeSystemState { status, initialTeeId }` payload against the chain's stored `initialTeeId`. Library-only (no diamond facet exposes it externally); consumed by `Verification._validateResponseBody`. Single uniform strict-compare path — callers `toProduction` / `replicateFrom` pre-commit the expected `initialTeeId` at `INITIALIZED → out` transitions so the comparison succeeds iff the TEE attests it. |
| [`VerificationFacet`](../../../contracts/tee/facets/VerificationFacet.sol) | `Verification` | Verify TEE attestation data (availability checks, code hash, platform), signing policies, challenges. |
| [`VrfFacet`](../../../contracts/tee/facets/VrfFacet.sol) | `Vrf` | Verifiable random function over TEE keys. |
| [`WalletBackupManagerFacet`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol) | `WalletKeyManager` | Wallet key backup (Shamir secret-sharing) — submit shares, finalize backup. |
| [`WalletKeyManagerFacet`](../../../contracts/tee/facets/WalletKeyManagerFacet.sol) | `WalletKeyManager` | Generate / delete keys; restore keys from admin shares. |
| [`WalletManagerFacet`](../../../contracts/tee/facets/WalletManagerFacet.sol) | `WalletManager` | Per-extension wallet creation, owner administration, key admin set updates. |
| [`WalletProjectManagerFacet`](../../../contracts/tee/facets/WalletProjectManagerFacet.sol) | `WalletProjectManager` | Project-level configuration (a *project* groups multiple wallets under one owner). |
| [`WalletProjectPauseFacet`](../../../contracts/tee/facets/WalletProjectPauseFacet.sol) | `WalletProjectPause` | Per-project pauser/unpauser delegation lists, plus the `pauseWallets`/`unpauseWallets` batch actions. The project owner adds addresses to the pauser list (authorized to pause project wallets, `PRODUCTION → PAUSED`) and the unpauser list (authorized to resume from `PAUSED → PRODUCTION`). Day-1 facet. |
| [`WalletResumeFacet`](../../../contracts/tee/facets/WalletResumeFacet.sol) | `WalletResume` | Resume wallet operations after pause / upgrade. |

Two non-facet init helpers ([`FlareTeeManagerInit`](../../../contracts/tee/facets/FlareTeeManagerInit.sol), [`ReplicationInit`](../../../contracts/tee/facets/ReplicationInit.sol)) are used only during `diamondCut` for initial / migration-time storage setup.

## ERC-7201 namespaced storage

Each library declares its storage struct at a deterministic, collision-free slot:

```solidity
bytes32 internal constant STATE_POSITION = keccak256(
    abi.encode(uint256(keccak256("tee.MachineManager.State")) - 1)
) & ~bytes32(uint256(0xff));

function getState() internal pure returns (State storage _state) {
    bytes32 position = STATE_POSITION;
    assembly { _state.slot := position }
}
```

The `& ~0xff` mask is the ERC-7201 convention — it sets the low byte to zero, leaving 248 bits of address space below the slot for arrays / mappings rooted there.

Because slots are derived from the library's name (`"tee.MachineManager.State"`, `"tee.OperationFees.State"`, etc.), libraries cannot collide. Replacing a facet that uses `MachineManager` with a new version that still calls `MachineManager.getState()` reads the same storage — the data persists across facet upgrades.

## How the libraries call each other

Libraries are not `delegatecall`-isolated like facets — they are linked at compile time and inline into whichever facet imports them. So `Instructions.sendInstructions` can directly call `MachineManager.getExtensionId(teeId)` — both libraries operate on the diamond's own storage, just at different namespaced slots.

Cross-library reads are extensive — `Instructions` consults `MachineManager`, `OperationFees`, and `ExternalAddresses` to validate, fee-calculate, and emit. `MachineManager` consults `ExtensionManager`. `WalletKeyManager` consults `WalletManager` and `WalletProjectManager`. The dependency graph is roughly:

```
                    FlareGovernance ─┐
                                     │
ExternalAddresses ←── (most libraries)
                                     │
ExtensionManager ←── MachineManager ←── Instructions ←── (most facets)
                  ↑                  ↑
                  │                  ├── OperationFees
                  │                  ├── Verification
                  │                  ├── SystemStateVerifier
                  │                  └── Replication
                  │
                  └── WalletProjectManager ←── WalletManager ←── WalletKeyManager
                                                                      │
                                                                      ├── WalletBackupManager (uses same lib)
                                                                      └── WalletResume
                                            MachinePathManager ←── ExtensionGovernance
                                                                    ↑
                                                         (read by ReplicationFacet.replicateFrom and
                                                          WalletBackupManager.directBackup/directRestore)
                                            Vrf (own state, calls MachineManager)
                                            OwnerAllowlist (own state)
```

## TeePayments — outside the diamond

A few accounting contracts sit *outside* the diamond, deployed as their own UUPS-upgradeable proxies. They handle fee schedules and limits for **extension-level** payment operations (separate from the per-instruction fees collected by `OperationFees` inside the diamond):

| Contract | Role |
|----------|------|
| [`TeePaymentsBase`](../../../contracts/tee/implementation/TeePaymentsBase.sol) | Abstract base for the payment contracts: UUPS/governance/`AddressUpdatable`, shared account/auth/wallet-status state and the `pay`/`reissue` plumbing. |
| [`TeePayments`](../../../contracts/tee/implementation/TeePayments.sol) | Account-model payment contract (e.g. XRPL): one native nonce per account, `paymentId`-keyed payments and single-instruction reissue. |
| [`TeePaymentsUtxo`](../../../contracts/tee/implementation/TeePaymentsUtxo.sol) | UTXO/anchor-model payment contract (e.g. BTC): per-anchor nonce streams with round-robin anchor selection, grow-only anchor sets, payment batches, and reissue/replacement tracking (records the exact reissue block list). |
| [`TeePaymentsConfigVerifier`](../../../contracts/tee/implementation/TeePaymentsConfigVerifier.sol) | Shared request + verify contract for PMW multisig configuration attestations (both account and UTXO). Requests live only here; the payment contracts call `verify{Account,Utxo}ConfiguredProof` (validate-only — reverts on an invalid proof, returns nothing) and write state read directly from the calldata proof. Reuses [`Fdc2ProofVerification`](../../../contracts/fdc2/library/Fdc2ProofVerification.sol). |
| [`TeePaymentsFeeScheduleManager`](../../../contracts/tee/implementation/TeePaymentsFeeScheduleManager.sol) | Per-extension fee schedules (which operations cost how much, when changes take effect). |
| [`TeePaymentsLimitsManager`](../../../contracts/tee/implementation/TeePaymentsLimitsManager.sol) | Per-extension payment caps and rate limits. |
| [`TeePaymentsRegistry`](../../../contracts/tee/implementation/TeePaymentsRegistry.sol) | Registry of `sourceId → TeePayments` bindings (with each source's `keyType`/`opType`/`paymentModel`); the diamond's `OperationFeesFacet` and the payment/verifier/manager contracts consult it. |
| [`TeeRewardOffersManager`](../../../contracts/tee/implementation/TeeRewardOffersManager.sol) | Inflation receiver / community offers manager for FCC. Mirrors `FtsoRewardOffersManager` and `FdcHub` — see [Rewarding](./Rewarding.md). |
| [`VrfVerifier`](../../../contracts/tee/implementation/VrfVerifier.sol) | Stand-alone VRF verifier contract. Verifies VRF proofs produced by FCC's `VrfFacet`. |

Each has its own UUPS proxy in [`contracts/tee/proxy/`](../../../contracts/tee/proxy/). They communicate with the diamond through `AddressUpdatable` (the diamond's `ExternalAddressesFacet` holds *their* addresses; they hold the diamond's address).

## Structs

Cross-library structs live in [`contracts/tee/structs/`](../../../contracts/tee/structs/). The most important:

- `TeeMachineStructs` — `TeeMachine`, `TeeMachineWithAttestationData`, `TeeStatus` enum.
- `TeeInstructionsStructs` — `TeeInstructionParams` (the body of an instruction), `TeeOperationParams`.
- `TeePaymentsStructs` — payment / fee schedule structs.
- `TeeWalletStructs` — wallet, key, admin set structs.
- `TeeReplicationStructs` — replication payload structs (`PauseForUpgrade`, `ReplicateTeeMachine`).
- `TeeMachinePathStructs` — machine path lists (`MachinePath` exposer for ABI codegen).
- `TeeVerificationStructs`, `TeeVrfStructs` — verification-flow specifics.

## What's "in" the diamond vs "around" it

| Inside the diamond (one facet → one library) | Outside, separate UUPS proxy |
|----------------------------------------------|------------------------------|
| Instruction dispatch | TEE payment accounting |
| Machine registration / lifecycle | Fee schedule (per extension) |
| Replication groups | Limits / rate caps |
| Wallet / key / admin management | Reward offers manager |
| Operation fees & schedule lookup | VRF verifier (stand-alone) |
| Diamond governance (ERC-2535 cut) | |
| Per-extension governance | |
| Owner allowlist | |
| Upgrade manager | |
| Verification | |

The split was deliberate: anything that needs a stable address that *other* contracts (like `Fdc2Hub`) call into, or that needs its own UUPS upgradeability separate from a diamond cut, lives outside. Everything else is a facet.

## Reading the live diamond

Standard EIP-2535 introspection works on `FlareTeeManager`:

- `facets()` — full list of `(facetAddress, selectors[])`.
- `facetFunctionSelectors(facet)` — which selectors a given facet exposes.
- `facetAddresses()` — every distinct facet address.
- `facetAddress(selector)` — which facet handles a given selector.

Off-chain tooling (block explorers, scripts) uses these to enumerate the live diamond. After every governance `diamondCut`, the answer changes; the loupe is the source of truth for what's currently deployed.
