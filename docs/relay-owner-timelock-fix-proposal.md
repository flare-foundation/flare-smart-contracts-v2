# Relay owner/timelock fix proposal

**Target branch:** `relay-owner-timelock`
**Reviewed source:** `d5af7136c03d6bab83307b0f4bd49101b8792e40`
**Status:** package 5's exact BIPS arithmetic is implemented in the current working tree; all other packages remain design proposals. Formal evidence has not yet been regenerated.

This proposal turns the findings in [`relay-owner-timelock-security-review.md`](relay-owner-timelock-security-review.md) into implementation packages. The ordering deliberately fixes the contract invariants before regenerating formal evidence.

## Release decisions

| Priority | Package                                       | Release condition                                                                                                                                                             |
| -------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P0       | Policy identity and initial-policy validation | No zero/duplicate voter can enter through initialization, the trusted setter, or Mode 1; an upgraded legacy policy must be revealed and validated before use                  |
| P0       | Random-number liveness and migration          | Future rounds are bounded, terminal rounds are impossible, timestamp arithmetic cannot overflow, and current randomness falls back to the old Relay until a local root exists |
| P0       | Safe FDC2 nonzero-threshold flow              | Threshold, request, proof owner, freshness/replay policy, and cosigner policy are bound atomically; typical consumers no longer call the raw primitive                        |
| P0       | Threshold arithmetic                          | The implemented comparison exactly matches the documented BIPS predicate, including non-divisible totals and values near 10000                                                |
| P0       | Formal rebaseline                             | Every proof input binds this implementation; invalid fixtures are repaired; the new paths have explicit obligations; the clean aggregate bundle passes                        |
| P1       | Timelock lifecycle                            | Owner rotation and implementation upgrades invalidate old operations; operations expire; cancellation of all pending intent is O(1)                                           |
| P1       | Deployment and upgrade compatibility          | Numeric narrowing is rejected; EIP-1153 is preflighted; any Safe-to-owner upgrade is either prohibited by evidence or implemented through a tested bridge                     |

## 1. Enforce voter identity uniqueness

### Contract changes

Add custom errors such as:

```solidity
error SigningPolicyVoterZero(uint256 index);
error SigningPolicyVoterDuplicate(address voter, uint256 firstIndex, uint256 secondIndex);
```

Create one high-level validator used by initialization and `setSigningPolicy`:

```solidity
function _validateSigningPolicy(SigningPolicy memory policy) internal pure {
    uint256 count = policy.voters.length;
    require(count != 0 && count <= MAX_VOTERS, ...);
    require(count == policy.weights.length, ...);

    uint256 totalWeight;
    for (uint256 i; i < count; ++i) {
        address voter = policy.voters[i];
        if (voter == address(0)) revert SigningPolicyVoterZero(i);
        for (uint256 j; j < i; ++j) {
            if (policy.voters[j] == voter) {
                revert SigningPolicyVoterDuplicate(voter, j, i);
            }
        }
        totalWeight += policy.weights[i];
    }
    // Existing total-weight and threshold consistency checks follow.
}
```

Do not require address sorting unless the upstream registry contractually guarantees that ordering. A bounded pairwise check runs only once per policy epoch and avoids changing the policy wire format.

Add the equivalent calldata validator to the Mode-1 assembly before the new policy hash or state is stored. For voter `i`, load its 20-byte address from the `43 + i * 22` entry, reject zero, and compare it with entries `0..i-1`. `MAX_VOTERS == 300`, so the worst case is bounded.

The initial policy must also be validated; accepting only its opaque hash leaves the original bypass intact. See package 2.

For an already-deployed implementation whose stored policy hash predates validation, require a one-time full-policy reveal that:

1. recomputes the source-bound hash;
2. matches it to the stored hash;
3. validates identities, weights, threshold, epoch, and start round; and
4. marks that epoch validated before `relay()` can consume it.

Also reject a recovered signer address that has already contributed weight at an earlier supplied index. This runtime backstop is required while a legacy, hash-only policy can still be active and remains useful defense in depth after all policy admission paths are repaired. With 300 signatures, the simple pairwise form is bounded to 44,850 address comparisons. A future optimized representation is acceptable only if it cannot collide or alias identities.

### Required tests/proofs

