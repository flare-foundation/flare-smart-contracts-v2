# L13 — Residual weaknesses & attack surface (proof-grounded review)

> **What you get from this level.** An honest, proof-grounded inventory of what could still go wrong in the
> **currently deployed-target `Relay.sol`** (`relay-fix-3`). It reads the whole verification effort *backwards*:
> the proofs establish what is sound, so the residual risk lives in what they **assume**, what they **don't
> cover**, and what was **deliberately deferred**. Everything here is cross-referenced to the claims ledger
> ([L10](10-claims-ledger-trust-and-residual.md)), the hardening log ([`relay-fixes.md`](../relay-fixes.md)),
> the security review ([`relay-security-review.md`](../relay-security-review.md)), and the contract source.

## Bottom line

**No proof surfaced a live, exploitable bug in the current code.** The security core — *acceptance requires
enough distinct registered voter weight, no voter double-counted* — is proven at four converging fidelities
(Lean ∀N∀K abstract, Lean ∀N on validated EVM incl. the literal 17-statement loop body with a faithful early
return, Kontrol ∀K on a model, Halmos bounded on the real bytecode). Every sharp edge found in the code is
either **gated**, **proven load-bearing**, or a **deferred item neutralized by another mechanism**.

"Weakness" therefore means the *residual risk surface*, which is of four honestly-different kinds. Each item
below is tagged with its **class**, **severity if it went wrong**, and **current status**.

| Class | Meaning | Is it a bug? |
|-------|---------|--------------|
| **trust boundary** | an assumption the proofs rest on (crypto, governance, external contracts) | no — attack surface *if* the assumption is false; irreducible by design |
| **coverage gap** | a place the proofs do not reach ("is what we proved about *exactly* the deployed bytes?") | possibly — where a bug could still hide |
| **deferred** | a known issue consciously accepted / documented, not fixed | known trade-off; mostly neutralized |
| **regression risk** | proven safe *today*, catastrophic if a future edit breaks it | no — a maintenance hazard |

This review is ordered by **how much attention each deserves**, not severity alone.

---

## 13.1 The baseline — what is proven safe (so weaknesses are seen against it)

