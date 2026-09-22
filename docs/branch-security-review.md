# Branch security review

## Snapshot and conclusion

Reviewed commit: `ef8ffd1e98685287cc9ee33589b6e15489a13a66` on
`relay-owner-timelock`.
Comparison: `origin/main` at
`b69873e1e1a0785e2450d811f35c7927a625716b`.

Primary targets are Relay, RelayProxy, FtsoV2, their dependencies, and the
contracts/interfaces changed on the branch. The
[scope inventory](security-review-scope.md) lists 216 Solidity paths
(215 present, one deleted; 23,823 added and 592 removed lines).
The [Relay review](relay-security-review.md) is the detailed source of Relay
findings and formal-assurance limitations.

No permissionless Relay quorum bypass, root overwrite, standard-token fee theft,
or unguarded upgrade was confirmed. No direct permissionless fund-theft path
was confirmed in the other reviewed components. This is not an absence-of-bugs
proof or a production approval: Relay's formal package is not release-qualified
for this commit, and the TEE availability path has a confirmed Medium
positive-proof/state-drift issue.

The highest-impact TEE concern is a trust-boundary decision: availability uses
one monitor, and the verifier accepts any eligible production system TEE without
binding it to the issued request's assignment. If every production system TEE
is intentionally trusted to make system-wide punitive statements, that is the
trust model; if isolation is intended, request/assignment enforcement must
change. Relay policy-uniqueness and start-bound concerns similarly require
malformed trusted admission; an unprivileged admission path was not established.

## Method, evidence and limits

Parallel source reviews traced authorization, signature/quorum semantics,
domains and freshness, policy and machine lifecycle transitions, value flow,
callbacks, proxy/diamond upgrades, storage and interface compatibility. Relevant
unchanged producers and inherited bases were inspected, not just changed lines.
Existing unit tests and checked-in formal artifacts were cross-checked against
the source. The inventory distinguishes primary targets, supporting components,
interfaces and test mocks; it is not a claim that each changed path received
an independent formal proof.

Governance, Relay setters/quorums, system TEEs, Safe owners/modules, deployment
operators, external tokens and off-chain attesters are separate trust domains.
Conditions below must not be silently replaced with “any caller.” Hardware
attestation, deployed dependency identities, actual signer behavior and
production configuration remain environmental assumptions.

### Local regression evidence

These existing suites were run against the reviewed source; no attack
reproductions or deployed-system tests were run.

| Suite group                                                             | Passed | Failed / skipped |
| ----------------------------------------------------------------------- | -----: | ---------------: |
| Relay implementation suites                                             |    104 |            0 / 0 |
| Relay owner-timelock and upgrade suites                                 |     49 |            0 / 0 |
| FtsoV2, conversion, custom feeds and NodePossessionVerifier             |    134 |            0 / 0 |
| Remaining governance, FDC2 and TEE payment suites in the commands below |    334 |            0 / 0 |
| Total distinct existing tests                                           |    621 |            0 / 0 |

The Relay implementation group includes two fuzz tests with 256 runs each.
Toolchain: Forge `1.6.0-nightly`,
commit `5e88010a83d1b87b8f4d13058e42a2949d3e9dc0`, Solc `0.8.35`.

```sh
forge test --match-path 'test-forge/unit/protocol/implementation/Relay*.t.sol' -vv
forge test --match-path 'test-forge/unit/{protocol/implementation/{FtsoV2,NodePossessionVerifier},customFeeds/implementation/{SFlrCustomFeed,StXrpCustomFeed}}.t.sol' --summary
forge test --match-path 'test-forge/unit/{tee/implementation/TeePayments*,governance/*,fdc2/implementation/*}.t.sol' --summary
```

These passing tests do not establish the absence of the issues below. In
particular, payment unit tests mock their configuration-proof verifier and
selected TEE dependencies; they do not establish actual proof freshness or
request binding through the complete production stack. The local runs are not
a substitute for the complete CI or formal bundle.

## Issue register

“Hardening,” “integration,” and “trust boundary” entries are not counted as
confirmed permissionless exploits. Severity is conditioned on the stated actor
and source path, not just the maximum imaginable impact.

