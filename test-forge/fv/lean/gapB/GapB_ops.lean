import EvmYul.Yul.Interpreter

open EvmYul EvmYul.Yul EvmYul.Yul.Ast

namespace GapB

-- Per-opcode rewrite lemmas for the Yul Semantics `step`, proven hole-free (`unfold; rfl`;
-- the dbg_trace preamble drops definitionally). These finish the per-statement reduction chain.
set_option maxHeartbeats 1000000 in
theorem step_ADD (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.ADD none s [a, b] = .ok (s, some (EvmYul.UInt256.add a b)) := by
  unfold EvmYul.step; rfl

set_option maxHeartbeats 1000000 in
theorem step_LT (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.LT none s [a, b] = .ok (s, some (EvmYul.UInt256.lt a b)) := by
  unfold EvmYul.step; rfl

set_option maxHeartbeats 1000000 in
theorem step_AND (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.AND none s [a, b] = .ok (s, some (EvmYul.UInt256.land a b)) := by
  unfold EvmYul.step; rfl

#print axioms step_ADD
#print axioms step_LT
#print axioms step_AND

end GapB
