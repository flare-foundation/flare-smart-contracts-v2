# Relay.sol — Security Review (post-fix) + Test-Coverage Analysis

**Target:** `contracts/protocol/implementation/Relay.sol` on branch `relay-fix-3` (the RLY-01…RLY-22 fixes; see `docs/relay-fixes.md`).
**Method:** adversarial multi-agent review — 8 dimension reviewers (signature/threshold, relay() assembly safety, policy rotation, random subsystem, governance/custom-sig, verify/fees, invariants/access, fix-regressions); every raised finding independently refute-tested; plus a dedicated test-coverage analysis. Findings below are the **verified** set (false positives filtered).
**Date:** 2026-06-14.

**Headline:** No critical/high confirmed. **1 Medium** (introduced by the RLY-21 refund fix), and a set of Lows that cluster into a few root causes. The signature/threshold core and the RLY-03 random redesign were independently confirmed **sound** (no forgery, no double-count, no memory-safety or second-preimage issue, reentrancy-safe).

---

## Resolution status (implemented on `relay-fix-3`)

The improvements selected after this review have been implemented and tested (Foundry `Relay.t.sol`: **31/31**; Hardhat Relay 54 + Submission + EndToEnd 36: **93/93**).

| Finding | Disposition |
|---|---|
| **M-1** | **Fixed (option a).** Fallback now reads `oldRelay.protocolFeeInWei`, forwards only that, requires `msg.value >= oldFee`, refunds the remainder, and `require`s the old relay's success. Test: `test_verify_oldRelayFallback_refundsOverpayment`. |
| **L-1** | **Fixed.** `getRandomNumberHistorical` now gates presence on `merkleRootsPrivate[randomNumberProtocolId][_votingRoundId] != 0` (RLY-04 guarantees non-zero roots) and returns the value (which may be `0`). Test: `test_random_zeroValue_isReturnedNotAbsent`. |
| **L-2** | **Documented.** `IRelay.verify` NOTE: overpayment refund is a value-bearing call; a contract caller must be able to receive ETH or pay the exact fee. (Push-with-revert behaviour kept; couples with M-1.) |
| **L-3** | **Documented.** `IRelay.verifyCustomSignature` SECURITY note: it is a generic quorum oracle; callers MUST domain-separate `_messageHash` with `block.chainid`, the consuming contract, and a nonce. |
| **L-4** | **Fixed.** Constructor `require(initialSigningPolicyHash != bytes32(0))`. Test: `test_ctor_rejects_zeroInitialSigningPolicyHash`. |
| **L-5** | **Accepted trade-off.** Nonce kept **strictly-increasing** (deliberate); downside documented here. No code change. |
| **L-6** | **Documented, not enforced (downgraded).** An on-chain `startVotingRoundId` monotonicity `require` in `setSigningPolicy` conflicted with legitimate setter-driven configurations (broke an existing voters-count test by pre-empting its revert, and the existing test configs do not maintain strict start-round monotonicity). Like RLY-06/L-8, this canonical-ordering invariant is the trusted setter's (FlareSystemsManager) responsibility; recorded as a code comment in `setSigningPolicy`. |
| **L-7** | **Documented.** Comment on the monotonic-random guard noting the `votingRoundId == 0`-first-round edge is unreachable on the production deployment. |
| **L-8** | **Documented (RLY-06).** Trusted-setter assumption noted in `IIRelay.setSigningPolicy`. |

**Coverage added this round:** High gap (cross-epoch random monotonicity, `test_random_monotonicity_acrossRewardEpochs`); Medium gaps (`test_random_malformedTrailerLength_reverts`, `test_random_deepMerkleProof`, `test_random_isSecureNormalization`, `test_threshold_exactBoundary_strictGreater`, `test_verify_feeReceiverReverts`, `test_verify_refundReceiverReverts`). Remaining Low-risk gaps and the Halmos/Kontrol FV opportunities below are **not** done (deferred).

---

## Confirmed findings

