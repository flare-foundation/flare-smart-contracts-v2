import EvmYul.Yul.Interpreter

open EvmYul EvmYul.Yul EvmYul.Yul.Ast

namespace GapB

set_option maxHeartbeats 1000000 in
theorem step_ADD (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.ADD none s [a, b] = .ok (s, some (EvmYul.UInt256.add a b)) := by
  unfold EvmYul.step; rfl

-- Per-statement effect (general over identifier names): `x := add(a, b)` inserts
-- x ↦ add(s[a], s[b]) into the varstore.  RHS uses the interpreter's own getElem! so it matches the LHS.
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

#print axioms assign_add_effect
end GapB
