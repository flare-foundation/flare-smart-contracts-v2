# Relay.sol — Phase 3 Step 2: assembly mutation-surface & memory/arithmetic review

> **Historical scope:** this review is frozen to `relay-fix-3` before GSS
> governance. Its “exactly three” mutation-surface statement is not a claim
> about `relay-fix-3-gss`, which adds `processGSSMessage` and removes
> `governanceFeeSetup`. See [`safe-governance.md`](safe-governance.md) for the
> current extension.

A static read pass over `contracts/protocol/implementation/Relay.sol` (1747 lines) that *scopes*
the rest of Phase 3. Covers obligations AC-4 (mutation surface), AC-8 (no delegatecall/fallback),
memory-no-collision, R8 (unchecked/assembly arithmetic bounds), L6 (startingVotingRoundId monotonicity).
Line refs are to the current `relay-fix-3` revision.

## 1. State-mutating entry points (AC-4) — exactly three

| Fn | Line | Authorization | Writes |
|----|------|---------------|--------|
| `setSigningPolicy(SigningPolicy)` | 321 | **`onlySigningPolicySetter`** (219: `require(msg.sender == signingPolicySetter)`) | `startingVotingRoundIds[epoch]` (1141), `toSigningPolicyHashPrivate[epoch]` (1153) |
| `governanceFeeSetup(bytes,RelayGovernanceConfig)` | 475 | **relayed governance message** (signature-gated via the quorum, not `msg.sender`) | fee config state |
| `relay()` | 507 | **signature quorum** over the message (the Phase-1/2 verified gate) | `stateData` (1333, 1490), `merkleRootsPrivate[id][round]` (1384), `isSecureRandomMap` bit (679) |

All other externals (`getVotingRoundId`, `toSigningPolicyHash`, …) are `view`. **Conclusion (AC-4):**
the mutation surface is confined to these three; every `sstore` in the file (679, 1141, 1153, 1333, 1384,
1490) sits inside one of them and targets one of the slots above. No hidden write path.

## 2. No dangerous low-level control flow (AC-8)

- **No `delegatecall` / `callcode` / `selfdestruct`** anywhere (grep-confirmed). The only external `call`s
  are the `staticcall` to `ecrecover` (precompile 0x01) and the M-1 fee-forward to the old relay.
- **No `fallback()` / `receive()`** in `Relay`. (The string "fallback" at line 1563 is a comment about the
  *old* relay's fallback, in the M-1 fee-forwarding code.)
- **Conclusion (AC-8):** no proxy/upgrade/destruct surface; control flow can't be hijacked via a
  fallback or delegate. The contract is not upgradeable.

## 3. Memory-slot layout & non-collision (memory-no-collision)

Fixed scratch offsets, used relative to an allocated `memPtr` (the Solidity free pointer `mload(0x40)`),
defined at lines 164–175:

```
M_0=0  M_1=32  M_2=64 (signingPolicyHashTmp)  M_3=96 (existingSigningPolicyHashTmp)
M_4=128  M_5=160 (stateData ⟂ isSecureRandom)  M_6=192 (merkleRoot)  M_7=224 (randomNumber)  M_8=256 (signatureStart)
```

- The region is allocated from the free pointer, so it does not alias Solidity-managed memory.
- **M_5 is intentionally reused** for two purposes (`stateData` and `isSecureRandom`) at offset 160 — they
  are live in **disjoint phases** of `relay()` (policy/threshold handling vs. random-quality handling), so
  the reuse is safe *provided* the two phases never interleave a read of one over a write of the other.
- **Finding (memory-no-collision):** the slot map is internally consistent and the M_5 dual-use is the one
  spot needing a temporal-disjointness argument. This is exactly the kind of property the **T2-MEMORY**
  Kontrol obligation (Step 7) should discharge mechanically; until then it rests on this review. No other
  slot is dual-purposed.

## 4. Arithmetic safety (R8)

- **No Solidity `unchecked { }` blocks** exist. Solidity-level arithmetic (e.g. the `totalWeight` loop at
  347–349) therefore carries 0.8 overflow checks.
- **All assembly arithmetic is wrap-by-nature** (EVM `add`/`mul` do not revert), so safety rests on
  **operand bounds**, which the code establishes up front in `setSigningPolicy` (321):
  - `totalWeight < 2**16` (line 350) — the **16-bit weight bound** (this is exactly the `uint16` model the
    Kontrol signature-loop proof relies on; the weight accumulator therefore cannot overflow: ≤ 300·65535
    ≪ 2²⁵⁶).
  - threshold is range-checked against `totalWeight` via `threshold·THRESHOLD_BIPS ∈ [totalWeight·MIN_BIPS,
    totalWeight·MAX_BIPS]` (351–358).
- **The one arithmetic edge to verify mechanically (R5/Step 4):** the cross-epoch threshold *scaling*
  `threshold · thresholdIncreaseBIPS / THRESHOLD_BIPS` uses **truncating integer division**; its SMT model
  must match EVM `div` exactly. Recommend unit-testing the scaling formula in isolation first.
- **Finding (R8):** no Solidity unchecked blocks; assembly arithmetic is bounded by the `setSigningPolicy`
  preconditions (weights 16-bit, totalWeight < 2¹⁶); the only nontrivial item is the truncating-division
  threshold scaling, routed to R5.

## 5. startingVotingRoundId monotonicity (L6) — trusted-setter assumption

`setSigningPolicy` deliberately does **not** enforce non-decreasing `startVotingRoundId` across epochs
(documented at lines 335–342): an on-chain `require` would conflict with legitimate setter-driven
configurations. The reward-epoch decision matrix in `relay()` *assumes* it. On pure-relay deployments the
value is instead written by the Mode-1 `relay()` path from relayed policy metadata, where the invariant is
carried transitively by the quorum's signature over the signing-policy hash.

- **Finding (L6):** this is a **trusted-setter (FlareSystemsManager) premise**, in the RLY-06 family — it
  is documented, not provable on-chain, and stays an explicit assumption. The relay()-side consumption of
  it *is* in scope for the Step-4 lifecycle proofs (given the assumption, the decision matrix is correct).

## Summary of Step-2 outcomes

| Obligation | Outcome |
|-----------|---------|
| AC-4 mutation surface | ✅ exactly 3 entries (`setSigningPolicy`/`governanceFeeSetup`/`relay`); all `sstore`s accounted for |
| AC-8 no delegatecall/fallback | ✅ none; not upgradeable; only `staticcall` ecrecover + M-1 fee call |
| memory-no-collision | ✅ consistent; M_5 dual-use needs temporal-disjointness (→ T2-MEMORY, Step 7) |
| R8 unchecked/assembly arithmetic | ✅ no Solidity unchecked; bounded by `totalWeight<2¹⁶`/16-bit weights; truncating-div scaling → R5 |
| L6 startingVotingRoundId monotonicity | ⚠️ trusted-setter assumption (documented), relay()-side consumption → Step 4 |

These confirm the access-control model the AC obligations rest on and bound the Kontrol memory work, with
no new mutation paths or dangerous control flow discovered.