| ID        | Classification                      | Current-state concern                                                          |
| --------- | ----------------------------------- | ------------------------------------------------------------------------------ |
| BR-SEC-01 | High-impact trust boundary          | Availability statements are not bound to issued-request monitor assignment     |
| BR-SEC-02 | Relay policy hardening              | Distinct policy slots need not contain distinct signer identities              |
| BR-SEC-03 | Relay policy hardening              | Policy retirement depends on an unbounded admitted next start                  |
| BR-SEC-04 | Conditional Low, operations         | Expiry is keeper-enforced, leaving an operational stale-key window             |
| BR-SEC-05 | Medium                              | An authenticated positive proof can become punitive after verifier-state drift |
| BR-SEC-06 | Conditional Medium                  | Safe caller/nonce inference does not establish exact approval execution        |
| BR-SEC-07 | Low, quorum-dependent               | A terminal accepted random round breaks the live getter and progress           |
| BR-SEC-08 | Low, manual configuration           | Initial-policy and migration-read boundaries can disagree                      |
| BR-SEC-09 | Low, inherited configuration        | Fast and custom feed namespaces are not jointly enforced                       |
| BR-SEC-10 | Low, inherited configuration        | One-hop redirects can shadow feeds or become dangling                          |
| BR-SEC-11 | Informational integration           | Feed indices are recyclable and do not bind an enduring asset identity         |
| BR-SEC-12 | Low, dependency hardening           | Custom-feed conversions assume numeric and decimal bounds                      |
| BR-SEC-13 | Low, owner-gated integration        | Configured-account proofs lack freshness and request binding                   |
| BR-SEC-14 | Conditional Low                     | TEE selection ignores Relay security/freshness and request-specific entropy    |
| BR-SEC-15 | Trusted capability hardening        | Registered system senders have global instruction authority                    |
| BR-SEC-16 | Governance design / Low integration | Durable queues and value semantics differ between governance bases             |
| BR-SEC-17 | Informational                       | Signed `teeTimestamp` does not establish on-chain observation freshness        |
| BR-SEC-18 | Conditional Low                     | Raw account strings permit aliases if the source admits multiple encodings     |
| BR-SEC-19 | Conditional Low                     | Source rebinding can repeat instruction identifiers                            |
| BR-SEC-20 | Conditional Low                     | UTXO anchor uniqueness is delegated to the attester and owner                  |
| BR-SEC-21 | Informational migration             | Signed custom-feed return types preserve the existing function selector        |
| BR-SEC-22 | Informational integration           | Oracle maximum age remains the consumer's responsibility                       |
| BR-SEC-23 | Informational                       | Bare diamond ETH has no currently installed recovery path                      |

## Relay and RelayProxy

### BR-SEC-02 — slot weight is not independent signer identity

Relay checks strictly increasing indices and authenticates the signer stored
in each slot, but does not reject duplicate addresses at policy admission.
Repeated identities concentrate slot weight in fewer keys.
Evidence: `contracts/protocol/implementation/Relay.sol:459-481,1485-1575`.

The supported home producer obtains its snapshot through VoterRegistry, whose
registration and EntityManager identity rules prevent this arbitrary duplication.
Initial configuration remains trusted. Mirror signers authorize the complete
replacement policy and already have authority to select its identities.
Consequently, this is an admission-invariant hardening target, not a confirmed
quorum bypass by an unprivileged submitter.

Verify unique nonzero addresses and positive total weight at complete-policy
admission and deployment. Preserve existing ordering and normalization semantics:
requiring sorted identities or banning every individual zero weight would
require producer and wire-compatibility review.

### BR-SEC-03 — retirement depends on the admitted next start

Cross-epoch finalization with policy R checks the stored start for R+1, not all
subsequent policy starts. An extreme admitted R+1 start can keep R eligible for
an extended interval even after later policies are installed.
Evidence: `Relay.sol:1161-1203,1273-1400`.

