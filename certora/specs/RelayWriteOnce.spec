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
 * cannot spuriously havoc an unrelated mapping entry.
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

// Persistent opcode observations survive an expected Solidity revert. The
// token-fee rules reset these ghosts immediately before invoking verify(), so
// they describe only external CALLs attempted by that verification.
persistent ghost bool feeVerificationCallTouched;
persistent ghost address feeVerificationCallTarget;
persistent ghost uint256 feeVerificationCallValue;

hook CALL(
    uint256 gasAmount,
    address target,
    uint256 value,
    uint256 argsOffset,
    uint256 argsLength,
    uint256 retOffset,
    uint256 retLength
) uint256 result {
    if (executingContract == currentContract) {
        feeVerificationCallTouched = true;
        feeVerificationCallTarget = target;
        feeVerificationCallValue = value;
    }
}

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
    function protocolFee(uint256) external returns (uint256) envfree;
    function feeToken() external returns (address) envfree;
    function feeProtocolIdInSet(uint256) external returns (bool) envfree;
    function feeExemptAddress(address) external returns (bool) envfree;
    function oldRelay() external returns (address) envfree;

    unresolved external in RelayHarness.executeTimelockedCall(bytes) => DISPATCH [
        RelayHarness.setProtocolFees(address, IRelay.FeeConfig[]),
        RelayHarness.setFeeExemptions(IIRelay.FeeExemption[]),
        RelayHarness.setFeeCollectionAddress(address),
        RelayHarness.setSigningPolicySetter(address),
        RelayHarness.setTimelockDuration(uint256)
    ] default HAVOC_ECF;

    unresolved external in _._ => DISPATCH [] default HAVOC_ECF;
}

definition ownerGuarded(method f) returns bool =
    f.selector == 0xc00dbe0c /* setProtocolFees(address,(uint8,uint256)[]) */
    || f.selector == 0x37ea4938 /* setFeeExemptions((address,bool)[]) */
    || f.selector == sig:setFeeCollectionAddress(address).selector
    || f.selector == sig:setSigningPolicySetter(address).selector
    || f.selector == sig:setTimelockDuration(uint256).selector
    || f.selector == sig:upgradeToAndCall(address, bytes).selector;

definition nonUpgradeOwnerGuarded(method f) returns bool =
    ownerGuarded(f)
    && f.selector != sig:upgradeToAndCall(address, bytes).selector;

definition preservesCurrentImplementation(method f) returns bool =
    f.selector != 0xa64ad51b /* initialize((...),address,address,address) */
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
            encodedCall[0] == to_bytes1(0xc0)
            && encodedCall[1] == to_bytes1(0x0d)
            && encodedCall[2] == to_bytes1(0xbe)
            && encodedCall[3] == to_bytes1(0x0c)
        ) /* setProtocolFees(address,(uint8,uint256)[]) */
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

/// The fee enumeration and fee mapping remain in lockstep for a sampled
/// protocol across every direct current-implementation transition. The
/// precondition is the reachable-state link established by
/// initialize/_setProtocolFees. Successful allowlisted non-upgrade execution is
/// covered by successfulNonUpgradeExecutionPreservesRelayInvariants.
rule feeTableMappingSetLockstepPreserved(method f, uint256 protocolId)
filtered { f -> preservesCurrentImplementation(f) }
{
    uint256 preFee = protocolFee(protocolId);
    bool preMember = feeProtocolIdInSet(protocolId);
    require (preFee != 0) <=> preMember;

    env e; calldataarg args;
    currentContract.f@withrevert(e, args);

    uint256 postFee = protocolFee(protocolId);
    bool postMember = feeProtocolIdInSet(protocolId);
    assert (postFee != 0) <=> postMember,
        "fee mapping and protocol-id enumeration must remain in lockstep";
}

