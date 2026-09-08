# Relay security review

## Scope and safety conclusion

Target: `contracts/protocol/implementation/Relay.sol` at commit
`ef8ffd1e98685287cc9ee33589b6e15489a13a66`, including RelayProxy,
OwnableWithTimelock, the home signing-policy producer, migration construction,
and the FDC2 custom-signature consumer. The comparison is `origin/main` at
`b69873e1e1a0785e2450d811f35c7927a625716b`.

No permissionless quorum bypass, unauthorized root replacement, standard-token
fee theft, or unguarded UUPS upgrade was confirmed. The current implementation
has a coherent authorization design under its stated trust assumptions.
Production approval still requires current verification evidence and explicit
acceptance or hardening of the boundaries below. A proof claim requires current
normalized reports, not the presence of verification files in the working tree.

In particular, a malicious quorum choosing a malicious replacement policy is
already exercising its policy authority. Missing duplicate-voter and policy-start
validation are valuable hardening targets, but an unauthorized admission path
has not been established in the supported home producer or quorum-controlled
mirror path. They are not ranked as High vulnerabilities merely by assuming
that those authorities have already failed.

Normative behavior is in [Finalization](specs/FSP/Finalization.md).
Deployment and owner operations are in [Relay governance](relay-governance.md).
The [branch review](branch-security-review.md) covers the other changed contracts,
and the [scope inventory](security-review-scope.md) lists all changed Solidity paths.

## Trust and authorization boundaries

| Actor or dependency                | Authority relied on                                                      | Boundary that Relay enforces                                                                 |
| ---------------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Anyone submitting relay calldata   | Transport only                                                           | Must present a stored policy and sufficient valid indexed signatures                         |
| Home signing-policy setter         | Supplies complete policies                                               | Only the configured setter can call; setter mode cannot be cleared                           |
| Mirror policy quorum               | Approves the next complete policy                                        | Mode-1 rotation authenticates the replacement under the admitted current policy              |
| Relay owner                        | Fee configuration, setter rotation, ownership and implementation changes | Guarded calls use the configured delay; cancellation is immediate                            |
| Timelock executor                  | Executes a specific queued authorization                                 | Permissionless execution must match the exact calldata hash and maturity                     |
| Initial deployer                   | Chooses policy hash, mode, source, timings and migration metadata        | Proxy initialization is atomic; opaque policy contents are not fully validated               |
| oldRelay and its upgrade authority | Answers delegated historical reads                                       | Immediate-source compatibility checks do not establish implementation provenance             |
| ERC-20 fee token and fee recipient | Transfer/refund behavior and availability                                | Root inclusion precedes fee calls; exact-transfer token semantics remain an assumption       |
| Custom-signature consumer          | Defines the meaning and lifetime of a digest                             | Relay checks policy eligibility and weight; consumer replay and freshness rules are external |

A nonzero delay protects the guarded owner surfaces only. It does not delay normal
home-policy creation or quorum finalization. A zero delay intentionally permits
immediate owner changes. An authorized implementation replacement can change
future semantics; current-code proofs cannot constrain arbitrary replacement code.

## Current issue register

Severity describes demonstrated reachability under the stated conditions.
“Hardening” and “integration” entries are not counted as permissionless exploits.

| ID         | Classification                        | Boundary                                                                                    |
| ---------- | ------------------------------------- | ------------------------------------------------------------------------------------------- |
| RLY-SEC-01 | Policy hardening                      | Slot uniqueness is enforced; signer-address uniqueness is delegated to policy admission     |
| RLY-SEC-02 | Low, quorum-dependent availability    | An accepted terminal random round makes the live getter unreadable and cannot be superseded |
| RLY-SEC-03 | Low, manual-configuration consistency | Opaque initial-policy start and nonzero oldRelay read boundary can disagree                 |
| RLY-SEC-04 | Low, migration integration            | The live random value is not carried across a migration                                     |
| RLY-SEC-05 | Policy hardening                      | A zero-total policy is structurally admissible but cannot reach strict acceptance           |
| RLY-SEC-06 | Policy hardening                      | Retirement depends on the next policy's unbounded start                                     |
| RLY-SEC-07 | Documented governance behavior        | Existing queued calls survive ownership and compatible implementation changes               |
| RLY-SEC-08 | Informational edge correctness        | A first secure round zero is not reflected in the live security bit                         |
| RLY-SEC-09 | Token integration assumption          | Fee transfers assume an exact-transfer ERC-20                                               |
| RLY-SEC-10 | Consumer freshness requirement        | The returned custom-signature policy epoch does not authenticate signature age              |
| RLY-SEC-11 | Deployment hardening                  | Opaque initial-policy and parameter bounds need composition checks                          |

