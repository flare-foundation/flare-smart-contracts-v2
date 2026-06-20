# L4 — The formal detail

> **What you get from this level.** The verbatim Lean 4 development, walked end to end, at the precision
> a referee needs to reconstruct or attack it. **§A** Phase A; **§B** the EVMYulLean API as we actually
> use it; **§C** the Gap-B bricks and capstone; **§D** *fuel-genericity* in full; **§E** the non-obvious
> pitfalls and their fixes; **§F** the axiom audit. File paths are relative to the repo root.
>
> Every code block below is copied from the committed sources
> (`test-forge/fv/lean/RelaySigLoop.lean`, `test-forge/fv/lean/gapB/GapB_close.lean`). Line numbers cited
> are as committed at the Gap-B-closed checkpoint.

---

## §A. Phase A in full — `RelaySigLoop.lean`

Phase A imports nothing but Lean core (`set_option linter.unusedVariables false` aside). Everything is
over `ℕ`.

### A.1 Prefix sum and its three facts

```lean
def sumTake : List Nat → Nat → Nat
  | _,        0      => 0
  | [],       _ + 1  => 0
  | x :: xs,  k + 1  => x + sumTake xs k
```

```lean
theorem sumTake_succ (w : List Nat) (idx : Nat) :
    sumTake w (idx + 1) = sumTake w idx + w.getD idx 0 := by
  induction idx generalizing w with
  | zero => cases w with | nil => rfl | cons x xs => simp [sumTake, List.getD]
  | succ n ih => cases w with
    | nil => rfl
    | cons x xs =>
      have hg : (x :: xs).getD (n + 1) 0 = xs.getD n 0 := rfl
      simp only [sumTake, ih xs, hg]; omega
```

`sumTake_succ` is the **one-step recurrence** (`getD` returns `0` past the end, making it unconditional).
From it:

```lean
theorem sumTake_le_succ (w : List Nat) (k : Nat) : sumTake w k ≤ sumTake w (k + 1) := by
  rw [sumTake_succ]; exact Nat.le_add_right _ _

theorem sumTake_mono (w : List Nat) {i j : Nat} (h : i ≤ j) : sumTake w i ≤ sumTake w j := by
  induction h with
  | refl => exact Nat.le_refl _
  | step _ ih => exact Nat.le_trans ih (sumTake_le_succ w _)
```

