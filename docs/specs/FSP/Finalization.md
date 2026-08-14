# Finalization

A sub-protocol round produces a Merkle root off-chain. **Finalization** is the act of getting that root onto the chain, signed by enough of the active signing policy to be trustworthy. All sub-protocols finalize through one contract — [`Relay`](../../../contracts/protocol/implementation/Relay.sol) — which checks signatures, stores the root, and emits `ProtocolMessageRelayed`. Consumers downstream prove their data items against that root via `Relay.verify`.

`Relay` is heavily assembly-optimized so finalization can carry a large signing policy and many signatures within a single transaction. The high-level shape, though, is straightforward.

## What `Relay` stores

| Storage | Description |
|---------|-------------|
| `toSigningPolicyHashPrivate[rewardEpochId] → bytes32` | Hash of the signing policy for that epoch: `keccak256(sourceChainId ‖ encoded policy bytes)`, one keccak over the 32-byte configured source chain id followed by the raw 43 + 22 × n encoded bytes. Setter-mode deployments install it through the authorized `signingPolicySetter`; relay-mode deployments install subsequent policies through threshold-signed mode 1. |
| `startingVotingRoundIds[rewardEpochId] → uint256` | First voting round the policy is in force for. |
| `merkleRootsPrivate[protocolId][votingRoundId] → bytes32` | The finalized Merkle root for that protocol/round. Once written, it does not change. |
| `isSecureRandomMap[votingRoundId / 256] → bytes32` | One bit per voting round indicating whether a finalized FTSO round produced a secure random. |
| `stateData` | A packed `StateData` struct with the active random-number protocol ID, voting-epoch parameters, the BIPS threshold-increase for cross-epoch relays, and the finalization window. |

`stateData.lastInitializedRewardEpoch` advances when setter mode installs the sequential next policy or relay mode accepts a threshold-signed mode-1 policy. An admitted signing policy must satisfy:

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

For the FTSO random-number protocol (`stateData.randomNumberProtocolId`), calldata after the signatures contains a 32-byte random value followed by zero or more 32-byte Merkle-proof nodes. Relay proves `keccak256(abi.encode(votingRoundId, randomNumber, normalizedSecureFlag))` under the signed root, stores the value and per-round secure bit, and advances the live pointer only when `votingRoundId` is strictly greater than the current pointer. See [Random Number](./RandomNumber.md).

### Custom-signature verification (`protocolId = 1`)

`verifyCustomSignature(_relayMessage, _messageHash)` is a stateless quorum
oracle. `_relayMessage` is complete calldata for the inner `relay()` self-call,
including the four-byte `relay()` selector. After the encoded active signing
policy it must carry this 38-byte protocol message and the indexed signatures:

```text
protocolId = 1 || votingRoundId = 0 || isSecureRandom = 0 || merkleRoot = _messageHash
```

The protocol-1 path stores no root. On acceptance it returns exactly 35 bytes:
the 32-byte message hash and the three-byte reward epoch ID from the supplied,
validated signing policy. The wrapper requires inner-call success, this exact
return shape, and hash equality, then returns that reward epoch ID.

`verifyCustomSignatureWithThreshold` performs the same validation with an
optional caller-selected weight threshold. A value of zero uses the policy
threshold. For `0 < thresholdBIPS < 10000`, the effective threshold is
`floor(totalPolicyWeight × thresholdBIPS / 10000)` and acceptance remains
strictly greater than that value. Values at or above `10000` revert. The
override is carried in EIP-1153 transient storage, is read only by protocol 1,
is cleared after success, and rolls back on revert; it cannot lower signing-policy
relay or protocol-finalization quorum. Deployments therefore require Cancun
transient-storage support.

Both functions authenticate only the source-domain digest. Consumers must put
the destination chain, consuming contract, operation, nonce, and freshness
rules they require into `_messageHash`, and must enforce replay state themselves.
See the [custom-message security boundary](../../relay-security-review.md#integration-boundary-for-custom-messages).

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

The fee configuration is replaced as a whole through the owner-timelocked `setProtocolFees(feeToken, feeConfigs)`. The call clears the table before rebuilding it, so omitted protocols are free and every installed amount has the selected denomination. Listed protocol IDs must be unique, greater than `1`, and paired with nonzero fees; a free protocol is expressed by omission. Each call and relay-mode initialization emits a self-contained `ProtocolFeesSet(feeToken, feeConfigs)` event. The configured token must be a standard exact-transfer ERC-20; fee-on-transfer and rebasing tokens are unsupported. `getFeeConfigs()` enumerates the live nonzero entries. `protocolFeeInWei(protocolId)` is a native-mode-only view and reverts with `FeeTokenActive` in token mode. Fee configuration, the fee token, and exemptions exist only in relay mode; setter-mode local verification is fee-free.

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

Delegated `verify` is free by construction. Every relay reachable through the `oldRelay` chain is assumed to be a genuine, supported Relay deployment — the migration trust assumption recorded in [relay-security-review.md](../../relay-security-review.md), which already underpins every delegated read. Under it each chain member is setter-mode (home), and neither Relay generation can ever hold a nonzero fee in setter mode: fee configuration is rejected at construction, every fee setter requires relay mode, and the deployment mode is fixed for life. The delegation therefore does not consult the old relay's fee schedule at all — it calls `oldRelay.verify` with no value, requires the delegated call to return `true`, and refunds the caller's entire `msg.value` (so a contract caller attaching value must be able to receive the refund). Local fee and exemption settings are irrelevant on this path. Should a genuine fee-enforcing Relay ever hold a nonzero fee, its own fee gate reverts the zero-value delegated call, so that case fails closed rather than mis-splitting value.

The initial local policy's encoded start round must equal the read-delegation boundary. The contract stores the policy hash and boundary independently, so deployment validation must establish that equality. The live `getRandomNumber()` getter does not delegate; consumers must wait for a verified local current random or implement an explicit trusted fallback before cutover.
