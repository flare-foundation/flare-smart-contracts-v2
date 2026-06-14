# Relay.sol — Robustness Fixes

**Branch:** `relay-fix-3` (off `origin/main` @ `264dab74`)
**Target:** `contracts/protocol/implementation/Relay.sol` (+ its interfaces / tests)
**Started:** 2026-06-14
**Status:** Substantive set + selected defence-in-depth notes + post-review hardening complete on `relay-fix-3`. Implemented & tested: RLY-02, RLY-03 (incl. RLY-14), RLY-01, RLY-13, RLY-21, RLY-10, RLY-11, RLY-04, **RLY-16, RLY-17, RLY-18, RLY-22**, and security-review **M-1, L-1, L-4**. Documented (no code): RLY-06, **RLY-07, RLY-09, RLY-15, RLY-19, RLY-20**, and **L-2, L-3, L-6, L-7**. Deferred: RLY-05, RLY-08, RLY-12; review L-5 (strictly-increasing nonce, accepted). **Foundry 31 passing · Hardhat Relay 54 + Submission + EndToEnd 36 = 93 passing.** See "Security-review follow-ups" at the end + `docs/relay-security-review.md`.

This document records, issue by issue, exactly what is changed in `Relay.sol`
to address the findings collected from the internal AI audit runs (the
`ai-audit-reports` `develop` branch) and the dedicated relay audits. Each issue
is proposed, discussed/challenged, agreed, then implemented **with tests** on
this branch. **Nothing is committed until explicitly confirmed.**

---

## Working process

1. Propose the fix for the next issue (root cause, exact change, risks, tests).
2. Challenge / discuss → agree.
3. Implement on `relay-fix-3` + add/extend tests; run them.
4. Record the final change here; mark the issue ✅. Move to the next.
5. Commit only on explicit confirmation.

**Status legend:** ⬜ Proposed · 🟡 Agreed (implementing) · ✅ Implemented & tested · 📝 Documented (no code change) · ⏸️ Deferred · ❌ Won't fix (documented)

---

## Global constraints / notes

- `relay()` is ~930 lines of inline assembly. Assembly-touching fixes are higher-risk and need explicit tests; assembly reverts use `revertWithMessage(ptr, "msg", <len>)` with a hand-counted byte length.
- Relay is **non-proxy** (constructor + immutables, redeployed fresh via `redeploy-relay.ts`), so storage-layout shifts are acceptable. New state vars are still **appended at the end**; `relay()` assembly references storage via `.slot` (resolved at compile time), so it stays correct.
- Some fixes change signed-message / ABI surfaces (e.g. governance digest, events). Those require matching off-chain (`scripts/libs/protocol/*.ts`) and consumer updates — flagged per issue.
- Tests: see "Testing approach" below.

---

## Testing approach — **Both** (confirmed 2026-06-14)

Baseline must be green before the first change: install deps, compile, run the existing `Relay` suite.

- **Hardhat regression:** `test/unit/protocol/implementation/Relay.test.ts` (~2700 lines, example-based) — must stay green; extended per fix.
- **New Foundry tests:** `test-forge/unit/protocol/implementation/Relay.t.sol` (forge available; doubles as the substrate for later formal verification with Halmos/Kontrol) — focused per-fix tests.

---

## Proposed fix order (by severity, then impact; grouped by code area to limit re-test churn)