## RLY-SEC-01 — policy slots and signer identities

The signature loop requires strictly increasing voter indices, canonical ECDSA
parameters, and recovery of the address in each selected slot. It does not
require the addresses in different slots to be distinct. If trusted admission
accepts repeated addresses, the associated weights are all attributable to the
same key. The security invariant is therefore “enough admitted slot weight,”
not “enough independently controlled identities.”
Evidence: `Relay.sol:459-481,1485-1575`.

The supported home producer is material to this assessment:
`FlareSystemsManager.sol:908-921` obtains its voter snapshot from
`VoterRegistry.sol:196-236`; voter registration and EntityManager signing-address
registration enforce identity restrictions
(`VoterRegistry.sol:532-540,622`,
`EntityManager.sol:231-243`). Initial policy configuration remains trusted.
Mirror rotation already requires approval of the entire replacement policy.

No arbitrary caller can choose the stored policy hash or inject an additional
voter slot through the reviewed honest producer. Assigning High severity without
an untrusted admission route would overstate the finding.

Hardening: validate nonzero unique signer addresses and positive total weight
at every complete-policy admission point; document and verify the producer-to-
Relay invariant. A sorted-address requirement would change the current policy
ordering and wire compatibility, so do not introduce it without coordinating the
producer and signers. Individual zero weights may result from normalization;
rejecting every zero weight also requires a producer compatibility decision.

## RLY-SEC-02 — terminal live-random state

Relay accepts sufficiently authenticated future rounds. If such a round reaches
the maximum uint32 value, the monotonic live pointer has no later representable
round, and `getRandomNumber()` adds one as uint32 before widening. That getter
then reverts. Evidence: `Relay.sol:1124-1203,1711-1738,1933-1941`.

This is a real arithmetic/availability boundary, but entering it requires
signatures over the abnormal future round. A submitter cannot transform valid
ordinary-round signatures into that message. The classification is Low,
quorum-dependent hardening, with high potential operational impact if entered.

Hardening: widen before addition, explicitly define terminal-round behavior,
and bound accepted future rounds to a protocol-compatible time horizon.
Widening alone repairs readability but does not restore progress after the
terminal round. The verification obligation is: every accepted live state is
readable, and ordinary protocol operation cannot consume the terminal state.

## RLY-SEC-03 — initial policy and migration boundary

With `oldRelay != address(0)`, initialization stores a separate read-delegation
boundary beside the opaque initial-policy hash. Local finalization uses the
start revealed in the policy; historical reads use the initialization boundary.
If these disagree, a locally stored root can fall on the delegated side, or an
interval may have no usable local initial policy.
Evidence: `Relay.sol:329-357,1788-1817,1900-1919,1955-1959`.

The supported home deployment constructs both from the same system-manager
value and checks the migrated policy hash:
`deployment/scripts/relay/DeployRelayHome.s.sol:156-193,222-259`.
The inconsistency therefore requires a different/manual configuration path or
failure of the trusted deployment assumptions. With no oldRelay, the separate
boundary does not control delegated reads.

Hardening: derive the boundary from a complete initial policy on-chain, or
validate equality at the first reveal. Retain deployment checks for the
source's policy hash, timings and mode, and additionally establish its
implementation provenance. Treat every transitive oldRelay and its upgrade
authority as part of the integrity boundary.

## RLY-SEC-04 — live randomness at migration

The live getter always uses local random state, while historical getters can
delegate. Immediately after cutover it returns zero with `isSecure = false`
until a local random is finalized. Consumers that require security may stop;
consumers that ignore the bit may use predictable input.
Evidence: `Relay.sol:1925-1941,1947-1959`.

