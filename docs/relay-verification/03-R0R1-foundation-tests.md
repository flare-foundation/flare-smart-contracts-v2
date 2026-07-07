# L3 — R0/R1: foundation tests (Foundry)

> **What you get from this level.** The base of the stack: concrete and fuzz tests that exercise the
> *actual compiled contract*. What they establish, what they deliberately do not, and how to run them.
> Highest object-fidelity (the real bytecode), weakest input-coverage (a few / random).

---

## 3.1 Role in the stack

R0/R1 are the foundation everything else builds on. They run the **deployed contract** end-to-end through
Foundry, with no abstraction: real storage, real assembly, real calldata decoding. Their job is to pin
*functional* correctness on representative and random inputs — the cases a human would think to check, plus
a fuzzed cloud around them — and to catch regressions cheaply on every CI run.

They do **not** give a guarantee over *all* inputs (that is R2 upward). Their value is fidelity and speed:
if a change breaks a mode in an obvious way, these fail in seconds, on the real code, before any symbolic
or inductive tool is invoked.

---

## 3.2 What is covered

**Artifact:** [`test-forge/unit/protocol/implementation/Relay.t.sol`](../../test-forge/unit/protocol/implementation/Relay.t.sol) — **59 test functions**, ~1145 lines.
(The engagement grew this from 31 to 59 as part of hardening; §3.5 itemizes all 59, one line each.) The
suite spans all three `relay()` modes and the auxiliary entry points:

- **Signing-policy / hashing:** `test_signingPolicyHash_matchesContract`,
  `test_event_signatures_match_canonical` — the on-chain policy hash and event ABI match the canonical
  reference encoder.
- **Signing-policy rotation (Mode 1, protocolId == 0):** `RelayPolicyRotationTest` — relaying a *new*
  signing policy advances `lastInitializedRewardEpoch` (`test_relayNewSigningPolicy_happyPath`); the new
  policy must be `lastInitialized + 1` (`_wrongRewardEpoch_reverts`) with enough weight
  (`_lowWeight_reverts`) and present metadata (`_noNewPolicySize_reverts`); post-rotation a message is
  finalized by the new policy (`_thenRelayWithNewPolicy`), the old policy is then locked out
  (`_mustUseNewSignPolicy_afterRotation_reverts`), and a future-epoch message under the current policy
  needs the +20% increased threshold (`_crossEpoch_oldPolicy_thresholdIncrease`). This ports the
  policy-rotation lifecycle the Hardhat suite covers ([`Relay.test.ts`](../../test/unit/protocol/implementation/Relay.test.ts), "Verification").
- **Governance-fee mode (protocolId == 1):** happy path then **replay rejected**
  (`test_governanceFeeSetup_happyPath_then_replayRejected`), strictly-increasing / non-sequential nonce
  handling, address binding, invalid-protocolId revert, and mode-gating
  (`test_governanceFeeSetup_onSetterMode_reverts`). This is the direct functional check on the RLY-02
  replay-protection area.
- **Custom-signature verify:** returns the reward epoch on success
  (`test_verifyCustomSignature_direct_returnsRewardEpoch`); **reverts on insufficient weight**
  (`test_verifyCustomSignature_insufficientWeight_reverts`) — the functional face of threshold soundness.
- **Randomness:** happy-path stores the proven value; **monotonicity** (stale round does not regress,
  across reward epochs); invalid/missing/short/malformed-trailer reverts; deep Merkle proof; secure-bit
  normalization; zero-value returned-not-absent.
- **Verify / Merkle:** `test_verify_unfinalizedZeroRoot_reverts` (the RLY-01 zero-root area), proof
  handling.

