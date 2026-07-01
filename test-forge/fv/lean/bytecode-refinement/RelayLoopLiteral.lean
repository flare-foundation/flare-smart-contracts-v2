import EvmYul.Yul.Interpreter
open EvmYul EvmYul.Yul EvmYul.Yul.Ast

/-!
# Relay signature loop — the LITERAL body (work in progress: deriving `hcorr`/`hvalid`)

This file transliterates the deployed signature loop's **actual body** — from the committed optimized-IR
snapshot `../relay_ir_optimized.yul:1563-1610` — into the EVMYulLean Yul AST: both `calldatacopy`s (the
67-byte signature record; the 22-byte voter record), the **fixed scratch-slot addressing** (`m+32`…`m+128`),
the full guard cascade (index range/order, canonical `v`, low-`s`, `staticcall`-success,
`returndatasize()==32`, non-zero signer, signer==expected), the masked weight accumulation, and the
**early-return accept gate**. The goal (in progress): prove that a *successful/accepting* execution of this
body forces the guards to have passed — deriving `RelayLoopMemRead.relay_loop_sound`'s hypotheses
`hcorr`/`hvalid` from a raw-calldata precondition instead of assuming them, and closing the address-map and
early-exit fidelity notes of L7 §7.4 (BR-3 items 1–2).

Deviations from the IR, each deliberate and accounting-irrelevant (fidelity register):
* **D1 — folded addressing.** The IR writes `add(usr$memPtrFor, 32)` with `memPtrFor` loop-invariant
  (`mload(0x40)`, fixed before the loop); we parameterize the whole AST by the base `m : Nat` and emit the
  folded literals `⟨m+32⟩` etc. Same addresses, fewer interpreter steps.
* **D2 — revert payloads.** The IR calls per-message helpers (`usr$revertWithMessage_15082(...)` = store
  message + `revert(ptr, len)`); we emit `revert(0,0)`. The guard **conditions** are verbatim; only the
  revert *data* (irrelevant to the accounting theorem, and to whether the run reverts) is simplified.
* **D3 — accept-branch interior.** On `gt(weight, threshold)` the IR runs the mode-specific finalization
  (sstore / event / return payload); we emit `return(0,0)`. The accept **control flow** (early halt inside
  the first threshold-crossing iteration) is verbatim; the finalization's storage effects are the separate
  "storage effects" work item, out of scope for the accounting theorem.
* **D4 — loop-invariant scalars as literals.** `numberOfSignatures` (`_17`), `numberOfVoters`
  (`shr(240,_1)`), `threshold`, and `signatureStart` are computed before the loop in the IR; they enter the
  AST as parameters (`nSig`, `nVot`, `thr`, `sigStart`), exactly as the folded values the IR loop reads.

Everything else — statement order, expression shapes, slot layout, guard conditions, the `staticcall`
argument list `(not(0), 1, m, 128, m+64, 32)` — matches the IR token-for-token.
-/

namespace RelayLoopLiteral

/-! ## Identifiers (the loop's Yul locals) -/

def II  : EvmYul.Identifier := "i"       -- usr$i
def WW  : EvmYul.Identifier := "weight"  -- usr$weight
def NUI : EvmYul.Identifier := "nui"     -- usr$nextUnusedIndex
def IDX : EvmYul.Identifier := "idx"     -- usr$index (fresh each iteration)
def VV  : EvmYul.Identifier := "v"       -- _18 (the v byte)

/-! ## Expression builders -/

/-- Builtin call. -/
def bc (op : Operation .Yul) (args : List Expr) : Expr := Expr.Call (Sum.inl op) args
/-- Literal from a `Nat`. -/
def litN (n : Nat) : Expr := Expr.Lit (UInt256.ofNat n)
/-- Literal from a `UInt256`. -/
def litU (u : EvmYul.UInt256) : Expr := Expr.Lit u
/-- Variable read. -/
def V (x : EvmYul.Identifier) : Expr := Expr.Var x

/-- secp256k1n/2 — the EIP-2 low-`s` bound (IR line 1584). -/
def SECP_HALF : EvmYul.UInt256 :=
  UInt256.ofNat 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0

/-- `revert(0,0)` — D2: payload simplified, condition verbatim. -/
def revert00 : Stmt := Stmt.ExprStmtCall (bc .REVERT [litN 0, litN 0])

/-- `if cond { revert }` — the guard shape used by every check in the loop. -/
def guard' (cond : Expr) : Stmt := Stmt.If cond [revert00]

/-! ## The loop, transliterated (IR lines 1563-1610)

Parameters: `m` = `usr$memPtrFor` (loop-invariant free-memory base), `sigStart` = `usr$signatureStart`,
`nSig` = `_17` (numberOfSignatures), `nVot` = `shr(240,_1)` (numberOfVoters), `thr` = `usr$threshold`. -/

/-- Loop condition `lt(usr$i, _17)`. -/
def condL (nSig : EvmYul.UInt256) : Expr := bc .LT [V II, litU nSig]

/-- Loop post `usr$i := add(usr$i, 1)`. -/
def postL : List Stmt := [Stmt.Let [II] (some (bc .ADD [V II, litN 1]))]

