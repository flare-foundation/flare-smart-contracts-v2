# Key Management

A wallet inside FCC is a secret key (or a set of keys) generated, used, and stored exclusively inside TEE machines. The on-chain side never sees the secret. What it *does* manage:

- Which keys belong to which wallet.
- How keys are generated, deleted, and replaced.
- How keys are **backed up** via Shamir secret sharing across a set of *key admins*.
- How keys are **restored** when a TEE machine fails and the only copies are in admin-encrypted shares.
- The VRF flow that uses TEE-held keys to produce verifiable random outputs.

The on-chain pieces are:

- [`WalletKeyManagerFacet`](../../../contracts/tee/facets/WalletKeyManagerFacet.sol) + [`library/WalletKeyManager`](../../../contracts/tee/library/WalletKeyManager.sol) — generate, delete, restore.
- [`WalletBackupManagerFacet`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol) — submit and finalize Shamir shares (uses the same `WalletKeyManager` library).
- [`VrfFacet`](../../../contracts/tee/facets/VrfFacet.sol) + [`Vrf`](../../../contracts/tee/library/Vrf.sol) — VRF requests and proofs.

## Key types and signing algorithms

The system supports a configurable set of `(keyType, signingAlgo)` pairs. Examples (as `bytes32` ASCII strings):

- `keyType = "secp256k1"` with `signingAlgo = "ECDSA"` — generic EVM / Bitcoin keys.
- `keyType = "ed25519"` with `signingAlgo = "EdDSA"` — XRPL / Solana / many modern chains.
- `keyType = "BLS12_381_G2"` with various BLS signing schemes.

Governance configures the **system-supported** key types via [`ExtensionManagerFacet.addSystemSupportedKeyTypesAndSigningAlgos`](../../../contracts/tee/facets/ExtensionManagerFacet.sol). Each extension owner then opts into the subset of system-supported types relevant to their use case via `addSupportedKeyTypes`. Generating a key with a type the extension hasn't enabled reverts.

## Key generation

The key-generation flow looks like this:

1. The wallet owner (the project owner — see [Wallet Management](./WalletManagement.md)) calls `WalletKeyManagerFacet`'s key-generate entry, specifying the wallet, key type, signing algorithm, and a per-instruction fee.
2. The facet validates: caller is the wallet owner, key type is supported by the extension, the wallet exists and is not paused.
3. The library emits a `(F_WALLET, "KEY_GENERATE")` instruction (a `Instructions.SYSTEM_OP_TYPE_PREFIX` operation — see [Instructions](./Instructions.md)) directed at the wallet's TEE machines, with the requested parameters in the message body. The fee goes to `RewardManager` and the FCC operation-fees layer.
4. **Off-chain**: each TEE in the wallet's group generates the new key in its TEE, deterministically (so replicas converge on the same private key), and signs an acknowledgement that includes the new public key.
5. The off-chain layer collects the threshold of TEE responses and submits an action result back to Flare. A facet method records the new public key in the wallet's `KeyDescriptor[]` and emits `KeyGenerated`.

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

When a TEE machine custodying a wallet has failed (no replication sibling left, machine `BANNED` or unrecoverable), the keys can be restored to a freshly-registered TEE via the admin-threshold path:

1. The wallet owner registers a new TEE (or selects an existing fresh one) and pairs it with the wallet through `WalletKeyManagerFacet`'s restore-init entry.
2. The on-chain layer emits an instruction to the new TEE to begin restore, generating a fresh ephemeral encryption key bound to that machine.
3. Each participating admin (off-chain) decrypts their Shamir share with their private key, re-encrypts it to the new TEE's ephemeral key, and submits it through a `WalletKeyManagerFacet` restore-share entry. The on-chain layer accumulates submissions.
4. Once $k$ admin shares are submitted, the off-chain layer relays them to the new TEE machine, which combines the shares and reconstructs the wallet keys in its secure storage.
5. The new TEE attests to successful restore. The on-chain side records the restored key descriptor and the wallet is back in business.

The cryptographic core (Shamir over the underlying field, threshold checks, share validity) is enforced off-chain inside the TEE. The on-chain piece just routes shares, accumulates a threshold's worth, and keys the machinery on the right wallet.

## VRF

[`VrfFacet`](../../../contracts/tee/facets/VrfFacet.sol) wraps a separate flow for producing **Verifiable Random Function** outputs from a TEE-held key:

1. A user submits a VRF request — a seed, a target wallet, a key type — via the facet.
2. The facet emits a `(F_WALLET, "VRF")` instruction.
3. The TEE produces a VRF output using its key and the seed; emits a proof.
4. The off-chain layer relays the proof back; consumer contracts verify it using [`VrfVerifier`](../../../contracts/tee/implementation/VrfVerifier.sol) (a stand-alone UUPS contract outside the diamond).

Since VRF outputs are deterministic given (key, seed), they're reproducible across a wallet's replicated TEEs — every replica produces the same output for the same input.

## Key type support and disabling

When governance disables a key type at the system level (`removeSupportedKeyTypes` on the extension), existing keys of that type are not deleted — they're just immobilized. Any new key-generate of that type fails; existing keys can still sign existing operations until the wallet owner explicitly deletes them. This soft-deprecation lets the system retire deprecated cryptographic primitives without breaking running wallets immediately.

## What's stored on-chain per key

Per key, the contracts hold:

- A descriptor: `keyType`, `signingAlgo`, the public key, the key admin set, the threshold.
- A status (active / pending-delete / pending-restore).
- The wallet it belongs to.

The actual private key, the Shamir shares before they reach admins, and the TEE machine internals are off-chain. The contracts coordinate; they never custody the secret.
