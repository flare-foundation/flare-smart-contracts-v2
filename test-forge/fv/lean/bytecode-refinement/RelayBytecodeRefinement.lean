import EvmYul.Yul.Interpreter
open EvmYul EvmYul.Yul EvmYul.Yul.Ast

/-!
# Relay signature loop — bytecode-level ∀N refinement against validated EVM/Yul semantics

This file lifts the abstract signature-loop threshold soundness (`RelaySigLoop.lean`, ∀N ∀K) onto a loop
executed by NethermindEth's validated EVMYulLean operational semantics, for all N. Self-contained: it
re-proves every supporting lemma locally, so a single `lake env lean` checks the whole development.

Capstone results (all hole-free; `#print axioms` ⊆ `{propext, Classical.choice, Quot.sound}`):
* `loop_acc`            — the induction: the validated `exec` drives the loop and accumulates `absAcc`.
* `bytecode_loop_correct` — ∀N: the interpreter runs the loop to completion (exact fuel `3N+10`) and the
                            final accumulator equals `absAcc 0 N ⟨0⟩`.
* `bytecode_threshold_sound` — ∀N: on that validated execution, accept (final weight > thr) ⟹ total
                            accumulated weight > thr.

Scope note: the encoded loop is memory-free (its body adds the loop index, not a memory load), so this
establishes the loop *mechanism* on validated semantics. The data-layer fact (each addend is the
registered weight), the 256-bit overflow bound, and the encoding fidelity are stated assumptions; see
the verification documentation's claims ledger.
-/

namespace RelayBytecodeRefinement

-- ===================== control-flow bricks =====================
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

set_option maxHeartbeats 1000000 in
theorem step_ADD (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.ADD none s [a, b] = .ok (s, some (EvmYul.UInt256.add a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_LT (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.LT none s [a, b] = .ok (s, some (EvmYul.UInt256.lt a b)) := by
  unfold EvmYul.step; rfl

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

-- ===================== loop encoding =====================
def II : EvmYul.Identifier := "i"
def WW : EvmYul.Identifier := "w"
theorem IW : II ≠ WW := by decide
def cond (n : EvmYul.UInt256) : Expr := Expr.Call (Sum.inl Operation.LT) [Expr.Var II, Expr.Lit n]
def post : List Stmt := [Stmt.Let [II] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var II, Expr.Lit ⟨1⟩]))]
def body : List Stmt := [Stmt.Let [WW] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var WW, Expr.Var II]))]

-- ===================== fuel-generic statement effects =====================
set_option maxHeartbeats 4000000 in
theorem body_eff (fuel : Nat) (ss : EvmYul.SharedState .Yul) (vs : VarStore) :
    EvmYul.Yul.exec (fuel + 7) (Stmt.Block body) none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss (Finmap.insert WW (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[WW]!) ((EvmYul.Yul.State.Ok ss vs)[II]!)) vs)) := by
  simp [body, EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall, EvmYul.Yul.head',
        EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill', EvmYul.Yul.State.multifill,
        EvmYul.Yul.State.insert, step_ADD]

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

-- ===================== abstract accumulator =====================
def absAcc : Nat → Nat → UInt256 → UInt256
  | _, 0,     w => w
  | a, m + 1, w => absAcc (a + 1) m (UInt256.add w (UInt256.ofNat a))

