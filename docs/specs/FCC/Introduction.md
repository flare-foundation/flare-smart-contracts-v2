# Introduction to FCC

**Flare Confidential Compute (FCC)** extends Flare with **Trusted Execution Environments** (TEEs) — isolated, attested compute units that run specified code, hold cryptographic keys securely, and produce signed responses to instructions submitted on Flare. FCC is what lets a smart contract on Flare ask "sign this XRPL transaction with the wallet's secret key" or "verify this Bitcoin payment and attest to it" without the chain itself ever seeing the secret key or running the verification.

The on-chain side of FCC lives in [`contracts/tee/`](../../../contracts/tee/) and is implemented as a single **EIP-2535 diamond proxy** — the [`FlareTeeManager`](https://github.com/flare-foundation/flare-smart-contracts-v2/tree/tee-diamond-cut/contracts/tee) — with around 22 facets and 20 libraries. The off-chain side (TEE machine software, TEE proxy, relay clients) lives in other Flare repositories and is not described here.

> "TEE" and "FCC" are the same protocol — see [Terminology / TEE vs FCC](../Terminology.md#a-note-on-names-tee-vs-fcc-fdc-vs-fdc2). The hardware concept "a TEE" still applies to one machine. Code keeps the `Tee*` prefix as the contract-name pattern.

## What FCC does

Three things, layered:

1. **Manage TEE machines.** Register them, attest to their state, replicate them for high-availability, control their lifecycle (initialized → production → paused → upgraded). Owners are administered via an allowlist; only allowlisted addresses can register machines for a given extension.
2. **Manage protocol-managed wallets and keys.** A *wallet* is a secret key (or set of keys) generated and stored across one or more TEE machines. Users create wallets, generate keys, back them up via Shamir secret sharing, and restore them. Each key has a **key admin** set that participates in backup decryption and restore approval.
3. **Execute signed instructions.** Users submit instructions through smart contracts on Flare; the orchestrator routes them to a chosen set of TEE machines, which verify them, execute the requested operation, and sign the response. Different operation types do different things — sign an XRPL payment, verify an FDC2 attestation, prove a VRF, run an extension's custom logic.

All three sit on top of an **extension** model — FCC is multi-tenant. The default tenant is the **system extension** (extension ID 0), Flare-operated, which currently hosts two applications: **FDC2** (the Flare Data Connector v2) and **PMW** (Protocol-Managed Wallet for XRPL). FDC2 and PMW are not separate extensions — they share `extensionId == 0`, the same TEE machines, and the same governance, but use different `opType` namespaces (`F_FDC2`, `F_WALLET`) for dispatch. Anyone (with governance approval) can register their own extension (extensionId ≥ 1), deploy their own TEE machines for it, and define their own applications and instructions.

## Off-chain actors

A high-level cast (full definitions in [Terminology](../Terminology.md)):

- **TEE operator.** Deploys and runs the actual TEE machines (typically Confidential VMs on Google or Azure) along with their TEE proxies. Each machine has a unique on-chain identity address (`teeId`) and an associated public key.
- **Data provider** (also "voter"). Same role as in FSP / FTSO / FDC. Runs a *relay client* that monitors Flare for instruction events, signs each instruction with its FSP signing-policy address, and forwards it to the relevant TEE proxies.
- **Project owner.** A Flare address that creates and administers a *project* — a collection of wallets and configurations within an extension. Controls wallet creation and key management.
- **Key admin.** A member of a per-wallet admin set whose public keys participate in Shamir backup encryption. Threshold-of-N admins can approve key restore operations.
- **Cosigner.** An address that's optionally required to additionally sign an instruction (per-instruction multisig). Used when an application wants stricter authorization than just the FSP signing policy.
- **Governance signer.** An address registered on-chain in a per-extension governance set (separate from system governance). Used for extension upgrades.

## How instructions flow

The headline flow is **smart contract → instruction event → relay → TEE → signed response → consumer**:

1. A user (or a contract acting on their behalf) calls a facet on `FlareTeeManager` — typically `InstructionsFacet.sendInstructions(...)` or, for the system extension, a system-only entry point — with FLR attached for the operation fee.
2. The facet's library validates the call (right caller, valid TEE set, correct fee), routes the fee to `RewardManager`, and emits a `TeeInstructionsSent` event.
3. **Off-chain**: each registered relay client picks up the event, signs it with its FSP signing-policy key, and forwards the signed instruction to each TEE proxy.
4. Each TEE proxy collects relay client signatures and any cosigner signatures. When enough weight has accumulated (FSP signing-policy threshold for ordinary operations, or per-instruction `thresholdBIPS` for FDC2 / extensions), the proxy hands the instruction to its TEE machine for execution.
5. The TEE machine runs the operation in its isolated environment, signs the response with its identity key (or a key it custodies), and returns it to the proxy.
6. The off-chain layer delivers the signed response back to the originator — either by submitting it as a transaction on Flare (where a verifier contract checks the signatures) or by routing it to another chain.

The on-chain contracts mostly emit and verify; the heavy lifting (running TEE machine code, collecting threshold signatures, delivering responses) is off-chain. The next docs in this section detail each on-chain piece.

## Where FCC sits relative to the rest of the system

- **FSP** publishes the signing policy that relay clients use to sign instructions. FCC reads `flareSystemsManager.getCurrentRewardEpochId()` and the signing-policy hash from `Relay`, and relies on the FSP-distributed sortition seed for randomness (e.g. `getRandomTeeIds`).
- **FDC2** is one of the applications offered by the system extension. `Fdc2Hub.requestAttestation` ultimately calls `FlareTeeManager.sendSystemInstructions` to dispatch a `(F_FDC2, "PROVE")` instruction to system-extension TEE machines through the FCC instruction pipeline (see [Extensions](./Extensions.md)).
- **Reward distribution.** All FCC operation fees flow into `RewardManager` as community offers (just like FDC user fees). The off-chain reward calculator distributes them to data providers (relay clients), TEE operators, and cosigners according to per-extension rules. There is also a `TeeRewardOffersManager` for FCC-specific inflation rewards (see [Rewarding](./Rewarding.md)).

## Why a diamond proxy

FCC is large. The full set of functionality — machine lifecycle, replication, key management across multiple wallets, multiple operation types, fee schedule, governance, replication groups, payments, registry, upgrade flow — easily exceeds the EIP-170 24KB contract-size limit. The diamond proxy lets the system run as a single externally-addressable contract while internally splitting logic across many facets. Each facet is small (often under 5KB); each library holds the per-namespace business logic and storage.

The split also gives FCC a natural upgrade story: governance can replace one facet (say, swap out `MachineManagerFacet` to fix a bug or add a feature) without touching the others. This is more granular than a UUPS-style "upgrade the whole implementation" model.

The architectural details are in [Architecture](./Architecture.md).
