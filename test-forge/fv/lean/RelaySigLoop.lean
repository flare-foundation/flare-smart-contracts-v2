/-
  Relay.sol signature-loop weight invariant — abstract ∀N ∀K proof (Phase A, Lean 4 core only).

  This is the genuinely-unbounded form of the property the Kontrol harness
  (test-forge/fv/kontrol/RelaySigLoopFV.t.sol) proves only at fixed N (3,5), and that Halmos proves
  only at bounded K. Here both are universally quantified: `w` is an arbitrary list of voter weights
  (so N = w.length is arbitrary, up to any bound) and `idxs` is an arbitrary signature stream (K
  arbitrary). The loop maintains  weight ≤ prefixSum(nextUnusedIndex)  and hence
      accept (weight > threshold)  ⟹  total registered weight > threshold,
  with no voter double-counted (the strictly-increasing-index discipline is encoded in `ValidRun`).

  Models the on-chain ACCOUNTING; assumes the cryptography (ecrecover/keccak), as in the whole engagement:
  here a "signature" is just the index it carries, and we reason about the weight it contributes.

  NEW TO LEAN / THIS SUITE?  See ../README.md §3 (how to read a Lean proof, and how to re-check it). This
  file is pure ℕ/List — it imports no EVM model, so a mathematician can read it as ordinary induction.
  Orientation for the tactics used below:
    • `induction xs with | nil => … | cons x xs ih => …`  — structural induction; `ih` is the hypothesis.
    • `omega`  — a decision procedure for linear integer arithmetic; it discharges the numeric "glue".
    • `xs.getD i d`  — the i-th element of list `xs`, or the default `d` if `i` is out of range.
    • `simp only [lemmas]` / `rw [lemma]`  — rewrite the goal using the named equations.
  The trust check: the `#print axioms` at the very bottom must be `[propext, Classical.choice, Quot.sound]`
  (Lean's three standard axioms) with no `sorryAx` — that certifies the proof is complete and gap-free.
-/
set_option linter.unusedVariables false

namespace RelaySigLoop

/-- prefixSum: the sum of the first `k` registered weights (= on-chain psAt(k)). -/
def sumTake : List Nat → Nat → Nat
  | _,        0      => 0
  | [],       _ + 1  => 0
  | x :: xs,  k + 1  => x + sumTake xs k

/-- Recurrence: one more boundary adds w[idx]. Unconditional — `getD` is 0 past the end. -/
theorem sumTake_succ (w : List Nat) (idx : Nat) :
    sumTake w (idx + 1) = sumTake w idx + w.getD idx 0 := by
  induction idx generalizing w with
  | zero =>
    cases w with
    | nil => rfl
    | cons x xs => simp [sumTake, List.getD]
  | succ n ih =>
    cases w with
    | nil => rfl
    | cons x xs =>
      have hg : (x :: xs).getD (n + 1) 0 = xs.getD n 0 := rfl
      simp only [sumTake, ih xs, hg]
      omega

/-- One step never decreases the prefix sum. -/
theorem sumTake_le_succ (w : List Nat) (k : Nat) : sumTake w k ≤ sumTake w (k + 1) := by
  rw [sumTake_succ]; exact Nat.le_add_right _ _

/-- prefixSum is monotone in the boundary. -/
theorem sumTake_mono (w : List Nat) {i j : Nat} (h : i ≤ j) : sumTake w i ≤ sumTake w j := by
  induction h with
  | refl => exact Nat.le_refl _
  | step _ ih => exact Nat.le_trans ih (sumTake_le_succ w _)

/-- The on-chain signature loop: state (weight, nextUnusedIndex), one step per signature index. -/
def loop : List Nat → Nat → Nat → List Nat → (Nat × Nat)
  | _, weight, nui, []          => (weight, nui)
  | w, weight, nui, idx :: rest => loop w (weight + w.getD idx 0) (idx + 1) rest

/-- A valid signature stream: indices strictly increasing and in range (G1+G2; no double-count). -/
inductive ValidRun (w : List Nat) : Nat → List Nat → Prop
  | nil  {nui} : ValidRun w nui []
  | cons {nui idx rest} :
      nui ≤ idx → idx < w.length → ValidRun w (idx + 1) rest → ValidRun w nui (idx :: rest)

/-- INVARIANT preserved by the whole loop, for ANY signature stream and ANY weights:
    weight ≤ prefixSum(nextUnusedIndex)  and  nextUnusedIndex ≤ N. -/
theorem loop_inv (w : List Nat) :
    ∀ (idxs : List Nat) (nui weight : Nat),
      weight ≤ sumTake w nui → nui ≤ w.length → ValidRun w nui idxs →
      (loop w weight nui idxs).1 ≤ sumTake w (loop w weight nui idxs).2 ∧
      (loop w weight nui idxs).2 ≤ w.length := by
  intro idxs
  induction idxs with
  | nil =>
    intro nui weight hw hn _
    exact ⟨hw, hn⟩
  | cons idx rest ih =>
    intro nui weight hw hn hv
    cases hv with
    | cons hle hlt hrest =>
      simp only [loop]
      apply ih (idx + 1) (weight + w.getD idx 0)
      · -- weight + w[idx] ≤ prefixSum(idx+1)
        have h2 : sumTake w nui ≤ sumTake w idx := sumTake_mono w hle
        have h4 : sumTake w idx + w.getD idx 0 = sumTake w (idx + 1) := (sumTake_succ w idx).symm
        omega
      · -- idx + 1 ≤ N
        omega
      · exact hrest

/-- THRESHOLD SOUNDNESS (∀N ∀K): if the loop accepts (final weight > threshold), then the TOTAL
    registered weight exceeds the threshold — so acceptance genuinely required enough distinct voter
    weight, with no voter counted twice. -/
theorem threshold_sound (w : List Nat) (idxs : List Nat) (thr : Nat)
    (hv : ValidRun w 0 idxs) (hacc : thr < (loop w 0 0 idxs).1) :
    thr < sumTake w w.length := by
  have hbase : (0 : Nat) ≤ sumTake w 0 := Nat.zero_le _
  have hn : (0 : Nat) ≤ w.length := Nat.zero_le _
  obtain ⟨hw, hb⟩ := loop_inv w idxs 0 0 hbase hn hv
  have hmono : sumTake w (loop w 0 0 idxs).2 ≤ sumTake w w.length := sumTake_mono w hb
  omega

/-- CONTRAPOSITIVE (∀N ∀K): if the total registered weight is within the threshold, the loop can
    never accept — for any number of signatures and any voter set. -/
theorem insufficient_weight_cannot_accept (w : List Nat) (idxs : List Nat) (thr : Nat)
    (hv : ValidRun w 0 idxs) (htot : sumTake w w.length ≤ thr) :
    (loop w 0 0 idxs).1 ≤ thr :=
  Nat.not_lt.mp (fun hlt => absurd (threshold_sound w idxs thr hv hlt) (Nat.not_lt.mpr htot))

end RelaySigLoop

#print axioms RelaySigLoop.threshold_sound
#print axioms RelaySigLoop.insufficient_weight_cannot_accept
