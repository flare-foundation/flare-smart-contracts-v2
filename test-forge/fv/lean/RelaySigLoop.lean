/-
  Relay.sol signature-loop weight invariant — abstract ∀N ∀K proof (Lean 4 core only).

  The theorem quantifies universally: `w` is an arbitrary list of voter weights
  (so N = w.length is arbitrary, up to any bound) and `idxs` is an arbitrary signature stream (K
  arbitrary). The loop maintains  weight ≤ prefixSum(nextUnusedIndex)  and hence
      accept (weight > threshold)  ⟹  total registered weight > threshold,
  with no policy INDEX counted twice (the strictly-increasing-index discipline is encoded in `ValidRun`).

  Identity boundary: this model contains weights and indices, not voter addresses. Interpreting its total
  as weight from distinct signing identities additionally requires the admitted policy to have unique
  addresses. The theorem therefore requires a separate unique-address policy-admission invariant for a
  distinct-identity interpretation.

  Models the on-chain ACCOUNTING and assumes the cryptography (ecrecover/keccak):
  here a "signature" is just the index it carries, and we reason about the weight it contributes.

  This file is pure ℕ/List and imports no EVM model, so it can be read as ordinary induction.
  Orientation for the tactics used below:
    • `induction xs with | nil => … | cons x xs ih => …`  — structural induction; `ih` is the hypothesis.
    • `omega`  — a decision procedure for linear integer arithmetic; it discharges the numeric "glue".
    • `xs.getD i d`  — the i-th element of list `xs`, or the default `d` if `i` is out of range.
    • `simp only [lemmas]` / `rw [lemma]`  — rewrite the goal using the named equations.
  The trust check: the `#print axioms` at the very bottom must be `[propext, Quot.sound]`
  (a subset of Lean's three standard axioms — this proof doesn't even need `Classical.choice`) with no
  `sorryAx` — that certifies the proof is complete and gap-free.
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

/-- A valid signature stream: indices strictly increasing and in range (G1+G2; no repeated slot). -/
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
    indexed policy weight exceeds the threshold, with no policy slot counted twice. A distinct-signer
    interpretation is conditional on voter-address uniqueness at policy admission. -/
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

/-! ## Protocol-1 BIPS override seam

The optimized Yul first selects an effective threshold and then enters the
strict signature loop. This section models that selection seam:

* protocol ID 1 with a nonzero transient override selects
  `floor(totalWeight * overrideBIPS / 10000)`;
* a zero override or any other protocol ID preserves the policy threshold; and
* strict comparison against the floor is exactly the advertised cross-product
  predicate, with no `UInt256` multiplication wrap under the parser field bounds.

The separate EVMYulLean storage layer proves the supported `TSTORE`/`TLOAD`
round-trip, clear, and account-isolation facts.  Call-frame rollback is not a
claim of this arithmetic/dispatch model. -/

/-- BIPS denominator used literally by the optimized Relay Yul. -/
def thresholdBIPS : Nat := 10000

/-- Parser-wide total-weight bound: at most `2^16-1` voters, each carrying a
`2^16-1` weight. Valid registered policies use the tighter `totalWeight < 2^16`
bound, but the wider parser bound also suffices for overflow freedom. -/
def parserTotalWeightMax : Nat := 65535 * 65535

/-- Modulus of the EVM's `UInt256` arithmetic. -/
def uint256Modulus : Nat := 2 ^ 256

/-- Floor plus strict comparison is exactly the cross-product BIPS predicate. -/
theorem bips_floor_strict_iff_cross (signedWeight totalWeight bips : Nat) :
    totalWeight * bips / thresholdBIPS < signedWeight ↔
      totalWeight * bips < signedWeight * thresholdBIPS := by
  exact Nat.div_lt_iff_lt_mul (by decide)

/-- The Yul product used to derive the override threshold cannot wrap a
`UInt256`, even under the wider parser field bounds. -/
theorem override_product_noOverflow (totalWeight bips : Nat)
    (htotal : totalWeight ≤ parserTotalWeightMax) (hbips : bips < thresholdBIPS) :
    totalWeight * bips < uint256Modulus := by
  have hbipsValue : bips < 10000 := by simpa [thresholdBIPS] using hbips
  have hbips' : bips ≤ 9999 := by omega
  have hproduct : totalWeight * bips ≤ parserTotalWeightMax * 9999 :=
    Nat.mul_le_mul htotal hbips'
  have hconstant : parserTotalWeightMax * 9999 < uint256Modulus := by decide
  exact Nat.lt_of_le_of_lt hproduct hconstant

