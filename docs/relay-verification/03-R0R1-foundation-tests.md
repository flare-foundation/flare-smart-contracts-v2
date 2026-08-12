# L3 — R0/R1: foundation tests (Foundry)

> **Evidence note.** Test inventories and totals change with the code. Use
> [`CURRENT-STATUS.md`](CURRENT-STATUS.md) for the run made against this revision; totals below are historical
> unless explicitly dated current.

> **What you get from this level.** The base of the stack: concrete and fuzz tests that exercise the
> _actual compiled contract_. What they establish, what they deliberately do not, and how to run them.
> Highest object-fidelity (the real bytecode), weakest input-coverage (a few / random).

---

## 3.1 Role in the stack

R0/R1 are the foundation everything else builds on. They run the **deployed contract** end-to-end through
Foundry, with no abstraction: real storage, real assembly, real calldata decoding. Their job is to pin
_functional_ correctness on representative and random inputs — the cases a human would think to check, plus
a fuzzed cloud around them — and to catch regressions cheaply on every CI run.

They do **not** give a guarantee over _all_ inputs (that is R2 upward). Their value is fidelity and speed:
if a change breaks a mode in an obvious way, these fail in seconds, on the real code, before any symbolic
or inductive tool is invoked.

---

## 3.2 What is covered

**Artifact:** [`test-forge/unit/protocol/implementation/Relay.t.sol`](../../test-forge/unit/protocol/implementation/Relay.t.sol) — **51 test functions**.
The five removed `governanceFeeSetup` tests, two direct custom-signature tests, and
one superseded policy-hash example covered the deleted legacy fee-governance path.
Section 3.5 itemizes the remaining 51 tests. A sibling
file [`RelayChainDomain.t.sol`](../../test-forge/unit/protocol/implementation/RelayChainDomain.t.sol) adds **10**
RLY-23 chain-domain-binding tests (cross-source replay rejection, mirror-accept, home-force, the fork trade-off,
same-chain acceptance, and a legacy migration A/B against the `contracts/mock/RelayMainDeployed.sol` pre-RLY-23
Relay), reusing the same
`RelayTestBase` harness. (The retired GSS gate added **36** tests across
`SafeGovernance.t.sol`, the production-rehearsal fixture and the state machine;
those suites went with the GSS design — git history — and the owner-timelock
successors are `RelayOwnableWithTimelock.t.sol` + `RelayUpgrade.t.sol`.)
Together these suites span all three `relay()` modes, migration behavior, and the
owner-governance surface:

- **Signing-policy / event ABI:** [`test_event_signatures_match_canonical`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L282)
  pins the assembly event topics to the canonical ABI.
- **Signing-policy rotation (Mode 1, protocolId == 0):** `RelayPolicyRotationTest` — relaying a _new_
  signing policy advances `lastInitializedRewardEpoch` ([`test_relayNewSigningPolicy_happyPath`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L1058)); the new
  policy must be `lastInitialized + 1` (`_wrongRewardEpoch_reverts`) with enough weight
  (`_lowWeight_reverts`) and present metadata (`_noNewPolicySize_reverts`); post-rotation a message is
  finalized by the new policy (`_thenRelayWithNewPolicy`), the old policy is then locked out
  (`_mustUseNewSignPolicy_afterRotation_reverts`), and a future-epoch message under the current policy
  needs the +20% increased threshold (`_crossEpoch_oldPolicy_thresholdIncrease`). This ports the
  policy-rotation lifecycle the Hardhat suite covers ([`Relay.test.ts`](../../test/unit/protocol/implementation/Relay.test.ts), "Verification").
- **Owner governance:** the owner-timelock queue/execute/cancel lifecycle, the
  guarded fee setters (validation + setter-mode fail-close) and the timelocked
  upgrade path are covered by
  [`RelayOwnableWithTimelock.t.sol`](../../test-forge/unit/governance/RelayOwnableWithTimelock.t.sol)
  and [`RelayUpgrade.t.sol`](../../test-forge/unit/governance/RelayUpgrade.t.sol);
  see [`relay-governance.md`](../relay-governance.md).
- **Randomness:** happy-path stores the proven value; **monotonicity** (stale round does not regress,
  across reward epochs); invalid/missing/short/malformed-trailer reverts; deep Merkle proof; secure-bit
  normalization; zero-value returned-not-absent.