Home production derives a time-based start
(`FlareSystemsManager.sol:1168-1175`); mirror rotation authenticates the full
replacement. A malformed start must first enter through trusted configuration
or admission. This can create latent exposure if retained keys are compromised
later, but malicious policy-authorizing quorums already control replacement
membership. Verify start bounds and monotonicity, and decide a protocol-compatible
overlap policy without breaking legitimate delayed finalization.

### BR-SEC-07 — terminal random state

The live getter widens only after adding one to a uint32 round. At the terminal
accepted round it reverts, and the monotonic pointer has no later representable
round.
Evidence: `Relay.sol:1711-1738,1933-1941`.

Acceptance still needs sufficient signatures on that abnormal round; a submitter
cannot convert ordinary valid signatures into it. Widen before addition and
define terminal/future-round admission. Widening alone does not restore
progress after the terminal state.

A separate informational edge is that a first secure round zero is stored
historically but leaves the live security bit false. Use an explicit
initialization indicator or enforce deployment assumptions excluding round zero.

### BR-SEC-08 — initial policy and migration boundary

With nonzero oldRelay, local finalization follows the start revealed in the
opaque initial policy, while delegated reads follow the separately supplied
initialization boundary. A mismatch can hide a local root or leave a cutover gap.
Evidence: `Relay.sol:329-357,1788-1817,1900-1919,1955-1959`.

The supported home deployment derives both from the same system-manager value
and validates the migrated policy hash:
`deployment/scripts/relay/DeployRelayHome.s.sol:156-193,222-259`.
This therefore requires manual/inconsistent configuration or a failed trusted
deployment premise. Validate full-policy/boundary equality and independently
establish the provenance and upgrade authority of every historical source.

The live random state is not seeded or delegated at cutover; it returns zero
with an honest insecure flag until local finalization. Require secure/fresh
consumer gating and a cutover readiness check.

### Additional Relay boundaries

The detailed [Relay review](relay-security-review.md) covers zero-total policies,
initial wire-width and multiplier feasibility, exact-transfer fee tokens,
source-domain separation, transient custom thresholds and consumer freshness.
In particular, the epoch returned by custom-signature verification identifies
the selected eligible policy, not the time the signatures were produced.

RelayProxy initializes atomically through the ERC1967Proxy constructor, Relay's
implementation locks direct initialization, and upgrades retain UUPS context
and owner-timelock checks. No unguarded upgrade or current storage collision was
found. Before first deployment, non-append-only layout changes do not inherently
prevent future upgrades. Once deployed, that exact sequential and namespaced
layout becomes the compatibility baseline.

## TEE and FDC2

### BR-SEC-01 — request assignment is not authenticated

Availability requests explicitly ask for one monitor
(`contracts/tee/library/Verification.sol:231-238`).
The verifier accepts eligible production system-TEE signatures but does not bind
the recovered identity to a stored issued request and assigned monitor, or
consume an issued request upon use.
Evidence: `Verification.sol:64-143`;
`contracts/fdc2/implementation/Fdc2Verification.sol:111-145,188-230`.

This is not a numeric threshold bypass: the configured availability design is
one-of-one. It makes each eligible system TEE a potential authority over peer
availability. The direct route requires extension 0 not emergency-paused and
a live, time-valid target challenge; production targets do not add registration
cosigners. A compromised production TEE therefore has system-wide availability
impact if its authenticated statements are false. Treat that as Conditional
High only if per-machine isolation, rather than global trust in each system TEE,
is a required invariant.

Bind request identity, target, challenge, deadline, assigned monitor identities
and required count. Caller-selected test-monitor results must be non-punitive
if arbitrary test selection is permitted. A multi-monitor or FSP quorum for
punitive outcomes is an additional trust-policy improvement, not an existing
threshold that the code secretly skips.

### BR-SEC-04 — expiry needs an operational transaction

An expired availability end time permits a keeper to pause a machine but does
not automatically remove PRODUCTION status. FDC2 signing and selection use that
status.
Evidence: `Verification.sol:32-47,149-163`;
`MachineManagerFacet.sol:106-130,297-326`;
`Fdc2Verification.sol:207-230`.

