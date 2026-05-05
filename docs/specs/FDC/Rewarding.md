# FDC Rewarding

FDC providers earn rewards from two pools per voting round: **request fees** paid by users (which arrive on `RewardManager` via `FdcHub.requestAttestation` → `RewardManager.receiveRewards{value, false}`) and a slice of **FLR inflation** allocated to FDC each reward epoch. The off-chain reward calculator combines both into per-provider claims; the on-chain side just collects FLR and emits the events that bound the calculation.

This page covers:

- The two reward streams (fees, inflation).
- The on-chain configuration that decides how much inflation flows.
- The success-coefficient model used by the off-chain calculator.
- Penalization rules.

## Streams

For round $j$ in reward epoch $r$:

$$R_\text{FDC}(j) = R_\text{IFDC}(j) + R_\text{fee}(j)$$

$$R_\text{FDC}(j) = R_\text{att}(j) + R_\text{fin}(j) \quad\text{(split by governance, finalization typically ~10\%)}$$

### Fee rewards

`R_fee(j)` is the sum of fees paid for **confirmed** requests in round $j$. Fees for requests that did not make the consensus bit-vector are **burned**. The on-chain side: every `FdcHub.requestAttestation(data)` calls `rewardManager.receiveRewards{value: msg.value}(rewardEpochId, false)` — the `false` means "not inflation, this is a community / user-paid offer." `RewardManager` accumulates `epochTotalRewards[rewardEpochId] += msg.value`. The off-chain calculator distributes the confirmed-request fees across providers when computing `R_att(j)`.

