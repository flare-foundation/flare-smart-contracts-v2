# Wallet Management

A **wallet** in FCC is a logical container for one or more keys, owned by a project, hosted on a set of TEE machines (one or more, typically a replication group). Wallets are how applications group keys and bind them to off-chain identities (e.g. an XRPL multisig account).

The on-chain pieces:

- [`WalletManagerFacet`](../../../contracts/tee/facets/WalletManagerFacet.sol) + [`library/WalletManager`](../../../contracts/tee/library/WalletManager.sol) — wallet creation, owner administration, key admin set updates, first-time activation (`enableWallet`: `INITIALIZED → PRODUCTION`).
- [`WalletProjectManagerFacet`](../../../contracts/tee/facets/WalletProjectManagerFacet.sol) + [`library/WalletProjectManager`](../../../contracts/tee/library/WalletProjectManager.sol) — *project*-level grouping (a project owns multiple wallets and is administered by a single project owner).
- [`WalletProjectPauseFacet`](../../../contracts/tee/facets/WalletProjectPauseFacet.sol) + [`library/WalletProjectPause`](../../../contracts/tee/library/WalletProjectPause.sol) — per-project pauser/unpauser delegation lists + the batch `pauseWallets` (`PRODUCTION → PAUSED`) and `unpauseWallets` (`PAUSED → PRODUCTION`) actions. The project owner adds addresses to either list; list members can pause / resume any wallet in their project alongside the owner.
- [`WalletBackupManagerFacet`](../../../contracts/tee/facets/WalletBackupManagerFacet.sol) — admin-share-based key restore (`backupRestore`) AND the path-list-gated direct backup/restore between two TEE machines (`directBackup` / `directRestore`). See [Key management → direct backup / restore](./KeyManagement.md#direct-backup--restore).
- [`WalletResumeFacet`](../../../contracts/tee/facets/WalletResumeFacet.sol) + [`library/WalletResume`](../../../contracts/tee/library/WalletResume.sol) — resume wallet operations after a pause / upgrade.

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

A **project** is the administrative unit that groups wallets together for a single off-chain operator. The same project owner address can administer many wallets without re-doing the per-wallet authorization. `WalletProjectManager` holds:

- Project ID (assigned at creation).
- Owner address (the Flare address authorized to make changes).
- Project-level configuration (key admin set defaults, etc.).
- The list of wallets under the project.

Project creation typically requires an extension to opt into project-based access (some extensions might host individual wallets directly). Once created, the owner can:

- Create new wallets under the project.
- Update the project's default key admin set (applied to new wallets going forward — existing wallets retain their original admin set unless changed individually).
- Propose / confirm a new project owner (two-step transfer).

## Wallet creation

The headline entry creates a wallet and attaches it to a project. Inputs (the exact parameter names live on `IWalletManager` / `WalletManagerFacet` — see source for current shape):

- `extensionId` and `projectId`.
- The desired set of TEE machines that will custody the wallet (must all be `PRODUCTION` and in the same extension).
- Key admin set: addresses + their public keys, plus the Shamir threshold $k$.
- Initial key descriptors (optional — the owner can also add keys later via key-generate operations).

The facet:

1. Validates the project (exists, caller is owner, extension matches).
2. Validates the TEE machine set (all `PRODUCTION`, all same extension, deduplicated).
3. Validates the admin set (no duplicates, valid public keys, threshold $\le n$).
4. Allocates a wallet ID.
5. Emits a `(F_WALLET, "WALLET_SETUP")` system instruction targeted at the chosen TEEs, carrying the admin set and any initial key requests in the message body. The TEE machines run the setup operation in their isolated environment; they generate any initial keys deterministically; they return signed acknowledgements.
6. Once the threshold of TEE responses arrives, a follow-up facet method records the wallet's public state and the wallet is live.

## Lifecycle states

Wallets have a small state machine:

- `ACTIVE` — accepting operations.
- `PAUSED` — owner-paused, or paused as part of a TEE upgrade. Operations against the wallet revert until resumed.
- `RESTORING` — wallet's keys are being restored from Shamir shares (see [Key Management / Restoration](./KeyManagement.md#key-restoration)). Operations are blocked.
- `RETIRED` — terminal. Wallet has been wound down, keys deleted; the on-chain state is preserved for historical lookups.

State transitions are owner-initiated (`pause`, `resume` — see `WalletResumeFacet`) or system-driven (extension upgrade pauses all wallets in the affected machines; restore flow drives `ACTIVE → RESTORING → ACTIVE`).

## Key admin set updates

The wallet's key admin set can be changed *after* creation. This is a sensitive operation — admins are who can recover the wallet if all TEEs fail — so it's a multi-step flow:

1. Owner proposes a new admin set + threshold via `WalletManagerFacet`.
2. The facet emits an instruction to the wallet's TEEs: "rotate the Shamir-shared backup to this new admin set, $k$-of-$n$".
3. TEEs encrypt fresh shares for the new admin set, return them.
4. Once shares are accepted on-chain (per the backup flow), the new admin set is recorded and the old one is invalidated.

Until step 4 completes, the wallet retains the old admin set — there is no window where the wallet has no recovery path.

## Wallet enumeration

Off-chain tooling can list:

- All projects under an extension owner / project owner.
- All wallets under a project.
- All keys under a wallet.
- The current admin set + threshold for each wallet.
- The TEE machines currently custodying each wallet.

The exact view methods live on the relevant facets and follow the same pattern: pagination-friendly `(start, end)` getters that return arrays plus a `totalLength`.

## What "ownership" of a wallet means

The wallet owner is the Flare address authorized to:

- Generate, delete, and rotate keys (see [Key Management](./KeyManagement.md)).
- Update the admin set / threshold.
- Pause and resume the wallet.
- Submit instructions that produce signed operations using the wallet's keys (e.g. signing an XRPL payment).

The owner does **not** hold the keys themselves and cannot extract them. The off-chain TEE machines do; the on-chain owner just authorizes which operations they should perform.

If the owner key is lost, the wallet's keys can be recovered through admin-threshold restore — but the *project ownership* itself can also be transferred (two-step propose/confirm), so a lost owner key is a significant but recoverable failure.

## How wallets relate to FDC2 and PMW

- **FDC2** doesn't custody wallets. It uses TEE machines as ad-hoc verifiers for attestation requests; no per-wallet state is involved.
- **PMW** (Protocol-Managed Wallet) is the headline wallet-using application — hosted by the system extension, it provides multisig accounts on XRPL whose private-key shares are hosted on system-extension TEE machines. PMW operations (signing an XRPL payment, rotating signers) are exactly the wallet-instruction flow described here. See [Extensions / PMW](./Extensions.md#pmw-protocol-managed-wallet).

A consumer building a custom FCC extension that needs key custody (not just attestations) implements its own application logic, then calls into `WalletManagerFacet` and `WalletKeyManagerFacet` to provision wallets, generate keys, and emit signing instructions. The generic wallet primitives are reusable across extensions.