The FCC specification explicitly describes keeper-enforced expiry. This is an
operational stale-key window, not a bypass of a documented hard expiry.
Specify and monitor the keeper SLA; if immediate expiry is required, add
read-path expiry checks together with stateful active-set maintenance.

### BR-SEC-05 — positive evidence is reinterpreted using current state

`pauseWithProof` accepts a non-OK status or a false result from current-state
response validation as negative evidence. Validation consults submission-time
reward-epoch and verifier configuration.
Evidence: `MachineManagerFacet.sol:146-156`;
`Verification.sol:332-395`.

An honest positive proof can remain authenticated and challenge-valid across an
epoch boundary while its reported policy is no longer accepted by current-state
validation. The positive result can then trigger suspension. Configuration drift
can create the same class of mismatch.

Separate authenticity, context validity and negative status. Stale or
context-inapplicable positive evidence should be rejected, not converted into
punitive evidence. Snapshot the relevant request context and test epoch and
configuration changes with honest positive responses.

### BR-SEC-06 — Safe identity is not proof of exact transaction execution

Path-list approval records derive an execution identity from a Safe caller and
its current nonce. Enabled module calls can act as the Safe without ordinary
transaction-nonce semantics.
Evidence: `contracts/tee/facets/MachinePathManagerFacet.sol:142-270`.

Consequently, the “cancelled signatures cannot confirm” guarantee is conditional
on module trust as well as Safe-owner signatures. The affected scenario requires
a compromised enabled module, an available cancelled signature set and current
owner/threshold/screening checks still passing; it is not permissionless access.
Use an execution artifact or approval-specific state authenticated by the
intended Safe transaction path. Bound or index accumulated approvals as an
additional liveness safeguard.

### BR-SEC-14 — selection discards security and freshness

Selection discards Relay's secure flag and timestamp and derives the subset from
the random value and active-set shape, without request-specific entropy.
Challenge construction also discards the secure flag.
Evidence: `MachineManagerFacet.sol:297-326`;
`Verification.sol:185-191`.

This makes selections repeatable under unchanged state and unsafe to assume
unpredictable when Relay is insecure or stale. No concrete selection-based
authorization bypass was established. Enforce a secure/fresh policy, define
fallback behavior and bind selection entropy to a unique request; a public salt
alone does not make predictable randomness unpredictable.

### BR-SEC-15 — system senders are globally trusted

Registered system senders bypass extension-scoped sender restrictions; system
operations also bypass ordinary production-status checks.
Evidence: `contracts/tee/facets/InstructionsFacet.sol:21-59`;
`contracts/tee/library/Instructions.sol:87-101,175-196`.

Current applications construct their operations; no arbitrary-user instruction
injection was found. The capability is nevertheless broad if a registered
application is compromised. Record that trust explicitly or scope registration
by extension, operation, command and destination status. Include sender origin
in auditability requirements.

### BR-SEC-17 — signed timestamp semantics

`teeTimestamp` is signed but is not read by response validation.
Evidence: `contracts/userInterfaces/fdc2/ITeeAvailabilityCheck.sol:59-66`;
`Verification.sol:332-395`.

It therefore cannot be treated as enforced observation freshness. Document it
as diagnostic or define and enforce its meaning. A signer-reported timestamp
alone cannot establish honesty of the observation.

## FtsoV2 and custom feeds

No unauthorized feed mutation, standard fee theft, unguarded upgrade or
profitable reentrancy path was confirmed. The twelve read APIs preserve the
pre-call balance and burn only excess value belonging to the current call.
Several configuration concerns below are inherited from main, not new defects
introduced by the signed-return change.

### BR-SEC-09 — namespaces require coherent configuration

Categories `0x20..0x3f` route as custom feeds, but the fast-feed registry can
admit an ID in that category. Governance could make an otherwise registered
fast feed inaccessible through the intended route.
Evidence: `contracts/protocol/implementation/FtsoV2.sol` custom-feed routing
and `contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol`
feed admission.

Enforce category ownership across registries and validate cross-registry
uniqueness. This requires governance misconfiguration; no public write path
was identified.

