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
| [`TeeOracleInstructionsSender`](../../../contracts/tee/extensions/oracle/implementation/TeeOracleInstructionsSender.sol) | One per extension — the extension's registered instructions sender. Stores the governance-published per-feed configuration and its hash (which the stores enforce), dispatches it to the extension's active set as part of the publication and to lagging machines on a permissionless push, and dispatches feed-observation requests. |
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

## Configuration: publish and auto-dispatch, push to catch up

Governance publishes a feed's configuration values; the same call then delivers them to the
extension's machines. The machine list is **not** a parameter — the publication resolves it
itself from `getActiveTeeMachines(extensionId)` inside the call body. That is deliberate: a
timelocked governance call's arguments are frozen when the call is *recorded*
([`FlareGovernance`](../../../contracts/governance/lib/FlareGovernance.sol) stores only
`keccak256(encodedCall)`), while the fleet's composition is only known when the executor *runs*
it. A target list in the signature therefore makes the whole publication unexecutable whenever one
named machine restarted, was paused or was re-keyed during the timelock; reading the active set in
the body is a snapshot of the *executing* block instead, so nothing about the fleet can invalidate
an approved publication and there is no delay between publishing a configuration and the fleet
receiving it.

That set is dispatched to **verbatim** — the publication applies no eligibility predicate of its
own. `extensionActiveTeeIds[extensionId]` in
[`MachineManager`](../../../contracts/tee/library/MachineManager.sol) is an `EnumerableSet`
written only by `changeStatus`: a machine is added on the transition to `PRODUCTION` and removed on
`PAUSED` / `SUSPENDED` / `BANNED`. The set is therefore exactly this extension's `PRODUCTION`
machines, with no duplicate, no zero address and no foreign-extension id, so there is nothing for
a filter to find — and a fresh version is new to every machine in it.

