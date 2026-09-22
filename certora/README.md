# Certora verification for Relay

This directory targets the current Relay architecture:

- upgradeable `Relay` implementation compiled with Solidity 0.8.35;
- per-chain `OwnableUpgradeable` owner;
- exact-calldata owner timelock in an ERC-7201 namespace, including ownership transfer;
- UUPS upgrades guarded by that same owner-timelock path; and
- atomically replaceable native/ERC-20 verification-fee configuration.

## Evidence outputs

[`verification-manifest.json`](../test-forge/fv/verification-manifest.json)
binds the exact Certora configurations and rule inventory. The local preparation
gate compiles the Solidity scenes and type-checks every declared CVL rule with:

- `certora-cli 8.16.1`;
- Java at or above the manifest's minimum version;
- `solc 0.8.35+commit.47b9dedd`;
- Cancun EVM, optimizer 200, `viaIR=true`; and
- OpenZeppelin contracts and upgradeable contracts 5.7.0.

The local result is a compilation and CVL front-end result, not a prover
verdict. `verification-reports/relay-certora-local.json` records the exact Git
commit, manifest, tool versions, source hashes, commands and rule inventory.

Cloud runs are normalized into
`verification-reports/relay-certora-cloud.json`. Cloud evidence is supplemental:
it is not a constituent of the local aggregate bundle or a release verdict. Use
the report's provenance, completeness, sanity and per-rule result fields rather
than copying job metadata into this document.

## Rule inventory

[`Relay.conf`](Relay.conf) checks scalar preservation rules directly against the
production implementation:

| Rule                                             | Claim                                                                                                        |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `sourceChainIdImmutableAfterInitialization`      | ordinary current-implementation calls cannot change the initialized source domain                            |
| `signingPolicySetterModeStable`                  | relay mode cannot gain a setter and setter mode cannot be cleared; a nonzero setter may rotate               |
| `lastInitializedMonotonic`                       | the initialized reward epoch does not regress                                                                |
| `ownerCannotBecomeZero`                          | ownership may rotate but cannot be renounced or transferred to zero                                          |
| `timelockDurationBoundPreserved`                 | an in-range delay remains at most seven days                                                                 |
| `feeCollectionAddressCannotBecomeZero`           | an established fee recipient cannot be cleared                                                               |
| `feeTokenZeroInSetterMode`                       | ordinary current-implementation calls preserve the zero fee token required in setter mode                    |
| `protocolFeeZeroInSetterMode`                    | ordinary current-implementation calls preserve a zero fee for every sampled protocol in setter mode          |
| `protocolFeeInWeiMatchesNativeFee`               | in native mode the native-wei compatibility getter equals the canonical protocol fee                         |
| `protocolFeeInWeiRejectsTokenMode`               | in token mode the native-wei compatibility getter reverts instead of exposing token units as wei             |

[`Relay-writeonce.conf`](Relay-writeonce.conf) checks raw mappings and timelock
transitions against [`RelayHarness`](harness/RelayHarness.sol):

