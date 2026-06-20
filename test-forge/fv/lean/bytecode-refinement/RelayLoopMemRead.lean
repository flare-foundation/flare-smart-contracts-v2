import EvmYul.Yul.Interpreter
open EvmYul EvmYul.Yul EvmYul.Yul.Ast

/-!
# Relay signature loop — bytecode-level ∀N refinement with a MEMORY-READING body

This strengthens `RelayBytecodeRefinement.lean` (whose loop body adds the index `i`) to a body that performs
the deployed contract's **actual masked weight read** — `w := w + (mload(i·32) & 0xffff)` — executed by
NethermindEth's validated EVMYulLean Yul semantics, for all N. It closes the data-layer half of BR-1
*inside the loop*: the per-iteration addend is a real `MLOAD` from memory, masked by `0xffff`, not the
loop index.

Capstones (all hole-free; `#print axioms` ⊆ `{propext, Classical.choice, Quot.sound}`):
* `body_effM`        — one iteration of the memory-reading body: under a state-preserving slot read, it adds
                       the masked memory word to the accumulator (the EVM `mload`+`and` executed for real).
* `loop_accM`        — the induction: ∀N, the validated `exec` drives the memory-reading loop and accumulates
                       `absAccM` (the sum of masked slot reads).
* `bytecode_loop_correct_mem` — ∀N: exact fuel `3N+15`, the final accumulator equals `absAccM rdv 0 N ⟨0⟩`.
* `bytecode_threshold_sound_mem` — ∀N: accept (final weight > thr) ⟹ total masked-read weight > thr.

Modeling choice: weights are memory-resident at 32-byte-aligned slots `i·32`, and the loop reads
`mload(i·32) & 0xffff` for `i = 0…N-1`. The hypothesis `hcov` (each slot read is state-preserving and
returns `rdv i`) is exactly BR-1's data-layer invariant — `DataLayer.weight_read` shows each such read
recovers the registered 16-bit weight, so `rdv i & 0xffff = w[i]`. The signature matching / strict-index
discipline (ecrecover, `ValidRun`) is orthogonal (assumptions MC-2 / OP-1) and composes on top.
-/

namespace RelayLoopMemRead

-- ===================== control-flow bricks (as in RelayBytecodeRefinement) =====================
theorem exec_For (fuel : Nat) (c : Expr) (po bo : List Stmt) (s : EvmYul.Yul.State) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.For c po bo) none s = EvmYul.Yul.loop fuel c po bo none s := by
  unfold EvmYul.Yul.exec; rfl

theorem loop_base (fuel : Nat) (c : Expr) (po bo : List Stmt) (s s₁ : EvmYul.Yul.State)
    (hc : EvmYul.Yul.eval fuel c none (EvmYul.Yul.State.mkOk s) = .ok (s₁, ⟨0⟩)) :
    EvmYul.Yul.loop (fuel + 1 + 1) c po bo none s = .ok (EvmYul.Yul.State.overwrite? s₁ s) := by
  unfold EvmYul.Yul.loop; simp only [hc]; rfl

theorem loop_step (fuel : Nat) (c : Expr) (po bo : List Stmt)
    (sa : EvmYul.SharedState .Yul) (va : VarStore) (s₃ : EvmYul.Yul.State)
    (sb : EvmYul.SharedState .Yul) (vb : VarStore) (x : EvmYul.UInt256)
    (hc : EvmYul.Yul.eval fuel c none (EvmYul.Yul.State.Ok sa va) = .ok (EvmYul.Yul.State.Ok sa va, x))
    (hx : x ≠ ⟨0⟩)
    (hb : EvmYul.Yul.exec fuel (Stmt.Block bo) none (EvmYul.Yul.State.Ok sa va) = .ok (EvmYul.Yul.State.Ok sb vb))
    (hp : EvmYul.Yul.exec fuel (Stmt.Block po) none (EvmYul.Yul.State.Ok sb vb) = .ok s₃) :
    EvmYul.Yul.loop (fuel + 1 + 1) c po bo none (EvmYul.Yul.State.Ok sa va)
      = EvmYul.Yul.exec fuel (Stmt.For c po bo) none s₃ := by
  unfold EvmYul.Yul.loop
  simp only [EvmYul.Yul.State.mkOk, hc, if_neg hx, hb, EvmYul.Yul.State.reviveJump, hp,
             EvmYul.Yul.State.overwrite?]
  cases EvmYul.Yul.exec fuel (Stmt.For c po bo) none s₃ <;> rfl

