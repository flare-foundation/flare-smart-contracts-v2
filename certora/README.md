# Certora verification for Relay

This directory targets the current `relay-owner-timelock` architecture:

- upgradeable `Relay` implementation compiled with Solidity 0.8.35;
- per-chain `OwnableUpgradeable` owner;
- exact-calldata owner timelock in an ERC-7201 namespace; and
- UUPS upgrades guarded by that same owner-timelock path.

The retired cross-chain Safe/GSS model is not part of the current source graph.
Its specifications and configurations were removed rather than left as apparently
executable evidence. Git history remains the record of that abandoned design.

## Current evidence status

> **Current normalized evidence.** At HEAD
> `d5af7136c03d6bab83307b0f4bd49101b8792e40`, manifest SHA-256
> `7ae2208f96a520f477b528ee808909f87e9402247bacab00e04052fa02ec2cb1`
> binds 3 Certora configs and an exact 15-rule inventory. The normalized local
> report SHA-256
> `9d3ce0394ebcfadb2b415021a077a0a29761814a11a510d90d23364f97185067`
> is **PASS** (3/3 configs, 15 rules, 0 local violations). This is a
> compilation/CVL front-end result, not a prover verdict. The aggregate local
> evidence bundle SHA-256
> `be386d63acdd336b99ab84c64cb0f32ba9c3bafbba02b17164ebd176b7e4f64a`
> is also **PASS**, but both artifacts are development-only solely because they
> were generated from a dirty worktree. A clean committed rerun is required for
> release-eligible evidence.

The current three-config local run used:

- `certora-cli 8.16.1`;
- Java 26 (the manifest requires at least Java 21);
- `solc 0.8.35+commit.47b9dedd`;
- Cancun EVM, optimizer 200, `viaIR=true`; and
- OpenZeppelin contracts and upgradeable contracts 5.7.0.

The normalized supplemental cloud report SHA-256
`93d09d86d1acbf3b3ffdb0f6d9f8145b094722b9b7de94e131ef8e8e97ca4821`
binds the same HEAD and manifest and is **PARTIAL**. Its threshold configuration
is **PASS**; the scalar and write-once configurations are **PARTIAL** because of
sanity exclusions. Across all three jobs, the normalized semantic totals are
308 `SUCCESS`, 2 `SATISFIED`, and 24 `SANITY_FAIL`, with no semantic assertion
counterexample, `UNKNOWN`, or `TIMEOUT`. Imported cloud results are supplemental
evidence, not a constituent of the local aggregate bundle or a release verdict.

Current cloud jobs:

