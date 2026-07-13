# Random Number

FSP exposes an on-chain random number that other parts of the system depend on for unpredictable selection — vote-power-block selection, finalizer sortition, FTSO block-latency feed sortition, FCC VRF inputs, and any application contract that asks for it. The random is **derived from finalized FTSO Merkle roots**, not produced by a separate VRF.

## Where the random comes from

The FTSO anchor protocol's voting rounds include a per-round 256-bit random as part of the per-round Merkle leaves. That value is the result of a commit-reveal across all participating providers — the keccak hash of `(commitment_i + reveal_i)` reduced over the participating set. The standard FTSO anchor protocol ID is what `Relay.stateData.randomNumberProtocolId` is configured to.

Each time `Relay.relay()` finalizes an FTSO anchor round, it updates:

- `stateData.randomVotingRoundId = votingRoundId`,
- `stateData.isSecureRandom = isSecureRandom` (the bit from the protocol message),
- The per-round bit in `isSecureRandomMap[votingRoundId / 256]`.

So the latest FTSO anchor finalization is automatically the latest random source.

## Reading the current random

```solidity
function getRandomNumber()
    external view
    returns (uint256 _randomNumber, bool _isSecureRandom, uint256 _randomTimestamp);
```

Returned values:

- `_randomNumber` is `keccak256(abi.encode(merkleRoot))` where `merkleRoot = merkleRootsPrivate[randomNumberProtocolId][randomVotingRoundId]`. The hash is what callers should use as a random — using the raw Merkle root would leak structure if multiple consumers index into it for different positions.
- `_isSecureRandom` reflects the secure-random bit from the protocol message at finalization. A secure round is one where the random was produced from a complete-enough quorum of revealed commitments. A non-secure round still has a random value, but it could be biased (it should be treated as "best-effort").
- `_randomTimestamp` is the start-of-next-round timestamp for `randomVotingRoundId`. It's the lower bound on when the random became known on-chain.

For historical lookups:

```solidity
function getRandomNumberHistorical(uint256 _votingRoundId)
    external view
    returns (uint256 _randomNumber, bool _isSecureRandom, uint256 _randomTimestamp);
```

This reverts if no random was ever finalized for that round.

## Where it's used

- **Vote-power-block selection.** `FlareSystemsManager.daemonize()` polls `relay.getRandomNumber()` during the random-acquisition phase. It accepts the random only when `_isSecureRandom == true` AND `_randomTimestamp > randomAcquisitionStartTs` — i.e. the random must come from a round that started *after* random acquisition opened, so a bad actor can't reuse a stale random. If the maximum acquisition window expires without a secure random, the previous epoch's random and vote-power block are reused.
- **Signing-policy seed.** The selected random is stored as `RewardEpochState.seed` and copied into the published `SigningPolicy.seed`. This is the seed downstream sub-protocols use for finalizer sortition and other per-policy randomness.
- **Finalizer selection.** `keccak256(abi.encode(signingPolicySeed, protocolId, votingRoundId))` is the entry point for sampling grace-period finalizers (see [Finalization](./Finalization.md)).
- **FTSO block-latency sortition.** `FastUpdater` uses the seed plus per-block randomness to choose which providers may submit price updates each block.
- **FCC VRF.** `VrfFacet` wraps the random and exposes a verifiable-random output to TEE-issued VRF requests.
- **Application contracts.** Any contract on Flare can call `IRandomProvider.getCurrentRandomWithQuality()` (proxied through `Submission` or `Relay` directly) and pick its own policy on whether to require `isSecureRandom == true`.

The convenience `IRandomProvider` views on `Submission` are:

```solidity
function getCurrentRandom()                       external view returns(uint256);                    // requires secure
function getCurrentRandomWithQuality()            external view returns(uint256, bool);
function getCurrentRandomWithQualityAndTimestamp() external view returns(uint256, bool, uint256);
```

`getCurrentRandom()` reverts with `"Not secure"` if the latest random is not flagged secure. The other two return the secure flag (and timestamp) and let the caller decide. All three forward to `Relay.getRandomNumber()`.

## What "secure" means

A round's random is **secure** when:

- The round actually finalized (otherwise no random exists for it at all), and
- Enough providers revealed valid commitments that the random produced is the keccak of a non-degenerate XOR of revealed values.

The protocol-level rules and the exact threshold for "enough" are part of the FTSO anchor protocol, enforced by the off-chain providers. The flag carried in `Relay.relay()`'s protocol message reflects that off-chain decision; `Relay` itself trusts the threshold-signed flag.

A non-secure round can still be useful (e.g. application contracts that don't need bias-resistance), but FSP only uses the random for vote-power-block selection when the secure flag is set.
