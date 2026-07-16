# Machine Lifecycle

A TEE machine progresses through a state machine from registration to operation to retirement. The on-chain piece is in [`MachineManagerFacet`](../../../contracts/tee/facets/MachineManagerFacet.sol) (entry points) and [`library/MachineManager`](../../../contracts/tee/library/MachineManager.sol) (storage and helpers).

## States

```solidity
enum TeeStatus {
    NONE,                // 0 — not registered
    INITIALIZED,         // 1 — registered, awaiting first availability check
    PRODUCTION,          // 2 — live, accepting instructions
    SUSPENDED,           // 3 — failed availability check or stale; can be revived with a fresh proof
    PAUSED,              // 4 — voluntarily paused by owner, or version disabled
    BANNED               // 5 — removed by extension owner; cannot return to PRODUCTION
}
```

The machine's state lives in `MachineManager.TeeMachineState`:

```solidity
struct TeeMachineState {
    uint256 extensionId;             // 0 = system extension, otherwise a registered extension
    PublicKey teePublicKey;          // tee identity public key
    address initialTeeId;            // dormant — always address(0); retained for forward compatibility
    uint32 initialSigningPolicyId;   // FSP signing policy at first PRODUCTION; binds the machine's identity to a policy
    address owner;                   // the TEE operator
    address teeProxyId;              // off-chain TEE proxy address
    TeeStatus status;
    uint256 lastStatusChangeTs;
    bytes32 codeHash;                // hash of the TEE software image
    bytes32 platform;                // identifier for the TEE hardware/runtime
    string url;                      // proxy URL
}
```

