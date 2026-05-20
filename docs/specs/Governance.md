# Governance

System governance on Flare is administered through a stack of governance primitives: a base [`Governed`](../../contracts/governance/implementation/Governed.sol) pattern that every governed contract inherits, a [`Governor`](../../contracts/governance/implementation/Governor.sol) on-chain proposal system for community votes, and concrete polling contracts that drive specific decisions. The pattern is the same one used in v1 — the v2 contracts plug into the existing v1 governance settings.

This page covers the system-wide governance contracts (everything except FCC). FCC has its own governance layer at the diamond level — see [FCC / Governance](./FCC/Governance.md).

## `Governed`

[`Governed`](../../contracts/governance/implementation/Governed.sol) and [`GovernedBase`](../../contracts/governance/implementation/GovernedBase.sol) are the base contracts that every governed contract in this repo (and the v1 repo) inherits. They provide:

- A `governance()` accessor — the address authorized to perform governance-only operations.
- An `onlyGovernance` modifier that wraps governance-only methods.
- A two-step governance transfer (propose / claim) that respects the `IGovernanceSettings` timelock.
- A `productionMode` flag and methods that can only be called before production-mode is locked.

Every `Governed` contract takes an `IGovernanceSettings` reference at construction. The settings contract is a system-wide singleton (deployed at network genesis) that holds the timelock duration and the executor list — the addresses that can execute timelocked governance changes after the delay.

