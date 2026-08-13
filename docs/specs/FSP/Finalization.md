# Finalization

A sub-protocol round produces a Merkle root off-chain. **Finalization** is the act of getting that root onto the chain, signed by enough of the active signing policy to be trustworthy. All sub-protocols finalize through one contract — [`Relay`](../../../contracts/protocol/implementation/Relay.sol) — which checks signatures, stores the root, and emits `ProtocolMessageRelayed`. Consumers downstream prove their data items against that root via `Relay.verify`.

`Relay` is heavily assembly-optimized so finalization can carry a large signing policy and many signatures within a single transaction. The high-level shape, though, is straightforward.

## What `Relay` stores

| Storage | Description |
|---------|-------------|
| `toSigningPolicyHashPrivate[rewardEpochId] → bytes32` | Hash of the signing policy for that epoch: `keccak256(sourceChainId ‖ encoded policy bytes)`, one keccak over the 32-byte configured source chain id followed by the raw 43 + 22 × n encoded bytes. Set by `setSigningPolicy` (callable only by the authorized `signingPolicySetter`, which is `FlareSystemsManager`). Read by every relay. |
| `startingVotingRoundIds[rewardEpochId] → uint256` | First voting round the policy is in force for. |
| `merkleRootsPrivate[protocolId][votingRoundId] → bytes32` | The finalized Merkle root for that protocol/round. Once written, it does not change. |
| `isSecureRandomMap[votingRoundId / 256] → bytes32` | One bit per voting round indicating whether a finalized FTSO round produced a secure random. |
| `stateData` | A packed `StateData` struct with the active random-number protocol ID, voting-epoch parameters, the BIPS threshold-increase for cross-epoch relays, and the finalization window. |

`stateData.lastInitializedRewardEpoch` is bumped each time `setSigningPolicy` is called for the next reward epoch. The signing-policy struct passed in must satisfy:

- `voters.length > 0` and `≤ MAX_VOTERS` (`300`),
- weights sum below `2^16`,
- threshold ≥ `5000` BIPS of total weight (50%),
- threshold ≤ `6600` BIPS of total weight (66%).

These bounds are enforced **by `Relay` itself** in `setSigningPolicy`, independent of whatever `signingPolicyThresholdPPM` `FlareSystemsManager` configured.

## The `relay()` flow

```solidity
function relay() external returns (bytes memory);
```

`relay()` is a no-arg public function whose calldata is parsed directly. Every call starts with an active signing policy. The next byte selects one of two layouts:

- **Signing-policy relay (`protocolId = 0`)** — active signing policy + `0` (1 byte) + new signing policy + signature count (2 bytes) + indexed ECDSA signatures (67 bytes each). The signatures authenticate the source-bound hash of the new policy.
- **Protocol-message relay (`protocolId > 0`)** — the layout below. For the configured random-number protocol, a random number (32 bytes) and zero or more Merkle-proof nodes (32 bytes each) follow the signatures.

1. **Signing policy bytes** — the canonical encoding of the signing policy (43 + 22 × `numberOfVoters` bytes). The contract recomputes its hash on the fly — a single `keccak256(sourceChainId ‖ signingPolicyBytes)` over the 32-byte configured source chain id followed by the raw encoded bytes, with no padding — and checks it against `toSigningPolicyHashPrivate[rewardEpochId]`. Wrong policy → revert.
2. **Protocol message** (38 bytes) — `protocolId` (1) + `votingRoundId` (4) + `isSecureRandom` (1) + `merkleRoot` (32). The digest this message is signed under is the analogous single keccak, `keccak256(sourceChainId ‖ protocolMessage)` (before the EIP-191 `"\x19Ethereum Signed Message:\n32"` prefix applied at signature verification).
3. **Signatures** — count (2 bytes) followed by 67 bytes per signature: `v` (1) + `r` (32) + `s` (32) + `index` (2). The index points into the signing-policy voter list. The contract recovers each signature, checks the recovered address equals `signingPolicy.voters[index]`, accumulates `signingPolicy.weights[index]`, and short-circuits as soon as accumulated weight passes the threshold.