`teeId` (the machine's primary key) is the address derived from `teePublicKey`. State is held in two indexed sets — `activeTeeIds` (all `PRODUCTION` machines, system-wide) and `extensionActiveTeeIds[extensionId]` (per-extension subset) — kept in sync with status transitions.

## Registration

```solidity
function register(
    TeeMachineData calldata _teeMachineData,
    Signature calldata _teeMachineDataSignature,
    address _teeProxyId,
    string calldata _url,
    address _claimBackAddress
) external payable;
```

Caller is the proposed owner (`msg.sender == _teeMachineData.initialOwner`). `TeeMachineData` carries the extension id, the TEE public key, the initial owner, the `(codeHash, platform)` pair, **and a `governanceHash`** committing the registration to a specific extension-governance signer set (or to zero to opt out of governance-signed flows entirely). This is a one-time, permanent choice — see the note under Validation. Validation:

- The caller's address must be on the **owner allowlist** for the target extension ([`OwnerAllowlist.isAllowedTeeMachineOwner`](../../../contracts/tee/library/OwnerAllowlist.sol)). If not, `OwnerNotAllowed()`.
- `governanceHash` must be either `bytes32(0)` *or* the extension's current `latestTeeGovernanceHash` (the most recent value set by `ExtensionGovernanceFacet.setNewTeeGovernance`). Earlier or unrelated hashes are rejected with `InvalidGovernanceHash()`. The hash is then stored on the machine's `TeeMachineState.governanceHash` slot and consumed later by `MachinePathManager` (see [Governance / Machine path manager](./Governance.md#machine-path-manager)), which requires a non-zero stored hash.
  - **The stored `governanceHash` is fixed for the life of the machine.** It is written only here, at registration; there is no method to change it afterward. A machine registered with `bytes32(0)` is therefore permanently excluded from governance-signed flows (`MachinePathManager`, and the machine-path-authorized backup/restore paths that depend on it) — it is not a "not yet" that can be opted into later. To participate, the owner registers a *new* machine committing to the extension's `latestTeeGovernanceHash`. Conversely, a machine bound to a specific `governanceHash` stays bound to that exact signer set even after the extension rotates its governance — it does not follow later `setNewTeeGovernance` updates.
- `publicKey` must be a valid uncompressed secp256k1 public key.
- `_teeMachineDataSignature` must be the EIP-191 signature, by the corresponding TEE private key, over `SignedPayload.messageHash(TEE_MACHINE_REGISTER, keccak256(abi.encode(_teeMachineData)))`. The recovered address becomes the `teeId`. The [`SignedPayload`](../../../contracts/utils/lib/SignedPayload.sol) envelope adds the `TEE_MACHINE_REGISTER` domain prefix and binds `block.chainid`, so the same TEE registration signature cannot be replayed across Flare networks. Since the inner `dataHash` covers the full `_teeMachineData` struct (including `governanceHash`), the TEE itself commits to the governance it's registering under.
- `_teeProxyId != 0`, `_url` non-empty.
- `(codeHash, platform)` must be on the extension's supported version list ([`ExtensionManager.isCodeHashPlatformSupported`](../../../contracts/tee/library/ExtensionManager.sol)).
- `teeId` must not already be registered (`AlreadyRegistered()`).

On success the state row is initialized at `INITIALIZED` with `initialTeeId = 0`. The `initialTeeId` slot is currently **dormant** — it stays `address(0)` for every machine throughout its lifecycle. The field is retained on-chain (in `TeeMachineState`, `getInitialTeeId`, and `IMachineManager.TeeMachineWithAttestationData`) so that future functionality requiring it can be re-introduced without a storage migration. The TEE-signed system-state payload presented at availability checks must be empty; see [Verification / System state verification](./Verification.md#system-state-verification) for the verifier semantics.

The facet then fires an **initial availability-check instruction** — a system-only `(F_REG, "TEE_ATTESTATION")` instruction directed at this single machine, with a random `challenge`. The challenge is stored in `Verification.State.challenges[teeId]` so the response can be matched. The fee paid (`msg.value`) covers the instruction fee.

`TeeMachineRegistered(teeId, teeProxyId, owner, extensionId, url, codeHash, platform, governanceHash)` is emitted.

## Going to PRODUCTION

```solidity
function toProduction(ITeeAvailabilityCheck.Proof calldata _proof) external;
```

Drives the transition `INITIALIZED → PRODUCTION` (after registration), `PAUSED → PRODUCTION` (resume), or `SUSPENDED → PRODUCTION` (recover from failed availability).

Validation:

- For `INITIALIZED` and `PAUSED`, only the owner may call. For `SUSPENDED`, anyone may call (the network reviving a stalled machine).
- `(codeHash, platform)` must still be supported (a version disabled mid-life forces a longer recovery path).
- The proof's `responseBody.status == OK` and the proof's timestamp ≥ `lastStatusChangeTs` (rejects stale proofs).
- `Verification.verifyAvailabilityCheckProof(teeMachine, oldStatus, _proof)` validates the TEE machine's signature(s) over the response and matches it against the stored challenge.
- For `INITIALIZED → PRODUCTION`, this is the first time the machine binds to a signing policy: `state.initialSigningPolicyId = _proof.responseBody.initialSigningPolicyId`. That policy ID is **immutable** thereafter — it's how the system knows when a machine pre-existed a given signing policy (and thus shouldn't be trusted for messages from earlier policies).

On success: status set to `PRODUCTION`, `lastStatusChangeTs` updated, the machine added to the active sets, the next availability-check window scheduled (`Verification.extendAvailability`).

## Pausing

Two `pause(teeId)` flavors:

- **Owner-initiated `pause(teeId)`** — voluntary. Only the owner can call. Status must be `PRODUCTION` or `SUSPENDED`. Becomes `PAUSED`.
- **Expired-availability `pause(teeId)`** — anyone can call if the machine's availability check has expired (`Verification.getAvailabilityCheckValidity(teeId).endTs < block.timestamp`) and the caller is not the owner. Status must be `PRODUCTION`. Becomes `SUSPENDED` (a softer pause that can be revived by anyone with a fresh proof, vs. `PAUSED` which only the owner can lift).

There is no permissionless "version-disabled" pause path: disabling a `(codeHash, platform)` pauses every active machine running it directly, in the same transaction, via [`disableCodeHashPlatforms`](./Extensions.md#configuring-versions) — so no off-chain watcher is needed to retire them.

A third path, `pauseWithProof(_proof)`, is a permissionless suspend triggered by submitting a *failing* availability-check proof: the proof's response data is invalid, **or** its `status != OK`. Status `PRODUCTION` → `SUSPENDED`. This is the rest of the network's way to take a misbehaving machine out of production without owner cooperation.

All paths emit `TeeMachineStatusChanged(teeId, newStatus)`.

## Emergency pause

Per-extension **emergency pause** is a boolean overlay maintained by [`MachineEmergencyPauseFacet`](../../../contracts/tee/facets/MachineEmergencyPauseFacet.sol) + [`library/MachineEmergencyPause`](../../../contracts/tee/library/MachineEmergencyPause.sol). It is a separate concern from a machine's `TeeStatus` — **machine statuses are not mutated** when the overlay flips, and neither are the active sets. While `emergencyPaused[extensionId]` is `true`, the single on-chain effect is:

- [`Instructions.sendInstructions`](../../../contracts/tee/library/Instructions.sol) reverts `EmergencyPauseActive(extensionId)`. Every dispatch path funnels through this library function — `InstructionsFacet.sendInstructions`, `InstructionsFacet.sendSystemInstructions` (both overloads), `VrfFacet.requestVrf`, and every wallet-key / backup flow that emits an instruction. Both regular and system opTypes are blocked.

Read getters — `getActiveTeeMachines`, `getAllActiveTeeMachines`, `getRandomTeeIds` — are intentionally **not** filtered; the active sets remain authoritative for status. Off-chain consumers that need "is this usable right now" should also call `isExtensionEmergencyPaused(extensionId)`. Verification / key-confirmation flows (`VerificationFacet.confirmAvailability`, `WalletKeyManagerFacet.confirmKey`) are not blocked either — they only record TEE-produced proofs whose generation is independent of the overlay (FDC2 attestations are signed by system-extension TEEs, and key-existence proofs are produced off-chain by the wallet's own TEEs). Blocking them would only delay submission, not prevent any state advance, so the overlay leaves them untouched.

**Pause/unpause access:**
- The extension owner OR an address on the per-extension pauser list can call `emergencyPauseExtension(extensionId)`.
- The extension owner OR an address on the per-extension unpauser list can call `emergencyUnpauseExtension(extensionId)`.
- The lists themselves are managed by the extension owner via `addExtensionEmergencyPausers / Unpausers` and the matching remove methods.

**Post-unpause grace window.** While the overlay is paused, machines' availability proofs can expire (typical validity tracks reward-epoch length — 3.5d on mainnets, 6h on testnets — but a long emergency can still outlast it). On unpause, `emergencyUnpauseTs[extensionId]` is recorded, and for the next `emergencyUnpauseGracePeriodSeconds` (global, governance-tunable; default 2h, bounded by 30 min ≤ x ≤ 24h) the **third-party expired-availability branch** of `pause(teeId)` is blocked (reverts `EmergencyProtectionActive(extensionId)`). This gives machine owners time to refresh attestations before anyone can shove their still-`PRODUCTION` machines to `SUSPENDED`. The owner-initiated branch and `pauseWithProof` remain unaffected.

The protection window **combines the machine's own extension AND the system extension (id 0)**. Refreshing availability requires two on-chain steps: `requestTeeAttestation(teeId)` is routed to the machine's extension (via `Instructions.sendInstructions`), and `requestAvailabilityCheckAttestation(teeId, ...)` is routed through FDC2 to system-extension TEEs only. If either side is currently emergency-paused or still inside its grace window, the third-party `pause()` branch stays blocked — protection holds for the longer of the two grace ends.

The grace duration is set at init via `FlareTeeManagerInit.init`'s `_emergencyUnpauseGracePeriodSeconds` parameter and retunable via `IIMachineEmergencyPause.setEmergencyUnpauseGracePeriodSeconds(seconds)` (governance, timelocked).

## Banning and unbanning

```solidity
function ban(address _teeId) external;
function unban(address _teeId) external;
```

Only the **extension owner** can call. `ban` accepts a machine in `PAUSED`, `SUSPENDED`, or `PRODUCTION` and forces it to `BANNED`. `unban` reverses to `PAUSED` (the machine then needs a fresh availability-check proof and an owner action to return to production).

`BANNED` machines are removed from all active sets. The state row is preserved — the same `teeId` cannot be re-registered, but its history (codeHash, platform, owner, last-known status timestamps) remains queryable.

## Ownership transfer

```solidity
function proposeNewOwner(address _teeId, address _newOwner) external;
function confirmOwnership(address _teeId) external;
```

Two-step transfer like `EntityManager`'s address propose/confirm:

1. Current owner calls `proposeNewOwner(teeId, newOwner)`. `_newOwner` must already be on the extension's allowlist (or `address(0)` to clear the proposal).
2. The new owner (allowlisted) calls `confirmOwnership(teeId)` from their own key. `state.owner` flips.

Setting `_newOwner = address(0)` is how an owner cancels a previously-made proposal without picking a replacement.

## Settings updates

```solidity
function updateTeeMachineSettings(address _teeId, address _teeProxyId, string calldata _url) external;
```

The owner can change the proxy address and URL anytime. **Side effect**: if the machine is `PRODUCTION` or `SUSPENDED`, the change forces it to `PAUSED` (the network needs a fresh availability check at the new endpoint before trusting it again). `INITIALIZED`, `PAUSED`, `BANNED` are unchanged.

## Random selection

```solidity
function getRandomTeeIds(uint256 _extensionId, uint256 _count) external view returns (address[] memory);
```

Used by `Fdc2Hub` (and any extension that wants a random subset) to pick `_count` random TEEs from `extensionActiveTeeIds[_extensionId]`. Reservoir sampling keyed off `relay.getRandomNumber()` (the FSP secure random — see [FSP/RandomNumber](../FSP/RandomNumber.md)). Reverts if `_count > activeCount`.

## Read-only views

```solidity
function getTeeMachineStatus(address) external view returns (TeeStatus);
function getTeeMachineOwner(address) external view returns (address);
function getTeeMachine(address) external view returns (TeeMachine memory);                       // teeId, teeProxyId, url
function getTeeMachineWithAttestationData(address) external view returns (TeeMachineWithAttestationData memory);  // + initialTeeId, codeHash, platform
function getInitialSigningPolicyId(address) external view returns (uint32);
function getPublicKey(address) external view returns (PublicKey memory);
function getLastStatusChangeTs(address) external view returns (uint256);
function getExtensionId(address) external view returns (uint256);
function getActiveTeeMachines(uint256 extensionId) external view returns (address[], string[]);
function getAllActiveTeeMachines(uint256 start, uint256 end) external view returns (address[], string[], uint256 totalLength);
```

The `Active` views skip everything outside `PRODUCTION`. Off-chain selectors (e.g. `Fdc2Hub`'s "use random TEEs" path, or any client picking a TEE to send an instruction to) start from these views.

## Why initial signing policy ID matters

`initialSigningPolicyId` is set once, when a machine first reaches `PRODUCTION`. It records *the FSP signing policy that was active when the machine became trusted*. This is the floor of provenance: a TEE machine signing a message that references a signing policy *older* than its `initialSigningPolicyId` is signing about a state it never witnessed, and the verification layer (see [Verification](./Verification.md)) rejects it. This anchor prevents replay of pre-existing TEE keys against future state.