A separate permissionless `pushEndpoints` / `pushAdmins` covers what the publication could not:
machines registered afterwards, a publication whose dispatch was skipped, and an instruction that
never reached its enclave. The push is handed the configuration *values* by its caller, re-encodes
them canonically and checks the result against the stored hash — the contract keeps **only** the
hash (see [Storage model](#storage-model-hash-on-chain-payload-in-the-log)).

### Publication (governance)

`setEndpoints(feedId, version, EndpointGroup[], claimBackAddress) payable` and
`setAdmins(feedId, version, AdminRole[], claimBackAddress) payable` on
[`IITeeOracleInstructionsSender`](../../../contracts/tee/extensions/oracle/interface/IITeeOracleInstructionsSender.sol)
are `onlyGovernance` and name no machines:

- **Endpoints** — tagged groups of upstream data endpoints (`bytes32` group tag = a chain's RPC
  set, a public or private API, ... — semantics pinned in the enclave build), each with an
  agreement `threshold`. An endpoint is either **PUBLIC** (plain `https://...` URL, optionally
  with a placeholder token — e.g. `{secret}` — substituted inside the enclave with the credential
  named by `secretRef`) or **PRIVATE** (only a salted `urlHash` commitment on-chain; the URL
  itself is provisioned off-chain like a credential — a commitment is used instead of a
  TEE-pubkey-encrypted URL because an on-chain ciphertext would expose the URL forever if the
  machine's key ever leaked).
- **Admins** — role-tagged admin signer sets (e.g. `bytes32("backing")`,
  `bytes32("providers")`) with per-role thresholds — the admins decide who may install
  credentials in the enclave. Role semantics (which credentials a role governs, required roles,
  role-specific floors) are pinned in the enclave build; the contract enforces only
  role-agnostic shape rules.

Each publication validates the payload's shape, takes the **governance-signed `version`** as the
feed's next one (`endpointsVersion` / `adminsVersion`, required to be exactly the current value plus
one — see [Version ordering](#version-ordering-governance-signs-the-version); part of the
ABI-encoded payload, so identical content republished still yields a new version and hash), stores its
`keccak256` (`latestEndpointsHash` / `latestAdminsHash`) and the timestamp
(`endpointsPublishedAt` / `adminsPublishedAt`), and emits `EndpointsPublished` /
`AdminsPublished` **carrying the published `EndpointGroup[]` / `AdminRole[]` in full**. The payload
itself is never stored — see [Storage model](#storage-model-hash-on-chain-payload-in-the-log).

Those six per-feed values live in **one** `FeedConfig` struct in one mapping — three slots, the
four `uint64`s sharing one — so a publication reads and writes a single struct; the individual
getters above are written out explicitly and `getFeedConfig(feedId)` returns the whole thing for
tooling. The per-machine record is likewise one packed `MachineVersions` slot per (feed, machine)
holding both kinds' dispatched versions, exposed as `expectedEndpointsVersion` /
`expectedAdminsVersion` and as `getMachineVersions(feedId, teeId)`. That packing is what lets
`requestFeedUpdate` check both kinds of a target with one cold `SLOAD` instead of two.

**Only then** does it attempt delivery, to the extension's active set as it stands in that block.
On the dispatch path the per-machine version records move (`expectedEndpointsVersion` /
`expectedAdminsVersion`), one `EndpointsSet` / `AdminsSet` is emitted per target, and one
instruction goes out with the whole `msg.value`.

The policy for a delivery that cannot happen is **skip only what the executor cannot fix, revert
everything they can**:

| Condition | Behavior |
|-----------|----------|
| Extension is emergency paused (`isExtensionEmergencyPaused`) | dispatch skipped, values published — the diamond hard-rejects every dispatch while paused ([`Instructions`](../../../contracts/tee/library/Instructions.sol)), and a corrected configuration must stay landable, not least because the pause may exist *because* the live configuration is wrong. Checked **before** the active set is read: `getActiveTeeMachines` is unpaginated and also builds a `string[]` of machine URLs the sender discards, which a paused publication must not pay for |
| The extension's active set is empty | dispatch skipped, values published — the fleet may not be registered yet |
| The signed `version` is not the feed's current version plus one | **reverts** (`UnexpectedConfigVersion(signed, expected)`) — nothing is published; see [Version ordering](#version-ordering-governance-signs-the-version) |
| `msg.value` is **below** the instruction fee of the snapshotted targets | **reverts** inside the diamond (`FeeTooLow`) — nothing is published. The sender does no fee arithmetic of its own on any path: it forwards the whole `msg.value` and [`Instructions`](../../../contracts/tee/library/Instructions.sol) enforces the floor. A **surplus** does not revert — see [The fee, and what a surplus costs](#the-fee-and-what-a-surplus-costs) |
| Unset / wrong TEE manager, or this contract is no longer the extension's registered instructions sender | **reverts** inside the diamond (`OnlyInstructionsSender`) — a deployment mistake must surface, not be hidden |

Reverting is cheap, which is what makes it the right default:
[`FlareGovernance.executeGovernanceCall`](../../../contracts/governance/lib/FlareGovernance.sol)
deletes the timelocked call's entry *before* the inner `address(this).call{value: msg.value}` and
bubbles the revert, so a failed execution rolls that deletion back too — the pending call survives
and the executor simply re-executes in the next block, with no re-proposal and no second timelock.

### The fee, and what a surplus costs

The fee is the **executor's**: `executeGovernanceCall` is payable and forwards its value into the
executed call, while recording a timelocked call still rejects value (`TimelockValueNotAllowed`).
Size it with `getEndpointsPublicationFee()` / `getAdminsPublicationFee()`, read in the block the
execution lands in, and attach that; while the extension is emergency paused they report no
machines and no fee, mirroring the publication's own skipped dispatch. A **skipped** dispatch must
carry no value (`ValueNotNeeded`): the executed
body runs as `address(this).call(...)`, so its `msg.sender` **is the sender contract**, and
`FlareGovernance` does not record who called `executeGovernanceCall` — the executor cannot be
identified, so there is nobody to refund, and keeping their fee here would be worse than telling
them to re-execute with none attached.

That same unidentifiable payer is why the dispatched instruction's `claimBackAddress` is an
explicit **argument** of the publication rather than something the contract derives. It is the
destination of the fee if the instruction is never executed, so it has to be the wallet that
funded the execution — and the contract cannot see who that was. Deriving it from
`FlareGovernance.governance()` would have sent the claim-back to governance for an instruction the
executor paid for. Freezing the address at proposal time is safe in a way that freezing a machine
list is not: a stale address cannot make the execution revert, where a machine that left
`PRODUCTION` during the timelock would; the worst case is naming a wallet since retired, which
governance recovers from by cancelling the pending call and re-proposing. `address(0)` is rejected
(`ZeroClaimBackAddress`) — [`Instructions`](../../../contracts/tee/library/Instructions.sol) stores
the claim-back unvalidated, so a zero would silently make an unexecuted instruction's fee
unreclaimable. The permissionless methods take no such argument: their payer *is* `msg.sender`.

On the dispatching path the sender forwards the **whole** `msg.value` and imposes no fee rule of
its own — exactly as the permissionless `requestFeedUpdate` / `push*` methods do. The gate is the
diamond's: [`Instructions`](../../../contracts/tee/library/Instructions.sol) requires
`calculatedFee <= msg.value` (`FeeTooLow`) and then hands the **entire** value to
`RewardManager.receiveRewards` **in the same transaction**, keeping no balance of its own;
`claimBackAddress` is only carried into the emitted `TeeInstructionsSent`. Two consequences follow,
and together they are why an exact-fee requirement on the publication was considered and
deliberately **not** adopted:

- for an instruction that is **never executed**, the full recorded value — surplus included — is
  claimable to the claim-back address, so an overpayment is not lost there;
- for an instruction that **is executed**, the whole value has already been distributed as that
  epoch's rewards and nothing on chain separates the fee from the surplus, so the surplus is not
  returned.

So the practical guidance is unchanged — read `get*PublicationFee` in the executing block and
attach what it says — but the failure mode of a stale quote differs by direction: too little
reverts (`FeeTooLow`, and is retryable as described above), while too much simply donates the
difference to the reward pool. A fleet that shrinks between the read and the execution — a machine
paused or suspended, or a changed fee row — therefore overpays rather than reverting.

### Version ordering: governance signs the version

The version is an **argument** of the publication, not something the contract derives when the call
executes, and it must be exactly the feed's current version for that kind **plus one**
(`UnexpectedConfigVersion(signed, expected)`). Endpoints and admins have separate streams.

The reason is how the timelock identifies a pending call.
[`FlareGovernance`](../../../contracts/governance/lib/FlareGovernance.sol) records it under
`keccak256(encodedCall)` — the hash of the *whole* calldata — so two `setEndpoints` calls for the
same feed with different payloads are two **independent** pending entries, each executable on its
own, in either order, and nothing removes one when the other is proposed. With the version computed
at execution time, an older publication executed *after* its replacement would take the higher
version, overwrite the commitment and be dispatched to the whole active fleet: the superseded
configuration would become the feed's latest. Stale **admins** are the serious case — a removed or
compromised administrator re-authorised under a newer version number.

Signing the version makes that a safe failure instead. Both calls of a supersede pair are proposed
while the feed is at version *n*, so both sign *n+1*; whichever executes first consumes it and the
other becomes permanently unexecutable. Two operational rules follow:

- **Sign the next consecutive version.** Read `endpointsVersion(feedId)` / `adminsVersion(feedId)`
  (or `getFeedConfig`) when proposing. Deliberately sequential publications are fine — sign *n+1*
  and *n+2*, and the second cannot execute before the first, which is what keeps the stored versions
  strictly consecutive.
- **Cancel a superseded pending call**, with `cancelGovernanceCall`, rather than leaving it queued:
  it can no longer execute, so it only clutters the timelock.

Governance tooling should therefore display the signed version and **all** pending calls per feed
and kind, and refuse to schedule a competing publication for the same feed and kind by default.

Equality is required rather than "greater than": an execution allowed to jump would let a single
publication land near `type(uint64).max` and exhaust the remaining version space, and at the maximum
the checked increment reverts (arithmetic overflow) rather than wrapping round to a version the
machines already hold.

### Storage model: hash on chain, payload in the log

The contract commits to a configuration by its `keccak256` **alone**. The values are emitted, as
the typed `EndpointGroup[]` / `AdminRole[]`, in `EndpointsPublished` / `AdminsPublished` and never
written to storage. `pushEndpoints` / `pushAdmins` take those same values back, re-encode them
exactly as the publication did — `abi.encode(Endpoints({version, feedId, groups}))`, with the
**version read from storage** — and require the result to hash to the stored commitment
(`WrongConfigPayload`).

The event logs the *array*, not the surrounding `Endpoints` / `Admins` wrapper: the wrapper's other
two fields are the event's own indexed `feedId` and `version` topics, and the push rebuilds the
wrapper itself, so logging it would duplicate both. What the log carries is therefore exactly what
the push takes — read `groups` from the event, pass it straight to
`pushEndpoints(feedId, teeIds, groups)`, no extraction step.

That is a gas decision, measured on this branch:

| | payload stored on chain | hash only, payload as calldata |
|---|---|---|
| per PUBLIC endpoint (~70-char URL) | ~217,000 gas — **96% of a publication** | ~8,000 gas |
| 25 groups × 5 endpoints (48.2 KB encoded) | ~30.5M gas | ~1.3-1.5M gas |
| against the block gas limit | **over** the 28,000,000 limit on `flare`, `songbird`, `coston2` and `coston` — unpublishable | ~5% of a block |

A 21-24x factor, and the difference between a configuration that can be published at all and one
that cannot. Storage at ~625 gas per fresh byte simply does not scale to a real endpoint set.

What it costs:

- **A log-retention dependency.** The payload exists only in the publication's event, so a pusher
  has to read it from there (an indexer, an archive query, or the execution receipt). A payload
  nobody retained is unpushable until governance republishes it. This is the deliberate trade;
  the on-chain state is unaffected, since the store only ever reads the hash.
- **No `getEndpointsMessage` / `getAdminsMessage`.** Those views are gone — there is nothing for
  them to return. The live configuration is read from the log, not from contract state.
- **The payload is ABI-encoded twice per publication.** Once by `abi.encode(...)`, whose result
  serves *both* the commitment and the instruction body (one encode, two uses); once more by `emit`
  for the log data. The two cannot share a buffer: the instruction body wraps the array in
  `Endpoints`, while the log data is the bare array behind an offset, and `emit` cannot be pointed
  at existing memory in any case. Only a hand-rolled `log3` over a mutated buffer could reuse one,
  which is not worth raw assembly for the ~8,700 gas involved. What *is* worth doing, and is done,
  is building the `Endpoints` struct in memory explicitly and handing the event
  `endpoints.groups` — the copy already made for the encode. Emitting the calldata `_groups`
  instead makes the log encoder traverse calldata a second time: **~52,000 gas more** on a 48 KB
  payload, for a byte-identical log.

What it does *not* cost:

- **Correctness of the push.** The push takes the payload's **fields**, not raw bytes. With raw
  bytes, hash equality would depend on the *caller's* ABI encoder reproducing the published bytes
  exactly; taking the fields and encoding canonically inside the contract means any correct set of
  field values hashes correctly, whatever library or language the keeper uses. The version is not a
  parameter at all — it comes from storage — so a caller can neither name a wrong one nor deliver a
  superseded generation: the values of an older publication simply fail the hash check, and
  identical content republished pushes as the *new* version. Handing an `Admins` payload to
  `pushEndpoints` is a compile-time type error rather than a runtime check. The payload is not
  re-validated: a hash match proves it was validated at publication.
- **Affordability.** Typing the *event* costs ~8,700 gas on a 48 KB payload — under 1% of the
  publication. Typing the *push parameter* costs ~385,000 gas at 25 × 5, because the contract
  re-encodes the nested payload from calldata instead of hashing calldata directly: ~32% of the push
  transaction, though still only ~4% of a block (see the table under
  [Push](#push-permissionless-pusher-pays)). That is the measured price of encoder-independence.
- **Recoverability when the dispatch is skipped.** The publication event carries the payload
  **unconditionally**, dispatch or no dispatch. That is required, not a convenience: when the
  extension is emergency paused or its active set is empty, no `TeeInstructionsSent` carries the
  payload either, so a conditional log would leave the configuration unrecoverable and no later
  push able to supply it. In the dispatching case the payload is therefore logged twice; the
  overlap costs 8 gas per byte (~385k for a 48 KB payload) and is accepted.

### Push (permissionless, pusher pays)

`pushEndpoints(feedId, teeIds[], groups[]) payable` /
`pushAdmins(feedId, teeIds[], roles[]) payable` are open to anyone from the moment of publication.
Each re-encodes the supplied values into the `Endpoints` / `Admins` payload with the version it
holds in storage, checks the hash, and dispatches one `SET_ENDPOINTS` / `SET_ADMINS` instruction
carrying it to the machines the caller named, forwarding the entire `msg.value` as the fee with
`claimBackAddress = msg.sender` — the same funding model as `requestFeedUpdate`. Before dispatch it
writes `expectedEndpointsVersion` / `expectedAdminsVersion` per target and emits `EndpointsSet` /
`AdminsSet`.

`groups` / `roles` are the values of the feed's latest publication, read from the
`endpoints.groups` / `admins.roles` field of its `EndpointsPublished` / `AdminsPublished` event; the
re-encoded payload must hash to `latestEndpointsHash(feedId)` / `latestAdminsHash(feedId)`
(`WrongConfigPayload`) — see
[Storage model](#storage-model-hash-on-chain-payload-in-the-log) for why the caller carries them and
what the check does and does not guarantee.

Measured cost, 3 active machines, PUBLIC endpoints with ~70-character URLs, execution gas plus the
payload's intrinsic calldata (16 / 4 gas per byte) and the 21,000 base:

| groups × endpoints | payload bytes | publication | push |
|---|---|---|---|
| 1 × 3 | 1,376 | ~238k | ~121k |
| 5 × 4 | 7,904 | ~465k | |
| 25 × 3 | 30,464 | ~1.32M | |
| 25 × 4 | 39,264 | ~1.63M | |
| 25 × 5 | 48,064 | **~1.95M** (7.0% of a 28M block) | **~1.21M** (4.3%) |

It exists for the machines a publication could not reach: registered afterwards, out of
`PRODUCTION` at the time, or in an extension that was emergency paused then. It is also the
**retry** path — re-pushing a version a machine already holds is allowed and idempotent (it
rewrites the same version), so an instruction the enclave never received is fixable in the next
block. There is no cooldown: the instruction fee is the spam bound, exactly as it already is for
the permissionless, un-rate-limited `requestFeedUpdate`.

The list is dispatched **as given**, and a bad id **reverts the whole call** rather than being
dropped from it: the caller names and pays for the machines it wants delivered to, so a silently
shortened list would deliver less than was paid for. The push applies exactly the validation
`requestFeedUpdate` applies to its own target list:

1. non-empty (`NoTeeIds`);
2. no `address(0)` (`ZeroTeeId`);
3. no duplicates (`DuplicateTeeId`);
4. on this extension (`TeeIdNotInExtension`, checked on the first id — the diamond requires all
   targets of one dispatch to share an extension, and registering a sender on a foreign extension
   needs no consent from the sender, so the target extension is pinned here rather than left to
   the diamond).

The order is load-bearing: every **local** rule (1-3) runs before the manager is consulted at all,
so a caller's own malformed argument is reported as such. With the extension lookup in front, a zero
or unregistered *first* element surfaced the registry's `TeeNotFound()` instead of the declared
`ZeroTeeId()`. An id that is no machine at all still reverts with `TeeNotFound()` — only the
registry can answer that question.

`PRODUCTION` status is deliberately **not** pre-checked: the diamond rejects a non-`PRODUCTION`
target with its own `TeeMachineNotAvailable`
([`Instructions`](../../../contracts/tee/library/Instructions.sol)), the revert bubbles and rolls
the version record back with it, which tells the caller why their target was refused. There is no
version filter either — a machine already at the latest version is accepted, which is what makes
the retry path work; `get*PushTargets` is where that question is asked instead.

Beyond the validation a push reverts when the feed has no published configuration of that kind
(`NoConfigPublished`), when the re-encoded values do not match the stored hash
(`WrongConfigPayload` — altered or superseded content), and when the diamond refuses
the dispatch: while the extension is emergency paused every push reverts `EmergencyPauseActive`
**atomically**, leaving no version record behind.

Versions may skip numbers (a machine can jump v1 → v3): only the newest published payload is ever
dispatched.

### Keeper ergonomics

`getEndpointsPushTargets(feedId)` / `getAdminsPushTargets(feedId)` return the machines that still
*need* a push — the extension's `getActiveTeeMachines(extensionId)` set minus the machines already
at the latest version (empty if nothing is published). That is the keeper's way to assemble a
clean `teeIds` list before calling the push, which now reverts on anything it cannot deliver to.
The `groups` / `roles` argument comes from the feed's latest publication event; a keeper therefore
follows `EndpointsPublished` / `AdminsPublished` as well as the straggler views.

These two views are **not a complete convergence mechanism**, and a keeper must cover two gaps from
elsewhere:

- **They compare dispatched versions, and nothing here observes a machine's local state.** A machine
  paused and unpaused under the **same id** with no publication in between keeps its recorded
  version, so it is omitted from the list even though its enclave may have lost the configuration
  entirely; the same holds for a restart, a re-provisioning, or an instruction that was dispatched
  but never applied. Keepers must also consume restart / lost-state / failed-delivery signals and
  push to those machines **explicitly**, which always works: the push applies no version filter and
  re-pushing a version a machine already holds is idempotent. Discovering such a case automatically
  would need a machine lifecycle generation or an acknowledgement signal, which this contract does
  not keep — the per-machine record is what was *dispatched*, nothing more.
- **They are not emergency-pause aware**, unlike `get*PublicationFee`. While the extension is paused
  they keep reporting who is behind, even though every resulting push reverts
  `EmergencyPauseActive`, so a caller acting on them must check `isExtensionEmergencyPaused`
  separately. The asymmetry is deliberate: the fee views' output is **actionable** — it is the value
  to attach, and during a pause it would be the wrong value — whereas "who is behind" stays true
  while paused, and blinding a diagnostic exactly when a problem is being diagnosed is worse than
  making its caller check one more thing.
There is no push fee preview: since the list is dispatched as given, the diamond's own
`calculateFeeByTeeIds(TEE_ORACLE_OP_TYPE, command, teeIds)` prices the call exactly, with no
sender-side view in between. Sending less reverts inside the diamond; sending more is forwarded to
the reward manager and is not refunded, so a keeper should read the fee in the same block it pays.

`getEndpointsPublicationFee()` / `getAdminsPublicationFee()` are the governance executor's
equivalent: the machines a publication would dispatch to — the extension's whole active set — and
the fee they cost. They are kept as views of their own, rather than left to the executor to
assemble, because a short fee reverts a governance execution. They are deliberately not
`get*PushTargets` — a fresh publication is new to *every* machine of the extension, including the
ones currently at the previous latest version, which that view filters out. A zero fee with an
empty machine list is the signal that the publication will skip its dispatch and must be executed
with no value attached — an active emergency pause reads exactly the same way, since these views
mirror the publication rather than the raw active set. Read them in the block the execution lands
in: a stale quote that is too low reverts (`FeeTooLow`) and a stale quote that is too high
overpays, since neither the sender nor the diamond refunds a surplus — see
[The fee, and what a surplus costs](#the-fee-and-what-a-surplus-costs).

## Feed updates

1. **Request** — anyone calls `requestFeedUpdate(feedId, teeIds[]) payable`. Every targeted
   machine must be at the feed's **latest** published generation for both kinds —
   `isTeeIdConfigured(feedId, teeId)` is `expectedEndpointsVersion == endpointsVersion &&
   expectedAdminsVersion == adminsVersion` with both feed-level versions non-zero, else
   `TeeIdNotConfigured`. That is a hard revert because the store gates submissions on the
   feed-level hash: an observation from a lagging machine would be rejected, so it must not be
   paid for. The feed's own two versions are read **once**, before the loop over the targets —
   including the both-kinds-published check, so an unpublished feed fails without touching a
   per-machine record — and each target is then compared against those two values. Known
   residual: the version record says what was *dispatched*, so a machine whose instruction never
   reached its enclave still reads as current and can waste one request fee before a re-push. The
   instruction message is the ABI-encoded `FeedUpdateRequest{feedId}` and the fee is `msg.value`
   (`claimBackAddress = msg.sender`). The target list is validated strictly (`NoTeeIds`,
   `ZeroTeeId`, `DuplicateTeeId`, `TeeIdNotInExtension`) — the same validation a push applies,
   for the same reason: a caller names the machines it pays for.
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
   - checks the **configuration generation**: `endpointsHash` / `adminsHash` must equal the
     sender's `latestEndpointsHash(feedId)` / `latestAdminsHash(feedId)` (`StaleEndpoints` /
     `StaleAdmins`, `NoEndpointsPublished` / `NoAdminsPublished`) — the machine proves it runs the
     feed's **latest published** configuration. The check is deliberately feed-level and not per
     machine, so a publication is an immediate invalidation of every machine still running the
     previous generation. The rollout gap that opens is bounded — a feed publishes at most hourly,
     and a publication auto-dispatches to the live active set — and it buys the property a
     per-machine record cannot give: a superseded configuration stops being accepted at once,
     rather than machine by machine as instructions land;
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
- `sender.isTeeIdConfigured(feedId, teeId)` — whether both kinds' latest versions were dispatched
  to the pair (dispatch, not proof — proof-of-running shows when the machine's updates pass the
  store's generation check).
- `sender.getEndpointsPushTargets(feedId)` / `getAdminsPushTargets(feedId)` — the machines that
  still need a push, ready to pass straight to the push (priced by the diamond's
  `calculateFeeByTeeIds`); not pause-aware and blind to a machine that lost local state under an
  unchanged id, so see [Keeper ergonomics](#keeper-ergonomics) before polling them as the only
  convergence signal. `getEndpointsPublicationFee` / `getAdminsPublicationFee` price the next
  publication, and must be read in the block the execution lands in — see
  [The fee, and what a surplus costs](#the-fee-and-what-a-surplus-costs). The live configuration payloads are not readable from state — they exist only in
  the `EndpointsPublished` / `AdminsPublished` logs (see
  [Storage model](#storage-model-hash-on-chain-payload-in-the-log));
  `getFeedConfig(feedId)` and `getMachineVersions(feedId, teeId)` return the packed publication and
  dispatch bookkeeping in one call each, with `latestEndpointsHash` / `latestAdminsHash`,
  `endpointsVersion` / `adminsVersion`, `endpointsPublishedAt` / `adminsPublishedAt` and
  `expectedEndpointsVersion` / `expectedAdminsVersion` as the per-field getters.
- Candidate machines come from the diamond's `getActiveTeeMachines(extensionId)`; indexers can
  also follow the `EndpointsPublished` / `AdminsPublished` (publication) and `EndpointsSet` /
  `AdminsSet` (per-machine dispatch) events alongside `FeedUpdateRequested` / `FeedUpdated`.

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
| `setExtensionContracts(extensionId, 0, sender)`, `addTeeVersion`, `addAllowedTeeMachineOwners` | extension owner (direct) |
| `setOperationFees` `TEE_ORACLE` rows | Flare governance (timelocked; the default fee applies until then) |
| `FtsoV2.addCustomFeeds([stores])` | Flare governance (timelocked) |
| `setEndpoints` / `setAdmins` per feed | Flare governance (timelocked; the executor attaches the instruction fee from `get*PublicationFee`, read in the block the execution lands in — too little reverts in the diamond (`FeeTooLow`) and is retryable, a surplus is forwarded into that epoch's rewards and is not refunded; zero value if and only if the dispatch will be skipped. Governance also signs the next consecutive `version` and cancels a superseded pending call rather than leaving it queued, and names the non-zero `claimBackAddress`, normally the wallet funding the execution) |
| `pushEndpoints` / `pushAdmins` per feed | anyone (pays the instruction fee for the accepted machines, and supplies the configuration values from the publication log) |

**TEE governance (`setNewTeeGovernance`) is not part of this extension's flow.** Machine
registration accepts a zero `governanceHash`
([`MachineManagerFacet`](../../contracts/tee/facets/MachineManagerFacet.sol)), and nothing on the
oracle's trust path reads it: a feed update is accepted on PRODUCTION status plus the TEE signature
and the configuration commitments. The signer set exists to sign machine path lists, which
[`WalletBackupManagerFacet`](../../contracts/tee/facets/WalletBackupManagerFacet.sol) requires for
machine-to-machine wallet key restore — an operation this extension has no keys for. If a
governance snapshot is ever wanted as an off-chain verifier anchor, it must be registered *before*
the machines register, since registration binds against the latest hash.

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
