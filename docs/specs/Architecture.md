# Architecture

This document describes how the contracts in this repo wire together. It is the cross-cutting view that the per-module specs assume. Contract names link to source.

## The three time scales

All on-chain behavior in this repo runs on one of three nested clocks:

| Scale | Length | Purpose |
|-------|--------|---------|
| Block | ~2 s | Block-latency FTSO fast updates |
| Voting epoch | 90 s | One round of FSP voting; sub-protocols (FTSO anchor, FDC) vote per voting epoch |
| Reward epoch | 3360 voting epochs (~3.5 days) | Voter registration, signing policy, reward distribution |

Voting epoch and reward epoch boundaries are defined in [`FlareSystemsManager`](../../contracts/protocol/implementation/FlareSystemsManager.sol) and read by every sub-protocol.

## The orchestrator: `FlareSystemsManager`

[`FlareSystemsManager`](../../contracts/protocol/implementation/FlareSystemsManager.sol) is the heart of FSP. Each reward epoch it drives the lifecycle:

1. **Random number acquisition** — pulls a secure random value from the previous reward epoch's voting rounds.
2. **Vote power block selection** — fixes a block at which delegated WNat and stakes are snapshotted.
3. **Voter registration** — opens the window during which data providers register via [`VoterRegistry`](../../contracts/protocol/implementation/VoterRegistry.sol).
4. **Signing policy snapshot** — calls [`FlareSystemsCalculator`](../../contracts/protocol/implementation/FlareSystemsCalculator.sol) to compute weights, then publishes a signing policy.
5. **Signing policy sign phase** — collects threshold signatures over the new policy from the *previous* reward epoch's voters.
6. **Uptime / rewards sign phase** — once rewards are calculated off-chain, collects threshold signatures over the rewards Merkle root and uptime votes.

Each phase is triggered by a `daemonize()` call, invoked once per block by the validator's daemon hook so the system advances in lock-step with block production rather than relying on external pokers.