/-- One iteration of the deployed signature loop, statement for statement. -/
def bodyL (m sigStart : Nat) (nVot thr : EvmYul.UInt256) : List Stmt := [
  -- mstore(add(m, 32), 0)                                            [zero the v slot]
  Stmt.ExprStmtCall (bc .MSTORE [litN (m+32), litN 0]),
  -- calldatacopy(add(m, 63), add(add(sigStart, mul(i, 67)), 2), 67)  [copy (v,r,s,index)]
  Stmt.ExprStmtCall (bc .CALLDATACOPY
    [litN (m+63),
     bc .ADD [bc .ADD [litN sigStart, bc .MUL [V II, litN 67]], litN 2],
     litN 67]),
  -- let index := shr(240, mload(add(m, 128)))
  Stmt.Let [IDX] (some (bc .SHR [litN 240, bc .MLOAD [litN (m+128)]])),
  -- if gt(add(index, 1), nVot) { revert }                            ["Index out of range"]
  guard' (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]),
  -- if lt(index, nextUnusedIndex) { revert }                         ["Index out of order"]
  guard' (bc .LT [V IDX, V NUI]),
  -- nextUnusedIndex := add(index, 1)
  Stmt.Let [NUI] (some (bc .ADD [V IDX, litN 1])),
  -- let v := and(mload(add(m, 32)), 0xff)
  Stmt.Let [VV] (some (bc .AND [bc .MLOAD [litN (m+32)], litN 0xff])),
  -- if iszero(or(eq(v, 27), eq(v, 28))) { revert }                   ["Bad v"]
  guard' (bc .ISZERO [bc .OR [bc .EQ [V VV, litN 27], bc .EQ [V VV, litN 28]]]),
  -- if gt(mload(add(m, 96)), SECP_HALF) { revert }                   ["Bad s"]
  guard' (bc .GT [bc .MLOAD [litN (m+96)], litU SECP_HALF]),
  -- if iszero(staticcall(not(0), 1, m, 128, add(m, 64), 32)) { revert }   ["ecrecover error"]
  guard' (bc .ISZERO [bc .STATICCALL
    [bc .NOT [litN 0], litN 1, litN m, litN 128, litN (m+64), litN 32]]),
  -- if iszero(eq(returndatasize(), 32)) { revert }                   ["ecrecover returned bad data"]
  guard' (bc .ISZERO [bc .EQ [bc .RETURNDATASIZE [], litN 32]]),
  -- if iszero(mload(add(m, 64))) { revert }                          ["Zero signer"]
  guard' (bc .ISZERO [bc .MLOAD [litN (m+64)]]),
  -- mstore(add(m, 96), 0)                                            [zero the voter slot]
  Stmt.ExprStmtCall (bc .MSTORE [litN (m+96), litN 0]),
  -- calldatacopy(add(m, 106), add(47, mul(index, 22)), 22)           [copy (address‖weight)]
  Stmt.ExprStmtCall (bc .CALLDATACOPY
    [litN (m+106), bc .ADD [litN 47, bc .MUL [V IDX, litN 22]], litN 22]),
  -- if iszero(eq(mload(add(m, 64)), shr(16, mload(add(m, 96))))) { revert }   ["Wrong signature"]
  guard' (bc .ISZERO [bc .EQ
    [bc .MLOAD [litN (m+64)], bc .SHR [litN 16, bc .MLOAD [litN (m+96)]]]]),
  -- weight := add(weight, and(mload(add(m, 96)), 65535))
  Stmt.Let [WW] (some (bc .ADD [V WW, bc .AND [bc .MLOAD [litN (m+96)], litN 65535]])),
  -- if gt(weight, threshold) { return(0,0) }                         [accept: early halt — D3]
  Stmt.If (bc .GT [V WW, litU thr]) [Stmt.ExprStmtCall (bc .RETURN [litN 0, litN 0])]
]

/-- The whole loop as a single `For` node (no init — the IR's `for { } … { }`). -/
def loopL (m sigStart : Nat) (nSig nVot thr : EvmYul.UInt256) : Stmt :=
  Stmt.For (condL nSig) postL (bodyL m sigStart nVot thr)

/-! ## The calldata layout, as pure decode functions

These interpret the raw calldata exactly as the deployed loop's `calldatacopy` offsets do; the capstone
(in progress) will quantify over an arbitrary calldata `cd : ByteArray` and conclude about
`weightsOf cd nVot` — deriving what `relay_loop_sound` currently assumes via `hcorr`/`hvalid`. -/

/-- Base offset of signature record `k`: `sigStart + 67·k + 2` (67-byte stride, 2-byte count prefix;
    record layout `v(1) ‖ r(32) ‖ s(32) ‖ index(2)`). -/
def sigRecBase (sigStart k : Nat) : Nat := sigStart + 67 * k + 2

/-- The voter index carried by signature `k`: big-endian of the record's last two bytes. -/
def sigIdxAt (cd : ByteArray) (sigStart k : Nat) : Nat :=
  fromBytesBigEndian ((cd.extract (sigRecBase sigStart k + 65) (sigRecBase sigStart k + 67)).data.toList)

/-- Base offset of voter record `idx`: `47 + 22·idx` (calldata offset 47 = selector 4 + policy prefix 43;
    record layout `address(20) ‖ weight(2)`). -/
def voterRecBase (idx : Nat) : Nat := 47 + 22 * idx

/-- Voter `idx`'s registered 16-bit weight: big-endian of the record's last two bytes. -/
def voterWeightAt (cd : ByteArray) (idx : Nat) : Nat :=
  fromBytesBigEndian ((cd.extract (voterRecBase idx + 20) (voterRecBase idx + 22)).data.toList)

/-- Voter `idx`'s registered 20-byte address. -/
def voterSignerAt (cd : ByteArray) (idx : Nat) : Nat :=
  fromBytesBigEndian ((cd.extract (voterRecBase idx) (voterRecBase idx + 20)).data.toList)

/-- The registered weight table, as the abstract proof's `w : List Nat`. -/
def weightsOf (cd : ByteArray) (nVot : Nat) : List Nat :=
  (List.range nVot).map (voterWeightAt cd)

end RelayLoopLiteral