-- ===================== THE INDUCTION: bytecode loop refines the abstract accumulator =====================
set_option maxHeartbeats 4000000 in
theorem loop_acc (N : Nat) (hN : N < UInt256.size) :
    ∀ (m a : Nat) (w : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : VarStore),
      a + m = N →
      (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat a →
      (EvmYul.Yul.State.Ok ss vs)[WW]! = w →
      ∃ vs', EvmYul.Yul.exec (3 * m + 10) (Stmt.For (cond (UInt256.ofNat N)) post body) none (EvmYul.Yul.State.Ok ss vs)
               = .ok (EvmYul.Yul.State.Ok ss vs') ∧
             (EvmYul.Yul.State.Ok ss vs')[WW]! = absAcc a m w := by
  intro m
  induction m with
  | zero =>
    intro a w ss vs hsum hi hw
    have ha : a = N := by omega
    refine ⟨vs, ?_, by simpa [absAcc] using hw⟩
    -- exec 10 (For) → loop 9 → loop_base (cond = lt (ofNat N)(ofNat N) = ⟨0⟩)
    have hc : EvmYul.Yul.eval 7 (cond (UInt256.ofNat N)) none (EvmYul.Yul.State.mkOk (EvmYul.Yul.State.Ok ss vs))
                = .ok (EvmYul.Yul.State.Ok ss vs, ⟨0⟩) := by
      have := cond_eff 1 (UInt256.ofNat N) ss vs
      simp only [EvmYul.Yul.State.mkOk]
      rw [show (7 : Nat) = 1 + 6 from rfl, this, hi, ha]
      rw [lt_self]
    rw [show (3 * 0 + 10) = 7 + 1 + 1 + 1 from rfl, exec_For, loop_base (fuel := 7) (hc := hc)]
    simp [EvmYul.Yul.State.overwrite?]
  | succ m ih =>
    intro a w ss vs hsum hi hw
    have haN : a < N := by omega
    have ha_sz : a < UInt256.size := by omega
    -- one iteration via loop_step
    have hc : EvmYul.Yul.eval (3 * m + 10) (cond (UInt256.ofNat N)) none (EvmYul.Yul.State.Ok ss vs)
                = .ok (EvmYul.Yul.State.Ok ss vs, UInt256.lt (UInt256.ofNat a) (UInt256.ofNat N)) := by
      have := cond_eff (3 * m + 4) (UInt256.ofNat N) ss vs
      rw [show (3 * m + 10) = (3 * m + 4) + 6 from by ring, this, hi]
    have hx : UInt256.lt (UInt256.ofNat a) (UInt256.ofNat N) ≠ ⟨0⟩ := by
      rw [ne_eq, lt_eq_zero_iff, not_not]; exact (ofNat_lt ha_sz hN).mpr haN
    have hb := body_eff (3 * m + 3) ss vs
    rw [show (3 * m + 3) + 7 = 3 * m + 10 from by ring, hi, hw] at hb
    -- vb = insert WW (w + ofNat a) vs
    have hp := post_eff (3 * m + 3) ss (Finmap.insert WW (UInt256.add w (UInt256.ofNat a)) vs)
    rw [show (3 * m + 3) + 7 = 3 * m + 10 from by ring,
        ge_ne ss vs WW II _ IW, hi, ← ofNat_succ] at hp
    -- assemble loop_step
    have hstep := loop_step (fuel := 3 * m + 10) (c := cond (UInt256.ofNat N)) (po := post) (bo := body)
                    (sa := ss) (va := vs) (hc := hc) (hx := hx) (hb := hb) (hp := hp)
    rw [show (3 * (m + 1) + 10) = (3 * m + 10) + 1 + 1 + 1 from by ring, exec_For, hstep]
    -- now apply ih to the post-iteration state
    set vs₃ := Finmap.insert II (UInt256.ofNat (a + 1)) (Finmap.insert WW (UInt256.add w (UInt256.ofNat a)) vs) with hvs₃
    have hi₃ : (EvmYul.Yul.State.Ok ss vs₃)[II]! = UInt256.ofNat (a + 1) := ge_self ss _ II _
    have hw₃ : (EvmYul.Yul.State.Ok ss vs₃)[WW]! = UInt256.add w (UInt256.ofNat a) := by
      rw [hvs₃, ge_ne ss _ II WW _ (Ne.symm IW), ge_self]
    obtain ⟨vs', hexec, hWW⟩ := ih (a + 1) (UInt256.add w (UInt256.ofNat a)) ss vs₃ (by omega) hi₃ hw₃
    exact ⟨vs', hexec, by rw [hWW]; rfl⟩

-- ===================== TOP-LEVEL: the deployed loop computes the accumulator, for ALL N =====================
theorem bytecode_loop_correct (N : Nat) (hN : N < UInt256.size)
    (ss : EvmYul.SharedState .Yul) (vs : VarStore)
    (hi : (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat 0)
    (hw : (EvmYul.Yul.State.Ok ss vs)[WW]! = ⟨0⟩) :
    ∃ vs', EvmYul.Yul.exec (3 * N + 10) (Stmt.For (cond (UInt256.ofNat N)) post body) none (EvmYul.Yul.State.Ok ss vs)
             = .ok (EvmYul.Yul.State.Ok ss vs') ∧
           (EvmYul.Yul.State.Ok ss vs')[WW]! = absAcc 0 N ⟨0⟩ :=
  loop_acc N hN N 0 ⟨0⟩ ss vs (by omega) hi hw

-- ===================== THRESHOLD SOUNDNESS, lifted to the bytecode =====================
-- The deployed loop's final accumulator IS the total accumulated weight (absAcc 0 N ⟨0⟩). Hence if the
-- bytecode "accepts" — its final weight strictly exceeds the threshold — then the TOTAL accumulated weight
-- exceeds the threshold. This is RelaySigLoop.threshold_sound's content (accept ⟹ enough weight), now on
-- the VALIDATED-SEMANTICS bytecode, for ALL N. (absAcc 0 N ⟨0⟩ = Σ_{j<N} ofNat j is the UInt256 mirror of
-- RelaySigLoop.sumTake over the registered weights; see PROGRESS.md.)
theorem bytecode_threshold_sound (N : Nat) (hN : N < UInt256.size)
    (ss : EvmYul.SharedState .Yul) (vs vs' : VarStore) (thr : EvmYul.UInt256)
    (hi : (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat 0)
    (hw : (EvmYul.Yul.State.Ok ss vs)[WW]! = ⟨0⟩)
    (hexec : EvmYul.Yul.exec (3 * N + 10) (Stmt.For (cond (UInt256.ofNat N)) post body) none (EvmYul.Yul.State.Ok ss vs)
              = .ok (EvmYul.Yul.State.Ok ss vs'))
    (haccept : thr < (EvmYul.Yul.State.Ok ss vs')[WW]!) :
    thr < absAcc 0 N ⟨0⟩ := by
  obtain ⟨vs'', hex2, hWW⟩ := bytecode_loop_correct N hN ss vs hi hw
  rw [hexec] at hex2
  simp only [Except.ok.injEq, EvmYul.Yul.State.Ok.injEq, true_and] at hex2
  rw [hex2, hWW] at haccept
  exact haccept

#print axioms loop_acc
#print axioms bytecode_loop_correct
#print axioms bytecode_threshold_sound
end RelayBytecodeRefinement
