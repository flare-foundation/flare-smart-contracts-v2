# Inflation and Incentive Pool

Inflation is the system-wide source of new FLR that funds protocol participation rewards. The **incentive pool** is a parallel mechanism for auxiliary token incentives (community grants, partner programs) routed through the same plumbing.

This repo doesn't host the inflation / incentive-pool *source* contracts — those live in the v1 repo. What's here are the **base classes** that every receiver inherits, plus the individual receivers themselves.

## Two parallel pipelines

```
v1 Inflation contract → setDailyAuthorizedInflation()       → InflationReceiver-derived contracts
                     → receiveInflation{value: ...}()
                                                              │
                                                              ├─ FtsoRewardOffersManager
                                                              ├─ FastUpdateIncentiveManager
                                                              ├─ FdcHub
                                                              ├─ ValidatorRewardOffersManager
                                                              └─ TeeRewardOffersManager

v1 IncentivePool      → setDailyAuthorizedIncentive()        → IncentivePoolReceiver-derived contracts
                     → receiveIncentive{value: ...}()
                                                              └─ RNat
```

Both pipelines follow the same protocol — a daily *authorization* (announce how much will be sent in the coming day, allowing the receiver to plan), then *receipt* (the actual FLR transfer). Receivers are notified at both points.

## `InflationReceiver`

[`InflationReceiver`](../../contracts/inflation/implementation/InflationReceiver.sol) is the abstract base class:

```solidity
abstract contract InflationReceiver is TokenPoolBase, IIInflationReceiver, AddressUpdatable {
    uint256 public totalInflationAuthorizedWei;
    uint256 public totalInflationReceivedWei;
    uint256 public lastInflationAuthorizationReceivedTs;
    uint256 public lastInflationReceivedTs;
    uint256 public dailyAuthorizedInflation;

    address internal inflation;  // the v1 Inflation contract

    modifier onlyInflation { _checkOnlyInflation(); _; }

    function setDailyAuthorizedInflation(uint256 _toAuthorizeWei) external onlyInflation;
    function receiveInflation() external payable mustBalance onlyInflation;

    function _setDailyAuthorizedInflation(uint256 _toAuthorizeWei) internal virtual;
    function _receiveInflation() internal virtual;
}
```

Key points:

- The `inflation` address is wired in via `AddressUpdatable._updateContractAddresses` reading the `"Inflation"` mapping. Every concrete receiver overrides `_updateContractAddresses` to call `super` so this resolution still happens.
- `setDailyAuthorizedInflation` is called once per day by the v1 Inflation contract. The receiver stores the daily figure and the running total; concrete receivers override `_setDailyAuthorizedInflation` to react if needed (most don't — the daily authorization is informational; what matters is the actual FLR receipt).
- `receiveInflation` is the FLR transfer. The full `msg.value` arrives at this call; concrete receivers override `_receiveInflation` if they want to react immediately (most don't — they let the FLR sit on-balance until reward-epoch switchover).
- `mustBalance` is the standard `TokenPoolBase` modifier that ensures the contract's balance equals its expected balance after the call — a basic sanity check against accidental mis-sends.

### How the receivers actually use it

Most receivers override `_setDailyAuthorizedInflation` and `_receiveInflation` as **no-ops**. Why? They don't need to do anything per-day — they hold the FLR until reward-epoch switchover, when `_triggerInflationOffers` (called by `FlareSystemsManager`) computes the per-epoch slice and emits the offer.

The pattern in [`FtsoRewardOffersManager`](../../contracts/ftso/implementation/FtsoRewardOffersManager.sol), [`FdcHub`](../../contracts/fdc/implementation/FdcHub.sol), [`FastUpdateIncentiveManager`](../../contracts/fastUpdates/implementation/FastUpdateIncentiveManager.sol), [`ValidatorRewardOffersManager`](../../contracts/staking/implementation/ValidatorRewardOffersManager.sol), [`TeeRewardOffersManager`](../../contracts/tee/implementation/TeeRewardOffersManager.sol):

```solidity
function _setDailyAuthorizedInflation(uint256 _toAuthorizeWei) internal override { /* nothing */ }
function _receiveInflation() internal override { /* nothing */ }
```

So the daily authorization is just informational; the FLR balance sits and grows. At reward-epoch switchover the standard time-weighted formula computes the slice:

```
totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
                    × rewardEpochDurationSeconds
                    / (intervalEnd - intervalStart);
```

And the slice is forwarded to `RewardManager`. See each protocol's Rewarding doc for specifics.

## `IncentivePoolReceiver`

[`IncentivePoolReceiver`](../../contracts/incentivePool/implementation/IncentivePoolReceiver.sol) is the analogous base class for the incentive-pool pipeline. Identical shape, different external interface name:

```solidity
abstract contract IncentivePoolReceiver is TokenPoolBase, IIIncentivePoolReceiver, AddressUpdatable {
    uint256 internal totalIncentiveAuthorizedWei;
    uint256 internal totalIncentiveReceivedWei;
    uint256 internal lastIncentiveAuthorizationReceivedTs;
    uint256 internal dailyAuthorizedIncentive;

    address internal incentivePool;

    function setDailyAuthorizedIncentive(uint256 _toAuthorizeWei) external onlyIncentivePool;
    function receiveIncentive() external payable mustBalance onlyIncentivePool;

    function _setDailyAuthorizedIncentive(uint256 _toAuthorizeWei) internal virtual;
    function _receiveIncentive() internal virtual;
}
```

Currently the only concrete receiver is [`RNat`](../../contracts/rNat/implementation/RNat.sol) — see [RNat](./RNat.md). RNat overrides `_receiveIncentive` to credit the daily incentive against `totalAssignableRewards`, which the project distributors then partition into per-month per-recipient assignments.

## Why `mustBalance`

The `mustBalance` modifier (from `TokenPoolBase`) checks that the contract's `address(this).balance == _getExpectedBalance()` *after* the function runs. Each receiver implements `_getExpectedBalance()` to return what the balance *should* be — typically `totalReceivedWei - totalRewardsOfferedWei` for offers managers (the funds awaiting forwarding) or `totalIncentiveReceivedWei` for `RNat` (everything received minus distributed).

The check catches:

- Self-destruct attacks where someone forces FLR onto the contract that's not accounted for.
- Bugs where the receiver fails to forward FLR it received.

If the balance is unexpected, the call reverts. The contract's accounting is always consistent or the call fails.

## Relationship to inflation events on `RewardManager`

Every receiver's `_triggerInflationOffers` ends in `rewardManager.receiveRewards{value}(rewardEpochId, true)`. The `true` flag tells `RewardManager` "this is inflation, not a community offer", which routes the FLR into `epochTotalInflationRewards[rewardEpochId]` (separate accounting from community-offer totals). Off-chain consumers can distinguish "rewards funded by inflation" from "rewards funded by community participation" by reading these per-epoch totals.

## What inflation rate Flare uses

The inflation rate is a system parameter tracked by the v1 `Inflation` contract — not in this repo. The split across receivers (24.5% FTSO scaling, 10.5% FTSO fast updates, 35% FDC, 30% validators) is governance-set on the inflation contract; this repo just sees the resulting `setDailyAuthorizedInflation` and `receiveInflation` calls.

## Adding a new receiver

To plug a new contract into the inflation pipeline:

1. Inherit from `InflationReceiver` (or `IncentivePoolReceiver` for the incentive side).
2. Implement `_setDailyAuthorizedInflation`, `_receiveInflation`, `_getExpectedBalance`. Most just stub the first two and use the standard "save FLR for epoch switchover" pattern.
3. If the receiver should also offer rewards onward, inherit from `RewardOffersManagerBase` instead of just `InflationReceiver` directly — it adds the `_triggerInflationOffers` hook called by `FlareSystemsManager` at epoch switchover.
4. Register the contract on the v1 Inflation / IncentivePool contracts (governance action) so they start sending it the daily authorizations.
5. Wire the `"Inflation"` / `"IncentivePool"` mapping via `AddressUpdater` so the receiver knows the source contract's address.

The cluster of `RewardOffersManagerBase` derivatives (`FtsoRewardOffersManager`, `FdcHub`, `FastUpdateIncentiveManager`, `ValidatorRewardOffersManager`, `TeeRewardOffersManager`) all do this — the boilerplate amounts to a few dozen lines per receiver.