| Rule                                                   | Claim                                                                                                                                                                            |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `policyHashWriteOnce`                                  | an initialized policy hash cannot be overwritten by an ordinary current-implementation call, under the documented reachable-state epoch link                                     |
| `merkleRootWriteOnce`                                  | a nonzero finalized root cannot be overwritten by an ordinary current-implementation call                                                                                        |
| `feeTableMappingSetLockstepPreserved`                  | the sampled mapping entry is nonzero exactly when its protocol id is in the fee enumeration, assuming that reachable-state relation before the transition                        |
| `reservedProtocolFeesRemainUnset`                      | protocol ids 0 and 1 remain absent and free across ordinary current-implementation calls                                                                                         |
| `immediateSetterModeProtocolFeeUpdateReverts`          | a clean zero-delay setter-mode call rejects every argument to the current `setProtocolFees` ABI                                                                                   |
| `immediateProtocolFeeUpdateCanApply`                   | a real zero-delay relay-mode fee-token transition has a successful execution witness                                                                                            |
| `tokenModeRejectsNativeValueBeforeExternalCall`        | token mode rejects nonzero `msg.value` before any external call                                                                                                                  |
| `tokenModeUnfinalizedVerificationDoesNotCallToken`     | a zero stored root reverts before an ERC-20 call                                                                                                                                 |
| `tokenModeInvalidEmptyProofDoesNotCallToken`           | a nonmatching leaf with an empty proof reverts before an ERC-20 call                                                                                                              |
| `tokenModeValidEmptyProofCallsConfiguredToken`         | a charged, valid empty-proof path calls the configured token with zero native value and has a successful witness                                                                 |
| `oldRelayDelegationForwardsNoValueAndRefundsOnSuccess` | a pre-boundary empty-proof call observes source finalization separately from delegated verification, sends no native value to the configured old Relay, and on success attempts the full caller refund; a successful witness prevents vacuity         |
| `onlyOwnerCanEnterGuardedSurface`                      | with the namespaced execution flag clear, a non-owner cannot enter any allowlisted guarded mutation entry point, including ownership transfer                                                                   |
| `delayedOwnerCallDoesNotApply`                         | with a positive delay, a successful non-upgrade owner call, including ownership transfer, cannot apply sampled owner, Relay, or fee-table state; queue creation is covered by the manifest-bound `RelayOwnerTimelockFV` fixture within its stated bounds |
| `successfulExecutionConsumesQueue`                     | from an initialized nonzero-owner state, a ready, successful execution of an allowlisted non-upgrade guarded call deletes its exact entry and clears the namespaced execution flag; an applied duration-change witness prevents vacuity |
| `successfulNonUpgradeExecutionPreservesRelayInvariants` | a ready, successful allowlisted non-upgrade execution preserves scalar, write-once, fee-table, reserved-id, setter-mode, and unrelated sampled queue invariants; only ownership transfer may change the owner                                           |
| `successfulDurationUpdateIsBounded`                    | a successful duration update respects the seven-day cap; a clean-boundary owner witness proves a zero-delay update is actually applied rather than queued or reverted            |
| `ownershipRenounceAlwaysReverts`                       | Relay cannot renounce ownership                                                                                                                                                  |
| `ownershipTransferPreservesQueuedCall`                 | a harness helper encodes a canonical transfer once for queue identity and the real executor: positive-delay execution installs the exact nonzero recipient, consumes its own queue entry, clears the execution flag, and preserves another pending entry; an actual owner-change witness prevents vacuity |

[`Relay-threshold.conf`](Relay-threshold.conf) isolates the wrapper's fail-fast
opcode checks and the threshold arithmetic lemma from the established
mapping/timelock job:

| Rule                                               | Claim                                                                                                                                                                                                                                                              |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `thresholdAtOrAbove100PercentRevertsBeforeEffects` | with zero call value and `thresholdBIPS >= 10000`, the real wrapper reverts before any Relay `SSTORE`, `TSTORE`, or `CALL`; persistent opcode ghosts keep attempted-effect observations visible through the expected revert                                        |
| `thresholdFloorCrossProductArithmeticLemma`        | for production-bounded nonnegative weights and `BIPS < 10000`, strict comparison against `floor(totalWeight * BIPS / 10000)` is mathematically equivalent to the exact cross-product inequality; this is not an implementation-link proof of Relay's Yul threshold |

## Cloud-proof interpretation and bounds

Every configuration enables `rule_sanity=basic`. This checks that the end of a
rule remains reachable after its assertions are removed; it does not by itself
show that a conditional `reverted || property` reached the successful branch.
Success-conditional timelock, fee-token, and old-Relay refund rules therefore
include explicit `satisfy` witnesses. `ownershipRenounceAlwaysReverts`,
setter-mode fee rejection, native-value rejection, unfinalized verification,
invalid-proof verification, and the threshold fail-fast rule
intentionally have no successful path: rejection is their property, so a generic
non-revert witness is inapplicable. Sanity exclusions and SAT witnesses are
recorded in the normalized cloud report and must be read per rule and method
rather than hidden behind the CLI's aggregate banner.