| # | ID | Sev | Area / function | Touches asm? | One-line fix approach | Status |
|---|-----|-----|-----------------|:---:|------------------------|:---:|
| 1 | RLY-02 | **Med** | `governanceFeeSetup` / `RelayGovernanceConfig` / `_verifyCustomSignature` | no | bind `address(this)` + strictly-increasing nonce; move fee-write after verify; emit event | ✅ |
| 2 | RLY-03 | **Med** | `relay()` random branch + storage + events + off-chain libs | **yes** | **adopt true Merkle-proven random** (port `relay-fix-random-2`): random becomes a proven Merkle leaf stored in `toRandomNumberPrivate`; ADD monotonicity guard; RESTORE the safety checks that branch dropped | ✅ |
| 3 | RLY-01 | High→bounded | `verify()` | no | `require(root != 0)` before Merkle check | ✅ |
| 4 | RLY-13 | Note (funds) | `verify()` oldRelay fallback | no | `require(success)` on `oldRelay.verify`; don't silently forward fee | ✅ |
| 5 | RLY-21 | Low | `verify()` | no | refund `msg.value - fee` overpayment | ✅ |
| 6 | RLY-10 | Low/Med | constructor | no | **Option A**: relay mode ⇒ require `feeCollectionAddress != 0`; no setter | ✅ |
| 7 | RLY-11 | Low | constructor | no | require `rewardEpochDurationInVotingEpochs > 0` and `votingEpochDurationSeconds > 0` | ✅ |
| 8 | RLY-06 | Low | `setSigningPolicy` | no | **documented only** — trusted setter (FlareSystemsManager) must ensure no zero/duplicate voters; no on-chain validation | 📝 |
| 9 | RLY-04 | Low | `relay()` Mode-2 | **yes** | reject `merkleRoot == 0` finalizations | ✅ |
| 10 | RLY-14 | Note | `relay()` random branch | **yes** | normalize `isSecureRandom` to {0,1} — **folded into RLY-03** | ✅ |
| 11 | RLY-18 | Note | `relay()` signature loop | **yes** | reject recovered signer `== address(0)` ("Zero signer") | ✅ |
| 12 | RLY-16 | Note | `relay()` signature loop | **yes** | enforce low-`s` and `v ∈ {27,28}` (defence-in-depth) | ✅ |
| 13 | RLY-17 | Note | `governanceFeeSetup` | no | guard `lastInitializedRewardEpoch - 1` underflow | ✅ |
| 14 | RLY-05 | Low | `relay()` threshold scaling | **yes** | round threshold up (ceil) instead of truncating | ⏸️ |
| 15 | RLY-19 | Note | `setSigningPolicy` | no | type-enforced by `uint24 rewardEpochId` — documented | 📝 |
| 16 | RLY-07 | Note | `_verifyCustomSignature` | no | 35-byte discriminator invariant documented (typed-decode deferred) | 📝 |
| 17 | RLY-08 | Note | `relay()` Mode-1 | yes | atomicity-safe; structural reorder deferred | ⏸️ |
| 18 | RLY-09 | Note | `relay()` / `isFinalized` | — | resolved by RLY-04 (non-zero roots) — documented | 📝 |
| 19 | RLY-15 | Note | `verify()` / leaf encoding | no | off-chain domain-separation documented in NatSpec | 📝 |
| 20 | RLY-22 | Note | events / API | no | event-signature regression test (Foundry) | ✅ |

**Out-of-`Relay.sol` (scope decision):**
- RLY-12 (legacy `FtsoProxy`/`PriceSubmitterProxy` random getters drop `_isSecureRandom`) — different files.
- RLY-20 (`getRandomNumber` deterministic in bootstrap) — overlaps RLY-04; resolved alongside.

**Decisions (2026-06-14):**
- **Scope:** substantive set first — RLY-02, 03, 01, 13, 21, 10, 11, 06, 04 — then reassess.
- **RLY-03:** adopt the `relay-fix-random-2` **true Merkle-proven random** redesign (chosen over the minimal guard). Breaking change (calldata trailer + `ProtocolMessageRelayed` event ABI + `IRelay` + off-chain libs). Must also (a) add the `votingRoundId > stored` monotonicity guard and (b) **restore** the safety checks that branch dropped — `ecrecover` returndatasize check and the `oldRelay` constructor compatibility checks.
- **Tests:** Hardhat regression + new Foundry.

---

## Fixes

### ✅ RLY-02 — `governanceFeeSetup` replay (Medium)

**Decision:** Option 1 (nonce as a struct field), **strictly-increasing (not sequential)** nonces, bind `address(this)`, verify-before-write, emit event.

**Root cause.** The signed digest `keccak256(abi.encode(_config))` bound neither a nonce nor `address(this)`, and the `protocolId == 1` relay path records no "consumed" marker — so an accepted governance message could be (a) re-applied repeatedly within the signing policy's validity window and (b) replayed on a redeployed Relay on the same chain.

