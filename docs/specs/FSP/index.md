# Flare Systems Protocol (FSP)

The foundational voting layer that all sub-protocols ride on. FSP organizes voter registration, signing policies, voting epochs, finalization, and reward distribution.

## Documents

- [Overview](./Overview.md) — `FlareSystemsManager`, `FlareSystemsCalculator`, `EntityManager`, and how they fit
- [Epochs](./Epochs.md) — voting-epoch and reward-epoch lifecycle
- [Voters](./Voters.md) — entity definition, registration, pre-registration, signing/submission addresses
- [Weighting](./Weighting.md) — vote-power composition (CCHAIN + PCHAIN + WNAT) and the diversity factor
- [Signing Policy](./SigningPolicy.md) — snapshot, sign phase, threshold
- [Submission](./Submission.md) — commit/reveal and signature submissions through `Submission.sol`
- [Finalization](./Finalization.md) — `Relay`, threshold sigs, slashing for late finalization
- [Random Number](./RandomNumber.md) — secure random source and quality flag
- [Rewarding](./Rewarding.md) — reward-epoch flow, claim path, unclaimed handling

## Key contracts

- [`FlareSystemsManager`](../../../contracts/protocol/implementation/FlareSystemsManager.sol)
- [`FlareSystemsCalculator`](../../../contracts/protocol/implementation/FlareSystemsCalculator.sol)
- [`EntityManager`](../../../contracts/protocol/implementation/EntityManager.sol)
- [`VoterRegistry`](../../../contracts/protocol/implementation/VoterRegistry.sol)
- [`VoterPreRegistry`](../../../contracts/protocol/implementation/VoterPreRegistry.sol)
- [`Submission`](../../../contracts/protocol/implementation/Submission.sol)
- [`Relay`](../../../contracts/protocol/implementation/Relay.sol)
- [`RewardManager`](../../../contracts/protocol/implementation/RewardManager.sol)
- [`RewardOffersManagerBase`](../../../contracts/protocol/implementation/RewardOffersManagerBase.sol)
- [`WNatDelegationFee`](../../../contracts/protocol/implementation/WNatDelegationFee.sol)
- [`NodePossessionVerifier`](../../../contracts/protocol/implementation/NodePossessionVerifier.sol)
