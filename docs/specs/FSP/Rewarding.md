# Rewarding

The reward system pays voters and their delegators for honest participation, and burns the share of mis-behaving or absent voters. The on-chain side does **not** calculate rewards — it only collects FLR, records offer events, and gates claims behind a threshold-signed Merkle root. The actual per-voter math happens off-chain in the [reward calculator](https://github.com/flare-foundation/fsp-rewards), which reads on-chain events.

## Sources of FLR

A reward epoch is funded from two streams:

- **Inflation.** [`InflationReceiver`](../../../contracts/inflation/implementation/) holds the per-period inflation allocation. On each new reward epoch, `FlareSystemsManager._triggerRewardEpochSwitchover` calls `triggerRewardEpochSwitchover(currentRewardEpochId, expectedEndTs, durationSeconds)` on every registered `IIRewardEpochSwitchoverTrigger` — i.e. every offers manager. Each manager's `_triggerInflationOffers` then computes its share of inflation, emits `InflationRewardsOffered`, and forwards the FLR to `RewardManager` via `RewardManager.receiveRewards{value: ...}(rewardEpochId, true)`.
- **Community offers.** Anyone can fund a sub-protocol for the *next* reward epoch by sending FLR to its offers manager's `offerRewards(nextRewardEpochId, offers[])`. The manager validates each offer (per-protocol parameters), emits `RewardsOffered`, and forwards the FLR via `receiveRewards(nextRewardEpochId, false)`.

The current allocation of inflation across sub-protocols (subject to governance changes) is approximately:

| Sub-protocol | Inflation share | Additional sources |
|--------------|----------------:|--------------------|
| FTSO anchor (Scaling) | 24.5% | Community feed reward offers. |
| FTSO block-latency (Fast Updates) | 10.5% | Volatility incentives via `FastUpdateIncentiveManager`. |
| FDC | 35% | Attestation request fees forwarded by `FdcHub`. |
| Validator rewards (independent) | 30% | None. |

Validator rewards have their own independent path through [`ValidatorRewardOffersManager`](../../../contracts/staking/implementation/ValidatorRewardOffersManager.sol) — see [Staking](../Staking.md).

`RewardManager.receiveRewards` (only callable by the registered set of offers managers; `setRewardOffersManagerList` configures the set):

```solidity
function receiveRewards(uint24 _rewardEpochId, bool _inflation) external payable onlyRewardOffersManager;
```

It rejects past reward epochs, accumulates `epochTotalRewards[rewardEpochId]`, and (for inflation) `epochTotalInflationRewards[rewardEpochId]`. The FLR sits in `RewardManager`'s own balance until claimed or burned.

## Off-chain reward calculation

After a reward epoch ends, an off-chain calculator (FSP C-chain indexer + reward calculation service) processes:

1. **Reward sources** — events from each offers manager (see above), keyed to the right epoch.
2. **Epoch metadata** — `Relay.SigningPolicyInitialized`, `VoterRegistry.VoterRegistered`, `FlareSystemsCalculator.VoterRegistrationInfo`, and equivalents.
3. **Submission and finalization data** — `submit1`, `submit2`, `submitSignatures`, and `relay()` transactions in their valid timestamp ranges. Submissions outside the windows are ignored, as are submissions from addresses not in the active signing policy.
4. **Block-latency events** — `FastUpdater.FastUpdateFeeds` and `FastUpdater.FastUpdateFeedsSubmitted` for each round.

The calculator then runs each protocol's per-voter rules and produces a flat list of **reward claims** with the structure:

```solidity
struct RewardClaim {
    uint24 rewardEpochId;
    bytes20 beneficiary;
    uint120 amount;
    ClaimType claimType;
}

enum ClaimType { DIRECT, FEE, WNAT, MIRROR, CCHAIN }
```

| Claim type | Beneficiary | Distribution |
|------------|-------------|--------------|
| `DIRECT` (0) | Any address | Goes solely to the beneficiary. Used for back-claims of undistributed pool funds, burn claims, and any direct rewards a sub-protocol wants to mint. |
| `FEE` (1) | Voter's `identityAddress` | The voter's WNat-delegation fee (set in [`WNatDelegationFee`](../../../contracts/protocol/implementation/WNatDelegationFee.sol)) and validator-staking fee, plus any reward portion the voter takes for itself. Solely owed to the beneficiary. |
| `WNAT` (2) | Voter's `delegationAddress` | Pool-style claim. The recorded amount is the *total* due to the delegation address, distributed proportionally to delegators by their share of WNat vote-power at the vote-power block. |
| `MIRROR` (3) | A `bytes20` validator node ID | Pool-style claim, distributed by P-chain stake share at the vote-power block. |
| `CCHAIN` (4) | A C-chain stake address | Pool-style claim, distributed by C-chain stake share. Only active when `cChainStakeEnabled`. |

For each beneficiary and claim type, the calculator sums any positive reward and subtracts any penalty from the same protocol. If the result is negative, the entire claim is burned (a `DIRECT` claim with the burn address as beneficiary). Penalties are applied per-protocol per-round (e.g. FTSO median miss, FDC reward miss).

The whole list is then hashed into a Merkle tree:

```solidity
claimHash = keccak256(abi.encode(rewardEpochId, beneficiary, amount, claimType));
rewardsHash = MerkleTree.root(claimHashes);
```

## Minimal participation conditions (FIP-10 passes)

Before producing the final claim list, the calculator applies the FIP-10 minimum-participation gate. Each protocol defines a participation requirement:

- **FTSO anchor.** Voter's price estimate within a 0.5% band around the consensus median in 80% of voting rounds in the reward epoch.
- **FTSO block-latency.** Voter submitted at least 80% of its expected updates (waived if the voter has less than 0.2% of total active weight).
- **FDC.** Voter rewarded in 60% of voting rounds in the epoch.
- **Staking.** ≥80% uptime in the epoch with ≥1M FLR active self-bond. Earning passes additionally requires ≥3M FLR self-bond and ≥15M FLR active stake. Providers below the upper bar but above 1M / 80% retain rewards, but neither earn nor lose passes.

The pass system buffers occasional failure:

- Every voter starts at 0 passes; missing registration for an epoch resets the count to 0.
- Meeting *all* protocol requirements in an epoch awards 1 pass (capped at 3).
- Each protocol the voter fails in costs 1 pass.
- A voter at 0 passes that loses one pass forfeits **all** its rewards (FEE, WNAT, MIRROR for that voter's node IDs, and the voter's identity / delegation addresses) for that epoch — the calculator burns them.

The on-chain side that drives this off-chain logic is the per-voter burn factor from [`FlareSystemsCalculator.calculateBurnFactorPPM`](./Weighting.md#burn-factor-for-late-signing) for late signing-policy signing, plus the pure event trail `Relay`, `FastUpdater`, `Submission`, `FlareSystemsManager` produce.

## On-chain reward sign-off

After calculation, a Merkle root and the per-`rewardManagerId` weight-based claim counts are signed by the *current* signing policy. The path is two stages:

### 1. Uptime vote sign

Voters first submit and then sign-off on the validator uptime vote, since pass logic depends on it.

```solidity
function submitUptimeVote(uint24 _rewardEpochId, bytes20[] calldata _nodeIds, Signature calldata _signature) external;
function signUptimeVote   (uint24 _rewardEpochId, bytes32 _uptimeVoteHash, Signature calldata _signature) external;
```

`submitUptimeVote` records each voter's node ID list (off-chain readers compute the canonical uptime hash from the union of submissions). `signUptimeVote` then threshold-signs one chosen `_uptimeVoteHash`. When threshold is reached, `uptimeVoteHash[rewardEpochId]` is fixed and `rewardsSignStartTs/Block` is set, opening the rewards-sign window.

This phase is enabled by the orchestrator only after `submitUptimeVoteMinDurationSeconds` (10 minutes) and `submitUptimeVoteMinDurationBlocks` (300) elapse from the start of the reward epoch under reward.

### 2. Rewards sign

```solidity
function signRewards(
    uint24 _rewardEpochId,
    NumberOfWeightBasedClaims[] calldata _noOfWeightBasedClaims,
    bytes32 _rewardsHash,
    Signature calldata _signature
) external;
```

The signed message is `keccak256(abi.encode(rewardEpochId, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash))`. `noOfWeightBasedClaims` is an array of `(rewardManagerId, noOfWeightBasedClaims)` pairs — one entry per `RewardManager` instance (Flare can run multiple in parallel, e.g. one current and one being phased out). The list must be strictly increasing by `rewardManagerId` (`require(rewardManagerId > prev)` in `_updateRewardsHashAndEmitRewardsSigned`).

When the signature accumulator passes the policy's threshold:

- `rewardsHash[rewardEpochId] = _rewardsHash`,
- `noOfWeightBasedClaimsHash[rewardEpochId] = keccak256(abi.encode(_noOfWeightBasedClaims))`,
- For each entry, `noOfWeightBasedClaims[rewardEpochId][rewardManagerId] = noOfWeightBasedClaims_i`,
- `rewardsSignEndTs/Block` is set,
- `RewardsSigned(..., thresholdReached=true)` is emitted.

The same `rewardsHash` cannot be re-signed once set. Governance has an emergency override via `setRewardsData(rewardEpochId, noOfWeightBasedClaims, rewardsHash)` (only `onlyImmediateGovernance`) — useful when off-chain calculation has been agreed off-band but the signing policy is unable to threshold-sign in a timely manner.

## Claims

Once `rewardsHash` is set for an epoch, beneficiaries can claim via [`RewardManager`](../../../contracts/protocol/implementation/RewardManager.sol).

### `claim`

```solidity
function claim(
    address _rewardOwner,
    address payable _recipient,
    uint24 _rewardEpochId,
    bool _wrap,
    RewardClaimWithProof[] calldata _proofs
) external returns (uint256 _rewardAmountWei);
```

`_rewardOwner` is the address whose rewards are being claimed (typically `msg.sender`, but see executor support below). `_recipient` is where the FLR (or wrapped WNat if `_wrap == true`) lands. `_rewardEpochId` is the latest epoch to claim through; the function processes every claimable epoch from `_minClaimableRewardEpochId()` through `_rewardEpochId`. For each epoch the function:

1. **Initializes weight-based claims.** Before any beneficiary can claim from a `WNAT`, `MIRROR`, or `CCHAIN` shared pool, the pool's totals must be on-chain. `_processProofs(_rewardOwner, _recipient, _proofs, minClaimableEpochId)` walks the supplied `RewardClaimWithProof` list, verifies each Merkle proof against `rewardsHash[claim.body.rewardEpochId]`, and for weight-based types records the unclaimed total in `epochTypeBeneficiaryUnclaimedReward[epoch][type][beneficiary]`. The number of weight-based claims expected per epoch per `RewardManager` is `noOfWeightBasedClaims[epoch][rewardManagerId]` — once that many proofs are processed, the epoch's pool is fully initialized.
2. **Pays direct and fee rewards.** For `DIRECT` and `FEE` claims, the proof is verified and the amount is paid out directly (after multiplying by the voter's late-signing burn factor, with the burned portion forwarded to `BURN_ADDRESS`).
3. **Pays the caller's share of weight-based pools.** For each epoch and pool the caller has a stake in (WNat delegation share, P-chain stake share, C-chain stake share), the function debits `epochTypeBeneficiaryUnclaimedReward` proportionally and pays out.
4. **Bumps `rewardOwnerNextClaimableEpochId[_rewardOwner]`** so the same epoch can't be claimed twice.

If `_wrap == true`, the FLR is wrapped to WNat and credited to `_recipient` rather than transferred raw.

### `autoClaim`

```solidity
function autoClaim(
    address[] calldata _rewardOwners,
    uint24 _rewardEpochId,
    RewardClaimWithProof[] calldata _proofs
) external;
```

Bulk claim used by third-party executors. It looks up each owner's auto-claim address and executor fee from [`ClaimSetupManager`](../../../contracts/protocol/interface/IIClaimSetupManager.sol), claims into that address, deducts the executor fee, and pays the executor for each owner. PDA (personal delegation account) WNat claims are handled with a follow-up `_claimWeightBasedRewards` call so the PDA's own delegation share is also claimed.

### `initialiseWeightBasedClaims`

```solidity
function initialiseWeightBasedClaims(RewardClaimWithProof[] calldata _proofs) external;
```

A standalone path to pre-populate weight-based pool totals without claiming anything. Useful for clients who want to avoid front-running on the per-pool first-proof requirement.

### Executor and recipient setup

`onlyExecutorAndAllowedRecipient` checks `msg.sender == _rewardOwner` OR (`_msgSender` is registered as an authorized executor for `_rewardOwner` in `ClaimSetupManager` AND `_recipient` is a permitted recipient for that owner). This is what lets services bulk-claim on behalf of holders without holding their keys.

### `claimProxy`

```solidity
function claimProxy(address _msgSender, address _rewardOwner, address payable _recipient, uint24 _rewardEpochId, bool _wrap, RewardClaimWithProof[] calldata _proofs) external returns (uint256);
```

A backwards-compatibility hook used by `FtsoRewardManagerProxy` so the v1 FTSO RewardManager interface keeps working. Restricted to `msg.sender == ftsoRewardManagerProxy`.

## Expiration and burn

Reward epochs eventually expire. `RewardManager.closeExpiredRewardEpoch(rewardEpochId)` (called only by `FlareSystemsManager` or the next `RewardManager`) advances `nextRewardEpochIdToExpire`, computes the unclaimed remainder

```
epochTotalRewards[epoch] - (epochClaimedRewards[epoch] + epochBurnedRewards[epoch])
```

and forwards it to `BURN_ADDRESS`. Late-signing burns and FIP-10 pass burns are already accounted in `epochBurnedRewards` at claim time. The orchestrator triggers expiration either eagerly (every reward epoch start, when `triggerExpirationAndCleanup` is on) or lazily (each `daemonize()`, when the cleanup block has passed the epoch's vote-power block).

The `firstClaimableRewardEpochId` is initialized to `type(uint24).max` and pinned to the current reward epoch by governance via `enableClaims()`. Until that's called, `_minClaimableRewardEpochId()` returns the future, and all claims fail. This is the post-deployment safety gate.

## Multi-RewardManager deployments

The system supports running multiple `RewardManager` contracts in parallel — each with its own `rewardManagerId` (immutable, set in the constructor). When upgrading, the new manager calls `setInitialRewardData()` to copy the next-to-expire bookmark from `FlareSystemsManager`, and the old manager's `setNewRewardManager(newAddress)` lets the old one forward `closeExpiredRewardEpoch` calls. `signRewards` accepts one `(rewardManagerId, count)` entry per manager; both old and new can claim against the same Merkle root for any reward epochs they overlap on.
