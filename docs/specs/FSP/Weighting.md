# Weighting

Vote power on Flare flows from two sources — **staked FLR** on validator node IDs, and **delegated WNat** to the delegation address — and is converted into a single per-voter **registration weight** by [`FlareSystemsCalculator.calculateRegistrationWeight`](../../../contracts/protocol/implementation/FlareSystemsCalculator.sol). This weight is what slots are awarded against in `VoterRegistry`, and what gets normalized into the signing policy's per-voter `uint16` weight.

## Inputs

For an entity attempting to register for reward epoch $e$ at vote-power block $b$:

- **Stake.** For each node ID $n$ in the entity's `nodeIds` at block $b$ (read via `EntityManager.getNodeIdsOfAt(voter, b)`), the P-chain mirror reports the FLR staked on $n$ at block $b$ via `IPChainStakeMirror.batchVotePowerOfAt(nodeIds, b)`. Node IDs that are **chilled** (`chilledUntilRewardEpochId[nodeId] > rewardEpochId`) contribute zero stake.
- **Delegation.** The entity's delegation address at block $b$ is fetched from `EntityManager.getDelegationAddressOfAt`. WNat vote-power at the delegation address (`wNat.votePowerOfAt(delegationAddress, b)`) becomes the delegation weight, *capped* at `wNatCapPPM` (currently `25_000` ≙ 2.5%) of total WNat supply at $b$. If the delegation address is chilled, its WNat contribution is zero.

The cap is applied **before** the diversity exponent. It exists to prevent any single delegation address from dominating the weighting, regardless of what real share of WNat is delegated there.

```solidity
uint256 totalWNatVotePower = wNat.totalVotePowerAt(_votePowerBlockNumber);
uint256 wNatWeightCap     = (totalWNatVotePower * wNatCapPPM) / PPM_MAX;
uint256 wNatWeight        = wNat.votePowerOfAt(delegationAddress, _votePowerBlockNumber);
uint256 wNatCappedWeight  = Math.min(wNatWeightCap, wNatWeight);
```

## The diversity exponent

Once stake and capped delegation are summed into a raw weight $W$, the contract applies an integer-valued $W^{3/4}$ approximation:

$$\mathrm{registrationWeight} \approx \lfloor\sqrt{W}\rfloor \cdot \lfloor\sqrt{\lfloor\sqrt{W}\rfloor}\rfloor.$$

In code (`FlareSystemsCalculator.sol` lines 128–129):

```solidity
_registrationWeight = _sqrt(_registrationWeight);
_registrationWeight *= _sqrt(_registrationWeight);
```

That is, the weight is replaced by `sqrt(sqrt(W)) * sqrt(W)` — equivalent to `W^(1/4) * W^(1/2) = W^(3/4)` up to integer rounding. The `_sqrt` helper is the EIP-7054-style binary-search square root (see lines 232–275).

The exponent compresses the weight scale: a voter with twice the underlying stake-plus-delegation has only $2^{3/4} \approx 1.68\times$ the registration weight, so doubling capital does *not* double signing power. This is what makes a small set of large providers harder to assemble than a flat-weight scheme would.

## What gets emitted

Once the weight is computed, the calculator emits

```solidity
event VoterRegistrationInfo(
    address voter,
    uint24 rewardEpochId,
    address delegationAddress,
    uint16 delegationFeeBIPS,
    uint256 wNatWeight,
    uint256 wNatCappedWeight,
    bytes20[] nodeIds,
    uint256[] nodeWeights
);
```

This event is what the off-chain reward calculator reads to break a single registration weight back into its components when computing per-beneficiary claim shares (`FEE` claims for the voter, `WNAT` claims for delegators, `MIRROR` claims for stakers on each node ID).

`delegationFeeBIPS` is read from [`WNatDelegationFee`](../../../contracts/protocol/implementation/WNatDelegationFee.sol) — the fee, in basis points, the voter charges its delegators on WNat-delegation rewards. It does not affect registration weight; it only affects how a `WNAT`-type reward is split between the voter (fee portion) and its delegators (everything else).

## Normalization in the signing policy

The unsigned 256-bit registration weights produced by the calculator are summed and projected to `uint16` for the signing policy. From [`VoterRegistry.createSigningPolicySnapshot`](../../../contracts/protocol/implementation/VoterRegistry.sol):

```solidity
_normalisedWeights[i] = uint16((weights[i] * UINT16_MAX) / weightsSum);
```

(`_normalisedWeights` and the storage field `normalisedWeightsSum` use the British spelling in code; the docs use the American "normalized" in prose, but cite the field names verbatim.) The signing-policy threshold is recorded per epoch in `RewardEpochState.threshold` and used by `Relay`, `signNewSigningPolicy`, `signUptimeVote`, and `signRewards`; the configured percentage is `signingPolicyThresholdPPM`, constrained by `Relay.setSigningPolicy` to a 50–66% absolute range. See [Signing Policy](./SigningPolicy.md).

## FTSO calculation weight (a different weight)

The weight described here — registration weight — is what FSP uses everywhere except for FTSO median computation. FTSO anchor median calculation uses a separate weight that **only counts WFLR delegation** (not stake), because including stake of providers that are inactive in FTSO would dilute the influence of providers actually submitting prices. That weight is computed off-chain using the `VoterRegistrationInfo` event's `wNatCappedWeight` field. See [FTSO/AnchorFeeds](../FTSO/AnchorFeeds.md).

## Burn factor for late signing

`FlareSystemsCalculator` also computes a per-voter **burn factor** for the signing-policy sign phase:

```solidity
function calculateBurnFactorPPM(uint24 _rewardEpochId, address _voter) external view returns(uint256);
```

It looks up the voter's signing record for reward epoch $e+1$'s signing policy (via `FlareSystemsManager.getVoterSigningPolicySignInfo`) and decides:

- **No penalty** if the policy was signed within `signingPolicySignNonPunishableDurationSeconds` (20 minutes) AND `signingPolicySignNonPunishableDurationBlocks` (600), OR if the voter signed within those bounds.
- **Quadratic ramp** otherwise: `linear = punishableBlocks * PPM_MAX / signingPolicySignNoRewardsDurationBlocks` (capped at `PPM_MAX`), and the returned burn factor is `linear * linear / PPM_MAX`.
- **Full burn** (`PPM_MAX`) once `punishableBlocks >= signingPolicySignNoRewardsDurationBlocks` (default 600 additional blocks). All of that voter's reward claims for epoch $e$ get burned by the off-chain calculator when this happens.

This is the on-chain piece of the late-finalization penalty that the off-chain reward calculator multiplies into the `FEE` and `WNAT`/`MIRROR` claims of the late voter.