The "credit-to-which-epoch" logic in `FdcHub.requestAttestation` (see [Making a Request](./MakingARequest.md#fdchubrequestattestation)) ensures that a request submitted near the end of an epoch gets its fee credited to the epoch in which the round actually voted on it.

### Inflation rewards

`R_IFDC(r)` is FDC's per-reward-epoch slice of FLR inflation. It comes through the standard offers-manager pattern. [`FdcHub`](../../../contracts/fdc/implementation/FdcHub.sol) is itself an `InflationReceiver` and a `RewardOffersManagerBase`. At each reward-epoch switchover, `FlareSystemsManager._triggerRewardEpochSwitchover` calls `FdcHub.triggerRewardEpochSwitchover` which routes to `_triggerInflationOffers`:

```solidity
totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
                    × rewardEpochDurationSeconds
                    / (intervalEnd - intervalStart);
```

The amount is then:

1. Logged via `InflationRewardsOffered(nextRewardEpochId, fdcInflationConfigurations.getFdcConfigurations(), totalRewardsAmount)`.
2. Forwarded to `RewardManager.receiveRewards{value: totalRewardsAmount}(nextRewardEpochId, true)`.
3. Tracked in `totalInflationRewardsOfferedWei`.

The pool is for the next reward epoch (the off-chain calculator settles at epoch end, and the inflation for epoch `r` is what was committed at the start of epoch `r`).

## `FdcInflationConfigurations`: which types qualify

[`FdcInflationConfigurations`](../../../contracts/fdc/implementation/FdcInflationConfigurations.sol) holds an array of `FdcConfiguration` records, one per attestation-type / source pair that governance wants to incentivize:

```solidity
struct FdcConfiguration {
    bytes32 attestationType;
    bytes32 source;
    uint8   inflationShare;        // share of the FDC inflation pool
    uint256 minRequestsThreshold;  // see below
    uint8   mode;                  // mode flag (e.g. fixed-vs-volume rewarding)
}
```

`addFdcConfigurations`, `replaceFdcConfigurations`, `removeFdcConfiguration` are governance-only. Each `_checkFdcConfiguration` verifies that the corresponding fee in `FdcRequestFeeConfigurations` is set (otherwise the request type couldn't even be made — there'd be no point inflation-rewarding it).

The off-chain reward calculator reads `getFdcConfigurations()` for each reward epoch and:

1. Counts the number of confirmed requests of each `(attestationType, source)` over the entire reward epoch.
2. For each configuration, if the count meets `minRequestsThreshold`, the configuration's `inflationShare` of the FDC inflation pool is allocated to that type's contributors. **If the threshold is not met, that configuration's inflation share is burned.**
3. The threshold-passing inflation is divided among providers proportionally to their participation (success coefficients × normalized signing weight) in rounds containing that type.

The threshold mechanism prevents inflation from being captured by attestation types that no one is actually using — if a type has very low usage in an epoch, its inflation slot gets burned rather than divided up among the few providers who happened to confirm a stray request.

## Per-round attestation rewards

For provider $i$ with normalized signing weight $W_{i,\text{sign}}$ in round $j$, the off-chain calculator computes:

$$R_\text{att}(i,j) = R_\text{att}(j) \cdot W_{i,\text{sign}} \cdot S(i,j)$$

where $S(i,j) \in \{0, 0.8, 1\}$ is the **success coefficient**:

- **`1.0` — full success.** Provider:
  - Submitted a bit-vote from `submitAddress` inside the choose phase, **and** the bit-vote *dominated* the consensus (i.e. provider's bitmap & consensus == consensus — the provider could confirm at least everything in the consensus set).
  - Submitted a signature from `signingPolicyAddress` for the (eventually) finalized Merkle root, within the grace period.
- **`0.8` — partial success.** Provider didn't bit-vote dominate (or didn't submit a bit-vote at all) but did submit a valid signature for the finalized Merkle root in the grace period. They still earn rewards, but at a discount.
- **`0.0` — failed.** Either no signature, or the signature was for a different (non-finalized) root.

Rewards "lost" to non-1.0 success coefficients are burned, not redistributed. A provider with no submissions for the round earns nothing and there is no extra payout to others.

## Finalization rewards

The grace-period finalizer-selection process (see [FSP/Finalization](../FSP/Finalization.md#finalizer-selection)) determines which providers are eligible. `R_fin(j)` is split equally among the $N_\text{fin}(j)$ selected providers who actually submit a valid finalization in the grace window:

$$R_\text{fin}(i,j) = \frac{R_\text{fin}(j)}{N_\text{fin}(j)}$$

Selected providers who *don't* submit a valid finalization have their share burned (not redistributed to those who did). If none of the selected providers finalizes in time, the entire `R_fin(j)` goes to the first non-selected provider to finalize after the grace window.

## Penalization

Two penalizable behaviors:

- **Multiple Merkle roots.** Signing a Merkle root that is different from the finalized one — including signing several distinct roots in the same round.
- **Bit-vote without follow-through.** Submitting a bit-vote inside the choose phase that *dominates* the consensus, but then failing to submit a Merkle-root signature in time. This penalizes providers who claim to be able to confirm requests and then disappear.

Each instance triggers a penalty:

$$R_\text{pen}(i,j) = R_\text{pen} \cdot W_{i,\text{sign}} \cdot R_\text{att}(j)$$

where `R_pen` is a system parameter (currently `30` per the spec, governance-tunable). Equivalently, the success coefficient becomes $S(i,j) = -R_\text{pen}$ for that round.

Penalties are applied at reward-epoch end. As in FTSO, FDC penalties exceeding the provider's FDC earnings can spill into other protocols' earnings — i.e. a heavy FDC penalty can burn the provider's FTSO rewards too. They cannot, however, exceed the provider's total cross-protocol rewards for the epoch (the burn is capped at the provider's total positive earnings).

## Where fees are sent for FDC2

FDC2 currently does not have its own inflation pool — neither the spec ([flare-specs/FCC/Extensions/FDC2.md](https://github.com/flare-foundation/flare-specs/blob/main/src/FCC/Extensions/FDC2.md)) nor the contracts define an `Fdc2InflationConfigurations` analogue. All FDC2 user fees go into `RewardManager` as community offers credited to the *current* reward epoch. From [`Fdc2Hub.requestAttestation`](../../../contracts/fdc2/implementation/Fdc2Hub.sol):

```solidity
rewardManager.receiveRewards{value: fee}(flareSystemsManager.getCurrentRewardEpochId(), false);
```

The remaining `msg.value - fee` is forwarded as instruction fees to the FCC TEE machines (via `flareTeeManager.sendSystemInstructions{value: ...}`), where the TEE operations layer's own accounting takes over (see [FCC/OperationFees](../FCC/OperationFees.md)). This means an FDC2 request's economics are split between the FDC reward pool (the per-(type, source) fee floor goes there) and the FCC fee schedule (anything above the floor pays for the TEE's work).

Adding an inflation share for FDC2 (mirroring `FdcInflationConfigurations` + `_triggerInflationOffers` for the legacy FDC) is a future design decision. It would require both a spec extension and a new on-chain `Fdc2InflationConfigurations` contract.

## Visibility

Off-chain monitoring of FDC rewards reads:

- `AttestationRequest(data, fee)` from `FdcHub` — every user-paid request.
- `Submission.submit2` calldata — bit-votes (parsed off-chain, not on chain).
- `Submission.submitSignatures` calldata — signatures (parsed off-chain).
- `Relay.ProtocolMessageRelayed` — finalization events and the round's Merkle root.
- `InflationRewardsOffered` from `FdcHub` — per-reward-epoch inflation pool.
- `RewardsSigned` from `FlareSystemsManager` — confirmation that the rewards Merkle root has been threshold-signed (i.e. claims are now live for this epoch).

The reward calculator combines all of the above with provider participation data into the per-(beneficiary, claimType, amount) Merkle tree that feeds `signRewards` on `FlareSystemsManager` and unlocks `RewardManager.claim`.
