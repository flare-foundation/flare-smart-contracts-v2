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

theorem weightsOf_length (cd : ByteArray) (nVot : Nat) : (weightsOf cd nVot).length = nVot := by
  simp [weightsOf]

/-- In-range lookup in the weight table is the calldata decode — the shape the abstract loop's
    `w.getD idx 0` addend takes once `idx < nVot` is derived from the range guard. -/
theorem weightsOf_getD (cd : ByteArray) (nVot idx : Nat) (h : idx < nVot) :
    (weightsOf cd nVot).getD idx 0 = voterWeightAt cd idx := by
  simp [weightsOf, List.getD, List.getElem?_map, List.getElem?_range, h]

/-! ## The abstract accounting layer (self-contained restatement)

Identical to `RelayLoopMemRead.lean` / `../RelaySigLoop.lean` — restated so this file, too, checks with a
single `lake env lean` against EVMYulLean alone. The capstone will *derive* `ValidRun` from the guards
(instead of assuming it) and transfer `threshold_sound`. -/

/-- prefix sum of the first `k` registered weights. -/
def sumTake : List Nat → Nat → Nat
  | _,        0      => 0
  | [],       _ + 1  => 0
  | x :: xs,  k + 1  => x + sumTake xs k

theorem sumTake_succ (w : List Nat) (idx : Nat) :
    sumTake w (idx + 1) = sumTake w idx + w.getD idx 0 := by
  induction idx generalizing w with
  | zero => cases w with
    | nil => rfl
    | cons x xs => simp [sumTake, List.getD]
  | succ n ih => cases w with
    | nil => rfl
    | cons x xs =>
      have hg : (x :: xs).getD (n + 1) 0 = xs.getD n 0 := rfl
      simp only [sumTake, ih xs, hg]; omega

theorem sumTake_le_succ (w : List Nat) (k : Nat) : sumTake w k ≤ sumTake w (k + 1) := by
  rw [sumTake_succ]; exact Nat.le_add_right _ _

theorem sumTake_mono (w : List Nat) {i j : Nat} (h : i ≤ j) : sumTake w i ≤ sumTake w j := by
  induction h with
  | refl => exact Nat.le_refl _
  | step _ ih => exact Nat.le_trans ih (sumTake_le_succ w _)

/-- The on-chain signature-loop accounting: state `(weight, nextUnusedIndex)`, one step per signature. -/
def sigLoop : List Nat → Nat → Nat → List Nat → (Nat × Nat)
  | _, weight, nui, []          => (weight, nui)
  | w, weight, nui, idx :: rest => sigLoop w (weight + w.getD idx 0) (idx + 1) rest

/-- Strictly-increasing, in-range index streams — what the deployed guards enforce. The capstone derives
    this from "the execution did not revert", rather than assuming it. -/
inductive ValidRun (w : List Nat) : Nat → List Nat → Prop
  | nil  {nui} : ValidRun w nui []
  | cons {nui idx rest} :
      nui ≤ idx → idx < w.length → ValidRun w (idx + 1) rest → ValidRun w nui (idx :: rest)

theorem loop_inv (w : List Nat) :
    ∀ (idxs : List Nat) (nui weight : Nat),
      weight ≤ sumTake w nui → nui ≤ w.length → ValidRun w nui idxs →
      (sigLoop w weight nui idxs).1 ≤ sumTake w (sigLoop w weight nui idxs).2 ∧
      (sigLoop w weight nui idxs).2 ≤ w.length := by
  intro idxs
  induction idxs with
  | nil => intro nui weight hw hn _; exact ⟨hw, hn⟩
  | cons idx rest ih =>
    intro nui weight hw hn hv
    cases hv with
    | cons hle hlt hrest =>
      simp only [sigLoop]
      apply ih (idx + 1) (weight + w.getD idx 0)
      · have h2 : sumTake w nui ≤ sumTake w idx := sumTake_mono w hle
        have h4 : sumTake w idx + w.getD idx 0 = sumTake w (idx + 1) := (sumTake_succ w idx).symm
        omega
      · omega
      · exact hrest

