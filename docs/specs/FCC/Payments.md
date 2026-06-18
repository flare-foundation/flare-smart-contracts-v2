# PMW Payments (`TeePayments`)

The `TeePayments*` contracts let the owner of a **Protocol Managed Wallet (PMW)** — a multisig wallet on an external chain (XRPL, BTC, …) whose keys are held by FCC TEE machines — instruct payments out of that wallet. They sit **outside** the [`FlareTeeManager`](../../../contracts/tee/) diamond as their own UUPS-upgradeable proxies, and turn a high-level *"pay recipient `R` amount `A` from account `X`"* call into a signed `TeeInstructionsSent` event that the relay/TEE pipeline picks up, signs on the target chain, and broadcasts.

A PMW account is identified by the pair `(sourceId, accountAddress)` and bound to a Flare `walletId`. Two payment models exist, discriminated by [`ITeePaymentsModel.paymentModel()`](../../../contracts/userInterfaces/tee/ITeePaymentsModel.sol):

| Model | Contract | Example chains | Nonce model | Reissue |
|-------|----------|----------------|-------------|---------|
| `ACCOUNT` | [`TeePayments`](../../../contracts/tee/implementation/TeePayments.sol) | XRPL, EVM | one native sequence per account | single payment |
| `UTXO` | [`TeePaymentsUtxo`](../../../contracts/tee/implementation/TeePaymentsUtxo.sol) | BTC, DOGE | per-anchor nonce streams, batched | whole batch |

Both inherit the shared [`TeePaymentsBase`](../../../contracts/tee/implementation/TeePaymentsBase.sol). The split exists because the two chain families have fundamentally different transaction-ordering models: account chains have a single monotonic sequence per address, whereas UTXO chains spend specific outputs, so FCC runs several parallel "anchor" chains per wallet and nonces are per-anchor.

Supporting contracts, all outside the diamond:

- [`TeePaymentsRegistry`](../../../contracts/tee/implementation/TeePaymentsRegistry.sol) — maps each `sourceId` to its `(keyType, opType, paymentModel, TeePayments)` binding.
- [`TeePaymentsConfigVerifier`](../../../contracts/tee/implementation/TeePaymentsConfigVerifier.sol) — requests and validates the PMW configuration attestations used to register accounts/anchors.
- [`TeePaymentsFeeScheduleManager`](../../../contracts/tee/implementation/TeePaymentsFeeScheduleManager.sol) / [`TeePaymentsLimitsManager`](../../../contracts/tee/implementation/TeePaymentsLimitsManager.sol) — per-extension fee schedules and payment caps (see [Operation Fees](./OperationFees.md)).

## Shared base — registration, authorization, dispatch

[`TeePaymentsBase`](../../../contracts/tee/implementation/TeePaymentsBase.sol) holds the state and plumbing common to both models:

- `accountHashToWalletId` — `keccak256(abi.encode(sourceId, accountAddress))` → `walletId`.
- `walletAccounts` — the list of `PMWMultisigAccount` per wallet.
- `authorizationAddresses` — the address allowed to submit payment instructions for an account (set at registration).
- `paymentHashes` — `keccak256(abi.encode(paymentInstruction, paymentId))` per `(accountHash, paymentId)`, recorded at `pay` time so a later reissue can prove it is re-sending a known payment.

**Registration** (`addPMWMultisigAccount`, model-specific) follows the same shape in both contracts:

1. Call `teePaymentsConfigVerifier.verify{Account,Utxo}ConfiguredProof(walletId, proof)` — this **validates** the attestation (reverts on an invalid proof) and **returns nothing**.
2. `_registerAccount(walletId, sourceId, accountAddress, authorizationAddress)` — validates wallet ownership (`getOwner == msg.sender`), system extension id, key type (`_sourceKeyType`), and that the wallet is in `PRODUCTION`/`PAUSED`; computes the account hash; rejects a duplicate; writes the account, authorization address, and `walletAccounts` entry.
3. Seed model-specific state and emit the model's registration event.

Because the whole FDC2 proof (header + request body + response body) is signature-verified together, the payment contracts read the verified fields **straight from the calldata `proof`** — there is no returned struct.

**Authorization** — `pay`/`reissue` are gated by `_checkAuthorizationAddress` (`authorizationAddresses[accountHash] == msg.sender`); registration and `addAnchors` are gated by wallet ownership.

**Dispatch** — `_sendPaymentInstructions` forwards `msg.value` to [`FlareTeeManager.sendSystemInstructions`](../../../contracts/tee/facets/InstructionsFacet.sol) with the computed `instructionId`, the receiving TEEs, the op type/command, the ABI-encoded message, and the wallet's cosigner set. That emits the `TeeInstructionsSent` event the off-chain pipeline consumes.

