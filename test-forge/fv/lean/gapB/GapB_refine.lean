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

#print axioms loop_base
#print axioms exec_For

end GapB
