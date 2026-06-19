# Gap B — bytecode-level ∀N refinement: RESUMABLE CHECKPOINT

**Goal:** lift the Phase-A Lean theorem (`test-forge/fv/lean/RelaySigLoop.lean`, sig-loop threshold
soundness ∀N∀K, abstract algorithm) to Relay's **actual compiled Yul**, by a refinement proof against the
**validated EVMYulLean semantics**. "Closed properly" = a HOLE-FREE (no `sorry`/`axiom`) Lean development
proving the encoded loop refines `RelaySigLoop.loop` under EVMYulLean's `exec`, transferring
`threshold_sound`, with the encoding differentially validated against the real compiled IR.

**Working principle:** every committed Lean file must check with no `sorry`/`axiom`. Partial progress is
committed as *completed lemmas*, never as holes. This file is the resume point.

---

## STATUS (update every checkpoint)

- **Current step:** B-1 (build EVMYulLean) — in progress (mathlib cache fetch running).
- **Done:** API study complete (facts below). Phase-A proof done (`../RelaySigLoop.lean`, hole-free).
- **Next:** finish build → B-2 (drive `exec` in a tiny proof) → B-3 (encode loop + relation) →
  B-4 (per-step refinement) → B-5 (induction + transfer + differential-validate).

## How to resume (toolchain)

```bash
# EVMYulLean (validated EVM/Yul semantics) — Lean 4.22.0 + mathlib + FFI:
cd /tmp && git clone --depth 1 https://github.com/NethermindEth/EVMYulLean evmyul2
cd evmyul2 && lake exe cache get && lake build      # elan auto-fetches 4.22.0 from lean-toolchain
# host has: elan/lean (~/.elan/bin), openjdk (/usr/local/opt/openjdk/bin), solc 0.8.27 (~/.local/solc)
```
The Gap-B proof is a lake project under `test-forge/fv/lean/gapB/` that `require`s EVMYulLean + re-states
the Phase-A defs (or imports them). Build with `lake build` once EVMYulLean is built/cached.

## EVMYulLean API facts (so we never re-derive)