### M-1 (Medium) — `verify()` oldRelay fallback does not refund overpayment (contradicts the RLY-21 spec)
**Where:** `verify()` oldRelay branch vs the new refund block; `IRelay.verify` NOTE ("Overpayment … is refunded").
**Issue:** RLY-21 added fee-only forwarding + overpayment refund **only on the new-relay path**. For a historical round (`_votingRoundId < startingVotingRoundIdForInitialRewardEpochId`) the call forwards the **entire `msg.value`** to `oldRelay.verify` and returns — so a caller that overpays (e.g. relying on the now-documented refund guarantee) loses the excess. The interface NOTE promises a refund unconditionally; the fallback path violates it.
**Impact:** Bounded fund loss (caller overpayment) during the migration window. Self-inflicted, no cross-account griefing.
**Fix options:** (a) on the fallback, read `oldRelay.protocolFeeInWei(_protocolId)`, forward only that, refund the remainder; or (b) scope the interface NOTE to the new-relay path and `require(msg.value == <oldFee>)` / document that delegated rounds follow the old relay's fee policy. (b) is the lower-risk doc-level fix; (a) makes the contract honour the spec uniformly.

### L-1 (Low, ×4 reviewers) — random `value == 0` collides with the "not relayed" sentinel
**Where:** `processRandomMerkleProof` writes `toRandomNumberPrivate[vrid] = value` unconditionally; `getRandomNumberHistorical` reverts on `_randomNumber == 0`; `getRandomNumber` returns `(0, isSecure, ts)`.
**Issue:** A relayed round whose proven random is exactly `0` is reported finalized by `isFinalized()`/`merkleRootsPrivate` but **absent** by `getRandomNumberHistorical` (reverts), and `getRandomNumber` can return `(0, true, …)`. Natural-keccak probability ~2⁻²⁵⁶, but a buggy/degenerate/adversarial off-chain aggregation could commit `value==0`. (This is RLY-20, which we *documented*; the review recommends actually fixing it — cheaply.)
**Fix:** Decouple presence from value — gate `getRandomNumberHistorical` on `merkleRootsPrivate[randomNumberProtocolId][_votingRoundId] != 0` (RLY-04 guarantees relayed roots are non-zero), then return the value (which may be 0); **and/or** reject a zero `value` word in `processRandomMerkleProof`. Removes the overload entirely.

### L-2 (Low) — `verify()` refund push reverts for contract callers that can't receive ETH
**Where:** `verify()` `msg.sender.call{value: refund}` + `require(refundOk, "Refund failed")`.
**Issue:** A contract caller that overpays and cannot accept ETH has its `verify()` revert (must pay the exact fee atomically). Caller-only (no cross-account griefing), but a behaviour change vs the old "sweep all" path.
**Fix:** Prefer **exact-payment** (`require(msg.value == fee)`) + document; or a pull-pattern (credit a withdrawable balance); or keep the push but don't revert the verification on refund failure. (Couples with M-1's resolution.)