/-- Faithful threshold-selection seam from optimized Yul lines 1363-1370. -/
def selectThreshold
    (protocolId overrideBIPS totalWeight policyThreshold : Nat) : Nat :=
  if protocolId = 1 then
    if overrideBIPS = 0 then policyThreshold
    else totalWeight * overrideBIPS / thresholdBIPS
  else
    policyThreshold

/-- Zero is the transient-slot sentinel and therefore preserves the policy
threshold for every protocol ID. -/
theorem selectThreshold_zero
    (protocolId totalWeight policyThreshold : Nat) :
    selectThreshold protocolId 0 totalWeight policyThreshold = policyThreshold := by
  simp [selectThreshold]

/-- A transient value cannot override any protocol other than protocol ID 1. -/
theorem selectThreshold_nonProtocolOne
    (protocolId overrideBIPS totalWeight policyThreshold : Nat)
    (hpid : protocolId ≠ 1) :
    selectThreshold protocolId overrideBIPS totalWeight policyThreshold = policyThreshold := by
  simp [selectThreshold, hpid]

/-- Protocol ID 1 with a nonzero override selects the BIPS-derived floor. -/
theorem selectThreshold_protocolOne
    (overrideBIPS totalWeight policyThreshold : Nat)
    (hoverride : overrideBIPS ≠ 0) :
    selectThreshold 1 overrideBIPS totalWeight policyThreshold =
      totalWeight * overrideBIPS / thresholdBIPS := by
  simp [selectThreshold, hoverride]

/-- Every nonzero total clears every admitted override below 10000 BIPS when
all of its weight signs. -/
theorem fullWeight_accepts_sub10000 (totalWeight bips : Nat)
    (htotal : 0 < totalWeight) (hbips : bips < thresholdBIPS) :
    totalWeight * bips / thresholdBIPS < totalWeight := by
  apply (bips_floor_strict_iff_cross totalWeight totalWeight bips).2
  exact Nat.mul_lt_mul_of_pos_left hbips htotal

/-- Composition capstone: on protocol ID 1, a strict-loop acceptance under a
nonzero override both satisfies the exact cross-product predicate for the
actually accumulated signature weight and retains the existing indexed-policy
threshold-soundness conclusion. -/
theorem protocolOne_override_loop_sound
    (w : List Nat) (idxs : List Nat) (policyThreshold overrideBIPS : Nat)
    (hv : ValidRun w 0 idxs) (hoverride : overrideBIPS ≠ 0)
    (haccept :
      selectThreshold 1 overrideBIPS (sumTake w w.length) policyThreshold <
        (loop w 0 0 idxs).1) :
    sumTake w w.length * overrideBIPS <
        (loop w 0 0 idxs).1 * thresholdBIPS ∧
      selectThreshold 1 overrideBIPS (sumTake w w.length) policyThreshold <
        sumTake w w.length := by
  constructor
  · rw [selectThreshold_protocolOne overrideBIPS (sumTake w w.length)
      policyThreshold hoverride] at haccept
    exact (bips_floor_strict_iff_cross
      (loop w 0 0 idxs).1 (sumTake w w.length) overrideBIPS).1 haccept
  · exact threshold_sound w idxs
      (selectThreshold 1 overrideBIPS (sumTake w w.length) policyThreshold) hv haccept

end RelaySigLoop

#print axioms RelaySigLoop.threshold_sound
#print axioms RelaySigLoop.insufficient_weight_cannot_accept
#print axioms RelaySigLoop.bips_floor_strict_iff_cross
#print axioms RelaySigLoop.override_product_noOverflow
#print axioms RelaySigLoop.selectThreshold_zero
#print axioms RelaySigLoop.selectThreshold_nonProtocolOne
#print axioms RelaySigLoop.fullWeight_accepts_sub10000
#print axioms RelaySigLoop.protocolOne_override_loop_sound
