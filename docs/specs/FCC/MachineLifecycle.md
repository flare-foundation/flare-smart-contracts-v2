# Machine Lifecycle

A TEE machine progresses through a state machine from registration to operation to retirement. The on-chain piece is in [`MachineManagerFacet`](../../../contracts/tee/facets/MachineManagerFacet.sol) (entry points) and [`library/MachineManager`](../../../contracts/tee/library/MachineManager.sol) (storage and helpers).

## States

```solidity
enum TeeStatus {
    INITIALIZED,         // 0 — registered, awaiting first availability check
    PRODUCTION,          // 1 — live, accepting instructions
    SUSPENDED,           // 2 — failed availability check or stale; can be revived with a fresh proof
    PAUSED,              // 3 — voluntarily paused by owner, or version disabled
    PAUSED_FOR_UPGRADE,  // 4 — paused as part of an extension upgrade
    REPLICATING,         // 5 — being copied to a new machine in the same replication group
    BANNED               // 6 — removed by extension owner; cannot return to PRODUCTION
}
```

The machine's state lives in `MachineManager.TeeMachineState`:

```solidity
struct TeeMachineState {
    uint256 extensionId;             // 0 = system extension, otherwise a registered extension
    PublicKey teePublicKey;          // tee identity public key
    address initialTeeId;            // the address derived from the original public key (immutable)
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

Caller is the proposed owner (`msg.sender == _teeMachineData.initialOwner`). `TeeMachineData` carries the extension id, the TEE public key, the initial owner, the `(codeHash, platform)` pair, **and a `governanceHash`** committing the registration to a specific extension-governance signer set (or to zero if the registrant doesn't yet want to participate in governance-signed flows). Validation:

- The caller's address must be on the **owner allowlist** for the target extension ([`OwnerAllowlist.isAllowedTeeMachineOwner`](../../../contracts/tee/library/OwnerAllowlist.sol)). If not, `OwnerNotAllowed()`.
- `governanceHash` must be either `bytes32(0)` *or* the extension's current `latestTeeGovernanceHash` (the most recent value set by `ExtensionGovernanceFacet.setNewTeeGovernance`). Earlier or unrelated hashes are rejected with `InvalidGovernanceHash()`. The hash is then stored on the machine's `TeeMachineState.governanceHash` slot and consumed later by `MachinePathManager` (see [Governance / Machine path manager](./Governance.md#machine-path-manager)) and by `ReplicationFacet` — both require a non-zero stored hash.
- `publicKey` must be a valid uncompressed secp256k1 public key.
- `_teeMachineDataSignature` must be the signature, by the corresponding TEE private key, over `keccak256(abi.encode(bytes32("TEE_MACHINE_REGISTER"), block.chainid, _teeMachineData))`. The recovered address becomes the `teeId`. The domain tag and `block.chainid` are bound into the payload so the same TEE registration signature cannot be replayed across Flare networks. Since the encoded `_teeMachineData` includes the `governanceHash`, the TEE itself commits to the governance it's registering under.
- `_teeProxyId != 0`, `_url` non-empty.
- `(codeHash, platform)` must be on the extension's supported version list ([`ExtensionManager.isCodeHashPlatformSupported`](../../../contracts/tee/library/ExtensionManager.sol)).
- `teeId` must not already be registered (`AlreadyRegistered()`).

On success the state row is initialized at `INITIALIZED` with `initialTeeId = 0`. The `initialTeeId` slot is **deferred** — it is captured at the first successful availability check (in `toProduction` or `replicateFrom`) from the TEE's signed `TeeSystemState` payload. A TEE binary that supports replication signs a populated payload; the chain stores the attested value. A binary that doesn't support replication signs empty, and `initialTeeId` stays zero permanently — which is the on-chain marker that the machine cannot be replicated, even if its `governanceHash` is non-zero. See [Verification / System state verification](./Verification.md#system-state-verification) for the verifier semantics.

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

Three pause flavors:

- **Owner-initiated `pause(teeId)`** — voluntary. Only the owner can call. Status must be `PRODUCTION` or `SUSPENDED`. Becomes `PAUSED`.
- **Version-disabled `pause(teeId)`** — anyone can call if `(codeHash, platform)` is *disabled* on the extension (governance withdrew support). Status must be `PRODUCTION` or `SUSPENDED`. Becomes `PAUSED`.
- **Expired-availability `pause(teeId)`** — anyone can call if the machine's availability check has expired (`Verification.getAvailabilityCheckValidity(teeId).endTs < block.timestamp`) and the caller is not the owner / version is not disabled. Status must be `PRODUCTION`. Becomes `SUSPENDED` (a softer pause that can be revived by anyone with a fresh proof, vs. `PAUSED` which only the owner can lift).

A fourth path, `pauseWithProof(_proof)`, is a permissionless suspend triggered by submitting a *failing* availability-check proof: the proof's response data is invalid, **or** its `status != OK`. Status `PRODUCTION` → `SUSPENDED`. This is the rest of the network's way to take a misbehaving machine out of production without owner cooperation.

All three paths emit `TeeMachineStatusChanged(teeId, newStatus)`.

## Emergency pause

Per-extension **emergency pause** is a boolean overlay maintained by [`MachineEmergencyPauseFacet`](../../../contracts/tee/facets/MachineEmergencyPauseFacet.sol) + [`library/MachineEmergencyPause`](../../../contracts/tee/library/MachineEmergencyPause.sol). It is a separate concern from a machine's `TeeStatus` — **machine statuses are not mutated** when the overlay flips, and neither are the active sets. While `emergencyPaused[extensionId]` is `true`, the single on-chain effect is:

- [`Instructions.sendInstructions`](../../../contracts/tee/library/Instructions.sol) reverts `EmergencyPauseActive(extensionId)`. Every dispatch path funnels through this library function — `InstructionsFacet.sendInstructions`, `InstructionsFacet.sendSystemInstructions` (both overloads), `VrfFacet.requestVrf`, `WalletResumeFacet.setPausingAddresses`, and every wallet-key / backup / resume flow that emits an instruction. Both regular and system opTypes are blocked.

Read getters — `getActiveTeeMachines`, `getAllActiveTeeMachines`, `getRandomTeeIds` — are intentionally **not** filtered; the active sets remain authoritative for status. Off-chain consumers that need "is this usable right now" should also call `isExtensionEmergencyPaused(extensionId)`. Verification / key-confirmation flows (`VerificationFacet.confirmAvailability`, `WalletKeyManagerFacet.confirmKey`) are not blocked either — they only record TEE-produced proofs whose generation is independent of the overlay (FDC2 attestations are signed by system-extension TEEs, and key-existence proofs are produced off-chain by the wallet's own TEEs). Blocking them would only delay submission, not prevent any state advance, so the overlay leaves them untouched.

**Pause/unpause access:**
- The extension owner OR an address on the per-extension pauser list can call `emergencyPauseExtension(extensionId)`.
- The extension owner OR an address on the per-extension unpauser list can call `emergencyUnpauseExtension(extensionId)`.
- The lists themselves are managed by the extension owner via `addExtensionEmergencyPausers / Unpausers` and the matching remove methods.

**Post-unpause grace window.** While the overlay is paused, machines' availability proofs can expire (typical validity tracks reward-epoch length — 3.5d on mainnets, 6h on testnets — but a long emergency can still outlast it). On unpause, `emergencyUnpauseTs[extensionId]` is recorded, and for the next `emergencyUnpauseGracePeriodSeconds` (global, governance-tunable; default 2h, bounded by 30 min ≤ x ≤ 24h) the **third-party expired-availability branch** of `pause(teeId)` is blocked (reverts `EmergencyProtectionActive(extensionId)`). This gives machine owners time to refresh attestations before anyone can shove their still-`PRODUCTION` machines to `SUSPENDED`. The owner-initiated branch, version-disabled branch, and `pauseWithProof` all remain unaffected.

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

The owner can change the proxy address and URL anytime. **Side effect**: if the machine is `PRODUCTION` or `SUSPENDED`, the change forces it to `PAUSED` (the network needs a fresh availability check at the new endpoint before trusting it again). `INITIALIZED`, `PAUSED`, `PAUSED_FOR_UPGRADE`, `REPLICATING`, `BANNED` are unchanged.

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

## What replication looks like in this state machine

`REPLICATING` is the transient status of the **new** machine being paired into an upgrade — see [Replication](./Replication.md). The upgrade source (`_oldTeeId`) moves `PRODUCTION → PAUSED → PAUSED_FOR_UPGRADE` and, on `confirmReplicate`, back to `PRODUCTION` carrying the new machine's identity; the new machine starts at `INITIALIZED`, is moved to `REPLICATING` by `replicateFrom`, and has its state row deleted when `confirmReplicate` absorbs it into the source's row. Until the upgrade finishes, both machines are out of the active sets.
