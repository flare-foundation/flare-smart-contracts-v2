# Introduction

## Overview

This repository implements the on-chain side of Flare's enshrined protocols: the **Flare Systems Protocol (FSP)** and its sub-protocols. FSP is the foundational layer — it organizes *who* gets to vote, *when* they vote, and *how* their results are agreed and finalized. The sub-protocols plug into FSP to do specific jobs:

- **FTSO** delivers price feeds (anchor feeds every 90 seconds, block-latency feeds in between).
- **FDC** (and its newer revision **FDC2**) attests to data outside Flare's EVM state — confirmations of Bitcoin payments, EVM transactions on other chains, address validity, and so on.
- **FCC** (Flare Confidential Compute) extends the system with **Trusted Execution Environments** (TEEs). Users submit instructions on Flare; data providers relay them to TEE machines; the TEE machines execute and sign results. FCC's system extension currently hosts two Flare-operated applications: **FDC2** (the Flare Data Connector v2) and the **Protocol-Managed Wallet** (PMW) for XRPL.

Around these sit governance, staking, RNat, inflation, and a small number of utilities. The repo does **not** contain off-chain services — data providers, relay clients, TEE proxies, indexers, and the like live in other Flare repositories — but every fact those services depend on (signing policies, reward Merkle roots, fee schedules, attestation requests) is committed to and read from contracts in this repo.

## Off-chain actors and their roles

The protocols here are designed to be operated by a network of registered participants. Most of them appear repeatedly across the docs; a fuller list lives in [Terminology](./Terminology.md).

A **data provider** (sometimes "voter" or "entity") is the central actor. Data providers run validators, accumulate vote power from delegations of the wrapped-native token (`WNat` — `WFLR` on Flare, `WSGB` on Songbird, `WCFLR` on Coston, `WC2FLR` on Coston2) and from validator stakes, register every reward epoch via [`EntityManager`](../../contracts/protocol/implementation/EntityManager.sol) and [`VoterRegistry`](../../contracts/protocol/implementation/VoterRegistry.sol), and submit data — price feeds, attestation votes, signatures — through [`Submission`](../../contracts/protocol/implementation/Submission.sol). They earn rewards in proportion to how well they participate, claimed from [`RewardManager`](../../contracts/protocol/implementation/RewardManager.sol).

**Delegators** are WNat holders who don't run infrastructure themselves. They delegate to a data provider's delegation address and share in that provider's rewards.

**Users** are anyone interacting with the system — a smart contract using FTSO prices, a dApp making an FDC request, a wallet submitting an FCC instruction. Most users only ever read state (price feeds, attestation Merkle proofs) and don't need to register.

**TEE operators**, **project owners**, **key admins**, **cosigners**, and **governance signers** are FCC-specific roles, all defined in the [FCC section](./FCC/index.md).

**Governance** is split: a top-level `Governor` (with timelock) administers most of the system, while FCC has its own diamond-internal governance that the [FCC Governance doc](./FCC/Governance.md) describes.

## Code architecture

The on-chain code is organized by sub-protocol. Each top-level folder under `contracts/` is one of:

| Folder | Purpose |
|--------|---------|
| [`contracts/protocol/`](../../contracts/protocol/) | FSP core: orchestrator, calculator, entity registry, relay, reward state, submission |
| [`contracts/ftso/`](../../contracts/ftso/) | FTSO anchor feeds: feed publisher, decimals, ID conversion, reward offers |
| [`contracts/fastUpdates/`](../../contracts/fastUpdates/) | FTSO block-latency feeds: fast updater, configuration, incentive manager |
| [`contracts/fdc/`](../../contracts/fdc/) | FDC legacy hub, verification, fee configuration |
| [`contracts/fdc2/`](../../contracts/fdc2/) | FDC2 hub, verification, fee configuration |
| [`contracts/tee/`](../../contracts/tee/) | FCC: the `FlareTeeManager` Diamond, all facets, libraries, and TEE payment infrastructure |
| [`contracts/diamond/`](../../contracts/diamond/) | Shared EIP-2535 diamond infrastructure (cut, loupe, namespaced storage) |
| [`contracts/governance/`](../../contracts/governance/) | `Governor`, `Governed`, timelock helpers |
| [`contracts/staking/`](../../contracts/staking/) | Validator reward offers, P-chain stake mirroring |
| [`contracts/rNat/`](../../contracts/rNat/) | RNat token plus per-account `RNatAccount` beacon proxies |
| [`contracts/inflation/`](../../contracts/inflation/), [`contracts/incentivePool/`](../../contracts/incentivePool/) | Inflation and incentive-pool receivers |
| [`contracts/adapters/`](../../contracts/adapters/), [`contracts/customFeeds/`](../../contracts/customFeeds/) | External feed integrations (Chainlink) and custom feeds (sFlr) |
| [`contracts/userInterfaces/`](../../contracts/userInterfaces/) | Public `I*.sol` interfaces — the integration surface |
| [`contracts/utils/`](../../contracts/utils/) | Shared utilities, primarily `AddressUpdatable` (the standard wiring mechanism) |

Inside the larger modules — FSP and FCC especially — code is split further into `implementation/` (the contracts themselves), `interface/` (internal `II*` interfaces used between contracts), and for FCC also `facets/` and `library/` (the diamond-cut split). The narrative docs below follow the protocol flow and cite implementation contracts as needed; the [API reference](./ApiReference.md) is the contract-shaped index pointing back from each module to its public `userInterfaces/I*.sol` files.

## How the protocols connect

The cross-protocol wiring is the subject of [Architecture](./Architecture.md). In one paragraph: every reward epoch, entities **self-register** through `VoterRegistry`; the top entities by weight (up to `maxVoters`, currently `100`) form the **signing policy** for that epoch, which is then published by `FlareSystemsManager` and threshold-signed by the *previous* epoch's voters. Sub-protocols (FTSO, FDC, FCC) all run their voting rounds against the active policy; the resulting Merkle roots are finalized through `Relay`; off-chain consumers (and on-chain verification contracts) prove against those roots. **Reward calculation is off-chain** — sub-protocols' offers managers only collect FLR (from inflation, the incentive pool, and community contributors) and emit events describing offers; the off-chain reward calculator builds a Merkle tree of claims, the active signing policy threshold-signs the resulting reward hash, and only then can beneficiaries claim from `RewardManager`. Inflation and the incentive pool feed the offers managers; governance configures parameters; FCC additionally runs its own confidential-compute layer that the FDC2 attestation hub depends on.
