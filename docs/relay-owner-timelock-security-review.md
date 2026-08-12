# `Relay.sol` security review — `relay-owner-timelock`

**Review date:** 2026-08-10
**Upstream and formal-evidence refresh:** 2026-08-12
**Branch:** `relay-owner-timelock` tracking `origin/relay-owner-timelock`
**Reviewed commit:** `d5af7136c03d6bab83307b0f4bd49101b8792e40`
**Primary targets:** [`Relay.sol`](../contracts/protocol/implementation/Relay.sol), [`OwnableWithTimelock.sol`](../contracts/utils/implementation/OwnableWithTimelock.sol), and the new FDC2 threshold-verification integration
**Review status:** the latest branch was fetched and fast-forwarded, the source delta from `7fdba93a…` to `d5af7136…` was reviewed, and the upstream full Forge tree plus focused Relay/FDC2/governance/Hardhat tests pass. The current working tree fixes L-04 and its focused exact-BIPS tests pass. The formal suite has also been locally rebaselined against reviewed source revision `d5af7136…` and manifest `7ae2208f…`: deployment, ABI, artifact parity, Halmos, Lean, and Certora local all pass. Those reports and their aggregate bundle are development-only solely because the checkout was dirty. Supplemental Certora cloud evidence is PARTIAL: the threshold job passes, while scalar and write-once retain sanity failures.

## Executive verdict

No unconditional, permissionless Critical exploit was found in the current signature parser, Merkle verification, fee forwarding, proxy initialization, timelock execution, or UUPS entry point.

The branch is nevertheless **not release-ready under its existing security and formal-verification claims**:

- a malformed signing policy can count one key at multiple voter indices, violating the stated distinct-voter threshold property;
- a sufficiently large current quorum can sign `type(uint32).max` as a random round, permanently freezing `getRandomNumber()` and preventing any later round from replacing the pointer;
- a fresh Relay migration exposes a predictable zero/insecure current random until its first local random proof, while some consumers discard the security flag;
- the opaque initial policy hash and migration read boundary are independent, allowing shadowed roots or a finalization gap;
- timelocked operations are not bound to an owner generation, implementation version, or expiry, so a former owner's queued upgrade remains executable after ownership transfer; and
- the advertised nonzero FDC2 threshold path is a raw primitive, not a proof-aware verifier: it neither derives the threshold from the signed response header nor enforces the Hub's low-threshold cosigner condition. The existing shared helper and cross-chain walkthrough still use the policy-threshold path; and
- all six current local formal constituents and their aggregate bundle pass, including new threshold/transient coverage, but they are development-only because generation occurred in a dirty tree; supplemental Certora cloud evidence is PARTIAL and is not a release verdict.

The previous branch's source/target Safe-governance grammar mismatch is gone because the Safe governance system was removed. The replacement owner-timelock has no current unprivileged execution bypass in the reviewed implementation, but its stale-operation semantics need an explicit product decision and stronger lifecycle controls.

The upstream delta does not close any earlier finding below. The current
working tree closes L-04's concrete arithmetic defect and the local formal
rebaseline covers its exact arithmetic and transient-state boundaries. The upstream delta adds a
caller-selected FDC2 signature threshold, transports it through transient
storage, tightens setter-mode initialization, and refactors several assembly
reads from memory copies to direct calldata loads. I found no new path that
lets the override lower Mode-1 policy rotation or Mode-2 finalization quorum:
the assembly consumes it only for protocol ID 1, successful calls clear it,
and a revert rolls the transient write back. The security gap is at the API and
consumer boundary, where the caller supplies the signed hash and threshold as
independent values.

### Finding summary

| ID       | Severity                                      | Finding                                                                         | Release disposition                                                          |
| -------- | --------------------------------------------- | ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| **H-01** | **Conditional High**                          | Duplicate voter addresses are counted at distinct indices                       | Fix before deployment; enforce uniqueness on every policy-ingestion path     |
| **M-01** | **Medium, quorum-authority**                  | A far-future terminal random round permanently freezes current randomness       | Bound the future horizon and reject the terminal round                       |
| **M-02** | **Medium, migration**                         | A fresh Relay does not inherit or fall back to the old current random           | Seed/fallback before registry cutover                                        |
| **M-03** | **Medium/Low, migration**                     | Initial policy metadata is not bound to the configured read boundary            | Initialize from and validate the complete policy                             |
| **L-01** | **Low, privileged/operational**               | Queued calls survive owner changes, upgrades, and indefinitely stale intent     | Bind operations to authority/version epochs and add expiry/cancel-all        |
| **L-02** | **Low, deployment**                           | JSON protocol IDs are narrowed to `uint8` before validation                     | Validate as `uint256` before casting; add schema bounds                      |
| **L-03** | **Low, conditional availability**             | Protocol-1 verification now requires EIP-1153 on every target chain             | Preflight every deployment target or avoid transient opcodes                 |
| **L-04** | **Low, liveness/integration — fixed locally** | Round-up plus strict comparison overstated the requested BIPS threshold         | Floor plus strict comparison implemented and locally reverified              |
| **M-04** | **Medium, integration/feature**               | FDC2's nonzero threshold is not bound and enforced end-to-end                   | Add a proof-aware verifier; do not advertise the raw primitive as sufficient |
| **C-01** | **Conditional High compatibility constraint** | Directly upgrading a `relay-safe-governance` proxy is unsupported and unsafe    | Prove no such deployment exists or ship a tested migration reinitializer     |
| **V-01** | **Release-evidence blocker**                  | Local formal reports and bundle pass but are development-only; cloud is PARTIAL | Re-run clean and scope any cloud claim to passing/non-sanity-failed nodes    |

