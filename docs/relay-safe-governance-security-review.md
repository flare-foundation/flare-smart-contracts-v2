# `Relay.sol` security review — `relay-safe-governance`

**Review date:** 2026-08-10
**Branch:** `relay-safe-governance` tracking `origin/relay-safe-governance`
**Reviewed commit:** `3e046d4d1a2d8355a544d4387f84523f2464f47b`
**Primary target:** [`contracts/protocol/implementation/Relay.sol`](../contracts/protocol/implementation/Relay.sol)
**Review status:** code and focused runtime review complete; the formal-verification bundle does **not** match this commit.

## Executive verdict

No unconditional, unprivileged Critical exploit was found in the current `Relay.sol` signature parser, Merkle-root finalization, fee-forwarding, proxy initialization, or upgrade entry point.

The branch is nevertheless **not release-ready under its existing formal-verification contract**:

- a malformed signing policy can count one key at multiple voter indices and thereby violate the distinct-weight threshold property;
- target-side Safe-governance parsing deliberately accepts actions that the source `SafeInstructions` contract rejects, even though source execution is not required for target authorization;
- a sufficiently large current quorum can sign a far-future random round that permanently freezes the live random pointer;
- fresh-relay migration exposes a predictable zero/insecure current random until the first new random root, while multiple consumers ignore the quality flag;
- the initial policy hash and migration read boundary are configured independently and are not tied together on-chain; and
- every authoritative FV layer is stale or red for this refactor. Passing unit tests do not restore the missing proof-to-bytecode link.

### Finding summary

| ID | Severity | Finding | Release disposition |
|---|---|---|---|
| **H-01** | **Conditional High** | Duplicate voter addresses are counted at distinct indices | Fix before deployment; enforce policy uniqueness on every ingestion path |
| **M-01** | **Medium** | Relay accepts governance actions rejected by `SafeInstructions` | Restore one grammar, or explicitly redesign and re-document the authorization domain |
| **M-02** | **Medium, quorum-authority** | A far-future random round can permanently freeze current-random reads | Bound the future horizon and reject the terminal round |
| **M-03** | **Medium, migration** | A fresh Relay does not inherit/fallback to the old current random | Seed or fallback before registry cutover |
| **M-04** | **Medium/Low, migration** | Initial policy hash is not bound to the configured read boundary | Initialize from and validate the complete policy |
| **L-01** | **Low, deployment** | JSON protocol IDs are narrowed to `uint8` before range validation | Validate as `uint256` before casting; add schema bounds |
| **V-01** | **Release blocker** | Halmos/manifest, ABI gate, Certora, Lean and Kontrol evidence is stale | Re-baseline all layers and require a green exact bundle |

Severity qualifications matter here. H-01 needs a malformed policy to be installed. M-02 needs a quorum above the increased future threshold. M-01 needs a threshold-signed action. These are not ordinary permissionless attacks, but each expands the damage caused by an upstream mistake or compromised authority beyond the intended invariant.

## Scope and threat model

The review covered:

- `Relay.sol`, `RelayProxy.sol`, `IIRelay` and `IRelay`;
- `SafeGoverned`, `SafeGovernance` and `SafeInstructions`;
- the home/mirror Relay deployment and configuration parsers;
- Relay, Safe-governance, invariant, upgrade and deployment tests; and
- the Halmos manifest/harnesses, revert-ABI and artifact gates, Certora munging, committed Lean/Yul snapshot and Kontrol bridge.

The adversary is an arbitrary caller/relayer who may reorder or replay valid signed data but cannot forge ECDSA signatures. The Safe owner threshold and normal Flare signing-policy setter are privileged trust roots. Findings that require those authorities are explicitly marked conditional rather than presented as threshold bypasses from a healthy configuration.

## H-01 — Duplicate voter addresses are double-counted at distinct indices

**Severity:** Conditional High impact; configuration-dependent likelihood.
**Affected paths:** initial opaque policy, `setSigningPolicy`, Mode-1 policy relay, and the signature loop.

### Description and root cause

