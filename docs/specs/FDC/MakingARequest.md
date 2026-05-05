# Making a Request

This page covers the **legacy FDC** request path through [`FdcHub`](../../../contracts/fdc/implementation/FdcHub.sol). The FDC2 path looks similar in shape but routes to TEE machines instead — see [Fdc2](./Fdc2.md).

A request is a packed byte sequence that names what to attest, where the data lives, and what the expected response is. Anyone can submit one; the hub charges a per-`(type, source)` fee and emits an event that providers pick up.

## The request format

The first 96 bytes of the request data are fixed across all attestation types:

| Bytes | Field | Description |
|-------|-------|-------------|
| `0..32` | `attestationType` | 32-byte ASCII identifier (right-zero-padded). Examples: `bytes32("Payment")`, `bytes32("EVMTransaction")`, `bytes32("Web2Json")`. |
| `32..64` | `sourceId` | 32-byte data-source identifier. Examples: `bytes32("BTC")`, `bytes32("XRP")`, `bytes32("ETH")`, chain ID strings for EVM sources. |
| `64..96` | `messageIntegrityCode` (MIC) | A salted hash of the **expected response**: `keccak256(abi.encode(response, "Flare"))` with `response.votingRound` set to `0`. |

After the 96-byte header, the rest of the data is the attestation type's `RequestBody` struct, ABI-encoded:

```solidity
abi.encode(requestBody)  // type-specific Solidity struct
```

The full encoded request is what gets passed as `bytes calldata _data` to `FdcHub.requestAttestation`.

The MIC is the protocol's anti-ambiguity gate: every response must hash, with the "Flare" salt, to the value committed in the request. That makes the response **uniquely defined** by the request — providers cannot disagree on what the right response *should* be, only on whether they can compute it.

## Fees

Fees are governed by [`FdcRequestFeeConfigurations`](../../../contracts/fdc/implementation/FdcRequestFeeConfigurations.sol), keyed by `keccak256(abi.encodePacked(type, source))`:

```solidity
function getRequestFee(bytes calldata _data) external view returns (uint256 _fee);
function setTypeAndSourceFee(bytes32 _type, bytes32 _source, uint256 _fee) external onlyGovernance;
function removeTypeAndSourceFee(bytes32 _type, bytes32 _source) external onlyGovernance;
function setTypeAndSourceFees(bytes32[], bytes32[], uint256[]) external onlyGovernance;
function removeTypeAndSourceFees(bytes32[], bytes32[]) external onlyGovernance;
```

Reading is open. Writing is governance-only. A fee of `0` is treated as "not configured" — `getRequestFee` reverts with `"Type and source combination not supported"`. Removing a fee is the same as setting it to zero (a separate event is emitted for clarity / gas).

The minimum fee is the floor; users may pay more. A larger fee makes a request more attractive to providers — when the bit-voting algorithm searches for the highest-value consensus bit-vector, it prioritizes high-fee requests. See [BitVote and Consensus](./BitVoteAndConsensus.md).

## `FdcHub.requestAttestation`

```solidity
function requestAttestation(bytes calldata _data) external payable;
```

The hub:

1. Calls `fdcRequestFeeConfigurations.getRequestFee(_data)` to look up the minimum fee. If the `(type, source)` is not configured, the call reverts.
2. Requires `msg.value >= fee` (with the underlying revert reason: `"fee to low, call getRequestFee to get the required fee amount"` — a recoverable typo in the source).
3. Determines which **reward epoch** to credit the fee to:
   - Default: the current reward epoch.
   - If `block.timestamp >= currentRewardEpochExpectedEndTs - requestsOffsetSeconds`, the request *might* not get processed by the current epoch's voters. The hub `try`/`catch`-calls `flareSystemsManager.getStartVotingRoundId(rewardEpochId + 1)`. If the next epoch's signing policy is initialized and its start voting round is at most `currentVotingEpochId + 1`, the fee is credited to the **next** reward epoch (so the round in which the request actually gets voted on collects the fee).
4. Forwards `msg.value` to `RewardManager.receiveRewards{value}(rewardEpochId, false)` — a **community offer**, not inflation.
5. Emits `AttestationRequest(_data, msg.value)`.

The `requestsOffsetSeconds` setting is governance-tunable (`setRequestsOffset(uint8)`), bounded above by `flareSystemsManager.votingEpochDurationSeconds()`. It exists because requests submitted near the end of an epoch may be picked up either by the current or the next round — crediting the fee to the right epoch ensures the providers who actually do the work get paid for it.

A request that arrives during a round's collect phase is **eligible** for that round. Multiple requests with identical `_data` in one round are merged into one with summed fees and the lowest arrival index. Requests not confirmed in their round have their fees burned at reward calculation time.

## What providers see

Off-chain provider clients filter for `AttestationRequest` events. Each event carries the raw `_data` blob and the `msg.value` paid (which is the upper bound on the fee they may earn for that request). Providers then:

1. Decode the type/source/MIC header.
2. Decode the `requestBody` according to the attestation type.
3. Verify the request against the source — e.g. fetch the named Bitcoin transaction; compute the response.
4. Compute `keccak256(abi.encode(response, "Flare"))` (with `response.votingRound = 0`) and compare to the request's MIC. Mismatch → ignore the request.
5. If the request is verifiable, mark it confirmable and proceed to bit-voting (see [BitVote and Consensus](./BitVoteAndConsensus.md)).

Providers that don't have access to a particular source (e.g. no Bitcoin RPC available) will mark requests against that source as unconfirmable and not include them in their bit-vector. The bit-voting algorithm tolerates this — only requests that >50% of weight can confirm get into the consensus bit-vector.

## Lowest used timestamp (LUT)

Each attestation response carries a `lowestUsedTimestamp` (LUT) — the Unix timestamp of the oldest data the provider needed to construct the response. The protocol compares this against a per-`(type, source)` limit:

```
collectPhaseEnd - LUT  ≤  per-pair limit
```

If the LUT is too old, providers should reject the request as invalid (because it forces them to keep historical state they no longer guarantee). The limit is set per attestation type; a value of `2^64 - 1` represents "no LUT requirement" (used for response types that don't need timestamped data). In practice this is enforced off-chain by provider clients — the LUT is part of the response struct and is hashed into the attestation hash, so a confirmed attestation's LUT is provable on-chain.

## Submitting through a contract

Most application contracts that need an attestation forward the call through their own helper:

```solidity
function makeAttestationRequest(bytes calldata data) external payable {
    fdcHub.requestAttestation{value: msg.value}(data);
}
```

The hub doesn't restrict callers — any address can make a request. Application contracts typically wrap this with their own bookkeeping (which user requested what; what to do when the attestation comes back) since the request → confirmation cycle is asynchronous and spans at least one full voting epoch.
