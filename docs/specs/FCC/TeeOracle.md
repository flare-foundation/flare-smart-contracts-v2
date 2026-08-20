# TEE oracle

The TEE oracle is a generic, reusable FCC **extension** that turns a fleet of TEE machines into
FTSO custom feeds: machines observe values from configured data sources inside the enclave, sign
them, and anyone can land the signed observations on-chain, where each feed is served to
consumers through FtsoV2 like any other feed. USDX/USD is the first deployed instance.

Two contracts implement it, both UUPS proxies on the new
[`FlareGovernance`](../../../contracts/governance/lib/FlareGovernance.sol) stack
(via [`FlareUpgradeableBase`](../../../contracts/governance/implementation/FlareUpgradeableBase.sol)):

| Contract | Role |
|----------|------|
| [`TeeOracleInstructionsSender`](../../../contracts/tee/extensions/oracle/implementation/TeeOracleInstructionsSender.sol) | One per extension — the extension's registered instructions sender. Dispatches feed-observation requests and governance-published configuration to the machines, and keeps the per-feed configuration commitments the stores enforce. |
| [`TeeOracleFeedStore`](../../../contracts/tee/extensions/oracle/implementation/TeeOracleFeedStore.sol) | One per feed — accepts TEE-signed feed updates and implements [`IICustomFeed`](../../../contracts/customFeeds/interface/IICustomFeed.sol), so it registers with [`FtsoV2`](../../../contracts/protocol/implementation/FtsoV2.sol) directly as a custom feed with its own timestamp (and a possibly signed value). |

Public interfaces: [`ITeeOracleInstructionsSender`](../../../contracts/userInterfaces/tee/ITeeOracleInstructionsSender.sol),
[`ITeeOracleFeedStore`](../../../contracts/userInterfaces/tee/ITeeOracleFeedStore.sol).
One sender serves **all** feeds of its extension — configuration commitments, versions and
publications are kept per feed and per machine — so a single machine fleet can run multiple
oracles at once.

## Operation types and commands

All instances share one operation type and three commands (file-level constants on
[`ITeeOracleInstructionsSender`](../../../contracts/userInterfaces/tee/ITeeOracleInstructionsSender.sol)):

- `TEE_ORACLE_OP_TYPE = bytes32("TEE_ORACLE")`
- `GET_FEED_COMMAND = bytes32("GET_FEED")` — feed observation request
- `SET_ENDPOINTS_COMMAND = bytes32("SET_ENDPOINTS")` — endpoint configuration publication
- `SET_ADMINS_COMMAND = bytes32("SET_ADMINS")` — admin signer-set publication

The [operation-fee table](./OperationFees.md) keys on `(opType, opCommand)`, so the three
commands get independently priced fee rows shared by every TEE oracle instance; per-feed
distinctions live in extension membership and inside the signed payloads, never in the op type.

## Configuration publications

Governance publishes two kinds of configuration to chosen machines, per feed, through the
sender (`onlyGovernance`, timelocked in production):

- **Endpoints** — `setEndpoints(feedId, teeIds[], EndpointGroup[], claimBackAddress)`. Tagged
  groups of upstream data endpoints (`bytes32` group tag = a chain's RPC set, a public or
  private API, ... — semantics pinned in the enclave build), each with an agreement
  `threshold`. An endpoint is either **PUBLIC** (plain `https://...` URL, optionally with a
  placeholder token — e.g. `{secret}` — substituted inside the enclave with the credential
  named by `secretRef`) or **PRIVATE** (only a salted `urlHash` commitment on-chain; the URL
  itself is provisioned off-chain like a credential — a commitment is used instead of a
  TEE-pubkey-encrypted URL because an on-chain ciphertext would expose the URL forever if the
  machine's key ever leaked).
- **Admins** — `setAdmins(feedId, teeIds[], AdminRole[], claimBackAddress)`. Role-tagged admin
  signer sets (e.g. `bytes32("backing")`, `bytes32("providers")`) with per-role thresholds —
  the admins decide who may install credentials in the enclave. Role semantics (which
  credentials a role governs, required roles, role-specific floors) are pinned in the enclave
  build; the contract enforces only role-agnostic shape rules.

Each publication assigns the feed's next monotonic **version** (contract-assigned, inside the
ABI-encoded payload, so identical content republished still yields a new hash), records
`keccak256(message)` and the version per feed and machine **before** dispatch — so an
undelivered instruction blocks stale submissions — and dispatches one instruction to all
targeted machines, which therefore share one version and hash (fleet-comparable generations).
Targets are validated as unique, non-zero machines **of this extension** (`TeeIdNotInExtension`
— the diamond derives the extension from the machines and registering a sender on a foreign
extension needs no consent, so the target extension is pinned explicitly).