Read this first, so the residuals are not mistaken for the whole picture. On the real compiled bytecode and/or
a [validated EVM semantics](CONCEPTS.md#18-validated-semantics-a-evm), the following are machine-checked:

- **Threshold soundness & no-double-count** — the [`RelaySigLoop.threshold_sound`](../../test-forge/fv/lean/RelaySigLoop.lean#L102) capstone (∀N∀K) and its contrapositive; lifted onto the deployed 17-statement loop body with real masked memory reads (R4b), corroborated bounded on real bytecode (`RelaySigFV`, `RelaySigParamFV`) and tied to the ∀K model by `RelayModelBridgeFV`.
- **The `ecrecover` guard triad** rejects the empty-return / stale-buffer failure mode and zero signer (`RelayEcrecoverSymbolicFV`, `RelayEcrecoverABI.t.sol`); canonical-ECDSA (`RelayCanonicalityFV`).
- **The whole `relay()` epoch-decision matrix**, threshold consistency, access control, constructor fail-closure, governance-nonce replay protection, Merkle & random binding, and fee conservation (the Halmos suite, bounded).
- **Cross-transaction storage invariants** — nonce/epoch monotonicity, setter immutability, hash/root write-once — for every function except `relay()` itself (Certora, C-1 discharged 2026-07), plus per-sequence forms on the real bytecode.

The residuals below are the *complement* of this list.

---

## 13.2 Tier 1 — code-local, worth attention

Low severity for the most part, but **live** — a maintainer or integrator should internalize each.

**T1-a · The `returndatasize() == 32` ecrecover guard is the highest-blast-radius line** — `Relay.sol:1305-1307`. *Class: regression risk.* The ecrecover output slot is pre-seeded with the attacker's `r` (the 67-byte `calldatacopy` at `Relay.sol:1245`), and on a bad signature precompile `0x01` returns *success with empty data and leaves that buffer untouched*. Remove or weaken this check and an attacker forges a "valid" signature by placing a target voter's address in the `r` field → threshold bypass. **Proven load-bearing today** (`RelayEcrecoverSymbolicFV` over all stale-buffer contents + the on-EVM regression), so not a current weakness — but the line that must survive every future edit. Two residual sub-gaps: the whole-`relay()` Halmos runs use a *total* built-in `0x01` that cannot exercise the empty-return mode (only the dedicated harness does), and "reviewed pattern == deployed bytes" rests on the assembly review. Ledger [OP-1](10-claims-ledger-trust-and-residual.md). The guard's client-side assumption is **cross-checked against the deployed precompile source** in [§13.8](#138-appendix--op-1-cross-checked-against-the-deployed-client-ecrecover-precompile).

**T1-b · `verifyCustomSignature()` is an unbound public signature oracle** — `Relay.sol:465-470` (review item **L-3**). *Class: deferred (doc-only).* It forwards the caller's raw `_messageHash` with **no chain-id / contract / nonce binding** (the RLY-02 domain-binding was added to `governanceFeeSetup` only). A third-party integrator using it for authorization can have the same quorum signatures **replayed** against an identical-policy Relay on another chain/deployment. The only mitigation is a NatSpec "callers MUST domain-separate" note — the risk is *exported to third parties the Relay team cannot control*. The strongest documentation-only residual; worth weighing even though it is by-decision.

**T1-c · The V1 proxies strip the `isSecureRandom` flag** — `FtsoProxy.sol:59-64,152-155` and `PriceSubmitterProxy.sol:35-49` (**RLY-12**, compounding **RLY-20**). *Class: deferred.* A live V1 consumer gets randomness with **no security signal** — possibly a bootstrap `0` — and `FtsoProxy` offers *no* quality-aware alternative at all (`PriceSubmitterProxy` at least has `getCurrentRandomWithQuality()`). "Migrate to V2" misses exactly the V1 callers at risk. Low-medium for any still-live V1 integration.

**T1-d · Two accepted rationales are thin enough to revisit** — both cheap to harden:
- **L-5 — irreversible fee-nonce bricking** (`Relay.sol:493`): one accepted message carrying a near-`uint256.max` nonce **permanently** locks all future fee configuration (no recovery short of redeploy). Needs a valid quorum signature, so it is a governance-trust risk, not an external exploit — but a sequential or bounded-delta nonce would remove the footgun at zero security cost.
- **`messageFinalizationWindowInRewardEpochs` unvalidated in the constructor** (`Relay.sol:266`): `0` ⇒ only the current epoch can ever finalize; very large ⇒ staleness protection is effectively off. It sits a few lines from the RLY-11 duration checks that *do* bound their inputs — an inconsistent-hardening gap a cheap `require` would close.

**T1-e · Off-chain-dependent residuals the contract cannot enforce:**
- **RLY-15** — `verify()` accepts `leaf == root` with an empty proof (`Relay.sol:1591-1597`): safe *only if* the off-chain leaf encoding is domain-separated from internal Merkle nodes; otherwise a type-confusion / second-preimage angle exists. Unenforceable on-chain (a leaf and an internal node are both 32 bytes).
- **L-6** — `startingVotingRoundIds` non-decreasing is comment-only (`Relay.sol:335-342`) and feeds the reward-epoch decision matrix (`Relay.sol:960-975`). The deferral rationale ("an on-chain `require` broke a legitimate test") hints the invariant may not hold for *all* valid setter configs — worth confirming rather than assuming.

---

## 13.3 Tier 2 — irreducible trust boundaries (by design)

Where the proofs *stop*. Attack surface **if** the assumption is false, but assuming them is the standard,
correct choice — they cannot be discharged inside an EVM proof. See
[uninterpreted functions & the ecrecover boundary](CONCEPTS.md#17-uninterpreted-functions-and-the-ecrecover-boundary).

- **MC-2 — ECDSA unforgeability** (`ecrecover` uninterpreted; isolated in Lean as the per-iteration `IterPremiseT`). **The entire accounting result is conditional on this** — the single largest concentration of trust. The literal model's value is that it shrinks the assumed surface to *exactly* this and nothing more.
- **MC-3 — the trusted signing-policy setter** (**RLY-06**; `setSigningPolicy` at `Relay.sol:321-460`). The contract does **not** validate zero-address / duplicate / canonical-order / weight-normalization. The no-double-count guarantee leans on the voter set being canonically ordered and distinct; it is *contained* on-chain by the strict-increasing-index and zero-signer guards (a duplicate counts at most once; a zero voter is unmatchable) but **not eliminated**. The widest governance trust surface.
- **MC-5 (`oldRelay`), MC-1 (keccak collision-resistance), MC-4 (OZ `MerkleProof` internals)** — trusted by design; the neighboring on-chain uses are proven (fee forwarding fail-closed via RLY-13; no `delegatecall`, so `oldRelay` cannot write this contract's storage; Merkle proof-element/alignment soundness at the call site).

Full register: [L10 §10.2](10-claims-ledger-trust-and-residual.md).

---

## 13.4 Tier 3 — model↔deployment coverage gaps

The question "did we prove about *exactly* the deployed bytes?" — where a bug could still hide behind green
proofs. See [bounded vs unbounded](CONCEPTS.md#10-bounded-vs-unbounded-proofs) and [refinement](CONCEPTS.md#16-refinement-and-the-simulation-relation).

- **BR-3 / deviations D1–D4 (especially D3)** — *the most genuine gap.* The Lean proofs run over `bodyL`, a **hand transcription** of the optimized-Yul loop; **no mechanical AST-equivalence** proof binds it to the compiled block. D3 specifically: the model returns immediately on accept, but the real code **writes the Merkle root then returns**, so the accept-*write* is verified as a *separate* piece (`sstore_reads_back`) rather than folded into the accounting composition — a seam where a bug in the accept-write path could live. Mitigated by the artifact-parity gate (FV solc output ≡ deployment artifact; optimized-Yul snapshot hash-bound); the unbound part is the transcription + D-deviations.
- **C-1 — Certora storage invariants are vacuous on `relay()` itself** (proven for every *other* function). `relay()`'s storage behaviour is covered only per-sequence at R2 + the Lean literal model. The assembly-barrier residual (the convergent Kontrol/Certora finding).
- **R5 composition seams** — the whole-`relay()` theorem (`relay_dispatch_loop_accept`) carries the calldata-decode setup as an explicit hypothesis, leaves the exec-level `.CALL` value-transfer wiring as a documented boundary (only the `transferBalance` primitive + bounded Halmos cover it), and keeps the D3 write unstitched. Breadth, not a new soundness fact.
- **A-EVM's weaker half** — the Yul control-flow layer the R4b/R5 proofs lean on hardest is validated by Yul semantic tests, *not* the execution-spec conformance corpus (which validates the opcode/memory layer). Hardenable by cross-validation against an independent Lean Yul semantics (e.g. powdr's — [verified compilation](CONCEPTS.md#19-verified-compilation)).
- **Halmos bounds (K≤3, N≤5)** — several ledger rows (epoch matrix, Merkle, randomness, fees, lifecycle) are R2-only and remain bounded; only the signature-loop accounting is lifted unbounded (R3/R4). A bug appearing only at large N/K would escape those rows.
- **K-2 — Kontrol proves a Solidity *model*** of the loop, tied to the bytecode only at K≤3 (`RelayModelBridgeFV`); a full bmc-depth-1 model↔bytecode bridge is a documented future step.

---

## 13.5 Tier 4 — deferred but negligible / neutralized

Verified present in the code, rationale sound, no action needed:

- **RLY-05** — truncating threshold scaling (`Relay.sol:981-991`): a sub-unit bias against an aggregate quorum; `RelayThresholdScalingFV` proves the rescale `neverWeakens` and cannot overflow.
- **RLY-08** — Mode-1 writes policy state before the aggregate is verified (`Relay.sol:1149-1163`): atomicity-safe — a failing threshold reverts and unwinds the writes, and the only external call in between is the ecrecover *staticcall* (a precompile, cannot re-enter), so intermediate state is never observable.
- **RLY-07** — the 35-byte return length discriminates the `protocolId==1` self-call path (`Relay.sol:1748`): unique today (it is the only non-empty return) and digest-backstopped (`returnHash == _messageHash`); proven the unique discriminator by `RelayReturnDiscriminatorFV`. *Structurally fragile* — any future change to `relay()`'s return shape silently breaks it — so it is a maintenance note, not a live weakness.
- **RLY-06/L-8** (neutralized by index ordering), **L-2** (refund-to-non-receiver is caller-self-inflicted), **L-7** (round-0 edge, unreachable in production).
- Note: **RLY-16/17/18** are *implemented* (belt-and-braces low-`s`/`v`, underflow guard, zero-signer), not deferred; **RLY-09/RLY-19** are effectively resolved (non-zero-root sentinel / `uint24` type makes `bytes3` lossless).

---

## 13.6 The through-line — assembly maintainability is the dominant real risk

The dominant *real* risk is not any single item; it is **inline-assembly maintainability**. Three silent-at-the-
Solidity-level failure modes stand out, all currently safe:

1. **Guard removal** — dropping or weakening the `returndatasize()==32` / zero-signer / strict-index checks (T1-a).
2. **An early `return` inserted into the RLY-08 window** (`Relay.sol:1149`→`1340`) would leak an unverified signing policy — the write-before-verify pattern relies entirely on there being *no* success-return before the accept gate.
3. **Drift between the packed-`StateData` bit offsets** (`Relay.sol:85-144`) and the struct field order, or between the hand-tracked scratch-memory slot liveness and its comments — either would silently corrupt an adjacent field.

None is enforced by the type system; the comments (`"NO CODE SHOULD BE ADDED HERE"`, `"if you change this, you have to adapt the assembly"`) are the only source-level guard. **This is exactly what the FV suite catches on change** — the Halmos gate (60 proofs + 29 anti-vacuity controls, [CEX discipline](CONCEPTS.md#7-what-is-a-cex-counterexamples-and-why-half-the-suite-celebrates-them)), the [hole-free](CONCEPTS.md#13-hole-free-and-print-axioms) Lean bytecode refinement, and the Certora storage invariants. It is the strongest argument for keeping the three CI gates green on every future edit.

---

## 13.7 Suggested cheap hardening (optional)

None is required for soundness; each removes a documented footgun at low cost:

1. **Bound the governance-fee nonce** (L-5) — sequential, or a bounded per-step delta — to remove the irreversible-bricking path (`Relay.sol:493`).
2. **Validate `messageFinalizationWindowInRewardEpochs`** in the constructor (`Relay.sol:266`), matching the RLY-11 duration-bound treatment.
3. **Add a quality-aware getter to `FtsoProxy`** (RLY-12) so V1 consumers can read the `isSecureRandom` flag, or document the migration path more forcefully.
4. **Strengthen the `verifyCustomSignature` domain-separation guidance** (L-3) — or, if feasible, bind `address(this)`/chain-id into the custom-signature digest as RLY-02 did for `governanceFeeSetup`.

---

## 13.8 Appendix — OP-1 cross-checked against the deployed client (`ecrecover` precompile)

T1-a's guard is load-bearing *only because of* a specific low-level behaviour of the `ecrecover` precompile
(ledger [OP-1](10-claims-ledger-trust-and-residual.md)). That behaviour is a property of the **client**, not
of `Relay.sol` — so it was cross-checked directly against the exact precompile source the Flare node runs
(2026-07-16). Verdict: **the OP-1 assumption as-assumed == as-implemented.**

**Provenance — where the code actually is.** `ecrecover` is *not* in go-flare's own tree. The C-chain EVM
(`coreth`) carries no `core/vm/contracts.go`; it imports the EVM and pins it in `coreth/go.mod`:
[`github.com/ava-labs/libevm v1.13.15-0.20251016142715-1bccf4f2ddb2`](https://github.com/flare-foundation/go-flare/blob/1a2d11b6fb0cb730fe15aaa9bbb2772ddf65bcb5/coreth/go.mod#L20)
→ **libevm commit [`1bccf4f2ddb2`](https://github.com/ava-labs/libevm/tree/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d)**. `coreth` does **not** override `0x01` (it carries only the
standard precompile test vectors, e.g. `coreth/core/vm/testdata/precompiles/ecRecover.json`). All links below
are permalinks to that pinned commit.

**The decisive code** (verbatim, at the pin):

- [`contracts.go` L49](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/contracts.go#L49) — `0x01 → &ecrecover{}`, registered in every fork map ([L49](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/contracts.go#L49)/[L58](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/contracts.go#L58)/[L71](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/contracts.go#L71)/[L85](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/contracts.go#L85)/[L99](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/contracts.go#L99)).
- [`contracts.go` L196-225 — `ecrecover.Run`](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/contracts.go#L196-L225):

  ```go
  if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
      return nil, nil          // bad v / out-of-range r,s  → empty output, NO error
  }
  ...
  pubKey, err := crypto.Ecrecover(input[:32], sig)
  if err != nil { return nil, nil }                    // unrecoverable → empty output, NO error
  return common.LeftPadBytes(crypto.Keccak256(pubKey[1:])[12:], 32), nil   // 32 bytes on success
  ```
- [`contracts.go` L178-187 — `RunPrecompiledContract`](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/contracts.go#L178-L187): errors **only** on `ErrOutOfGas`; otherwise passes `Run`'s `(output, err)` straight through — so `(nil, nil)` stays a success with empty output.
- [`instructions.go` L748-774 — `opStaticCall`](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/instructions.go#L748-L774): on `err == nil` pushes success `temp.SetOne()`, copies the return via `scope.Memory.Set(retOffset, retSize, ret)`, and sets `interpreter.returnData = ret`.
- [`memory.go` L35-45 — `Memory.Set`](https://github.com/ava-labs/libevm/blob/1bccf4f2ddb28ff440f9e24f46506a2e98ad2a0d/core/vm/memory.go#L35-L45): `copy(m.store[offset:offset+size], value)` with **no pre-zeroing** — an empty `value` copies **0 bytes**, leaving the output region's prior contents intact.

| OP-1 assumption | Evidence (pinned client source) | Verdict |
|---|---|---|
| ecrecover is precompile `0x01` | `contracts.go` L49 (+ all fork maps) | ✅ met |
| does not revert on a bad signature | `Run` returns `nil,nil` (L209/L220); `RunPrecompiledContract` errors only on gas (L178-187) | ✅ met |
| success with **empty** return data (`returndatasize()==0`) | `ret == nil`; `interpreter.returnData = ret` (`instructions.go` L748-774) | ✅ met |
| **leaves the output buffer unmodified** (stale-read hazard) | `Memory.Set` copies `min(size, len(ret))=0` bytes, no memset (`memory.go` L44) | ✅ met |
| CALL success flag = 1 even on a bad sig | `temp.SetOne()` on `err==nil` (`instructions.go`) | ✅ met |
| 32 bytes only on valid recovery | `LeftPadBytes(…, 32)` (`contracts.go` L224) | ✅ met |
| s-malleable (looser than the EIP-2 tx rule) | `ValidateSignatureValues(v, r, s, false)` — `homestead=false` (`contracts.go` L207) | ✅ met — matches the ledger note that Relay adds its own low-`s`/`v` check (RLY-16) |

**The chain end-to-end:** a bad signature → `Run` returns `(nil, nil)` → the precompile call *succeeds* with
empty return → `opStaticCall`'s `Memory.Set` copies **nothing** into the 32-byte output region → that region
still holds the attacker's `r` (pre-seeded by Relay's `calldatacopy` at `Relay.sol:1245`) → and
`RETURNDATASIZE` is `0`. So `Relay.sol`'s `require(returndatasize() == 32)` (`Relay.sol:1305-1307`) is exactly
what stands between "empty return / stale buffer" and a forged-signature acceptance — and the client behaviour
it depends on is confirmed present.

**Scope & caveat.** This verifies the *operational ABI and control flow* — precisely what OP-1 asserts. It does
**not** verify the elliptic-curve math inside `crypto.Ecrecover` / libsecp256k1; that is the cryptographic
hardness assumption **MC-2** ([§13.3](#133-tier-2--irreducible-trust-boundaries-by-design)), separate and
irreducible. The check is against go-flare `main` (HEAD `1a2d11b6`) → libevm `1bccf4f2ddb2`; the `ecrecover`
logic is byte-stable across geth/coreth/libevm history, but to bind it to the *deployed* binary it should be
re-confirmed against the exact go-flare **release tag** the Flare/Songbird validators run.

---

## Method & provenance

This review was produced by reading the verification corpus *backwards* — the claims ledger's assumption
register and "what is not claimed" ([L10 §10.2/§10.6](10-claims-ledger-trust-and-residual.md)), the deferred/
accepted items in [`relay-fixes.md`](../relay-fixes.md) and [`relay-security-review.md`](../relay-security-review.md),
and a direct read of the current `Relay.sol` — and cross-checking each residual against the neighboring proof
that *does* cover it, so every "weakness" is stated with its exact boundary. It reflects `relay-fix-3` as of
2026-07-16. Nothing here is a newly-discovered vulnerability; it is the honest complement of the proven surface.

**Next:** [L10 — Claims ledger, trust & residual](10-claims-ledger-trust-and-residual.md) for the formal register,
or [`relay-fixes.md`](../relay-fixes.md) / [`relay-security-review.md`](../relay-security-review.md) for the
per-issue hardening history.