Severity qualifications are important. H-01 requires a malformed policy to be installed. M-01 requires a quorum above the increased future threshold. L-01 requires privileged stale intent and is visible/cancelable if operations are monitored. C-01 is not a live issue if the documented statement that the Safe branch was never deployed is verified.

## Scope and threat model

The review covered:

- `Relay.sol`, `RelayProxy.sol`, `IIRelay`, and `IRelay`;
- `OwnableWithTimelock` and its interface;
- home/mirror Relay deployment and configuration parsing;
- Relay, timelock, upgrade, chain-domain, and deployment tests; and
- the Halmos manifest/harnesses, custom-error ABI and artifact gates, Certora munging, Lean/Yul snapshot, and Kontrol bridge.

The ordinary adversary may submit, reorder, replay, or front-run valid calldata but cannot forge ECDSA signatures. The signing-policy setter, quorum, and Relay owner are privileged trust roots. Findings requiring those authorities are marked conditional or operational rather than presented as attacks against a healthy configuration.

## H-01 — Duplicate voter addresses are double-counted at distinct indices

**Severity:** Conditional High impact; configuration-dependent likelihood.
**Affected paths:** initial opaque policy, `setSigningPolicy`, Mode-1 policy relay, and the signature loop.

### Description and root cause

`setSigningPolicy` explicitly delegates zero-address and voter-uniqueness checks to the trusted setter and validates only dimensions, total weight, and threshold consistency ([`Relay.sol:442-469`](../contracts/protocol/implementation/Relay.sol#L442-L469)). Mode 1 likewise checks policy size and total-weight/threshold consistency but never compares voter identities ([`Relay.sol:817-868`](../contracts/protocol/implementation/Relay.sol#L817-L868), [`Relay.sol:1254-1335`](../contracts/protocol/implementation/Relay.sol#L1254-L1335)). The initial deployment accepts only an opaque hash, so it cannot validate voter identities at all.

The signature loop requires indices to increase ([`Relay.sol:1466-1480`](../contracts/protocol/implementation/Relay.sol#L1466-L1480)), then compares the recovered signer with the address at that index and adds the indexed weight ([`Relay.sol:1498-1546`](../contracts/protocol/implementation/Relay.sol#L1498-L1546)). If two entries contain the same address, the same `(v,r,s)` can be copied at two strictly increasing indices and both weights are added.

The upstream `d5af7136…` comment still incorrectly says a duplicate voter can be counted at most once. The retained audit worktree corrects that wording: increasing indices prevent reuse of an **index**, not reuse of a **key** ([`Relay.sol:1518-1525`](../contracts/protocol/implementation/Relay.sol#L1518-L1525)). This comment-only correction does not enforce the invariant; a malformed admitted policy remains exploitable.

The normal Flare setter path lowers likelihood. `VoterRegistry.createSigningPolicySnapshot` obtains registered signing addresses ([`VoterRegistry.sol:196-228`](../contracts/protocol/implementation/VoterRegistry.sol#L196-L228)), while `EntityManager` prevents an explicitly registered signing address from belonging to two voters ([`EntityManager.sol:221-243`](../contracts/protocol/implementation/EntityManager.sol#L221-L243)). That upstream invariant does not protect an opaque migration policy, a setter regression/upgrade, or a malformed quorum-relayed Mode-1 policy.

### Impact

Once a malformed policy is active, fewer distinct keys than intended can:

- finalize arbitrary protocol roots and random values;
- approve `verifyCustomSignature` messages; or
- install a subsequent signing policy.

This violates the central threshold claim and amplifies an upstream configuration or policy-generation failure into a consensus bypass under the malformed policy.

### PoC / reproduction

**Status: executed successfully in a disposable Foundry test; the probe was removed after execution.**

The test installed:

```text
voters    = [A, A, C, D, E]
weights   = [150, 150, 67, 67, 66]
threshold = 260
```

`A` signed once. The identical signature was encoded at indices `0` and `1`. Both recoveries matched their indexed voter address; `300 > 260`, so a single distinct key finalized a protocol root. The audit suite reported **PASS**.

The current Halmos tests do not cover this case. `RelaySigFV` constructs distinct voters and tests duplicate indices `[0,1,1]` ([`RelaySigFV.t.sol:31-39`](../test-forge/fv/RelaySigFV.t.sol#L31-L39), [`RelaySigFV.t.sol:66-77`](../test-forge/fv/RelaySigFV.t.sol#L66-L77)); the parametric harness explicitly makes distinct addresses an A4 constructional assumption ([`RelaySigParamFV.t.sol:20-43`](../test-forge/fv/RelaySigParamFV.t.sol#L20-L43)). Lean/Kontrol model indexed weight accounting, not address uniqueness.

### Proposed fix

1. Reject `address(0)` and duplicate voter addresses in both `setSigningPolicy` and Mode-1 ingestion.
2. Prefer a canonical strictly increasing address order if protocol compatibility permits it. Otherwise use a bounded in-memory set or pairwise check; `MAX_VOTERS` is 300.
3. Initialize from the complete initial policy, validate it, and recompute its source-bound hash on-chain instead of accepting only an opaque hash.
4. Add the exact repeated-address/repeated-signature regression for the setter, initial-policy reveal, and Mode-1 paths.
5. Restate and prove the actual property: accepted weight is the sum of distinct recovered signer identities, with policy uniqueness enforced or proved as an explicit admission precondition.

## M-01 — A terminal future random round permanently freezes current randomness

**Severity:** Medium; requires a byzantine/compromised quorum above the increased future threshold.
**Affected paths:** Mode-2 epoch checks and current-random state.

### Description and root cause

Relay rejects messages that are too old but has no upper bound on future voting rounds. The latest policy may sign an arbitrarily future, uninitialized reward epoch after satisfying the increased threshold ([`Relay.sol:1111-1197`](../contracts/protocol/implementation/Relay.sol#L1111-L1197)).

For the random protocol, any accepted round greater than the stored pointer becomes current ([`Relay.sol:1693-1720`](../contracts/protocol/implementation/Relay.sol#L1693-L1720)). `getRandomNumber()` then computes `stateData.randomVotingRoundId + 1` while the value is still `uint32`, before converting it to `uint256` ([`Relay.sol:1857-1873`](../contracts/protocol/implementation/Relay.sol#L1857-L1873)). At `type(uint32).max`, the getter always reverts. No later representable `uint32` can exceed the poisoned monotonic pointer.

### Impact

A current quorum can turn temporary epoch-scoped authority into persistent liveness damage. Current-random reads revert even after the policy is replaced; recovery requires an implementation upgrade or state migration.

### PoC / reproduction

**Status: executed successfully in a disposable Foundry test; the probe was removed after execution.**

Four 100-weight signers exceeded the future threshold of 312, signed a valid random leaf for `votingRoundId = type(uint32).max`, and supplied the committed random value. Relay stored the terminal pointer. A subsequent `getRandomNumber()` static call reverted on arithmetic overflow. The audit suite reported **PASS**.

### Proposed fix

- Reject `type(uint32).max` explicitly.
- Cast before adding: `(uint256(stateData.randomVotingRoundId) + 1)`.
- Bound finalization to a small future horizon derived from the current time/round, or at minimum prohibit reward epochs beyond the next uninitialized epoch.
- Add current-round, next-epoch, far-future, and terminal-round tests plus an invariant that every accepted live pointer is readable and replaceable by a later valid round.

## M-02 — Fresh Relay migration exposes zero/insecure current randomness

**Severity:** Medium migration risk.
**Affected path:** `getRandomNumber()` during old-to-new cutover.

### Description and root cause

Initialization configures `oldRelay` but does not seed the live random pointer, value, or security bit ([`Relay.sol:301-425`](../contracts/protocol/implementation/Relay.sol#L301-L425)). Historical reads delegate below the migration boundary, but `getRandomNumber()` never delegates and simply reads zero-initialized local state ([`Relay.sol:1857-1900`](../contracts/protocol/implementation/Relay.sol#L1857-L1900)). The committed test explicitly expects `(0, false, timestampForRound1)` before the first local random ([`Relay.t.sol:797-803`](../test-forge/unit/protocol/implementation/Relay.t.sol#L797-L803)).

Some consumers correctly enforce the quality flag, but `MachineManagerFacet` uses the value for reservoir sampling without it ([`MachineManagerFacet.sol:304-318`](../contracts/tee/facets/MachineManagerFacet.sol#L304-L318)), and `Verification` uses it in TEE challenge creation without it ([`Verification.sol:180-187`](../contracts/tee/library/Verification.sol#L180-L187)). Legacy proxy getters also discard the flag.

### Impact

If registries or consumers switch to the fresh Relay before its first local secure root, flag-aware consumers lose liveness and flag-blind consumers use a predictable zero seed.

### PoC / reproduction

**Status: committed default-state test passes; consumer cutover was source-reviewed, not run end-to-end.**

### Proposed fix

- Until a local random root exists, delegate `getRandomNumber()` to `oldRelay.getRandomNumber()` when an old Relay is configured; detect presence from finalized-root state rather than treating random value zero as absent.
- Alternatively seed the new Relay from a verified old-relay snapshot during initialization.
- Require a non-default secure current random as a registry-cutover precondition.
- Make every consumer either require `_isSecureRandom` or explicitly document why insecure fallback is safe.
- Add an end-to-end migration rehearsal for every current-random consumer.

## M-03 — Initial policy metadata is not bound to the migration read boundary

**Severity:** Medium/Low configuration and migration integrity.
**Affected paths:** initialization, Mode-2 writes, and old-relay read delegation.

### Description and root cause

Initialization stores an opaque `initialSigningPolicyHash` and a separately configured `startingVotingRoundIdForInitialRewardEpochId` ([`Relay.sol:314-336`](../contracts/protocol/implementation/Relay.sol#L314-L336)). When that policy is supplied to `relay()`, its encoded start round gates writes ([`Relay.sol:1148-1157`](../contracts/protocol/implementation/Relay.sol#L1148-L1157)). Read paths use the independent configured boundary to select the old Relay ([`Relay.sol:1766-1777`](../contracts/protocol/implementation/Relay.sol#L1766-L1777), [`Relay.sol:1828-1849`](../contracts/protocol/implementation/Relay.sol#L1828-L1849)).

No on-chain check proves that the start round committed by the hashed policy equals the read boundary. The comment asserting that no new write can land below the boundary therefore relies on an unstated equality that the contract does not establish.

### Impact

- If the encoded policy start is lower than the configured boundary, Relay can accept and store roots that its getters silently shadow by delegating to `oldRelay`.
- If the encoded start is higher, the cutover can contain an unfinalizable gap.

Deployment tooling normally derives both fields from the same source, reducing likelihood, but the contract accepts inconsistent state.

### PoC / reproduction

**Status: executed successfully in a disposable Foundry test; the probe was removed after execution.**

The test configured read boundary `3400` and a correctly hashed initial policy whose encoded start was `3399`. A quorum root for round `3399` was accepted by the new Relay. Calling `verify()` for that same root delegated to a mock old Relay because `3399 < 3400` and reverted on the old Relay's result, proving the new root was shadowed. The audit test reported **PASS**.

### Proposed fix

- Pass the complete encoded initial policy to `initialize`, validate it, recompute its source-bound hash, and derive the boundary from the decoded policy.
- If the initializer ABI cannot change, add a one-time reveal step that validates the stored hash and pins metadata before activation.
- Require the policy start supplied to `relay()` to equal the stored `startingVotingRoundIds[rewardEpochId]` rather than only comparing the message round with the supplied metadata.
- Add lower-start, higher-start, and exact-boundary migration regressions.

## L-01 — Timelocked calls outlive their authority and implementation context

**Severity:** Low, privileged/operational; high potential impact.
**Affected paths:** ownership handover, upgrades, and superseded queued operations.

### Description and root cause

The queue stores only `keccak256(encodedCall) -> ETA` ([`OwnableWithTimelock.sol:18-23`](../contracts/utils/implementation/OwnableWithTimelock.sol#L18-L23), [`OwnableWithTimelock.sol:139-153`](../contracts/utils/implementation/OwnableWithTimelock.sol#L139-L153)). Execution checks presence and time, deletes the entry, sets a generic self-call flag, and calls the exact calldata ([`OwnableWithTimelock.sol:39-56`](../contracts/utils/implementation/OwnableWithTimelock.sol#L39-L56)). It does not bind the operation to:

- the owner that queued it or an owner generation;
- the implementation/codehash under which the calldata was reviewed;
- an operation nonce/salt; or
- an expiry/grace deadline.

`transferOwnership` is inherited as an immediate one-step operation, while only the current owner can cancel. Consequently, a queued call survives ownership transfer and remains permissionlessly executable. Queues also survive upgrades, where the same selector/calldata may have new semantics. Failed operations remain live atomically and can become valid after later state or implementation changes.

This behavior is partly acknowledged: the docs say older matured intent remains executable ([`relay-governance.md:19-30`](relay-governance.md#L19-L30)), and the unit suite asserts that superseded duration changes execute in arbitrary order ([`RelayOwnableWithTimelock.t.sol:116-135`](../test-forge/unit/governance/RelayOwnableWithTimelock.t.sol#L116-L135)). Event logs reveal exact queued calldata, so a diligent new owner can cancel known operations; this mitigation and the privileged prerequisite drive the Low severity.

### Impact

A former owner can retain delayed authority after its role has been revoked. Because `upgradeToAndCall` is on the guarded surface, the stale operation can replace all Relay logic. An old queued call can also be reinterpreted by a newer implementation, invalidating the review performed when it was queued.

### PoC / reproduction

**Status: executed successfully in a disposable Foundry test; the probe was removed after execution.**

1. Owner A queued a UUPS upgrade with a one-day delay.
2. A immediately transferred ownership to B.
3. After one day, an unrelated account called `executeTimelockedCall`.
4. The queued implementation became active while B remained the nominal owner.

The audit suite reported **PASS**.

### Proposed fix

1. Store an owner/queue generation in each operation and bump the generation on every ownership transfer. A generation bump should invalidate all prior operations atomically.
2. Bind queued calls to the current implementation address or codehash, or bump the queue generation after every upgrade.
3. Add an execution grace period and expiry, plus a permissioned `invalidateAllTimelockedCalls()`/generation bump.
4. Use a timelocked `Ownable2Step` transfer/acceptance ceremony; acceptance should invalidate old-owner queues.
5. Track the executing operation hash rather than a generic boolean as defense in depth.
6. Add regressions for queue -> owner rotation -> rejection and queue -> implementation upgrade -> rejection.

## L-02 — Deployment parser narrows protocol IDs before validating them

**Severity:** Low deployment safety.
**Affected path:** mirror JSON fee configuration.

`DeployRelayMirror._readFeeConfigs` parses a JSON integer and immediately casts it to `uint8` ([`DeployRelayMirror.s.sol:175-195`](../deployment/scripts/relay/DeployRelayMirror.s.sol#L175-L195)). An input such as `259` becomes `3`, and Relay accepts it as a valid protocol ID. The source-snapshot loader similarly narrows reward epochs, round/timestamp fields, durations, threshold settings, and protocol ID before checking their ranges ([`RelayDeployBase.s.sol:250-273`](../deployment/scripts/relay/RelayDeployBase.s.sol#L250-L273)). Generated snapshots should already be typed correctly, but a stale or hand-edited artifact can silently change meaning. The JSON schema describes a fee protocol ID as a byte greater than one but provides neither a minimum nor a maximum ([`relay-parameters.json:5-22`](../deployment/chain-config/relay/relay-parameters.json#L5-L22)).

**PoC status:** source-derived; not executed.

Parse every numeric field into `uint256`, range-check against its destination type and semantic minimum, and cast only afterward. Add schema bounds and tests for each exact boundary plus one-overflow values; for protocol IDs include `1`, `2`, `255`, `256`, and `259`.

## L-03 — Protocol-1 verification now requires EIP-1153

**Severity:** Low, conditional deployment/availability risk.
**Affected paths:** both `verifyCustomSignature` entry points on every home or mirror deployment.

The new wrapper writes the caller's override with `TSTORE` ([`Relay.sol:595-617`](../contracts/protocol/implementation/Relay.sol#L595-L617)), and the common protocol-1 assembly path executes `TLOAD` even when the legacy entry point left the slot at zero ([`Relay.sol:1079-1105`](../contracts/protocol/implementation/Relay.sol#L1079-L1105)). Consequently, every protocol-1 verification now requires a Cancun-compatible target runtime. A chain without EIP-1153 raises an invalid opcode and loses both the new and legacy custom-signature paths after upgrade.

The repository compiles Relay for Cancun, so this is not a compiler mismatch. It is a target-chain compatibility condition that the deployment scripts do not currently probe. Require a fork/RPC opcode smoke for every home and mirror chain before upgrade, publish the supported-chain matrix, and fail deployment if transient storage is unavailable. If arbitrary pre-Cancun EVM mirrors remain a product requirement, transport the override without transient opcodes.

## L-04 — Exact BIPS threshold arithmetic — fixed in working tree

**Severity:** Low liveness/integration; conditional on a minimally sufficient signer set, and potentially unsatisfiable for a low-total admitted policy near 100%.
**Affected path:** `verifyCustomSignatureWithThreshold`.

The reviewed upstream implementation computed `ceil(totalWeight * thresholdBIPS / 10000)` and then required accumulated weight to be **strictly greater**. This applied two conservative steps. For example, `200 / 500 = 40%` is mathematically greater than a requested 3999 BIPS, but the old calculation rounded `199.95` up to `200` and rejected `200 > 200`. For the same admitted 500-weight test policy, 9999 BIPS rounded to 500, so even all five signers could not satisfy the call although the public API rejected only 10000 and above.

**Resolution status:** fixed in the current working tree at [`Relay.sol:1093-1103`](../contracts/protocol/implementation/Relay.sol#L1093-L1103) by using floor division with the existing strict comparison. Committed tests require 3999 BIPS to accept 200/500, 4000 and 6000 equality to reject, 9999 to accept 500/500, and fuzz the implementation against the exact cross-product predicate.

The local formal rebaseline is also complete. Halmos proves 11 bounded
threshold/transient properties with six validated reachability controls; Lean
proves floor/strict cross-product equivalence, no wrap, zero/non-protocol
fallback, and composition with the existing strict signature loop; and the
dedicated Certora threshold config compiles and CVL-typechecks locally. The
Lean refinement composition retains an explicit `hsetupThreshold` premise for
the unextracted `TSTORE -> self-call -> TLOAD -> threshold-local` seam. The
Certora local result is front-end evidence, not a cloud proof verdict.

The implemented predicate is:

```text
signedWeight * 10000 > totalWeight * thresholdBIPS
```

For integer weights this is equivalent to `floor(totalWeight * thresholdBIPS / 10000)` with the existing strict comparison. The products are bounded by the admitted 16-bit total weight and cannot overflow `uint256`.

## M-04 — FDC2's nonzero threshold is not enforced end-to-end

**Severity:** Medium integration risk; release blocker for the advertised nonzero-threshold feature.
**Affected paths:** FDC2 request admission, signing-policy verification, cosigner authorization, and cross-chain consumer guidance.

The Hub correctly validates the signed request's `thresholdBIPS` range and requires a cosigner majority when a nonzero threshold is below 50% ([`Fdc2Hub.sol:75-87`](../contracts/fdc2/implementation/Fdc2Hub.sol#L75-L87)). The new consumer-facing function, however, accepts `_messageHash` and `_thresholdBIPS` as independent caller arguments and blindly forwards both to Relay ([`Fdc2Verification.sol:62-70`](../contracts/fdc2/implementation/Fdc2Verification.sol#L62-L70)). Neither Relay nor this wrapper can establish that the supplied threshold is the value authenticated inside the signed `Fdc2ResponseHeader`.

The shared production helper still calls only the policy-threshold entry point ([`Fdc2ProofVerification.sol:31-45`](../contracts/fdc2/library/Fdc2ProofVerification.sol#L31-L45)), and the typical cross-chain flow still directs consumers to that helper ([`Fdc2.md:217-219`](specs/FDC/Fdc2.md#L217-L219)). This creates two failure modes:

- if a request asks for a threshold above the signing policy's default, a consumer following the helper/docs can accept less weight than the signed request required; and
- if it asks for a lower threshold, the helper needlessly rejects a response that satisfied the requested quorum.

Calling the raw new method is not sufficient by itself. A caller can supply a lower threshold than the one in the signed header. For thresholds below 50%, it must also preserve the Hub's corresponding cosigner-majority invariant, but the threshold wrapper verifies no cosigners. The existing cosigner helper intentionally uses a live caller-supplied set rather than the signed request's set ([`Fdc2ProofVerification.sol:80-100`](../contracts/fdc2/library/Fdc2ProofVerification.sol#L80-L100)); rotation therefore needs explicit semantics and cannot be assumed to preserve the request-time invariant automatically.

No current in-tree production consumer is directly exploitable: all existing consumer paths require `thresholdBIPS == 0`, and no production caller uses the new function. The issue becomes security-relevant as soon as the advertised nonzero-threshold or cross-chain feature is integrated.

### Proposed fix

1. Add one proof-aware verification helper that accepts the authenticated response/header, computes the canonical signed hash, derives `thresholdBIPS` internally, invokes Relay, and validates the returned reward-epoch window.
2. Bind the response to an expected/stored request, `proofOwner`, threshold range/minimum, and the corresponding signed and/or current cosigner policy. Specify rotation semantics rather than describing a live policy as unconditionally stronger.
3. Make consuming applications enforce timestamp freshness and a consumed request/proof identifier; the stateless verifier alone does not prevent reuse of the same valid proof.
4. Add real Relay + FDC2 integration tests for zero, lower, and higher thresholds; a supplied threshold different from the signed header; a below-50% threshold without cosigner majority; and cosigner rotation.
5. For cross-chain use, add a source-chain-aware signed-payload helper. The current helper hashes local `block.chainid` ([`SignedPayload.sol:36-43`](../contracts/utils/lib/SignedPayload.sol#L36-L43)), which is ambiguous for a source-signed proof recomputed on a destination chain.

**Upgrade note:** older FDC2 Hub state allowed `minThresholdBIPS == 10000`. After this upgrade, every nonzero threshold is rejected until governance lowers such a stored value. Add a pre-upgrade state check and migration rehearsal.

## C-01 — Direct upgrade from `relay-safe-governance` is unsupported and unsafe

**Classification:** Conditional High compatibility constraint, not a live issue if the Safe branch was never deployed.

The branch documentation says the Safe machinery was removed before any deployment ([`relay-governance.md:3-7`](relay-governance.md#L3-L7)). That statement is load-bearing.

The parent Safe implementation stored the RLY-23 source id inside the `SafeGoverned` ERC-7201 namespace and exposed it through `_safeSourceChainId()`. This branch adds `sourceChainId` as a new sequential Relay storage field ([`Relay.sol:263-277`](../contracts/protocol/implementation/Relay.sol#L263-L277)) and adds a different, initially empty timelock namespace. There is no reinitializer that copies the source id or seeds the duration.

Directly upgrading a proxy running the Safe-branch implementation would therefore leave `sourceChainId == 0` and `timelockDurationSeconds == 0`. Existing source-bound policy hashes would no longer match policy calculations, and owner setters/upgrades would take the immediate path. Setter-mode policy rotation could subsequently bind policies/messages to source zero rather than the intended network.

**PoC status:** source/storage-layout comparison; not executed as a cross-branch proxy test.

Before release, either:

- prove from deployment inventories and on-chain bytecode that no Safe-branch proxy exists and state explicitly that this is fresh-deploy-only code; or
- add a versioned, owner/self-guarded migration reinitializer that copies/verifies the old source id, seeds the timelock, invalidates old governance state, and is exercised through `upgradeToAndCall` in a real cross-version storage test.

Add an automated storage-layout compatibility gate for every supported upgrade pair.

## V-01 — Local formal evidence passes but is not release eligible

**Classification:** Release/assurance blocker, not a runtime exploit by itself.

The stale-fixture and missing-threshold-coverage problems identified during the
review have been repaired locally. The current exact manifest is
`7ae2208f96a520f477b528ee808909f87e9402247bacab00e04052fa02ec2cb1`,
and the local reports bind reviewed source revision `d5af7136…`. Every local gate passes; each report
has `release_eligible=false` solely because it was generated from a dirty
checkout. The aggregate bundle passes with the same development-only boundary.
The supplemental cloud import is PARTIAL rather than a release verdict.

### Current evidence status

| Layer                    | Observation on `d5af7136…`                                                                                                                                                    |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Deployment/provenance    | **PASS, development-only.** Report SHA-256 `44468783…`.                                                                                                                       |
| Custom-error ABI         | **PASS, development-only:** 37/37 assembly selectors. Report SHA-256 `1fb2ca10…`.                                                                                             |
| Compiler/artifact parity | **PASS, development-only.** Current bytecode and regenerated optimized Yul match. Report SHA-256 `0b2a7518…`.                                                                 |
| Halmos                   | **PASS, development-only:** 123/123 = 86 proofs + 37 validated reachability controls, 0 violations. Report `f591eb78…`.                                                       |
| Lean/Yul                 | **PASS, development-only:** 9/9 files and 183 axiom audits. Report `82fff1ff…`.                                                                                               |
| Certora local            | **PASS, development-only:** 3/3 configs, 15 rules, 0 local violations. Report `9d3ce039…`; not a prover verdict.                                                              |
| Certora cloud            | **PARTIAL, supplemental:** threshold PASS; scalar/write-once PARTIAL; 308 `SUCCESS`, 2 `SATISFIED`, 24 `SANITY_FAIL`, 0 semantic CEX/`UNKNOWN`/`TIMEOUT`. Report `93d09d86…`. |
| Verification bundle      | **PASS, development-only.** Validates all six reports; SHA-256 `be386d63acdd336b99ab84c64cb0f32ba9c3bafbba02b17164ebd176b7e4f64a`.                                            |

The new Halmos threshold harness covers the exact floor-plus-strict predicate,
zero and non-protocol fallback, protocol-1 reachability, success cleanup,
caught-revert rollback, and address scope. Lean proves the arithmetic and
strict-loop composition but retains the explicit `hsetupThreshold` premise at
the unextracted call-frame seam. The passing Certora threshold job proves the
pure exact-arithmetic lemma and fail-fast behavior for `_thresholdBIPS >= 10000`
before any `SSTORE`, `TSTORE`, or external `CALL`; it does not prove successful
forwarding, cleanup, rollback, mode isolation, or a link from the pure lemma to
the successful Yul-local path. Certora local proves only that
the three current configs compile, munge, and CVL-typecheck; it must not be
described as a proof verdict. None of these results closes H-01: indexed accounting still
depends on the admitted policy having unique voter addresses.

### Remaining assurance work

1. Re-run every local constituent from one clean commit and generate a release-eligible aggregate bundle.
2. Resolve or explicitly exclude the 24 Certora sanity failures before promoting the affected scalar/write-once method/rule pairs.
3. Add end-to-end FDC2 request/header -> verifier -> Relay properties and tests that enforce the authenticated threshold and corresponding cosigner policy.
4. After fixing H-01 and M-01 through M-03, add the missing identity, terminal/future-random, migration-boundary, and current-random fallback properties.
5. Do not use “formally verified” or equivalent release language until the clean bundle and any claimed cloud evidence exist.

## Test assessment

Focused functional tests are strong and green on the reviewed checkout:

| Area                                      | Result on the current working tree                                                                                             |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Full Forge tree                           | **2,079/2,079 pass** after the exact-BIPS fix                                                                                  |
| Owner-timelock + upgrade Forge tests      | **39/39 pass** (30 timelock, 9 upgrade)                                                                                        |
| Focused Relay unit file                   | **70/70 pass**                                                                                                                 |
| Focused FDC2 Forge tests                  | **53/53 pass**                                                                                                                 |
| Hardhat Relay suite                       | **53/53 pass**; it has no threshold-override coverage                                                                          |
| Formal-verification checker utility tests | **109/109 pass**                                                                                                               |
| Disposable prior-finding PoCs             | **4/4 historical pass**: duplicate address, terminal random, stale queued upgrade after owner transfer, and boundary shadowing |
| Exact-BIPS regression                     | **11/11 pass:** includes 512 fuzz cases plus fixed 3999/4000, 6000, and 9999 boundaries                                        |

The full Forge tree is green after this latest pull. The new tests provide useful regression evidence, but they do not exercise a real signed FDC2 header through `Fdc2Verification` into Relay, a caught failure followed by another verification in the same transaction, or non-override Mode 1 through the new wrapper.

The timelock suite meaningfully covers exact-calldata binding, ETA, permissionless execution, cancellation authorization, requeue delay reset, unknown/already-executed calls, failed-execution atomicity, value rejection, the ERC-7201 layout, UUPS substitution rejection, migration self-calls, and single-use consumption of the execution flag.

### Formal coverage and remaining material gaps

The normalized local formal results now cover `d5af7136…` and the repaired
setter-mode fixtures. They and their passing aggregate bundle are
development-only because the checkout was dirty; the supplemental cloud result
remains PARTIAL. The rebaseline adds dedicated threshold/transient coverage without
removing the pre-existing security gaps.

The remaining material gaps are:

- No committed regression or formal property covers duplicate **addresses** with one key/signature represented at distinct indices.
- No committed regression or formal property covers `type(uint32).max` or an upper future horizon.
- No migration test or property makes `getRandomNumber()` fall back to a seeded old Relay or rehearses every consumer.
- No committed lower/higher initial-policy-start versus read-boundary test or property exists.
- No implementation control or proof invalidates a former owner's queue on transfer, expires stale operations, or invalidates old calldata on implementation change.
- Upgrade preservation now checks owner, timelock duration, source chain, initial-round state, exact implementation/data binding, and a migration value, but it does not snapshot the complete fee/exemption/collector, root/random, oldRelay, and queue state across versions.
- There is no supported `relay-safe-governance` -> `relay-owner-timelock` storage migration test.
- There is no stateful multi-operation invariant that explores arbitrary queue/cancel/owner-transfer/upgrade sequences. The new Halmos checks are bounded scenarios. Certora local is only a front-end/typecheck gate; the current scalar/write-once cloud jobs retain sanity gaps.
- There is no proof or integration test that the threshold argument equals the authenticated FDC2 header, or that a below-50% threshold is coupled to the required cosigner majority.
- Halmos covers `TSTORE`/`TLOAD` cleanup, rollback, address scope, and protocol-ID isolation at bounded scope, while Lean covers the operation/state seam. No deployment gate proves EIP-1153 availability on every mirror target, and Lean does not extract the complete self-call call-frame path.

## Configuration and accepted design risks

The user has accepted the deployment and deployer-transition items as explicit
assumptions for this review. They remain documented because that acceptance is
not evidence of on-chain deployment history, target-chain compatibility, or a
safe cross-version migration.

- All committed home-chain JSON files currently set `timelockDurationSeconds` to `0`; the docs justify this by relying on the upstream Flare governance timelock. That makes every Relay owner setter and UUPS upgrade immediate on the home deployment ([`OwnableWithTimelock.sol:156-164`](../contracts/utils/implementation/OwnableWithTimelock.sol#L156-L164)). The files also contain zero deployment placeholders and fail preflight until completed, so this is an explicit release-configuration approval item rather than a live exploit. Document and test the upstream delay assumption.
- A guarded call returns success both when it applies and when it only queues. Automation must inspect events/ETA and target state, not transaction success alone.
- The current timelock has no independent guardian; cancellation authority is the same owner that proposes operations.
- `verifyCustomSignature` remains a same-source, same-chain cross-deployment signature oracle unless consumers include their own contract address, purpose, and nonce in the message hash.
- FDC2 verification is stateless. Applications must enforce `proofOwner`, timestamp/freshness, expected request identity, and one-time consumption where replay is unsafe; signing an identical proof does not prevent that same proof from being reused.
- `SignedPayload.messageHash` binds the local `block.chainid`. Cross-chain consumers must define whether signers authenticate the source or destination chain and compute the same value explicitly; the current shared helper offers no chain-ID argument.
- A reverting fee collector can deny paid `verify()` calls; pull-payment accounting would decouple verification liveness from recipient behavior.

## Confirmed nonissues in the reviewed implementation

- No current permissionless timelock bypass was found. Only the owner can queue; execution requires the exact calldata hash and ETA; deletion occurs before the self-call; the single-use flag requires `msg.sender == address(this)` and is consumed before the body.
- OpenZeppelin 5.7 exposes only `upgradeToAndCall` on UUPS. Relay overrides that public entry with `onlyOwnerWithTimelock`; the empty `_authorizeUpgrade` is not reachable through an alternate current upgrade entry point.
- `RelayProxy` initializes atomically in its constructor, and the implementation disables initializers.
- `renounceOwnership` is disabled and ownership transfer to zero reverts.
- The signature parser enforces in-range/increasing indices, canonical `v`, low `s`, exact ecrecover output, nonzero recovery, and signer equality with the indexed policy entry. H-01 is specifically about the same address occupying different valid entries.
- `verify()` performs no Relay storage writes. Fee-recipient/refund/old-relay callbacks cannot corrupt Relay state belonging to another invocation.
- Random leaf binding, sorted Merkle folding, zero-root rejection, and monotonic handling of ordinary stale rounds appear sound under a valid policy and nonterminal round.
- The threshold override is read only for protocol ID 1. Direct Mode-1 policy relay and Mode-2 finalization retain the policy threshold, and no persistent storage-layout field or selector collision was introduced.
- The transient slot is explicitly cleared after success; an inner revert rolls the write back. No current external callback was found between setting and consuming the override. The bounded Halmos suite now includes caught-revert rollback and legacy-threshold preservation controls.
- Rejecting `thresholdBIPS == 10000` is correct because Relay accepts only when accumulated weight is strictly greater than the computed threshold.

## Recommended implementation order

1. **P0 — restore consensus and liveness invariants:** reject duplicate/zero policy voters everywhere; reject terminal and excessive-future random rounds; fix cast-before-add.
2. **P0 — make migration coherent:** bind the initial policy metadata to the read boundary and seed/fallback current randomness before cutover.
3. **P0 — make the nonzero FDC2 feature safe:** introduce the proof-aware header/request/cosigner verifier, update the cross-chain flow, and require consumers to use it rather than the raw threshold primitive.
4. **P0 — finish release evidence:** reproduce every passing local constituent and the aggregate bundle from one clean commit, then resolve or explicitly scope the Certora sanity failures before claiming affected cloud properties.
5. **P1 — harden operation lifecycle:** add owner/implementation queue epochs, expiry, global invalidation, and timelocked two-step ownership.
6. **P1 — resolve upgrade provenance:** prove fresh-deployment-only status or implement/test the Safe-to-timelock migration.
7. **P2 — deployment and operations:** reject numeric narrowing, preflight EIP-1153, fill and independently review production owners/collectors/timelocks, and rehearse owner handover plus queue cancellation.

## Review limitations

This was a source and local-test review, not a live-deployment audit. It did not verify on-chain proxy implementations, owners, source registries, upstream governance delay, deployed bytecode hashes, target-chain fork compatibility, or off-chain FDC2 signer behavior. Four earlier disposable Foundry probes reproduced the principal pre-existing issues. L-04 now has committed boundary and differential regressions plus passing local Halmos/Lean/Certora-front-end coverage and a passing scoped Certora threshold job. The local formal reports and aggregate bundle pass but are development-only; the supplemental scalar/write-once cloud evidence remains PARTIAL.