The parametric scalar and write-once rules invoke generic direct methods with
`@withrevert`. Reverting calls remain in the method domain and must preserve the
sampled state after rollback. This includes ABI-dispatched `relay()`, whose
generic zero-argument call supplies only the selector and lacks the required
trailing protocol payload, and the deliberately disabled `renounceOwnership()`.
Raw relay payloads are modeled by the manifest-bound Halmos and Lean layers
within their stated bounds; the direct `ownershipRenounceAlwaysReverts` rule also
covers the disabled ownership path.

Each configuration sets `loop_iter=3` and `optimistic_loop=true`. Certora may
assume away executions that continue past three loop iterations, so a cloud
`SUCCESS` is conditional on this bounded loop model and is not an unrestricted
all-input result for Relay's longer loops. In particular, fee-table replacement
claims cover only executions that finish within this loop bound.

Each configuration also sets `optimistic_hashing=true` with
`hashing_length_bound=512`. The Prover therefore assumes that every unbounded
byte chunk it hashes is at most 512 bytes. In `Relay-writeonce.conf`, this
includes the timelock's `encodedCall` and the raw `msg.data` hashed when an owner
call is queued. The current threshold fail-fast rule rejects before parsing or
hashing the relay message, and the arithmetic lemma is pure, so this hashing
assumption is not load-bearing for either current threshold claim. Other claims
remain limited to hashed inputs at or below 512 bytes; inputs longer than the
bound are not proved safe.

The token-fee opcode rules require `oldRelay == 0`, matching the reachable token
mode, and use the harness's raw root getter to isolate current-contract proof
ordering. Persistent `CALL` ghosts remain visible across a revert. They establish
that nonzero native value, an unfinalized root, and a concrete invalid empty proof
are rejected before any external call. For a concrete valid empty proof with a
nonzero fee and a non-exempt caller, they establish a call to the configured token
with zero native value and include a successful witness. These rules do not decode
the ERC-20 call arguments or establish recipient balance deltas. Correct
`transferFrom(sender, feeCollectionAddress, fee)` behavior and exact-transfer
balance semantics remain assumptions about the configured standard token; ECF
also excludes reentrant effects on Relay state.

The old-Relay value-flow rule covers the pre-boundary branch with an empty Merkle
proof and nonzero attached value. The current implementation first queries
`isFinalized()` and requires a true result; only then may it invoke the delegated
`verify()`. A fixture or external summary must permit that finalization query or
it cannot witness successful delegation. Separate persistent `STATICCALL` and
`CALL` observations distinguish the source-finalization query from delegated
proof verification. The rule requires the modeled sender's native balance
to fund that value, which is the reachable-call condition for entering a payable
function. Persistent target-specific `CALL` observations prove that any attempted
delegated `verify` call carries zero value even when the operation later reverts,
and that a successful operation attempts to return the full attached value to the
caller. The rule does not validate the old Relay's code or proof decision; the
configured contract's provenance and return value remain the migration trust
boundary. The setter-mode scalar invariant, initialization checks, and
delayed-execution preservation jointly cover the current Relay implementation's
zero-fee behavior.

The threshold fail-fast rule invokes the real
`verifyCustomSignatureWithThreshold` method, with zero call value to exclude the
unrelated nonpayable guard. Persistent `ALL_SSTORE`, `ALL_TSTORE`, and `CALL`
ghosts are essential: unlike ordinary ghosts, their observations are not erased
when the expected Solidity revert rolls back. The rule therefore establishes that
every `uint16` threshold at or above 10000 is rejected before either kind of store
or the raw-calldata self-call. There is no dispatcher, `HAVOC`, or `NONDET`
summary in this spec.

Certora does **not** claim the below-100% successful path. Solc's via-IR lowering
does not expose a sufficient relation between `_relayMessage`'s CVL bytes and the
low-level `CALL` selector for a pessimistic dispatcher to eliminate its
fail-closed fallback. An optimistic dispatcher would merely assume the key
match. Successful override forwarding,
`TSTORE -> self-call -> TLOAD`, zero cleanup, caught-revert rollback, address
scope, and protocol-mode isolation therefore remain the responsibility of the
bounded Halmos checks and the stated Lean operation/state refinement seam, with
their documented bounds and assumptions. Lean keeps this dependency explicit as
the `hsetupThreshold` hypothesis; it is not discharged by either threshold
Certora rule.

