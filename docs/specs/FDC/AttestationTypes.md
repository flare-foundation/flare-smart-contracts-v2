# Attestation Types

The seven attestation types currently supported by FDC are defined in [`contracts/userInterfaces/fdc/`](../../../contracts/userInterfaces/fdc/). Each type defines a `RequestBody`, a `ResponseBody`, a `Response` (the on-chain leaf), and a `Proof` (response + Merkle proof). [`FdcVerification`](../../../contracts/fdc/implementation/FdcVerification.sol) has one verifier method per type.

This page summarizes each type — what it attests, which data sources are supported, and the shape of request and response — at the level needed to consume the attestations on Flare. The detailed per-chain verification rules (encoding specifics, success/failure status, edge cases) live in the upstream [flare-specs FDC AttestationTypes folder](https://github.com/flare-foundation/flare-specs/tree/main/src/FDC/AttestationTypes), which are the authoritative source for what providers compute. Here we focus on the on-chain shape.

For all types, the on-chain `Response` adds three protocol-level fields on top of the request and response bodies: `attestationType` (`bytes32` matching the type name), `sourceId` (`bytes32` matching the source name), `votingRound` (the round that finalized this attestation, set during signing), and `lowestUsedTimestamp` (LUT — see [Making a Request / Lowest Used Timestamp](./MakingARequest.md#lowest-used-timestamp)).

## `Payment`

Attests that a transaction on an external chain transferred a native-currency payment from one address to another, optionally with a payment reference.

**Sources:** `BTC`, `DOGE`, `XRP`.

**`RequestBody`:**

| Field | Type | Notes |
|-------|------|-------|
| `transactionId` | `bytes32` | The external-chain transaction ID. |
| `inUtxo` | `uint256` | UTXO chains: index of source-address input, OR `standardAddressHash` of source. Non-UTXO: `0`. |
| `utxo` | `uint256` | UTXO chains: index of receiving-address output, OR `standardAddressHash`. Non-UTXO: `0`. |

**`ResponseBody`:**

| Field | Type | Notes |
|-------|------|-------|
| `blockNumber` | `uint64` | Block containing the transaction. |
| `blockTimestamp` | `uint64` | Bitcoin/Doge: median time. XRPL: ledger close time. Drives the LUT. |
| `sourceAddressHash` | `bytes32` | `standardAddressHash` of the source. |
| `sourceAddressesRoot` | `bytes32` | Merkle root over all source addresses (UTXO chains). |
| `receivingAddressHash` | `bytes32` | `standardAddressHash` of the receiver, or zero if not applicable. |
| `intendedReceivingAddressHash` | `bytes32` | What the sender *intended* (XRPL `Destination`). |
| `spentAmount` | `int256` | Net spend by source, in source-chain minimal units. |
| `intendedSpentAmount` | `int256` | What the source intended to spend. |
| `receivedAmount` | `int256` | Net received by receiver. |
| `intendedReceivedAmount` | `int256` | What the receiver should have gotten. |
| `standardPaymentReference` | `bytes32` | The chain's standard payment reference (e.g. XRPL `MemoData`). Zero if none. |
| `oneToOne` | `bool` | True iff one source ↔ one receiver (UTXO change-back to source counts; XRPL is always `oneToOne`). |
| `status` | `uint8` | `0` = success, `1` = failed by sender, `2` = failed by receiver. |

**LUT:** the `blockTimestamp`. For BTC/DOGE/XRPL the limit is `1_209_600` (2 weeks).

**Important:** `standardPaymentReference == 0x00…` means *no reference present*. Smart contracts that key on the reference must reject this value as a "no match" — never as a wildcard.

## `BalanceDecreasingTransaction`

Attests that a particular external-chain transaction caused a *decrease* in the balance of a specified address. Used for fraud-proof systems where a controlled address shouldn't be able to spend without governance approval — if it spends, the application can prove it via this type.

**Sources:** UTXO and account-based external chains where the source address can be unambiguously identified.

**`RequestBody`:** `transactionId` (`bytes32`), `sourceAddressIndicator` (`bytes32`).

**`ResponseBody`:** `blockNumber`, `blockTimestamp`, `sourceAddressHash`, `spentAmount`, `standardPaymentReference`.

**LUT:** the `blockTimestamp`.

The asymmetry from `Payment` is that this type doesn't care who *received* — only that the source's balance went down. That's what fraud-proofs against trusted-vault arrangements need.

## `ConfirmedBlockHeightExists`

Attests that a block at a given height on an external chain is confirmed (has at least the chain's required confirmation depth) at a given moment.

**Sources:** the block-producing external chains.

**`RequestBody`:** `blockNumber` (`uint64`), `queryWindow` (`uint64` — how far back from the current top to allow searching).

**`ResponseBody`:** `blockTimestamp`, `numberOfConfirmations`, `lowestQueryWindowBlockNumber`, `lowestQueryWindowBlockTimestamp`.

**LUT:** the `blockTimestamp`.

This is the time-anchor type — applications that need to check "is X amount of time on chain Y past?" or "what was the cross-chain time at this Flare block?" use this.

## `ReferencedPaymentNonexistence`

Attests that *no payment* was made with a specific standard payment reference within a specified time window. Used by FAssets and similar systems to prove that an agent failed to pay an underlying-chain redemption — i.e. the *absence* of a transaction.

**Sources:** chains supporting payment references.

**`RequestBody`:** `minimalBlockNumber`, `deadlineBlockNumber`, `deadlineTimestamp`, `destinationAddressHash`, `amount`, `standardPaymentReference`.

**`ResponseBody`:** `minimalBlockTimestamp`, `firstOverflowBlockNumber`, `firstOverflowBlockTimestamp`.

**LUT:** the earliest of `minimalBlockTimestamp` and the response timestamp fields.

The verification rule: scan every block in the window for any transaction matching `(destinationAddressHash, ≥amount, paymentReference)`. If none is found, the attestation confirms with the `firstOverflowBlock*` fields proving the search reached past `deadlineTimestamp`.

## `EVMTransaction`

Attests that a transaction occurred on a target EVM chain, with the transaction's logs and decoded data accessible on Flare.

**Sources:** `ETH`, `BSC`, `MATIC`, etc. — any EVM-compatible chain the providers support.

**`RequestBody`:** `transactionHash`, `requiredConfirmations`, `provideInput` (`bool`), `listEvents` (`bool`), `logIndices` (`uint32[]`).

**`ResponseBody`:** `blockNumber`, `blockTimestamp`, `sourceAddress`, `isDeployment`, `receivingAddress`, `value`, `input`, `status`, `events[]` (each with `logIndex`, `emitterAddress`, `topics[]`, `data`, `removed`).

**LUT:** the `blockTimestamp`.

This is the heavyweight type — a confirmed `EVMTransaction` attestation lets a Flare contract react to events that happened on Ethereum (or another EVM chain), enabling cross-EVM bridges and oracles. The `logIndices[]` request field lets the requester pick which log entries from the transaction to include in the response (filtering down to relevant events to keep the response compact).

## `AddressValidity`

Attests whether a given address string is a valid address on a given external chain.

**Sources:** `BTC`, `DOGE`, `XRP`.

**`RequestBody`:** `addressStr` (`string`).

**`ResponseBody`:** `isValid` (`bool`), `standardAddress` (`string` — empty if invalid), `standardAddressHash` (`bytes32` — zero if invalid).

**LUT:** `2^64 - 1` (no LUT — the answer is invariant under time).

This is the lightest type. The verification rule is purely string-format: check the address against the chain's encoding scheme (Base58Check for BTC P2PKH/P2SH, Bech32 / Bech32m for SegWit, XRPL's own Base58 dictionary, etc.). No external state lookup is required, so the data is unbounded in age — `LUT = 2^64 - 1`.

## `Web2Json`

Attests the result of a JSON HTTP GET against a specified URL. The most general attestation type — anything reachable over HTTP returning JSON can be brought on chain.

**Sources:** typically `WEB2` or a service-specific source ID.

**`RequestBody`:** `url` (`string`), `httpMethod` (`string`), `headers` (`string`), `queryParams` (`string`), `body` (`string`), `postProcessJq` (`string`), `abiSignature` (`string`).

**`ResponseBody`:** `abiEncodedData` (`bytes`).

**LUT:** the response timestamp (when the providers fetched).

The response is opaque on-chain — `abiEncodedData` is a pre-determined ABI-encoded blob whose shape is given by `abiSignature`. The consumer decodes it on-chain via `abi.decode(responseBody.abiEncodedData, (...))`.

The `postProcessJq` field is a [`jq`](https://stedolan.github.io/jq/) expression applied to the upstream JSON before ABI encoding — this lets a request reduce a giant API response down to just the bytes the consumer needs. Providers run the same `jq` expression on the same fetched JSON, so they all produce the same `abiEncodedData`.

The Web2Json type is what enables off-chain APIs (price feeds, identity providers, KYC results) to be consumed on Flare with the same trust model as on-chain attestations.

## Adding a new type

To add an attestation type to FDC:

1. **Define the interface.** New file in [`contracts/userInterfaces/fdc/IYourType.sol`](../../../contracts/userInterfaces/fdc/) with `RequestBody`, `ResponseBody`, `Response`, `Proof`. Add a sibling `IYourTypeVerification.sol` with `verifyYourType(IYourType.Proof) returns (bool)`.
2. **Add the verifier.** Update [`FdcVerification`](../../../contracts/fdc/implementation/FdcVerification.sol) to implement `verifyYourType` (one-line Merkle proof check) and inherit the new verification interface. Deploy a new implementation; governance calls `upgradeToAndCall` on the proxy.
3. **Configure fees.** Governance calls `FdcRequestFeeConfigurations.setTypeAndSourceFee(bytes32("YourType"), bytes32("Source"), feeWei)` for each source pair.
4. **Configure inflation share** (optional). Governance calls `FdcInflationConfigurations.addFdcConfigurations` to qualify the type for inflation rewards.
5. **Off-chain providers** must update their clients to compute responses for the new type — until they do, users can submit requests but no provider will confirm them.

The same flow with `Fdc2*` contracts adds the type to FDC2.

## A note on encoding stability

Once an attestation type is in production, its `RequestBody` and `ResponseBody` shapes must not change without a coordinated upgrade across providers, contracts, and consumers — the Merkle leaf hash includes the ABI encoding of the response, and any structural change breaks all existing proofs against historical roots. Adding a new type is a contract upgrade plus a provider-software update; *changing* an existing type is an irreversible governance action. In practice, evolving an attestation usually means introducing a new type with a different name (`PaymentV2` etc.) and deprecating the old one.
