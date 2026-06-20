import EvmYul.Wheels
open EvmYul

/-!
# BR-1 (data layer) — foundation bricks

Work toward discharging **BR-1** from the claims ledger: that each signature-loop iteration's accumulated
value is the registered weight `mload(weights[i]) = w[i]`. This file collects the **hole-free** sub-results
of that data-layer refinement, committed incrementally (no `sorry`/`admit`).

## The one axiom

`ffi.ByteArray.zeroes` (EVMYulLean's `@[extern "memset_zero"]`) is declared `opaque`, so it has no
proof-level content. We add its minimal, obviously-true spec — `zeroes_data` below — as the single
documented trust addition. It is dischargeable upstream by changing `opaque ByteArray.zeroes` to a real
`def … @[implemented_by memset_zero]`, after which this axiom becomes a theorem and disappears. It is the
only assumption these proofs add beyond Lean's standard three.

## Status (see `docs/relay-verification/10-claims-ledger-trust-and-residual.md` §10.5)

* **Byte-decode round-trip — DONE** (`fromBytesBigEndian_toBytesBigEndian`).
* **Memory keystone — DONE** (`keystone`): `copySlice`/`extract` round-trip, *no* `zeroes` axiom.
* **ByteArray memory round-trip — DONE** (`mem_roundtrip`): `readWithPadding (write …) … = src`, against
  EVMYulLean's actual `ByteArray.write`/`readWithPadding`. This is the heart of `mload∘mstore`.
* **Remaining**: the `MachineState.mstore`/`mload` wrapping (the `activeWords`/size guard), the value
  decode `fromByteArrayBigEndian (v.toByteArray) = v.toNat`, the `& 0xffff` mask, the slot arithmetic, and
  the simulation relation `R` over the ∀N loop.
-/

namespace RelayDataLayer

/-- The minimal spec for the `opaque ffi.ByteArray.zeroes` (`memset_zero`). The single documented trust
    addition; dischargeable upstream (`opaque → def + @[implemented_by]`). -/
axiom zeroes_data (n : USize) : (ffi.ByteArray.zeroes n).data = Array.replicate n.toNat (0 : UInt8)

/-- BR-1 brick: the big-endian byte encode/decode is the identity, about EVMYulLean's real functions. -/
theorem fromBytesBigEndian_toBytesBigEndian (n : Nat) :
    fromBytesBigEndian (toBytesBigEndian n) = n := by
  simp [fromBytesBigEndian, toBytesBigEndian]

/-! ## ByteArray helpers (Lean 4.22 has no ByteArray lemma layer, so these drop to `Array.data`) -/

/-- `ByteArray` append is `Array` append on `.data`. -/
theorem append_data (a b : ByteArray) : (a ++ b).data = a.data ++ b.data := by
  show (b.copySlice 0 a a.size b.size).data = a.data ++ b.data
  unfold ByteArray.copySlice
  rw [show a.data.extract 0 a.size = a.data from Array.extract_eq_self_iff.mpr (Or.inr ⟨rfl, Nat.le_refl _⟩),
      show b.data.extract 0 (0 + b.size) = b.data from by
        rw [Nat.zero_add]; exact Array.extract_eq_self_iff.mpr (Or.inr ⟨rfl, Nat.le_refl _⟩),
      show a.data.extract (a.size + min b.size (b.data.size - 0)) a.data.size = #[] from by
        apply Array.eq_empty_of_size_eq_zero; have hb : a.size = a.data.size := rfl
        simp only [Array.size_extract]; omega]
  simp

private theorem array_core (A B C : Array UInt8) (d : Nat) (hA : A.size = d) (hB : B.size = 32) :
    ((A ++ B) ++ C).extract d (d + 32) = B := by
  apply Array.ext
  · simp [Array.size_extract, Array.size_append, hA, hB]
  · intro i h1 h2
    rw [Array.getElem_extract, Array.getElem_append_left (by simp only [Array.size_append]; omega),
        Array.getElem_append_right (by omega)]; congr 1; omega

private theorem array_extract_self (a : Array UInt8) (h : a.size = 32) : a.extract 0 32 = a := by
  apply Array.ext
  · simp [Array.size_extract, h]
  · intro i h1 h2; rw [Array.getElem_extract]; congr 1; omega

private theorem copySlice_data (src mem : ByteArray) (d : Nat) (hsrc : src.size = 32) :
    (src.copySlice 0 mem d 32).data
      = mem.data.extract 0 d ++ src.data.extract 0 32 ++ mem.data.extract (d + 32) mem.data.size := by
  have hd : src.data.size = 32 := hsrc
  unfold ByteArray.copySlice; simp [hd]

private theorem copySlice_size (src mem : ByteArray) (d : Nat) (hsrc : src.size = 32)
    (hmem : d + 32 ≤ mem.size) : (src.copySlice 0 mem d 32).size = mem.size := by
  have hd : src.data.size = 32 := hsrc
  have hmd : d + 32 ≤ mem.data.size := hmem
  show (src.copySlice 0 mem d 32).data.size = mem.data.size
  rw [copySlice_data src mem d hsrc]; simp [Array.size_append, Array.size_extract, hd]; omega

private theorem extract_data_inst (X : ByteArray) (d : Nat) (hX : d + 32 ≤ X.size) :
    (X.extract d (d + 32)).data = X.data.extract d (d + 32) := by
  have hXd : d + 32 ≤ X.data.size := hX
  have he : ByteArray.empty.data.size = 0 := by rfl
  unfold ByteArray.extract ByteArray.copySlice; simp [he]

/-- **Keystone.** Writing a 32-byte word at offset `d` and reading those 32 bytes back is the identity.
    No `zeroes` axiom (the `copySlice→extract` core dodges the padding). -/
theorem keystone (src mem : ByteArray) (d : Nat) (hsrc : src.size = 32) (hmem : d + 32 ≤ mem.size) :
    (src.copySlice 0 mem d 32).extract d (d + 32) = src := by
  have hmd : d + 32 ≤ mem.data.size := hmem
  have hsd : src.data.size = 32 := hsrc
  apply ByteArray.ext
  rw [extract_data_inst _ d (by rw [copySlice_size src mem d hsrc hmem]; exact hmem),
      copySlice_data src mem d hsrc,
      array_core (mem.data.extract 0 d) (src.data.extract 0 32) (mem.data.extract (d + 32) mem.data.size) d
        (by simp [Array.size_extract]; omega) (by simp [Array.size_extract, hsd])]
  exact array_extract_self src.data hsd

/-- `ByteArray.write` of a 32-byte word into a large-enough buffer reduces to `copySlice`. -/
theorem write_eq_copySlice (src dest : ByteArray) (d : Nat) (hsrc : src.size = 32)
    (hd : d + 32 ≤ dest.size) : ByteArray.write src 0 dest d 32 = src.copySlice 0 dest d 32 := by
  have hs : src.size = 32 := hsrc
  have hds : d ≤ dest.size := by omega
  apply ByteArray.ext; unfold ByteArray.write
  simp only [hs, show ¬ (32 = 0) from by decide, if_false, show ¬ ((0:Nat) ≥ 32) from by decide,
             Nat.sub_zero, Nat.min_self, min_eq_right hd, Nat.sub_self, Nat.sub_eq_zero_of_le hds,
             Nat.add_zero]
  unfold ByteArray.copySlice; simp only [append_data, zeroes_data]; simp

/-- `ByteArray.readWithPadding` of 32 bytes from a large-enough buffer reduces to `extract`. -/
theorem readWithPadding_eq_extract (X : ByteArray) (d : Nat) (hX : d + 32 ≤ X.size) :
    ByteArray.readWithPadding X d 32 = X.extract d (d + 32) := by
  have hXd : d + 32 ≤ X.data.size := hX
  have hrd : (X.extract d (d + 32)).size = 32 := by
    show (X.extract d (d + 32)).data.size = 32
    rw [extract_data_inst X d hX]; simp [Array.size_extract]; omega
  unfold ByteArray.readWithPadding ByteArray.readWithoutPadding
  simp only [show ¬ ((32:Nat) ≥ 2^64) from by decide, if_false, show ¬ (d ≥ X.size) from by omega,
             min_eq_left (show (32:Nat) ≤ X.size by omega)]
  rw [hrd]; apply ByteArray.ext; rw [append_data, zeroes_data]; simp

/-- **ByteArray memory round-trip.** Writing a 32-byte word into a buffer with room and reading those 32
    bytes back via EVMYulLean's actual `write`/`readWithPadding` returns the word. The heart of
    `mload∘mstore`. -/
theorem mem_roundtrip (src mem : ByteArray) (d : Nat) (hsrc : src.size = 32) (hmem : d + 32 ≤ mem.size) :
    ByteArray.readWithPadding (ByteArray.write src 0 mem d 32) d 32 = src := by
  rw [write_eq_copySlice src mem d hsrc hmem,
      readWithPadding_eq_extract _ d (by rw [copySlice_size src mem d hsrc hmem]; exact hmem)]
  exact keystone src mem d hsrc hmem

#print axioms fromBytesBigEndian_toBytesBigEndian
#print axioms keystone
#print axioms mem_roundtrip
end RelayDataLayer