The insecure flag is honest; this is not a forged secure random value. The
system manager itself checks security/freshness
(`FlareSystemsManager.sol:278-280`).
Require consumer checks and a cutover procedure that establishes a local secure
value before dependants switch, or design a verified atomic seed/delegation rule.

## RLY-SEC-05 — unusable zero-total policy

A nonempty zero-total policy can satisfy structural threshold-band checks but
cannot satisfy strict accumulated weight greater than threshold. It requires
trusted initialization, setter admission, or a quorum-approved replacement.
The normalized home snapshot cannot have all-zero weights under its bounded
voter count and positive input total.
Evidence: `Relay.sol:459-481`, `VoterRegistry.sol:204-236`.

Enforce a positive total as defense in depth and keep the upstream positive-input
premise explicit. This is configuration liveness hardening.

## RLY-SEC-06 — policy retirement

For a policy from epoch R, the cross-epoch gate consults the stored start of
R+1. It does not consult every later policy. An extreme admitted next start can
leave the older policy eligible for a very long interval, even when more policies
exist. Its ordinary threshold can apply once it is no longer the last initialized
policy. Evidence: `Relay.sol:1161-1203,1273-1400`.

The home producer derives a start from time and enforces a forward delay
(`FlareSystemsManager.sol:1168-1175`). Mirror signers authorize the full
replacement, and a malicious quorum could already retain its own identities in
successive policies. The extreme boundary itself is not an escalation beyond
that authority. It becomes a latent risk under accidental malformed admission
followed by later compromise of retired keys.

Hardening: verify producer start bounds and monotonicity at admission and consider
a bounded overlap rule. Any current/previous-only rule must preserve legitimate
delayed finalization and policy availability behavior; it is a protocol change,
not a safe incidental edit.

## RLY-SEC-07 — queued authorizations and handover

Queue entries bind calldata and maturity, not the owner generation or an expiry.
The documented semantics preserve an existing authorization across ownership
transfer. A compatible implementation can also retain the same queue.
Evidence: `OwnableWithTimelock.sol:23-28,63-80,110-132`.

The outgoing owner should inventory events and cancel unwanted entries before
transfer; the incoming owner cannot cancel until ownership changes. The queue
has no on-chain enumeration. Ownership transfer is itself delayed when the
delay is nonzero, and an outgoing owner can cancel it. A nonzero but incorrect
recipient has no recovery or acceptance handshake.

Relay's executor is nonpayable and performs a zero-value self-call; executor-
chosen value is not a Relay issue. With a nonzero delay, upgrade initializers
must work with zero value. The execution flag is consumed before the guarded
body. Current concrete tests cover migration reinitializers and rejection of
attempted second guarded calls from an upgrade.

Consider generation invalidation, finite execution windows, or a two-step
ownership acceptance only if those semantics are desired. Keep the event-based
handover procedure mandatory while durable authorizations remain the design.

## RLY-SEC-08 — round-zero presence

The live pointer advances only for a strictly greater round. A first secure
round zero can be recorded historically while the live security bit stays false.
No insecure value is falsely marked secure.
Evidence: `Relay.sol:1711-1738`.

An explicit “local random initialized” flag would separate absence from round
zero. Deployments whose first valid round is nonzero avoid this edge.

## RLY-SEC-09 — fee token assumptions

Local verification requires a finalized root and valid inclusion before charging.
Native fee and refund arithmetic conserve the current call's value. Token-mode
verification rejects native value and uses SafeERC20 to request payment from the
actual caller. No balance-delta check establishes exact receipt.
Evidence: `Relay.sol:1788-1872`.

An owner-selected fee-on-transfer, rebasing, or callback-capable token has behavior
outside the exact-transfer model. A collector or refund recipient can also
reject its callback and make the call revert. These trusted dependencies can
affect availability; no standard-token accounting theft was found.

Configure reviewed exact-transfer tokens, include their upgrade authority in
the trust model, and test each supported token's real implementation. Token
and fee-table replacement is atomic, preventing mixed denominations during an
ordinary configuration change.

## RLY-SEC-10 — custom signatures authenticate eligibility, not age