/// Reserved protocol ids 0 and 1 cannot acquire a verification fee or appear
/// in the fee enumeration. The precondition is their initialized state.
rule reservedProtocolFeesRemainUnset(method f)
filtered { f -> preservesCurrentImplementation(f) }
{
    require protocolFee(0) == 0;
    require protocolFee(1) == 0;
    require !feeProtocolIdInSet(0);
    require !feeProtocolIdInSet(1);

    env e; calldataarg args;
    currentContract.f@withrevert(e, args);

    assert protocolFee(0) == 0 && !feeProtocolIdInSet(0),
        "protocol id zero must remain absent from the fee table";
    assert protocolFee(1) == 0 && !feeProtocolIdInSet(1),
        "protocol id one must remain absent from the fee table";
}

/// At a clean zero-delay boundary, setter mode rejects the real
/// setProtocolFees ABI for every token and fee-table argument.
rule immediateSetterModeProtocolFeeUpdateReverts(method f)
filtered { f -> f.selector == 0xc00dbe0c }
{
    address currentOwner = owner();
    require currentOwner != 0;
    require signingPolicySetter() != 0;
    require getTimelockDurationSeconds() == 0;
    require !timelockExecuting();

    env e; calldataarg args;
    require e.msg.sender == currentOwner;
    require e.msg.value == 0;
    currentContract.f@withrevert(e, args);
    assert lastReverted, "setter mode must reject protocol-fee configuration";
}

/// The real fee setter has a reachable immediate relay-mode execution that
/// changes the configured payment token. This is an explicit non-vacuity
/// witness for the current ABI and the token/table update path.
rule immediateProtocolFeeUpdateCanApply(
    env e,
    address nextToken,
    IRelay.FeeConfig[] nextFees
) {
    address currentOwner = owner();
    address preToken = feeToken();
    require currentOwner != 0;
    require signingPolicySetter() == 0;
    require getTimelockDurationSeconds() == 0;
    require !timelockExecuting();
    require nextToken != preToken;
    require nextFees.length == 0;

    require e.msg.sender == currentOwner;
    require e.msg.value == 0;
    setProtocolFees@withrevert(e, nextToken, nextFees);
    satisfy !lastReverted && feeToken() != preToken,
        "an immediate relay-mode fee-token update must be reachable";
}

/// Token mode rejects attached native value before attempting any external
/// call, independently of Merkle-root and proof contents.
rule tokenModeRejectsNativeValueBeforeExternalCall(
    env e,
    uint256 protocolId,
    uint256 votingRoundId,
    bytes32 leaf,
    bytes32[] proof
) {
    require oldRelay() == 0;
    require feeToken() != 0;
    require protocolId > 1;
    require e.msg.value > 0;

    feeVerificationCallTouched = false;
    feeVerificationCallTarget = 0;
    feeVerificationCallValue = 0;
    verify@withrevert(e, protocolId, votingRoundId, leaf, proof);

    assert lastReverted, "token-mode verify must reject attached native value";
    assert !feeVerificationCallTouched,
        "token-mode value rejection must happen before an external call";
}

/// An unfinalized token-mode request cannot reach the ERC-20 call. The raw
/// harness getter avoids delegation and protocol gating in this precondition.
rule tokenModeUnfinalizedVerificationDoesNotCallToken(
    env e,
    uint256 protocolId,
    uint256 votingRoundId,
    bytes32 leaf,
    bytes32[] proof
) {
    require oldRelay() == 0;
    require feeToken() != 0;
    require protocolId > 1;
    require e.msg.value == 0;
    require merkleRootAt(protocolId, votingRoundId) == to_bytes32(0);

    feeVerificationCallTouched = false;
    feeVerificationCallTarget = 0;
    feeVerificationCallValue = 0;
    verify@withrevert(e, protocolId, votingRoundId, leaf, proof);

    assert lastReverted, "verification against an unfinalized root must revert";
    assert !feeVerificationCallTouched,
        "an unfinalized request must not attempt an ERC-20 fee call";
}