- [scalar invariants](https://prover.certora.com/output/3798318/96136f4b1ce349889963c722745f6d8a)
- [threshold fail-fast and arithmetic](https://prover.certora.com/output/3798318/a133698c16d54e7cb4a518a3251dd73a)
- [write-once and timelock transitions](https://prover.certora.com/output/3798318/5f29c9d404134b7aa3578484455bf424)

## Rule inventory

[`Relay.conf`](Relay.conf) checks scalar preservation rules directly against the
production implementation:

| Rule                                        | Claim                                                                                          |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `sourceChainIdImmutableAfterInitialization` | ordinary current-implementation calls cannot change the initialized source domain              |
| `signingPolicySetterModeStable`             | relay mode cannot gain a setter and setter mode cannot be cleared; a nonzero setter may rotate |
| `lastInitializedMonotonic`                  | the initialized reward epoch does not regress                                                  |
| `ownerCannotBecomeZero`                     | ownership may rotate but cannot be renounced or transferred to zero                            |
| `timelockDurationBoundPreserved`            | an in-range delay remains at most seven days                                                   |
| `feeCollectionAddressCannotBecomeZero`      | an established fee recipient cannot be cleared                                                 |

[`Relay-writeonce.conf`](Relay-writeonce.conf) checks raw mappings and timelock
transitions against [`RelayHarness`](harness/RelayHarness.sol):

| Rule                                | Claim                                                                                                                                                                            |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `policyHashWriteOnce`               | an initialized policy hash cannot be overwritten by an ordinary current-implementation call, under the documented reachable-state epoch link                                     |
| `merkleRootWriteOnce`               | a nonzero finalized root cannot be overwritten by an ordinary current-implementation call                                                                                        |
| `onlyOwnerCanEnterGuardedSurface`   | with the transient execution flag clear, a non-owner cannot enter any of the six guarded mutation entry points                                                                   |
| `delayedOwnerCallDoesNotApply`      | with a positive delay, a successful non-upgrade owner call cannot apply a sampled Relay-state mutation; queue creation itself is covered by Halmos/concrete tests                |
| `successfulExecutionConsumesQueue`  | a ready, successful execution of one of the five non-upgrade guarded calls deletes its exact entry and clears the transient flag; a real applied setter witness prevents vacuity |
| `successfulDurationUpdateIsBounded` | a successful duration update respects the seven-day cap; a clean-boundary owner witness proves a zero-delay update is actually applied rather than queued or reverted            |
| `ownershipRenounceAlwaysReverts`    | Relay cannot renounce ownership                                                                                                                                                  |

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
The two success-conditional timelock rules therefore include explicit `satisfy`
witnesses. `ownershipRenounceAlwaysReverts` and the threshold fail-fast rule
intentionally have no successful path: rejection is their property, so a generic
non-revert witness is inapplicable. The current normalized cloud report records
24 sanity exclusions and two concrete SAT witnesses. These outcomes must be read
per rule and per method rather than hidden behind the CLI's aggregate banner.

All three configurations set `loop_iter=3` and `optimistic_loop=true`. Certora may
assume away executions that continue past three loop iterations, so a cloud
`SUCCESS` is conditional on this bounded loop model and is not an unrestricted
all-input result for Relay's longer loops.

All three configurations also set `optimistic_hashing=true` with
`hashing_length_bound=512`. The Prover therefore assumes that every unbounded
byte chunk it hashes is at most 512 bytes. In `Relay-writeonce.conf`, this
includes the timelock's `encodedCall` and the raw `msg.data` hashed when an owner
call is queued. The current threshold fail-fast rule rejects before parsing or
hashing the relay message, and the arithmetic lemma is pure, so this hashing
assumption is not load-bearing for either current threshold claim. Other claims
remain limited to hashed inputs at or below 512 bytes; inputs longer than the
bound are not proved safe.

The threshold fail-fast rule invokes the real
`verifyCustomSignatureWithThreshold` method, with zero call value to exclude the
unrelated nonpayable guard. Persistent `ALL_SSTORE`, `ALL_TSTORE`, and `CALL`
ghosts are essential: unlike ordinary ghosts, their observations are not erased
when the expected Solidity revert rolls back. The rule therefore establishes that
every `uint16` threshold at or above 10000 is rejected before either kind of store
or the raw-calldata self-call. There is no dispatcher, `HAVOC`, or `NONDET`
summary in this spec.

Certora does **not** currently claim the below-100% successful path. In the
superseded attempt, solc's via-IR lowering did not leave the Prover a sufficient
relation between `_relayMessage`'s CVL bytes and the low-level `CALL` selector for
a pessimistic dispatcher to eliminate its fail-closed fallback. An optimistic
dispatcher would merely assume the key match. Successful override forwarding,
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

All three scenes compile through `viaIR=true`. The current jobs preserve their
cloud call-resolution diagnostics. A “failed to locate internal function” diagnostic
does not by itself omit that code: without an internal summary, the TAC remains
inlined and attributed to the enclosing external method. It does limit internal
function attribution, decomposition, and the applicability of an internal
summary. The normalized report contains no semantic counterexample, `UNKNOWN`,
or `TIMEOUT`, but its `viaIR` resolution diagnostics and 24 sanity failures remain
limitations of the current scalar and write-once jobs. In particular, the direct
implementation scene cannot establish full proxy-context reachability for UUPS;
proxy upgrade behavior remains a separate proxy-aware verification and test
obligation.

## Trusted-upgrade boundary

The parametric scalar and mapping-preservation rules exclude:

1. `initialize(...)`, which establishes proxy state;
2. `upgradeToAndCall(...)`, which can deliberately replace every implementation
   invariant; and
3. `executeTimelockedCall(...)`, because it can dispatch the queued upgrade.

This exclusion is necessary for sound specification. An owner-authorized UUPS
upgrade can install arbitrary code, so an invariant over the old implementation
cannot quantify over arbitrary replacement semantics. The CVL still checks the
owner entry guard and current-implementation timelock queue behavior. The
`successfulExecutionConsumesQueue` uses a positive, exact-selector allowlist for
the five non-upgrade owner methods; this excludes every
`upgradeToAndCall(address,bytes)` call, whose selector is `0x4f1ef286`. The
four-byte length guard is load-bearing because out-of-bounds CVL array reads are
otherwise unconstrained. The rule also requires a clean external boundary,
zero-value execution, and a nonzero queue timestamp whose ETA has passed. Its
outer caller remains unconstrained because execution is permissionless after the
ETA.

Inside `RelayHarness.executeTimelockedCall(bytes)`, the unresolved self-call uses
the default pessimistic `DISPATCH` mode and explicitly lists the same five
methods, so a matching selector executes real current-implementation code; only
unmatched calls fall back to `HAVOC_ECF`. The explicit success witness further
requires canonical `setTimelockDuration(uint256)` calldata and an observed
in-range duration change. Thus neither a queued no-op nor the fallback summary
can be the sole reachability evidence. The current detailed SAT model
exhibited the intended queued duration call's ETA consumption, transient-flag
cleanup, and applied duration mutation.

Upgrade arguments are deliberately not parsed or constrained: every call to the
UUPS entry point is outside the execution rule, including malformed calls that
would revert.

The queue claim therefore means: for a successful non-upgrade self-call executed
by the currently modeled Relay implementation, the exact queue entry is consumed
and the transient authorization flag is cleared. It does **not** establish that a
queued upgrade succeeds through a proxy, that arbitrary replacement or migration
code preserves the timelock namespace, that a new implementation is
storage-compatible, or that migration calldata is safe.

Unresolved old-Relay, precompile and external-call boundaries use an ECF summary.
The rules therefore assume an external callback does not cause an owner-controlled
upgrade during the modeled operation. Cryptographic correctness of `ecrecover`
and `keccak256` is outside this storage-invariant layer.

## Faithful mapping access

The two mappings written from Relay's large assembly routine are private.
[`munge.sh`](munge.sh) regenerates `certora/munged/` from production source and
changes exactly these two visibility keywords from `private` to `internal`:

- `toSigningPolicyHashPrivate`; and
- `merkleRootsPrivate`.

All current owner-timelock dependencies are copied byte-for-byte. The script deletes
the generated tree first, preventing retired architecture files from surviving a
regeneration, then fails if the Relay diff is anything other than those two lines.
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

With a Certora account key:

```bash
export CERTORAKEY=<key>
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-threshold.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-writeonce.conf --solc /path/to/solc-0.8.35
```

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
sanity exclusion before updating the claims ledger.

## Historical evidence

Earlier jobs targeted predecessor source, manifests, or a non-upgradeable,
pre-owner-timelock Relay with different compiler settings. They remain useful for
explaining why the successful threshold-path dispatcher was retired, but none is
evidence for the current revision. Use only the current normalized reports and
the three current job URLs listed above for present-tense claims.