**Fee pre-flight** — `pay`/`reissue` are `payable` and revert `FeeTooLow()` if `msg.value` is short of the per-instruction fee (see [Operation Fees](./OperationFees.md)). A wallet computes the exact amount to send with the read-only `getPaymentFee(account, opCommand)` on `TeePaymentsBase` (shared by both models): it resolves the wallet from the account (`accountHashToWalletId`, reverting `PMWMultisigAccountNotRegistered()` for an unknown account) and the op type from the source (`_sourceOpType`), then returns `FlareTeeManager.calculateFeeByWalletId(walletId, opType, opCommand)`. Pass `bytes32("PAY")` or `bytes32("REISSUE")` as `opCommand`; the result equals what the corresponding dispatch will charge (it reverts `ThresholdNotMet()` if the wallet has too few available keys).

## Config verifier

[`TeePaymentsConfigVerifier`](../../../contracts/tee/implementation/TeePaymentsConfigVerifier.sol) is the single place that both requests and verifies PMW configuration attestations, for both models:

- `requestAccountConfiguredAttestation(...)` / `requestUtxoConfiguredAttestation(...)` — wallet owners call these directly to trigger an FDC2 attestation request (the request body carries the account index / anchors / public keys; the source id rides in the FDC2 header).
- `verifyAccountConfiguredProof(walletId, proof)` / `verifyUtxoConfiguredProof(walletId, proof)` — **validate-only**: they re-run the signing-policy / TEE-signature and cosigner checks through the shared stateless [`Fdc2ProofVerification`](../../../contracts/fdc2/library/Fdc2ProofVerification.sol) library, cross-check the proof's public keys against the wallet's confirmed keys, and (for UTXO) validate the anchor-set shape. They revert on any failure and return nothing.

