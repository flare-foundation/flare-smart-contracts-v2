# Wallet Management

A **wallet** in FCC is a logical container for one or more keys, owned by a project, hosted on a set of TEE machines. Wallets are how applications group keys and bind them to off-chain identities (e.g. an XRPL multisig account).

The on-chain pieces:

- [`WalletManagerFacet`](../../../contracts/tee/facets/WalletManagerFacet.sol) + [`library/WalletManager`](../../../contracts/tee/library/WalletManager.sol) — wallet creation, admin / cosigner set configuration and confirmation, initialization (`closeWalletInitialization`: `CREATED → INITIALIZED`), first-time activation (`enableWallet`: `INITIALIZED → PRODUCTION`).
- [`WalletProjectManagerFacet`](../../../contracts/tee/facets/WalletProjectManagerFacet.sol) + [`library/WalletProjectManager`](../../../contracts/tee/library/WalletProjectManager.sol) — *project*-level grouping (a project owns multiple wallets and is administered by a single project owner).
- [`WalletProjectPauseFacet`](../../../contracts/tee/facets/WalletProjectPauseFacet.sol) + [`library/WalletProjectPause`](../../../contracts/tee/library/WalletProjectPause.sol) — per-project pauser/unpauser delegation lists + the batch `pauseWallets` (`PRODUCTION → PAUSED`) and `unpauseWallets` (`PAUSED → PRODUCTION`) actions. The project owner adds addresses to either list; list members can pause / resume any wallet in their project alongside the owner.
- [`WalletBackupManagerFacet`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol) — admin-share-based key restore (`backupRestore`) AND the path-list-gated direct backup/restore between two TEE machines (`directBackup` / `directRestore`). See [Key management → direct backup / restore](./KeyManagement.md#direct-backup--restore).

## The hierarchy

```
Extension                  ← registered on-chain by extension owner
└── Project                ← created by an address (the project owner)
    └── Wallet             ← created by the project owner
        ├── Key admin set  ← public keys for Shamir-share encryption
        └── Keys[]         ← one or more (keyType, signingAlgo, publicKey) descriptors
```

Every wallet is bound to one extension and one project. Project ownership is transferable; wallet ownership is project-scoped (the wallet inherits the project's owner).

## Projects

A **project** is the administrative unit that groups wallets together for a single off-chain operator. The same project owner address can administer many wallets without re-doing the per-wallet authorization. Each project's `TeeWalletProjectState` (in [`WalletProjectManager`](../../../contracts/tee/library/WalletProjectManager.sol)) holds:

- `owner` — the Flare address authorized to make changes.
- `extensionId` — the extension the project belongs to.
- `keyType` and `signingAlgo` — the project's key configuration.
- `backupManager` — an optional address authorized alongside the owner for backup operations.

The list of wallets under a project is tracked separately in `WalletManager.projectWallets` (queryable via `getProjectWalletIds`).

Projects are created on [`WalletProjectManagerFacet`](../../../contracts/tee/facets/WalletProjectManagerFacet.sol) (`createProject`). Once created, the owner can:

- Create new wallets under the project (`createWallet`).
- Propose / confirm a new project owner (two-step transfer via `proposeNewOwner` / `confirmOwnership`).

## Wallet creation

Bringing a wallet to life is a multi-step flow across `WalletManagerFacet` (and the key facets); a wallet is not configured in a single call.

1. `createWallet(projectId)` — callable only by the project owner. It allocates a `walletId` (`keccak256("WALLET", msg.sender, ++walletCounter)`), records the wallet under the project, sets status to `CREATED`, and emits `WalletCreated(projectId, walletId)`. No TEE machine set or admin set is supplied here.
2. `setAdmins` / `confirmAdmin` and (optionally) `setCosigners` / `confirmCosigner` — configure and confirm the admin and cosigner sets while the wallet is `CREATED` (see [Setting the key admin set](#setting-the-key-admin-set)).
3. `closeWalletInitialization` — locks the admin / cosigner sets and moves the wallet to `INITIALIZED`.
4. Keys are generated under the wallet (see [Key Management](./KeyManagement.md)); the off-chain key-generation / setup instructions to the wallet's TEE machines are emitted by the key facets, not by `createWallet`.
5. `enableWallet` — once the multisig threshold is set and at least that many keys exist, transitions the wallet `INITIALIZED → PRODUCTION` and emits `WalletEnabled(walletId)`.

## Lifecycle states

Wallets have a small state machine. The `WalletStatus` enum on [`IWalletManager`](../../../contracts/userInterfaces/tee/IWalletManager.sol) has exactly four members:

- `CREATED` — wallet exists and is being configured. Admins / cosigners are set and confirmed in this state.
- `INITIALIZED` — `closeWalletInitialization` has been called; admins and cosigners are locked. Keys may now be added before first activation.
- `PRODUCTION` — accepting operations.
- `PAUSED` — operations against the wallet are suspended until it is unpaused.

State transitions:

- `CREATED → INITIALIZED` — `closeWalletInitialization` (owner), once all admins and cosigners are confirmed.
- `INITIALIZED → PRODUCTION` — `enableWallet` (owner), once the multisig threshold is set and at least that many keys exist.
- `PRODUCTION → PAUSED` — `pauseWallets` (batch) on [`WalletProjectPauseFacet`](../../../contracts/tee/facets/WalletProjectPauseFacet.sol), callable by the project owner or a project pauser.
- `PAUSED → PRODUCTION` — `unpauseWallets` (batch) on `WalletProjectPauseFacet`, callable by the project owner or a project unpauser.

## Setting the key admin set

The wallet's key admin set (admins are who can recover the wallet if all TEEs fail) is configured during the `CREATED` phase, before the wallet is initialized:

1. Owner calls `setAdmins(walletId, adminsPublicKeys[], adminsThreshold)` — only valid while the wallet is `CREATED`. Public keys must be valid and de-duplicated, `adminsThreshold` must be in `(0, n]`, and at most `MAX_WALLET_ADMINS` (50, hardcoded) admins can be set. Emits `WalletAdminsSet`.
2. Each admin calls `confirmAdmin(walletId)` from the address derived from their public key. Emits `WalletAdminConfirmed`.
3. (Optionally) the owner sets cosigners via `setCosigners(walletId, cosigners[], cosignersThreshold)` and each cosigner calls `confirmCosigner(walletId)`. At most `MAX_WALLET_COSIGNERS` (50, hardcoded) cosigners can be set.
4. `closeWalletInitialization(walletId)` requires that admins are set and every admin and cosigner has confirmed; it transitions the wallet to `INITIALIZED` and **locks the admin and cosigner sets** — they cannot be changed afterwards.

There is no on-chain method to rotate the admin set after `closeWalletInitialization`.

## Wallet enumeration

Off-chain tooling can list:

- All projects under an extension owner / project owner.
- All wallets under a project.
- All keys under a wallet.
- The current admin set + threshold for each wallet.
- The TEE machines currently custodying each wallet.

The exact view methods live on the relevant facets — e.g. `getProjectWalletIds(projectId)`, `getWalletAdminsAndThreshold(walletId)`, `getWalletAdminsPublicKeysAndThreshold(walletId)`, `getWalletCosignersAndThreshold(walletId)`, and `getWalletStatus(walletId)` on `WalletManagerFacet`.

## What "ownership" of a wallet means

The wallet owner is the Flare address authorized to:

- Generate, delete, and rotate keys (see [Key Management](./KeyManagement.md)).
- Configure the admin / cosigner sets (during the `CREATED` phase only) and initialize / enable the wallet.
- Pause and unpause the wallet (via `WalletProjectPauseFacet`). Pause / unpause authority can also be delegated to per-project pauser / unpauser lists.
- Submit instructions that produce signed operations using the wallet's keys (e.g. signing an XRPL payment).

The owner does **not** hold the keys themselves and cannot extract them. The off-chain TEE machines do; the on-chain owner just authorizes which operations they should perform.

If the owner key is lost, the wallet's keys can be recovered through admin-threshold restore — but the *project ownership* itself can also be transferred (two-step propose/confirm), so a lost owner key is a significant but recoverable failure.

## How wallets relate to FDC2 and PMW

- **FDC2** doesn't custody wallets. It uses TEE machines as ad-hoc verifiers for attestation requests; no per-wallet state is involved.
- **PMW** (Protocol-Managed Wallet) is the headline wallet-using application — hosted by the system extension, it provides multisig accounts on XRPL whose private-key shares are hosted on system-extension TEE machines. PMW operations (signing an XRPL payment, rotating signers) are exactly the wallet-instruction flow described here. See [Extensions / PMW](./Extensions.md#pmw-protocol-managed-wallet).

A consumer building a custom FCC extension that needs key custody (not just attestations) implements its own application logic, then calls into `WalletManagerFacet` and `WalletKeyManagerFacet` to provision wallets, generate keys, and emit signing instructions. The generic wallet primitives are reusable across extensions.
