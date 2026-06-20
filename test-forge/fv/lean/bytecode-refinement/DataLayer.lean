import EvmYul.Wheels
open EvmYul

/-!
# BR-1 (data layer) — foundation bricks

Work toward discharging **BR-1** from the claims ledger: that each signature-loop iteration's accumulated
value is the registered weight `mload(weights[i]) = w[i]`. This file collects the **hole-free** sub-results
of that data-layer refinement, committed incrementally (no `sorry`/`admit`; axioms ⊆
`{propext, Classical.choice, Quot.sound}`).

Status (see `docs/relay-verification/10-claims-ledger-trust-and-residual.md` §10.5):

* **Byte-decode round-trip — DONE** (`fromBytesBigEndian_toBytesBigEndian`). Reuses EVMYulLean's existing
  `@[simp] fromBytes'_toBytes'` (private, but fires downstream).
* **Memory keystone — DONE** (`keystone`). Writing a 32-byte word at offset `d` into a large-enough
  buffer and reading those 32 bytes back is the identity — proven against EVMYulLean's actual
  `ByteArray.copySlice`/`extract` on Lean 4.22 (which has no ByteArray lemma layer, so the proof drops to
  the `Array.data` level). This was the hard critical-path brick.
* **Remaining** (the `mstore`/`mload` wrapping around `keystone`): the `ByteArray.write`/`readWithPadding`
  reductions (these *do* touch the `opaque ffi.ByteArray.zeroes` padding, needing its minimal spec), the
  `mload` size/`activeWords` guard, the `& 0xffff` mask, the slot arithmetic, and the simulation relation
  `R` over the ∀N loop.
-/

namespace RelayDataLayer

/-- BR-1 brick: the big-endian byte encode/decode is the identity, about EVMYulLean's real functions. -/
theorem fromBytesBigEndian_toBytesBigEndian (n : Nat) :
    fromBytesBigEndian (toBytesBigEndian n) = n := by
  simp [fromBytesBigEndian, toBytesBigEndian]

/-! ## The memory keystone: write-then-read 32 bytes round-trips -/

/-- Array core: extracting `[d, d+32)` from `(A ++ B) ++ C`, when `A.size = d` and `B.size = 32`, is `B`. -/
private theorem array_core (A B C : Array UInt8) (d : Nat) (hA : A.size = d) (hB : B.size = 32) :
    ((A ++ B) ++ C).extract d (d + 32) = B := by
  apply Array.ext
  · simp [Array.size_extract, Array.size_append, hA, hB]
  · intro i h1 h2
    rw [Array.getElem_extract,
        Array.getElem_append_left (by simp only [Array.size_append]; omega),
        Array.getElem_append_right (by omega)]
    congr 1; omega

/-- A full-length extract is the identity. -/
private theorem array_extract_self (a : Array UInt8) (h : a.size = 32) : a.extract 0 32 = a := by
  apply Array.ext
  · simp [Array.size_extract, h]
  · intro i h1 h2; rw [Array.getElem_extract]; congr 1; omega

/-- `.data` of a 32-byte `copySlice` into `mem` at offset `d`. -/
private theorem copySlice_data (src mem : ByteArray) (d : Nat) (hsrc : src.size = 32) :
    (src.copySlice 0 mem d 32).data
      = mem.data.extract 0 d ++ src.data.extract 0 32 ++ mem.data.extract (d + 32) mem.data.size := by
  have hd : src.data.size = 32 := hsrc
  unfold ByteArray.copySlice; simp [hd]

/-- Such a `copySlice` does not change the buffer size. -/
private theorem copySlice_size (src mem : ByteArray) (d : Nat) (hsrc : src.size = 32)
    (hmem : d + 32 ≤ mem.size) : (src.copySlice 0 mem d 32).size = mem.size := by
  have hd : src.data.size = 32 := hsrc
  have hmd : d + 32 ≤ mem.data.size := hmem
  show (src.copySlice 0 mem d 32).data.size = mem.data.size
  rw [copySlice_data src mem d hsrc]; simp [Array.size_append, Array.size_extract, hd]; omega

/-- `.data` of a 32-byte `extract` from a large-enough buffer. -/
private theorem extract_data_inst (X : ByteArray) (d : Nat) (hX : d + 32 ≤ X.size) :
    (X.extract d (d + 32)).data = X.data.extract d (d + 32) := by
  have hXd : d + 32 ≤ X.data.size := hX
  have he : ByteArray.empty.data.size = 0 := by rfl
  unfold ByteArray.extract ByteArray.copySlice; simp [he]

/-- **THE KEYSTONE.** Writing a 32-byte word at offset `d` into a buffer with room (`mem.size ≥ d+32`) and
    reading those 32 bytes back returns exactly the word. This is the memory write/read round-trip that the
    full `mload∘mstore` data-layer fact is built on. Proven against EVMYulLean's actual ByteArray ops. -/
theorem keystone (src mem : ByteArray) (d : Nat) (hsrc : src.size = 32) (hmem : d + 32 ≤ mem.size) :
    (src.copySlice 0 mem d 32).extract d (d + 32) = src := by
  have hmd : d + 32 ≤ mem.data.size := hmem
  have hsd : src.data.size = 32 := hsrc
  apply ByteArray.ext
  rw [extract_data_inst _ d (by rw [copySlice_size src mem d hsrc hmem]; exact hmem),
      copySlice_data src mem d hsrc,
      array_core (mem.data.extract 0 d) (src.data.extract 0 32) (mem.data.extract (d + 32) mem.data.size) d
        (by simp [Array.size_extract]; omega)
        (by simp [Array.size_extract, hsd])]
  exact array_extract_self src.data hsd

#print axioms fromBytesBigEndian_toBytesBigEndian
#print axioms keystone
end RelayDataLayer
