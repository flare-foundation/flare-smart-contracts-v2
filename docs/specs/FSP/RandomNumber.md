# Random Number

FSP exposes an on-chain random number that other parts of the system depend on for unpredictable selection — vote-power-block selection, finalizer sortition, FTSO block-latency feed sortition, FCC VRF inputs, and application contracts. Relay accepts the value only when a signing-policy quorum finalizes a Merkle root and the caller proves the value under that root.

## Where the random comes from

The FTSO anchor protocol's voting rounds include a per-round 256-bit random as a Merkle-tree value. `Relay.stateData.randomNumberProtocolId` identifies that protocol. A random-protocol `relay()` call appends this trailer after the indexed signatures:

```text
randomNumber (32 bytes) || Merkle proof nodes (32 bytes each)
```

Relay normalizes the signed `isSecureRandom` byte to `0` or `1`, computes

```text
leaf = keccak256(abi.encode(votingRoundId, randomNumber, normalizedSecureFlag))
```

and folds the supplied proof with OpenZeppelin-compatible sorted-pair hashing. The computed root must equal the root in the threshold-signed protocol message. A missing value, non-word-aligned trailer, or invalid proof reverts without storing the random.

For every accepted random-protocol round, Relay stores:

- `toRandomNumberPrivate[votingRoundId] = randomNumber`;
- the per-round secure bit in `isSecureRandomMap[votingRoundId / 256]`; and
- the signed Merkle root in `merkleRootsPrivate[randomNumberProtocolId][votingRoundId]`.

The live `stateData.randomVotingRoundId` and `stateData.isSecureRandom` fields advance only when the accepted round is strictly greater than the current live round. Finalizing an older round therefore adds a historical value without regressing the current random.

## Reading the current random

```solidity
function getRandomNumber()
    external view
    returns (uint256 _randomNumber, bool _isSecureRandom, uint256 _randomTimestamp);
```

Returned values:

- `_randomNumber` is the Merkle-proven 256-bit value stored for `stateData.randomVotingRoundId`.
- `_isSecureRandom` reflects the normalized, threshold-signed secure-random bit from the protocol message. Relay does not independently derive this quality classification. A non-secure round still has a value but must be treated as best-effort.
- `_randomTimestamp` is the nominal start of the next voting round, computed as `firstVotingRoundStartTs + (randomVotingRoundId + 1) × votingEpochDurationSeconds`. It is protocol time derived from the round ID, not the block timestamp at which Relay stored the value.

For historical lookups:

```solidity
function getRandomNumberHistorical(uint256 _votingRoundId)
    external view
    returns (uint256 _randomNumber, bool _isSecureRandom, uint256 _randomTimestamp);
```

This reverts unless a nonzero random-protocol Merkle root was finalized for that round. The random value itself may validly be zero.

The live pointer is initialized to round `0` and advances only on a strictly greater round. If round zero is finalized, its value is stored and is returned by the live getter while the pointer remains zero, but the live `isSecureRandom` field is not updated; the historical getter returns the stored per-round security bit. Deployments must therefore configure the accepted round domain so the first live random is above zero. They must also exclude `type(uint32).max`, because that round makes the live timestamp arithmetic revert and cannot be superseded.

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

A round's random is **secure** when the FTSO anchor protocol's off-chain rules classify it as secure and a signing-policy quorum finalizes that classification with the root. Relay checks that the proven leaf contains the same normalized secure flag as the signed protocol message; it does not recompute reveal participation or security quality.

A non-secure round can still be useful (e.g. application contracts that don't need bias-resistance), but FSP only uses the random for vote-power-block selection when the secure flag is set.