The threshold multiplier applies only when the message belongs to a later reward epoch than the supplied signing policy **and** that policy's reward epoch is still `lastInitializedRewardEpoch`. In that state the policy for the message's reward epoch has not been initialized, so the effective threshold is `floor(policyThreshold × thresholdIncreaseBIPS / 10000)`. If a later policy has been initialized but its start round has not yet been reached, the earlier policy may still sign the round at its unscaled threshold.

`thresholdIncreaseBIPS` is deployment configuration, not a mutable governance setting. `Relay.initialize` copies `RelayInitialConfig.thresholdIncreaseBIPS` into `stateData` and requires it to be at least `10000`; Relay has no setter and supplies no contract-level default. The TypeScript deploy and redeploy scripts obtain it from `parameters.relayThresholdIncreaseBIPS`. The Foundry home redeployment reads it from the configured old Relay, while the mirror deployment reads it from the source snapshot.

If accumulated signature weight strictly exceeds the effective threshold, `merkleRootsPrivate[protocolId][votingRoundId]` is written and `ProtocolMessageRelayed(protocolId, votingRoundId, isSecureRandom, merkleRoot)` is emitted. If all declared signatures are processed without enough weight, the call reverts with `NotEnoughWeight()`. `NotEnoughSignatures()` instead reports calldata that is too short for the declared signature count.

For the FTSO random-number protocol (`stateData.randomNumberProtocolId`), every accepted message stores its Merkle-proven random number and records its secure flag for historical lookup. The live `stateData.randomVotingRoundId` pointer and `stateData.isSecureRandom` flag advance only when `votingRoundId` is strictly greater than the current pointer, so a later finalization of an older round cannot regress the live random. Because the pointer is initialized to round `0`, finalizing round `0` does not advance the live fields; its value remains available through `getRandomNumberHistorical(0)`. See [Random Number](./RandomNumber.md).

### Cross-epoch boundary

A round whose `votingRoundId < startingVotingRoundIds[nextEpoch]` is signed by the *previous* signing policy. Within the finalization window (`stateData.messageFinalizationWindowInRewardEpochs`), the contract still accepts these. Outside the window, they are rejected. This is a soft-finality boundary: a few epochs of grace, then the round is closed for new finalizations.

## Finalizer selection (the grace period)

Within each voting round, a small subset of voters is selected as **grace-period finalizers** — those who get the on-chain reward for finalizing the round if they do so before the grace window closes. The selection is deterministic from the signing policy seed and the round number, and identical for all participants:

1. Let `seed = keccak256(abi.encode(signingPolicySeed, protocolId, votingRoundId))`.
2. Let `W = total weight` and `t = W × 0.05`.
3. Sample voters by repeated `(seed mod W)` look-ups against the cumulative weight, replacing `seed` with `keccak256(seed)` after each successful pick, until the accumulated weight of distinct picked voters exceeds `t`.

Selected voters are precomputable and known before the round starts. If a selected voter calls `relay()` (from their `signingPolicyAddress`) inside the grace period and either finalizes the round *or* tries to finalize an already-finalized round, they earn an equal share of the per-round finalization reward `V(i) / N(i)` where `N(i)` is the size of the selection set. If they don't, their portion is burned. After the grace window closes, the next address to successfully `relay()` takes the entire reward.

The exact grace-period duration is a sub-protocol concern (FTSO anchor, FDC, FCC each have slightly different windows) and is enforced by the off-chain reward calculator, not on-chain.

> **Note.** The grace-period selection is **not** enforced by `Relay` — `relay()` accepts a finalization from any address that produces a valid threshold of signatures. The reward consequence (who gets paid, who gets burned) is computed entirely off-chain by the reward calculator from `ProtocolMessageRelayed` events, the seed, the protocol ID, and the round number. This is by design: putting the selection on-chain would force every relay to do the sortition computation, which would dominate the gas cost.

## Reading finalized data

Consumers on Flare prove individual data items against a finalized root via:

```solidity
function verify(
    uint256 _protocolId,
    uint256 _votingRoundId,
    bytes32 _leaf,
    bytes32[] calldata _proof
) external payable returns (bool);
```

For a locally stored root, `verify` enforces `protocolId > 1` and uses OpenZeppelin's `MerkleProof.verifyCalldata`. A caller in `feeExemptAddress` pays no fee; every other caller owes `protocolFee[protocolId]`. The payment medium depends on the deployment's `feeToken`:

- **No fee token set** (all home deployments, default on mirrors): the fee is paid in native coin via `msg.value`. The caller must attach at least the fee; Relay forwards exactly the required fee to `feeCollectionAddress` and refunds any excess to the caller (so a contract caller must be able to receive the refund).
- **Fee token set** (relay-mode mirrors on chains without a spendable native token, e.g. Tempo, where `msg.value` is always 0): the fee is denominated in the configured ERC-20's base units and pulled via `safeTransferFrom` straight to `feeCollectionAddress`, so the caller must `approve` at least the fee beforehand. `msg.value` must be zero (`MsgValueNotAllowed`); there is no refund path because the pull is exact.

The fee configuration is replaced as a whole through the owner-timelocked `setProtocolFees(feeToken, feeConfigs)` — one atomic full-replace call that clears the previous table first, so a protocol not listed is free (fee 0) afterwards and fees can never be carried over as amounts in a different denomination after a token switch. Every listed protocol id must be unique (`DuplicateProtocolId`) and every fee nonzero (`ProtocolFeeZero`); a free protocol is expressed by omission. Each call, and each relay-mode initialization, emits one self-contained `ProtocolFeesSet(feeToken, feeConfigs)` event — the latest occurrence fully describes the current fee state. The configured token must be a standard exact-transfer ERC-20 (fee-on-transfer/rebasing tokens are unsupported), and the live table is enumerable via `getFeeConfigs()`. The deprecated `protocolFeeInWei(protocolId)` getter still serves native-mode deployments but reverts with `FeeTokenActive` when a token is set, so a token-denominated fee can never be misread as a wei amount. Fee configuration, the fee token, and exemptions exist only in relay mode; setter-mode initialization rejects them and local verification there is fee-free.

Other read-only views:

- `isFinalized(protocolId, votingRoundId)` — true if the root is set.
- `merkleRoots(protocolId, votingRoundId)` — read the root directly on a setter-mode (home) deployment.
- `toSigningPolicyHash(rewardEpochId)` — the signing-policy hash, used by `FlareSystemsManager.signNewSigningPolicy` and by off-chain consumers verifying the policy.
- `getVotingRoundId(timestamp)` — convert a timestamp to a voting round.

## What `Relay` does **not** do

- It does not restrict who may submit a valid finalization. Anyone can call `relay()` with a valid threshold of signatures; a subsequent call for the same `(protocolId, votingRoundId)` reverts with `AlreadyRelayed()`.
- It does not enforce the grace-period reward selection (see above).
- It does not pay anything to finalizers. Finalizer rewards are part of the off-chain reward calculation, paid via `RewardManager` like all other reward types.

## Read delegation and cutover

`Relay` supports an optional `oldRelay` read source. If set, `verify`, `isFinalized`, `merkleRoots`, and `getRandomNumberHistorical` delegate voting-round queries strictly below `startingVotingRoundIdForInitialRewardEpochId`; `toSigningPolicyHash` delegates reward-epoch queries strictly below `initialRewardEpochId`. Queries at or above the applicable boundary use local state.

The `oldRelay` path is **setter-mode only**: `initialize` rejects it on a relay-mode mirror (`OldRelayNotAllowedInRelayMode`), requires the configured source to be a setter-mode deployment (`OldRelayIncompatible`), and checks that the voting and reward-epoch timing parameters match. Relay-mode mirrors seed a source snapshot instead of delegating.

Delegated `verify` uses the configured old Relay's fee path, not the new Relay's local fee or exemption settings. It reads `oldRelay.protocolFeeInWei(protocolId)`, requires that amount, forwards exactly that amount to `oldRelay.verify`, requires the old Relay to return `true`, and refunds only the caller's excess over the reported old fee. A local exemption on the new Relay therefore does not waive the old Relay's reported fee. This path is always native-coin: `oldRelay` exists only on setter-mode (home) deployments, and a fee token can never be configured in that mode.

The initial local policy's encoded start round must equal the read-delegation boundary. The contract stores the policy hash and boundary independently, so deployment validation must establish that equality. The live `getRandomNumber()` getter does not delegate; consumers must wait for a verified local current random or implement an explicit trusted fallback before cutover.
