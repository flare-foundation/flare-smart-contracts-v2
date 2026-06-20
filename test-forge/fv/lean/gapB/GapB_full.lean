import EvmYul.Yul.Interpreter

open EvmYul EvmYul.Yul EvmYul.Yul.Ast

namespace GapB

-- ============ control-flow bricks ============
theorem exec_For (fuel : Nat) (cond : Expr) (post body : List Stmt) (s : EvmYul.Yul.State) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.For cond post body) none s
      = EvmYul.Yul.loop fuel cond post body none s := by
  unfold EvmYul.Yul.exec; rfl

theorem loop_base (fuel : Nat) (cond : Expr) (post body : List Stmt) (s s₁ : EvmYul.Yul.State)
    (hcond : EvmYul.Yul.eval fuel cond none (EvmYul.Yul.State.mkOk s) = .ok (s₁, ⟨0⟩)) :
    EvmYul.Yul.loop (fuel + 1 + 1) cond post body none s = .ok (EvmYul.Yul.State.overwrite? s₁ s) := by
  unfold EvmYul.Yul.loop; simp only [hcond]; rfl

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
  simp only [EvmYul.Yul.State.mkOk, hcond, if_neg hx, hbody, EvmYul.Yul.State.reviveJump, hpost,
             EvmYul.Yul.State.overwrite?]
  cases EvmYul.Yul.exec fuel (Stmt.For cond post body) none s₃ <;> rfl

-- ============ opcode + bridge bricks ============
set_option maxHeartbeats 1000000 in
theorem step_ADD (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.ADD none s [a, b] = .ok (s, some (EvmYul.UInt256.add a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_LT (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.LT none s [a, b] = .ok (s, some (EvmYul.UInt256.lt a b)) := by
  unfold EvmYul.step; rfl

theorem getElem_Ok (ss : EvmYul.SharedState .Yul) (vs : VarStore) (id : EvmYul.Identifier) :
    (EvmYul.Yul.State.Ok ss vs)[id]! = EvmYul.Yul.State.lookup! id (EvmYul.Yul.State.Ok ss vs) := by
  simp only [getElem!, decidableGetElem?, EvmYul.Yul.State.store]
  by_cases h : id ∈ vs
  · simp only [dif_pos h]; rfl
  · simp only [dif_neg h, EvmYul.Yul.State.lookup!, Finmap.lookup_eq_none.mpr h]; rfl

-- ============ loop identifiers + the accumulation loop ============
def II : EvmYul.Identifier := "i"
def WW : EvmYul.Identifier := "w"
theorem IW : II ≠ WW := by decide

def cond (n : EvmYul.UInt256) : Expr := Expr.Call (Sum.inl Operation.LT) [Expr.Var II, Expr.Lit n]
def post : List Stmt := [Stmt.Let [II] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var II, Expr.Lit ⟨1⟩]))]
def body : List Stmt := [Stmt.Let [WW] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var WW, Expr.Var II]))]

-- ============ fuel-generic statement-effect bricks (simp peels succs; symbolic fuel works) ============
-- body effect (fuel-generic): exec (Block body) inserts WW ↦ w + i.
set_option maxHeartbeats 4000000 in
theorem body_eff (fuel : Nat) (ss : EvmYul.SharedState .Yul) (vs : VarStore) :
    EvmYul.Yul.exec (fuel + 7) (Stmt.Block body) none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss
        (Finmap.insert WW (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[WW]!) ((EvmYul.Yul.State.Ok ss vs)[II]!)) vs)) := by
  simp [body, EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall,
        EvmYul.Yul.head', EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill',
        EvmYul.Yul.State.multifill, EvmYul.Yul.State.insert, step_ADD]

-- post effect (fuel-generic): exec (Block post) inserts II ↦ i + 1.
set_option maxHeartbeats 4000000 in
theorem post_eff (fuel : Nat) (ss : EvmYul.SharedState .Yul) (vs : VarStore) :
    EvmYul.Yul.exec (fuel + 7) (Stmt.Block post) none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss
        (Finmap.insert II (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[II]!) ⟨1⟩) vs)) := by
  simp [post, EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall,
        EvmYul.Yul.head', EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill',
        EvmYul.Yul.State.multifill, EvmYul.Yul.State.insert, step_ADD]

-- cond eval (fuel-generic): eval (cond n) gives lt(i, n).
set_option maxHeartbeats 4000000 in
theorem cond_eff (fuel : Nat) (n : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : VarStore) :
    EvmYul.Yul.eval (fuel + 6) (cond n) none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss vs, EvmYul.UInt256.lt ((EvmYul.Yul.State.Ok ss vs)[II]!) n) := by
  simp [cond, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail, EvmYul.Yul.evalPrimCall,
        EvmYul.Yul.primCall, EvmYul.Yul.head', EvmYul.Yul.cons', EvmYul.Yul.reverse', step_LT]

#print axioms body_eff
#print axioms post_eff
#print axioms cond_eff
end GapB