The separate Certora arithmetic lemma proves only the floor/cross-product
identity: CVL cannot directly expose the Yul-local threshold variable, so this
layer does not by itself link that identity to the production
`div(mul(totalWeight, overrideBIPS), 10000)` instruction. At `BIPS == 0` the
identity remains mathematical only: production treats zero as the no-override
sentinel and uses the policy threshold.

Each scene compiles through `viaIR=true`. A “failed to locate internal function” diagnostic
does not by itself omit that code: without an internal summary, the TAC remains
inlined and attributed to the enclosing external method. It does limit internal
function attribution, decomposition, and the applicability of an internal
summary. Any such diagnostics and sanity failures are explicit limitations on
the affected cloud claims. The direct implementation scene cannot establish
full proxy-context reachability for UUPS; proxy upgrade behavior remains a
separate proxy-aware verification and test obligation.

## Trusted-upgrade boundary

The parametric scalar and mapping-preservation rules exclude:

1. `initialize(...)`, which establishes proxy state;
2. `upgradeToAndCall(...)`, which can deliberately replace every implementation
   invariant; and
3. `executeTimelockedCall(...)`, because arbitrary queued calldata can dispatch
   an upgrade.

This exclusion is necessary for sound specification. An owner-authorized UUPS
upgrade can install arbitrary code, so an invariant over the modeled implementation
cannot quantify over arbitrary replacement semantics. The CVL still checks the
owner entry guard and current-implementation timelock queue behavior. The
`successfulExecutionConsumesQueue` and
`successfulNonUpgradeExecutionPreservesRelayInvariants` rules use a positive,
exact-selector allowlist for the modeled non-upgrade owner methods, including
`transferOwnership(address)`; this excludes every
`upgradeToAndCall(address,bytes)` call, whose selector is `0x4f1ef286`. The
four-byte length guard is load-bearing because out-of-bounds CVL array reads are
otherwise unconstrained. The rule also requires a clean external boundary,
zero-value execution, and a nonzero queue timestamp whose ETA has passed. Its
outer caller remains unconstrained because execution is permissionless after the
ETA.

Inside `RelayHarness.executeTimelockedCall(bytes)`, the unresolved self-call uses
the default pessimistic `DISPATCH` mode and explicitly lists the same allowlisted
methods. When the prover cannot resolve the raw-calldata call, the fallback
`HAVOC_ECF` permits a storage-preserving no-op. The general rules therefore
establish preservation and queue-consumption claims under this over-approximation;
they do not establish exact recipient binding for arbitrary raw calldata. The
queue-consumption rule assumes an initialized, nonzero pre-owner. Its canonical
duration-change witness, and the separate general-invariant rule's equivalent
witness, must observe an actual in-range duration change.

`ownershipTransferPreservesQueuedCall` uses the verification-only
`canonicalOwnershipTransferCall(address)` helper. It constructs
`abi.encodeCall(this.transferOwnership, (recipient))` in Solidity without writing
or emulating timelock state. CVL binds that returned byte array once and uses the
same value for queue identity and the inherited production executor. The rule
checks the exact recipient, execution flag, consumed entry, unrelated entry,
and zero-recipient rollback. The executor's outer caller remains unconstrained
and the rule requires zero native value. This canonical typed-input property is
distinct from a raw-calldata decoding/composition proof. Its success witness must
observe a nonzero owner change.