### L-3 (Low) — generic `verifyCustomSignature` is an unbound signature oracle
**Where:** `verifyCustomSignature` / `_verifyCustomSignature` (RLY-02's `address(this)`+nonce binding was added to **`governanceFeeSetup` only**).
**Issue:** A third-party contract that calls `verifyCustomSignature(msg, H)` to authorise an action can have the same voter signatures **replayed** against an identical-policy Relay on another chain/deployment for the same `H` (no chainId / consuming-contract / nonce binding).
**Fix:** Document loudly in `IRelay.verifyCustomSignature` that callers MUST domain-separate `H` with `block.chainid`, the consuming contract address, and an application nonce; consider offering a binding-aware variant.

### L-4 (Low) — constructor accepts a zero `initialSigningPolicyHash`, bricking a pure-relay deployment
**Where:** constructor sets `toSigningPolicyHashPrivate[initialRewardEpochId] = initialSigningPolicyHash` with no non-zero check; reachable via `redeploy-relay.ts` if run before the next epoch's policy exists on the old relay.
**Fix:** `require(_initialConfig.initialSigningPolicyHash != bytes32(0), "initial signing policy hash zero");` and have `redeploy-relay.ts` assert the fetched hash is non-zero.

### L-5 (Low) — `governanceFeeSetup` can be permanently bricked by one over-high signed nonce
**Where:** RLY-02 strictly-increasing nonce (`require(_config.nonce > governanceFeeNonce)`).
**Issue:** A single accepted message carrying a near-`type(uint256).max` nonce locks out all future fee updates (no recovery path). This is the trade-off of *strictly-increasing* (chosen deliberately over sequential). It requires a valid signature set, so it's an operational/governance-trust risk, not an external exploit.
**Fix (if desired):** switch to sequential `require(_config.nonce == governanceFeeNonce + 1)`, or bound the per-step delta. **Decision point — you chose strictly-increasing; this is the documented downside.**

### L-6 (Low) — `startingVotingRoundIds` monotonicity not enforced on-chain (decision-matrix dependency)
**Where:** the reward-epoch matrix consults `startingVotingRoundIds[r+1]`; setSigningPolicy records `startVotingRoundId` without a monotonicity check.
**Fix (defence-in-depth):** in setSigningPolicy `require(_signingPolicy.startVotingRoundId >= startingVotingRoundIds[lastInitializedRewardEpoch])` (and `>= firstRewardEpochStartVotingRoundId`).

### L-7 (Low) — monotonic random guard skips the live-pointer update for the first round when `votingRoundId == 0`
**Where:** the `votingRoundId > stored` guard; on a deployment where the first secure random is round 0, `getRandomNumber()` under-reports `(value, false)`.
**Fix:** advance when `votingRoundId > stored` **OR** the pointer was never set (track a "set" flag / use `>=` for the first write). Narrow, deployment-specific.

### L-8 (Low, documented) — duplicate / zero-address voters not re-validated on-chain (RLY-06)
The "distinct authorized weight > threshold" guarantee rests on the trusted setter (FlareSystemsManager) and, in relay mode, on the current quorum signing the new policy. Confirmed **not** a one-tx exploit. You chose to document this (RLY-06); the review reaffirms a cheap optional hardening: enforce strictly-increasing voter addresses in `setSigningPolicy` (and while validating a relayed Mode-1 policy).

### Operational — RLY-03 trailer is a coordinated breaking change (liveness/migration)
Deploying this contract before **every** random-protocol relayer emits the `randomNumber + proof` trailer halts random finalization (the relay reverts `"No random number"`). Sequence the rollout (upgrade relayers first) or gate behind a switch. Not a code bug; a deployment requirement.

---

## Confirmed sound (selected "no-bug" verifications — confidence boosters)
- **RLY-16/RLY-18** read the correct memory slots in the correct order; no regression to the signature loop.
- **Threshold logic:** strict `weight > threshold`, increase-only; **no double-count** (strictly-increasing index ⇒ each policy entry counted once); no overflow.
- **Random binding:** `toRandomNumberPrivate[vrid]` can only be set to a value whose `keccak256(abi.encode(vrid, value, isSecure))` is a leaf under the **signed** `merkleRoot`; no forgery/replay/second-preimage; bound to the signed `(votingRoundId, isSecure)`.
- **Self-call** `address(this).call(_relayMessage)` cannot be coerced to forge a 35-byte return / reenter harmfully.
- **`verify()` fee/refund** external calls are reentrancy-safe (no state writes in `verify()`; CEI holds trivially).
- **RLY-04** zero-root rejection does not interfere with the random path (random roots are always non-zero).

---

## Test-coverage gaps (proposed additions)

Coverage is strong on the fixed behaviours (each RLY-xx has a regression test; Hardhat 54 + Foundry 21 + EndToEnd 36). Gaps, by risk:

| Risk | Area | Missing | Proposed test (framework) |
|---|---|---|---|
| **High** | Random monotonicity **across reward epochs** | `test_random_monotonicity_*` only relays `v` and `v+1` in the **same** epoch | Relay random for epoch R+1 then an older in-window round for epoch R; assert `getRandomNumber()` still returns R+1's value (Foundry) |
| Med | Random proof: malformed trailer length | `"Incorrect merkle proof"` branch (non-multiple-of-32 trailer) untested | Append a 33-byte trailer; assert revert `"Incorrect merkle proof"` (Foundry) |
| Med | Random proof: deep multi-node proof | Harness only builds a 2-leaf tree (proof loop runs once, one sorted-pair branch) | 4+ leaf tree forcing both `leaf<sibling` and `leaf>sibling` fold branches (Foundry) |
| Med | RLY-14 `isSecure` normalization | Only `0/1` tested; the `byte != 0 ⇒ 1` normalization (e.g. byte `2`) untested | Hand-encode a message with `isSecure=2`, leaf using `1`; assert success + normalized event/state (Foundry) |
| Med | Threshold **exact** boundaries (base + increase) | Tests use coarse N/2 vs N/2+1; exact `weight == threshold` / `threshold-1` and the increased-threshold boundary untested | Non-uniform weights; signatures summing to exactly threshold (pass) and threshold-1 (`"Not enough weight"`) (Foundry) |
| Med | Fee/refund to a **reverting receiver** | `"Transfer failed"` / `"Refund failed"` never exercised (all receivers are EOAs) | feeCollection = revert-on-receive contract → assert `"Transfer failed"`; caller = revert-on-receive → assert `"Refund failed"` (Foundry) |
| Low | RLY-17 `lastInitializedRewardEpoch-1` branch | only the happy side tested | governanceFeeSetup signed by the `R` policy when `lastInitialized = R+1` (Foundry) |
| Low | `getRandomNumber()` before any relay (RLY-20) | not asserted | fresh relay → `(0, false, ts)`, no revert (either) |
| Low | governanceFeeSetup with **multiple** FeeConfigs | only single-config tested | `[{2,1000},{5,2000}]` → both fees + two events (either) |
| Low | Message-finalization-window **exact** edge | upper edge covered; exact `L-W` vs `L-W+1` not pinned | relay at reward epoch exactly `L-W` (`"Message too old"`) and `L-W+1` (pass) (Foundry) |
| Low | `RandomNumberRelayed` payload fields | event test checks only topic0 | decode `topics[1]==vrid` and `(value, isSecure)` data (Foundry) |
| Low | Duplicate-voter acceptance (RLY-06) | no negative test encoding the documented trusted-setter assumption | relay/set a policy with a duplicate voter; assert accepted, with a comment (Foundry) |

## Formal-verification opportunities (reuse the `Relay.t.sol` harness)
- **Threshold soundness (Halmos):** `relay()` reverts whenever summed weight of the provided canonical, index-ordered signatures `< effective threshold`.
- **No-double-count (Halmos):** strictly-increasing index ⇒ accumulated weight ≤ Σ distinct policy-entry weights.
- **Random-proof binding (Halmos/Kontrol):** `toRandomNumberPrivate[vrid]` settable only to a Merkle-leaf value under the signed root.
- **Random monotonicity invariant (Kontrol):** `stateData.randomVotingRoundId` non-decreasing across any `relay()` sequence.
- **`isSecure` normalization (Halmos):** stored/emitted/leaf `isSecure == (byte != 0)`, consistently.
- **35-byte return discriminator (Kontrol):** only the `protocolId==1` path returns 35 bytes.
- **Fee conservation (Kontrol):** in `verify()`, feeCollection gets exactly `fee`, caller net-pays `fee`, contract retains 0 — for any `msg.value >= fee` (new-relay path).
- **Signing-policy-hash equivalence (Halmos):** lift the harness's dynamic cross-check of `calculateSigningPolicyHash` to a symbolic proof.

---

## Recommended priority
1. **M-1 + L-2** (one change to the `verify()` fee/refund design): make the fallback honour the refund spec, or scope the spec + use exact-payment. Quick.
2. **L-1** (random `value==0` sentinel): gate `getRandomNumberHistorical` presence on `merkleRootsPrivate != 0`. Quick, removes the cluster.
3. **L-4** (`initialSigningPolicyHash != 0`) + **L-3** (verifyCustomSignature NatSpec warning) + **L-6/L-7** guards: cheap hardening.
4. **L-5**: decide strictly-increasing vs sequential nonce (your call; trade-off documented).
5. **Coverage:** add the High gap (cross-epoch random monotonicity) + the Medium gaps; then pursue the Halmos/Kontrol invariants on the harness.

---

# Round 2 — re-review of the UPDATED contract (post M-1 / L-1 / L-4)

**Target:** `Relay.sol` @ commit `463fd59c` on `relay-fix-3` (after the Round-1 hardening landed). 1726 lines.
**Method:** adversarial multi-agent workflow — **11 dimension reviewers** (M-1 fallback, L-1 random presence, constructor, sig/threshold, asm/memory, random-asm, governance/custom-sig, verify/fee, state-machine, Mode-0 policy rotation, invariants/access); **every finding refute-tested through 3 independent lenses** (exploitability, correctness-vs-code, regression-from-fix; survives only with ≥2/3); plus **2 coverage angles** (behavioral + adversarial) and a **completeness critic**. 80 agents total.
**Date:** 2026-06-14.

**Headline: CLEAN.** Zero findings survived adversarial verification — the M-1/L-1/L-4 fixes introduced **no new defect**, and the previously-asserted-sound core was independently **re-confirmed against the code**. The critic re-derived the full `relay()` assembly memory layout and verified: `M_8` (signature start, `0x180`) is never clobbered by the signature loop / random-proof scratch / event logging; the random `sstore` precedes the `M_5` reuse (state persistence correct); the ecrecover input/output overlap (output into the `0x80` input window) is benign (the precompile reads input fully before writing); `protocolId==1` is the only non-empty return and never writes `merkleRootsPrivate`; and `governanceFeeSetup` reentrancy is safe (the re-entered `protocolId==1` path makes no external calls and writes no fee/nonce state).

## Verified-sound (the M-1 three-call fallback specifically)
The new `verify()` oldRelay branch makes three external calls (`protocolFeeInWei`, `verify{value:oldFee}`, refund `msg.sender.call`). Confirmed safe: `verify()` performs **no state writes**, so reentrancy into `relay()`/`verify()`/`governanceFeeSetup` during any of the three calls cannot corrupt or double-spend (it is plain CEI with no critical state). `oldRelay` is the trusted previous deployment (set once at construction); the refund recipient is arbitrary but only risks its own call (self-inflicted DoS, no cross-account griefing). No double-charge: the fallback `return true`s before the new-relay fee path.

## Silent-shadowing concern — investigated and refuted (would have been the only correctness gap)
The critic asked whether a **new-relay Mode-2 write** could ever target a `votingRoundId < startingVotingRoundIdForInitialRewardEpochId` — which the four read paths (`verify`/`merkleRoots`/`isFinalized`/`getRandomNumberHistorical`) unconditionally delegate to `oldRelay`, so such a write would be silently shadowed. **Verified unreachable** by reading the code: the lowest signing-policy hash ever stored is `initialRewardEpochId` (constructor), and `setSigningPolicy`/Mode-1 relay only add strictly-greater epochs; the relay gates at `Relay.sol:917` ("Wrong sign policy reward epoch", `messageRewardEpochId ≥ rewardEpochId`) and `Relay.sol:948` ("Delayed sign policy", `votingRoundId ≥ policy.startVotingRoundId`) together force every Mode-2 write to have `votingRoundId ≥ startingVotingRoundIdForInitialRewardEpochId`. The write domain and the read-delegation boundary coincide exactly; no shadowing is possible.

## Test-coverage gaps (this is where the actionable value is)

Coverage is strong (Foundry 31 + Hardhat 54 + EndToEnd 36; every RLY-xx and the M-1/L-1/L-4 happy paths have regression tests). The gaps below are **revert-branch / boundary** holes, prioritized:

| Risk | Area | What's missing | Proposed test (framework) |
|---|---|---|---|
| **High** | M-1 fallback `"too low fee"` (`Relay.sol:1545`) | `msg.value < oldFee` on the oldRelay branch never sent (existing test overpays 5000 vs 700) | MockOldRelay fee=700; `verify{value:699}(3,100,…)` ⇒ revert `"too low fee"` (Foundry) |
| **High** | M-1 fallback exact-fee / no-refund branch | `msg.value == oldFee > 0` (refund branch skipped) untested | `verify{value:700}`; assert old relay +700, caller −700, no refund call (Foundry) |
| **High** | `governanceFeeSetup` own negatives | in-loop `"invalid protocol id"` (config protocolId ≤ 1) and `"fee cannot be set"` (called on a setter-mode relay) untested (the existing hits are *constructor* checks) | config with `protocolId==1` ⇒ `"invalid protocol id"`; setter-mode relay ⇒ `"fee cannot be set"`; `nonce == governanceFeeNonce` pins the strict-`>` edge (either) |
| Med | M-1 fallback `oldFee==0` + overpay | full-refund-with-zero-fee combo untested | MockOldRelay fee=0; `verify{value:1234}`; caller net 0, returns true (Foundry) |
| Med | new-relay `verify()` `"merkle proof invalid"` / `"invalid protocol id"` | only `"not finalized"` + happy path tested; wrong leaf/proof against a *finalized* root, and `protocolId ≤ 1`, untested | finalize a root, `verify(pid,vrid,wrongLeaf,proof)` ⇒ `"merkle proof invalid"`; `verify(1,…)` ⇒ `"invalid protocol id"` (either) |
| Med | `"No random number"` short trailer (`Relay.sol:689`) | 1..31-byte trailer (partial random word) hits this branch; existing tests only assert `ok==false`, not the reason | append 31-byte trailer, bubble revert ⇒ assert `"No random number"` (Foundry) |
| Med | oldRelay **read**-delegation in isolation | `MockOldRelay` doesn't implement `getRandomNumberHistorical`/`merkleRoots`/`toSigningPolicyHash`/`isFinalized`; their `< boundary` delegation is unit-untested | extend mock with sentinels; assert delegation below boundary, local logic at/above (Foundry) |
| Med | relay-mode getter lockouts | `merkleRoots()` `"no access to merkle roots"` (`:1613`) and `toSigningPolicyHash()` `"no access…"` (`:1684`) never asserted | on relay-mode harness, `expectRevert` both (Foundry) |
| Med | `getVotingRoundId()` `"before the start"` (`:1673`) | underflow-guard revert never asserted | `expectRevert("before the start"); getVotingRoundId(firstTs-1)` (either) |
| Med | `verifyCustomSignature()` direct | only reached via `governanceFeeSetup`; its own happy path + `"Verification failed"` untested | call directly with valid + too-few signers (Foundry) |
| Med | Mode-1 `checkThresholdConsistency` `"total weight too big"` exact edge | sum `== 65535` pass / `== 65536` fail on the **relay()** path not pinned | relay() Mode-1 with weights summing to 65535 then 65536 (Hardhat) |
| Low | `getRandomNumber()` pre-relay tuple (RLY-20) | `(0,false,ts)` on a fresh relay never asserted | fresh relay ⇒ assert `(0,false,ts)` (either) |
| Low | Foundry signature-index checks | `"Index out of range"` / `"Index out of order"` only in Hardhat | hand-craft descending / out-of-range indices (Foundry) |
| Low | zero `numberOfSignatures` | `count==0` falls through to `"Not enough weight"` untested | 0-count trailer ⇒ `"Not enough weight"` (Foundry) |
| Low | `"Message too old"` / `"Wrong sign policy reward epoch"` window edge in Foundry | only Hardhat advances epochs enough to cross the window | push `lastInitializedRewardEpoch`, relay at window vs window+1 (Foundry) |
| Low | constructor oldRelay incompatibility in Foundry | Foundry `MockOldRelay` always matches; reverse setter/relay-mode mismatch + timing-mismatch reverts untested there | mismatched-mock variants ⇒ `"old relay incompatible"` / `"wrong … "` (Foundry) |
| Low | reentrancy receiver (defense-in-depth) | receivers that *revert* are tested; one that *re-enters* `verify()`/`relay()` during the refund is not | re-entrant receiver; assert outer call still consistent, no extra ETH extracted (Foundry) |
| Low | relay() Mode-1 accept exactly `MAX_VOTERS` (300) | only 301-reject + setter-path 300 tested | Mode-1 message with 300 voters ⇒ relays OK (Hardhat) |
| Low | non-random Mode-2 `isSecure` byte propagation | raw (non-normalized) byte into `ProtocolMessageRelayed` for a non-random protocol undocumented/untested | relay non-random with `isSecure=2`; assert event reflects raw byte (Foundry) |

## Critic Info/Low items (documentation / optional hardening)
- **L-6 invariant carries to the relay path transitively.** The L-6 comment defers monotonicity to the trusted local setter, but on **pure-relay** chains `startingVotingRoundIds` is written by the Mode-1 `relay()` path from *signature-bound* policy metadata — so the invariant is enforced transitively by the quorum's signature over the signing-policy hash, not by a local setter. Worth stating in the comment. (Trust model unchanged; severity Info.)
- **Mode-1 relayed policy skips RLY-06 voter checks** (no zero-addr/duplicate/order re-check). Security is carried by the **strictly-increasing signature index** (a duplicate voter is counted at most once) and ecrecover never returning `address(0)`. Worth documenting this linkage next to RLY-06.
- **`messageFinalizationWindowInRewardEpochs` is unvalidated** in the constructor (unlike the RLY-11 duration checks). `0` ⇒ only the current epoch can finalize; very large ⇒ staleness protection effectively disabled. Config-quality, not a vuln — consider a constructor bound or an explicit "accepted range" note.
- **`uint32 + 1` overflow in the random getters** (`Relay.sol:1635`, `:1665`): `randomVotingRoundId + 1` is computed in `uint32` before the `uint256` cast; at `type(uint32).max` it reverts. Astronomically unreachable (Info). Optional robustness: cast before adding (`uint256(x) + 1`).
- **Migration handshake** (`redeploy-relay.ts`): the new relay seeds `lastInitializedRewardEpoch = initialRewardEpochId` and the first `setSigningPolicy` must be exactly `+1`. No on-chain check that FlareSystemsManager's bookkeeping agrees; relies on operational cutover sequencing. Operational note (L-4 already fail-closes a zero next-policy hash).

## Round 2 — resolution status (implemented on `relay-fix-3`)

All selected improvements implemented + tested. **Foundry `Relay.t.sol`: 31 → 52 passing · Hardhat 93 passing.** (Suite later grown to **59** by the signing-policy-rotation lifecycle port.)
- **Coverage (all four bundles):** added the High/Medium revert-branch and boundary tests — M-1 fallback `"too low fee"` / exact-fee-no-refund / zero-fee-full-refund; `governanceFeeSetup` `"invalid protocol id"` + `"fee cannot be set"`; `verifyCustomSignature` direct + insufficient-weight; `verify()` `"merkle proof invalid"` / `"invalid protocol id"`; relay-mode getter lockouts; `getVotingRoundId` `"before the start"`; `getRandomNumber` pre-relay default; `"No random number"` short trailer; oldRelay read-delegation (mock extended); signature `"Index out of range"` / `"Index out of order"` / zero-sig; constructor oldRelay incompatibility + timing mismatch; relay()-path accept-exactly-300-voters (Hardhat); and a reentrancy defense-in-depth test.
- **Deliberately skipped (low value):** exact `totalWeight` 65535/65536 off-by-one on the relay() path (the `"total weight too big"` revert + happy 300-voter accept are already covered; an exact off-by-one is fragile to craft) and a Foundry re-implementation of the `"Message too old"` window edge (already covered in Hardhat).
- **Critic Info/Low items — documented in code** (no behavior change): L-6 transitive-via-signed-policy-hash note; RLY-06 index-ordering linkage at the signature loop; shadowing-unreachable invariant at the `verify()` read boundary; migration-handshake note in the constructor. `messageFinalizationWindowInRewardEpochs` bound and the `uint32 + 1` getter edge left as-is (Info).
