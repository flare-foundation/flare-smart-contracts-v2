# Key Management

A wallet inside FCC is a secret key (or a set of keys) generated, used, and stored exclusively inside TEE machines. The on-chain side never sees the secret. What it *does* manage:

- Which keys belong to which wallet.
- How keys are generated, deleted, and replaced.
- How keys are **backed up** via Shamir secret sharing across a set of *key admins*.
- How keys are **restored** when a TEE machine fails and the only copies are in admin-encrypted shares.
- The VRF flow that uses TEE-held keys to produce verifiable random outputs.

The on-chain pieces are:

- [`WalletKeyManagerFacet`](../../../contracts/tee/facets/WalletKeyManagerFacet.sol) + [`library/WalletKeyManager`](../../../contracts/tee/library/WalletKeyManager.sol) — generate, delete, restore. Also exposes the read-only [`getKeyNonce(teeId, walletId, keyId)`](../../../contracts/userInterfaces/tee/IWalletKeyManager.sol) view, returning `(uint256 _nonce, bool _teeHoldsKey)` so callers can disambiguate "TEE holds the key at this nonce" from "TEE never held this key".
- [`WalletBackupManagerFacet`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol) — submit and finalize Shamir shares (uses the same `WalletKeyManager` library); additionally drives the [direct backup / restore](#direct-backup--restore) flow gated by [`MachinePathManager`](./Governance.md#machine-path-manager).
- [`VrfFacet`](../../../contracts/tee/facets/VrfFacet.sol) + [`Vrf`](../../../contracts/tee/library/Vrf.sol) — VRF requests and proofs.

## Key types and signing algorithms

The system supports a configurable set of `(keyType, signingAlgo)` pairs. Examples (as `bytes32` ASCII strings):

- `keyType = "secp256k1"` with `signingAlgo = "ECDSA"` — generic EVM / Bitcoin keys.
- `keyType = "ed25519"` with `signingAlgo = "EdDSA"` — XRPL / Solana / many modern chains.
- `keyType = "BLS12_381_G2"` with various BLS signing schemes.

Governance configures the **system-supported** key types via [`ExtensionManagerFacet.addSystemSupportedKeyTypesAndSigningAlgos`](../../../contracts/tee/facets/ExtensionManagerFacet.sol) and can withdraw them via `removeSystemSupportedKeyTypesAndSigningAlgos` (which only blocks *new* projects from selecting that key type / signing algo; existing projects keep their stored `signingAlgo` and are unaffected). Each extension owner then opts into the subset of system-supported types relevant to their use case via `addSupportedKeyTypes`. Generating a key with a type the extension hasn't enabled reverts.

## Key generation

The key-generation flow looks like this:

1. The wallet owner (the project owner — see [Wallet Management](./WalletManagement.md)) calls [`WalletKeyManagerFacet.addKey(_teeId, _walletId, _claimBackAddress)`](../../../contracts/tee/facets/WalletKeyManagerFacet.sol), specifying the target TEE machine and wallet (plus a per-instruction fee as `msg.value`). The key type and signing algorithm are not passed in — they are taken from the wallet's project ([`WalletProjectManager`](../../../contracts/tee/library/WalletProjectManager.sol)).
2. The facet validates: caller is the wallet owner, key type is supported by the extension, the wallet exists and is not paused.
3. The library emits a `(F_WALLET, "KEY_GENERATE")` instruction (a `Instructions.SYSTEM_OP_TYPE_PREFIX` operation — see [Instructions](./Instructions.md)) directed at the wallet's TEE machines, with the requested parameters in the message body. The fee goes to `RewardManager` and the FCC operation-fees layer.
4. **Off-chain**: each TEE in the wallet's group generates the new key in its TEE, deterministically (so replicas converge on the same private key), and signs an acknowledgement that includes the new public key.
5. The off-chain layer collects the threshold of TEE responses and submits an action result back to Flare. `WalletKeyManagerFacet.confirmKey` records the new public key in the wallet's `KeyDefinition` and emits `WalletKeyConfirmed`.

The on-chain bookkeeping holds **public keys only**. The private key only ever exists inside TEE machines.

## Key deletion

```
F_WALLET / KEY_DELETE
```

The owner sends a delete instruction; TEE machines erase the secret material from their secure storage; the on-chain key descriptor is marked deleted. Re-creating a key with the same type for the same wallet creates a *new* private key — not a recovery of the old one.

## Key admins and Shamir backup

A wallet has a set of **key admins** (Flare addresses with associated public keys) and a **threshold** $k$. When the owner instructs a backup, the TEEs:

1. Split each wallet private key into $n$ Shamir secret shares (where $n$ is the admin set size).
2. Encrypt each share with the corresponding admin's public key.
3. Return the $n$ encrypted shares along with a signed attestation of correctness.

The shares are surfaced on-chain (via `WalletBackupManagerFacet`'s submit methods) so each admin can fetch their own. **The contracts never decrypt** — only the admin's private key, off-chain, can recover their share.

The threshold $k$ is what governs restore: any $k$-of-$n$ admins, working together, can decrypt their shares, combine them to reconstruct the secret, and submit the combined result (re-encrypted to a target TEE machine) back through the on-chain restore flow.

## Key restoration

When a TEE machine custodying a wallet has failed (machine `BANNED` or otherwise unrecoverable, with no other TEE in the wallet's set still holding the key), the keys can be restored to a freshly-registered TEE via the admin-threshold path:

1. The wallet owner registers a new TEE (or selects an existing fresh one) and pairs it with the wallet through `WalletKeyManagerFacet`'s restore-init entry.
2. The on-chain layer emits an instruction to the new TEE to begin restore, generating a fresh ephemeral encryption key bound to that machine.
3. Each participating admin (off-chain) decrypts their Shamir share with their private key, re-encrypts it to the new TEE's ephemeral key, and submits it through a `WalletKeyManagerFacet` restore-share entry. The on-chain layer accumulates submissions.
4. Once $k$ admin shares are submitted, the off-chain layer relays them to the new TEE machine, which combines the shares and reconstructs the wallet keys in its secure storage.
5. The new TEE attests to successful restore. The on-chain side records the restored key descriptor and the wallet is back in business.

The cryptographic core (Shamir over the underlying field, threshold checks, share validity) is enforced off-chain inside the TEE. The on-chain piece just routes shares, accumulates a threshold's worth, and keys the machinery on the right wallet.

## Direct backup / restore

A second restore path lets a wallet key be migrated **directly between two TEE machines** without going through admin-decryption + reconstruction. It is gated by a governance-signed [machine-path list](./Governance.md#machine-path-manager) — the extension's governance has to have explicitly approved the `(source teeId, destination teeId)` pair before either operation is callable.

### `directBackup`

Triggers backup creation on the source TEE. Both source and destination must be in `PRODUCTION` status. The source produces an encrypted backup blob and exposes it on its proxy.

```solidity
function directBackup(
    address _sourceTeeId,
    address _destinationTeeId,
    bytes32 _walletId,
    uint64 _keyId,
    address _claimBackAddress
)
    external payable
    returns (bytes32 _instructionId);
```

On-chain validation, in order:

1. **Project auth** — caller must be the wallet's project owner or backup manager.
2. **Both ends are PRODUCTION** — neither side accepts a backup operation in any other status (the backup blob is no use if a side is paused / suspended / banned).
3. **Extension match** — source, destination, and the wallet's project must all share the same extension.
4. **Active-list path** — `(sourceTeeId, destinationTeeId)` must be present in the extension's currently-active signed `MachinePathList`. Reverts `NoActiveMachinePathList` if the extension has never had a signed list, `InvalidMachinePath` if the pair isn't in the active list. The function captures the active list nonce and ships it as `machinePathListNonce` in the instruction payload — the relay client reads the list from chain by `(extensionId, nonce)` and forwards it alongside the instruction so the source TEE can verify path membership locally. For a list approved by a Safe multisig (see [Governance / Approving via a Safe multisig](./Governance.md#approving-via-a-safe-multisig)), the relay instead reads the confirmed artifact — the signed Safe nonce plus the packed owner signatures — from `getMachinePathListSafeApprovalArtifact` and forwards it in place of contract-stored signatures (the `getMachinePathListApprovals` entries remain a fallback pointer to the raw Safe `execTransaction` transaction).
5. **Source actually holds the key** — `getWalletKeyTeeIds(walletId, keyId)` must contain the source teeId; otherwise reverts `SourceTeeDoesNotHoldKey`.
6. **Destination must not already hold the key** — `KeyAlreadyAvailable` fails the call if the destination already holds it, so the source doesn't waste a backup blob.

The function does not read or mutate the destination's per-key nonce. The backup blob is intentionally stateless w.r.t. destination state — see [Read-vs-bump nonce contract](#read-vs-bump-nonce-contract) for why and what protections this preserves.

The dispatched instruction is `(F_WALLET, "KEY_DIRECT_BACKUP")` with payload [`KeyDirectBackup`](../../../contracts/userInterfaces/tee/IWalletBackupManager.sol) (sourceTeeId, walletId, keyId, destination TEE's public key, machinePathListNonce). No additional cosigners are required on the instruction — the governance-signed path list is itself the authorization.

`DirectBackupTriggered` fires with the returned instructionId; the off-chain caller captures that id and passes it as `_backupInstructionId` into the later `directRestore`.

### `directRestore`

Triggers the key import on the destination TEE. The destination must be in `PRODUCTION`; the source must be in any status other than `INITIALIZED` (it may have moved past `PRODUCTION` since the backup was created — what matters is that its attestation is real).

```solidity
function directRestore(
    address _destinationTeeId,
    BackupId calldata _backupId,
    bytes32 _backupInstructionId,
    address _claimBackAddress
)
    external payable
    returns (bytes32 _instructionId);
```

Shares the same restore-side gate block with the legacy `backupRestore` (factored as `_validateRestoreInputs` in the facet): destination PRODUCTION, source not INITIALIZED, destination must not already hold the key, stored public key matches `BackupId.publicKey`, keyType / signingAlgo match the project, all teeIds belong to the extension. The shared block does **not** constrain the reward epoch; each path applies its own reward-epoch rule (below).

In addition:

1. **Recent backup only** — the backup's `rewardEpochId` must be the **current or the immediately preceding** reward epoch, otherwise `InvalidRewardEpochId`. A direct restore is a live machine-to-machine transfer, not an archived-backup restore, so a stale backup is rejected. (The admin-threshold `backupRestore` has no such window: it accepts any older epoch up to `current + 1`, reverting `InvalidRewardEpochId` only for the future.)
2. **Active-list path** — `(BackupId.teeId, destinationTeeId)` must be in the active list (same gate as `directBackup`).
3. **Now mutate the destination nonce** — `WalletKeyManager.increaseKeyNonce(destinationTeeId, walletId, keyId)` bumps the stored value by `+1`. The destination's restore attestation binds to this new value, so a stale attestation cannot be replayed against a later restore call.

The dispatched instruction is `(F_WALLET, "KEY_DIRECT_RESTORE")` with payload [`KeyDirectRestore`](../../../contracts/userInterfaces/tee/IWalletBackupManager.sol) (sourceTeeId, source's proxy URL looked up on-chain, the BackupId, `backupInstructionId` so the destination knows which response to fetch from the source proxy, just-incremented destinationNonce, machinePathListNonce). Again, no cosigners — the path list is the authorization.

`DirectRestoreTriggered` fires with the just-incremented destination nonce.

### Read-vs-bump nonce contract

| Call | Reads destination nonce? | Writes destination nonce? | Value shipped to TEE |
|---|---|---|---|
| `directBackup` | **no** | **no** | n/a |
| `directRestore` | n/a | yes (`increaseKeyNonce`) | the just-incremented value |

The backup blob is stateless with respect to the destination's per-key nonce: the source does not bake any destination state into the encrypted payload. This is deliberate and lets `directRestore` be retried after a failure (each retry bumps the destination nonce) without forcing a re-issue of `directBackup`.

Replay protection lives entirely on the restore side:

- The destination's restore attestation binds to the post-increment `destinationNonce` shipped in `KeyDirectRestore`. A stale attestation cannot be replayed against a later restore call because the nonce will have moved.
- `KeyAlreadyAvailable` blocks a second restore of the same key onto a destination that already holds it.
- `InvalidPublicKey` matches `BackupId.publicKey` against the current on-chain key descriptor — if the key was deleted and regenerated between backup and restore, a stale blob's attested public key will not match the new on-chain value and the restore fails.
- The blob is encrypted to `destinationTeePublicKey`, so only the intended destination TEE can decrypt it.

### When to use which restore

- **Use `backupRestore`** when bringing a key back from admin-encrypted Shamir shares (the original mechanism). The wallet's admin set acts as the trust anchor.
- **Use `directBackup` + `directRestore`** when migrating a key directly between two extension-attested TEE machines. The extension's governance acts as the trust anchor (via the path list); admins are not involved per-operation.

The two paths coexist — neither replaces the other. They share the restore-side validation block (`_validateRestoreInputs`) so any future tightening of that gate applies to both flows uniformly.

## VRF

[`VrfFacet`](../../../contracts/tee/facets/VrfFacet.sol) wraps a separate flow for producing **Verifiable Random Function** outputs from a TEE-held key:

1. A user submits a VRF request — a seed, a target wallet, a key type — via the facet.
2. The facet emits a `(F_WALLET, "VRF")` instruction, carrying the **wallet's cosigner set and threshold** (like every other wallet-key op). A VRF key created under a cosigner threshold therefore has its VRF instructions authorized by those cosigners; a wallet with no cosigners dispatches an empty set.
3. The TEE produces a VRF output using its key and the seed; emits a proof.
4. The off-chain layer relays the proof back; consumer contracts verify it using [`VrfVerifier`](../../../contracts/tee/implementation/VrfVerifier.sol) (a stand-alone contract outside the diamond, deployed directly with no proxy).

Since VRF outputs are deterministic given (key, seed), they're reproducible across all TEEs in a wallet's set — every TEE holding the key produces the same output for the same input.

## Key type support and disabling

When the extension owner removes a key type from the extension's supported set (`removeSupportedKeyTypes`, extension-owner-only), existing keys of that type are not deleted — they're just immobilized. Any new key-generate of that type fails; existing keys can still sign existing operations until the wallet owner explicitly deletes them. This soft-deprecation lets the system retire deprecated cryptographic primitives without breaking running wallets immediately.

## Receiving TEEs for a wallet

When a wallet operation (a PMW `PAY`/`REISSUE`, see [Payments](./Payments.md)) is dispatched, the
instruction is sent to the set of TEEs that currently hold the wallet's keys. That set is computed
by [`WalletKeyManager.receivingTeesAndKeys`](../../../contracts/tee/library/WalletKeyManager.sol):

- For each of the wallet's key ids, it collects the TEEs holding that key that are in `PRODUCTION`
  status (others are skipped — a key with no available holder is reported via the
  `WalletKeysNotAvailable` event).
- It requires the number of available keys to be at least the wallet's `multisigThreshold`,
  reverting `ThresholdNotMet()` otherwise.
- It returns `(teeId, keyId)` pairs — one per available holder, so a TEE holding two of the
  wallet's keys appears twice.

`receivingTeesAndKeys` is **not** a view (it emits `WalletKeysNotAvailable`), so it cannot be read
via `eth_call`. Its read-only twin `getReceivingTeeIds(walletId)` returns just the **deduplicated**
list of receiving TEE ids — identical to what the dispatch path feeds the fee calculation, because
[`InstructionsFacet`](../../../contracts/tee/facets/InstructionsFacet.sol) deduplicates the TEE list
before charging. It applies the same `ThresholdNotMet()` revert and emits nothing. A wallet uses it
(or the convenience [`calculateFeeByWalletId`](./OperationFees.md#setting-per-operation-fees)) to
pre-flight the fee before submitting a payment.

## What's stored on-chain per key

Per key, the [`KeyDefinition`](../../../contracts/tee/library/WalletKeyManager.sol) struct holds:

- The public key (`publicKey`).
- The list of TEE machines currently holding the key (`teeIds`).
- A per-TEE nonce (`nonces`), used for replay protection on delete / restore.

The key's `keyType` and `signingAlgo` are not stored per key — they are fixed at the project level (see [`WalletProjectManager`](../../../contracts/tee/library/WalletProjectManager.sol)); the admin set and threshold are stored at the wallet level (see [`WalletManager`](../../../contracts/tee/library/WalletManager.sol)).

The actual private key, the Shamir shares before they reach admins, and the TEE machine internals are off-chain. The contracts coordinate; they never custody the secret.
