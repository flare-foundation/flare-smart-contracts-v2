import EvmYul.Yul.Interpreter

open EvmYul EvmYul.Yul EvmYul.Yul.Ast

namespace GapB

set_option maxHeartbeats 1000000 in
theorem step_ADD (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.ADD none s [a, b] = .ok (s, some (EvmYul.UInt256.add a b)) := by
  unfold EvmYul.step; rfl

set_option maxHeartbeats 1000000 in
theorem step_LT (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.LT none s [a, b] = .ok (s, some (EvmYul.UInt256.lt a b)) := by
  unfold EvmYul.step; rfl

-- body effect: `x := add(a, b)` (two vars).
set_option maxHeartbeats 4000000 in
theorem assign_add_effect (ss : EvmYul.SharedState .Yul) (vs : VarStore) (x a b : EvmYul.Identifier) :
    EvmYul.Yul.exec 8
      (Stmt.Let [x] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var a, Expr.Var b])))
      none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss
        (Finmap.insert x
          (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[a]!) ((EvmYul.Yul.State.Ok ss vs)[b]!)) vs)) := by
  simp [EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall,
        EvmYul.Yul.head', EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill',
        EvmYul.Yul.State.multifill, EvmYul.Yul.State.insert, step_ADD]

-- post effect: `x := add(a, c)` (var + literal constant).
set_option maxHeartbeats 4000000 in
theorem assign_add_lit_effect (ss : EvmYul.SharedState .Yul) (vs : VarStore) (x a : EvmYul.Identifier) (c : EvmYul.UInt256) :
    EvmYul.Yul.exec 8
      (Stmt.Let [x] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var a, Expr.Lit c])))
      none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss
        (Finmap.insert x (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[a]!) c) vs)) := by
  simp [EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall,
        EvmYul.Yul.head', EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill',
        EvmYul.Yul.State.multifill, EvmYul.Yul.State.insert, step_ADD]

-- cond eval: `lt(a, c)` (var < literal).
set_option maxHeartbeats 4000000 in
theorem cond_lt_eval (ss : EvmYul.SharedState .Yul) (vs : VarStore) (a : EvmYul.Identifier) (c : EvmYul.UInt256) :
    EvmYul.Yul.eval 8
      (Expr.Call (Sum.inl Operation.LT) [Expr.Var a, Expr.Lit c]) none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss vs, EvmYul.UInt256.lt ((EvmYul.Yul.State.Ok ss vs)[a]!) c) := by
  simp [EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail, EvmYul.Yul.evalPrimCall,
        EvmYul.Yul.primCall, EvmYul.Yul.head', EvmYul.Yul.cons', EvmYul.Yul.reverse', step_LT]

#print axioms assign_add_effect
#print axioms assign_add_lit_effect
#print axioms cond_lt_eval
end GapB
