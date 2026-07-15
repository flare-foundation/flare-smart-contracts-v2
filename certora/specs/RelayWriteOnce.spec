/*
 * Relay.sol — write-once storage invariants, restated over harness getters (C-1 discharge, Phase B).
 *
 * The original spec (RelayInvariants.spec) states these two rules via CVL direct storage access
 * (`currentContract.toSigningPolicyHashPrivate[...]`), which depends on the prover's storage analysis —
 * exactly the analysis Relay's raw-assembly sstores defeat (the documented C-1 wall). Here they are
 * restated over plain-Solidity view getters (certora/harness/RelayHarness.sol) reading the same mappings
 * (visibility-munged private -> internal; faithfulness machine-checked by certora/munge.sh), and the run
 * disables the storage-splitting optimization (-enableStorageSplitting false). Storage then becomes one
 * SMT array and aliasing is decided by the prover's injective hashing model (keccak locations are
 * guaranteed distinct from scalar slots and from each other for distinct keys), so a raw assembly store
 * can no longer spuriously havoc an unrelated mapping entry.
 *
 * ecrecover stays NONDET (uninterpreted-signature modeling contract A2), and unresolved external calls
 * must not havoc this contract's storage (Relay has no delegatecall — AC-8), as in the original spec.
 */

methods {
    function policyHashAt(uint256) external returns (bytes32) envfree;
    function merkleRootAt(uint256, uint256) external returns (bytes32) envfree;
    function lastInitializedRewardEpochData() external returns (uint32, uint32) envfree;

    unresolved external in _._ => DISPATCH [] default HAVOC_ECF;
}

/// A finalized signing-policy hash is WRITE-ONCE: once an epoch's hash is set (non-zero) it is never
/// overwritten or cleared by any function — finalized policies cannot be tampered.
///
/// REACHABLE-STATE LINK (documented assumption): the rule quantifies over arbitrary pre-states, including
/// the unreachable combination "hash[epoch] != 0 while lastInitializedRewardEpoch < epoch", from which
/// setSigningPolicy(epoch) may legitimately (re)write epoch's hash (its gate only enforces
/// rewardEpochId == lastInitialized + 1). On every REACHABLE state a non-zero hash exists only for epochs
/// <= lastInitializedRewardEpoch (the constructor seeds the initial epoch and every writer — the setter and
/// relay() Mode-1 alike — writes exactly lastInitialized+1, then advances the pointer). The require below
/// restricts the rule to states satisfying that link; without it the prover exhibits exactly the
/// unreachable-state artifact (Phase-B2 run f4777ba7, legacy codegen).
rule policyHashWriteOnce(method f, uint256 epoch) {
    bytes32 pre = policyHashAt(epoch);
    require pre != to_bytes32(0);
    uint32 lastInit; uint32 _startRound;
    lastInit, _startRound = lastInitializedRewardEpochData();
    require to_mathint(epoch) <= to_mathint(lastInit);
    env e; calldataarg args;
    f(e, args);
    bytes32 post = policyHashAt(epoch);
    assert post == pre, "a finalized signing-policy hash must be write-once";
}

/// A finalized Merkle root is WRITE-ONCE per (protocolId, votingRoundId): once set it is never changed —
/// a relayed finalization cannot be silently rewritten by a later call.
rule merkleRootWriteOnce(method f, uint256 protocolId, uint256 votingRoundId) {
    bytes32 pre = merkleRootAt(protocolId, votingRoundId);
    require pre != to_bytes32(0);
    env e; calldataarg args;
    f(e, args);
    bytes32 post = merkleRootAt(protocolId, votingRoundId);
    assert post == pre, "a finalized Merkle root must be write-once";
}
