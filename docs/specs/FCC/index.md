# Flare Confidential Compute (FCC)

FCC extends Flare with **Trusted Execution Environments** (TEEs): isolated cloud-VM environments that run specified code, store keys securely, and attest to their state. Users issue instructions to TEEs through smart contracts on Flare; data providers relay them to TEE machines; TEE machines execute the instructions and return signed results — transactions for external chains, signed attestations, VRF outputs, and so on.

The FCC contracts live under [`contracts/tee/`](../../../contracts/tee/) and are organized as a single EIP-2535 **diamond proxy** — [`FlareTeeManager`](../../../contracts/tee/) — with around 22 facets and 15 libraries. The diamond layout is the headline difference from earlier FCC drafts (which described separate contracts for TEE management, payments, governance, etc.); these docs describe the diamond-cut implementation that is currently on the `tee-diamond-cut` branch.

> "TEE" and "FCC" are the same protocol. The hardware concept "a TEE" still appears (one machine), but the protocol section is **FCC**. Code keeps the `Tee*` prefix for contract names.

## Documents

- [Introduction](./Introduction.md) — what FCC is, why TEEs, where it sits relative to FDC2
- [Architecture](./Architecture.md) — the `FlareTeeManager` diamond, facets, libraries, ERC-7201 storage
- [Machine lifecycle](./MachineLifecycle.md) — registration, state, attestation, eviction (`MachineManagerFacet`)
- [Replication](./Replication.md) — replication groups (`ReplicationFacet`, `ReplicationInit`)
- [Key management](./KeyManagement.md) — generate, restore, delete; VRF keys (`WalletKeyManagerFacet`, `VrfFacet`)
- [Wallet management](./WalletManagement.md) — `WalletManagerFacet`, `WalletBackupManagerFacet`, `WalletProjectManagerFacet`, `WalletResumeFacet`
- [Instructions](./Instructions.md) — fee-validated TEE instruction sending and system instructions (`InstructionsFacet`)
- [Operation fees](./OperationFees.md) — `OperationFeesFacet`, `TeePayments` suite, fee schedules and limits
- [Verification](./Verification.md) — `VerificationFacet`, `VrfFacet`, `SystemStateVerifierFacet`, `VrfVerifier`
- [Extensions](./Extensions.md) — `ExtensionManagerFacet` + the system extension's currently-hosted applications (FDC2, PMW)
- [Governance](./Governance.md) — `DiamondGovernanceFacet`, `OwnerAllowlistFacet`, `UpgradeManagerFacet`, `ExternalAddressesFacet`
- [Rewarding](./Rewarding.md) — `TeeRewardOffersManager`

## Key contracts and code layout

```
contracts/tee/
├── facets/          # ~22 facets, thin delegates
├── library/         # ~15 libraries, business logic
├── interface/       # II* internal interfaces (facet ↔ library)
├── implementation/  # FlareTeeManager + shared utility contracts (TeePayments, TeeRewardOffersManager, ...)
├── proxy/           # beacon proxies for TEE-managed accounts
├── structs/         # shared data structures
└── mock/            # test mocks
```

Public interfaces — about 20 `I*.sol` files (`IFlareTeeManager`, `IExtensionManager`, `IInstructions`, `IMachineManager`, `IOperationFees`, `IOwnerAllowlist`, `IReplication`, `ISystemStateVerifier`, `IUpgradeManager`, `IVerification`, `IVrf`, `IVrfVerifier`, `IWalletManager`, `IWalletKeyManager`, `IWalletBackupManager`, `IWalletProjectManager`, `IWalletResume`, `IExtensionGovernance`, `IExtensionPausing`, `IFlareGovernance`, `IDiamondGovernance`) — live in [`contracts/userInterfaces/`](../../../contracts/userInterfaces/).