`setSigningPolicy` delegates zero-address and uniqueness checks to the trusted setter and validates only list size, total weight and threshold consistency ([`Relay.sol:425-452`](../contracts/protocol/implementation/Relay.sol#L425-L452)). Mode-1 ingestion performs the same structural/threshold checks without validating voter addresses ([`Relay.sol:1296-1367`](../contracts/protocol/implementation/Relay.sol#L1296-L1367)). The initial deployment accepts only an opaque policy hash, so it cannot validate the underlying addresses at all.

The signature loop requires indices to increase, but it does not require the addresses at those indices to differ ([`Relay.sol:1508-1522`](../contracts/protocol/implementation/Relay.sol#L1508-L1522)). It recovers a signer, compares it with the address at each selected index, and adds each entry's weight ([`Relay.sol:1564-1588`](../contracts/protocol/implementation/Relay.sol#L1564-L1588)). Therefore the same signature can be copied at two distinct indices when both entries contain the same address.

The comment at lines 1509-1514 is incorrect: increasing indices prevent reuse of one **index**, not reuse of one **key**.

### Impact

Once a malformed policy is active, one unique signer can contribute the sum of every duplicated entry. That can allow fewer distinct keys than intended to:

- finalize arbitrary protocol Merkle roots;
- supply arbitrary random roots/values;
- approve `verifyCustomSignature` messages; or
- rotate to another signing policy.

The normal current Flare setter path reduces likelihood: `VoterRegistry.createSigningPolicySnapshot` obtains the registered signing addresses, and `EntityManager` enforces uniqueness for explicitly registered signing-policy addresses. That operational invariant does not protect a bad migration policy, a future setter regression/upgrade, or a malformed policy admitted through Mode 1.

### PoC / reproduction

**Status: executed successfully in a disposable Foundry test; the probe was deleted after the run.**

Use this policy:

```text
voters    = [A, A, B]
weights   = [30, 30, 40]
threshold = 50
```

Have `A` sign the message once. Encode the same `(v,r,s)` twice with strictly increasing indices `0` and `1`. Both recovered signers match their indexed address, the index-order checks pass, and the accumulated weight becomes `60 > 50`. A key intended to carry weight 30 clears the threshold alone.

The executable probe used five entries with weights `[150,150,67,67,66]`, threshold 260 and the same key/address at indices 0 and 1. Replaying that key's signature at the two indices finalized a non-random protocol root with only one distinct signer. Foundry reported **PASS** (`gas: 90,227`).

The existing FV checks reject repeated indices such as `[0,1,1]`; they do not establish distinct recovered addresses across `[0,1]`.

### Proposed fix

1. Reject `address(0)` and duplicate voter addresses in both `setSigningPolicy` and Mode-1 policy ingestion.
2. If changing policy order is acceptable, use strictly increasing addresses as a canonical representation. Otherwise use a bounded pairwise or in-memory-set uniqueness check; `MAX_VOTERS` is 300.
3. Initialize from the complete encoded initial policy, validate it, and recompute its hash on-chain instead of accepting only an opaque hash.
4. Add the exact `[A,A,B]` regression test with one signature copied at two indices.
5. Change the formal statement from “no repeated index” to “accepted weight is the sum of distinct recovered signer identities,” with voter uniqueness either proved or enforced as an explicit checked precondition.

## M-01 — Target semantics are looser than the source Safe instruction grammar

**Severity:** Medium integrity/signing-intent risk.
**Affected paths:** all three fee-family Safe-governance actions.

### Description and root cause

The shared `SafeGovernance` library defines nonempty, at-most-256, strictly ordered lists with no duplicates ([`SafeGovernance.sol:110-225`](../contracts/governance/lib/SafeGovernance.sol#L110-L225)). `SafeInstructions` calls those validators before a source transaction can succeed.

The Relay target handlers do not call them. Instead they validate only entries addressed to the current deployment and intentionally implement last-write-wins for duplicates, no whole-list cap, and an empty-list no-op ([`Relay.sol:604-706`](../contracts/protocol/implementation/Relay.sol#L604-L706)). This contradicts the library's “single source of truth used by both sides” statement and the still-present “Safe-A3 fixed” documentation.

This matters because `processSafeMessage` treats threshold signatures themselves as remote authorization. It does not require the Safe transaction to execute successfully on Flare, and `txData.to` is not an allowed-helper constraint. A transaction that fails exactly because `SafeInstructions` rejects its structure may still mutate every addressed Relay.

### Impact

A threshold can sign data believing source execution is the operative validation boundary. The source call then fails or is canceled, while an arbitrary relayer delivers the same signatures directly to a target whose looser interpretation applies it. Duplicate fee/collector entries can resolve to a different final value than a signing UI or source simulation expects; oversized batches bypass the documented protocol cap.

This is not an ECDSA forgery or a bypass of the Safe threshold. It is a mismatch between signing intent, documented source validation, and target authorization semantics.

### PoC / reproduction

**Status: executed by the committed unit suite.**

- `test_sourceRejectsNonCanonicalFeeCollectionListButTargetAppliesLastWins` signs two collector entries for one target. Safe execution reverts, then the target accepts the same signed action and installs the second collector ([`SafeGovernance.t.sol:404-427`](../test-forge/unit/governance/SafeGovernance.t.sol#L404-L427)).
- `test_duplicateLocalFeeAppliesLastWins` demonstrates duplicate local fee application ([`SafeGovernance.t.sol:562-579`](../test-forge/unit/governance/SafeGovernance.t.sol#L562-L579)).
- `test_feeBatchAboveSourceLimitStillAppliesOnTarget` signs 257 entries; the target consumes the nonce and applies them although the source cap is 256 ([`SafeGovernance.t.sol:647-667`](../test-forge/unit/governance/SafeGovernance.t.sol#L647-L667)).

These are passing tests of the divergent behavior, not failing regressions.

### Proposed fix

The safest minimal fix is to call the same validator immediately after decoding and canonical re-encoding:

```solidity
SafeGovernance.validateFeeUpdates(updates);
SafeGovernance.validateFeeExemptions(updates);
SafeGovernance.validateFeeCollections(updates);
```

Do this before filtering for local relevance. Then restore differential tests asserting that source and target accept/reject exactly the same action bytes.

If looser target semantics are an intentional product decision, remove the false “one grammar” claims and make the authorization model explicit in signing tools. Stronger alternatives are to bind an expected `SafeInstructions` address/version into the action domain and, ultimately, require authenticated evidence of the canonical Safe `ExecutionSuccess`. Signed expiry, deployment epoch, revocation and cancellation fields narrow the gap but do not by themselves prove source execution.

## M-02 — A far-future random round can permanently freeze the live pointer

**Severity:** Medium; requires a compromised/byzantine quorum above the increased future threshold.
**Affected paths:** Mode-2 epoch checks and current-random state.

### Description and root cause

Relay rejects messages that are too old, but does not impose an upper bound on future voting rounds ([`Relay.sol:1153-1188`](../contracts/protocol/implementation/Relay.sol#L1153-L1188)). The latest initialized policy may sign a message for a future, uninitialized reward epoch after satisfying the increased threshold ([`Relay.sol:1201-1238`](../contracts/protocol/implementation/Relay.sol#L1201-L1238)).

For the random protocol, any accepted voting round strictly larger than the stored one becomes the live pointer ([`Relay.sol:1716-1762`](../contracts/protocol/implementation/Relay.sol#L1716-L1762)). `getRandomNumber()` then evaluates `stateData.randomVotingRoundId + 1` in `uint32` before converting it to `uint256` ([`Relay.sol:1907-1915`](../contracts/protocol/implementation/Relay.sol#L1907-L1915)). At `type(uint32).max`, that read always reverts, and no later `uint32` value can advance the monotonic pointer.

### Impact

A compromised current quorum can convert temporary signing power into permanent future liveness damage: current-random reads revert even after the offending policy is replaced. Recovery needs a Relay upgrade or explicit state migration. This is stronger persistence than the quorum's expected epoch-scoped authority.

### PoC / reproduction

**Status: executed successfully in a disposable Foundry test; the probe was deleted after the run.**

1. Use the current policy and enough signers to exceed the increased future threshold.
2. Sign a random-protocol message with `votingRoundId = type(uint32).max`.
3. Use `keccak256(abi.encode(uint256(votingRoundId), randomValue, uint256(1)))` as the signed root and provide `randomValue` with an empty Merkle proof.
4. Relay accepts the root and stores `randomVotingRoundId = type(uint32).max`.
5. `getRandomNumber()` reverts on the checked `uint32 + 1`; every later representable round is lower and cannot replace the pointer.

The executable probe used four 100-weight signers (400 > the increased threshold 312), relayed a valid random Merkle proof for `type(uint32).max`, and then observed the expected arithmetic revert from `getRandomNumber()`. Foundry reported **PASS** (`gas: 147,031`).

### Proposed fix

- Reject `type(uint32).max` explicitly.
- Cast before addition in both random timestamp calculations: `uint256(stateData.randomVotingRoundId) + 1`.
- Bound finalization to a small configured future horizon and/or to the current time-derived voting round. At minimum, prohibit epochs beyond the next uninitialized reward epoch.
- Add current-round, next-epoch, far-future and terminal-round regressions, plus an invariant that any accepted random pointer remains readable and recoverable by a later valid round.

## M-03 — Fresh Relay migration exposes zero/insecure current randomness

**Severity:** Medium migration risk.
**Affected path:** `getRandomNumber()` during old-to-new cutover.

### Description and root cause

Initialization does not seed `randomVotingRoundId`, `isSecureRandom` or the current value from `oldRelay` ([`Relay.sol:298-413`](../contracts/protocol/implementation/Relay.sol#L298-L413)). Historical reads delegate to the old Relay below the migration boundary, but `getRandomNumber()` never does ([`Relay.sol:1899-1942`](../contracts/protocol/implementation/Relay.sol#L1899-L1942)). A newly deployed proxy therefore returns the default `(0, false, timestampForRound1)` until it receives its first new random proof.

Some consumers correctly require the quality flag, but others discard it:

- `Submission.getCurrentRandom` reverts while the flag is false;
- `MachineManagerFacet.getRandomTeeIds` uses the value without the flag for reservoir sampling;
- `Verification.requestTeeAttestation` uses it in a TEE challenge without the flag; and
- legacy `FtsoProxy`/`PriceSubmitterProxy` getters drop the quality flag.

### Impact

If registries/consumers switch to the fresh Relay before its first new secure root:

- flag-aware consumers lose liveness; and
- flag-blind consumers use a predictable zero seed, weakening selection/challenge unpredictability during the cutover window.

### PoC / reproduction

**Status: executed for the Relay default; full consumer cutover not executed.**

The committed `test_getRandomNumber_beforeAnyRelay` confirms the fresh default `(0, false, ts)` ([`Relay.t.sol:810-815`](../test-forge/unit/protocol/implementation/Relay.t.sol#L810-L815)). Static call-site review confirms the consumers listed above.

### Proposed fix

- Until a local random root exists, make `getRandomNumber()` delegate to `oldRelay.getRandomNumber()` when an old Relay is configured. Presence can be detected from the random-protocol Merkle-root mapping at the current pointer, avoiding a value-as-sentinel mistake.
- Alternatively seed the new Relay from a verified old-relay snapshot during initialization.
- Treat “new Relay returns a non-default, secure, current random” as a mandatory precondition before registry/AddressUpdater cutover.
- Add an end-to-end migration rehearsal covering every current-random consumer, including both quality-aware and quality-blind paths.

## M-04 — Initial policy hash is not bound to the migration boundary

**Severity:** Medium/Low configuration and migration integrity.
**Affected paths:** initialization, Mode-2 writes, and old-relay read delegation.

### Description and root cause

Initialization stores an opaque `initialSigningPolicyHash` and a separate `startingVotingRoundIdForInitialRewardEpochId` ([`Relay.sol:311-330`](../contracts/protocol/implementation/Relay.sol#L311-L330)). When the policy is later supplied to `relay()`, its encoded `startingVotingRoundId` controls write acceptance ([`Relay.sol:1190-1199`](../contracts/protocol/implementation/Relay.sol#L1190-L1199)). Historical reads use the separately configured migration boundary to decide whether to delegate to `oldRelay`.

No on-chain check proves that the start round committed by the hashed policy equals the read boundary.

### Impact

- If the policy's encoded start is lower than the configured boundary, Relay can accept and store new roots that its getters silently shadow by delegating those rounds to `oldRelay`.
- If the encoded start is higher, the cutover can contain an unfinalizable gap.

The deployment scripts normally derive both values from the same live system, so exploitation is configuration-dependent. The contract nonetheless accepts an internally inconsistent migration state.

### PoC / reproduction

**Status: not executed.**

Construct an encoded policy whose start round is `B - 1`, pass its valid hash as `initialSigningPolicyHash`, and separately configure the migration boundary as `B`. Relay a root for `B - 1`; the policy gate permits the write, while `verify`, `merkleRoots`, `isFinalized` and historical random lookup continue reading the old Relay for that round.

### Proposed fix

- Pass the complete initial encoded policy to `initialize`, validate its epoch/start/voters/weights, recompute its source-bound hash, and derive the boundary from the same decoded value.
- If the initializer ABI cannot change, add a one-time policy-reveal step that validates the stored hash and pins its metadata before activation.
- At relay time, require the supplied policy start to equal `startingVotingRoundIds[rewardEpochId]`, not merely that the message round is greater than the supplied start.
- Add lower-start, higher-start and exact-boundary migration regressions.

## L-01 — Deployment parser silently narrows an out-of-range protocol ID

**Severity:** Low deployment safety.
**Affected path:** mirror JSON configuration.

### Description and root cause

`DeployRelayMirror._readFeeConfigs` parses a JSON integer and immediately casts it to `uint8` ([`DeployRelayMirror.s.sol:169-187`](../deployment/scripts/relay/DeployRelayMirror.s.sol#L169-L187)). Solidity explicit narrowing truncates; for example `259` becomes `3`. Relay then sees a valid protocol ID and deploys with a fee for the wrong protocol.

The generated JSON schema describes the field as a `uint8 > 1`, but contains only `"type": "integer"` with no minimum or maximum.

### PoC / reproduction

**Status: not executed.**

Set a mirror fee configuration's `protocolId` to `259`. The parser produces `uint8(259) == 3`; `Relay.initialize` accepts `3 > 1`.

### Proposed fix

Parse into a `uint256`, require `value > 1 && value <= type(uint8).max`, then cast. Add `minimum: 2` and `maximum: 255` to the schema source/generator and a deployment parser regression for 1, 2, 255 and 256/259.

## V-01 — Formal verification does not match the reviewed code

**Classification:** Release/assurance blocker, not a runtime exploit by itself.

The branch documentation explicitly says the Safe-upgradeable refactor leaves the FV gates red pending re-baselining ([`safe-governance.md:981-987`](safe-governance.md#L981-L987)). Direct inspection and local gates confirm that this is not a documentation-only caveat.

### Concrete gate results

| Gate | Result on this checkout | Cause |
|---|---|---|
| `verify_relay_revert_abi.py` | **FAIL**, exit 1 | Manifest expects 37 `revertWithMessage`/`Error(string)` paths; current assembly uses custom-error selectors |
| `verify_gss_governance.py` | **FAIL**, exit 1 / missing file | Manifest names three deleted `GSSGovernance*.t.sol` suites instead of the current Safe suites |
| `verify_relay_artifact.py` | **Blocked/fail-closed locally** | Manifest requires Foundry 1.7.1 while this branch CI uses a newer custom nightly and the local tool is 1.6.0-nightly |
| Safe Halmos fee property | **Semantic failure in a disposable concrete adapter** | Harness hashes the obsolete `uint256 protocolId` selector; production uses `uint8` |
| Certora local/cloud evidence | **Not applicable to current Relay** | Munging imports deleted GSS contracts, uses the removed constructor and models old direct governance storage |
| Lean optimized-Yul snapshot | **Not current bytecode** | Committed Yul references old GSS/revert-string code and differs from fresh 0.8.35 optimized IR |
| Kontrol bridge | **Abstract results only** | No passing current-bytecode/Halmos refinement bridge |

### Manifest and harness drift

- The manifest pins solc 0.8.27 for FV and 0.8.30 for deployment, while current Relay requires `^0.8.35`.
- It names `GSSGovernanceFV` and deleted GSS unit/invariant paths; the current exact Safe gate is 43 tests (37 unit + 3 production rehearsal + 3 invariant).
- `SafeGovernanceFV.t.sol` constructs `changeProtocolFees(uint256,bytes32,(uint256,address,uint256,uint256)[])`; production uses `(uint256,address,uint8,uint256)[]`.
- The harness still expects duplicate local fees to revert atomically, while current code and tests intentionally implement last-write-wins.
- The Safe FV surface does not cover fee exemptions, fee-collection changes, seeded exemptions, the `eth_sign` branch, initializer single-use, implementation locking, UUPS authorization or upgrade storage preservation.
- Certora's munged Relay differs substantially from production and still models the removed direct GSS state instead of ERC-7201 `SafeGoverned` state.

### PoC / reproduction

**Status: executed for the lightweight gates and a disposable semantic adapter; full Halmos/Certora/Lean jobs were not claimed or run against incompatible pins.**

```bash
python3 test-forge/fv/verify_relay_revert_abi.py
python3 test-forge/fv/verify_gss_governance.py
python3 test-forge/fv/verify_relay_artifact.py
```

The first two fail as described. The artifact gate stops at the toolchain mismatch. A disposable adapter calling the current target hook with the harness's fee action made `check_gss_relevantFee_atomicAndConsumed` fail its assertion, while its supposed reachability control passed—exactly the opposite of the required proof/control contract. The disposable file was removed and is not part of this report change.

### Required re-baseline

1. Pin both verification and deployment builds to the exact solc 0.8.35 settings used for production, including `viaIR`, optimizer and metadata settings. Pin one compatible Foundry build consistently in the manifest and CI.
2. Replace the legacy string-revert inventory with a fail-closed custom-error selector gate binding every assembly `ERR_*` constant to the interface ABI.
3. Replace every GSS path/class/test inventory with the current Safe equivalents; make missing files a clean gate failure rather than a traceback.
4. Fix the fee selector to `uint8`. Restore source/target grammar equivalence and retain the atomic-revert property, or deliberately replace it with properties matching the chosen semantics. Add proof/control pairs for exemptions and collection-address changes.
5. Add initializer, implementation-lock, owner-only UUPS, renounce-rejection and upgrade-storage-preservation checks.
6. Regenerate optimized Yul from the exact deployment build, re-audit the literal Lean transcription and re-establish artifact/bytecode parity before citing Lean results.
7. Rewrite Certora munging/harnesses for proxy initialization, `SafeGoverned`, ERC-7201 storage and solc 0.8.35; run a fresh local typecheck and cloud proof.
8. Revalidate the Kontrol model against the current loop and restore its bytecode bridge through a passing exact Halmos suite.
9. Require the complete verification bundle to pass at this exact commit before using “formally verified” or equivalent release language.

## Test assessment

The focused runtime tests are green on the local checkout:

| Area | Command | Result |
|---|---|---|
| Full Forge tree | `forge test --summary --color never` | **PASS: exit 0, every listed suite green** |
| Relay Foundry | `forge test --match-path 'test-forge/unit/protocol/implementation/Relay*.t.sol' --summary --color never` | **PASS: 121 executions** (55 `Relay.t.sol` tests under both configured compiler modes, 10 chain-domain, 1 error-selector) |
| Safe unit/rehearsal/upgrade | `forge test --match-path 'test-forge/unit/governance/Safe*.t.sol' --summary --color never` | **PASS: 65/65** (37 governance, 3 production rehearsal, 15 base, 10 upgrade) |
| Safe stateful invariant | `forge test --match-path test-forge/invariant/governance/SafeGovernanceInvariant.t.sol --summary --color never` | **PASS: 3/3**, each at 128 runs × depth 128 = 16,384 handler calls |
| Relay deployment | `forge test --match-path 'test-forge/unit/deployment/Relay*.t.sol' --summary --color never` | **PASS: 18/18** |
| Hardhat Relay | `node node_modules/hardhat/internal/cli/bootstrap.js test --network hardhat ./test/unit/protocol/implementation/Relay.test.ts` | **PASS: 53** |
| Disposable audit PoCs | `forge test --match-path test-forge/unit/protocol/implementation/RelayAuditPoC.t.sol --match-test '^test_audit_' -vv --color never` | **PASS: 2/2** (duplicate-address threshold acceptance and terminal-random freeze); file removed after execution |

Local tools were solc 0.8.35, Foundry 1.6.0-nightly, Hardhat 2.28.6 and Node 24.14.0. That Foundry version is **not** the stale manifest's 1.7.1 pin and is also not the branch CI's custom `forge-nightly-160b6026` image, so exact deployment/FV artifact claims cannot be inferred from these green functional tests.

### Material coverage gaps

- No **committed** regression covers duplicate **addresses** with one repeated signature at distinct indices; the disposable audit PoC reproduced it.
- No **committed** regression asserts a maximum future voting round or the `uint32.max` current-random failure; the disposable audit PoC reproduced it.
- No end-to-end migration test switches every random consumer while the new Relay has no local current random.
- Current Safe tests deliberately assert source/target grammar divergence; there is no equivalence property after the latest semantic change.
- The initial-policy hash/read-boundary consistency cannot be tested through a full-policy initializer because the initializer never receives that policy.
- The current FV harness lacks exemption, collection, initialization and upgrade properties.
- The upgrade-preservation test snapshots only a small state subset (starting round, last epoch and owner); it does not protect fee/exemption/collector state, Safe owner generations and consumed nonces, roots/random state, source domain or `oldRelay` across an implementation upgrade.
- The stateful Safe invariant models protocol-fee and owner-rotation actions, but not fee-exemption or fee-collection actions and their conflicting/delayed nonce behavior.
- The proxy tests do not directly pin rejection of a zero `_initialOwner` (currently inherited from OpenZeppelin's initializer behavior).

## Accepted design risks and hardening proposals

These are real authority/trust exposures, but not new unprivileged exploits found in this review:

| Risk | Current behavior | Hardening option |
|---|---|---|
| Signed but unexecuted/canceled Safe transaction | Target accepts valid threshold signatures without Flare execution evidence | Prove finalized `ExecutionSuccess` through a light client/bridge; otherwise add signed expiry, revocation epoch and deployment domain |
| Same Safe nonce, two signed actions | First delivery wins independently on each target; targets can diverge | Canonical source execution proof or signed nonce-to-digest registry |
| Lagging owner rotation | Removed source owner remains valid on targets that have not installed the new generation | Authenticated owner checkpoints, expiry, or suspend consumers on missed cutover |
| `uint256.max` fee action nonce | Permanently exhausts later fee governance | Reject terminal nonce, bound forward gaps, and add an authorized recovery action |
| Per-chain UUPS owner | Upgrade owner can replace all Relay logic outside Safe fee-action restrictions | Use an `Ownable2Step` timelocked multisig/Safe and an explicit upgrade ceremony with codehash checks |
| Reverting fee collector | Paid `verify()` calls revert if forwarding the fee fails | Pull-payment accounting or a non-reverting collector contract with monitored withdrawal |
| `verifyCustomSignature` consumer domain | Same-source, same-chain cross-deployment replay remains caller-controlled | Require consumers to hash their address, chain/source domain, purpose and nonce |

## Recommended implementation order

1. **P0 — restore enforceable invariants:** validate unique/nonzero policy voters on all paths; restore source/target governance grammar equivalence; reject terminal/far-future random rounds.
2. **P0 — make migration safe:** add old-current-random fallback/seed and bind the initial policy metadata to the read boundary; add a registry-cutover rehearsal.
3. **P0 — rebuild assurance:** re-pin and re-baseline the complete FV stack, then require the exact bundle green at the release commit.
4. **P1 — harden governance authority:** decide whether canonical source execution is required; if not, add explicit signed expiry/deployment/revocation domains and make signing UI semantics match Relay semantics.
5. **P2 — deployment/operations:** reject numeric narrowing, bound configuration values, move upgrade ownership to a delayed two-step authority, and preflight fee-recipient behavior.

## Confirmed nonissues

- `Relay` disables initialization on the implementation, and `RelayProxy` initializes atomically in its constructor.
- UUPS upgrade authorization is owner-gated; `renounceOwnership` is disabled.
- The signature parser enforces increasing indices, in-range indices, canonical `v`/low-`s`, exact precompile output, a nonzero recovered signer and equality with the selected policy entry. H-01 is specifically about duplicate addresses across different valid entries.
- `verify()` performs no Relay storage writes. Fee-recipient/refund/old-relay reentrancy cannot corrupt Relay state or extract value belonging to another invocation.
- Random leaf binding, sorted Merkle folding, zero-root rejection and monotonic handling of ordinary stale rounds appear sound under a valid policy and nonterminal round.

## Review limitations

This was a source and local-test review, not a live-deployment audit. It did not verify current on-chain proxy implementations, owners, Safe configuration, registry pointers or deployed bytecode hashes. Disposable Foundry probes executed the duplicate-voter and terminal-random cases; the boundary-mismatch case remains source-derived and unexecuted. The lightweight stale-FV gates and governance divergence tests were executed; incompatible full formal jobs were not presented as current evidence.