- Setter, initial reveal, and Mode-1 tests for zero and duplicate addresses.
- Repeat the same `(v,r,s)` at two valid increasing indices and require rejection.
- Cover duplicates at the first/last positions and non-adjacent positions at `MAX_VOTERS` bounds.
- Prove accepted signature weight is the sum of distinct signer identities, not merely distinct indices.

## 2. Replace opaque initial-policy configuration

### Preferred fresh-deployment ABI

Replace the independent initial hash/epoch/start fields with the complete policy:

```solidity
struct RelayInitialConfigV2 {
  SigningPolicy initialSigningPolicy;
  // Existing timing, random, fee, source-chain and timelock fields.
}
```

During `initialize`:

1. validate `sourceChainId` and timing parameters;
2. call `_validateSigningPolicy(initialSigningPolicy)`;
3. derive `initialRewardEpochId` and `startingVotingRoundIdForInitialRewardEpochId` from that policy;
4. recompute the exact source-bound policy hash on-chain; and
5. store all three values atomically.

There should be no separately supplied boundary capable of disagreeing with the policy metadata. Deployment tooling must export the complete policy snapshot and independently compare its locally calculated hash with the on-chain result.

### Upgrade-compatible alternative

If the initializer ABI cannot change, add a one-time `reinitializer`/reveal step that accepts the encoded initial policy and requires:

```text
calculatedSourceBoundHash == storedInitialHash
policy.rewardEpochId      == initialRewardEpochId
policy.startVotingRoundId == startingVotingRoundIdForInitialRewardEpochId
```

The proxy must not be activated in registries until this reveal succeeds. A mismatch is a deployment failure, not a value to normalize silently.

## 3. Bound future random rounds and make the getter total

### Arithmetic fix

Cast before adding:

```solidity
uint256 round = uint256(stateData.randomVotingRoundId);
_randomTimestamp = stateData.firstVotingRoundStartTs
    + (round + 1) * stateData.votingEpochDurationSeconds;
```

Apply the same cast-before-add convention to every round/timestamp helper.

### Acceptance bound

First impose the structural protocol bound before accepting any Mode-2 message:

```solidity
require(
    messageRewardEpochId <= uint256(stateData.lastInitializedRewardEpoch) + 1,
    RewardEpochTooFarInFuture()
);
```

This retains the intended next-uninitialized-epoch path and rejects arbitrarily distant rounds. Prefer adding a second, explicit `maxFutureVotingRounds` wall-clock bound for the configured random protocol, stored in a new append-only slot rather than changing the packed `StateData` getter. Compute all additions in `uint256`:

```solidity
uint256 currentRound = block.timestamp <= firstVotingRoundStartTs
    ? 0
    : (block.timestamp - firstVotingRoundStartTs) / votingEpochDurationSeconds;

require(votingRoundId != type(uint32).max, TerminalVotingRound());
require(votingRoundId <= currentRound + maxFutureVotingRounds, VotingRoundTooFarInFuture());
```

The maximum must be reviewed against legitimate pre-finalization behavior. It must not be derived solely from signer authority: the purpose is to prevent a current quorum from creating permanent future state.

### Liveness invariants

- Every accepted current-random pointer is readable without revert.
- Every accepted future pointer eventually becomes non-future under advancing time.
- A later valid round can replace every stored pointer.
- `uint32.max` and a far-future `uint32.max - 1` both reject without changing roots, random value, or pointer; an injected legacy max pointer cannot make the getter overflow.

## 4. Preserve current randomness during migration

Use finalized-root presence, not random value zero, to decide whether local current randomness exists:

```solidity
function _hasLocalCurrentRandom() internal view returns (bool) {
    uint256 round = stateData.randomVotingRoundId;
    return merkleRootsPrivate[stateData.randomNumberProtocolId][round] != bytes32(0);
}

function getRandomNumber() external view returns (...) {
    if (address(oldRelay) != address(0) && !_hasLocalCurrentRandom()) {
        return oldRelay.getRandomNumber();
    }
    return _getLocalRandomNumber();
}
```

This correctly handles a legitimate random value of zero and a locally finalized round zero. Add `hasLocalCurrentRandom()` as an operational readiness getter and make registry cutover require either a secure local random or a working old-Relay fallback.

If a zero Merkle root is ever valid, append an explicit `hasLocalCurrentRandom` bit and set it atomically after a successful random proof; do not overload either the random value or round number as the sentinel. Existing deployments can initialize that bit from a nonzero stored root during the upgrade.

