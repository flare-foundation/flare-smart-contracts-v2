# Flare Systems Smart Contracts

Specification documents for the on-chain protocols implemented in this repository: the **Flare Systems Protocol (FSP)** and its sub-protocols — the **Flare Time Series Oracle (FTSO)**, the **Flare Data Connector (FDC + FDC2)**, and **Flare Confidential Compute (FCC)** — together with governance, staking, rewards, and supporting modules.

These docs describe protocol-level behavior and the contracts that implement it. Where a doc cites a contract, the link goes to the actual `.sol` file in this repo, which is the source of truth.

## Reading order

- [Introduction](./Introduction.md) — what this repo contains, how the pieces fit together, who interacts with them
- [Architecture](./Architecture.md) — cross-module wiring, the reward-epoch lifecycle, finalization
- [Terminology](./Terminology.md) — roles and concepts referenced throughout

## Sub-protocols

- [Flare Systems Protocol (FSP)](./FSP/index.md) — voting epochs, voter registration, signing policy, finalization, rewards
- [Flare Time Series Oracle (FTSO)](./FTSO/index.md) — anchor and block-latency price feeds
- [Flare Data Connector (FDC)](./FDC/index.md) — request-and-attest external data; legacy FDC and the new FDC2
- [Flare Confidential Compute (FCC)](./FCC/index.md) — TEE-backed instructions, extensions, machine and key management

## Cross-cutting modules

- [Governance](./Governance.md) — `Governor`, `Governed`, timelocks
- [Staking](./Staking.md) — `ValidatorRewardOffersManager`, `PChainStakeMirrorVerifier`
- [RNat](./RNat.md) — the RNat token and per-account `RNatAccount` proxies
- [Inflation and Incentive Pool](./Inflation.md) — `InflationReceiver`, `IncentivePoolReceiver`, distribution into reward managers
- [API reference](./ApiReference.md) — pointer index from each module to its public `userInterfaces/I*.sol`