**Change.**
- `IRelay.RelayGovernanceConfig`: added `uint256 nonce` (after `chainId`).
- `IRelay`: added event `RelayGovernanceFeeConfigured(uint8 indexed protocolId, uint256 feeInWei, uint256 nonce)` and getter `governanceFeeNonce()`.
- `Relay`: added `uint256 public governanceFeeNonce` (appended storage — non-proxy, `relay()` uses `.slot` symbolically so unaffected). Rewrote `governanceFeeSetup`:
  1. digest is now `keccak256(abi.encode(_config, address(this)))` — binds the deployment (closes cross-deployment replay);
  2. `require(_config.nonce > governanceFeeNonce, "nonce too low")` then `governanceFeeNonce = _config.nonce` — strictly increasing, gaps allowed;
  3. fee writes moved to **after** `_verifyCustomSignature` succeeds;
  4. emit `RelayGovernanceFeeConfigured` per fee.

**Ordering note.** The nonce check sits *after* signature verification (and the "too old signing policy" check). Rationale: a replayed message is validly signed, so it still reaches the nonce check and is rejected — while the existing failure-path tests (which revert earlier on chainId/descriptionHash/verification) keep their original revert reasons. A cheap pre-verify nonce check was rejected to avoid disturbing that ordering.

**Off-chain / ABI impact.** `RelayGovernanceConfig` gains a field (breaking struct ABI). Governance signers must now sign `keccak256(abi.encode(_config, address(this)))` with a strictly-increasing `nonce`. The only in-repo consumer is the Hardhat test (updated). No deployment script references it.

**Files.** `contracts/protocol/implementation/Relay.sol`, `contracts/userInterfaces/IRelay.sol`, `test/unit/protocol/implementation/Relay.test.ts`, `test-forge/unit/protocol/implementation/Relay.t.sol` (new reusable harness).