Every consumer must explicitly require `_isSecureRandom` unless its insecure behavior is documented and tested.

## 5. Make the BIPS comparison exact

**Implementation status:** fixed in the current working tree. Concrete boundary and differential fuzz tests pass; source-bound formal reports remain stale until the complete rebaseline in package 11.

The intended predicate should be written directly:

```text
signedWeight * 10000 > totalWeight * thresholdBIPS
```

All operands are tightly bounded, so the products cannot approach `uint256` overflow. In the existing loop this can be implemented either as a separate override comparison or as:

```solidity
effectiveThreshold = (totalWeight * thresholdBIPS) / 10000; // floor
accept iff signedWeight > effectiveThreshold;
```

Remove the `+ 9999` ceiling term. Zero continues to select the policy threshold; `thresholdBIPS >= 10000` continues to fail fast. This guarantees that all signers satisfy every nonzero value below 10000 when total weight is nonzero.

If the stronger ceiling-plus-strict rule is a deliberate product decision, rename/document the parameter accordingly and validate `roundedThreshold < totalWeight`. The Hub and off-chain aggregator must then use that exact rule before charging a non-refundable request fee.

Required differential tests cover all totals `1..65535`, BIPS `0, 1, 4999, 5000, 9999, 10000`, divisible/non-divisible products, and the exact equality boundary.

## 6. Add a proof-aware FDC2 verifier

Keep `Relay.verifyCustomSignatureWithThreshold` explicitly documented as a low-level cryptographic primitive. Do not direct applications to call it or the current pass-through as a complete FDC2 policy check.

### Bind a response to independent request state

Add a V2 response header containing `sourceChainId`, `sourceHub`, and `requestId` in addition to the existing response fields. Add a request commitment that is available to the consuming application. On the source chain, store it in FDC2 Hub under a domain-separated key such as `keccak256(abi.encode(FDC2_REQUEST_DOMAIN, sourceChainId, sourceHub, requestId))`; on a mirror, import the same commitment through an independent normal-quorum/bridge path.

Prefer a new `requestAttestationV2`. Allocate its request ID before dispatch from an appended nonce, include that exact ID and the source domain/deadline in the instruction sent to the TEE, require its mapping slot to be empty, and store the commitment before the external dispatch. All writes then roll back if dispatch fails. This is safer than relying on an identifier generated or returned only after the external call and avoids silently changing V1 return behavior.

The committed request record should contain at least:

```solidity
struct ExpectedFdc2Request {
  bytes32 requestId;
  address sourceHub;
  bytes32 attestationType;
  bytes32 sourceId;
  bytes32 requestBodyHash;
  bytes32 teePolicyHash;
  uint16 thresholdBIPS;
  address proofOwner;
  bytes32 cosignerSetHash;
  uint64 cosignersThreshold;
  uint64 createdAt;
  uint64 validUntil;
  address requester;
  uint256 sourceChainId;
  uint8 verificationMode;
  bool revoked;
}
```

The expected structure must come from application storage or an authenticated cross-chain request commitment. Deriving the threshold only from the response being verified is circular: a smaller signer subset could otherwise sign a different header containing a smaller threshold.

### Safe helper flow

For each typed proof, the shared library should:

1. compare the response header/request body to the stored `ExpectedFdc2Request`;
2. hash the actual header, request body, and response body internally;
3. compute the signed payload using the expected **source** chain ID;
4. call Relay with `expected.thresholdBIPS`, never a free caller value;
5. validate the recovered reward epoch is current or previous;
6. verify the request-time TEE/signing-policy mode and the exact resolved TEE/cosigner policies, including the below-50% majority rule;
7. optionally apply the current cosigner set as a separate revocation overlay, rather than substituting it for request-time authorization;
8. require the expected proof owner and freshness window; and
9. mark the request/proof identifier consumed before application side effects.

Hub admission should also reject zero or duplicate cosigners, cap the set length, and require `(cosigners.length == 0) == (cosignersThreshold == 0)`. For a nonzero threshold below 5000 BIPS, preserve the existing strict-majority requirement against the exact request-time cosigner set. Commit whether the request permits `TeeOnly`, `SigningPolicyOnly`, or `Either`; the presence of a signature array must never let the prover select a weaker mode. Bound request TTL and clock skew, and require `createdAt <= responseTimestamp <= validUntil`, `responseTimestamp <= block.timestamp + MAX_CLOCK_SKEW`, and `block.timestamp <= validUntil` after ordering checks.

