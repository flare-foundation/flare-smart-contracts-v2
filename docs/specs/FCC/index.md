# Flare Confidential Compute (FCC)

FCC extends Flare with **Trusted Execution Environments** (TEEs): isolated cloud-VM environments that run specified code, store keys securely, and attest to their state. Users issue instructions to TEEs through smart contracts on Flare; data providers relay them to TEE machines; TEE machines execute the instructions and return signed results — transactions for external chains, signed attestations, VRF outputs, and so on.

The FCC contracts live under [`contracts/tee/`](../../../contracts/tee/) and are organized as a single EIP-2535 **diamond proxy** — [`FlareTeeManager`](../../../contracts/tee/) — with 18 facets and 17 libraries. The diamond layout is the headline difference from earlier FCC drafts (which described separate contracts for TEE management, payments, governance, etc.); these docs describe the diamond-cut implementation that is currently on the `tee-diamond-cut` branch.

> "TEE" and "FCC" are the same protocol. The hardware concept "a TEE" still appears (one machine), but the protocol section is **FCC**. Code keeps the `Tee*` prefix for contract names.

## Documents

- [Introduction](./Introduction.md) — what FCC is, why TEEs, where it sits relative to FDC2
- [Architecture](./Architecture.md) — the `FlareTeeManager` diamond, facets, libraries, ERC-7201 storage
- [Machine lifecycle](./MachineLifecycle.md) — registration, state, attestation, eviction (`MachineManagerFacet`)
- [Key management](./KeyManagement.md) — generate, restore, delete; VRF keys (`WalletKeyManagerFacet`, `VrfFacet`)
- [Wallet management](./WalletManagement.md) — `WalletManagerFacet`, `WalletBackupManagerFacet`, `WalletProjectManagerFacet`, `WalletProjectPauseFacet`
- [Instructions](./Instructions.md) — fee-validated TEE instruction sending and system instructions (`InstructionsFacet`)
- [Operation fees](./OperationFees.md) — `OperationFeesFacet`, fee schedules and limits
- [Payments](./Payments.md) — PMW (Protocol Managed Wallet) payment instructing: account vs UTXO models, anchors, batches, reissue (`TeePayments`, `TeePaymentsUtxo`, `TeePaymentsConfigVerifier`)
- [Verification](./Verification.md) — `VerificationFacet`, `VrfFacet`, `SystemStateVerifier` (library), `VrfVerifier`
- [Extensions](./Extensions.md) — `ExtensionManagerFacet` + the system extension's currently-hosted applications (FDC2, PMW)
- [Governance](./Governance.md) — `DiamondGovernanceFacet`, `OwnerAllowlistFacet`, `MachinePathManagerFacet`, `ExternalAddressesFacet`, `MachineEmergencyPauseFacet`
- [Rewarding](./Rewarding.md) — `TeeRewardOffersManager`

## Key contracts and code layout

```
contracts/tee/
├── facets/          # 18 facets, thin delegates
├── library/         # 17 libraries, business logic
├── interface/       # II* internal interfaces (facet ↔ library)
├── diamond/         # FlareTeeManager (the diamond root contract)
├── implementation/  # shared utility contracts (TeePayments suite, TeeRewardOffersManager, VrfVerifier)
├── proxy/           # UUPS proxies for the implementation/ contracts
├── structs/         # shared data structures
└── mock/            # test mocks
```

Public interfaces — the FCC `I*.sol` files (`IFlareTeeManager`, `IExtensionManager`, `IInstructions`, `IMachineManager`, `IMachineEmergencyPause`, `IMachinePathManager`, `IOperationFees`, `IOwnerAllowlist`, `IVerification`, `IVrf`, `IVrfVerifier`, `IWalletManager`, `IWalletKeyManager`, `IWalletBackupManager`, `IWalletProjectManager`, `IWalletProjectPause`, `IExtensionGovernance`, `IDiamondGovernance`, `ITeeRewardOffersManager`, the `ITeePayments*` family, etc.) — live in [`contracts/userInterfaces/tee/`](../../../contracts/userInterfaces/tee/). The cross-cutting `IFlareGovernance` lives one level up in [`contracts/userInterfaces/`](../../../contracts/userInterfaces/).
