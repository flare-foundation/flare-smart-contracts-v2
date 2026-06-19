import EvmYul.Yul.Interpreter

open EvmYul EvmYul.Yul EvmYul.Yul.Ast

-- sanity: the validated interpreter + AST names resolve
#check @EvmYul.Yul.exec
#check (Stmt.Let ["x"] (some (Expr.Lit (UInt256.ofNat 5))) : Stmt)

-- a trivial Yul program: x := 5
def s0 : EvmYul.Yul.State := default
def prog1 : Stmt := Stmt.Let ["x"] (some (Expr.Lit (UInt256.ofNat 5)))
def res1 : Except EvmYul.Yul.Exception EvmYul.Yul.State := EvmYul.Yul.exec 100 prog1 none s0

-- read back x; confirm the validated semantics computes x = 5
#eval (res1.toOption.map (fun s => (s.lookup! "x").val.val))   -- expect: some 5

-- a program with arithmetic: x := add(2, 3)  (uses the REAL .ADD semantics = UInt256.add)
def prog2 : Stmt :=
  Stmt.Let ["x"] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Lit (UInt256.ofNat 2), Expr.Lit (UInt256.ofNat 3)]))
def res2 : Except EvmYul.Yul.Exception EvmYul.Yul.State := EvmYul.Yul.exec 100 prog2 none s0
#eval (res2.toOption.map (fun s => (s.lookup! "x").val.val))   -- expect: some 5