### BR-SEC-10 — redirects resolve exactly one hop

Redirect configuration validates the immediate target, but does not maintain
canonical terminal targets or inbound references. Active IDs can be shadowed,
and targets can themselves be aliases or later removed.
Evidence: `FtsoV2.sol:534-569,823-833`.

Cycles do not cause recursive execution or infinite loops: resolution is
one-hop. They can nevertheless produce unexpected identity mapping. Validate
intended mappings during governance changes and reject unsupported alias
composition or dangling targets.

### BR-SEC-11 — indices are ephemeral

Fast-feed removal frees an index for reuse.
Evidence: `FastUpdatesConfiguration.sol:40-60,84-97`.
The interface documents recycling; index reads are not enduring asset
identifiers. Prefer feed IDs or pair cached indices with expected identity
and registry-generation checks.

### BR-SEC-12 — numeric, decimal and dependency assumptions

Custom feeds explicitly cast unsigned dependency values to signed values.
A value above int256's maximum would become negative; ordinary configured
price/rate magnitudes are far below this bound.
Evidence: `contracts/customFeeds/implementation/SFlrCustomFeed.sol:50-67`;
`contracts/customFeeds/implementation/StXrpCustomFeed.sol:47-64`.

The conversion-token addresses are immutable constructor arguments, not
registry-resolved addresses. FastUpdater/configuration/fee references are
address-updated dependencies. Correctness also depends on share/asset decimal
relations, conversion-rate behavior and coherent feed/fee configuration.
The returned timestamp authenticates the reference-price time, not conversion
rate freshness.

Use checked casts, validate decimal normalization and dependency identities,
and test the actual configured tokens. A fee-forwarding caller must not be
incorrectly free-fetch allowlisted. The reviewed deployment does not establish
such a FtsoV2/custom-feed allowlist error; this is a configuration check, not a
demonstrated deployment vulnerability.

### BR-SEC-21 — signed-return migration

The custom-feed return changes from uint256 to int256 without changing the
function selector. Positive values remain bit-compatible. A legacy unsigned
consumer would misinterpret a negative result; the current unsigned FtsoV2
wrappers reject negatives.
Evidence: `contracts/customFeeds/interface/IICustomFeed.sol:10-21`;
`FtsoV2.sol:744-755,856-866`.

This migration requirement is documented. Bundled feeds are intended to return
nonnegative values, and no affected deployed mixed-version consumer was
established. Inventory direct consumers before introducing negative feeds.

### BR-SEC-22 — consumers enforce maximum age

FtsoV2 returns timestamps rather than imposing a universal freshness limit.
Proof inclusion likewise does not establish recency.
`ChainlinkAdapter.sol:91-95` demonstrates a current maximum-age check.
Every consumer must define its own age limit and unavailable-data behavior.

## TEE payments

Payment mutation remains current-wallet-owner or configured-authorization
gated as applicable. No permissionless payment theft or concrete current-source
address-validator false acceptance was confirmed.

### BR-SEC-13 — configuration proofs lack request and freshness binding

Configured-account verification checks signatures, wallet keys and response
shape without enforcing `header.timestamp` or recorded-request identity.
Evidence: `contracts/tee/implementation/TeePaymentsConfigVerifier.sol:142-197,239-266`.

This affects both direct TEE and FSP proof routes under their respective live
signer/cosigner eligibility conditions. In the FSP route, a current/previous
selected policy does not prove signature age: Relay's custom digest does not
bind that selected policy epoch. Retained identities with sufficient weight can
remain eligible under later policies.
Evidence: `contracts/fdc2/library/Fdc2ProofVerification.sol:31-45`;
`Relay.sol:1212-1225,1579-1591`.

Owner authorization prevents public registration takeover, but does not make
stale nonce or UTXO-anchor state current. Uniqueness and limited resynchronization
can make configuration mistakes persistent. Under a compromised-attester model,
false configuration statements can also deny registration of a claimed account;
signer trust is essential.

