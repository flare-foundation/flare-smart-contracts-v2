# Relay.sol — Gap B: bytecode-level ∀N refinement (foundation + plan)

**Goal.** Lift the Phase-A Lean theorem (`test-forge/fv/lean/RelaySigLoop.lean`, signature-loop threshold
soundness ∀N ∀K over the *abstract algorithm*) to the **actual compiled EVM/Yul of `relay()`** — so the
∀N∀K guarantee holds for the deployed bytecode, not just the algorithm. This is the research-grade tier;
this document is the **honest foundation**: validated tooling, the real subject, the simulation relation,
the refinement theorem, the proof obligations, and a candid effort estimate. **It is not a completed
proof** — the proof itself is multi-week work, deliberately not faked.

## Why a theorem prover (not Halmos/Kontrol) is required here

For the bytecode↔algorithm link, Halmos and Kontrol *execute the real EVM semantics*, so they are the most
faithful tools — but both are bounded (Halmos in K; Kontrol's N=10 was empirically intractable, 12h/0).
The *only* way to get ∀N over the **real bytecode** is an **inductive refinement against a validated EVM
semantics inside a theorem prover**. A hand-rolled mini-EVM would be *less* faithful than Halmos running
the actual bytecode — so it is explicitly rejected (it would be a false bridge).

## Validated base: EVMYulLean

- **Tool:** NethermindEth/EVMYulLean — a Lean 4 formalization of EVM + Yul semantics (Lean `v4.22.0`,
  mathlib `v4.22.0`, with FFI keccak/sha2). Cloned and built under `/tmp/evmyul` (toolchain auto-fetched
  via elan). This provides the *validated* semantics; we do not re-derive EVM.
- **API (confirmed by reading the source):**
  - Yul AST: `EvmYul/Yul/Ast.lean` — `inductive Expr`, `inductive Stmt` (Yul blocks, for-loops, assignments,
    function calls).
  - Interpreter (the validated semantics): `EvmYul/Yul/Interpreter.lean` —
    `def exec (fuel : Nat) (stmt : Stmt) (codeOverride : Option YulContract) (s : State) : Except Yul.Exception State`.
  - `State` (`EvmYul/Yul/State.lean`): the Yul machine state — locals, memory, calldata, storage, etc.
  - Primops (`EvmYul/Yul/PrimOps.lean`): `add`, `and`, `mload`, `staticcall`, … the opcodes the loop uses.

## The concrete subject: the real compiled loop

Extracted via `forge inspect Relay irOptimized` (3697 lines, with `@src` source-maps back to Relay.sol).
The signature loop is one of the `for { } … { }` blocks (e.g. IR line ~324/963), recognisable by:
`and(mload(...), 0xffff)` (weight read & mask = Relay.sol:1327), the `staticcall(...ecrecover...)` signer
recovery, the strict-index guard, and the accept gate. This Yul fragment — **the actual deployed logic** —
is what the refinement targets (encoded as a `Yul.Stmt`).

## The refinement: simulation relation + theorem

Phase A already gives the abstract side:
```
RelaySigLoop.loop      : List Nat → Nat → Nat → List Nat → (Nat × Nat)   -- (weights) weight nui (sigIdxs)
RelaySigLoop.ValidRun  : List Nat → Nat → List Nat → Prop                -- strict-increase / in-range
RelaySigLoop.threshold_sound : accept ⟹ total registered weight > threshold   (∀N ∀K, machine-checked)
```

Gap B adds a **simulation relation** `R` tying EVMYulLean's concrete `State` to the abstract state, and a
refinement theorem that `exec` of the loop preserves it (target Lean, *to be proved* against EVMYulLean):
```lean
-- R s (w, sigs, weight, nui): the Yul State s encodes the abstract loop state
--   • the calldata signing-policy region decodes to weights `w` (each lane & 0xffff)
--   • the calldata signature region decodes to the index stream `sigs`
--   • the loop locals (weight accumulator, nextUnusedIndex) hold `weight`, `nui`
--   • ecrecover is the uninterpreted matcher (modeling-contract A2)
def R (s : Yul.State) (w sigs : List Nat) (weight nui : Nat) : Prop := …

theorem loop_refines
    (fuel : Nat) (s s' : Yul.State) (w sigs : List Nat) (weight nui : Nat)
    (hR : R s w sigs weight nui)
    (hexec : Yul.exec fuel sigLoopStmt none s = .ok s') :
    ∃ weight' nui', R s' w sigs weight' nui' ∧
      (weight', nui') = RelaySigLoop.loop w weight nui sigs := by
  …  -- induction on the loop iterations / fuel; per-opcode lemmas below

-- Corollary: the deployed loop's accept decision satisfies the Phase-A soundness, for ALL N and K.
theorem bytecode_threshold_sound … := …   -- transfer RelaySigLoop.threshold_sound through loop_refines
```

## Proof obligations (the remaining work)

1. **Encode** the extracted Yul loop fragment as a `Yul.Stmt` (faithful to the IR; validated by replaying
   it under `exec` against the existing Halmos/concrete vectors — differential check vs real EVM).
2. **Per-opcode lemmas** against EVMYulLean primops:
   - `and(mload(weightSlot), 0xffff)` evaluates to `w.getD idx 0` (the masked 16-bit weight) under `R`;
   - the strict-index guard `idx ≥ nextUnusedIndex ∧ idx < N` corresponds to `ValidRun.cons`'s premises;
   - `weight := add(weight, …)` is the abstract `weight + w[idx]`;
   - the accept gate `gt(weight, threshold)` is the abstract `threshold < weight`.
3. **ecrecover / keccak**: keep uninterpreted (A1/A2) — model EVMYulLean's `staticcall` to 0x01 as the
   abstract matcher so a matched signature contributes its weight (consistent with the whole engagement).
4. **Loop induction**: `exec` of the `for` body preserves `R` (one iteration ↔ one `loop` step), then close
   over fuel/iteration count to cover all K; N is the (arbitrary) decoded calldata length — giving ∀N∀K.
5. **Transfer**: compose `loop_refines` with `RelaySigLoop.threshold_sound` ⇒ `bytecode_threshold_sound`.

## Honest effort & status

| Piece | Status |
|------|--------|
| Validated EVM/Yul semantics (EVMYulLean) | obtained; building (`/tmp/evmyul`, Lean 4.22 + mathlib) |
| Phase-A abstract proof (∀N∀K) | ✅ done & machine-checked (`lean/RelaySigLoop.lean`) |
| Real Yul subject extracted | ✅ done (`forge inspect`, with source-maps) |
| Simulation relation `R` + theorem statement | ✅ specified (above) |
| Per-opcode lemmas, loop induction, transfer | ⏳ **the remaining multi-week effort** |

**Realistic effort:** encoding the loop + the memory/calldata decoding relation + the opcode lemmas +
fuel/iteration induction against an unfamiliar 50+-file semantics is **person-weeks-to-months**, and is the
standard cost of bytecode-level functional verification (cf. KEVM/eth-isabelle case studies). This document
+ the built tooling + the Phase-A proof are the foundation; the proof is scoped, not completed.

**Pragmatic alternative (recommended before committing months):** **Certora** has native loop/state
invariants over real bytecode and may discharge the ∀N statement directly without a hand-written refinement
— likely a far better ROI than a full EVMYulLean refinement, and worth a spike first.

## What is *already* assured without Gap B

Even without the bytecode-level ∀N refinement, the deployed contract has: real-bytecode invariant at K≤3
(`RelayModelBridgeFV`, Halmos), unbounded-in-K on a faithful model (Kontrol, N∈{3,5}), and the abstract
algorithm ∀N∀K (Lean). Gap B would replace the "faithful model" caveat with the real bytecode for all N —
incremental assurance over an already-strong stack, at high cost.
