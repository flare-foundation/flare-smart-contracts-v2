/*
 * Relay.sol — Certora CVL spec: cross-transaction STORAGE invariants.
 *
 * These are PARAMETRIC rules: each holds for EVERY external/public method `f`, EVERY caller, and EVERY
 * argument — i.e. over all functions and all call sequences. That is Certora's genuine advantage over the
 * Halmos/Kontrol proofs in this repo, which established the same properties only for SPECIFIC call
 * sequences (e.g. RelayGovernanceNonceFV's 2-call nonce sequence, RelayEpochAdvanceFV's single +1 step).
 * Here they become global state invariants.
 *
 * NOTE (honest scope): Certora — like Halmos and Kontrol — UNROLLS the within-call signature loop
 * (--loop_iter), so it does NOT close the ∀N within-call signature-loop gap better than Kontrol; the ∀N∀K
 * signature-loop soundness is the Lean proof (test-forge/fv/lean/RelaySigLoop.lean). Certora's value here
 * is exactly these all-functions/all-sequences STORAGE invariants.
 *
 * ecrecover (precompile 0x01) is left NONDET — the uninterpreted-signature modeling contract (A2): the
 * storage invariants below hold regardless of which signatures the prover lets through.
 *
 * Run (requires a Certora account/key — the prover is cloud-hosted):  certoraRun certora/Relay.conf
 */

methods {
    function governanceFeeNonce() external returns (uint256) envfree;
    function signingPolicySetter() external returns (address) envfree;
    function lastInitializedRewardEpochData() external returns (uint32, uint32) envfree;

    // Unresolved external calls — the ecrecover precompile (0x01), the address(this).call self-verify in
    // _verifyCustomSignature, and oldRelay.* — must NOT havoc this contract's storage. Sound because Relay
    // has NO delegatecall (verified, AC-8): an external call can never write currentContract storage.
    // Without this, Certora's default HAVOC_ALL spuriously breaks every storage invariant on relay()/
    // governanceFeeSetup.
    unresolved external in _._ => DISPATCH [] default HAVOC_ECF;
}

/// The governance-fee nonce never decreases — across ANY function (generalises RLY-02 / AC-10 from the
/// 2-call sequence in RelayGovernanceNonceFV to all functions & all sequences).
rule nonceMonotonic(method f) {
    uint256 pre = governanceFeeNonce();
    env e; calldataarg args;
    f(e, args);
    uint256 post = governanceFeeNonce();
    assert post >= pre, "governanceFeeNonce must never decrease";
}

/// The last-initialized reward epoch never regresses — across ANY function (generalises L1 / the +1 step in
/// RelayEpochAdvanceFV to global monotonicity, including the relay() Mode-1 policy-rotation path).
rule lastInitializedMonotonic(method f) {
    uint32 pre; uint32 _a;
    pre, _a = lastInitializedRewardEpochData();
    // exclude the uint32 wrap edge (≈386yr/47yr out, documented out-of-scope R7/RLY-19): the +1 advance
    // would only regress if pre were at type-max, an unreachable state.
    require pre < max_uint32;
    env e; calldataarg args;
    f(e, args);
    uint32 post; uint32 _b;
    post, _b = lastInitializedRewardEpochData();
    assert post >= pre, "lastInitializedRewardEpoch must never regress";
}

/// The signing-policy setter is immutable after construction — across ANY function (access-control anchor:
/// the authority that may rotate policy in setter mode can never be changed).
rule signingPolicySetterImmutable(method f) {
    address pre = signingPolicySetter();
    env e; calldataarg args;
    f(e, args);
    address post = signingPolicySetter();
    assert post == pre, "signingPolicySetter must be immutable";
}

/// A finalized signing-policy hash is WRITE-ONCE: once an epoch's hash is set (non-zero) it is never
/// overwritten or cleared by any function — finalized policies cannot be tampered. (Direct storage access
/// to the private mapping avoids the toSigningPolicyHash() getter's oldRelay delegation / access gate.)
rule policyHashWriteOnce(method f, uint256 epoch) {
    bytes32 pre = currentContract.toSigningPolicyHashPrivate[epoch];
    require pre != to_bytes32(0);
    env e; calldataarg args;
    f(e, args);
    bytes32 post = currentContract.toSigningPolicyHashPrivate[epoch];
    assert post == pre, "a finalized signing-policy hash must be write-once";
}

/// A finalized Merkle root is WRITE-ONCE per (protocolId, votingRoundId): once set it is never changed —
/// so a relayed finalization cannot be silently rewritten by a later call. (If this FAILS it documents
/// that re-finalization is permitted by design; either way the result is informative.)
rule merkleRootWriteOnce(method f, uint256 protocolId, uint256 votingRoundId) {
    bytes32 pre = currentContract.merkleRootsPrivate[protocolId][votingRoundId];
    require pre != to_bytes32(0);
    env e; calldataarg args;
    f(e, args);
    bytes32 post = currentContract.merkleRootsPrivate[protocolId][votingRoundId];
    assert post == pre, "a finalized Merkle root must be write-once";
}