The custom-message digest binds the source domain and fixed protocol message
containing the supplied message hash. It does not bind the selected policy
epoch or policy hash. Relay returns the epoch of the policy against which the
signatures were accepted.
Evidence: `Relay.sol:1085-1089,1124-1126,1212-1225,1579-1591`.

If the same signing identities still have sufficient weight under a later
policy, their signatures can remain valid under that policy. This is expected
for a generic digest-verification API. The returned epoch cannot establish
when the signatures were produced.

The concrete consumer boundary is FDC2:
`Fdc2ProofVerification.sol:31-45` accepts current/previous selected policy IDs,
while `TeePaymentsConfigVerifier.sol:144-196,239-267` does not enforce the
signed header timestamp. Its configuration proofs can therefore remain usable
through policy rotations if the wallet keys and required cosigners remain
eligible. Owner authorization still gates registration; no public takeover is
established. Availability proofs have additional live-challenge checks.

Consumers must bind purpose, destination, request identity, expiry, and any
required policy epoch into the signed application data, then enforce those
values. Describe the return value as selected-policy identity. Changing Relay's
digest itself would affect the intentional FDC2/FSP/cosigner preimage alignment
and requires coordinated compatibility review.

## RLY-SEC-11 — deployment composition bounds

Opaque initial-policy admission does not revalidate every voter-count, address,
weight, epoch and start invariant. The initial epoch input is wider than the
policy's 24-bit wire epoch. The future-threshold multiplier has an operational
upper-bound requirement: too large a multiplier can prevent later-round
acceptance using the last initialized older policy, even when every voter signs.
Installing the appropriate newer policy restores its ordinary-threshold path.
These are trusted configuration inputs, not caller-controlled arithmetic overflows.

The packed count/weight sizes keep offset and weight products far below uint256
wrap. The separate concern is usability and gas when an opaque initial policy
does not respect the operational voter limit.

Validate the complete deployment manifest: wire-width epoch, bounded count,
positive weight total, threshold feasibility, source domain, time parameters,
migration boundary, owner/delay, fee mode, and setter-mode consistency. Preserve
the full signed manifest with the compiled implementation identity.

## Mechanisms checked with no confirmed bypass

| Mechanism                | Source-level conclusion                                                                             | Remaining assumption                                              |
| ------------------------ | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Parser and memory layout | Fixed-width counts determine offsets; reviewed scratch regions preserve needed state                | This manual trace is not a proof for every calldata value         |
| Domain separation        | Policy and protocol-message encodings have distinct lengths and source binding                      | Keccak collision resistance; consumers supply application domains |
| ECDSA recovery           | v, low s, call success, return length, nonzero recovery and expected address are checked            | ECDSA security and valid policy admission                         |
| Write-once finalization  | Existing roots/policies are gated; a later signature failure rolls back earlier writes              | No arbitrary authorized upgrade changing these rules              |
| Custom wrapper           | relay selector and return discriminator/hash are checked; transient override is scoped and cleared  | Future changes preserve the no-callback setup-to-use interval     |
| Random leaf binding      | Round, value and canonical boolean are tied to the signed root                                      | Merkle/keccak assumptions and authenticated input freshness       |
| Fee/refund callbacks     | Inclusion precedes external fee operations; no mutable per-user fee credit was found to corrupt     | Dependency behavior and callback availability                     |
| RelayProxy/UUPS          | Constructor initialization is atomic; implementation initialization and upgrade context are guarded | Selected implementation and future upgrade code are trusted       |
| Timelock                 | Exact mature calldata is replayed; execution privilege is consumed before body callbacks            | Queue survival and zero-delay mode are intentional                |

## Formal assurance and remaining work

Existing Relay implementation suites passed 104 tests, including two fuzz tests
with 256 runs each. Owner-timelock and upgrade suites passed another 49 tests:
153 relevant tests passed, with none failed or skipped. These are concrete
regression results, not proofs that every calldata or policy is safe. Exact commands and broader
test coverage are recorded in the [branch review](branch-security-review.md).

The evidence rule is defined by
[CURRENT-STATUS](relay-verification/CURRENT-STATUS.md), the
[claims ledger](relay-verification/10-claims-ledger-trust-and-residual.md), and
[AUDIT-TRAIL](relay-verification/AUDIT-TRAIL.md). Normalized reports in
`verification-reports/` are generated, gitignored evidence, not committed proof
inputs. Their manifest, source and toolchain bindings determine applicability.
An uncommitted working-tree run remains development evidence even when all
individual properties pass.