**Fuzzing (R1).** Foundry automatically fuzzes any test taking parameters: such tests are run on many
randomized inputs per CI invocation (Foundry's property-based layer), widening coverage beyond the fixed
concrete cases at no extra authoring cost.

---

## 3.3 How CI runs it

Two jobs in `.gitlab-ci.yml`, both green in the current pipeline:

- **`test-unit-forge`** — `forge test -vvv` (runs all Foundry tests incl. fuzz).
- **`coverage-forge`** (+ `coverage-forge-reports`) — `forge build` then the coverage pass over the suite.

Reproduce locally (see [L11](11-reproducibility.md) for the full toolchain):

```bash
forge test -vvv --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
forge coverage --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
```

---

## 3.4 What R0/R1 do and do not establish

- **Do:** functional correctness of all modes on concrete + randomized inputs, on the **real deployed
  bytecode**; fast regression protection; concrete witnesses that the accept/revert paths behave as
  intended (the human-legible counterpart to the symbolic reachability controls at R2).
- **Do not:** cover *all* inputs. A fuzzer can miss the one adversarial input; concrete tests only speak to
  the cases written. The unbounded and bounded-exhaustive guarantees come from R2 (Halmos, all inputs in
  range) and R3/R4 (all sizes). R0/R1 are necessary and cheap, not sufficient.

This is exactly the ladder's bottom two rungs: maximal fidelity, minimal coverage. Every claim that needs
"for all inputs" is escalated upward.

---

## 3.5 The test inventory (59 tests, grouped)

All **59** tests, one line each, grouped by behavior area (2+7+7+10+7+8+7+4+7 = 59) — so a reader can see
what is concretely pinned without opening the file. Every test is concrete/example-based (R0; Foundry's
fuzz layer, R1, randomizes any parameterized test), and the shared harness (`RelayTestBase`: the
policy/message/signature encoders and the chunked policy hash) doubles as the substrate the FV harnesses
(Halmos/Kontrol) build on.

**Signing-policy hash & event-ABI canonicality (2)**

- `test_signingPolicyHash_matchesContract` — the reference policy-hash encoder matches `setSigningPolicy`'s hash.
- `test_event_signatures_match_canonical` — assembly's hardcoded event topics match the canonical ABI (RLY-22).

**Signing-policy rotation — Mode 1, protocolId == 0 (7)**

- `test_relayNewSigningPolicy_happyPath` — relaying the next policy advances `lastInitializedRewardEpoch`, records its start round.
- `test_relayNewSigningPolicy_thenRelayWithNewPolicy` — after rotation, the new policy finalizes a next-epoch message.
- `test_relayNewSigningPolicy_wrongRewardEpoch_reverts` — the relayed policy must be `lastInitialized + 1`.
- `test_relayNewSigningPolicy_lowWeight_reverts` — under-threshold signer weight rejected; the epoch does not advance.
- `test_relayNewSigningPolicy_noNewPolicySize_reverts` — protocolId 0 with no new-policy metadata reverts.
- `test_relay_mustUseNewSignPolicy_afterRotation_reverts` — the old policy is locked out once the new one exists.
- `test_relay_crossEpoch_oldPolicy_thresholdIncrease` — a future-epoch message under the current policy needs +20% weight.

**Custom signatures & governance fees — protocolId == 1 (7)**

- `test_governanceFeeSetup_happyPath_then_replayRejected` — fee applied once; replaying the accepted message rejected (RLY-02).
- `test_governanceFeeSetup_strictlyIncreasing_nonSequential_nonce` — the nonce may jump forward; any lower nonce rejected.
- `test_governanceFeeSetup_addressBinding` — the digest is bound to this relay's address; wrong-address messages fail.
- `test_governanceFeeSetup_invalidProtocolId_reverts` — a fee config for a reserved protocol id (≤ 1) is rejected.
- `test_governanceFeeSetup_onSetterMode_reverts` — fee setup is disabled on setter-mode (Flare) deployments.
- `test_verifyCustomSignature_direct_returnsRewardEpoch` — successful custom-signature verify returns the policy's reward epoch.
- `test_verifyCustomSignature_insufficientWeight_reverts` — below-threshold weight fails custom-signature verification.

**Random protocol — Mode 2, RLY-03 (10)**

- `test_random_happyPath_storesProvenValue` — a Merkle-proven random is stored; live and historical reads return it.
- `test_random_monotonicity_staleRoundDoesNotRegress` — a stale round never regresses the live pointer (still stored historically).
- `test_random_monotonicity_acrossRewardEpochs` — the same monotonicity across reward epochs (+20% threshold branch).
- `test_random_invalidProof_reverts` — a value that does not hash into the signed root reverts.
- `test_random_missingTrailer_reverts` — a random message without its value+proof trailer reverts.
- `test_random_shortTrailer_revertsNoRandomNumber` — a trailer shorter than the 32-byte random word: "No random number".
- `test_random_malformedTrailerLength_reverts` — a trailer that is not a multiple of 32 bytes reverts.
- `test_random_deepMerkleProof` — a multi-node proof verifies (the fold loop runs more than once).
- `test_random_isSecureNormalization` — an isSecure byte outside {0,1} is normalized to 1 (RLY-14).
- `test_random_zeroValue_isReturnedNotAbsent` — a relayed zero random is returned, not treated as absent (L-1).

**Mode-2 message & signature-loop edges (7)**

- `test_relay_zeroMerkleRoot_reverts` — relaying a zero Merkle root reverts (RLY-04).
- `test_relay_badV_reverts` — a non-canonical `v` is rejected before `ecrecover`: "Bad v" (RLY-16).
- `test_relay_highS_reverts` — a high-`s` (malleable) signature is rejected: "Bad s" (RLY-16).
- `test_threshold_exactBoundary_strictGreater` — weight == threshold must fail; strictly greater passes.
- `test_relay_indexOutOfRange_reverts` — a signature index == numberOfVoters: "Index out of range".
- `test_relay_indexOutOfOrder_reverts` — non-increasing signature indices: "Index out of order".
- `test_relay_zeroSignatures_notEnoughWeight` — zero signatures falls through to "Not enough weight".

**`verify()` — Merkle membership, fees, refunds, reentrancy (8)**

- `test_verify_unfinalizedZeroRoot_reverts` — an unfinalized (zero) stored root is rejected (RLY-01).
- `test_verify_finalizedRoot_passes` — a valid proof against a finalized root passes.
- `test_verify_merkleProofInvalid_reverts` — a proof for the wrong leaf is rejected.
- `test_verify_invalidProtocolId_reverts` — a reserved protocol id (≤ 1) is rejected.
- `test_verify_refundsOverpayment` — exactly the fee is forwarded; the overpayment is refunded (RLY-21).
- `test_verify_feeReceiverReverts` — an ETH-rejecting fee collector reverts the call: "Transfer failed".
- `test_verify_refundReceiverReverts` — an ETH-rejecting refund recipient reverts the call: "Refund failed".
- `test_verify_reentrantReceiver_consistentNoExtraEth` — refund-callback reentrancy sees consistent state, pays one fee (DiD).

**`verify()` — the oldRelay fallback (7)**

- `test_verify_oldRelayFallback_revertsOnFalse` — fails closed when `oldRelay.verify` returns false (RLY-13).
- `test_verify_oldRelayFallback_passesOnTrue` — passes through the old relay's true verdict.
- `test_verify_oldRelayFallback_refundsOverpayment` — forwards only the old fee and refunds the rest (M-1).
- `test_verify_oldRelayFallback_tooLowFee_reverts` — `msg.value` below the old fee: "too low fee".
- `test_verify_oldRelayFallback_exactFee_skipsRefund` — an exact fee skips the refund call entirely.
- `test_verify_oldRelayFallback_zeroFee_fullRefund` — a zero old fee refunds the caller in full.
- `test_oldRelay_readDelegation_belowBoundary` — the four read paths delegate to the old relay below the boundary.

**Getters, lifecycle & access windows (4)**

- `test_merkleRoots_relayMode_reverts` — `merkleRoots()` is locked out in relay mode.
- `test_toSigningPolicyHash_relayMode_reverts` — `toSigningPolicyHash()` is locked out in relay mode.
- `test_getVotingRoundId_beforeStart_reverts` — a pre-start timestamp hits the underflow guard.
- `test_getRandomNumber_beforeAnyRelay_returnsDefault` — returns `(0, false, ts)` before any random relay (RLY-20).

**Constructor / config validation (7)**

- `test_ctor_rejects_zeroRewardEpochDuration` — a zero reward-epoch duration is rejected.
- `test_ctor_rejects_zeroVotingEpochDuration` — a zero voting-epoch duration is rejected.
- `test_ctor_rejects_zeroFeeCollection_relayMode` — relay mode requires a fee-collection address.
- `test_ctor_allows_zeroFeeCollection_setterMode` — setter mode (no fees) permits a zero fee-collection address.
- `test_ctor_rejects_zeroInitialSigningPolicyHash` — a zero initial policy hash (a bricked epoch) is rejected (L-4).
- `test_ctor_oldRelay_incompatibleSetterMode_reverts` — a setter-mode old relay is incompatible with a relay-mode deployment.
- `test_ctor_oldRelay_wrongStartTs_reverts` — a timing mismatch with the old relay is rejected.

**Next:** [L4 — R2: bounded symbolic execution (Halmos)](04-R2-bounded-symbolic-halmos.md), which keeps the
real-bytecode fidelity but replaces "a few / random" with "all inputs up to a bound."
