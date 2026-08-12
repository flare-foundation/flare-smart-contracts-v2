/*
 * Relay.sol — write-once and owner-timelock invariants over verification getters.
 *
 * CVL direct storage access (`currentContract.toSigningPolicyHashPrivate[...]`) depends on the
 * prover's storage analysis, which does not reliably track Relay's raw-assembly stores. These rules
 * use plain-Solidity view getters (certora/harness/RelayHarness.sol) reading the same mappings
 * (visibility-munged private -> internal; faithfulness machine-checked by certora/munge.sh), and the run
 * disables the storage-splitting optimization (-enableStorageSplitting false). Storage then becomes one
 * SMT array and aliasing is decided by the prover's injective hashing model (keccak locations are
 * guaranteed distinct from scalar slots and from each other for distinct keys), so a raw assembly store
 * can no longer spuriously havoc an unrelated mapping entry.
 *
 * ecrecover stays NONDET as an uninterpreted recovery function. During queued execution, the five
 * non-upgrade owner methods pessimistically dispatch to the real current implementation; the fallback ECF
 * summary cannot alter Relay storage. UUPS does use delegatecall; direct upgrade and queued-upgrade
 * dispatch are filtered from preservation/execution rules and treated as the explicit trusted-upgrade
 * boundary documented in certora/README.md.
 *
 * Parametric preservation calls use @withrevert, so calls that revert remain in the method domain and
 * must preserve the sampled mappings after rollback. This includes ABI-dispatched relay(), whose generic
 * zero-argument call supplies only the selector and lacks the required trailing protocol payload, and the
 * deliberately disabled renounceOwnership(). Raw relay payloads are modeled by the dedicated
 * concrete-symbolic and refinement layers within their stated bounds, and renunciation also has a direct
 * rule below.
 */

methods {
    function policyHashAt(uint256) external returns (bytes32) envfree;
    function merkleRootAt(uint256, uint256) external returns (bytes32) envfree;
    function lastInitializedRewardEpochData() external returns (uint32, uint32) envfree;
    function owner() external returns (address) envfree;
    function getTimelockDurationSeconds() external returns (uint256) envfree;
    function timelockedCallTimestampAt(bytes) external returns (uint256) envfree;
    function timelockExecuting() external returns (bool) envfree;
    function signingPolicySetter() external returns (address) envfree;
    function feeCollectionAddress() external returns (address) envfree;
    function sourceChainId() external returns (uint256) envfree;
    function protocolFeeInWei(uint256) external returns (uint256) envfree;
    function feeExemptAddress(address) external returns (bool) envfree;

    unresolved external in RelayHarness.executeTimelockedCall(bytes) => DISPATCH [
        RelayHarness.setProtocolFees(IRelay.FeeConfig[]),
        RelayHarness.setFeeExemptions(IIRelay.FeeExemption[]),
        RelayHarness.setFeeCollectionAddress(address),
        RelayHarness.setSigningPolicySetter(address),
        RelayHarness.setTimelockDuration(uint256)
    ] default HAVOC_ECF;

    unresolved external in _._ => DISPATCH [] default HAVOC_ECF;
}

definition ownerGuarded(method f) returns bool =
    f.selector == 0x1684afe8 /* setProtocolFees((uint8,uint256)[]) */
    || f.selector == 0x37ea4938 /* setFeeExemptions((address,bool)[]) */
    || f.selector == sig:setFeeCollectionAddress(address).selector
    || f.selector == sig:setSigningPolicySetter(address).selector
    || f.selector == sig:setTimelockDuration(uint256).selector
    || f.selector == sig:upgradeToAndCall(address, bytes).selector;

definition nonUpgradeOwnerGuarded(method f) returns bool =
    ownerGuarded(f)
    && f.selector != sig:upgradeToAndCall(address, bytes).selector;

definition preservesCurrentImplementation(method f) returns bool =
    f.selector != 0x1d5226a3 /* initialize((...),address,address,address) */
    && f.selector != sig:upgradeToAndCall(address, bytes).selector
    && f.selector != sig:executeTimelockedCall(bytes).selector;