- **Verify / Merkle:** [`test_verify_unfinalizedZeroRoot_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L427) (the RLY-01 zero-root area), proof
  handling.

**Fuzzing (R1).** Foundry automatically fuzzes any test taking parameters: such tests are run on many
randomized inputs per CI invocation (Foundry's property-based layer), widening coverage beyond the fixed
concrete cases at no extra authoring cost.

---

## 3.3 How CI runs it

Two jobs in `.gitlab-ci.yml` define the current automated test paths; consult
the pipeline for the target commit rather than inferring a verdict from this page:

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
- **Do not:** cover _all_ inputs. A fuzzer can miss the one adversarial input; concrete tests only speak to
  the cases written. The unbounded and bounded-exhaustive guarantees come from R2 (Halmos, all inputs in
  range) and R3/R4 (all sizes). R0/R1 are necessary and cheap, not sufficient.

This is exactly the ladder's bottom two rungs: maximal fidelity, minimal coverage. Every claim that needs
"for all inputs" is escalated upward.

---

## 3.5 The core Relay test inventory (51 tests, grouped)

All **51** tests, one line each, grouped by behavior area
(1+7+10+7+8+7+4+7 = 51) — so a reader can see
what is concretely pinned without opening the file. Every test is concrete/example-based (R0; Foundry's
fuzz layer, R1, randomizes any parameterized test), and the shared harness (`RelayTestBase`: the
policy/message/signature encoders and the chunked policy hash) doubles as the substrate the FV harnesses
(Halmos/Kontrol) build on.

**Event-ABI canonicality (1)**

- [`test_event_signatures_match_canonical`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L282) — assembly's hardcoded event topics match the canonical ABI (RLY-22).

**Signing-policy rotation — Mode 1, protocolId == 0 (7)**

- [`test_relayNewSigningPolicy_happyPath`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L1058) — relaying the next policy advances `lastInitializedRewardEpoch`, records its start round.
- [`test_relayNewSigningPolicy_thenRelayWithNewPolicy`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L1072) — after rotation, the new policy finalizes a next-epoch message.
- [`test_relayNewSigningPolicy_wrongRewardEpoch_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L1082) — the relayed policy must be `lastInitialized + 1`.
- [`test_relayNewSigningPolicy_lowWeight_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L1091) — under-threshold signer weight rejected; the epoch does not advance.
- [`test_relayNewSigningPolicy_noNewPolicySize_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L1099) — protocolId 0 with no new-policy metadata reverts.
- [`test_relay_mustUseNewSignPolicy_afterRotation_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L1107) — the old policy is locked out once the new one exists.
- [`test_relay_crossEpoch_oldPolicy_thresholdIncrease`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L1119) — a future-epoch message under the current policy needs +20% weight.

**Random protocol — Mode 2, RLY-03 (10)**

- [`test_random_happyPath_storesProvenValue`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L226) — a Merkle-proven random is stored; live and historical reads return it.
- [`test_random_monotonicity_staleRoundDoesNotRegress`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L242) — a stale round never regresses the live pointer (still stored historically).
- [`test_random_monotonicity_acrossRewardEpochs`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L323) — the same monotonicity across reward epochs (+20% threshold branch).
- [`test_random_invalidProof_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L259) — a value that does not hash into the signed root reverts.
- [`test_random_missingTrailer_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L271) — a random message without its value+proof trailer reverts.
- [`test_random_shortTrailer_revertsNoRandomNumber`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L393) — a trailer shorter than the 32-byte random word: "No random number".
- [`test_random_malformedTrailerLength_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L339) — a trailer that is not a multiple of 32 bytes reverts.
- [`test_random_deepMerkleProof`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L350) — a multi-node proof verifies (the fold loop runs more than once).
- [`test_random_isSecureNormalization`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L367) — an isSecure byte outside {0,1} is normalized to 1 (RLY-14).
- [`test_random_zeroValue_isReturnedNotAbsent`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L311) — a relayed zero random is returned, not treated as absent (L-1).

**Mode-2 message & signature-loop edges (7)**