`sumTake_mono` inducts on the *proof* `h : i ≤ j` (Lean's `Nat.le` is inductively `refl`/`step`), the
cleanest way to get monotonicity.

### A.2 The loop, the validity predicate, the invariant

```lean
def loop : List Nat → Nat → Nat → List Nat → (Nat × Nat)
  | _, weight, nui, []          => (weight, nui)
  | w, weight, nui, idx :: rest => loop w (weight + w.getD idx 0) (idx + 1) rest

inductive ValidRun (w : List Nat) : Nat → List Nat → Prop
  | nil  {nui} : ValidRun w nui []
  | cons {nui idx rest} :
      nui ≤ idx → idx < w.length → ValidRun w (idx + 1) rest → ValidRun w nui (idx :: rest)
```

The invariant is stated with the quantifiers *after* the list argument so the induction generalizes over
`nui` and `weight` automatically:

```lean
theorem loop_inv (w : List Nat) :
    ∀ (idxs : List Nat) (nui weight : Nat),
      weight ≤ sumTake w nui → nui ≤ w.length → ValidRun w nui idxs →
      (loop w weight nui idxs).1 ≤ sumTake w (loop w weight nui idxs).2 ∧
      (loop w weight nui idxs).2 ≤ w.length := by
  intro idxs
  induction idxs with
  | nil => intro nui weight hw hn _; exact ⟨hw, hn⟩
  | cons idx rest ih =>
    intro nui weight hw hn hv
    cases hv with
    | cons hle hlt hrest =>
      simp only [loop]
      apply ih (idx + 1) (weight + w.getD idx 0)
      · have h2 : sumTake w nui ≤ sumTake w idx := sumTake_mono w hle
        have h4 : sumTake w idx + w.getD idx 0 = sumTake w (idx + 1) := (sumTake_succ w idx).symm
        omega
      · omega
      · exact hrest
```

Note the proof obligations handed to `ih`: the weight bound (closed by `omega` from `h2`, `h4`, `hw`),
the range bound `idx+1 ≤ N` (from `hlt`), and the residual `ValidRun` (from the `cons` case).
`cases hv` is what extracts `nui ≤ idx`, `idx < N`, and the tail validity.

### A.3 The theorems

```lean
theorem threshold_sound (w : List Nat) (idxs : List Nat) (thr : Nat)
    (hv : ValidRun w 0 idxs) (hacc : thr < (loop w 0 0 idxs).1) :
    thr < sumTake w w.length := by
  have hbase : (0 : Nat) ≤ sumTake w 0 := Nat.zero_le _
  have hn : (0 : Nat) ≤ w.length := Nat.zero_le _
  obtain ⟨hw, hb⟩ := loop_inv w idxs 0 0 hbase hn hv
  have hmono : sumTake w (loop w 0 0 idxs).2 ≤ sumTake w w.length := sumTake_mono w hb
  omega

theorem insufficient_weight_cannot_accept (w : List Nat) (idxs : List Nat) (thr : Nat)
    (hv : ValidRun w 0 idxs) (htot : sumTake w w.length ≤ thr) :
    (loop w 0 0 idxs).1 ≤ thr :=
  Nat.not_lt.mp (fun hlt => absurd (threshold_sound w idxs thr hv hlt) (Nat.not_lt.mpr htot))
```

That is the entire Phase A. It is small because the invariant is the right one; the `omega` calls
discharge the linear-arithmetic glue. Nothing here mentions the EVM.

---

## §B. The EVMYulLean API, as we use it

Gap B is built against EVMYulLean (`import EvmYul.Yul.Interpreter`). The facts we rely on — collected so
they are never re-derived (full list in `gapB/PROGRESS.md`):

- **Words.** `Literal := UInt256`, and `UInt256 := Fin 2²⁵⁶` written `⟨val⟩`. So `⟨0⟩` is zero,
  `⟨1⟩` is one. `UInt256.ofNat n` is `n mod 2²⁵⁶`; `UInt256.add` is `+` mod 2²⁵⁶; `UInt256.lt a b`
  returns `⟨1⟩`/`⟨0⟩` via `fromBool (a < b)`.
- **AST.** `Expr := Call (PrimOp ⊕ FnName) (List Expr) | Var Identifier | Lit Literal`;
  `Stmt := Block (List Stmt) | Let (List Identifier) (Option Expr) | For Expr (List Stmt) (List Stmt)
  | If | Switch | Continue | Break | Leave | ExprStmtCall`. **`For cond post body` has no init**
  (the optimizer's `ForLoopInitRewriter` hoists it out) — this is why our encoding has none.
- **State.** `State := Ok (SharedState .Yul) VarStore | OutOfFuel | Checkpoint Jump`;
  `VarStore := Finmap (Identifier ⇀ Literal)`; `Identifier := String` (but see Gotcha E.1 — it is a
  `def`, not an `abbrev`).
- **Interpreter.** `exec (fuel) (stmt) (codeOverride) (s) : Except Exception State`;
  `loop (fuel) (cond) (post body) (codeOverride) (s)`; `eval (fuel) (expr) ... : Except Exception
  (State × Literal)`. Expression calls go `eval → evalArgs/evalTail → evalPrimCall → execPrimCall →
  primCall → step` (the per-opcode `Semantics` dispatch).
- **Validation.** EVMYulLean is exercised against the Ethereum execution-spec tests; that is the basis
  for treating it as *the* EVM (L2 §2.4).

The version/build pin (Lean 4.22.0, mathlib 4.22.0, FFI keccak/sha2) is in
[L6](06-reproduce-and-lessons.md).

---

## §C. Gap B — `gapB/GapB_close.lean`, walked

The file is self-contained: it re-proves its bricks locally so it checks with one `lake env lean`.

### C.1 Control-flow bricks (lines 6–27)

```lean
theorem exec_For (fuel : Nat) (c : Expr) (po bo : List Stmt) (s : EvmYul.Yul.State) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.For c po bo) none s = EvmYul.Yul.loop fuel c po bo none s := by
  unfold EvmYul.Yul.exec; rfl
```

`exec` of a `For` at fuel `fuel+1` unfolds definitionally to `loop` at fuel `fuel` — pure `rfl` after one
`unfold`. (This is our first use of *symbolic-fuel + concrete-offset*: `fuel+1`, not a literal.)

```lean
theorem loop_base (fuel : Nat) (c : Expr) (po bo : List Stmt) (s s₁ : EvmYul.Yul.State)
    (hc : EvmYul.Yul.eval fuel c none (EvmYul.Yul.State.mkOk s) = .ok (s₁, ⟨0⟩)) :
    EvmYul.Yul.loop (fuel + 1 + 1) c po bo none s = .ok (EvmYul.Yul.State.overwrite? s₁ s) := by
  unfold EvmYul.Yul.loop; simp only [hc]; rfl
```

If the condition evaluates to `⟨0⟩`, the loop exits restoring the outer scope (`overwrite?`). The
hypothesis is stated over `mkOk s` because that is what `loop` feeds to `eval`.

```lean
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
```

`loop_step` is the engine of the induction: *one* iteration (condition non-zero, run `body` then `post`)
equals continuing as `exec (For ...)` on the post-state `s₃`. The final `cases ... <;> rfl` discharges
the `Except` match identity (both branches reduce to the same thing). See Gotcha E.2 for why `hc` is
stated over `Ok sa va` and not `mkOk (Ok sa va)`.

### C.2 Opcode bricks (lines 29–36)

```lean
set_option maxHeartbeats 1000000 in
theorem step_ADD (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.ADD none s [a, b] = .ok (s, some (EvmYul.UInt256.add a b)) := by
  unfold EvmYul.step; rfl
set_option maxHeartbeats 1000000 in
theorem step_LT (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.LT none s [a, b] = .ok (s, some (EvmYul.UInt256.lt a b)) := by
  unfold EvmYul.step; rfl
```

The per-opcode meaning. `step` is an `Id.run do` with a `dbg_trace op.pretty` preamble; `unfold; rfl`
sees through the trace and the monadic `do`. The raised `maxHeartbeats` is because `step` dispatches over
the full opcode enum.

### C.3 The state-access bridge (lines 39–53)

Reading a Yul variable is `s[id]!` (a `GetElem!` on the state). We need to relate it to `Finmap.lookup`.

```lean
theorem getElem_Ok (ss : EvmYul.SharedState .Yul) (vs : VarStore) (id : EvmYul.Identifier) :
    (EvmYul.Yul.State.Ok ss vs)[id]! = EvmYul.Yul.State.lookup! id (EvmYul.Yul.State.Ok ss vs) := by
  simp only [getElem!, decidableGetElem?, EvmYul.Yul.State.store]
  by_cases h : id ∈ vs
  · simp only [dif_pos h]; rfl
  · simp only [dif_neg h, EvmYul.Yul.State.lookup!, Finmap.lookup_eq_none.mpr h]; rfl
```

This holds **only for `Ok` states** (Gotcha E.3): a `Checkpoint` state's `.store` is `default`, but
`lookup!` reads the checkpoint's own store, so they disagree there. Our loop only ever produces `Ok`
states, so the restriction is free. Two corollaries thread the `Finmap`:

```lean
theorem ge_self (ss) (vs) (k) (v) : (State.Ok ss (vs.insert k v))[k]! = v := by
  rw [getElem_Ok]; simp [State.lookup!, Finmap.lookup_insert]

theorem ge_ne (ss) (vs) (k j) (v) (h : j ≠ k) :
    (State.Ok ss (vs.insert k v))[j]! = (State.Ok ss vs)[j]! := by
  rw [getElem_Ok, getElem_Ok]; simp [State.lookup!, Finmap.lookup_insert_of_ne _ h]
```

(`Finmap.lookup_insert` / `lookup_insert_of_ne` are the standard finite-map laws.) These let the
induction track exactly which variable each `insert` changed.

### C.4 The loop encoding (lines 56–61)

```lean
def II : EvmYul.Identifier := "i"
def WW : EvmYul.Identifier := "w"
theorem IW : II ≠ WW := by decide
def cond (n : EvmYul.UInt256) : Expr := Expr.Call (Sum.inl Operation.LT) [Expr.Var II, Expr.Lit n]
def post : List Stmt := [Stmt.Let [II] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var II, Expr.Lit ⟨1⟩]))]
def body : List Stmt := [Stmt.Let [WW] (some (Expr.Call (Sum.inl Operation.ADD) [Expr.Var WW, Expr.Var II]))]
```

`II`/`WW` are *named definitions* of type `EvmYul.Identifier` (not raw string literals — Gotcha E.1).
`IW : II ≠ WW` is `by decide`. `cond/post/body` are the real Yul AST nodes for `lt(i,N)`, `i := add(i,1)`,
`w := add(w,i)`.

### C.5 Fuel-generic statement effects (lines 64–87)

These are the payoff of §D. Each is universally quantified over `fuel`, proven at `fuel + K`:

```lean
set_option maxHeartbeats 4000000 in
theorem body_eff (fuel : Nat) (ss) (vs) :
    EvmYul.Yul.exec (fuel + 7) (Stmt.Block body) none (State.Ok ss vs)
    = .ok (State.Ok ss (Finmap.insert WW (UInt256.add ((State.Ok ss vs)[WW]!) ((State.Ok ss vs)[II]!)) vs)) := by
  simp [body, EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall, EvmYul.Yul.head',
        EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill', EvmYul.Yul.State.multifill,
        EvmYul.Yul.State.insert, step_ADD]
```

`post_eff` (inserts `II ↦ i+1`) and `cond_eff` (`eval (fuel+6) (cond n) = (state, lt(i,n))`) are the
same shape with `step_ADD`/`step_LT`. The big `simp` set is the entire expression-evaluation pipeline;
`step_ADD`/`step_LT` close the opcode leaves. The RHS deliberately uses the interpreter's *own* accessor
`(State.Ok ss vs)[WW]!` rather than a literal (Gotcha E.1).

### C.6 Arithmetic helpers (lines 90–114)

Four facts about `𝕌`:

- `ofNat_succ : ofNat (a+1) = add (ofNat a) ⟨1⟩` — proved via `Fin.ext` and `Nat.add_mod` (the increment
  in `post` matches `ofNat` of the successor).
- `lt_eq_zero_iff : lt a b = ⟨0⟩ ↔ ¬(a < b)` — relates the word-valued `LT` to the Prop `<`.
- `lt_self : lt x x = ⟨0⟩` — the loop-exit fact (condition false when `i = N`); proved through
  `show ¬(x.val < x.val); exact lt_irrefl _` to pin the right `<` instance (Gotcha E.4).
- `ofNat_lt : a, n < 2²⁵⁶ → (ofNat a < ofNat n ↔ a < n)` — moves between `𝕌`-order and `ℕ`-order under
  the no-wrap hypotheses (used to fire the loop body while `a < N`).

### C.7 The abstract accumulator and the induction (lines 117–173)

```lean
def absAcc : Nat → Nat → UInt256 → UInt256
  | _, 0,     w => w
  | a, m + 1, w => absAcc (a + 1) m (UInt256.add w (UInt256.ofNat a))
```

```lean
set_option maxHeartbeats 4000000 in
theorem loop_acc (N : Nat) (hN : N < UInt256.size) :
    ∀ (m a : Nat) (w : EvmYul.UInt256) (ss) (vs),
      a + m = N →
      (State.Ok ss vs)[II]! = UInt256.ofNat a →
      (State.Ok ss vs)[WW]! = w →
      ∃ vs', EvmYul.Yul.exec (3 * m + 10) (Stmt.For (cond (UInt256.ofNat N)) post body) none (State.Ok ss vs)
               = .ok (State.Ok ss vs') ∧
             (State.Ok ss vs')[WW]! = absAcc a m w := by
  intro m
  induction m with
  | zero =>
    intro a w ss vs hsum hi hw
    have ha : a = N := by omega
    refine ⟨vs, ?_, by simpa [absAcc] using hw⟩
    have hc : EvmYul.Yul.eval 7 (cond (UInt256.ofNat N)) none (State.mkOk (State.Ok ss vs))
                = .ok (State.Ok ss vs, ⟨0⟩) := by
      have := cond_eff 1 (UInt256.ofNat N) ss vs
      simp only [State.mkOk]
      rw [show (7 : Nat) = 1 + 6 from rfl, this, hi, ha]
      rw [lt_self]
    rw [show (3 * 0 + 10) = 7 + 1 + 1 + 1 from rfl, exec_For, loop_base (fuel := 7) (hc := hc)]
    simp [State.overwrite?]
  | succ m ih =>
    intro a w ss vs hsum hi hw
    have haN : a < N := by omega
    have ha_sz : a < UInt256.size := by omega
    have hc : EvmYul.Yul.eval (3 * m + 10) (cond (UInt256.ofNat N)) none (State.Ok ss vs)
                = .ok (State.Ok ss vs, UInt256.lt (UInt256.ofNat a) (UInt256.ofNat N)) := by
      have := cond_eff (3 * m + 4) (UInt256.ofNat N) ss vs
      rw [show (3 * m + 10) = (3 * m + 4) + 6 from by ring, this, hi]
    have hx : UInt256.lt (UInt256.ofNat a) (UInt256.ofNat N) ≠ ⟨0⟩ := by
      rw [ne_eq, lt_eq_zero_iff, not_not]; exact (ofNat_lt ha_sz hN).mpr haN
    have hb := body_eff (3 * m + 3) ss vs
    rw [show (3 * m + 3) + 7 = 3 * m + 10 from by ring, hi, hw] at hb
    have hp := post_eff (3 * m + 3) ss (Finmap.insert WW (UInt256.add w (UInt256.ofNat a)) vs)
    rw [show (3 * m + 3) + 7 = 3 * m + 10 from by ring,
        ge_ne ss vs WW II _ IW, hi, ← ofNat_succ] at hp
    have hstep := loop_step (fuel := 3 * m + 10) (c := cond (UInt256.ofNat N)) (po := post) (bo := body)
                    (sa := ss) (va := vs) (hc := hc) (hx := hx) (hb := hb) (hp := hp)
    rw [show (3 * (m + 1) + 10) = (3 * m + 10) + 1 + 1 + 1 from by ring, exec_For, hstep]
    set vs₃ := Finmap.insert II (UInt256.ofNat (a + 1)) (Finmap.insert WW (UInt256.add w (UInt256.ofNat a)) vs) with hvs₃
    have hi₃ : (State.Ok ss vs₃)[II]! = UInt256.ofNat (a + 1) := ge_self ss _ II _
    have hw₃ : (State.Ok ss vs₃)[WW]! = UInt256.add w (UInt256.ofNat a) := by
      rw [hvs₃, ge_ne ss _ II WW _ (Ne.symm IW), ge_self]
    obtain ⟨vs', hexec, hWW⟩ := ih (a + 1) (UInt256.add w (UInt256.ofNat a)) ss vs₃ (by omega) hi₃ hw₃
    exact ⟨vs', hexec, by rw [hWW]; rfl⟩
```

This is the whole argument. Read the `succ` case as the §C.3 proof sketch made literal:

1. `hc` — the condition evaluates to `lt(ofNat a, ofNat N)` (via `cond_eff` at the matching fuel).
2. `hx` — that value is non-zero because `a < N` (via `ofNat_lt`); the iteration fires.
3. `hb` — `body` inserts `WW ↦ w + ofNat a` (via `body_eff`, after rewriting `i`/`w` by `hi`/`hw`).
4. `hp` — `post` then inserts `II ↦ ofNat(a+1)` (via `post_eff`; `ge_ne ... WW II ... IW` says inserting
   `WW` did not disturb `II`, and `← ofNat_succ` turns `i+1` into `ofNat(a+1)`).
5. `hstep` — `loop_step` glues one iteration to "continue as `exec (For ...)` on the post-state".
6. The fuel bookkeeping `3*(m+1)+10 = (3*m+10)+1+1+1` and `exec_For` line up the recursion.
7. `set vs₃ := ...` names the post-iteration store; `hi₃`/`hw₃` read back its `i`/`w` (via `ge_self` /
   `ge_ne`); the **induction hypothesis** `ih` at `(a+1, m)` finishes, and `absAcc`'s defining equation
   makes the accumulators agree (`by rw [hWW]; rfl`).

### C.8 The capstone and the transfer (lines 176–203)

```lean
theorem bytecode_loop_correct (N : Nat) (hN : N < UInt256.size) (ss) (vs)
    (hi : (State.Ok ss vs)[II]! = UInt256.ofNat 0) (hw : (State.Ok ss vs)[WW]! = ⟨0⟩) :
    ∃ vs', EvmYul.Yul.exec (3 * N + 10) (Stmt.For (cond (UInt256.ofNat N)) post body) none (State.Ok ss vs)
             = .ok (State.Ok ss vs') ∧ (State.Ok ss vs')[WW]! = absAcc 0 N ⟨0⟩ :=
  loop_acc N hN N 0 ⟨0⟩ ss vs (by omega) hi hw
```

`bytecode_loop_correct` is just `loop_acc` at `m = N, a = 0` (`0 + N = N`). Then:

```lean
theorem bytecode_threshold_sound (N : Nat) (hN : N < UInt256.size) (ss) (vs vs') (thr : EvmYul.UInt256)
    (hi : (State.Ok ss vs)[II]! = UInt256.ofNat 0) (hw : (State.Ok ss vs)[WW]! = ⟨0⟩)
    (hexec : EvmYul.Yul.exec (3 * N + 10) (Stmt.For (cond (UInt256.ofNat N)) post body) none (State.Ok ss vs)
              = .ok (State.Ok ss vs'))
    (haccept : thr < (State.Ok ss vs')[WW]!) :
    thr < absAcc 0 N ⟨0⟩ := by
  obtain ⟨vs'', hex2, hWW⟩ := bytecode_loop_correct N hN ss vs hi hw
  rw [hexec] at hex2
  simp only [Except.ok.injEq, EvmYul.Yul.State.Ok.injEq, true_and] at hex2
  rw [hex2, hWW] at haccept
  exact haccept
```

The transfer: `bytecode_loop_correct` produces a final store `vs''` with `vs''[w] = absAcc 0 N ⟨0⟩`;
since `exec` is a function and `hexec` already gives `vs'`, the injectivity simp (`Except.ok.injEq`,
`State.Ok.injEq`) forces `vs' = vs''`; substitute and the acceptance hypothesis *is* the goal.

---

## §D. Fuel-genericity, in full

This is the technique most worth extracting. The setting: `exec`/`eval` are defined by structural
recursion on a `fuel : ℕ`, decrementing it. EVMYulLean provides **no** monotonicity lemma
`exec f s = .ok r → exec (f+1) s = .ok r`. (Proving one in general is real work — it needs an invariant
about how every constructor consumes fuel.) Naively, then, in an induction where the available fuel is a
symbolic `3m+10`, you cannot reduce `exec`.

**Resolution.** You never reduce at *arbitrary* fuel; you reduce at fuel `fuel + K` with `fuel` a free
variable and `K` the *exact* number of unfoldings the statement needs. Concretely, `simp [exec, eval,
...]` unfolds the recursion; each unfolding pattern-matches `fuel + K` as `Nat.succ (... (fuel) ...)` and
peels one `succ`. After exactly `K` peels the statement is fully evaluated and the leftover `fuel` sits
inertly in the (already-computed) result. Because `fuel` is universally quantified, the lemma you get —
e.g. `body_eff : ∀ fuel, exec (fuel+7) (Block body) s = .ok (...)` — applies at *any* fuel you later need,
in particular the symbolic `3m+3` arising in the induction (`(3m+3)+7 = 3m+10`).

The constants are determined empirically per statement (here `7` for a one-assignment block, `6` for the
condition) and verified by the proof going through: if `K` were wrong, the `simp` would leave a stuck
`exec`/`OutOfFuel` and fail. The induction then chooses concrete offsets so the symbolic fuels line up:
the `rw [show (3*m+3)+7 = 3*m+10 from by ring]` lines are exactly this alignment.

**Why this is the crux.** It converts "I need a monotonicity meta-theorem about someone else's
interpreter" into "I need to know each statement's exact fuel cost" — a *local, decidable* fact the
simplifier establishes for free. The whole induction reduces to gluing these generic per-statement
effects with `loop_step`. The technique is not specific to EVMYulLean; it works for **any** fuel-indexed
definitional interpreter.

---

## §E. Pitfalls and their fixes (so a reimplementer avoids them)

- **E.1 `Identifier` is a `def`, not an `abbrev`.** `Identifier := String` is opaque to typeclass
  synthesis. Writing a raw string literal `"w"` where an `Identifier` key is expected collapses it to
  `String` and `GetElem?` instance search fails. Fix: introduce keys as *named definitions*
  (`def WW : EvmYul.Identifier := "w"`) and state RHS accessors with the interpreter's own `s[a]!` over
  `Identifier` *variables*, never string literals.

- **E.2 `mkOk` desync in `loop_step`.** `loop` feeds `eval` a `mkOk s`, and `simp` reduces `mkOk` early.
  If `hc` is phrased over `mkOk (Ok sa va)` the rewrite desyncs (the term is already reduced). Fix: state
  `hc` directly over `Ok sa va`. The trailing `cases (exec For ...) <;> rfl` then settles the `Except`
  match identity.

- **E.3 `getElem_Ok` is `Ok`-only.** A `Checkpoint` state has `.store = default` but `lookup!` reads the
  checkpoint store, so the bridge fails there. Safe because the loop only produces `Ok` states; keep all
  state-access lemmas restricted to `Ok`.

- **E.4 The right `<` instance in `lt_self`.** `lt_irrefl` may pick the preorder `<` while the goal
  carries the `Fin`/`UInt256` `<`. Fix: `show ¬(x.val < x.val)` to force the `Nat`-level `<`, then
  `lt_irrefl _`; finish the residual `ofNat 0 = ⟨0⟩` by `decide`.

- **E.5 Argument order in `ge_ne`.** `ge_ne ss vs k j v h` proves `(insert k v)[j]! = vs[j]!` for
  `j ≠ k`. It is easy to swap `k`/`j`; in the induction the two uses are `ge_ne ss vs WW II _ IW` (post
  did not disturb the `WW` we just set... read: inserting `WW` leaves `II`) and
  `ge_ne ss _ II WW _ (Ne.symm IW)`. Both directions of `IW` are needed.

- **E.6 Named arguments for `loop_step`.** Positional application got stuck on the many implicit/explicit
  slots; supplying `(fuel:=)(c:=)(po:=)(bo:=)(sa:=)(va:=)(hc:=)(hx:=)(hb:=)(hp:=)` is what makes it
  elaborate.

---

## §F. The axiom audit

Every claim of correctness in this project is backed by Lean's `#print axioms`. The file ends with:

```lean
#print axioms loop_acc
#print axioms bytecode_loop_correct
#print axioms bytecode_threshold_sound
```

and the build prints, for all three:

```
'GapB.loop_acc' depends on axioms: [propext, Classical.choice, Quot.sound]
'GapB.bytecode_loop_correct' depends on axioms: [propext, Classical.choice, Quot.sound]
'GapB.bytecode_threshold_sound' depends on axioms: [propext, Classical.choice, Quot.sound]
```

What this means, and why it is the right bar:

- **`propext`, `Classical.choice`, `Quot.sound`** are Lean 4's three standard foundational axioms,
  the same ones mathlib is built on. They are known consistent (they hold in the standard model) and are
  *not* statements about our problem — accepting them is accepting classical mathematics, nothing
  domain-specific.
- **No `sorryAx`.** This is the decisive one: `sorryAx` is what appears if *any* proof in the dependency
  tree contains a `sorry` (a hole) or fails. Its absence certifies the proof is **complete** — no gaps,
  no admitted lemmas.
- **No `Lean.ofReduceBool`.** This would appear if we had used `native_decide` (trusting the compiler to
  evaluate a decision procedure). We deliberately avoided it: it both enlarges the trusted base (the
  Lean compiler + our FFI) and, for memory programs, cannot even link the FFI in a plain file. Our proofs
  reduce inside the kernel.

The same audit applies to Phase A (`#print axioms threshold_sound` → `[propext, Classical.choice,
Quot.sound]`). "Bulletproof" in this engagement is defined as exactly this: every committed theorem
checks with that axiom list and nothing more.

**Next:** [L5 — Limits, trust & residual](05-limits-trust-and-residual.md): the precise boundary — what
is proven, what is assumed, and what a skeptic must still verify to trust the deployment.
