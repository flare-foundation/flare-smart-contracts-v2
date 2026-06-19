import EvmYul.Yul.Interpreter

open EvmYul EvmYul.Yul EvmYul.Yul.Ast

def s0 : EvmYul.Yul.State := default

-- accumulation For-loop: i:=0; sum:=0; for (i<n) { i:=i+1 } { sum := add(sum,i) }
-- computes 0+1+...+(n-1).  (For has no init — init hoisted; post = increment; body = accumulate.)
def progSum (n : Nat) : Stmt := Stmt.Block [
  Stmt.Let ["i"]   (some (Expr.Lit (UInt256.ofNat 0))),
  Stmt.Let ["sum"] (some (Expr.Lit (UInt256.ofNat 0))),
  Stmt.For
    (Expr.Call (Sum.inl Operation.LT) [Expr.Var "i", Expr.Lit (UInt256.ofNat n)])
    [Stmt.Let ["i"]   (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var "i", Expr.Lit (UInt256.ofNat 1)]))]
    [Stmt.Let ["sum"] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var "sum", Expr.Var "i"]))]
]

def runSum (n : Nat) : Option Nat :=
  ((EvmYul.Yul.exec 100000 (progSum n) none s0).toOption.map (fun s => (s.lookup! "sum").val.val))

#eval runSum 5    -- expect: some 10   (0+1+2+3+4)
#eval runSum 10   -- expect: some 45
#eval runSum 1    -- expect: some 0