/// With an empty proof, a leaf different from the nonzero finalized root is
/// invalid. Token collection remains after this proof check.
rule tokenModeInvalidEmptyProofDoesNotCallToken(
    env e,
    uint256 protocolId,
    uint256 votingRoundId,
    bytes32 leaf,
    bytes32[] proof
) {
    bytes32 root = merkleRootAt(protocolId, votingRoundId);
    require oldRelay() == 0;
    require feeToken() != 0;
    require protocolId > 1;
    require e.msg.value == 0;
    require root != to_bytes32(0);
    require proof.length == 0;
    require leaf != root;

    feeVerificationCallTouched = false;
    feeVerificationCallTarget = 0;
    feeVerificationCallValue = 0;
    verify@withrevert(e, protocolId, votingRoundId, leaf, proof);

    assert lastReverted, "an invalid empty Merkle proof must revert";
    assert !feeVerificationCallTouched,
        "an invalid proof must not attempt an ERC-20 fee call";
}

/// A non-exempt token-mode request with an empty proof whose leaf equals the
/// finalized root reaches a zero-native-value CALL to the configured token.
/// ERC-20 balance-delta semantics remain an explicit token-contract assumption.
rule tokenModeValidEmptyProofCallsConfiguredToken(
    env e,
    uint256 protocolId,
    uint256 votingRoundId,
    bytes32[] proof
) {
    bytes32 root = merkleRootAt(protocolId, votingRoundId);
    address token = feeToken();
    require oldRelay() == 0;
    require token != 0;
    require protocolId > 1;
    require e.msg.value == 0;
    require root != to_bytes32(0);
    require proof.length == 0;
    require protocolFee(protocolId) > 0;
    require !feeExemptAddress(e.msg.sender);

    feeVerificationCallTouched = false;
    feeVerificationCallTarget = 0;
    feeVerificationCallValue = 0;
    verify@withrevert(e, protocolId, votingRoundId, root, proof);

    satisfy !lastReverted && feeVerificationCallTouched,
        "a valid token-mode verification must have a successful execution witness";
    assert feeVerificationCallTouched,
        "a valid charged token-mode verification must attempt the token call";
    assert feeVerificationCallTarget == token,
        "the fee call must target the configured token";
    assert feeVerificationCallValue == 0,
        "the ERC-20 fee call must carry no native value";
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
/// that transaction. This rule does not observe the generic call's exact calldata/queue entry;
/// concrete encoded-call queue creation is covered by the manifest-bound RelayOwnerTimelockFV
/// concrete/Halmos fixture within its stated bounds.
rule delayedOwnerCallDoesNotApply(method f, uint256 protocolId, address account)
filtered { f -> nonUpgradeOwnerGuarded(f) }
{
    address preOwner = owner();
    uint256 preDuration = getTimelockDurationSeconds();
    address preSetter = signingPolicySetter();
    address preCollector = feeCollectionAddress();
    address preToken = feeToken();
    uint256 preSource = sourceChainId();
    uint256 preFee = protocolFee(protocolId);
    bool preFeeMember = feeProtocolIdInSet(protocolId);
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
    assert feeToken() == preToken, "a delayed owner call must not change the fee token";
    assert sourceChainId() == preSource, "a delayed owner call must not change source domain";
    assert protocolFee(protocolId) == preFee, "a delayed owner call must not change protocol fees";
    assert feeProtocolIdInSet(protocolId) == preFeeMember,
        "a delayed owner call must not change fee-table membership";
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

/// A successful ready execution of an allowlisted non-upgrade owner call preserves the
/// current implementation's scalar, write-once, and fee-table invariants. This rule closes
/// the executeTimelockedCall exclusion used by the generic parametric rules: the exact
/// queued calldata is pessimistically dispatched to one of the five real owner methods.
/// Queued UUPS upgrades remain the explicit trusted-upgrade boundary.
rule successfulNonUpgradeExecutionPreservesRelayInvariants(
    env e,
    bytes encodedCall,
    uint256 epoch,
    uint256 feeProtocolId,
    uint256 rootProtocolId,
    uint256 votingRoundId
) {
    require isNonUpgradeOwnerGuardedCall(encodedCall);
    require !timelockExecuting();
    require e.msg.value == 0;
    uint256 preTimestamp = timelockedCallTimestampAt(encodedCall);
    require preTimestamp != 0;
    require e.block.timestamp >= preTimestamp;

    uint32 preLastInitialized; uint32 _preStartRound;
    preLastInitialized, _preStartRound = lastInitializedRewardEpochData();
    bytes32 prePolicyHash = policyHashAt(epoch);
    bytes32 preMerkleRoot = merkleRootAt(rootProtocolId, votingRoundId);
    address preOwner = owner();
    uint256 preDuration = getTimelockDurationSeconds();
    address preSetter = signingPolicySetter();
    address preCollector = feeCollectionAddress();
    address preToken = feeToken();
    uint256 preSource = sourceChainId();
    uint256 preFee = protocolFee(feeProtocolId);
    bool preFeeMember = feeProtocolIdInSet(feeProtocolId);

    require preDuration <= 604800;
    require preSetter == 0 || preToken == 0;
    require (preFee != 0) <=> preFeeMember;
    require protocolFee(0) == 0 && !feeProtocolIdInSet(0);
    require protocolFee(1) == 0 && !feeProtocolIdInSet(1);

    executeTimelockedCall@withrevert(e, encodedCall);
    bool reverted = lastReverted;

    uint32 postLastInitialized; uint32 _postStartRound;
    postLastInitialized, _postStartRound = lastInitializedRewardEpochData();
    address postSetter = signingPolicySetter();
    address postToken = feeToken();
    uint256 postDuration = getTimelockDurationSeconds();
    uint256 postFee = protocolFee(feeProtocolId);
    bool postFeeMember = feeProtocolIdInSet(feeProtocolId);

    satisfy !reverted
        && isCanonicalDurationSetterCall(encodedCall)
        && postDuration != preDuration
        && postDuration <= 604800,
        "a real delayed non-upgrade execution must witness invariant preservation";

    assert reverted || policyHashAt(epoch) == prePolicyHash,
        "delayed non-upgrade execution must preserve every sampled policy hash";
    assert reverted || merkleRootAt(rootProtocolId, votingRoundId) == preMerkleRoot,
        "delayed non-upgrade execution must preserve every sampled Merkle root";
    assert reverted || sourceChainId() == preSource,
        "delayed non-upgrade execution must preserve the source domain";
    assert reverted || postLastInitialized == preLastInitialized,
        "delayed non-upgrade execution must preserve the initialized epoch";
    assert reverted || owner() == preOwner,
        "delayed non-upgrade execution must preserve ownership";
    assert reverted || postDuration <= 604800,
        "delayed non-upgrade execution must preserve the duration bound";
    assert reverted || preCollector == 0 || feeCollectionAddress() != 0,
        "delayed non-upgrade execution must not clear an established fee recipient";
    assert reverted || ((preSetter == 0) <=> (postSetter == 0)),
        "delayed non-upgrade execution must preserve signing-policy mode";
    assert reverted || postSetter == 0 || postToken == 0,
        "delayed non-upgrade execution must preserve zero fee token in setter mode";
    assert reverted || ((postFee != 0) <=> postFeeMember),
        "delayed non-upgrade execution must preserve fee mapping/set lockstep";
    assert reverted || (protocolFee(0) == 0 && !feeProtocolIdInSet(0)),
        "delayed non-upgrade execution must preserve reserved protocol id zero";
    assert reverted || (protocolFee(1) == 0 && !feeProtocolIdInSet(1)),
        "delayed non-upgrade execution must preserve reserved protocol id one";
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