**Tests.**
- Hardhat ("Governance fee changing"): happy path applies fee + increments nonce + emits event; replay → `nonce too low`; non-sequential bump (1→5) accepted; stale nonce (3 < 5) rejected. Suite: **46 passing**.
- Foundry (`Relay.t.sol`, new harness): `test_signingPolicyHash_matchesContract` (validates the harness's signing-policy-hash reimplementation against a setter-mode Relay), happy-path + replay, strictly-increasing non-sequential nonce, address-binding (`Invalid config hash` for a wrong-address digest). **4 passed**.

**Residual.** RLY-17 (`lastInitializedRewardEpoch - 1` underflow) shares this function and is intentionally deferred to its own item (#13).

**Status:** ✅ Implemented & tested on `relay-fix-3` (uncommitted).

---

### ✅ RLY-03 — true Merkle-proven random + monotonicity (Medium) — folds in RLY-14

**Decision:** adopt the `relay-fix-random-2` true-Merkle-proven-random redesign; proof verified **inline** in `relay()`; a **new** `RandomNumberRelayed` event (`ProtocolMessageRelayed` left unchanged); add the **monotonicity guard** (the actual RLY-03 fix the branch lacked); fold in RLY-14 (`isSecureRandom` normalization); keep `getRandomNumber` returning `0` in bootstrap; **leaf format kept exactly as the branch defines it** (off-chain commitment unchanged).

**Root cause.** (a) The "random number" was `keccak256(merkleRoot)` — a meaningless hash, not the protocol's real random. (b) The live random pointer (`stateData.randomVotingRoundId`) was advanced **unconditionally**, so a stale, never-relayed, still-in-window older round could be relayed *after* a newer one and **regress** the reported current random (permissionless griefing of FTSO/FlareSystemsManager random consumers).

**Change (`Relay.sol`).**
- New storage `mapping(uint256 votingRoundId => uint256) toRandomNumberPrivate` (appended after `governanceFeeNonce`).
- New assembly helper `processRandomMerkleProof` (the branch's, **cleaned** of its `// revert if not 100` debug leftover): on the random path, after threshold is met, it reads the calldata trailer, rebuilds `leaf = keccak256(votingRoundId(32) ‖ value(32) ‖ isSecure(32))`, folds the proof with OZ sorted-pair hashing, requires it equals the signed `merkleRoot`, and stores `toRandomNumberPrivate[votingRoundId]`.
- New memory slots `M_7_randomNumber=224`, `M_8_signatureStart=256`; `signatureStart` is stashed to `M_8` right after the signature count (avoids stack-too-deep deep in the random branch).
- Random branch rewritten: **RLY-14** normalize `isSecureRandom` to {0,1}; verify+store the proven value (always, for historical); set the historical `isSecureRandomMap` bit (always); **monotonicity** — advance the live pointer (`randomVotingRoundId`/`isSecureRandom`) only if `votingRoundId > stored`; emit `ProtocolMessageRelayed` (unchanged) then the new `RandomNumberRelayed`.
- `getRandomNumber()` / `getRandomNumberHistorical()` now read `toRandomNumberPrivate` (old `keccak256(merkleRoot)` derivation removed).
- `IRelay`: new event `RandomNumberRelayed(uint32 indexed votingRoundId, uint256 randomNumber, bool isSecureRandom)`.

**Calldata layout (random protocol only).** `selector(4) ‖ signingPolicy ‖ message(38) ‖ sigCount(2) ‖ signatures(67·k) ‖ randomNumber(32) ‖ proof(32·d)`. Non-random and `protocolId==1` paths are unchanged (no trailer).

**Deliberately NOT ported from the branch (its regressions).** Kept main's `ecrecover` returndatasize check, the `oldRelay` constructor compatibility checks, and the 11-tuple `stateData()` getter (did **not** move `StateData` into the interface — that move is what had forced the branch to comment out the constructor checks). Removed the branch's debug leftover.

**Off-chain / ABI impact.** Random-protocol relay calldata gains the trailer; off-chain `scripts/libs/protocol/RelayMessage.ts` `encode` updated to append `randomNumber + merkleProof` when `isRandomNumberGeneratingProtocolMessage` is set. New `RandomNumberRelayed` event for indexers. *(Residual: `RelayMessage.decode` does not yet parse the trailer — encode/relay works; decode-trailer parsing tracked as a minor follow-up.)*

**Adversarial review.** A 6-lens review (memory-slot safety, calldata bounds, proof/leaf forgeability, monotonicity, event ABI, regressions) found **no defects**: scratch (`M_0..M_2`) preserves `M_5_stateData`/`M_6_merkleRoot`; event ordering correct; bounds safe (upstream "Not enough signatures" guarantees `_proofStart ≤ calldatasize`); leaf matches off-chain and is bound to the signed round; monotonicity closes the regression; event signature byte-lengths (40 / 49) exact; all kept-checks intact. One **negligible LOW accepted**: `getRandomNumberHistorical` treats `randomNumber == 0` as "not relayed" (a real relayed value of exactly 0 has probability ~2⁻²⁵⁶; consumers gate on `isSecureRandom`; could later gate presence on the merkle-root once RLY-04 lands).

**Tests.**
- Foundry (`Relay.t.sol`): `test_random_happyPath_storesProvenValue`, `test_random_monotonicity_staleRoundDoesNotRegress` (the core fix), `test_random_invalidProof_reverts`, `test_random_missingTrailer_reverts`. **8 passed** (with RLY-02).
- Hardhat: the 10 random-protocol tests migrated to supply the value+proof trailer (via a `prepareDataWithRandom` helper building a real Merkle tree); `getRandomNumber` assertions switched to the relayed value; new `RandomNumberRelayed` event asserted; monotonicity-aware assertions (`randomVotingRoundId >= round` + `getRandomNumberHistorical` proving the per-round value was stored). Suite: **46 passing**.

**Status:** ✅ Implemented & tested on `relay-fix-3` (uncommitted).

---

### ✅ RLY-01 — `verify()` accepts an uninitialized (zero) Merkle root (was High → bounded)

**Root cause.** With no root stored for `(protocolId, votingRoundId)`, `merkleRootsPrivate[...] == bytes32(0)`; `verify(pid, vrId, 0x0, [])` made OZ `processProofCalldata` return the zero leaf unchanged → `0 == 0` → `verify()` returned `true` for an unfinalized round.

**Fix (`verify()` `else` branch).** Load `root = merkleRootsPrivate[_protocolId][_votingRoundId]`; `require(root != bytes32(0), "not finalized")` before the proof check; the proof is then checked against the cached `root`. Now consistent with `isFinalized()`. No assembly touched; the `oldRelay` fallback path is unchanged.

**Complementary to RLY-04** (relay-side: stop *storing* a zero root). With both, this guard is belt-and-braces but remains correct.

**Tests.**
- Hardhat: new test "Should reject verification against an unfinalized (zero) root [RLY-01]" → reverts `"not finalized"`; the existing relay-then-verify tests still pass. Suite: **47 passing**.
- Foundry: `test_verify_unfinalizedZeroRoot_reverts` (zero root reverts) and `test_verify_finalizedRoot_passes` (relay a non-random root, then a leaf+proof verifies). **10 passing** total.

**Status:** ✅ Implemented & tested on `relay-fix-3` (uncommitted).

---

### ✅ RLY-13 — `oldRelay` fallback now fails closed (defensive; opencode High → Note)

**Root cause.** `verify()`'s pre-migration branch forwarded the full `msg.value` to `oldRelay.verify` and returned its result. If `oldRelay.verify` returned `false` *without reverting*, the fee was already transferred and the caller got `false` with no finalization or refund.

**Reachability.** The current/prior `Relay` reverts on verification failure (atomic — the value transfer unwinds), so this is not reachable with a same-implementation `oldRelay`. The fix is defensive against the `IRelay` bool return contract / any alternate old relay.

**Fix.**
```solidity
bool ok = oldRelay.verify{value: msg.value}(_protocolId, _votingRoundId, _leaf, _proof);
require(ok, "old relay verification failed");
return true;
```

**Tests.** Foundry: a parameterized `MockOldRelay` (satisfies the constructor's `signingPolicySetter()` + `stateData()` timing compatibility) — the fallback reverts `"old relay verification failed"` when the mock returns false, and passes when true. The existing Hardhat "verify on old and new relay contract" test covers the success path. **Foundry 12 passing; Hardhat 47.**

**Status:** ✅ Implemented & tested on `relay-fix-3` (uncommitted).

---

### ✅ RLY-21 — `verify()` refunds fee overpayment (Low)

**Root cause.** `verify()` swept the **entire** `msg.value` to `feeCollectionAddress`; any overpayment above `protocolFeeInWei[_protocolId]` was lost to the caller.

**Fix.** Forward only `fee` to `feeCollectionAddress`, then refund `msg.value - fee` to `msg.sender`; removed the old "sweep all" post-block. `verify()` performs no state writes, so the external calls (fee transfer, refund last) cannot corrupt contract state — checks-effects-interactions holds trivially; no `nonReentrant` needed. `IRelay.verify` NatSpec updated ("Overpayment … is refunded").

**Tests.**
- Foundry `test_verify_refundsOverpayment`: deploy with a 1000-wei fee for protocol 3, finalize a root, `verify{value: 5000}` → `feeCollectionAddress += 1000`, caller net cost `= 1000` (4000 refunded). **13 passing.**
- Hardhat: extended "Should verification work" — `verify{value: 2000}` against the 1000-fee protocol → `BURN_ADDRESS` (feeCollection) `+= 1000` only (overpayment refunded). **47 passing.**

**Status:** ✅ Implemented & tested on `relay-fix-3` (uncommitted).

---

### ✅ RLY-10 + RLY-11 — constructor input validation (Low / Low-Med)

**RLY-11 (epoch-duration positivity).** Constructor now requires `rewardEpochDurationInVotingEpochs > 0` and `votingEpochDurationSeconds > 0` (placed right after the threshold-increase check, before the initial-starting-round check). Prevents the div-by-zero panic in `getVotingRoundId` and the *silent-zero* result in the assembly `rewardEpochIdFromVotingRoundId` (EVM `div` by 0 returns 0).

**RLY-10 (fee-collection address) — Option A.** Constructor now requires
```solidity
require(_signingPolicySetter != address(0) || _initialConfig.feeCollectionAddress != address(0), "fee collection address zero");
```
i.e. in **relay mode** (where fees can be charged at construction or added later via `governanceFeeSetup`) the fee-collection address must be non-zero, so collected fees can't be burned. In setter mode (no fees possible) a zero address is allowed. No `feeCollectionAddress` setter added (stays constructor-set).

**Test impact.** 20 Hardhat relay-mode deploys used `feeCollectionAddress: ZERO_ADDRESS` (including the governance test, which adds fees later) — repointed to `BURN_ADDRESS` (inert for the fee-less tests; correct for the governance test).

**Tests.** Foundry `RelayConstructorTest` (4): rejects zero reward-epoch duration / zero voting-epoch duration / zero fee-collection in relay mode; allows zero fee-collection in setter mode. Hardhat "Constructor validation" describe (5): same + a valid-config sanity deploy. **Foundry 17 passing; Hardhat 52.**

**Status:** ✅ Implemented & tested on `relay-fix-3` (uncommitted).

---

### 📝 RLY-06 — zero/duplicate voters in `setSigningPolicy` (Low) — documented, not validated

**Decision (user).** The signing-policy setter on Flare is **FlareSystemsManager**, a trusted system contract. On-chain re-validation of voter well-formedness is therefore unnecessary; instead the trust assumption is documented.

**Resolution (documentation only, no logic change).**
- `IIRelay.setSigningPolicy` NatSpec now states the setter is trusted and **MUST** ensure: no zero-address voters, no duplicate voters, voters in canonical order, normalised weights — explicitly noting these are **not** re-validated on-chain (RLY-06).
- A matching comment was added in the `Relay.setSigningPolicy` implementation body.

**Mode-1 `relay()` (new-policy relay on relay chains).** Not changed: a new signing policy there is installed only when signed by the existing quorum, which vouches for its contents — the same trust basis. No assembly validation added.

**Tests.** None (no behavior change); existing suites unaffected (Foundry 17, Hardhat 52).

**Status:** 📝 Documented on `relay-fix-3` (uncommitted).

---

### ✅ RLY-04 — Mode-2 `relay()` rejects a zero Merkle root (Low)

**Root cause.** Mode-2 stored `merkleRootsPrivate[protocolId][votingRoundId] = merkleRoot` without a non-zero check. A zero root made `isFinalized()` return `false` despite the relay, and — because the already-relayed sentinel *is* the stored root — let the same round be re-relayed → duplicate `ProtocolMessageRelayed` event spam.

**Fix (assembly, Mode-2 path, after the `protocolId == 1` early return).**
```text
if iszero(mload(add(memPtrFor, M_6_merkleRoot))) { revertWithMessage(memPtrFor, "zero merkle root", 16) }
```
Applies to all `protocolId > 1` (including the random protocol, whose root is non-zero anyway). `protocolId == 1` (custom-signature) returns earlier and is unaffected. The stored root is now always non-zero, so the already-relayed sentinel and `isFinalized` are reliable — this also resolves RLY-09's "sentinel coupled to merkle-root" fragility and makes RLY-01's read-side guard belt-and-braces.

**Tests.** Foundry `test_relay_zeroMerkleRoot_reverts` (contrast: identical relay with a non-zero root finalizes, the zero-root one reverts). Hardhat "Should fail to relay a Mode-2 message with a zero merkle root [RLY-04]" → `revertedWith("zero merkle root")`. **Foundry 18 passing; Hardhat 53.**

**Status:** ✅ Implemented & tested on `relay-fix-3` (uncommitted).

---

## Substantive set complete — remaining notes (reassessment)

Agreed set done: **RLY-02, RLY-03 (+RLY-14), RLY-01, RLY-13, RLY-21, RLY-10, RLY-11, RLY-04** (+ RLY-06 documented). Remaining notes to decide on:

| ID | Sev | Essence | Resolution | Status |
|---|---|---|---|---|
| RLY-16 | Note | ECDSA s-malleability / v∉{27,28} unchecked | signature loop now rejects v∉{27,28} ("Bad v") and high-s ("Bad s") | ✅ |
| RLY-18 | Note | no zero-recovered-signer guard in asm | explicit `iszero(mload(M_2))` guard ("Zero signer") after the `returndatasize==32` check | ✅ |
| RLY-17 | Note | `lastInitializedRewardEpoch - 1` underflow (unreachable) | guarded with `> 0` in `governanceFeeSetup` | ✅ |
| RLY-22 | Note | hardcoded event-signature strings can desync from ABI | Foundry regression test asserts emitted `ProtocolMessageRelayed`/`RandomNumberRelayed` topic0 == canonical signatures | ✅ |
| RLY-19 | Note | `bytes3(rewardEpochId)` truncation > 2^24 | **type-enforced**: `SigningPolicy.rewardEpochId` is `uint24`, so `bytes3(...)` is lossless — documented in code | 📝 |
| RLY-07 | Note | `_verifyCustomSignature` 35-byte return sentinel | robust typed-discriminator needs an assembly return-format change (higher risk, no exploit); the 35-byte invariant is documented in `relay()` and `_verifyCustomSignature` | 📝 |
| RLY-09 | Note | already-relayed sentinel coupling | **resolved by RLY-04** (relayed roots are now non-zero) — `isFinalized` comment added | 📝 |
| RLY-15 | Note | `verify()` accepts `leaf==root`, empty proof when finalized | off-chain leaf domain-separation requirement documented in `IRelay.verify` NatSpec | 📝 |
| RLY-20 | Note | `getRandomNumber` returns 0 in bootstrap | accepted (consumers gate on `isSecureRandom`) — documented in `getRandomNumber` | 📝 |
| RLY-05 | Low | threshold rounding bias ≤1 unit | **deferred** (immaterial; optional `ceilDiv`) | ⏸️ |
| RLY-08 | Note | Mode-1 writes policy state before threshold met | **deferred** (atomicity-safe; structural asm reorder is risky for no exploit) | ⏸️ |
| RLY-12 | Low | legacy `FtsoProxy`/`PriceSubmitterProxy` drop `_isSecureRandom` | **deferred** — different contracts (not `Relay.sol`); separate scope | ⏸️ |

### ✅/📝 RLY-16/17/18/22 (implemented) + RLY-07/09/15/19/20 (documented)

- **RLY-16** (signature loop): after the strict-index checks and before `ecrecover`, `relay()` now rejects `v ∉ {27,28}` (`"Bad v"`) and `s > secp256k1n/2` (`"Bad s"`). Defence-in-depth on the verification path (malleability double-counting was already neutralized by strict index ordering). Tests: Hardhat (`v=0 → "Bad v"`, high-s → `"Bad s"`; `generateForgedSignatures` repointed to `v=27, r=0` so the `returndatasize` tests still hit `"ecrecover returned bad data"`); Foundry `test_relay_badV_reverts` / `test_relay_highS_reverts`.
- **RLY-18** (signature loop): explicit `"Zero signer"` guard after the `returndatasize==32` check (redundant with it — a successful recovery is never `address(0)` — kept for clarity/robustness). Inert for tests.
- **RLY-17** (`governanceFeeSetup`): the `lastInitializedRewardEpoch - 1` branch is now guarded by `lastInitializedRewardEpoch > 0` (unreachable today, made locally safe).
- **RLY-22** (events): Foundry `test_event_signatures_match_canonical` relays a non-random and a random message and asserts the emitted `ProtocolMessageRelayed` / `RandomNumberRelayed` topic0 equal the canonical signature hashes — guarding the hardcoded assembly event strings against drift. (`SigningPolicyRelayed` unchanged; not re-tested here.)
- **RLY-19** 📝: `SigningPolicy.rewardEpochId` is `uint24`, so `bytes3(rewardEpochId)` is lossless and matches the mapping key — no >2²⁴ truncation possible. Documented at the encoding site.
- **RLY-07** 📝: the proper fix (explicit protocol discriminator in `relay()`'s return) is an assembly return-format change — higher risk for a no-exploit note. Instead, the invariant "the 35-byte return length uniquely identifies the `protocolId==1` path" is documented in both `relay()` and `_verifyCustomSignature`.
- **RLY-09** 📝: largely resolved by RLY-04 — relayed roots are now non-zero, so the merkle-root-as-finalized-sentinel is reliable; `isFinalized` carries an explanatory comment.
- **RLY-15** 📝: `IRelay.verify` NatSpec now states that off-chain leaf encoding must be domain-separated from internal/root node hashes (the `leaf==root` empty-proof case is a standard Merkle property).
- **RLY-20** 📝: `getRandomNumber` comment documents the bootstrap `(0,false,ts)` return and that consumers must gate on `_isSecureRandom`.

**Status:** ✅/📝 Implemented/documented & tested on `relay-fix-3` (uncommitted).

---

## Security-review follow-ups (post-review hardening + coverage)

After the substantive set, a dedicated security review (`docs/relay-security-review.md`) surfaced one Medium and a Low cluster. The selected improvements are implemented here. **Foundry `Relay.t.sol`: 31 passing · Hardhat Relay 54 + Submission + EndToEnd 36: 93 passing.**

### ✅ M-1 — `verify()` oldRelay fallback now refunds overpayment (Medium)

The RLY-21 refund applied only to the new-relay path; the historical-round fallback forwarded the **entire `msg.value`** to `oldRelay.verify`, contradicting the documented refund guarantee. Fixed (option a): the fallback now reads `oldFee = oldRelay.protocolFeeInWei(_protocolId)`, `require(msg.value >= oldFee, "too low fee")`, forwards only `oldFee`, `require`s the old relay's success (`"old relay verification failed"`), then refunds `msg.value - oldFee` to `msg.sender` (`require(ok, "Refund failed")`). Test: `test_verify_oldRelayFallback_refundsOverpayment` (mock fee 700, `verify{value:5000}` on a historical round; asserts old relay nets +700 and caller −700). `MockOldRelay` gained `protocolFeeInWei`.

### ✅ L-1 — random `value == 0` no longer collides with the "not relayed" sentinel (Low)

`getRandomNumberHistorical` previously gated on `_randomNumber != 0`, so a legitimately relayed `value == 0` round was reported finalized yet absent. Now it gates on `require(merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0), "no random number")` (RLY-04 guarantees relayed roots are non-zero) and returns `toRandomNumberPrivate[_votingRoundId]` (which may be `0`). Test: `test_random_zeroValue_isReturnedNotAbsent`.

### ✅ L-4 — constructor rejects a zero `initialSigningPolicyHash` (Low)

`require(_initialConfig.initialSigningPolicyHash != bytes32(0), "initial signing policy hash zero");` (after the RLY-11 duration checks). Prevents a bricked pure-relay deployment seeded with a zero initial hash. Test: `test_ctor_rejects_zeroInitialSigningPolicyHash`. (Setter-mode tests that set the genesis policy via `setSigningPolicy` now pass a non-zero placeholder initial hash.)

### 📝 L-2 / L-3 — interface NatSpec hardening (documented)

- **L-2:** `IRelay.verify` NOTE — the overpayment refund is a value-bearing call; a contract caller must be able to receive ETH (or send exactly the fee), else `verify()` reverts.
- **L-3:** `IRelay.verifyCustomSignature` SECURITY note — it is a generic signature-quorum oracle (no chainId / contract / nonce binding); callers MUST domain-separate `_messageHash` themselves.

### 📝 L-6 — `startVotingRoundId` monotonicity: documented, **not** enforced on-chain (downgraded)

Initially implemented as a `require(_signingPolicy.startVotingRoundId >= startingVotingRoundIds[lastInitializedRewardEpoch])` in `setSigningPolicy`, but **reverted to a code comment**: an on-chain check pre-empted an existing voters-count revert and conflicted with legitimate setter-driven configurations (the existing test scenarios do not maintain strict start-round monotonicity). Like RLY-06, this canonical-ordering invariant is the trusted setter's (FlareSystemsManager) responsibility; the assumption is now documented at the `setSigningPolicy` site.

### 📝 L-7 — monotonic-random guard edge documented (Low)

Comment on the `votingRoundId > stored` guard noting the `votingRoundId == 0`-first-round under-report edge is unreachable on the production deployment (the first reward epoch starts at a non-zero voting round).

### ✅ Coverage additions

- **High gap** — cross-epoch random monotonicity: `test_random_monotonicity_acrossRewardEpochs` (relay epoch R+1's random, then an older in-window round; live pointer stays at R+1).
- **Medium gaps** — `test_random_malformedTrailerLength_reverts` (non-%32 trailer reverts), `test_random_deepMerkleProof` (multi-node proof fold), `test_random_isSecureNormalization` (message `isSecure` byte `2` folds to `1` in the leaf + stored flag), `test_threshold_exactBoundary_strictGreater` (weight `==` threshold fails, `>` passes), `test_verify_feeReceiverReverts` / `test_verify_refundReceiverReverts` (reverting receiver → `"Transfer failed"` / `"Refund failed"`; new `RevertingReceiver` helper).

Remaining Low-risk coverage gaps and the Halmos/Kontrol FV opportunities (see the review doc) are **deferred**.