The current package includes delayed ownership-transfer lifecycle and queue
preservation checks; canonical security-byte rejection plus both legal-byte
success witnesses; finalized-source delegation and refund checks; and bounded
custom-wrapper selector rejection with genuine relay success controls elsewhere
in the same fixture. Certora's verification-only source tree is regenerated
from production with only the declared visibility substitutions. The optimized
Yul snapshot is compiler-generated, and the sequential storage baseline is
checked independently. These input-consistency measures do not replace a
complete run of the manifest-bound gates.

| Proof area                     | What the present package can establish when regenerated and passing | What it does not establish                                            |
| ------------------------------ | ------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Halmos signature/parser checks | Bounded bytecode fixtures and selected success/failure paths        | All calldata, all signer counts, or untrusted-policy admission safety |
| Lean signature loop            | Unbounded abstract/conditional index and weight reasoning           | Unconditional equivalence of the entire deployed Relay to the model   |
| Random/Merkle checks           | Bounded leaf/fold binding under hashing assumptions                 | Terminal progress, migration continuity, or a future-round policy     |
| Fees                           | Native arithmetic and selected native/token transitions             | Arbitrary token semantics or a complete hostile-dependency model      |
| Timelock/UUPS                  | Concrete control checks and bounded modeled transitions             | Semantics of arbitrary owner-selected replacement code                |
| Artifact/layout gates          | Compiler/settings/source/Yul identity and sequential layout drift   | Compiler correctness or complete future namespace compatibility       |
| Certora local                  | Solidity scene compilation and CVL front-end acceptance             | Cloud solver proof results                                            |

Certora configurations use finite loop settings, optimistic loop/hash
abstractions and a hashing-length bound. Generic ABI calls to `relay()` contain
no raw payload; preservation rules over those calls alone do not prove valid
relay-message execution. Successful reachability witnesses and the exact rule
scope matter. Lean refinement retains explicit crypto, setup and composition
premises and declared local semantic axioms; absence of `sorry` is not an
assumption-free full-contract proof.

The literal Lean acceptance bridge is specifically unverified: the pinned Yul
`STATICCALL` handler dispatches an ordinary account instead of the address-1
precompile and clears caller calldata on return. Relay reads its voter record
after that call. Recovery premises with preserved caller calldata are therefore
an unresolved model interface, not established executable precompile behavior.
Reachable-state composition and any recovery-seam witnesses do not close that
interface. This limits the Lean refinement claim, not the independent abstract
accounting or bounded bytecode checks. See the
[refinement scope](relay-verification/07-R4b-bytecode-refinement.md).

The sequential storage snapshot is the first-deployment baseline. It excludes
ERC-7201 and transient namespaces; current concrete namespace tests help, but
future upgrades need review of those namespaces, inherited layout, types and
semantics as well. A non-append-only change before first deployment does not
by itself break future upgradeability. Once deployed, that exact storage
baseline becomes the compatibility reference.

Certora cloud is supplemental under the current bundle policy. Cloud claims
require current, complete normalized job results with acceptable sanity outcomes.
The [branch review](branch-security-review.md) records the regression-test scope;
the generated bundle is authoritative for formal-verification status.

## Recommended hardening order

1. Obtain a passing, release-eligible bundle for the exact clean commit. Keep
   source-to-proof identity checks and successful-path witnesses mandatory
   whenever a guarded surface or parser rule changes.
2. Widen live-random timestamp arithmetic; define and enforce terminal/future
   round limits and first-random presence behavior.
3. Validate initial-policy/deployment composition and machine-check the
   home-producer uniqueness, total-weight and start-bound premises.
4. Specify migration continuity and require consumer freshness/security checks.
5. Clarify custom-signature policy identity versus signature age; enforce
   expiry/request binding in FDC2 and other consumers.
6. Decide whether durable queues, single-step ownership and exact-transfer-only
   fee tokens match the deployment threat model. Encode the accepted policy in
   deployment checks and upgrade procedures.