/// Exact ABI-selector checks over raw calldata. The length guard is load-bearing because CVL gives
/// out-of-bounds array reads an unconstrained value rather than Solidity's reverting semantics.
definition isCanonicalDurationSetterCall(bytes encodedCall) returns bool =
    encodedCall.length == 36
    && encodedCall[0] == to_bytes1(0x15)
    && encodedCall[1] == to_bytes1(0x0f)
    && encodedCall[2] == to_bytes1(0xea)
    && encodedCall[3] == to_bytes1(0x09);

definition isNonUpgradeOwnerGuardedCall(bytes encodedCall) returns bool =
    encodedCall.length >= 4
    && (
        (
            encodedCall[0] == to_bytes1(0x16)
            && encodedCall[1] == to_bytes1(0x84)
            && encodedCall[2] == to_bytes1(0xaf)
            && encodedCall[3] == to_bytes1(0xe8)
        ) /* setProtocolFees((uint8,uint256)[]) */
        || (
            encodedCall[0] == to_bytes1(0x37)
            && encodedCall[1] == to_bytes1(0xea)
            && encodedCall[2] == to_bytes1(0x49)
            && encodedCall[3] == to_bytes1(0x38)
        ) /* setFeeExemptions((address,bool)[]) */
        || (
            encodedCall[0] == to_bytes1(0xb8)
            && encodedCall[1] == to_bytes1(0xcc)
            && encodedCall[2] == to_bytes1(0x76)
            && encodedCall[3] == to_bytes1(0xfb)
        ) /* setFeeCollectionAddress(address) */
        || (
            encodedCall[0] == to_bytes1(0x42)
            && encodedCall[1] == to_bytes1(0xc3)
            && encodedCall[2] == to_bytes1(0xf2)
            && encodedCall[3] == to_bytes1(0x37)
        ) /* setSigningPolicySetter(address) */
        || (
            encodedCall[0] == to_bytes1(0x15)
            && encodedCall[1] == to_bytes1(0x0f)
            && encodedCall[2] == to_bytes1(0xea)
            && encodedCall[3] == to_bytes1(0x09)
        ) /* setTimelockDuration(uint256) */
    );

/// A finalized signing-policy hash is WRITE-ONCE: once an epoch's hash is set (non-zero) it is never
/// overwritten or cleared by any function — finalized policies cannot be tampered.
///
/// REACHABLE-STATE LINK (documented assumption): the rule quantifies over arbitrary pre-states, including
/// the unreachable combination "hash[epoch] != 0 while lastInitializedRewardEpoch < epoch", from which
/// setSigningPolicy(epoch) may legitimately (re)write epoch's hash (its gate only enforces
/// rewardEpochId == lastInitialized + 1). On every REACHABLE state a non-zero hash exists only for epochs
/// <= lastInitializedRewardEpoch (the constructor seeds the initial epoch and every writer — the setter and
/// relay() Mode-1 alike — writes exactly lastInitialized+1, then advances the pointer). The require below
/// restricts the rule to states satisfying that reachable-state link.
rule policyHashWriteOnce(method f, uint256 epoch)
filtered { f -> preservesCurrentImplementation(f) }
{
    bytes32 pre = policyHashAt(epoch);
    require pre != to_bytes32(0);
    uint32 lastInit; uint32 _startRound;
    lastInit, _startRound = lastInitializedRewardEpochData();
    require to_mathint(epoch) <= to_mathint(lastInit);
    env e; calldataarg args;
    currentContract.f@withrevert(e, args);
    bytes32 post = policyHashAt(epoch);
    assert post == pre, "a finalized signing-policy hash must be write-once";
}

/// A finalized Merkle root is WRITE-ONCE per (protocolId, votingRoundId): once set it is never changed —
/// a relayed finalization cannot be silently rewritten by a later call.
rule merkleRootWriteOnce(method f, uint256 protocolId, uint256 votingRoundId)
filtered { f -> preservesCurrentImplementation(f) }
{
    bytes32 pre = merkleRootAt(protocolId, votingRoundId);
    require pre != to_bytes32(0);
    env e; calldataarg args;
    currentContract.f@withrevert(e, args);
    bytes32 post = merkleRootAt(protocolId, votingRoundId);
    assert post == pre, "a finalized Merkle root must be write-once";
}

/// At an external transaction boundary, no non-owner can enter any of Relay's
/// six owner-timelocked mutation entry points. The `executing == false`
/// assumption is the reachable-state boundary: it is only true transiently
/// during executeTimelockedCall's self-call.
rule onlyOwnerCanEnterGuardedSurface(method f)
filtered { f -> ownerGuarded(f) }
{
    env e; calldataarg args;
    require !timelockExecuting();
    require e.msg.sender != owner();
    currentContract.f@withrevert(e, args);
    assert lastReverted, "a non-owner must not enter an owner-timelocked method";
}