The publication fee rides as `msg.value`: `executeGovernanceCall` is payable and forwards its
value into the executed call (see [Governance](../Governance.md)), so the executor attaches the
fee at execution time; recording a timelocked call rejects value (`TimelockValueNotAllowed`).
The whole value is forwarded to the diamond (and on to the reward manager); fees of unexecuted
instructions are claimable to the caller-chosen `claimBackAddress`.

## Feed updates

1. **Request** — anyone calls `requestFeedUpdate(feedId, teeIds[]) payable`. Every targeted
   machine must have both configuration kinds published for the feed
   (`isTeeIdConfigured(feedId, teeId)`, else `TeeIdNotConfigured`); the instruction message is
   the ABI-encoded `FeedUpdateRequest{feedId}` and the fee is `msg.value`
   (`claimBackAddress = msg.sender`).
2. **Observation** — the machine reads its configured sources and builds a
   [`FeedUpdate`](../../../contracts/userInterfaces/tee/ITeeOracleFeedStore.sol):
   `{extensionId, feedId, value (int32), decimals (int8), observedAt, endpointsHash, adminsHash}`.
   The value uses the FTSO-style int32 + dynamic-decimals representation (the enclave picks the
   scale); `observedAt` is the timestamp of an emitted on-chain event, so it is always strictly
   in the past at submission. It signs
   `SignedPayload.ethSignedHash(TEE_ORACLE_FEED, keccak256(abi.encode(feedUpdate)))` — the
   canonical [`SignedPayload`](../../../contracts/utils/lib/SignedPayload.sol) envelope
   (domain prefix + chain id + data hash), same as every other TEE signature.
3. **Submission** — anyone calls `submitFeedUpdate(feedUpdate, signature)` on the feed's store.
   The store:
   - recovers and authorizes the signer through
     [`Fdc2Verification.verifyTeeSignature(extensionId, sig, messageHash)`](../../../contracts/fdc2/implementation/Fdc2Verification.sol)
     — PRODUCTION machine of the extension, extension not emergency paused;
   - checks the **feed binding**: the signed update must name this store's `extensionId` and
     `feedId` (`WrongExtensionId` / `WrongFeedId`) — one constant signing prefix serves every
     deployment, so the binding inside the payload is what prevents replaying an update onto
     another feed served by the same extension;
   - checks the **configuration commitments**: `endpointsHash` / `adminsHash` must equal the
     sender's current per-feed-and-machine expectations (`StaleEndpoints` / `StaleAdmins`,
     `NoEndpointsPublished` / `NoAdminsPublished`) — the machine proves it runs the feed's
     latest published configuration;
   - checks time: `observedAt` must strictly increase (`NotNewer` — replay and out-of-order
     protection) and be strictly below `block.timestamp` (`TooFarAhead` — the observation
     event and the update cannot land in the same block, and a future-dated timestamp would
     freeze the feed irreversibly, since `observedAt` only ratchets up);
   - stores value, decimals and timestamp (one packed storage slot) and emits `FeedUpdated`.

There is no acceptance window and no pause flag: staleness is the consumer's check (as with
every FTSO feed), and the FCC per-extension
[emergency pause](../../../contracts/userInterfaces/tee/IMachineEmergencyPause.sol) already
stops submissions at the verifier.