The orchestrator also pushes addresses to all sub-protocols (see [Address wiring](#address-wiring) below) and publishes the current signing policy to [`Relay`](../../contracts/protocol/implementation/Relay.sol).

## Voter and entity model

Voters are organized through [`EntityManager`](../../contracts/protocol/implementation/EntityManager.sol) and [`VoterRegistry`](../../contracts/protocol/implementation/VoterRegistry.sol). An *entity* is a long-lived identity: an identity address, plus a delegation address and signing/submission addresses bound to it. A *voter* is an entity registered for a specific reward epoch — entities must re-register every reward epoch to count.

Voter registration is **self-service**. Each reward epoch, every entity that wants to participate calls [`VoterRegistry.registerVoter`](../../contracts/protocol/implementation/VoterRegistry.sol) (signed by its `signingPolicyAddress`); the contract calls [`FlareSystemsCalculator`](../../contracts/protocol/implementation/FlareSystemsCalculator.sol) to compute the entity's registration weight from staked FLR, mirrored P-chain stake, and WFLR delegations at the vote-power block. There are at most `maxVoters` slots in a single signing policy (currently `100`, hard-capped at `300` in the contract). Once the slots are full, an entity with higher weight than the lowest-weight registered entity displaces it; an entity whose weight is not higher than the existing minimum reverts with `"vote power too low"`. The full weighting formula and its diversity factor are described in [FSP/Weighting](./FSP/Weighting.md).

[`VoterPreRegistry`](../../contracts/protocol/implementation/VoterPreRegistry.sol) lets data providers already in the current signing policy stage their registration for the next reward epoch from the moment the current one starts, well before the on-chain registration window opens. The actual `registerVoter` call for those pre-registrations is then triggered automatically by the daemon when the registration window opens — removing a race that would otherwise penalize providers under high gas pressure.

## Submission and finalization

Per voting epoch, sub-protocols accept submissions through [`Submission`](../../contracts/protocol/implementation/Submission.sol) — the single entry point that gates by current signing policy and routes to per-protocol commit/reveal logic. Submissions don't write protocol state directly; they emit events that off-chain providers and the relay layer consume.

After a voting round, providers compute results off-chain and converge on a Merkle root. The root is finalized on chain by [`Relay`](../../contracts/protocol/implementation/Relay.sol), which checks threshold signatures from the active signing policy. Once a sub-protocol's root is in `Relay`, downstream consumers (FTSO price reads, FDC `FdcVerification`, FCC `Fdc2Verification`) prove their data against it.

`Relay` is shared: every sub-protocol writes its Merkle roots into the same contract, keyed by `(protocolId, votingRoundId)`.

## Reward state

Rewards flow through one central contract — [`RewardManager`](../../contracts/protocol/implementation/RewardManager.sol) — but **no on-chain contract calculates rewards**. Reward calculation is entirely off-chain. The on-chain contracts only **collect funds**, **emit events** describing the inputs to calculation, and **gate claims** behind a signed Merkle root.

The pattern:

1. **Inflation and incentive-pool funding.** [`InflationReceiver`](../../contracts/inflation/implementation/) and [`IncentivePoolReceiver`](../../contracts/incentivePool/implementation/) periodically push FLR into per-sub-protocol offers managers (FTSO anchor, FTSO fast updates, FDC, validators, FCC), each of which extends [`RewardOffersManagerBase`](../../contracts/protocol/implementation/RewardOffersManagerBase.sol).

2. **Reward offers.** Anyone can also fund a sub-protocol by calling `offerRewards` on the offers manager. Each offer:
   - Is validated by the offers manager (e.g. fee/turnout-band parameters in FTSO).
   - Causes the manager to emit an event — [`RewardsOffered`](../../contracts/userInterfaces/) for community offers, [`InflationRewardsOffered`](../../contracts/userInterfaces/) for inflation top-ups (e.g. [`FtsoRewardOffersManager`](../../contracts/ftso/implementation/FtsoRewardOffersManager.sol) line 86).
   - Forwards the FLR to `RewardManager` via `RewardManager.receiveRewards{value: ...}` so the funds custody at the end of the chain is always `RewardManager`.

   The offers managers do **not** record per-voter reward amounts. They record *offers* and forward FLR.

3. **Off-chain reward calculation.** The off-chain reward calculator (see the FSP C-chain indexer and the reward calculation service) reads:
   - Offers events from each offers manager,
   - Submission events from `Submission`,
   - Finalization events from `Relay`,
   - FTSO fast-update events from `FastUpdater`,
   - Voter registration events from `VoterRegistry` and `FlareSystemsCalculator`,

   and produces a flat list of reward claims — `(rewardEpochId, beneficiary, amount, claimType)` — applying each protocol's per-voter rules, penalties, and the FIP-10 minimal-participation passes.

4. **Reward-hash signing.** The list is hashed into a Merkle tree. Each registered voter of the *current* signing policy then submits its signature over that hash via [`FlareSystemsManager.signRewards`](../../contracts/protocol/implementation/FlareSystemsManager.sol). Once submitted signatures pass the policy's threshold, the reward hash is considered final and `RewardManager` is unlocked for the epoch.

5. **Claims.** Beneficiaries call into `RewardManager`, supplying their `(beneficiary, amount, claimType)` row plus a Merkle proof. `RewardManager` verifies the proof, debits the unclaimed-amount tracker for that row, and forwards FLR. Unclaimed rewards expire after a configurable number of reward epochs and are burned.

## Address wiring: `AddressUpdatable`

Every contract that talks to other contracts inherits [`AddressUpdatable`](../../contracts/utils/implementation/AddressUpdatable.sol). The pattern:

- A central `AddressUpdater` contract holds the canonical mapping from contract names (`"FlareSystemsManager"`, `"Relay"`, `"WNat"`, …) to addresses.
- When governance updates an address, `AddressUpdater` calls `updateContractAddresses(...)` on every dependent, which writes the new address into local immutable-shaped storage.
- This means address upgrades are atomic across the system: governance flips one mapping, and every dependent picks the new address up on the next call.

Every doc in this repo that mentions "the FSP manager" or "the relay" or "the WNat token" is implicitly relying on this mechanism. It is the lowest-level cross-cutting concern.

## Sub-protocol wiring at a glance

```
                    InflationReceiver / IncentivePoolReceiver
                              │
                              ▼  (per reward epoch FLR)
   FtsoRewardOffersManager ─┐
   FdcRewardOffersManager  ─┼──► RewardManager  ◄─── Relay (rewards Merkle root)
   ValidatorRewardOffersM. ─┤             ▲
   TeeRewardOffersManager  ─┘             │
                                          │ (per voting round Merkle roots)
                                          │
   FtsoFeedPublisher    ───► FlareSystemsManager  ◄─── Submission
   FastUpdater          ───►  (orchestrator)         (commit/reveal,
   FdcHub               ───►       ▲                  signature submission)
   Fdc2Hub              ───►       │
   FlareTeeManager      ───►       │
                                   │
                       VoterRegistry / EntityManager
                       FlareSystemsCalculator
```

Reading clockwise: inflation funds reward offers; reward offers per protocol feed `RewardManager`; the orchestrator publishes signing policies; sub-protocols submit through `Submission` and finalize through `Relay`; consumers read sub-protocol roots and reward proofs.

## What is not in this repo

For context, several pieces sit outside this repository:

- The **wrapped-native token contract** (`WNat` — `WFLR` on Flare, `WSGB` on Songbird, `WCFLR` on Coston, `WC2FLR` on Coston2) lives in the v1 contracts repo; it is wired in via `AddressUpdatable` but not changed here.
- All **off-chain services**: data-provider clients, relay clients, the TEE proxy, indexers, the data availability layer.
- The **FCC node software** that runs inside TEE machines.

Where this repo references those, it does so by interface only.
