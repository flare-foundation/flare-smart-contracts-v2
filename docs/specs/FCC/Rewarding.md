# FCC Rewarding

FCC has its own reward stream. Two sources feed it:

- **Per-instruction fees** — every `sendInstructions` call routes its full `msg.value` to `RewardManager.receiveRewards(currentRewardEpochId, false)` as a community offer (see [Instructions](./Instructions.md) and [Operation Fees](./OperationFees.md)). This is by far the dominant flow during normal operations.
- **Inflation** — handled by [`TeeRewardOffersManager`](../../../contracts/tee/implementation/TeeRewardOffersManager.sol), a separate UUPS-upgradeable contract outside the diamond, that mirrors `FtsoRewardOffersManager` and `FdcHub`.

Like every other Flare protocol, FCC reward calculation is **off-chain**: the on-chain side collects FLR and emits events; the reward calculator builds a Merkle tree of claims; the active signing policy threshold-signs the reward hash; beneficiaries claim from `RewardManager`.

## `TeeRewardOffersManager`

A UUPS-upgradeable [`RewardOffersManagerProxyBase`](../../../contracts/protocol/implementation/RewardOffersManagerProxyBase.sol) implementation in the FCC namespace. Like the FTSO and FDC equivalents:

- Inherits from `RewardOffersManagerProxyBase`, which combines `FlareGovernedBase`, `UUPSUpgradeable`, and `InflationReceiver` — the scaffolding the UUPS offers managers share.
- Receives FLR inflation through `InflationReceiver` (held on-balance until reward-epoch switchover).
- On `triggerRewardEpochSwitchover`, the same time-weighted formula:

  ```
  totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
                     × rewardEpochDurationSeconds
                     / (intervalEnd - intervalStart);
  ```

- Emits `InflationRewardsOffered(nextRewardEpochId, amount, teeOwnersPPM)`, where `teeOwnersPPM` is the FCC-specific share (parts-per-million) of the inflation pool earmarked for TEE owners.
- Forwards the slice to `RewardManager.receiveRewards{value}(nextRewardEpochId, true)`.