Add a pure source-aware helper:

```solidity
function messageHashForChain(bytes32 prefix, uint256 sourceChainId, bytes32 dataHash) internal pure returns (bytes32);
```

The existing local helper can call it with `block.chainid`. A mirror consumer should use `IRelay(relay).sourceChainId()` and compare it with the request commitment.

### Compatibility and rollout

- Existing in-tree consumers that require `thresholdBIPS == 0` can remain on the V1 policy-threshold helper.
- Introduce a new versioned helper/interface for nonzero thresholds; do not silently alter the semantics of deployed consumers.
- If a mirror has no authenticated request-commitment registry, disallow nonzero thresholds there rather than trusting caller-supplied expected state.
- For state-changing consumers, key consumption by consumer and domain request ID, set it before effects, and reject a second or alternate response for the same request. Keep a non-consuming helper only for explicitly read-only/idempotent use.
- Before upgrading FDC2 Hub, require stored `minThresholdBIPS < 10000`. If it equals 10000 under old state, governance must lower it first or an atomic `upgradeToAndCall` migration must do so. The one-shot reinitializer must authorize the proxy self-call (`msg.sender == address(this)`), not nest `onlyGovernance`: the production governance wrapper has already consumed its execution authorization before the delegatecall. Require the exact legacy value, validate the replacement range, and test the real timelock-to-upgrade path.
- Add an end-to-end source-chain != destination-chain test and request/cosigner rotation tests.

## 7. Bind timelocked operations to authority and code context

Append a new ERC-7201 state version; do not reinterpret existing mapping values in place:

```solidity
struct Operation {
  uint64 validAfter;
  uint64 validUntil;
}

struct StateV2 {
  uint64 queueEpoch;
  bytes32 executingCallHash;
  mapping(bytes32 operationId => Operation) operations;
}
```

Calculate the operation ID as:

```solidity
keccak256(abi.encode(
    block.chainid,
    address(this),
    owner(),
    queueEpoch,
    keccak256(encodedCall)
));
```

Increment `queueEpoch` on:

- completed ownership transfer;
- every successful implementation upgrade;
- an explicit `invalidateAllTimelockedCalls()`; and
- any governance-mode migration that changes interpretation of guarded calldata.

Set `validUntil = validAfter + executionGracePeriod` and reject expired operations. Replacing the generic boolean with the exact `executingCallHash` ensures that only the queued self-call can consume the one-shot authorization.

The minimum safe ownership change is a timelocked proposal plus epoch invalidation. Prefer `Ownable2Step`: the current owner proposes through the timelock, the pending owner accepts, and actual transfer bumps the epoch. Old mapping entries may remain physically stored but become unreachable in O(1).

## 8. Validate deployment input before narrowing

Parse every JSON integer into `uint256`, validate it, then cast:

```solidity
uint256 rawProtocolId = vm.parseJsonUint(json, path);
require(rawProtocolId > 1 && rawProtocolId <= type(uint8).max, "invalid protocol id");
uint8 protocolId = uint8(rawProtocolId);
```

Apply this pattern to every `uint8`, `uint16`, `uint24`, and `uint32` snapshot field. Add matching JSON-schema minima/maxima and one-overflow tests for each destination type.

## 9. Decide the EIP-1153 support boundary

The lowest-risk option for the current implementation is to keep transient storage and make Cancun support an explicit deployment prerequisite:

- execute a `TSTORE`/`TLOAD` smoke in the implementation constructor so deployment itself fails on an unsupported runtime;
- perform an RPC/fork `TSTORE`/`TLOAD` probe for every home and mirror target;
- record chain ID, block number, client, and result in the deployment artifact;
- reject deployment/upgrade when the probe fails; and
- retain a same-transaction caught-revert cleanup test.

If arbitrary pre-Cancun mirrors are required, prefer a dedicated protocol-1 verifier that receives the threshold as an ordinary argument and shares a parameterized parser/signature loop with `relay()`. That refactor is higher risk and requires byte-for-byte differential fuzzing for every non-override path.