The duration and ownership witnesses are kept in separate rules because CVL's
default `satisfy` semantics require earlier executed `satisfy` conditions to hold
on the same path. Thus neither a queued no-op nor the fallback summary can be
the sole reachability evidence. See the
[CVL statement semantics](https://docs.certora.com/en/latest/docs/cvl/statements.html#satisfy-statements).

Upgrade arguments are deliberately not parsed or constrained: every call to the
UUPS entry point is outside the execution rule, including malformed calls that
would revert.

The delayed-execution claims therefore mean: for a successful non-upgrade
self-call executed by the currently modeled Relay implementation, the exact queue
entry is consumed, the namespaced authorization flag is cleared, and the sampled
current-implementation invariants remain true. They do **not** establish that a
queued upgrade succeeds through a proxy, that arbitrary replacement or migration
code preserves the timelock namespace, that a new implementation is
storage-compatible, or that migration calldata is safe.

Ownership transfer follows the same queue-and-execute model: positive delay
leaves the owner unchanged while queuing the exact transfer calldata; zero delay
allows an immediate transfer. The outgoing owner can cancel a pending transfer.
Successful transfer does not invalidate unrelated queued operations, so handover
must review and cancel unwanted calls. The execution flag is the persistent
`OwnableWithTimelock.State.executing` field in its ERC-7201 namespace, not the
transient threshold-override slot used by Relay's custom-signature wrapper.

Unresolved old-Relay, precompile and external-call boundaries use an ECF summary.
The rules therefore assume an external callback does not cause an owner-controlled
upgrade during the modeled operation. Cryptographic correctness of `ecrecover`
and `keccak256` is outside this storage-invariant layer.

## Faithful private-state access

Two mappings written from Relay's assembly routine and the fee-protocol
enumeration set are private.
[`munge.sh`](munge.sh) regenerates `certora/munged/` from production source and
changes exactly these three visibility keywords from `private` to `internal`:

- `toSigningPolicyHashPrivate`; and
- `merkleRootsPrivate`; and
- `feeProtocolIdsPrivate`.

All required dependencies are copied byte-for-byte. The script deletes the
generated tree first so unlisted files cannot survive a regeneration, then fails
if the Relay diff is anything other than those three lines.
The harness adds read-only raw getters; it does not alter production storage.

## Reproduce the local preparation gate

From the repository root, with the pinned tools available:

```bash
bash certora/munge.sh

certoraRun certora/Relay.conf \
  --compilation_steps_only \
  --solc /path/to/solc-0.8.35

certoraRun certora/Relay-threshold.conf \
  --compilation_steps_only \
  --solc /path/to/solc-0.8.35

certoraRun certora/Relay-writeonce.conf \
  --compilation_steps_only \
  --solc /path/to/solc-0.8.35

python3 test-forge/fv/verify_certora_local.py \
  --solc /path/to/solc-0.8.35 \
  --report-output verification-reports/relay-certora-local.json
```

The Python wrapper additionally enforces the manifest's exact CLI and solc versions,
plus a minimum Java major version of 21. CI separately pins the exact Temurin build
and archive digest. Before invoking Certora it fail-closes on config drift: the exact config
set and its complete proof-semantic field inventory — source/target, packages,
compiler, loop/hash optimism and bounds, sanity/wait modes, prover arguments,
and ordered rule inventory — must match the manifest;
the rule declarations discovered in each CVL file must match too. Config/spec and
command-output hashes are recorded in the normalized report.

## Run the cloud prover

Load a Certora account key from a restricted secret file, without placing its
literal value in the command or committing it. The example below works in Bash
and Zsh when `/private/tmp/certora.key` already contains only the key:

```bash
export CERTORAKEY="$(< /private/tmp/certora.key)"
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-threshold.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-writeonce.conf --solc /path/to/solc-0.8.35
unset CERTORAKEY
```

Keep the key file owner-readable only, never print the environment, and rotate
credentials exposed in chat or logs.

Normalize saved logs together with the exact CLI submission archives:

```bash
python3 test-forge/fv/verify_certora_cloud.py \
  --run certora/Relay.conf=/path/to/scalar.log=/path/to/scalar-submission.zip \
  --run certora/Relay-threshold.conf=/path/to/threshold.log=/path/to/threshold-submission.zip \
  --run certora/Relay-writeonce.conf=/path/to/writeonce.log=/path/to/writeonce-submission.zip \
  --report verification-reports/relay-certora-cloud.json
```

Do not convert a local `compilation_steps_only` pass into a proof claim, or read
the CLI's aggregate `FAIL` label on a SAT `satisfy` subnode as a property
counterexample. The normalizer binds job identity, archive inputs, config/spec
semantics, every authoritative result block, and the detailed SAT witness table.
Imported cloud evidence remains development-only. Record the commit, manifest,
compiler settings, rule inventory, report URLs, per-method outcomes, and every
sanity exclusion in the normalized report.