- [`test_relay_zeroMerkleRoot_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L647) — relaying a zero Merkle root reverts (RLY-04).
- [`test_relay_badV_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L669) — a non-canonical `v` is rejected before `ecrecover`: "Bad v" (RLY-16).
- [`test_relay_highS_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L679) — a high-`s` (malleable) signature is rejected: "Bad s" (RLY-16).
- [`test_threshold_exactBoundary_strictGreater`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L707) — weight == threshold must fail; strictly greater passes.
- [`test_relay_indexOutOfRange_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L901) — a signature index == numberOfVoters: "Index out of range".
- [`test_relay_indexOutOfOrder_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L911) — non-increasing signature indices: "Index out of order".
- [`test_relay_zeroSignatures_notEnoughWeight`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L923) — zero signatures falls through to `NotEnoughWeight()`.

**`verify()` — Merkle membership, fees, refunds, reentrancy (8)**

- [`test_verify_unfinalizedZeroRoot_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L427) — an unfinalized (zero) stored root is rejected (RLY-01).
- [`test_verify_finalizedRoot_passes`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L433) — a valid proof against a finalized root passes.
- [`test_verify_merkleProofInvalid_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L771) — a proof for the wrong leaf is rejected.
- [`test_verify_invalidProtocolId_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L784) — a reserved protocol id (≤ 1) is rejected.
- [`test_verify_refundsOverpayment`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L466) — exactly the fee is forwarded; the overpayment is refunded (RLY-21).
- [`test_verify_feeReceiverReverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L726) — an ETH-rejecting fee collector reverts the call: "Transfer failed".
- [`test_verify_refundReceiverReverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L749) — an ETH-rejecting refund recipient reverts the call: "Refund failed".
- [`test_verify_reentrantReceiver_consistentNoExtraEth`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L872) — refund-callback reentrancy sees consistent state, pays one fee (DiD).

**`verify()` — the oldRelay fallback (7)**

- [`test_verify_oldRelayFallback_revertsOnFalse`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L453) — fails closed when `oldRelay.verify` returns false (RLY-13).
- [`test_verify_oldRelayFallback_passesOnTrue`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L460) — passes through the old relay's true verdict.
- [`test_verify_oldRelayFallback_refundsOverpayment`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L691) — forwards only the old fee and refunds the rest (M-1).
- [`test_verify_oldRelayFallback_tooLowFee_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L826) — `msg.value` below the old fee: "too low fee".
- [`test_verify_oldRelayFallback_exactFee_skipsRefund`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L835) — an exact fee skips the refund call entirely.
- [`test_verify_oldRelayFallback_zeroFee_fullRefund`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L845) — a zero old fee refunds the caller in full.
- [`test_oldRelay_readDelegation_belowBoundary`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L857) — the four read paths delegate to the old relay below the boundary.

**Getters, lifecycle & access windows (4)**

- [`test_merkleRoots_relayMode_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L790) — `merkleRoots()` is locked out in relay mode.
- [`test_toSigningPolicyHash_relayMode_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L796) — `toSigningPolicyHash()` is locked out in relay mode.
- [`test_getVotingRoundId_beforeStart_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L802) — a pre-start timestamp hits the underflow guard.
- [`test_getRandomNumber_beforeAnyRelay_returnsDefault`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L808) — returns `(0, false, ts)` before any random relay (RLY-20).

**Constructor / config validation (7)**

- [`test_ctor_rejects_zeroRewardEpochDuration`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L947) — a zero reward-epoch duration is rejected.
- [`test_ctor_rejects_zeroVotingEpochDuration`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L955) — a zero voting-epoch duration is rejected.
- [`test_ctor_rejects_zeroFeeCollection_relayMode`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L963) — relay mode requires a fee-collection address.
- [`test_ctor_allows_zeroFeeCollection_setterMode`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L971) — setter mode (no fees) permits a zero fee-collection address.
- [`test_ctor_rejects_zeroInitialSigningPolicyHash`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L980) — a zero initial policy hash (a bricked epoch) is rejected (L-4).
- [`test_ctor_oldRelay_incompatibleSetterMode_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L989) — a setter-mode old relay is incompatible with a relay-mode deployment.
- [`test_ctor_oldRelay_wrongStartTs_reverts`](../../test-forge/unit/protocol/implementation/Relay.t.sol#L998) — a timing mismatch with the old relay is rejected.

**Next:** [L4 — R2: bounded symbolic execution (Halmos)](04-R2-bounded-symbolic-halmos.md), which keeps the
real-bytecode fidelity but replaces "a few / random" with "all inputs up to a bound."