The verifier is stateless with respect to accounts — it never writes account/anchor storage; the payment contracts do. See also [FDC / Verification](../FDC/Verification.md#what-changes-for-fdc2).

## Registry

[`TeePaymentsRegistry`](../../../contracts/tee/implementation/TeePaymentsRegistry.sol) is the source-of-truth for which `TeePayments` contract owns a `sourceId` and which model it uses. Governance registers sources with `registerSources`, which validates that the bound contract's `paymentModel()` matches the declared model. Lookups used on the hot path:

- `getSourceOpTypeAndTeePayments(sourceId)` / `getSourceKeyTypeAndTeePayments(sourceId)` — `(opType|keyType, teePayments)`; the payment contracts assert `teePayments == address(this)` to reject unsupported sources.
- `getSourcePaymentModel(sourceId)` — used by `TeePaymentsFeeScheduleManager` to restrict fee-schedule config to `ACCOUNT` sources.

## Account model — `TeePayments`

State per account is minimal: `AccountState { uint64 initialNonce; uint64 nextPaymentId; }`. `initialNonce` is seeded at registration from the attested `responseBody.sequence`; `nextPaymentId` starts at 1.

**`pay(account, paymentInstruction, claimBackAddress)`**

1. `paymentId = nextPaymentId++`; record `paymentHashes[accountHash][paymentId]`.
2. Native nonce = `_nativeNonce(initialNonce, paymentId)` = `initialNonce + paymentId - 1`.
3. Build the `PaymentInstructionMessage` (wallet id, sender/recipient, amount, max fee, fee schedule from `TeePaymentsFeeScheduleManager.getEffectiveSchedule`, payment reference, nonce, paymentId).
4. Instruction id = `keccak256(abi.encode(opType, "PAY", sourceId, accountAddress, nonce))`.
5. Dispatch. Returns `paymentId`.

**`reissue(account, paymentId, [paymentInstruction], reissueFeeParams, claimBackAddress)`** re-sends exactly one previously-paid payment (e.g. with a higher max fee). It requires `paymentInstructions.length == 1`, verifies the supplied instruction against the stored `paymentHashes[accountHash][paymentId]` **before** any external calls (cheap revert), bumps a per-`(account, paymentId)` `reissueCounter` to a `reissueNumber`, and dispatches with op command `"REISSUE"` and instruction id `keccak256(abi.encode(opType, "REISSUE", sourceId, accountAddress, nonce, reissueNumber))`. It always returns `true` — the account model reissues a single payment in one instruction, so it is finalized immediately.

The registration event is `PMWMultisigAccountAdded(walletId, sourceId, accountAddress, authorizationAddress, initialNonce)`.

## UTXO model — `TeePaymentsUtxo`

The UTXO model is the more involved one. A wallet account runs **N parallel anchor chains**; payments are grouped into **batches** routed onto one anchor at a time; each anchor has its own monotonic nonce stream.

### Anchors

Each account stores an array of `UtxoAnchorState { string anchorAddress; bytes32 genesisAnchorTxid; uint32 genesisAnchorVout; uint64 nextNonce; uint64 availableAt; }`. Anchors are **grow-only**:

- `addPMWMultisigAccount(walletId, proof, authorizationAddress)` registers the account and its initial anchor set (`_appendAnchors` from the verified proof), seeds `nextPaymentId = 1`, `batchSize = 1`, `accountIndex`, and `anchorCount`, then emits `PMWMultisigUtxoAccountAdded(walletId, sourceId, accountAddress, accountIndex, anchorCount, authorizationAddress)` and `UtxoBatchSettingsSet`.
- `addAnchors(proof)` grows the set. It derives the account from the (verifier-validated) proof, checks `accountIndex` still matches (`AccountIndexMismatch`), requires strictly more anchors than stored (`NoNewAnchors`), checks the new set is a **prefix-preserving superset** of the stored anchors via `_checkStoredAnchorsMatch` (`AnchorMismatch`), appends the new ones, and emits `UtxoAnchorsAdded(walletId, sourceId, accountAddress, accountIndex, anchorCount)`.

The anchor address validity (non-empty, set bounds) is enforced by the config verifier at proof time, so the contract trusts the validated proof.

### Anchor selection (cyclic round-robin)

When a new batch opens, `_openBatch` scans anchors cyclically starting from the per-account `nextAnchorIndex` cursor and takes the **first anchor whose reuse window has cleared** (`availableAt <= block.timestamp`). If a candidate is busy it moves on to the next (including any freshly added chains); only if **all** anchors are still busy does it revert `AnchorNotReady(earliestAvailableAt)`. On selection it advances the cursor, consumes the anchor's nonce (`batchNonce = anchor.nextNonce++`), and pins the anchor's reuse window when the batch closes (`availableAt = closedAt + defaultAnchorReuseDelaySeconds[sourceId]`). The reuse delay ensures at most one unconfirmed batch per anchor at a time.

### Batches

A **batch** groups one or more payments that share one anchor and one nonce. Batch fields live in `AccountState` (`batchPaymentId`, `batchEndTs`, `batchPaymentCount`, `batchSizeEffective`, `batchNonce`, `batchAnchorIndex`, `batchRewardEpochId`, `batchOpen`). On the first `pay` after a batch closes, `_openBatch` snapshots the **effective** batch size and duration (capped by the per-source `MaxBatchSettings`) into `batchSizeEffective` / `batchEndTs` — so a settings change mid-batch only affects the *next* batch.

`_closeOpenBatchIfDue` closes the open batch when any of:

- it is **full** — `batchPaymentCount >= batchSizeEffective` (`_isBatchFull`);
- it has **ended** — `block.timestamp > batchEndTs`;
- the **reward epoch changed** — `batchRewardEpochId != currentRewardEpochId`.

`pay` closes a due batch, opens a fresh one if needed, records the payment, and — because the only *new* close reason after open is fullness (block time and reward epoch are fixed within a call) — captures `_isBatchFull` once and, if full, closes the batch **at the current block**, emitting `batchEndTs = block.timestamp` (the actual close time) rather than the planned end. That lets off-chain consumers detect a full close immediately via the standard "`batchEndTs` has passed" rule without tracking batch-size history. Closing stamps a `BatchRecord { nonce, batchEndTs, paymentCount, anchorIndex, rewardEpochId }`.

### Instruction id and message

The UTXO instruction id binds the anchor index and the per-anchor nonce:

```
PAY:     keccak256(abi.encode(opType, "PAY",     sourceId, accountAddress, anchorIndex, nonce))
REISSUE: keccak256(abi.encode(opType, "REISSUE", sourceId, accountAddress, anchorIndex, nonce, reissueNumber))
```

`(walletId, anchorIndex, nonce)` is the batch identity everywhere off-chain, so the id preimage places `anchorIndex` immediately before `nonce`; every off-chain party that recomputes the id must match this byte ordering. The message (`UtxoPaymentInstructionMessage`) carries the account index, the selected anchor's index / address / genesis outpoint, the nonce, the payment id, the batch payment id, and `batchEndTs`.

### Reissue / replacement

`reissue(account, batchPaymentId, paymentInstructions, reissueFeeParams, claimBackAddress)` re-sends the payments of an already-closed batch (e.g. to bump fees, or to nullify with a negative fee factor). The batch must have ended.

A `ReplacementAttempt { uint64 id; uint64 nextPaymentId; uint64 emittedCount; uint24 rewardEpochId; bool finalized; uint256[] blocks; }` tracks progress per `(accountHash, batchPaymentId)`:

- A reissue whose first instruction matches the batch's *first* payment **starts a fresh attempt** (`++id`, reset `nextPaymentId`/`emittedCount`/`blocks`), emitting `UtxoReplacementStarted`. Otherwise it **continues** the active attempt (must be non-finalized and in the same reward epoch).
- `_checkPaymentRange` ensures the requested range stays within the batch's `[batchPaymentId, batchPaymentId + paymentCount)` window — the global `paymentHashes` keying alone can't prevent spilling into a neighbouring batch's payment ids.
- Each instruction is validated against its stored payment hash, then dispatched with `reissueNumber = replacement.id` in the instruction id (so two attempts that both restart from the beginning derive distinct ids). The same receiving TEEs are fetched once and reused across the batch's instructions.
- `_recordReissueBlock` appends `block.number` (deduped) to `blocks` — the exact blocks the watcher must scan, instead of a wide range.
- When `emittedCount == batch.paymentCount`, the attempt **finalizes**: `_finalizeReplacement` emits `UtxoReplacementReady(walletId, accountHash, batchPaymentId, replacementId, firstPaymentId, paymentCount, blocks)`. `reissue` returns `true` once the whole batch has been re-emitted, `false` while a multi-call replacement is still in progress.

### Batch settings

`setBatchSettings(account, batchSize, batchDurationSeconds)` (wallet-owner) sets the account's preferred batch size/duration (effective from the next batch). Governance caps them per source via `setMaxBatchSettings` and sets the per-source anchor reuse delay via `setDefaultAnchorReuseDelay`. Getters: `getBatchSettings`, `getMaxBatchSettings`, `getDefaultAnchorReuseDelay`, `getAnchor`, `getAnchorCount`.

## Fees and limits

Payment fee schedules and caps are **not** part of the instruction-dispatch contracts:

- [`TeePaymentsFeeScheduleManager`](../../../contracts/tee/implementation/TeePaymentsFeeScheduleManager.sol) holds per-source fee schedules; `pay`/`reissue` read the effective schedule via `getEffectiveSchedule` and embed it in the message. Reissue may override it via `reissueFeeParams` (a single zero-delay factor schedule; scheduled signatures are not supported — `ScheduledSignaturesUnsupported`).
- [`TeePaymentsLimitsManager`](../../../contracts/tee/implementation/TeePaymentsLimitsManager.sol) holds per-extension payment caps, set through its own `SET_PAYMENT_LIMITS` instruction path.

See [Operation Fees](./OperationFees.md) for how these relate to the in-diamond per-instruction `OperationFees`.

## Events

All events and errors are declared on the public `I*` interfaces ([`ITeePaymentsBase`](../../../contracts/userInterfaces/tee/ITeePaymentsBase.sol), [`ITeePayments`](../../../contracts/userInterfaces/tee/ITeePayments.sol), [`ITeePaymentsUtxo`](../../../contracts/userInterfaces/tee/ITeePaymentsUtxo.sol)):

| Event | Emitted by | Meaning |
|-------|-----------|---------|
| `PMWMultisigAccountAdded(walletId, sourceId, accountAddress, authorizationAddress, initialNonce)` | `TeePayments` | account-model account registered |
| `PMWMultisigUtxoAccountAdded(walletId, sourceId, accountAddress, accountIndex, anchorCount, authorizationAddress)` | `TeePaymentsUtxo` | UTXO-model account registered |
| `UtxoAnchorsAdded(walletId, sourceId, accountAddress, accountIndex, anchorCount)` | `TeePaymentsUtxo` | anchor set grown (new total) |
| `UtxoBatchSettingsSet(walletId, sourceId, accountAddress, batchSize, batchDurationSeconds)` | `TeePaymentsUtxo` | batch settings (re)configured |
| `UtxoReplacementStarted(walletId, accountHash, batchPaymentId, replacementId, firstPaymentId, startBlock)` | `TeePaymentsUtxo` | a fresh reissue attempt began |
| `UtxoReplacementReady(walletId, accountHash, batchPaymentId, replacementId, firstPaymentId, paymentCount, blocks)` | `TeePaymentsUtxo` | a reissue attempt finalized (whole batch re-emitted) |

The actual `pay`/`reissue` dispatch surfaces as the diamond's `TeeInstructionsSent` event (see [Instructions](./Instructions.md)), keyed by the instruction id described above.
