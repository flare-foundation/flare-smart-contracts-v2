# RNat

RNat is a **non-transferable, vesting** ERC-20-shaped reward token. It exists so that Flare can hand out reward incentives that cannot be immediately liquidated — recipients accrue RNat over time and unlock it linearly over a 12-month vesting schedule.

The on-chain pieces:

- [`RNat`](../../contracts/rNat/implementation/RNat.sol) — the central manager contract. Tracks projects, monthly reward assignments, per-account claim state.
- [`RNatAccount`](../../contracts/rNat/implementation/RNatAccount.sol) — a per-recipient personal account contract, deployed as a beacon-style minimal-proxy clone for each RNat owner. Holds the vesting schedule and the wrapped balance.
- [`CloneFactory`](../../contracts/rNat/implementation/CloneFactory.sol) — the EIP-1167 minimal-proxy deployer used by `RNat` to spawn personal accounts cheaply.

## What RNat is

```solidity
string public name;
string public symbol;
uint8 public immutable decimals;
uint256 public constant MONTH = 30 days;
uint256 public immutable firstMonthStartTs;
```

Standard ERC-20 metadata, plus a fixed 30-day month and an immutable epoch start. The token is **non-transferable** — there is no `transfer` / `transferFrom` implementation that updates balances; balances live in per-account vesting schedules and become withdrawable as vesting progresses.

The economics: `RNat` is funded either by (a) a `fundingAddress` (a designated wallet with FLR allocated to the RNat program) or (b) the **incentive pool** — the system-wide token pool that distributes auxiliary FLR (`RNat` is an `IncentivePoolReceiver`). When `incentivePoolEnabled` is true, the contract participates in daily incentive authorization just like the other receivers (see [Inflation and Incentive Pool](./Inflation.md)).

## Projects and monthly assignment

`RNat` organizes rewards into **projects**:

```solidity
struct Project {
    string name;
    address distributor;                          // can assign rewards to recipients
    bool currentMonthDistributionEnabled;         // whether distributor can target the current month
    bool distributionDisabled;                    // global pause for this project
    bool claimingDisabled;                        // pause claiming
    uint128 totalAssignedRewards;
    uint128 totalDistributedRewards;
    uint128 totalClaimedRewards;
    uint128 totalUnassignedUnclaimedRewards;
    mapping(uint256 month => MonthlyRewards) monthlyRewards;
    uint256[] monthsWithRewards;
    mapping(address owner => uint256 index) lastClaimingMonthIndex;
}
```

Each project has a **distributor** (typically a community team or external entity that earned rewards through their work) and a per-month allocation. The flow:

1. **Manager assigns rewards to a project for a specific month.** The protocol manager (a privileged role on `RNat`) calls into `RNat` to credit `assignedRewards` for project P, month M. The amount comes from the contract's `totalAssignableRewards` budget (sourced from the funding address or the incentive pool).
2. **Distributor distributes within the project.** The project's distributor calls a method (per the `IRNat` interface) to partition the month's `assignedRewards` among recipient addresses. Each recipient's `Rewards.assignedRewards` for the month grows.
3. **Recipient claims.** When the recipient calls `claim`, `RNat` ensures they have an `RNatAccount` (deploys one via `CloneFactory` if not), and forwards the recipient's rewards to that account, which begins vesting.

The distinction between *assigned* (committed to the project but not yet distributed to specific recipients) and *distributed* (allocated to a specific recipient) lets a project distribute monthly without immediate per-recipient finality — distributors can iterate on splits before recipients claim.

## Personal accounts: `RNatAccount`

Each RNat holder gets a per-address `RNatAccount` contract — a minimal-proxy clone of the `libraryAddress` implementation — controlled by the user but with restricted methods only callable through `RNat`:

```solidity
contract RNatAccount {
    address public owner;       // the user
    IRNat public rNat;          // the RNat manager

    mapping(uint256 month => uint256) internal rewards;
    uint128 public receivedRewards;
    uint128 public withdrawnRewards;

    receive() external payable {
        // Auto-wrap incoming FLR to WNat (so the balance earns delegation rewards while vesting)
        if (!disableAutoWrapping) {
            rNat.wNat().deposit{value: msg.value}();
        }
    }
}
```

When `RNat.claim` runs, it calls `RNatAccount.receiveRewards(_wNat, months[], amounts[])`, transferring the FLR with `msg.value` and the months/amounts arrays describing which month each portion belongs to. The account auto-wraps the FLR into WNat so the balance can be delegated and earn FTSO / FSP rewards during vesting.

### Vesting

A month's rewards vest linearly over 12 months from the **assignment month**. The withdrawable amount at time $t$ is:

```
elapsed_months = floor((t - firstMonthStartTs - assignmentMonth × MONTH) / MONTH)
unlocked = rewards[assignmentMonth] × min(elapsed_months, 12) / 12
```

`RNatAccount.withdraw` lets the owner pull any unlocked amount up to the unwithdrawn balance. The contract emits standard withdrawal events; the WNat wrapping is reversed (or kept wrapped, per the user's preference) on the way out.

Locked rewards stay in the account, continuing to accrue WNat-delegation rewards. The user can delegate the WNat balance to a data provider just like any other WNat — non-transferable doesn't mean no delegation.

### `disableAutoWrapping`

The user can disable the automatic FLR → WNat wrap on incoming transfers (e.g. if they want to receive plain FLR and manage wrapping themselves). This is per-account state controlled by the owner.

## Why RNat is non-transferable

The design reflects how RNat is used: it's a way to commit future reward streams without giving recipients immediate liquidity to dump. Common use cases:

- **Community grants** that should disburse over time rather than as a lump sum.
- **Protocol incentives** for behaviors (running infrastructure, providing liquidity, contributing to the ecosystem) that should reward sustained participation, not one-time engagement.
- **Vesting schedules** for partner integrations.

If RNat were transferable, recipients could sell the entire 12-month future stream the day they got it, defeating the vesting purpose. By making it withdrawable only as it unlocks, the contract enforces the vesting on-chain.

## Cross-references

- **WNat** is the wrapped native token (`WFLR` on Flare, etc.). RNat accounts hold WNat-wrapped balances during vesting.
- **`ClaimSetupManager`** lets users authorize executors (e.g. claim-bot services) to claim on their behalf — the same authorization layer that `RewardManager.claim` uses. RNat reuses this for `claim` access control.
- **`IncentivePoolReceiver`** is the parent class — RNat receives FLR from the incentive pool through the standard `setDailyAuthorizedIncentive` / `receiveIncentive` interface, same as any other receiver. See [Inflation and Incentive Pool](./Inflation.md).

## Reading RNat state

| View | Returns |
|------|---------|
| `getProject(projectId)` | Project metadata, totals. |
| `getProjectMonthlyRewards(projectId, month)` | Per-month assignment and distribution data. |
| `getOwnerInfo(owner)` | Owner's `RNatAccount` address, total received, total withdrawn, current claimable balance. |
| `getTokenPoolSupplyData()` | Standard `IITokenPool` triple: `(lockedFundsWei, totalInflationAuthorizedWei, totalClaimedWei)` — RNat reports its incentive-pool side here. |

The full reader API is in [`IRNat`](../../contracts/userInterfaces/IRNat.sol) and [`IRNatAccount`](../../contracts/userInterfaces/IRNatAccount.sol).