The only governance-tunable parameter is `teeOwnersPPM` (set at `initialize` and via `setTeeOwnersPPM`, both bounded by `PPM_MAX = 1e6`, governance-only). `TeeRewardOffersManager` does **not** expose a community-offer entry point (there is no `offerRewards` in the style of `FtsoRewardOffersManager`); community offers for FCC are entirely per-instruction (paid by the requester through `Fdc2Hub` or any extension's instructions sender). Its inflation flow is driven solely by `triggerRewardEpochSwitchover`, callable only by `FlareSystemsManager`.

## What gets rewarded

The FCC reward pool is split (off-chain) across:

- **Relay clients** — registered FSP voters that monitor `TeeInstructionsSent` events, sign instructions with their `signingPolicyAddress`, and forward to the relevant TEE proxies. Reward is proportional to participation: signing the right instructions, with the right signing-policy address, before the deadline. Late or wrong signatures get burned.
- **TEE operators** — for each TEE machine that successfully executed an instruction, the owner is rewarded. Includes the `lastStatusChangeTs` / availability-check freshness as eligibility factors — TEE operators that let their attestations expire don't get paid.
- **Cosigners** — when an instruction includes a `cosigners[]` array and the `cosignersThreshold` is met, the participating cosigners share a portion of the pool.
- **Replication participants** — TEE operators participating in active replication groups can earn for the additional service of running replicas.
- **Project owners and key admins** — application-level rewards, where the on-chain economics flow through to the off-chain admin set the FCC infrastructure is supporting. Less standardized, depends on extension.

The exact percentages and per-extension rules are an off-chain concern; the on-chain layer just emits the events the calculator needs and holds the FLR until claims become live.

## Per-extension reward configuration

Different extensions (and different applications within an extension) have different reward priorities. The system extension, with its FDC2 and PMW applications, needs to reward:

- Relay clients heavily (they're the throughput limit on FDC2 attestations).
- TEE operators meaningfully (they bear hardware cost).
- Cosigners proportionally (less work, lower reward).

A custom extension might have a totally different shape — e.g. all reward to TEE operators, none to cosigners (no cosigners involved), some to a third-party project owner who runs the application that drives the extension.

The off-chain reward calculator reads per-extension reward configurations either from on-chain settings (extensions may publish their reward-share parameters via `ITeeExtensionStateVerifier`) or from off-chain configurations distributed alongside the calculator's deployment. The on-chain layer doesn't enforce a specific split.

## Penalties

The penalty surface for FCC, as far as the on-chain layer is concerned:

- **Late availability check.** A TEE machine whose availability check expires gets pause-able by anyone, dropping it out of the active set. Off-chain reward calculation treats this as zero rewards for the machine until it re-attests.
- **Instruction failures.** A TEE that's part of an instruction's target set but doesn't return a valid signed response gets zero reward for that instruction (its share is burned, not redistributed).
- **Banned machines.** A `BANNED` machine is permanently removed from active sets and, depending on extension policy, may have all its reward history clawed back via `DIRECT` burn claims at reward-epoch end.
- **Failed signing-policy upgrade.** A relay client (data provider) that fails to sign the *new* signing policy on time gets the FSP late-signing burn factor (see [FSP / Weighting](../FSP/Weighting.md#burn-factor-for-late-signing)) applied to all its FCC rewards for the affected reward epoch.

## Where claims happen

Same place as everything else: [`RewardManager`](../../../contracts/protocol/implementation/RewardManager.sol). The off-chain calculator combines FCC claims with FTSO and FDC claims into a single Merkle tree. The active signing policy signs the unified `rewardsHash` via `FlareSystemsManager.signRewards`. Beneficiaries call `RewardManager.claim` (or `autoClaim`) with the right Merkle proof and receive their FLR.

The claim types are the same as elsewhere — `DIRECT`, `FEE`, `WNAT`, `MIRROR`, `CCHAIN`. FCC primarily produces:

- `DIRECT` claims for TEE operators (where the beneficiary is the operator's address) and for cosigners.
- `FEE` claims for relay clients (the same `signingPolicyAddress` they use elsewhere; the same fee-vs-delegator-share semantics as FTSO and FDC).
- `WNAT` claims when FCC participation contributes to the standard delegator-distribution model — e.g. relay clients also forwarding FCC instructions earn a `WNAT` claim that gets distributed to their delegators.

There is no FCC-specific claim type; the existing five suffice.

## Visibility

Off-chain monitoring of FCC rewards reads:

- `TeeInstructionsSent` from the diamond — every instruction, every TEE set, every fee.
- `TeeMachineRegistered` / `TeeMachineStatusChanged` — machine lifecycle, used to know which operators are eligible.
- `InflationRewardsOffered` from `TeeRewardOffersManager` — per-epoch inflation pool.
- `RewardsSigned` from `FlareSystemsManager` — confirmation that the unified rewards Merkle root has been threshold-signed.

A monitor that wants to estimate "how much will my TEE operator address earn this reward epoch" combines: events for instructions targeting my machines, my availability-check status, the per-extension reward split, and the inflation pool size. The monitor's per-extension configuration is what makes the answer specific.

## Summary

FCC's economics are:

- Per-instruction `msg.value` → `RewardManager` (current epoch, `inflation = false`).
- FCC inflation share → `TeeRewardOffersManager` → `RewardManager` (next epoch, `inflation = true`).
- Off-chain split across relay clients, TEE operators, cosigners (and others).
- Standard FSP signing-policy signs the resulting Merkle root.
- Standard `RewardManager` claim path.

The new piece compared to FTSO / FDC is the **per-extension** dimension — an FCC reward calculation must know which extension's machines did which work, and apply that extension's reward rules. Extensions that publish their reward configurations on-chain make this auditable; extensions that don't operate by off-chain agreement.