Bind purpose, request, account, destination, expiry and relevant epoch into
authenticated application data and enforce them. Define authenticated
resynchronization/anchor-retirement procedures. Do not change Relay's digest
without coordinating FDC2/FSP/cosigner preimage compatibility.

### BR-SEC-18 — account identity is textual

Uniqueness hashes the source ID and raw account string.
Evidence: `contracts/tee/implementation/TeePaymentsBase.sol:186-209,333-354`.
If a source accepts multiple spellings for one native account, aliases can
create independent on-chain identities. This review does not establish such
an alias for every supported attester. Require canonical source-specific
identity in the authenticated response.

### BR-SEC-19 — identifiers do not bind deployment generation

Payment instruction identifiers omit contract/chain and source-generation
identity. Fresh state after a source rebind can repeat an identifier when the
other inputs repeat.
Evidence: `TeePaymentsBase.sol:366-385`.
Impact depends on off-chain components treating identifiers as globally unique.
Bind deployment/generation context or explicitly scope off-chain deduplication.

### BR-SEC-20 — anchor uniqueness is an external assumption

UTXO anchor counts are bounded, but duplicate transaction/output pairs are not
rejected on-chain. The attester and current owner must both admit the duplicate
configuration for it to reach storage. This is owner/configuration liveness
hardening, not public anchor injection. Enforce uniqueness within the bounded
list and define recovery for unusable anchors.

## Governance, upgrades and deployment

### BR-SEC-16 — durable queues and distinct value semantics

Do not conflate the three governance implementations:

| Surface                         | Queue and authority behavior                                                     | Execution value                           |
| ------------------------------- | -------------------------------------------------------------------------------- | ----------------------------------------- |
| Relay / OwnableWithTimelock     | Exact calldata; no generation or expiry; transfer preserves queued authorization | Nonpayable executor, zero-value self-call |
| New FlareGovernance descendants | Calldata queue; no generation or expiry                                          | Executor can choose value                 |
| FtsoV2 / legacy GovernedBase    | Inherited governance queue and context rules                                     | Nonpayable executor, zero-value self-call |

Relay deliberately documents durable authorizations. Unwanted calls should be
inventoried from events and cancelled by the outgoing owner before transfer;
the incoming owner cannot cancel until it takes ownership.
Evidence: `contracts/utils/implementation/OwnableWithTimelock.sol:23-28,63-80,110-132`.

New FlareGovernance's executor-selected value can affect a nonempty upgrade
initializer if that initializer uses msg.value. An incompatible empty-data
upgrade reverts atomically, rather than silently applying.
Evidence: `contracts/governance/lib/FlareGovernance.sol:84-103,214-228`.
Relay and FtsoV2 do not have that executor-value behavior. Their delayed upgrade
initializers must work with zero value and the actual self-call authorization
context. A nested guarded initializer must not assume the already-consumed
execution privilege can be reused.

Choose generation invalidation, expiry, value commitments or two-step ownership
only as explicit governance-policy changes. Under durable queues, require an
event-based handover inventory and cancellation procedure.

### Direct system-extension administration

Extension 0 owner checks resolve directly to the governance address, so certain
system-extension changes are not delayed by the diamond's governance queue.
Evidence: `contracts/tee/library/ExtensionManager.sol:77-98`.
This is documented privileged administration, not a discovered caller bypass.
If the delay is intended to mitigate governance-key compromise, identify
risk-increasing direct powers and route those through the intended delay.

### BR-SEC-23 — bare diamond ETH

The diamond accepts bare ETH but has no currently installed unaccounted-balance
recovery facet.
Evidence: `contracts/diamond/implementation/Diamond.sol:19-55`.
Governance could install recovery code. This does not alter forwarding of
current instruction fees. Do not fund it directly; decide whether a narrow
timelocked recovery method is required.

Deployment must validate initial policy contents, domain, mode, timing, fee
token/collector, owner/delay, setter, migration source and implementation code.
CREATE3 addresses bind deployer and salt, not an immutable initializer identity.
Treat deployer and every historical source's upgrade authority as explicit
trust dependencies.

## Additional integration and specification requirements

