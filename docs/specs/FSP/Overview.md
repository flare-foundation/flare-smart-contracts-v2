# FSP Overview

The Flare Systems Protocol is the layer that lets every other Flare protocol — FTSO, FDC, FCC, validator staking — share a single voter set, a single signing policy, and a single finalization pipeline. This page walks through the contracts that make that work; the following pages drill into each phase.

## What FSP is responsible for

- Defining the time grid: **voting epochs** (90 s) and **reward epochs** (3360 voting epochs, ~3.5 days). See [Epochs](./Epochs.md).
- Maintaining the **entity** model: each data provider is a long-lived identity with several specialized addresses (identity, signing policy, submit, submit-signatures, delegation). See [Voters](./Voters.md).
- Running **self-service voter registration** every reward epoch and computing a **signing policy** from the top-by-weight registrants — who votes, with what weight, and what threshold finalizes a round. See [Signing Policy](./SigningPolicy.md) and [Weighting](./Weighting.md).
- Hosting the gas-subsidized **submission** entry point that all sub-protocols use to push commits, reveals, and signatures. See [Submission](./Submission.md).
- **Finalizing** voting rounds — verifying threshold signatures over Merkle roots and emitting them on-chain. See [Finalization](./Finalization.md).
- Generating an on-chain **random number** stream consumed by sub-protocols and by FSP itself for finalizer selection and vote-power-block selection. See [Random Number](./RandomNumber.md).
- Coordinating **reward distribution**: routing inflation and community offers into `RewardManager`, gating claims behind a signing-policy-signed Merkle root, applying minimum-participation passes. See [Rewarding](./Rewarding.md).

## The contracts

FSP lives in [`contracts/protocol/`](../../../contracts/protocol/). The headline contracts and what they do:

| Contract | Role |
|----------|------|
| [`FlareSystemsManager`](../../../contracts/protocol/implementation/FlareSystemsManager.sol) | The orchestrator. Drives the per-reward-epoch lifecycle (random acquisition → vote-power block → registration → signing policy snapshot → sign phase → uptime/rewards sign). Driven by `daemonize()`, called once per block by the validator's daemon hook. |
| [`FlareSystemsCalculator`](../../../contracts/protocol/implementation/FlareSystemsCalculator.sol) | Computes registration weights from staked FLR, mirrored P-chain stake, and WNat delegations at the vote-power block. Applies the delegation cap and the diversity-weighting exponent. |
| [`EntityManager`](../../../contracts/protocol/implementation/EntityManager.sol) | Manages the long-lived **entity** model: identity address, plus delegation/signing/submit/submit-signatures addresses, plus registered validator node IDs and sortition keys. |
| [`VoterRegistry`](../../../contracts/protocol/implementation/VoterRegistry.sol) | Self-service, reward-epoch-scoped voter registration. Holds at most `maxVoters` slots (currently `100`, hard-capped at `300`); when full, a higher-weight entity displaces the lowest-weight registered one. |
| [`VoterPreRegistry`](../../../contracts/protocol/implementation/VoterPreRegistry.sol) | Lets entities already in the current signing policy stage their registration for the next reward epoch any time during the current one. Daemonized into actual `registerVoter` calls when the registration window opens. |
| [`Submission`](../../../contracts/protocol/implementation/Submission.sol) | The single submission entry-point. Provides `submit1`/`submit2`/`submit3`/`submitSignatures` — protocol-agnostic markers whose calldata payload is fanned out off-chain. The first submission per round per entity is gas-refunded. |
| [`Relay`](../../../contracts/protocol/implementation/Relay.sol) | The finalization and verification sink. Verifies threshold signatures over source-domain messages, stores protocol roots, proves random values under the signed random root, validates consumer Merkle proofs with native/token fees where configured, and provides stateless custom-signature quorum checks. |
| [`RewardManager`](../../../contracts/protocol/implementation/RewardManager.sol) | Custodian of reward funds and the claim path. Receives FLR forwarded by offers managers via `receiveRewards`. Verifies Merkle proofs of `(beneficiary, claimType, amount)` rows against the policy-signed reward hash, records claims, and burns reward portions when penalties or minimum-participation conditions apply. |
| [`RewardOffersManagerBase`](../../../contracts/protocol/implementation/RewardOffersManagerBase.sol) | Base contract for per-sub-protocol offers managers (FTSO anchor, FTSO fast updates, FDC, validators, FCC). Standardizes how inflation arrives via `InflationReceiver`, how community offers are validated, and how the manager forwards FLR onward to `RewardManager`. **Does not calculate rewards** — only emits offer events. |
| [`WNatDelegationFee`](../../../contracts/protocol/implementation/WNatDelegationFee.sol) | Tracks the fee a data provider charges its delegators on WNat delegation rewards. Updated by the entity, with delays applied so changes can't surprise delegators mid-epoch. |
| [`NodePossessionVerifier`](../../../contracts/protocol/implementation/NodePossessionVerifier.sol) | Verifies that an entity actually controls a P-chain validator node it claims to register, by checking a signed message during `EntityManager.registerNodeId`. |

## How a reward epoch flows

A single reward epoch is the smallest self-contained unit of FSP behavior. Roughly:

1. **About 2 hours before the next epoch's expected start**, `FlareSystemsManager` opens **random acquisition** — it polls `Relay` for the next secure FTSO random.
2. The acquired random selects a **vote-power block** in the current reward epoch. Stake/delegation values at that block freeze the inputs to weighting.
3. **Voter registration** opens. Entities call `VoterRegistry.registerVoter` directly; entities already in the current signing policy can have called `VoterPreRegistry.preRegisterVoter` earlier, in which case the daemon converts those pre-registrations into actual registrations as soon as the window opens. Each registration computes the entity's weight via `FlareSystemsCalculator.calculateRegistrationWeight`. If the slot table is full (`maxVoters`, currently `100`), a higher-weight entry displaces the lowest-weight existing entry; equal-or-lower weight reverts.
4. When registration closes (after at least 30 minutes, 900 blocks, and 10 voters), `VoterRegistry.createSigningPolicySnapshot` produces the per-voter normalized weights and `FlareSystemsManager` publishes the **signing policy** to `Relay`.
5. The *current* reward epoch's voters enter the **sign phase** for the initialized policy. Threshold completion records `signingPolicySignEndTs/Block`, determines late-signing penalties, and gates the later rewards-signing flow. The reward epoch itself starts independently when scheduled time is reached, the policy hash exists, and the current voting round reaches the policy's configured start round.
6. Throughout the epoch, sub-protocols accept submissions through `Submission`, finalize Merkle roots through `Relay`, and **collect FLR** via their offers managers — both inflation top-ups (via `InflationReceiver`) and community offers (via `offerRewards`-style methods). Each offer emits an event; the FLR is immediately forwarded to `RewardManager`.
7. Off-chain, after the epoch ends, the reward calculator reads all the offer/submission/finalization events and produces a flat list of reward claims, hashed into a Merkle tree. Each voter of the *current* signing policy then signs the **reward hash** through `FlareSystemsManager.signRewards`. Once submitted signatures pass the policy threshold, claims become live on `RewardManager`.

The rest of this section explains each phase in detail.

## Daemon execution

The validator runtime invokes `FlareSystemsManager.daemonize()` and analogous per-block hooks. The daemon contract is outside this repository. See [Architecture / The orchestrator](../Architecture.md#the-orchestrator-flaresystemsmanager).
