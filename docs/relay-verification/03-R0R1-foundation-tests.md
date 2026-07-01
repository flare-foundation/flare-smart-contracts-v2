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
(The engagement grew this from 31 to 59 as part of hardening.) The suite spans all three `relay()` modes
and the auxiliary entry points:

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

**Next:** [L4 — R2: bounded symbolic execution (Halmos)](04-R2-bounded-symbolic-halmos.md), which keeps the
real-bytecode fidelity but replaces "a few / random" with "all inputs up to a bound."