- Custody thresholds count distinct key identities, not independent machines.
  Co-location is explicitly permitted. Document concentration risk and include
  recovery administrators and approved migration paths in the custody model;
  no owner-only key replacement/extraction bypass was found under honest
  TEE and administrator assumptions.
- An immutable payment-authorization address does not prove independent
  authorization governance. An “owner cannot drain” guarantee requires
  independently governed authorization and recovery administrators.
- Key-type removal prevents new projects; existing-project behavior is
  grandfathered by `Extensions.md:140-142`. Align contradictory wording in
  KeyManagement rather than claiming a new enforcement bypass.
- Global cosigners default to an empty list and zero threshold until configured.
  This does not bypass the primary signature. Deployment must explicitly
  assert the intended bootstrap and production cosigner policy.
- `Verification.md:79-86` describes in-diamond VRF verification not present in
  current VrfFacet; the current verifier is standalone. VrfFacet requests use
  a key ID and should reject incompatible project signing algorithms.
- Configuration-attestation requests are permissionless and self-funded;
  registration is owner-gated. `Payments.md:70` should distinguish them.
- `initialSigningPolicyId` is checked in availability response validation, not
  as a provenance restriction in FDC2 signature verification. Documentation
  must not claim on-chain enforcement of an off-chain signing rule.
- Ownership transfer preserves configured delegates, operators, backup managers
  and authorizations. Transferees must inventory those roles; ownership change
  is not an automatic reset of project/extension policy.
- Global Signature type moves preserve tuple ABI selectors but can break
  Solidity source references to nested types. Raised pragma floors and
  owner/fee/domain/UUPS ABI changes require exact-snapshot tooling.

## Formal-verification and CI status

Formal verification targets Relay, not the branch's TEE, FDC2, FtsoV2, diamond
or payment subsystem. The current proof inventory, compiler and toolchain are
defined by `test-forge/fv/verification-manifest.json`.

The package includes the current delayed ownership-transfer lifecycle and
guarded selectors, canonical security-byte handling, finalized-source
delegation, and custom-call selector protection. Compiler-generated optimized
Yul and a visibility-only regenerated Certora tree bind those layers to current
source. Successful-path witnesses remain mandatory beside conditional
preservation and rejection properties.

Normalized results in `verification-reports/` are generated and gitignored.
A passing local file or pipeline badge alone does not establish release status.
The aggregate bundle must bind all mandatory constituents to the same clean
commit and manifest with `status = pass` and `release_eligible = true`.
Working-tree runs are development evidence, even when every constituent passes.
Use [CURRENT-STATUS](relay-verification/CURRENT-STATUS.md) and the
[reproduction procedure](relay-verification/11-reproducibility.md) to obtain
and interpret those results.

The [Relay proof matrix](relay-security-review.md#formal-assurance-and-remaining-work)
explains bounded Halmos coverage, conditional Lean refinement, optimistic
Certora abstractions and namespace/layout limits. Local Certora compilation
does not execute the cloud solver. Cloud evidence is supplemental and requires
complete, current normalized jobs without disqualifying solver or sanity
outcomes. Neither source synchronization nor passing conditional proofs closes
the runtime and integration findings in this review.

## Release priorities

1. Run the Relay models, generated sources, Yul/provenance and
   anti-vacuity gates until the exact clean commit has a passing,
   release-eligible aggregate bundle.
2. Repair live-random timestamp arithmetic and define terminal/future-round and
   round-zero behavior. Verify deployment and home-producer policy invariants
   and migration readiness.
3. Fix BR-SEC-05; decide whether one system TEE is a global punitive authority
   and enforce request/monitor assignment consistent with that decision.
4. Establish consumer freshness/replay requirements, especially configured-account
   proof expiry and request binding. State the Safe-module, system-sender,
   cosigner, custody and keeper trust model explicitly.
5. Resolve the documented configuration and specification requirements with
   deployment assertions and integration tests using actual verifier/dependency
   implementations. Passing mocked unit tests are insufficient for these claims.
6. Obtain independent review of the TEE/FDC2/payment and off-chain composition.
   Relay-only formal proofs do not cover that system.