- **Yul AST** (`EvmYul/Yul/Ast.lean`, namespace `EvmYul.Yul.Ast`):
  - `Literal := UInt256`; `Identifier := String`; `PrimOp := Operation .Yul`.
  - `Expr : | Call (PrimOp ⊕ YulFunctionName) (List Expr) | Var Identifier | Lit Literal`.
  - `Stmt : | Block (List Stmt) | Let (List Identifier) (Option Expr) | ExprStmtCall Expr
            | Switch Expr (List (Literal × List Stmt)) (List Stmt) | For Expr (List Stmt) (List Stmt)
            | If Expr (List Stmt) | Continue | Break | Leave`.
    NOTE: `For cond post body` has NO init (optimizer's ForLoopInitRewriter); init is hoisted out.
- **State** (`EvmYul/Yul/State.lean`): `State : | Ok (SharedState .Yul) VarStore | OutOfFuel | Checkpoint Jump`.
  - `VarStore := Finmap (Identifier ↦ Literal)` (`EvmYul/Yul/Wheels.lean`) — the Yul locals.
  - `SharedState .Yul` holds memory/calldata/storage (the EVM machine state).
  - `Jump : Continue/Break/Leave (SharedState .Yul) VarStore` — control-flow checkpoints.
- **Interpreter** (`EvmYul/Yul/Interpreter.lean`):
  - `exec (fuel : Nat) (stmt : Stmt) (codeOverride : Option YulContract) (s : State) : Except Yul.Exception State`.
    Fuel-based. `Block`, `Let`, `If`, `ExprStmtCall`, `Switch`, `For→loop`, `Continue/Break/Leave`.
  - `loop (fuel) (cond) (post body : List Stmt) (codeOverride) (s) : Except Exception State` — evaluates
    `cond` (via `eval`); if `0` exits restoring the outer varstore; else `exec body`, handle
    Break/Leave/Continue, `exec post`, then recurse on `For`. Uses varstore save/restore notations
    (`👌` save, `✏️⟦s⟧?` restore, `🔁/💔/🚪` continue/break/leave, `🧟` un-checkpoint).
  - `eval (fuel) (expr) (codeOverride) (s) : Except Exception (State × Literal)` — expression value.
  - `Let vars (some (Call (inl prim) args))` ⇒ `evalArgs` then `execPrimCall` binds result to `vars`.
- **PrimOps** (`EvmYul/Yul/PrimOps.lean`): `Transformer := State → List Literal → Except Exception (State × Option Literal)`.
  - binary ops (`add`, `and`) via `execBinOp (f : Primop.Binary)`; `mload` via a machineState op
    (reads memory). The opcode→transformer dispatch is in the interpreter's `execPrimCall`.

## Design of the refinement (target)

- **Encode** the sig-loop core as `Yul.Stmt.For`: cond = "more signatures", body = read index `idx`,
  guard `idx ≥ nui ∧ idx < N` (strict-increase), `weight := add(weight, and(mload(wSlot(idx)),0xffff))`,
  `nui := idx+1`. ecrecover (`staticcall` 0x01) abstracted as the uninterpreted matcher (A2).
- **Relation** `R (s : Yul.State) (w sigs : List Nat) (weight nui : Nat)`: the VarStore binds the loop
  locals (`weight`,`nui`); the calldata/memory region decodes to `w` (lane & 0xffff) and `sigs`.
- **Per-step lemma** (B-4): one `loop` iteration with `exec body` refines `RelaySigLoop.loop`'s step,
  preserving `R`. **Loop induction** (B-5): induct on fuel/iterations ⇒ ∀K; N = decoded length (∀N).
- **Transfer**: compose with `RelaySigLoop.threshold_sound` ⇒ `bytecode_threshold_sound`.
- **Differential validation**: run EVMYulLean `exec` on the encoded `Stmt` vs the real contract on the
  existing test vectors — confirms the encoding matches the compiler output (the residual, validated not
  proven; same trust as any bytecode-loading step in KEVM/eth-isabelle).

## More API facts (Semantics dispatch — `EvmYul/Semantics.lean`)

- The opcode→Transformer dispatch is a big match on `(τ, Operation)`:
  - `.ADD => dispatchBinary τ UInt256.add`; `.AND => dispatchBinary τ UInt256.land`;
    `.MUL/.SUB/.DIV/.MOD/.LT/.GT/.EQ/.ISZERO/...` similarly; `.Yul, .MLOAD => λ yulState lits ↦ …`
    (reads memory at the given offset).
  - `Operation : OperationType → Type` is at `EvmYul/Operations.lean:564` (uppercase EVM opcode ctors).
  - `execPrimCall fuel prim vars args = multifill' vars (primCall fuel s prim args)`; `primCall` routes
    through the Semantics dispatch.
- **KEY: `exec`/`eval` are COMPUTABLE.** For CONCRETE inputs they reduce — so a concrete loop execution can
  be proved equal to the abstract result by `native_decide`/`decide`/`rfl`. Symbolic ∀-proofs need
  unfolding + induction (the hard part; `loop`'s varstore checkpointing is intricate).

## Refined strategy (concrete-first, then symbolic) — keeps every step hole-free

1. **B-2 / concrete refinement (achievable):** encode the accumulation loop as a `Yul.Stmt.For`
   (`while i<n: weight := add(weight, weights[i]); i := i+1`) and prove by `native_decide` that, for several
   concrete weight lists, `exec`'s result equals `RelaySigLoop.sumTake`. This is a *bounded but
   validated-EVM-semantics* check — strictly more than the foundation doc (it runs the REAL Yul interpreter
   and matches the abstract algorithm). Commit it.
2. **B-4/5 / symbolic refinement (hard):** attempt the inductive `loop`-vs-`sumTake` proof (∀ weights, ∀ K).
   Commit only the lemmas that check hole-free; if `loop`'s checkpoint handling blocks full symbolic
   induction within available effort, commit the concrete-validated version + partial symbolic lemmas +
   honest status, and keep going across sessions.
- **Data-layout note:** the calldata→weights decoding (mload offsets) is the data-layout fidelity layer;
  for the accumulation refinement we model weights as the decoded list (validated by the concrete runs +
  the existing Halmos `RelayModelBridgeFV`), and prove the loop's control-flow + arithmetic under real Yul
  semantics. Full calldata-layout proof is the deepest residual (documented).

## Honest fidelity ladder (what each layer buys)

1. control-flow fidelity: the loop executed by REAL EVM/Yul semantics refines the algorithm (B-4/B-5).
2. data-layout fidelity: calldata→weights decoding in `R` matches the compiled memory layout
   (the harder part; may be modeled + differentially validated rather than fully proven).
3. encoding faithfulness: the `Yul.Stmt` = compiler output (differentially validated).
The residual is (3) [+ part of (2)] — the irreducible bytecode-loading trust, documented explicitly.