## Reading a feed

The store implements `IICustomFeed`, so after governance registers it via
`FtsoV2.addCustomFeeds([store])` it is read like any feed — including through the signed
`getCurrentFeed(s)` family with per-feed timestamps (see
[FTSO / FeedManagement](../FTSO/FeedManagement.md)). Reading is paid:

- `calculateFee()` resolves through the central
  [`FeeCalculator`](../../../contracts/fastUpdates/implementation/FeeCalculator.sol)
  (per-feed override → category fee → default fee, all governance-settable there); FtsoV2
  forwards exactly that fee.
- `getCurrentFeed()` requires the fee (`FeeTooLow`) and forwards the **entire** `msg.value` to
  the governance-set `feeDestination` — no refund of overpayment, so nothing ever accumulates
  on the store. It reverts with `NoValuePublished` until the first update lands (an unpublished
  store must not read as "value 0"), and serves negative values (FtsoV2's unsigned read paths
  reject those with `"value negative"`).
- The value and decimals have **no free getters** — the fee gates on-chain consumers
  (off-chain readers can always inspect storage directly). `observedAt` is public.

## Discovery

- `sender.getFeedIds()` — every feed with both configuration kinds published, in
  first-completed order.
- `sender.isTeeIdConfigured(feedId, teeId)` — whether both commitments are published for the
  pair (publication, not proof — proof-of-running shows when the machine's updates pass the
  store's commitment checks).
- Candidate machines come from the diamond's `getActiveTeeMachines(extensionId)`; indexers can
  also follow the `EndpointsSet` / `AdminsSet` / `FeedUpdateRequested` / `FeedUpdated` events.

## Deployment and lifecycle

[`DeployTeeOracle.s.sol`](../../../deployment/scripts/DeployTeeOracle.s.sol) (wrapper:
`deployment/scripts/deploy-tee-oracle.sh <network> [--dry-run]`) deploys one sender proxy for
`teeOracleExtensionId` plus one feed store proxy per `teeOracleFeeds` chain-config entry
(`{registryName, feedCategory, feedName}`; the feed id is
`bytes21(category byte || name || zero padding)`, category in the custom range `[32, 64)`),
wires everything through the AddressUpdater (`FlareTeeManager` for the sender;
`Fdc2Verification` + `FeeCalculator` for the stores), sets the read-fee destination from
the `teeOracleFeeDestinationAddress` chain parameter (a config setting — currently the burn
address on all networks, matching FastUpdater's live fee destination; changeable later via the
governance `setFeeDestination` setter), and switches all proxies to production mode.

Steps the script cannot perform:

| Step | Who |
|------|-----|
| `registerReserved(extensionId, owner)` on the diamond | Flare governance (timelocked) |
| `setExtensionContracts(extensionId, 0, sender)`, `addTeeVersion`, `addAllowedTeeMachineOwners`, `setNewTeeGovernance` | extension owner (direct) |
| `setOperationFees` `TEE_ORACLE` rows | Flare governance (timelocked; the default fee applies until then) |
| `FtsoV2.addCustomFeeds([stores])` | Flare governance (timelocked) |
| `setEndpoints` / `setAdmins` per feed and machine | Flare governance (timelocked; the executor attaches the fee) |

The stores cache the sender's `extensionId` at initialization (it is initializer-only on the
sender, so it cannot diverge) and refuse to initialize against an uninitialized sender
(`ZeroExtensionId`). Feed id, extension wiring and the decimal scale have no setters — exotic
rotations go through a `reinitializer` upgrade, and a scale change means a new store and feed.

## The USDX instance

The first deployment serves **USDX/USD**: reserved extension id `1`, feed id category `32`,
name `"USDX/USD"`, registry name `UsdxFeedStore` — all in the `teeOracle*` block of
[`deployment/chain-config/`](../../../deployment/chain-config/). The enclave-side USDX
implementation pins the group tags (per-chain RPC sets plus the reserve APIs) and the admin
role tags (`backing`, `providers`) described above.