-- ===================== opcode bricks =====================
set_option maxHeartbeats 1000000 in
theorem step_ADD (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.ADD none s [a, b] = .ok (s, some (EvmYul.UInt256.add a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_LT (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.LT none s [a, b] = .ok (s, some (EvmYul.UInt256.lt a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_MUL (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.MUL none s [a, b] = .ok (s, some (EvmYul.UInt256.mul a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_AND (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.AND none s [a, b] = .ok (s, some (EvmYul.UInt256.land a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_MLOAD (s : EvmYul.Yul.State) (a : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.MLOAD none s [a]
      = .ok (s.setMachineState (s.toSharedState.toMachineState.mload a).2,
             some (s.toSharedState.toMachineState.mload a).1) := by
  unfold EvmYul.step; rfl

theorem setMachineState_self (ss : EvmYul.SharedState .Yul) (vs : VarStore) :
    (EvmYul.Yul.State.Ok ss vs).setMachineState ss.toMachineState = EvmYul.Yul.State.Ok ss vs := by
  unfold EvmYul.Yul.State.setMachineState; rfl

-- ===================== state-access bridge + insert helpers =====================
theorem getElem_Ok (ss : EvmYul.SharedState .Yul) (vs : VarStore) (id : EvmYul.Identifier) :
    (EvmYul.Yul.State.Ok ss vs)[id]! = EvmYul.Yul.State.lookup! id (EvmYul.Yul.State.Ok ss vs) := by
  simp only [getElem!, decidableGetElem?, EvmYul.Yul.State.store]
  by_cases h : id ∈ vs
  · simp only [dif_pos h]; rfl
  · simp only [dif_neg h, EvmYul.Yul.State.lookup!, Finmap.lookup_eq_none.mpr h]; rfl

theorem ge_self (ss : EvmYul.SharedState .Yul) (vs : VarStore) (k : EvmYul.Identifier) (v : EvmYul.UInt256) :
    (EvmYul.Yul.State.Ok ss (vs.insert k v))[k]! = v := by
  rw [getElem_Ok]; simp [EvmYul.Yul.State.lookup!, Finmap.lookup_insert]

theorem ge_ne (ss : EvmYul.SharedState .Yul) (vs : VarStore) (k j : EvmYul.Identifier) (v : EvmYul.UInt256)
    (h : j ≠ k) :
    (EvmYul.Yul.State.Ok ss (vs.insert k v))[j]! = (EvmYul.Yul.State.Ok ss vs)[j]! := by
  rw [getElem_Ok, getElem_Ok]; simp [EvmYul.Yul.State.lookup!, Finmap.lookup_insert_of_ne _ h]

-- ===================== loop encoding (memory-reading body) =====================
def II : EvmYul.Identifier := "i"
def WW : EvmYul.Identifier := "w"
theorem IW : II ≠ WW := by decide
def cond (n : EvmYul.UInt256) : Expr := Expr.Call (Sum.inl Operation.LT) [Expr.Var II, Expr.Lit n]
def post : List Stmt := [Stmt.Let [II] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var II, Expr.Lit ⟨1⟩]))]
/-- The deployed masked weight read, indexed by the loop counter: `w := w + (mload(i·32) & 0xffff)`. -/
def bodyM : List Stmt :=
  [Stmt.Let [WW] (some (Expr.Call (Sum.inl Operation.ADD)
    [Expr.Var WW,
     Expr.Call (Sum.inl Operation.AND)
       [Expr.Call (Sum.inl Operation.MLOAD)
          [Expr.Call (Sum.inl Operation.MUL) [Expr.Var II, Expr.Lit ⟨32⟩]],
        Expr.Lit ⟨0xffff⟩]]))]

-- ===================== fuel-generic statement effects =====================
set_option maxHeartbeats 4000000 in
theorem body_effM (fuel a : Nat) (ss : EvmYul.SharedState .Yul) (vs : VarStore) (v : EvmYul.UInt256)
    (hi : (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat a)
    (hmload : ss.toMachineState.mload (UInt256.mul (UInt256.ofNat a) ⟨32⟩) = (v, ss.toMachineState)) :
    EvmYul.Yul.exec (fuel + 15) (Stmt.Block bodyM) none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss (Finmap.insert WW
        (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[WW]!) (EvmYul.UInt256.land v ⟨0xffff⟩)) vs)) := by
  have htss : (EvmYul.Yul.State.Ok ss vs).toSharedState = ss := rfl
  simp [bodyM, EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall, EvmYul.Yul.head',
        EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill', EvmYul.Yul.State.multifill,
        EvmYul.Yul.State.insert, step_ADD, step_MUL, step_AND, step_MLOAD, hi, htss, hmload,
        setMachineState_self]

set_option maxHeartbeats 4000000 in
theorem post_eff (fuel : Nat) (ss : EvmYul.SharedState .Yul) (vs : VarStore) :
    EvmYul.Yul.exec (fuel + 7) (Stmt.Block post) none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss (Finmap.insert II (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[II]!) ⟨1⟩) vs)) := by
  simp [post, EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall, EvmYul.Yul.head',
        EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill', EvmYul.Yul.State.multifill,
        EvmYul.Yul.State.insert, step_ADD]

set_option maxHeartbeats 4000000 in
theorem cond_eff (fuel : Nat) (n : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : VarStore) :
    EvmYul.Yul.eval (fuel + 6) (cond n) none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss vs, EvmYul.UInt256.lt ((EvmYul.Yul.State.Ok ss vs)[II]!) n) := by
  simp [cond, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail, EvmYul.Yul.evalPrimCall,
        EvmYul.Yul.primCall, EvmYul.Yul.head', EvmYul.Yul.cons', EvmYul.Yul.reverse', step_LT]

-- ===================== arithmetic helpers =====================
theorem ofNat_succ (a : Nat) : UInt256.ofNat (a + 1) = UInt256.add (UInt256.ofNat a) ⟨1⟩ := by
  unfold UInt256.ofNat UInt256.add; simp only [Id.run]; congr 1; apply Fin.ext
  show (a + 1) % UInt256.size = ((a % UInt256.size) + (1 : Fin UInt256.size).val) % UInt256.size
  have h1 : (1 : Fin UInt256.size).val = 1 % UInt256.size := rfl
  rw [h1, Nat.add_mod]

theorem lt_eq_zero_iff (a b : UInt256) : UInt256.lt a b = ⟨0⟩ ↔ ¬ (a < b) := by
  by_cases h : a < b <;>
    simp only [UInt256.lt, UInt256.fromBool, Bool.toUInt256, h, decide_true, decide_false,
               if_true, if_false] <;>
    first | (intro hc; exact absurd rfl (by decide)) |
            (constructor <;> intro <;> first | rfl | exact absurd h ‹_›) | decide | simp [h]

theorem lt_self (x : UInt256) : UInt256.lt x x = ⟨0⟩ := by
  have hnn : ¬ (x < x) := by show ¬ (x.val < x.val); exact lt_irrefl _
  have key : UInt256.lt x x = UInt256.ofNat 0 := by
    simp [UInt256.lt, UInt256.fromBool, Bool.toUInt256, decide_eq_false hnn]
  rw [key]; decide

theorem ofNat_lt {a n : Nat} (ha : a < UInt256.size) (hn : n < UInt256.size) :
    (UInt256.ofNat a < UInt256.ofNat n) ↔ a < n := by
  show (UInt256.ofNat a).val < (UInt256.ofNat n).val ↔ a < n
  unfold UInt256.ofNat; simp only [Id.run]
  show (a % UInt256.size) < (n % UInt256.size) ↔ a < n
  rw [Nat.mod_eq_of_lt ha, Nat.mod_eq_of_lt hn]

-- ===================== abstract accumulator (sum of masked slot reads) =====================
def absAccM (rdv : Nat → UInt256) : Nat → Nat → UInt256 → UInt256
  | _, 0,     w => w
  | a, m + 1, w => absAccM rdv (a + 1) m (UInt256.add w (UInt256.land (rdv a) ⟨0xffff⟩))

-- ===================== THE INDUCTION =====================
set_option maxHeartbeats 4000000 in
theorem loop_accM (N : Nat) (hN : N < UInt256.size) (rdv : Nat → EvmYul.UInt256)
    (ss : EvmYul.SharedState .Yul)
    (hcov : ∀ j, j < N →
      ss.toMachineState.mload (UInt256.mul (UInt256.ofNat j) ⟨32⟩) = (rdv j, ss.toMachineState)) :
    ∀ (m a : Nat) (w : EvmYul.UInt256) (vs : VarStore),
      a + m = N →
      (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat a →
      (EvmYul.Yul.State.Ok ss vs)[WW]! = w →
      ∃ vs', EvmYul.Yul.exec (3 * m + 15) (Stmt.For (cond (UInt256.ofNat N)) post bodyM) none (EvmYul.Yul.State.Ok ss vs)
               = .ok (EvmYul.Yul.State.Ok ss vs') ∧
             (EvmYul.Yul.State.Ok ss vs')[WW]! = absAccM rdv a m w := by
  intro m
  induction m with
  | zero =>
    intro a w vs hsum hi hw
    have ha : a = N := by omega
    refine ⟨vs, ?_, by simpa [absAccM] using hw⟩
    have hc : EvmYul.Yul.eval 12 (cond (UInt256.ofNat N)) none (EvmYul.Yul.State.mkOk (EvmYul.Yul.State.Ok ss vs))
                = .ok (EvmYul.Yul.State.Ok ss vs, ⟨0⟩) := by
      have := cond_eff 6 (UInt256.ofNat N) ss vs
      simp only [EvmYul.Yul.State.mkOk]
      rw [show (12 : Nat) = 6 + 6 from rfl, this, hi, ha, lt_self]
    rw [show (3 * 0 + 15) = 12 + 1 + 1 + 1 from rfl, exec_For, loop_base (fuel := 12) (hc := hc)]
    simp [EvmYul.Yul.State.overwrite?]
  | succ m ih =>
    intro a w vs hsum hi hw
    have haN : a < N := by omega
    have ha_sz : a < UInt256.size := by omega
    have hc : EvmYul.Yul.eval (3 * m + 15) (cond (UInt256.ofNat N)) none (EvmYul.Yul.State.Ok ss vs)
                = .ok (EvmYul.Yul.State.Ok ss vs, UInt256.lt (UInt256.ofNat a) (UInt256.ofNat N)) := by
      have := cond_eff (3 * m + 9) (UInt256.ofNat N) ss vs
      rw [show (3 * m + 15) = (3 * m + 9) + 6 from by ring, this, hi]
    have hx : UInt256.lt (UInt256.ofNat a) (UInt256.ofNat N) ≠ ⟨0⟩ := by
      rw [ne_eq, lt_eq_zero_iff, not_not]; exact (ofNat_lt ha_sz hN).mpr haN
    have hb := body_effM (3 * m) a ss vs (rdv a) hi (hcov a haN)
    rw [hw] at hb
    have hp := post_eff (3 * m + 8) ss (Finmap.insert WW (UInt256.add w (UInt256.land (rdv a) ⟨0xffff⟩)) vs)
    rw [show (3 * m + 8) + 7 = 3 * m + 15 from by ring,
        ge_ne ss vs WW II _ IW, hi, ← ofNat_succ] at hp
    have hstep := loop_step (fuel := 3 * m + 15) (c := cond (UInt256.ofNat N)) (po := post) (bo := bodyM)
                    (sa := ss) (va := vs) (hc := hc) (hx := hx) (hb := hb) (hp := hp)
    rw [show (3 * (m + 1) + 15) = (3 * m + 15) + 1 + 1 + 1 from by ring, exec_For, hstep]
    set vs₃ := Finmap.insert II (UInt256.ofNat (a + 1)) (Finmap.insert WW (UInt256.add w (UInt256.land (rdv a) ⟨0xffff⟩)) vs) with hvs₃
    have hi₃ : (EvmYul.Yul.State.Ok ss vs₃)[II]! = UInt256.ofNat (a + 1) := ge_self ss _ II _
    have hw₃ : (EvmYul.Yul.State.Ok ss vs₃)[WW]! = UInt256.add w (UInt256.land (rdv a) ⟨0xffff⟩) := by
      rw [hvs₃, ge_ne ss _ II WW _ (Ne.symm IW), ge_self]
    obtain ⟨vs', hexec, hWW⟩ := ih (a + 1) (UInt256.add w (UInt256.land (rdv a) ⟨0xffff⟩)) vs₃ (by omega) hi₃ hw₃
    exact ⟨vs', hexec, by rw [hWW]; rfl⟩

-- ===================== TOP-LEVEL =====================
theorem bytecode_loop_correct_mem (N : Nat) (hN : N < UInt256.size) (rdv : Nat → EvmYul.UInt256)
    (ss : EvmYul.SharedState .Yul) (vs : VarStore)
    (hcov : ∀ j, j < N →
      ss.toMachineState.mload (UInt256.mul (UInt256.ofNat j) ⟨32⟩) = (rdv j, ss.toMachineState))
    (hi : (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat 0)
    (hw : (EvmYul.Yul.State.Ok ss vs)[WW]! = ⟨0⟩) :
    ∃ vs', EvmYul.Yul.exec (3 * N + 15) (Stmt.For (cond (UInt256.ofNat N)) post bodyM) none (EvmYul.Yul.State.Ok ss vs)
             = .ok (EvmYul.Yul.State.Ok ss vs') ∧
           (EvmYul.Yul.State.Ok ss vs')[WW]! = absAccM rdv 0 N ⟨0⟩ :=
  loop_accM N hN rdv ss hcov N 0 ⟨0⟩ vs (by omega) hi hw

theorem bytecode_threshold_sound_mem (N : Nat) (hN : N < UInt256.size) (rdv : Nat → EvmYul.UInt256)
    (ss : EvmYul.SharedState .Yul) (vs vs' : VarStore) (thr : EvmYul.UInt256)
    (hcov : ∀ j, j < N →
      ss.toMachineState.mload (UInt256.mul (UInt256.ofNat j) ⟨32⟩) = (rdv j, ss.toMachineState))
    (hi : (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat 0)
    (hw : (EvmYul.Yul.State.Ok ss vs)[WW]! = ⟨0⟩)
    (hexec : EvmYul.Yul.exec (3 * N + 15) (Stmt.For (cond (UInt256.ofNat N)) post bodyM) none (EvmYul.Yul.State.Ok ss vs)
              = .ok (EvmYul.Yul.State.Ok ss vs'))
    (haccept : thr < (EvmYul.Yul.State.Ok ss vs')[WW]!) :
    thr < absAccM rdv 0 N ⟨0⟩ := by
  obtain ⟨vs'', hex2, hWW⟩ := bytecode_loop_correct_mem N hN rdv ss vs hcov hi hw
  rw [hexec] at hex2
  simp only [Except.ok.injEq, EvmYul.Yul.State.Ok.injEq, true_and] at hex2
  rw [hex2, hWW] at haccept
  exact haccept

-- ===================== BR-2 for the memory loop: modular accumulator carries the INTEGER sum =====================
theorem zero_ofNat : (⟨0⟩ : EvmYul.UInt256) = UInt256.ofNat 0 := by
  unfold UInt256.ofNat; simp only [Id.run]; congr 1

theorem ofNat_add (x y : Nat) :
    UInt256.add (UInt256.ofNat x) (UInt256.ofNat y) = UInt256.ofNat (x + y) := by
  unfold UInt256.add UInt256.ofNat; simp only [Id.run]; congr 1; apply Fin.ext
  simp [Fin.val_add, Fin.val_ofNat, Nat.add_mod]

theorem ofNat_toNat (v : UInt256) : UInt256.ofNat v.toNat = v := by
  unfold UInt256.ofNat UInt256.toNat; simp only [Id.run]
  apply congrArg UInt256.mk; apply Fin.ext
  show v.val.val % UInt256.size = v.val.val
  exact Nat.mod_eq_of_lt v.val.isLt

/-- The per-iteration masked read, as a `Nat` (the registered weight, once `hcov`/`weight_read` apply). -/
def mrd (rdv : Nat → UInt256) (j : Nat) : Nat := ((rdv j).land ⟨0xffff⟩).toNat

/-- ℕ-valued mirror of `absAccM`: the integer sum of the masked slot reads. -/
def absAccMNat (rdv : Nat → UInt256) : Nat → Nat → Nat → Nat
  | _, 0,     w => w
  | a, m + 1, w => absAccMNat rdv (a + 1) m (w + mrd rdv a)

theorem absAccM_val (rdv : Nat → UInt256) : ∀ (m a w : Nat), absAccMNat rdv a m w < UInt256.size →
    (absAccM rdv a m (UInt256.ofNat w)).val = absAccMNat rdv a m w := by
  intro m
  induction m with
  | zero =>
    intro a w h
    show (UInt256.ofNat w).val = w
    unfold UInt256.ofNat; simp only [Id.run]; show w % UInt256.size = w; exact Nat.mod_eq_of_lt h
  | succ m ih =>
    intro a w h
    show (absAccM rdv (a + 1) m (UInt256.add (UInt256.ofNat w) (UInt256.land (rdv a) ⟨0xffff⟩))).val
          = absAccMNat rdv (a + 1) m (w + mrd rdv a)
    rw [show UInt256.land (rdv a) ⟨0xffff⟩ = UInt256.ofNat (mrd rdv a) from (ofNat_toNat _).symm, ofNat_add]
    exact ih (a + 1) (w + mrd rdv a) h

theorem absAccM_zero_val (rdv : Nat → UInt256) (N : Nat) (h : absAccMNat rdv 0 N 0 < UInt256.size) :
    (absAccM rdv 0 N (⟨0⟩ : EvmYul.UInt256)).val = absAccMNat rdv 0 N 0 := by
  rw [zero_ofNat]; exact absAccM_val rdv N 0 0 h

/-- **Threshold soundness for the memory-reading loop, as an INTEGER inequality.** Under no overflow,
    accept (final weight > thr) ⟹ the *integer* total of the masked slot reads exceeds thr. With the
    data-layer invariant `mrd rdv j = w[j]` (each masked read is the registered weight — `DataLayer.weight_read`),
    `absAccMNat rdv 0 N 0 = Σ_{j<N} w[j] = RelaySigLoop.sumTake w N`, so this is exactly
    `RelaySigLoop.threshold_sound` carried onto the validated bytecode with a *real* memory-read body. -/
theorem bytecode_threshold_sound_mem_int (N : Nat) (hN : N < UInt256.size) (rdv : Nat → EvmYul.UInt256)
    (ss : EvmYul.SharedState .Yul) (vs vs' : VarStore) (thr : EvmYul.UInt256)
    (hcov : ∀ j, j < N →
      ss.toMachineState.mload (UInt256.mul (UInt256.ofNat j) ⟨32⟩) = (rdv j, ss.toMachineState))
    (hi : (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat 0)
    (hw : (EvmYul.Yul.State.Ok ss vs)[WW]! = ⟨0⟩)
    (hexec : EvmYul.Yul.exec (3 * N + 15) (Stmt.For (cond (UInt256.ofNat N)) post bodyM) none (EvmYul.Yul.State.Ok ss vs)
              = .ok (EvmYul.Yul.State.Ok ss vs'))
    (haccept : thr < (EvmYul.Yul.State.Ok ss vs')[WW]!)
    (hnoovf : absAccMNat rdv 0 N 0 < UInt256.size) :
    thr.val < absAccMNat rdv 0 N 0 := by
  have hmod := bytecode_threshold_sound_mem N hN rdv ss vs vs' thr hcov hi hw hexec haccept
  have key : (absAccM rdv 0 N (⟨0⟩ : EvmYul.UInt256)).val = absAccMNat rdv 0 N 0 := absAccM_zero_val rdv N hnoovf
  have hlt : thr.val < (absAccM rdv 0 N (⟨0⟩ : EvmYul.UInt256)).val := hmod
  omega

#print axioms body_effM
#print axioms loop_accM
#print axioms bytecode_loop_correct_mem
#print axioms bytecode_threshold_sound_mem
#print axioms bytecode_threshold_sound_mem_int
end RelayLoopMemRead