/// With a positive delay, a successful non-upgrade owner call cannot apply any sampled Relay mutation in
/// that transaction. This rule does not observe the generic call's exact calldata/queue entry; queue
/// creation is covered separately by the concrete and Halmos timelock harnesses.
rule delayedOwnerCallDoesNotApply(method f, uint256 protocolId, address account)
filtered { f -> nonUpgradeOwnerGuarded(f) }
{
    address preOwner = owner();
    uint256 preDuration = getTimelockDurationSeconds();
    address preSetter = signingPolicySetter();
    address preCollector = feeCollectionAddress();
    uint256 preSource = sourceChainId();
    uint256 preFee = protocolFeeInWei(protocolId);
    bool preExempt = feeExemptAddress(account);
    require preOwner != 0;
    require preDuration > 0;
    require !timelockExecuting();

    env e; calldataarg args;
    require e.msg.sender == preOwner;
    require e.msg.value == 0;
    currentContract.f(e, args);

    assert owner() == preOwner, "a delayed owner call must not change owner";
    assert getTimelockDurationSeconds() == preDuration, "a delayed owner call must not change duration";
    assert signingPolicySetter() == preSetter, "a delayed owner call must not change setter";
    assert feeCollectionAddress() == preCollector, "a delayed owner call must not change fee recipient";
    assert sourceChainId() == preSource, "a delayed owner call must not change source domain";
    assert protocolFeeInWei(protocolId) == preFee, "a delayed owner call must not change protocol fees";
    assert feeExemptAddress(account) == preExempt, "a delayed owner call must not change exemptions";
}

/// A successful non-upgrade execution consumes exactly the queue entry whose calldata was
/// supplied and never leaves the self-call authorization bit set. A positive selector allowlist
/// excludes UUPS, recursive execution and arbitrary calldata: this direct-implementation harness
/// cannot soundly model replacement-code or migration-data effects in proxy storage.
rule successfulExecutionConsumesQueue(env e, bytes encodedCall) {
    require isNonUpgradeOwnerGuardedCall(encodedCall);
    require !timelockExecuting();
    require e.msg.value == 0;
    uint256 preTimestamp = timelockedCallTimestampAt(encodedCall);
    require preTimestamp != 0;
    require e.block.timestamp >= preTimestamp;
    uint256 preDuration = getTimelockDurationSeconds();
    require preDuration <= 604800;
    executeTimelockedCall@withrevert(e, encodedCall);
    bool reverted = lastReverted;
    uint256 postTimestamp = timelockedCallTimestampAt(encodedCall);
    bool postExecuting = timelockExecuting();
    uint256 postDuration = getTimelockDurationSeconds();
    satisfy !reverted
        && isCanonicalDurationSetterCall(encodedCall)
        && postDuration != preDuration
        && postDuration <= 604800,
        "a real duration-setter self-call must witness successful queue execution";
    assert reverted || postTimestamp == 0, "successful execution must consume the queued call";
    assert reverted || !postExecuting, "execution authorization must not persist";
}

/// The duration setter either reverts or leaves a value within the hard cap.
rule successfulDurationUpdateIsBounded(env e, uint256 newDuration) {
    uint256 pre = getTimelockDurationSeconds();
    bool preExecuting = timelockExecuting();
    address preOwner = owner();
    require pre <= 604800;
    setTimelockDuration@withrevert(e, newDuration);
    bool reverted = lastReverted;
    uint256 post = getTimelockDurationSeconds();
    satisfy !preExecuting
        && preOwner != 0
        && e.msg.sender == preOwner
        && e.msg.value == 0
        && pre == 0
        && !reverted
        && newDuration <= 604800
        && post == newDuration
        && post != pre,
        "an owner must have an immediate, applied duration-mutation witness";
    assert reverted || post <= 604800, "a successful duration update must respect the seven-day cap";
}

/// Relay deliberately disables the destructive Ownable renounce path.
rule ownershipRenounceAlwaysReverts(env e) {
    renounceOwnership@withrevert(e);
    assert lastReverted, "renounceOwnership must always revert";
}