An append-only persistent scratch slot is a compatibility fallback only after explicit review: require it to be zero on entry, set it immediately before the inner verification call, clear it on success, and add a reentrancy guard. A reverted call rolls the write back, but this design remains safe only while protocol 1 has no arbitrary callback. Document that invariant and cover caught-revert, nested-call, and upgrade-storage-layout cases. It costs an `SSTORE`/clear pair per nonzero-threshold verification.

## 10. Resolve Safe-to-owner upgrade compatibility

Preferred resolution: prove from deployment inventories and on-chain bytecode that no `relay-safe-governance` proxy exists, and encode “fresh deployment only” as a deployment precondition.

If any proxy exists, use a dedicated bridge release rather than a direct upgrade. The atomic `upgradeToAndCall` migration must:

1. read and validate the old Safe-governance source-chain value;
2. initialize a nonzero owner and reviewed timelock duration;
3. copy the source ID into the new Relay field;
4. invalidate old governance/queue intent;
5. preserve all Relay roots, policies, fees, randomness, and migration pointers; and
6. be proved and rehearsed against the exact old deployed bytecode/storage layout.

The one-shot migration entry point must be callable only from the expected proxy upgrade context. In production the queued owner operation self-calls `upgradeToAndCall`, so the delegatecalled reinitializer sees `msg.sender == address(this)` after the timelock authorization has already been consumed; nesting the normal owner/timelock modifier would incorrectly queue or revert again.

## 11. Formal and regression rebaseline

Repair formal inputs before interpreting any solver result:

1. Repair all 18 affected Halmos obligations: the valid setter-mode constructor and the five shared setter-mode harnesses must set `feeCollectionAddress = 0`. The affected split is Constructor 6, Access Control 2, Epoch Advance 3, Threshold Consistency 3, Finalization Window 2, and Must-Use-New-Policy 2. Add separate constructor rejection properties for a nonzero collector, nonempty fee configuration, and nonempty fee exemptions; the repaired valid-deploy control supplies non-vacuity.
2. Add `RelayThresholdOverrideFV.t.sol` properties for `>=10000` rejection, zero-sentinel equivalence, lower/higher exact boundaries, protocol-ID isolation, success clearing, caught-revert rollback followed by a legacy call in the same transaction, and transient-slot address scoping. There is no reachable arbitrary external callback in the current protocol-1 path, so do not claim a reentrancy proof that the implementation cannot exercise. Freeze these statements against the implemented exact BIPS semantics.
3. Use a minimum explicit inventory of 10 new threshold proofs and 5 reachability controls, plus 3 constructor rejection proofs. Starting from 103 = 72 proofs + 31 controls, that produces 121 = 85 + 36. Add at least one duplicate-identity rejection proof and one unique-policy reach control with the H-01 fix, for a minimum final inventory of 123 = 86 + 37; additional ingress-specific checks increase these counts and must be manifested explicitly.
4. Add a Lean protocol-ID-1 refinement bridge from transiently selected BIPS to the exact threshold comparison; regenerate optimized Yul and every line anchor. Prefer a separate transient-layer file for same-slot round-trip, zero clear, and contract-address isolation. Leave revert rollback to Halmos unless the Lean call-frame model actually proves it.
5. Remunge current Relay/interfaces for Certora, include the new method in the exact method inventory, and add persistent-state purity plus functional threshold/request-binding rules rather than relying only on generic invariants. Do not let the new self-call resolve to a `HAVOC` summary over Relay storage; if Certora cannot model the transient slot faithfully, state that boundary and leave the functional transient-state proof to Halmos and the arithmetic/dispatch bridge to Lean.
6. Add concrete end-to-end FDC2 tests, future/random migration tests, timelock generation/expiry sequences, and deployment overflow tests.
7. Update the manifest with every new proof and reachability ID, then regenerate deployment provenance, custom-error ABI, artifact parity, Halmos, Lean, Certora local/cloud, and the aggregate bundle from one clean commit.

## Suggested implementation sequence

1. Land packages 1–5 together because policy admission, initial metadata, randomness, and threshold semantics affect the same Relay assembly/proof surface.
2. Land the proof-aware FDC2 interface and update off-chain producers/consumers before enabling any nonzero request threshold.
3. Land timelock V2 and deployment preflights with explicit upgrade rehearsals.
4. Freeze production source, regenerate every formal artifact, and require a clean release-eligible bundle.

Do not regenerate formal reports between partially landed packages and present them as final evidence; the proof object changes again at each step.
