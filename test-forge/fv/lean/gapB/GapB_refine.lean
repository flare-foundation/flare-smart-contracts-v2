import EvmYul.Yul.Interpreter

open EvmYul EvmYul.Yul EvmYul.Yul.Ast

namespace GapB
open EvmYul.Yul

-- L_base: when the loop condition evaluates to 0, the For-loop exits, returning the post-condition state
-- (overwritten back onto the outer state). First symbolic brick of the refinement; no `sorry`.
theorem loop_base (fuel : Nat) (cond : Expr) (post body : List Stmt) (s s₁ : EvmYul.Yul.State)
    (hcond : EvmYul.Yul.eval fuel cond none (EvmYul.Yul.State.mkOk s) = .ok (s₁, ⟨0⟩)) :
    EvmYul.Yul.loop (fuel + 1 + 1) cond post body none s = .ok (EvmYul.Yul.State.overwrite? s₁ s) := by
  unfold EvmYul.Yul.loop
  simp only [hcond]
  rfl

-- exec unfolds a For statement to `loop` (consuming one fuel).
theorem exec_For (fuel : Nat) (cond : Expr) (post body : List Stmt) (s : EvmYul.Yul.State) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.For cond post body) none s
      = EvmYul.Yul.loop fuel cond post body none s := by
  unfold EvmYul.Yul.exec
  rfl

-- L_step: one loop iteration. With an `Ok` state, a condition evaluating non-zero, and a body+post that
-- complete to `Ok` states (no break/continue/leave), `loop (fuel+2)` reduces to running the For-loop again
-- on the post-iteration state s₃ (the `overwrite?`/`reviveJump`/`mkOk` ops are identities on `Ok`).
theorem loop_step (fuel : Nat) (cond : Expr) (post body : List Stmt)
    (sa : EvmYul.SharedState .Yul) (va : VarStore)
    (s₁ s₃ : EvmYul.Yul.State) (sb : EvmYul.SharedState .Yul) (vb : VarStore) (x : EvmYul.UInt256)
    (hcond : EvmYul.Yul.eval fuel cond none (EvmYul.Yul.State.Ok sa va) = .ok (s₁, x))
    (hx : x ≠ ⟨0⟩)
    (hbody : EvmYul.Yul.exec fuel (Stmt.Block body) none s₁ = .ok (EvmYul.Yul.State.Ok sb vb))
    (hpost : EvmYul.Yul.exec fuel (Stmt.Block post) none (EvmYul.Yul.State.Ok sb vb) = .ok s₃) :
    EvmYul.Yul.loop (fuel + 1 + 1) cond post body none (EvmYul.Yul.State.Ok sa va)
      = EvmYul.Yul.exec fuel (Stmt.For cond post body) none s₃ := by
  unfold EvmYul.Yul.loop
  -- reduce 👌(Ok ..) = (Ok ..), then eval (hcond), then the if (x ≠ 0), then body, post, overwrite?s.
  simp only [EvmYul.Yul.State.mkOk, hcond, if_neg hx, hbody, EvmYul.Yul.State.reviveJump, hpost,
             EvmYul.Yul.State.overwrite?]
  -- remaining goal is the Except match-identity `(match e with error e=>error e | ok s=>ok s) = e`.
  cases EvmYul.Yul.exec fuel (Stmt.For cond post body) none s₃ <;> rfl

#print axioms loop_base
#print axioms exec_For
#print axioms loop_step

end GapB
