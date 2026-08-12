/*
 * Relay.sol — current owner-timelock branch: cross-transaction scalar invariants.
 *
 * These rules deliberately exclude three dispatchers:
 *
 * - initialize(...) establishes the proxy's initial state;
 * - upgradeToAndCall(...) may intentionally replace every implementation invariant; and
 * - executeTimelockedCall(...) can dispatch the queued upgrade above.
 *
 * That is a trust boundary, not a prover workaround: an authorized UUPS upgrade can
 * install arbitrary code, so no implementation-level invariant can soundly quantify
 * over it without constraining the replacement implementation. The separate timelock
 * rules exercise queue/execute/cancel behavior without claiming upgrade equivalence.
 *
 * Calls unresolved outside the verification scene are summarized as ECF. This models
 * the old-Relay/read/precompile boundaries while assuming no owner-controlled upgrade
 * is entered through an external callback. ecrecover remains nondeterministic.
 */

methods {
    function lastInitializedRewardEpochData() external returns (uint32, uint32) envfree;
    function signingPolicySetter() external returns (address) envfree;
    function sourceChainId() external returns (uint256) envfree;
    function owner() external returns (address) envfree;
    function getTimelockDurationSeconds() external returns (uint256) envfree;
    function feeCollectionAddress() external returns (address) envfree;

    unresolved external in _._ => DISPATCH [] default HAVOC_ECF;
}

definition preservesCurrentImplementation(method f) returns bool =
    f.selector != 0x1d5226a3 /* initialize((...),address,address,address) */
    && f.selector != sig:upgradeToAndCall(address, bytes).selector
    && f.selector != sig:executeTimelockedCall(bytes).selector;

/// Once initialized, no ordinary current-implementation method can change the
/// source-network domain bound into policies and messages.
rule sourceChainIdImmutableAfterInitialization(method f)
filtered { f -> preservesCurrentImplementation(f) }
{
    uint256 pre = sourceChainId();
    require pre != 0;
    env e; calldataarg args;
    currentContract.f(e, args);
    uint256 post = sourceChainId();
    assert post == pre, "sourceChainId must remain immutable after initialization";
}

/// Relay mode (zero setter) cannot become setter mode, and setter mode cannot
/// become relay mode. The owner may rotate one nonzero setter to another.
rule signingPolicySetterModeStable(method f)
filtered { f -> preservesCurrentImplementation(f) }
{
    address pre = signingPolicySetter();
    env e; calldataarg args;
    currentContract.f(e, args);
    address post = signingPolicySetter();
    assert (pre == 0) <=> (post == 0), "signing-policy mode must not change";
}

/// The last initialized epoch is monotone under current Relay behavior. The
/// uint32 maximum edge is excluded because a +1 advance reverts there.
rule lastInitializedMonotonic(method f)
filtered { f -> preservesCurrentImplementation(f) }
{
    uint32 pre; uint32 _preStart;
    pre, _preStart = lastInitializedRewardEpochData();
    require pre < max_uint32;
    env e; calldataarg args;
    currentContract.f(e, args);
    uint32 post; uint32 _postStart;
    post, _postStart = lastInitializedRewardEpochData();
    assert post >= pre, "lastInitializedRewardEpoch must never regress";
}

/// Ownership can rotate but cannot be cleared: transferOwnership rejects zero
/// and renounceOwnership always reverts.
rule ownerCannotBecomeZero(method f)
filtered { f -> preservesCurrentImplementation(f) }
{
    address pre = owner();
    require pre != 0;
    env e; calldataarg args;
    currentContract.f(e, args);
    address post = owner();
    assert post != 0, "Relay ownership must not be renounced or transferred to zero";
}

/// The configured delay remains inside the production seven-day cap whenever
/// it starts inside that cap.
rule timelockDurationBoundPreserved(method f)
filtered { f -> preservesCurrentImplementation(f) }
{
    uint256 pre = getTimelockDurationSeconds();
    require pre <= 604800;
    env e; calldataarg args;
    currentContract.f(e, args);
    uint256 post = getTimelockDurationSeconds();
    assert post <= 604800, "timelock duration must remain at most seven days";
}

/// Relay-mode fee proceeds cannot be redirected to the zero address once a
/// valid recipient has been established.
rule feeCollectionAddressCannotBecomeZero(method f)
filtered { f -> preservesCurrentImplementation(f) }
{
    address pre = feeCollectionAddress();
    require pre != 0;
    env e; calldataarg args;
    currentContract.f(e, args);
    address post = feeCollectionAddress();
    assert post != 0, "fee collection address must not become zero";
}