/-- THRESHOLD SOUNDNESS (abstract): accept ⟹ total registered weight > thr. -/
theorem threshold_sound (w : List Nat) (idxs : List Nat) (thr : Nat)
    (hv : ValidRun w 0 idxs) (hacc : thr < (sigLoop w 0 0 idxs).1) :
    thr < sumTake w w.length := by
  obtain ⟨hw, hb⟩ := loop_inv w idxs 0 0 (Nat.zero_le _) (Nat.zero_le _) hv
  have hmono : sumTake w (sigLoop w 0 0 idxs).2 ≤ sumTake w w.length := sumTake_mono w hb
  omega

/-! ## Interpreter bricks (verified against EVMYulLean's real `step`/`exec`)

Opcode `step` reductions and control-flow `exec` equations for every construct the literal body uses. Each
proves by `unfold … ; rfl` (or `conv_lhs => unfold` where the RHS also mentions `exec` at opaque fuel), so
they are decidable per-construct facts about the actual interpreter. These are the substrate for the
per-statement effect lemmas (in progress). `set_option maxHeartbeats 1000000` covers the large `step` match. -/

-- Arithmetic / comparison / bitwise
set_option maxHeartbeats 1000000 in
theorem step_ADD (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.ADD none s [a, b] = .ok (s, some (EvmYul.UInt256.add a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_MUL (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.MUL none s [a, b] = .ok (s, some (EvmYul.UInt256.mul a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_LT (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.LT none s [a, b] = .ok (s, some (EvmYul.UInt256.lt a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_GT (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.GT none s [a, b] = .ok (s, some (EvmYul.UInt256.gt a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_EQ (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.EQ none s [a, b] = .ok (s, some (EvmYul.UInt256.eq a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_AND (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.AND none s [a, b] = .ok (s, some (EvmYul.UInt256.land a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_OR (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.OR none s [a, b] = .ok (s, some (EvmYul.UInt256.lor a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_ISZERO (s : EvmYul.Yul.State) (a : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.ISZERO none s [a] = .ok (s, some (EvmYul.UInt256.isZero a)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_NOT (s : EvmYul.Yul.State) (a : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.NOT none s [a] = .ok (s, some (EvmYul.UInt256.lnot a)) := by
  unfold EvmYul.step; rfl
-- SHR uses `flip shiftRight`: Yul args [shift, val] ⟹ `shiftRight val shift` (= val >>> shift).
set_option maxHeartbeats 1000000 in
theorem step_SHR (s : EvmYul.Yul.State) (shift val : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.SHR none s [shift, val]
      = .ok (s, some (EvmYul.UInt256.shiftRight val shift)) := by
  unfold EvmYul.step; rfl

-- Memory
set_option maxHeartbeats 1000000 in
theorem step_MLOAD (s : EvmYul.Yul.State) (a : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.MLOAD none s [a]
      = .ok (s.setMachineState (s.toSharedState.toMachineState.mload a).2,
             some (s.toSharedState.toMachineState.mload a).1) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_MSTORE (s : EvmYul.Yul.State) (off v : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.MSTORE none s [off, v]
      = .ok (s.setMachineState (s.toMachineState.mstore off v), none) := by
  unfold EvmYul.step; rfl

-- Calldata / return-data
set_option maxHeartbeats 1000000 in
theorem step_CALLDATACOPY (s : EvmYul.Yul.State) (destOff srcOff len : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.CALLDATACOPY none s [destOff, srcOff, len]
      = .ok (s.setSharedState (s.toSharedState.calldatacopy destOff srcOff len), none) := by
  unfold EvmYul.step; rfl
theorem calldatacopy_unfold (ss : EvmYul.SharedState .Yul) (mstart datastart size : EvmYul.UInt256) :
    ss.calldatacopy mstart datastart size
      = { ss with
          memory := ss.executionEnv.calldata.write datastart.toNat ss.memory mstart.toNat size.toNat,
          activeWords := EvmYul.UInt256.ofNat
            (EvmYul.MachineState.M ss.activeWords.toNat mstart.toNat size.toNat) } := rfl
set_option maxHeartbeats 1000000 in
theorem step_RETURNDATASIZE (s : EvmYul.Yul.State) (args : List EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.RETURNDATASIZE none s args
      = .ok (s, some (s.toMachineState.returndatasize)) := by
  unfold EvmYul.step; rfl
theorem returndatasize_unfold (m : EvmYul.MachineState) :
    m.returndatasize = EvmYul.UInt256.ofNat m.returnData.size := rfl

-- Control flow: If (bare — no mkOk/overwrite wrappers, unlike loop)
theorem exec_If_true (fuel : Nat) (c : Expr) (body : List Stmt) (s s₁ : EvmYul.Yul.State)
    (x : EvmYul.UInt256)
    (h : EvmYul.Yul.eval fuel c none s = .ok (s₁, x)) (hx : x ≠ ⟨0⟩) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.If c body) none s
      = EvmYul.Yul.exec fuel (Stmt.Block body) none s₁ := by
  conv_lhs => unfold EvmYul.Yul.exec
  simp only [h, if_pos hx]
theorem exec_If_false (fuel : Nat) (c : Expr) (body : List Stmt) (s s₁ : EvmYul.Yul.State)
    (h : EvmYul.Yul.eval fuel c none s = .ok (s₁, ⟨0⟩)) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.If c body) none s = .ok s₁ := by
  conv_lhs => unfold EvmYul.Yul.exec
  simp only [h]; simp

-- Control flow: Block chaining
theorem exec_Block_nil (fuel : Nat) (s : EvmYul.Yul.State) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.Block []) none s = .ok s := by
  unfold EvmYul.Yul.exec; rfl
theorem exec_Block_cons_ok (fuel : Nat) (st : Stmt) (rest : List Stmt) (s s₁ : EvmYul.Yul.State)
    (hst : EvmYul.Yul.exec fuel st none s = .ok s₁) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.Block (st :: rest)) none s
      = EvmYul.Yul.exec fuel (Stmt.Block rest) none s₁ := by
  conv_lhs => unfold EvmYul.Yul.exec
  simp only [hst]
theorem exec_Block_cons_err (fuel : Nat) (st : Stmt) (rest : List Stmt) (s : EvmYul.Yul.State)
    (e : EvmYul.Yul.Exception) (hst : EvmYul.Yul.exec fuel st none s = .error e) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.Block (st :: rest)) none s = .error e := by
  conv_lhs => unfold EvmYul.Yul.exec
  simp only [hst]

-- REVERT: the deployed guards' fail path — throws `.Revert`, discarding state (return data unobservable
-- at the Yul level). Holds for a general `s`, so every guard's revert branch is one lemma.
set_option maxHeartbeats 1000000 in
theorem step_REVERT (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.REVERT none s [a, b] = .error .Revert := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 4000000 in
theorem revert_eff (fuel : Nat) (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.Yul.exec (fuel + 6)
      (Stmt.ExprStmtCall (Expr.Call (Sum.inl Operation.REVERT) [Expr.Lit a, Expr.Lit b])) none s
    = .error .Revert := by
  simp [EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall,
        EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill', step_REVERT]

-- RETURN: the accept gate's early halt — `.error (.YulHalt …)` with the return-data memory read.
set_option maxHeartbeats 1000000 in
theorem step_RETURN (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.RETURN none s [a, b]
      = .error (.YulHalt (s.setMachineState (s.toMachineState.evmReturn a b)) ⟨1⟩) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 4000000 in
theorem return_eff (fuel : Nat) (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.Yul.exec (fuel + 6)
      (Stmt.ExprStmtCall (Expr.Call (Sum.inl Operation.RETURN) [Expr.Lit a, Expr.Lit b])) none s
    = .error (.YulHalt (s.setMachineState (s.toMachineState.evmReturn a b)) ⟨1⟩) := by
  simp [EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall,
        EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill', step_RETURN]

#print axioms threshold_sound
#print axioms weightsOf_getD
#print axioms step_CALLDATACOPY
#print axioms exec_If_true
#print axioms revert_eff
#print axioms return_eff

end RelayLoopLiteral