`Governed` contracts that are also UUPS-upgradeable proxies use [`GovernedProxyImplementation`](../../contracts/governance/implementation/GovernedProxyImplementation.sol) — a variant that supports the proxy initialization pattern (the implementation is marked initialised in its constructor so it can't be misused; the proxy's `initialise` is what the proxy's constructor `delegatecall`s).

### `FlareGovernance` library — the ERC-7201 variant

A second, structurally-similar governance stack lives in [`contracts/governance/lib/FlareGovernance.sol`](../../contracts/governance/lib/FlareGovernance.sol). It stores its state in an **ERC-7201 namespaced** slot instead of fixed slots 0..N, and its timelock is **hash-keyed** (only `keccak256(encodedCall)` is stored on-chain; the executor supplies the full calldata at execution time). The public API is otherwise the same: `executeGovernanceCall`, `cancelGovernanceCall`, `switchToProductionMode`, `governance`, `governanceSettings`, `productionMode`, `isExecutor` — all declared on [`IFlareGovernance`](../../contracts/userInterfaces/IFlareGovernance.sol) as custom-error/event interfaces (no string reverts).

Two abstracts sit above the library:

- [`FlareGovernedAccess`](../../contracts/governance/implementation/FlareGovernedAccess.sol) — provides `onlyGovernance` / `onlyImmediateGovernance` modifiers. Inherits OpenZeppelin's [`Initializable`](../../dependencies/@openzeppelin-contracts-5.4.0/proxy/utils/Initializable.sol) and calls `_disableInitializers()` in its constructor as the implementation-side anti-selfdestruct. **No public functions** — used by TEE Diamond facets that share the diamond's governance state but must not pollute its ABI with duplicate selectors.
- [`FlareGovernedBase`](../../contracts/governance/implementation/FlareGovernedBase.sol) — extends `FlareGovernedAccess` and adds the seven public governance functions. Inherited by [`FlareUpgradeableBase`](../../contracts/governance/implementation/FlareUpgradeableBase.sol) (the UUPS base used by FDC2 and TEE non-Diamond contracts) and by the TEE Diamond's [`DiamondGovernanceFacet`](../../contracts/tee/facets/DiamondGovernanceFacet.sol).

The initialization lifecycle is enforced at two layers:

- **OpenZeppelin's `Initializable`** — every concrete `initialize(...)` external function carries the `initializer` modifier, and `initializeBase(...)` carries `onlyInitializing`. OZ tracks state in its own ERC-7201 slot (`openzeppelin.storage.Initializable`). This is the primary single-call guard, and unlocks `reinitializer(uint64)` for future versioned migrations.
- **`FlareGovernance` library** — keeps its own `bool initialised` flag inside the namespaced State struct (defense in depth). The library's `initialise(...)` reverts with `IFlareGovernance.GovernedAlreadyInitialized` if called a second time on the same storage — relevant if an existing proxy is upgraded to new bytecode whose OZ slot is virgin (zero) but whose FlareGovernance state is already set.

Scope today: this library backs the TEE Diamond and every FDC2 / TEE UUPS contract. All other governed contracts in the repo (FdcHub, FtsoRewardOffersManager, ValidatorRewardOffersManager, FastUpdateIncentiveManager, ChainlinkAdapter, FtsoV2Proxy, the protocol contracts, etc.) continue to use the legacy `GovernedBase`-derived stack above.

## `Governor` — community proposals

[`Governor`](../../contracts/governance/implementation/Governor.sol) is the OpenZeppelin-style on-chain proposal system, adapted for Flare's vote-power model. It implements [`IGovernor`](../../contracts/userInterfaces/IGovernor.sol) and aggregates two helpers: [`GovernorProposals`](../../contracts/governance/implementation/GovernorProposals.sol) (proposal lifecycle) and [`GovernorVotes`](../../contracts/governance/implementation/GovernorVotes.sol) (vote counting). Inputs:

- A reference to [`IISupply`](https://github.com/flare-foundation/flare-periphery-contracts) — the v1 supply contract that provides circulating-supply data for quorum calculations.
- A reference to [`IIGovernanceVotePower`](https://github.com/flare-foundation/flare-periphery-contracts) — the v1 contract that exposes per-address governance vote power (typically WNat governance vote power, separate from FSP delegation vote power).
- A reference to [`Submission`](../../contracts/protocol/implementation/Submission.sol) — used for the gas-refunded `submit3` mechanism if proposals route through it.

Lifecycle:

1. **Propose.** The proposer (a `GovernorProposer`) calls `propose(targets, values, calldatas, description)`. The proposal is recorded with a vote-start time and vote-end time computed from governance settings. The proposer can `cancel` before voting starts.
2. **Vote.** Token holders call `castVote(proposalId, support)` (or the EIP-712 `castVoteBySig` variant) during the voting window. Vote weight comes from `governanceVotePower.votePowerOfAt(voter, proposal.votePowerBlock)` — fixed at proposal creation so vote-buying mid-proposal doesn't work.
3. **Tally.** When voting closes, `state(proposalId)` reports `Succeeded` if quorum is met and the support threshold (defaulting to >50%) is passed; otherwise `Defeated`.
4. **Execute.** Successful proposals can be executed via `execute(proposalId, ...)`. The proposal's stored `(targets, values, calldatas)` are executed in sequence by the contract.

Quorum is a percentage of the circulating supply — the contract reads the snapshotted supply at the proposal's vote-power block and requires `for + abstain` votes to exceed `quorumBIPS / 10000` of it.

`castVoteBySig` lets a delegator authorize someone else (e.g. a wallet UI) to submit a vote on their behalf without paying gas, by signing an EIP-712 ballot. The signature recovers the voter's address; only that address's vote-power is counted.

## `GovernorProposer` and `PollingFoundation`

[`GovernorProposer`](../../contracts/governance/implementation/GovernorProposer.sol) is an abstract layer on top of `Governor` that gates proposal creation. The two concrete polls extend it:

- **[`PollingFoundation`](../../contracts/governance/implementation/PollingFoundation.sol)** — the foundation-level governance. Proposals can be made by a configured `proposers[]` set (typically the Flare Foundation team). High-impact decisions: setting up new sub-protocols, parameter changes, treasury actions.
- **[`PollingManagementGroup`](../../contracts/governance/implementation/PollingManagementGroup.sol)** — a separate poll for the management group of registered providers. Lower-impact decisions, faster cadence.

Each poll has its own quorum and threshold parameters. Both inherit `Governor` and present the same `IGovernor` interface to voters; what differs is the proposer set and the timing.

## How `Governed` interacts with these polls

The flow for a typical governance change to a v2 contract:

1. **Foundation** drafts a proposal (e.g. "set `randomAcquisitionMaxDurationSeconds` to 6 hours") and submits via `PollingFoundation.propose`.
2. Voting window opens. WNat / governance-vote-power holders cast votes.
3. If passed, `PollingFoundation.execute(proposalId)` runs the proposal's `(target, calldata)` — typically a call into the target contract's governance-only setter (e.g. `flareSystemsManager.updateSettings(...)`).
4. The setter, gated by `onlyGovernance`, checks `msg.sender == governance()`. The poll address *is* the governance for v2 contracts (via `IGovernanceSettings`).
5. After the timelock, the change takes effect.

Day-to-day operational changes (chilling a misbehaving provider, adding an FDC attestation type, setting a feed configuration) are done through `IGovernanceSettings.executors[]` — addresses authorized to execute already-passed governance directly. The executors don't have proposal power; they just submit the on-chain transaction once the proposal has been approved.

## Differences from v1 governance

The v2 contracts deliberately reuse v1's governance settings — the `IGovernanceSettings` instance, the polling foundation, the executor list. This means a single governance action can update a v1 and a v2 contract together.

The v2-specific addition is `IIGovernanceVotePower` for vote weight, which is computed against the `governanceVotePower` snapshot rather than v1's `vpToken`. The accounting model is otherwise identical.

## What governance can and cannot do

| Can | Cannot |
|-----|--------|
| Update settings on `Governed` contracts (durations, thresholds, fees) | Read or move user funds (no privileged token access) |
| Set / replace the AddressUpdater mapping | Forge signatures (no key custody) |
| Cut facets in / out of the FCC diamond | Override the FSP signing-policy threshold for specific rounds |
| Change reward-offer and inflation parameters | Predict or influence the FTSO secure random |
| Chill providers, ban TEE machines, disable extensions | Edit historical `Relay` Merkle roots |
| Upgrade UUPS implementations behind their proxies | Bypass the timelock |

The timelock is the structural protection against governance takeover. An attacker who steals governance keys can propose anything, but cannot execute the change for the timelock duration, giving the network time to respond (e.g. with an emergency upgrade or, in worst cases, a hard fork).

## Reading governance state

```solidity
governor.state(proposalId)            // ProposalState enum: Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed
governor.proposalSnapshot(proposalId) // vote-power block
governor.proposalDeadline(proposalId) // voting end timestamp
governor.proposalVotes(proposalId)    // (against, for, abstain) tallies
```

Off-chain monitors read these to display proposal status. Each `Governed` contract also exposes `governance()` for direct lookups of who currently controls it.
