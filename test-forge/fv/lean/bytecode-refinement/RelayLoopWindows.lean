import EvmYul.Wheels
import EvmYul.UInt256
open EvmYul

/-!
# RelayLoopWindows — byte-level / arithmetic decode of the Relay loop's memory windows

The **data layer for the literal loop-body model** (`RelayLoopLiteral.lean`). Pure `ByteArray`/`Nat`/
`UInt256` lemmas (no interpreter): generalized window reads against EVMYulLean's real
`ByteArray.write`/`readWithPadding`, and the value decode of the four scratch-slot windows the deployed loop
uses. These are what turn the loop's `calldatacopy`→`mload` chain into the abstract weights/indices — the
facts that let `RelayLoopLiteral.relay_loop_sound`'s `hcorr`/`hvalid` be *derived* rather than assumed.

Payoff lemmas: `weight_of_window` (`and(mload(voterSlot), 0xffff)` = the 2-byte registered weight),
`signer_of_window` (`shr(16, mload(voterSlot))` = the 20-byte registered address), and the four window
reads `read_zero_then_write_suffix` / `_at31` / `read_sig_window_r` / `_s` / `read_index_window_head`
matching the `mstore(0)` + `calldatacopy` pattern of the IR body.

Self-contained (checks with one `lake env lean` against the pinned EVMYulLean `047f6307`). Its only local
semantic assumption beyond Lean's standard three is `zeroes_data`, which specifies the `opaque` FFI
`memset_zero`; the value-decode half uses none of it. The source is hole-free.
-/

namespace RelayWindows

/-- The minimal spec for the `opaque ffi.ByteArray.zeroes` (`memset_zero`), as in `DataLayer.lean`. -/
axiom zeroes_data (n : USize) : (ffi.ByteArray.zeroes n).data = Array.replicate n.toNat (0 : UInt8)

/-! ## ByteArray helper lemmas -/

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

/-- `ByteArray` append adds sizes. -/
theorem size_append (a b : ByteArray) : (a ++ b).size = a.size + b.size := by
  show (a ++ b).data.size = a.data.size + b.data.size
  rw [append_data]; simp [Array.size_append]

/-- `ByteArray.get!` agrees with `data.toList` indexing. -/
private theorem get!_eq (bs : ByteArray) (i : Nat) (h : i < bs.size) :
    bs.get! i = bs.data.toList[i]'(by rw [Array.length_toList]; exact h) := by
  obtain ⟨d⟩ := bs
  have h' : i < d.size := h
  show d[i]! = d.toList[i]
  rw [Array.getElem_toList]; exact getElem!_pos d i h'

/-- Loop invariant of `ByteArray.toList.loop`. -/
private theorem toList_loop (bs : ByteArray) (i : Nat) (r : List UInt8) :
    ByteArray.toList.loop bs i r = r.reverse ++ bs.data.toList.drop i := by
  induction i, r using ByteArray.toList.loop.induct bs with
  | case1 i r h ih =>
    rw [ByteArray.toList.loop, if_pos h, ih, List.reverse_cons,
        List.drop_eq_getElem_cons (show i < bs.data.toList.length by rw [Array.length_toList]; exact h),
        get!_eq bs i h]
    simp
  | case2 i r h =>
    have hb : bs.data.size = bs.size := rfl
    rw [ByteArray.toList.loop, if_neg h, List.drop_eq_nil_of_le (by rw [Array.length_toList]; omega)]
    simp

/-- `ByteArray.toList = data.toList`. -/
theorem toList_data (bs : ByteArray) : bs.toList = bs.data.toList := by
  show ByteArray.toList.loop bs 0 [] = bs.data.toList
  rw [toList_loop]; simp

private theorem extract_data_inst (X : ByteArray) (d : Nat) (hX : d + 32 ≤ X.size) :
    (X.extract d (d + 32)).data = X.data.extract d (d + 32) := by
  have hXd : d + 32 ≤ X.data.size := hX
  have he : ByteArray.empty.data.size = 0 := by rfl
  unfold ByteArray.extract ByteArray.copySlice; simp [he]

/-- `ByteArray.readWithPadding` of 32 bytes from a large-enough buffer reduces to `extract`
    (copied from `DataLayer.lean`). -/
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

/-! ## Generalized `write → copySlice` reduction (general length) -/

/-- `copySlice` at general length, on `.data` (generalizes `DataLayer.copySlice_data`). -/
private theorem copySlice_data_gen (src mem : ByteArray) (d len : Nat) (hsrc : src.size = len) :
    (src.copySlice 0 mem d len).data
      = mem.data.extract 0 d ++ src.data.extract 0 len ++ mem.data.extract (d + len) mem.data.size := by
  have hd : src.data.size = len := hsrc
  unfold ByteArray.copySlice; simp [hd]

private theorem copySlice_size_gen (src mem : ByteArray) (d len : Nat) (hsrc : src.size = len)
    (hmem : d + len ≤ mem.size) : (src.copySlice 0 mem d len).size = mem.size := by
  have hd : src.data.size = len := hsrc
  have hmd : d + len ≤ mem.data.size := hmem
  show (src.copySlice 0 mem d len).data.size = mem.data.size
  rw [copySlice_data_gen src mem d len hsrc]
  simp only [Array.size_append, Array.size_extract]; omega

/-- **General-length `write → copySlice`**: writing `len` bytes (`src.size = len`, `0 < len`)
    into a buffer with room reduces to `copySlice` (generalizes `DataLayer.write_eq_copySlice`). -/
theorem write_eq_copySlice_gen (src dest : ByteArray) (d len : Nat) (hlen : 0 < len)
    (hsrc : src.size = len) (hd : d + len ≤ dest.size) :
    ByteArray.write src 0 dest d len = src.copySlice 0 dest d len := by
  have hs : src.size = len := hsrc
  have hds : d ≤ dest.size := by omega
  apply ByteArray.ext; unfold ByteArray.write
  simp only [hs, show ¬ (len = 0) from by omega, if_false, show ¬ ((0:Nat) ≥ len) from by omega,
             Nat.sub_zero, Nat.min_self, min_eq_right hd, Nat.sub_self, Nat.sub_eq_zero_of_le hds,
             Nat.add_zero]
  unfold ByteArray.copySlice; simp only [append_data, zeroes_data]; simp

/-- A general-length write into a large-enough buffer preserves the buffer size. -/
theorem write_size_gen (src mem : ByteArray) (d len : Nat) (hlen : 0 < len)
    (hsrc : src.size = len) (hmem : d + len ≤ mem.size) :
    (ByteArray.write src 0 mem d len).size = mem.size := by
  rw [write_eq_copySlice_gen src mem d len hlen hsrc hmem]
  exact copySlice_size_gen src mem d len hsrc hmem

/-! ## (G1) Reads inside a written region -/

private theorem array_window (A B C : Array UInt8) (w len a : Nat)
    (hA : A.size = w) (hB : B.size = len) (hwa : w ≤ a) (ha : a + 32 ≤ w + len) :
    ((A ++ B) ++ C).extract a (a + 32) = B.extract (a - w) (a - w + 32) := by
  apply Array.ext
  · simp only [Array.size_extract, Array.size_append, hA, hB]; omega
  · intro i h1 h2
    simp only [Array.size_extract, Array.size_append, hA, hB] at h1 h2
    rw [Array.getElem_extract, Array.getElem_extract,
        Array.getElem_append_left (by simp only [Array.size_append]; omega),
        Array.getElem_append_right (by omega)]
    congr 1; omega

/-- **(G1) Read inside a written region.** If a 32-byte read window lies inside the region just
    written by a general-length `ByteArray.write`, the read returns the corresponding slice of the
    source. Generalizes the committed `keystone`/`mem_roundtrip` (their `a = w`, `len = 32` case). -/
theorem read_inside_write (src mem : ByteArray) (w len a : Nat)
    (hsrc : src.size = len) (hw : w + len ≤ mem.size) (hwa : w ≤ a) (ha : a + 32 ≤ w + len) :
    ByteArray.readWithPadding (ByteArray.write src 0 mem w len) a 32
      = src.extract (a - w) (a - w + 32) := by
  have hlen : 0 < len := by omega
  have hsd : src.data.size = len := hsrc
  have hmd : w + len ≤ mem.data.size := hw
  have hcs : (src.copySlice 0 mem w len).size = mem.size := copySlice_size_gen src mem w len hsrc hw
  rw [write_eq_copySlice_gen src mem w len hlen hsrc hw,
      readWithPadding_eq_extract _ a (by rw [hcs]; omega)]
  apply ByteArray.ext
  rw [extract_data_inst _ a (by rw [hcs]; omega),
      extract_data_inst src (a - w) (by omega),
      copySlice_data_gen src mem w len hsrc,
      show src.data.extract 0 len = src.data from
        Array.extract_eq_self_iff.mpr (Or.inr ⟨rfl, by omega⟩)]
  exact array_window (mem.data.extract 0 w) src.data (mem.data.extract (w + len) mem.data.size)
    w len a (by simp only [Array.size_extract]; omega) hsd hwa ha

/-! ## Source-offset bridge (`calldatacopy`)

The interpreter's `calldatacopy` (see `RelayLoopLiteral.calldatacopy_unfold`) produces
`ByteArray.write cd srcOff mem destOff len` where the **source** offset is the *calldata* offset
(e.g. the byte position of a signature's `r`/`s` word, or a voter record). But `read_inside_write`
above — and every window lemma below — is stated for source offset `0`. This section closes that
gap once and for all with `write_from_offset`, then packages the directly usable
`read_inside_write_off`. It is the bridge that lets the deployed loop's `calldatacopy(scratch, pos, 32)`
be decoded by the `write · 0 ·` machinery.

The whole section is elementary `Array`/`ByteArray` surgery: `write` (with room) is a `copySlice`,
`copySlice` on `.data` is a three-way `extract` append, and `extract`-of-`extract` composes
(`Array.extract_extract`). No new assumption beyond `zeroes_data` (already used above). -/

/-- Generalized `extract` on `.data` for any window `a ≤ b` (the public generalization of the
    32-byte `extract_data_inst`). -/
theorem extract_data_gen (X : ByteArray) (a b : Nat) (hab : a ≤ b) :
    (X.extract a b).data = X.data.extract a b := by
  have he : ByteArray.empty.data.size = 0 := by rfl
  have hb : a + (b - a) = b := by omega
  unfold ByteArray.extract ByteArray.copySlice; simp [he, hb]

/-- General source-offset `copySlice`, on `.data`: prefix ++ source-window ++ suffix
    (generalizes `copySlice_data_gen`'s `srcOff = 0`). -/
theorem copySlice_data_off (src mem : ByteArray) (so d len : Nat)
    (hso : so + len ≤ src.size) (hd : d + len ≤ mem.size) :
    (src.copySlice so mem d len).data
      = mem.data.extract 0 d ++ src.data.extract so (so + len)
        ++ mem.data.extract (d + len) mem.data.size := by
  have hsod : so + len ≤ src.data.size := hso
  have hdd : d + len ≤ mem.data.size := hd
  have hmin : min len (src.data.size - so) = len := by omega
  unfold ByteArray.copySlice
  simp only [hmin]

/-- The padding `ffi.ByteArray.zeroes ⟨0⟩` (used by `ByteArray.write` when there is room) carries
    no data, so appending it is invisible on `.data`. -/
theorem append_zeroes0 (a : ByteArray) : (a ++ ffi.ByteArray.zeroes ⟨0⟩).data = a.data := by
  rw [append_data, zeroes_data]; simp

/-- ... and invisible on `.size`. -/
theorem size_zeroes0 (a : ByteArray) : (a ++ ffi.ByteArray.zeroes ⟨0⟩).size = a.size := by
  rw [size_append]; show a.size + (ffi.ByteArray.zeroes ⟨0⟩).data.size = a.size
  rw [zeroes_data]; simp

/-- A general source-offset `write` (with room) reduces to a `copySlice` on empty-padded buffers.
    This is where the `let`-heavy `ByteArray.write` definition (both branches) is discharged:
    with room, `practicalLen = len`, both paddings have length `0`. -/
theorem write_reduced (src mem : ByteArray) (so d len : Nat)
    (hlen : 0 < len) (hso : so + len ≤ src.size) (hd : d + len ≤ mem.size) :
    ByteArray.write src so mem d len
      = (src ++ ffi.ByteArray.zeroes ⟨0⟩).copySlice so (mem ++ ffi.ByteArray.zeroes ⟨0⟩) d len := by
  have hne : ¬ (len = 0) := by omega
  have hscd : ¬ so ≥ src.size := by omega
  have e1 : min len (src.size - so) = len := by omega
  have e2 : min mem.size (d + len) = d + len := by omega
  have e3 : d - mem.size = 0 := by omega
  have e4 : d + len - (d + len) = 0 := by omega
  unfold ByteArray.write
  simp only [hne, hscd, if_false, e1, e2, e3, e4, Nat.add_zero]
  norm_cast

/-- **BRIDGE (calldatacopy source-offset reduction).** Writing `len` bytes from calldata offset
    `srcOff` into memory offset `destOff` equals writing the *extracted* calldata window from offset
    `0`. This is the single fact that reconciles `calldatacopy_unfold` with the `write · 0 ·` window
    lemmas. Proof: reduce both `write`s to `copySlice` (`write_reduced`), expand both on `.data`
    (`copySlice_data_off`), drop the empty padding (`append_zeroes0`/`size_zeroes0`), and observe the
    source windows coincide (`(cd.extract srcOff (srcOff+len)).data.extract 0 len = cd.data.extract srcOff (srcOff+len)`). -/
theorem write_from_offset (cd mem : ByteArray) (srcOff destOff len : Nat)
    (hlen : 0 < len) (hsrc : srcOff + len ≤ cd.size) (hdest : destOff + len ≤ mem.size) :
    ByteArray.write cd srcOff mem destOff len
      = ByteArray.write (cd.extract srcOff (srcOff + len)) 0 mem destOff len := by
  have hcd : cd.data.size = cd.size := rfl
  have hmm : mem.data.size = mem.size := rfl
  have hexsz : (cd.extract srcOff (srcOff + len)).size = len := by
    show (cd.extract srcOff (srcOff + len)).data.size = len
    rw [extract_data_gen cd srcOff (srcOff + len) (by omega)]
    simp only [Array.size_extract]; omega
  apply ByteArray.ext
  rw [write_reduced cd mem srcOff destOff len hlen hsrc hdest,
      write_reduced (cd.extract srcOff (srcOff + len)) mem 0 destOff len hlen (by omega) hdest,
      copySlice_data_off _ _ srcOff destOff len (by rw [size_zeroes0]; omega) (by rw [size_zeroes0]; omega),
      copySlice_data_off _ _ 0 destOff len (by rw [size_zeroes0, hexsz]; omega) (by rw [size_zeroes0]; omega),
      append_zeroes0, append_zeroes0, append_zeroes0,
      extract_data_gen cd srcOff (srcOff + len) (by omega)]
  congr 1
  rw [Nat.zero_add,
      show (cd.data.extract srcOff (srcOff + len)).extract 0 len = cd.data.extract srcOff (srcOff + len) from
        Array.extract_eq_self_iff.mpr (Or.inr ⟨rfl, by simp only [Array.size_extract]; omega⟩)]

/-- **(G1′) Read inside a source-offset write** — the integration-ready form of `read_inside_write`.
    A 32-byte read of a window inside a `calldatacopy(destOff, srcOff, len)` returns the corresponding
    32-byte slice of the *calldata* (`extract`-of-`extract` composed via `Array.extract_extract`). This
    is exactly the shape the deployed loop's `mload(scratch)` after `calldatacopy(scratch, pos, 32)` needs. -/
theorem read_inside_write_off (cd mem : ByteArray) (so w len a : Nat)
    (hlen : 0 < len) (hso : so + len ≤ cd.size) (hw : w + len ≤ mem.size)
    (hwa : w ≤ a) (ha : a + 32 ≤ w + len) :
    ByteArray.readWithPadding (ByteArray.write cd so mem w len) a 32
      = cd.extract (so + (a - w)) (so + (a - w) + 32) := by
  have hcd : cd.data.size = cd.size := rfl
  have hexsz : (cd.extract so (so + len)).size = len := by
    show (cd.extract so (so + len)).data.size = len
    rw [extract_data_gen cd so (so + len) (by omega)]; simp only [Array.size_extract]; omega
  rw [write_from_offset cd mem so w len hlen hso hw,
      read_inside_write (cd.extract so (so + len)) mem w len a hexsz hw hwa ha]
  apply ByteArray.ext
  rw [extract_data_gen (cd.extract so (so + len)) (a - w) (a - w + 32) (by omega),
      extract_data_gen cd so (so + len) (by omega),
      Array.extract_extract,
      extract_data_gen cd (so + (a - w)) (so + (a - w) + 32) (by omega),
      show min (so + (a - w + 32)) (so + len) = so + (a - w) + 32 from by omega]

/-! ## `getElem!` toolkit (no `getElem!` lemma layer for these shapes on Lean 4.22) -/

private theorem getElem!_append_left' (A B : Array UInt8) (i : Nat) (h : i < A.size) :
    (A ++ B)[i]! = A[i]! := by
  rw [getElem!_pos (A ++ B) i (by simp only [Array.size_append]; omega), getElem!_pos A i h]
  exact Array.getElem_append_left h

private theorem getElem!_append_right' (A B : Array UInt8) (i : Nat) (h1 : A.size ≤ i)
    (h2 : i < A.size + B.size) :
    (A ++ B)[i]! = B[i - A.size]! := by
  rw [getElem!_pos (A ++ B) i (by simp only [Array.size_append]; omega),
      getElem!_pos B (i - A.size) (by omega)]
  exact Array.getElem_append_right h1

private theorem getElem!_extract' (A : Array UInt8) (s e i : Nat) (h : i < min e A.size - s) :
    (A.extract s e)[i]! = A[s + i]! := by
  have h1 : i < (A.extract s e).size := by simp only [Array.size_extract]; omega
  rw [getElem!_pos (A.extract s e) i h1, getElem!_pos A (s + i) (by omega)]
  exact Array.getElem_extract h1

private theorem getElem!_replicate (n i : Nat) (h : i < n) :
    (Array.replicate n (0 : UInt8))[i]! = 0 := by
  rw [getElem!_pos (Array.replicate n (0 : UInt8)) i (by simp only [Array.size_replicate]; omega)]
  exact Array.getElem_replicate _

/-- ByteArray extensionality through `getElem!` (sizes + bytes). -/
private theorem byteArray_ext! (x y : ByteArray) (hsz : x.size = y.size)
    (h : ∀ i, i < x.size → x.data[i]! = y.data[i]!) : x = y := by
  apply ByteArray.ext
  apply Array.ext hsz
  intro i h1 h2
  have hx := h i h1
  rwa [getElem!_pos x.data i h1, getElem!_pos y.data i h2] at hx

/-! ## Index views of `write` and 32-byte reads -/

/-- A general-length in-bounds `write`, on `.data`: prefix / source / suffix. -/
private theorem write_data (src mem : ByteArray) (w len : Nat)
    (hlen : 0 < len) (hsrc : src.size = len) (hw : w + len ≤ mem.size) :
    (ByteArray.write src 0 mem w len).data
      = mem.data.extract 0 w ++ src.data ++ mem.data.extract (w + len) mem.data.size := by
  have hsd : src.data.size = len := hsrc
  rw [write_eq_copySlice_gen src mem w len hlen hsrc hw, copySlice_data_gen src mem w len hsrc,
      show src.data.extract 0 len = src.data from
        Array.extract_eq_self_iff.mpr (Or.inr ⟨rfl, by omega⟩)]

/-- Bytes inside the just-written region come from the source. -/
private theorem write_getElem!_in (src mem : ByteArray) (w len j : Nat)
    (hlen : 0 < len) (hsrc : src.size = len) (hw : w + len ≤ mem.size)
    (hj1 : w ≤ j) (hj2 : j < w + len) :
    (ByteArray.write src 0 mem w len).data[j]! = src.data[j - w]! := by
  have hsd : src.data.size = len := hsrc
  have hmd : w + len ≤ mem.data.size := hw
  rw [write_data src mem w len hlen hsrc hw,
      getElem!_append_left' _ _ j
        (by simp only [Array.size_append, Array.size_extract]; omega),
      getElem!_append_right' _ _ j (by simp only [Array.size_extract]; omega)
        (by simp only [Array.size_extract]; omega),
      show (mem.data.extract 0 w).size = w from by simp only [Array.size_extract]; omega]

/-- Bytes strictly below the written region are unchanged. -/
private theorem write_getElem!_lo (src mem : ByteArray) (w len j : Nat)
    (hlen : 0 < len) (hsrc : src.size = len) (hw : w + len ≤ mem.size) (hj : j < w) :
    (ByteArray.write src 0 mem w len).data[j]! = mem.data[j]! := by
  have hmd : w + len ≤ mem.data.size := hw
  rw [write_data src mem w len hlen hsrc hw,
      getElem!_append_left' _ _ j
        (by simp only [Array.size_append, Array.size_extract]; omega),
      getElem!_append_left' _ _ j (by simp only [Array.size_extract]; omega),
      getElem!_extract' mem.data 0 w j (by omega), Nat.zero_add]

private theorem read32_data (X : ByteArray) (a : Nat) (hX : a + 32 ≤ X.size) :
    (ByteArray.readWithPadding X a 32).data = X.data.extract a (a + 32) := by
  rw [readWithPadding_eq_extract X a hX, extract_data_inst X a hX]

/-- A 32-byte in-bounds `readWithPadding` has size 32. -/
theorem read32_size (X : ByteArray) (a : Nat) (hX : a + 32 ≤ X.size) :
    (ByteArray.readWithPadding X a 32).size = 32 := by
  have hXd : a + 32 ≤ X.data.size := hX
  show (ByteArray.readWithPadding X a 32).data.size = 32
  rw [read32_data X a hX]; simp only [Array.size_extract]; omega

/-- **(G4 helper) Bytewise read**: byte `i` of an in-bounds 32-byte `readWithPadding` window is
    byte `a + i` of the buffer. -/
theorem read32_getElem! (X : ByteArray) (a i : Nat) (hX : a + 32 ≤ X.size) (hi : i < 32) :
    (ByteArray.readWithPadding X a 32).data[i]! = X.data[a + i]! := by
  have hXd : a + 32 ≤ X.data.size := hX
  rw [read32_data X a hX]
  exact getElem!_extract' X.data a (a + 32) i (by omega)

/-! ## General ByteArray `extract` on `.data` (needed for sub-window statements) -/

private theorem extract_data' (X : ByteArray) (s e : Nat) (hse : s ≤ e) :
    (X.extract s e).data = X.data.extract s e := by
  have he : ByteArray.empty.data.size = 0 := by rfl
  unfold ByteArray.extract ByteArray.copySlice
  simp [he, Nat.add_sub_cancel' hse]

theorem extract_size' (X : ByteArray) (s e : Nat) (hse : s ≤ e) (he : e ≤ X.size) :
    (X.extract s e).size = e - s := by
  have hXd : e ≤ X.data.size := he
  show (X.extract s e).data.size = e - s
  rw [extract_data' X s e hse]; simp only [Array.size_extract]; omega

private theorem extract_getElem! (X : ByteArray) (s e i : Nat) (hse : s ≤ e)
    (h : i < min e X.size - s) :
    (X.extract s e).data[i]! = X.data[s + i]! := by
  rw [extract_data' X s e hse]
  exact getElem!_extract' X.data s e i h

/-! ## (G2) The voter-record window -/

/-- **(G2) Voter-record window.** Write a 32-byte zero word at `d`, then a 22-byte record
    (20-byte address ++ 2-byte weight) at `d + 10`: the 32-byte read at `d` is exactly
    10 zero bytes followed by the record. -/
theorem read_zero_then_write_suffix (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 22) (hmem : d + 32 ≤ mem.size) :
    ByteArray.readWithPadding
      (ByteArray.write src 0
        (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 10) 22) d 32
      = (⟨Array.replicate 10 0⟩ : ByteArray) ++ src := by
  have hsd : src.data.size = 22 := hsrc
  have hZ : ((⟨Array.replicate 32 0⟩ : ByteArray)).size = 32 := by
    show (Array.replicate 32 (0 : UInt8)).size = 32
    simp only [Array.size_replicate]
  have h10 : ((⟨Array.replicate 10 0⟩ : ByteArray)).size = 10 := by
    show (Array.replicate 10 (0 : UInt8)).size = 10
    simp only [Array.size_replicate]
  have h1s : (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32).size = mem.size :=
    write_size_gen _ mem d 32 (by omega) hZ hmem
  have h2s : (ByteArray.write src 0
      (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 10) 22).size
      = mem.size := by
    rw [write_size_gen src _ (d + 10) 22 (by omega) hsrc (by omega)]; exact h1s
  apply byteArray_ext!
  · rw [read32_size _ d (by omega), size_append, h10, hsrc]
  · intro i hi
    rw [read32_size _ d (by omega)] at hi
    rw [read32_getElem! _ d i (by omega) hi, append_data,
        show ((⟨Array.replicate 10 0⟩ : ByteArray)).data = Array.replicate 10 (0 : UInt8) from rfl]
    by_cases h10i : i < 10
    · rw [write_getElem!_lo src _ (d + 10) 22 (d + i) (by omega) hsrc (by omega) (by omega),
          write_getElem!_in (⟨Array.replicate 32 0⟩ : ByteArray) mem d 32 (d + i)
            (by omega) hZ hmem (by omega) (by omega),
          show d + i - d = i from by omega,
          show ((⟨Array.replicate 32 0⟩ : ByteArray)).data = Array.replicate 32 (0 : UInt8) from rfl,
          getElem!_replicate 32 i (by omega),
          getElem!_append_left' _ _ i (by simp only [Array.size_replicate]; omega),
          getElem!_replicate 10 i h10i]
    · rw [write_getElem!_in src _ (d + 10) 22 (d + i)
            (by omega) hsrc (by omega) (by omega) (by omega),
          show d + i - (d + 10) = i - 10 from by omega,
          getElem!_append_right' _ _ i (by simp only [Array.size_replicate]; omega)
            (by simp only [Array.size_replicate, hsd]; omega),
          show (Array.replicate 10 (0 : UInt8)).size = 10 from by simp only [Array.size_replicate]]

/-! ## (G3) The v-byte window and the two signature windows -/

/-- **(G3a) v-byte window.** Write a 32-byte zero word at `d`, then a 67-byte blob at `d + 31`:
    the 32-byte read at `d` is 31 zero bytes followed by the blob's first byte. -/
theorem read_zero_then_write_at31 (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 67) (hmem : d + 98 ≤ mem.size) :
    ByteArray.readWithPadding
      (ByteArray.write src 0
        (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 31) 67) d 32
      = (⟨Array.replicate 31 0⟩ : ByteArray) ++ src.extract 0 1 := by
  have hsd : src.data.size = 67 := hsrc
  have hZ : ((⟨Array.replicate 32 0⟩ : ByteArray)).size = 32 := by
    show (Array.replicate 32 (0 : UInt8)).size = 32
    simp only [Array.size_replicate]
  have h31 : ((⟨Array.replicate 31 0⟩ : ByteArray)).size = 31 := by
    show (Array.replicate 31 (0 : UInt8)).size = 31
    simp only [Array.size_replicate]
  have hx1 : (src.extract 0 1).size = 1 := extract_size' src 0 1 (by omega) (by omega)
  have hx1d : (src.extract 0 1).data.size = 1 := hx1
  have h1s : (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32).size = mem.size :=
    write_size_gen _ mem d 32 (by omega) hZ (by omega)
  have h2s : (ByteArray.write src 0
      (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 31) 67).size
      = mem.size := by
    rw [write_size_gen src _ (d + 31) 67 (by omega) hsrc (by omega)]; exact h1s
  apply byteArray_ext!
  · rw [read32_size _ d (by omega), size_append, h31, hx1]
  · intro i hi
    rw [read32_size _ d (by omega)] at hi
    rw [read32_getElem! _ d i (by omega) hi, append_data,
        show ((⟨Array.replicate 31 0⟩ : ByteArray)).data = Array.replicate 31 (0 : UInt8) from rfl]
    by_cases h31i : i < 31
    · rw [write_getElem!_lo src _ (d + 31) 67 (d + i) (by omega) hsrc (by omega) (by omega),
          write_getElem!_in (⟨Array.replicate 32 0⟩ : ByteArray) mem d 32 (d + i)
            (by omega) hZ (by omega) (by omega) (by omega),
          show d + i - d = i from by omega,
          show ((⟨Array.replicate 32 0⟩ : ByteArray)).data = Array.replicate 32 (0 : UInt8) from rfl,
          getElem!_replicate 32 i (by omega),
          getElem!_append_left' _ _ i (by simp only [Array.size_replicate]; omega),
          getElem!_replicate 31 i h31i]
    · rw [write_getElem!_in src _ (d + 31) 67 (d + i)
            (by omega) hsrc (by omega) (by omega) (by omega),
          show d + i - (d + 31) = i - 31 from by omega,
          getElem!_append_right' _ _ i (by simp only [Array.size_replicate]; omega)
            (by simp only [Array.size_replicate]; omega),
          show (Array.replicate 31 (0 : UInt8)).size = 31 from by simp only [Array.size_replicate],
          extract_getElem! src 0 1 (i - 31) (by omega) (by omega), Nat.zero_add]

/-- **(G3b) First signature window.** From the same buffer (zero word at `d`, 67-byte blob at
    `d + 31`), the 32-byte read at `d + 32` is bytes 1..33 of the blob (instance of G1). -/
theorem read_sig_window_r (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 67) (hmem : d + 98 ≤ mem.size) :
    ByteArray.readWithPadding
      (ByteArray.write src 0
        (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 31) 67) (d + 32) 32
      = src.extract 1 33 := by
  have hZ : ((⟨Array.replicate 32 0⟩ : ByteArray)).size = 32 := by
    show (Array.replicate 32 (0 : UInt8)).size = 32
    simp only [Array.size_replicate]
  have h1s : (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32).size = mem.size :=
    write_size_gen _ mem d 32 (by omega) hZ (by omega)
  rw [read_inside_write src _ (d + 31) 67 (d + 32) hsrc (by omega) (by omega) (by omega),
      show d + 32 - (d + 31) = 1 from by omega, show (1 : Nat) + 32 = 33 from by norm_num]

/-- **(G3c) Second signature window.** The 32-byte read at `d + 64` is bytes 33..65 of the blob
    (instance of G1). -/
theorem read_sig_window_s (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 67) (hmem : d + 98 ≤ mem.size) :
    ByteArray.readWithPadding
      (ByteArray.write src 0
        (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 31) 67) (d + 64) 32
      = src.extract 33 65 := by
  have hZ : ((⟨Array.replicate 32 0⟩ : ByteArray)).size = 32 := by
    show (Array.replicate 32 (0 : UInt8)).size = 32
    simp only [Array.size_replicate]
  have h1s : (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32).size = mem.size :=
    write_size_gen _ mem d 32 (by omega) hZ (by omega)
  rw [read_inside_write src _ (d + 31) 67 (d + 64) hsrc (by omega) (by omega) (by omega),
      show d + 64 - (d + 31) = 33 from by omega, show (33 : Nat) + 32 = 65 from by norm_num]

/-- **(G4) Index-window head.** From the same buffer, the first two bytes of the 32-byte read at
    `d + 96` are bytes 65 and 66 of the blob; the rest of that window is unspecified stale memory. -/
theorem read_index_window_head (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 67) (hmem : d + 128 ≤ mem.size) :
    (ByteArray.readWithPadding
      (ByteArray.write src 0
        (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 31) 67)
      (d + 96) 32).extract 0 2
      = src.extract 65 67 := by
  have hsd : src.data.size = 67 := hsrc
  have hZ : ((⟨Array.replicate 32 0⟩ : ByteArray)).size = 32 := by
    show (Array.replicate 32 (0 : UInt8)).size = 32
    simp only [Array.size_replicate]
  have h1s : (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32).size = mem.size :=
    write_size_gen _ mem d 32 (by omega) hZ (by omega)
  have h2s : (ByteArray.write src 0
      (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 31) 67).size
      = mem.size := by
    rw [write_size_gen src _ (d + 31) 67 (by omega) hsrc (by omega)]; exact h1s
  have hr32 : (ByteArray.readWithPadding
      (ByteArray.write src 0
        (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 31) 67)
      (d + 96) 32).size = 32 :=
    read32_size _ (d + 96) (by omega)
  apply byteArray_ext!
  · rw [extract_size' _ 0 2 (by omega) (by rw [hr32]; omega),
        extract_size' src 65 67 (by omega) (by omega)]
  · intro i hi
    rw [extract_size' _ 0 2 (by omega) (by rw [hr32]; omega)] at hi
    rw [extract_getElem! _ 0 2 i (by omega) (by rw [hr32]; omega), Nat.zero_add,
        read32_getElem! _ (d + 96) i (by omega) (by omega),
        write_getElem!_in src _ (d + 31) 67 (d + 96 + i)
          (by omega) hsrc (by omega) (by omega) (by omega),
        show d + 96 + i - (d + 31) = 65 + i from by omega,
        extract_getElem! src 65 67 i (by omega) (by omega)]

/-! ## PART 2 — value decode of the windows (Nat/UInt256 level) -/

/-- Little-endian append law (low bytes first). -/
theorem fromBytes'_append (m₁ m₂ : List UInt8) :
    fromBytes' (m₁ ++ m₂) = fromBytes' m₁ + 2 ^ (8 * m₁.length) * fromBytes' m₂ := by
  induction m₁ with
  | nil => simp [fromBytes']
  | cons b bs ih =>
    simp only [List.cons_append, fromBytes', ih, List.length_cons,
               show 8 * (bs.length + 1) = 8 * bs.length + 8 from by ring, Nat.pow_add]
    ring

/-- **(V1) Big-endian append law**: the tail contributes the low `8 * l₂.length` bits. -/
theorem fromBytesBigEndian_append (l₁ l₂ : List UInt8) :
    fromBytesBigEndian (l₁ ++ l₂)
      = fromBytesBigEndian l₂ + 2 ^ (8 * l₂.length) * fromBytesBigEndian l₁ := by
  unfold fromBytesBigEndian
  simp only [Function.comp]
  rw [List.reverse_append, fromBytes'_append, List.length_reverse]

/-- Little-endian value bound (mirror of the `private` upstream `fromBytes'_le`). -/
theorem fromBytes'_lt (l : List UInt8) : fromBytes' l < 2 ^ (8 * l.length) := by
  induction l with
  | nil => simp [fromBytes']
  | cons b bs ih =>
    have hb : b.toFin.val < 256 := b.toFin.isLt
    simp only [fromBytes', List.length_cons]
    rw [show 8 * (bs.length + 1) = 8 * bs.length + 8 from by ring, Nat.pow_add,
        show (2:ℕ) ^ 8 = 256 from by norm_num]
    omega

/-- **(V2) Big-endian value bound.** -/
theorem fromBytesBigEndian_lt (l : List UInt8) : fromBytesBigEndian l < 2 ^ (8 * l.length) := by
  unfold fromBytesBigEndian
  simp only [Function.comp]
  have h := fromBytes'_lt l.reverse
  rwa [List.length_reverse] at h

/-- **(V3, general form) `mod` split**: reducing mod `2^(8·(len−k))` keeps the last `len − k` bytes. -/
theorem fromBytesBigEndian_mod_pow (l : List UInt8) (k : Nat) :
    fromBytesBigEndian l % 2 ^ (8 * (l.length - k)) = fromBytesBigEndian (l.drop k) := by
  have hlt : fromBytesBigEndian (l.drop k) < 2 ^ (8 * (l.length - k)) := by
    have h := fromBytesBigEndian_lt (l.drop k)
    rwa [List.length_drop] at h
  have h := fromBytesBigEndian_append (l.take k) (l.drop k)
  rw [List.take_append_drop, List.length_drop] at h
  rw [h, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt hlt]

/-- **(V3, general form) `div` split**: dividing by `2^(8·(len−k))` keeps the first `k` bytes. -/
theorem fromBytesBigEndian_div_pow (l : List UInt8) (k : Nat) :
    fromBytesBigEndian l / 2 ^ (8 * (l.length - k)) = fromBytesBigEndian (l.take k) := by
  have hlt : fromBytesBigEndian (l.drop k) < 2 ^ (8 * (l.length - k)) := by
    have h := fromBytesBigEndian_lt (l.drop k)
    rwa [List.length_drop] at h
  have h := fromBytesBigEndian_append (l.take k) (l.drop k)
  rw [List.take_append_drop, List.length_drop] at h
  rw [h, Nat.add_mul_div_left _ _ (Nat.two_pow_pos _), Nat.div_eq_of_lt hlt, Nat.zero_add]

/-- **(V3a)** For a 32-byte word, `mod 2¹⁶` is the big-endian value of the low 2 bytes. -/
theorem fromBytesBigEndian_mod_2_16 (l : List UInt8) (hl : l.length = 32) :
    fromBytesBigEndian l % 2 ^ 16 = fromBytesBigEndian (l.drop 30) := by
  have h := fromBytesBigEndian_mod_pow l 30
  rw [hl] at h
  rw [show (2:ℕ) ^ 16 = 2 ^ (8 * (32 - 30)) from by norm_num]
  exact h

/-- **(V3b)** For a 32-byte word, `div 2¹⁶` is the big-endian value of the high 30 bytes. -/
theorem fromBytesBigEndian_div_2_16 (l : List UInt8) (hl : l.length = 32) :
    fromBytesBigEndian l / 2 ^ 16 = fromBytesBigEndian (l.take 30) := by
  have h := fromBytesBigEndian_div_pow l 30
  rw [hl] at h
  rw [show (2:ℕ) ^ 16 = 2 ^ (8 * (32 - 30)) from by norm_num]
  exact h

/-! ## (V4) UInt256 bridges: masks, shifts, `ofNat` -/

/-- Bitwise AND with `0xffff` is reduction mod 2¹⁶ (copied from `DataLayer.lean`). -/
theorem land_65535 (n : Nat) : n &&& 65535 = n % 65536 := by
  have h1 : (65535 : Nat) = 2 ^ 16 - 1 := by norm_num
  have h2 : (65536 : Nat) = 2 ^ 16 := by norm_num
  rw [h1, h2]
  apply Nat.eq_of_testBit_eq
  intro i
  rw [Nat.testBit_and, Nat.testBit_two_pow_sub_one, Nat.testBit_mod_two_pow, Bool.and_comm]

/-- Bitwise AND with `0xff` is reduction mod 2⁸ (same three-lemma rewrite). -/
theorem land_255 (n : Nat) : n &&& 255 = n % 256 := by
  have h1 : (255 : Nat) = 2 ^ 8 - 1 := by norm_num
  have h2 : (256 : Nat) = 2 ^ 8 := by norm_num
  rw [h1, h2]
  apply Nat.eq_of_testBit_eq
  intro i
  rw [Nat.testBit_and, Nat.testBit_two_pow_sub_one, Nat.testBit_mod_two_pow, Bool.and_comm]

/-- **(V4a-16)** `and(x, 0xffff)` extracts the low 16 bits (copied from `DataLayer.lean`). -/
theorem mask16_toNat (x : UInt256) :
    (UInt256.land x (⟨0xffff⟩ : UInt256)).toNat = x.toNat % 65536 := by
  have hb : ((⟨0xffff⟩ : UInt256)).val.val = 65535 := by
    show 0xffff % UInt256.size = 65535
    exact Nat.mod_eq_of_lt (by unfold UInt256.size; omega)
  show (Fin.land x.val (⟨0xffff⟩ : UInt256).val).val = x.toNat % 65536
  rw [show (Fin.land x.val (⟨0xffff⟩ : UInt256).val).val
        = (x.val.val &&& (⟨0xffff⟩ : UInt256).val.val) % UInt256.size from rfl, hb, land_65535]
  exact Nat.mod_eq_of_lt (lt_trans (Nat.mod_lt _ (by norm_num)) (by unfold UInt256.size; omega))

/-- **(V4a-8)** `and(x, 0xff)` extracts the low byte: its value is `x.toNat mod 2⁸`. -/
theorem mask8_toNat (x : UInt256) :
    (UInt256.land x (⟨0xff⟩ : UInt256)).toNat = x.toNat % 2 ^ 8 := by
  have hb : ((⟨0xff⟩ : UInt256)).val.val = 255 := by
    show 0xff % UInt256.size = 255
    exact Nat.mod_eq_of_lt (by unfold UInt256.size; omega)
  rw [show (2:ℕ) ^ 8 = 256 from by norm_num]
  show (Fin.land x.val (⟨0xff⟩ : UInt256).val).val = x.toNat % 256
  rw [show (Fin.land x.val (⟨0xff⟩ : UInt256).val).val
        = (x.val.val &&& (⟨0xff⟩ : UInt256).val.val) % UInt256.size from rfl, hb, land_255]
  exact Nat.mod_eq_of_lt (lt_trans (Nat.mod_lt _ (by norm_num)) (by unfold UInt256.size; omega))

/-- **(V4b) `shr` bridge**: for shift amounts `< 256`, `shr` is `toNat` division by `2^s`. -/
theorem shr_toNat (x s : UInt256) (hs : s.val.val < 256) :
    (UInt256.shiftRight x s).toNat = x.toNat / 2 ^ s.val.val := by
  have h256 : ((256 : Fin UInt256.size)).val = 256 := by
    show 256 % UInt256.size = 256
    exact Nat.mod_eq_of_lt (by unfold UInt256.size; omega)
  have hcond : ¬ (s.val ≥ (256 : Fin UInt256.size)) := by
    intro hge
    have h2 : ((256 : Fin UInt256.size)).val ≤ s.val.val := hge
    omega
  unfold UInt256.shiftRight
  rw [if_neg hcond]
  show ((x.val >>> s.val)).val = x.toNat / 2 ^ s.val.val
  rw [show (x.val >>> s.val).val = (x.val.val >>> s.val.val) % UInt256.size from rfl,
      Nat.shiftRight_eq_div_pow]
  exact Nat.mod_eq_of_lt (lt_of_le_of_lt (Nat.div_le_self _ _) x.val.isLt)

/-- **(V4b-16)** `shr(16)` is division by 2¹⁶. -/
theorem shr16_toNat (x : UInt256) :
    (UInt256.shiftRight x (⟨16⟩ : UInt256)).toNat = x.toNat / 2 ^ 16 := by
  have hv : ((⟨16⟩ : UInt256)).val.val = 16 := by
    show 16 % UInt256.size = 16
    exact Nat.mod_eq_of_lt (by unfold UInt256.size; omega)
  have h := shr_toNat x (⟨16⟩ : UInt256) (by rw [hv]; omega)
  rwa [hv] at h

/-- **(V4b-240)** `shr(240)` is division by 2²⁴⁰. -/
theorem shr240_toNat (x : UInt256) :
    (UInt256.shiftRight x (⟨240⟩ : UInt256)).toNat = x.toNat / 2 ^ 240 := by
  have hv : ((⟨240⟩ : UInt256)).val.val = 240 := by
    show 240 % UInt256.size = 240
    exact Nat.mod_eq_of_lt (by unfold UInt256.size; omega)
  have h := shr_toNat x (⟨240⟩ : UInt256) (by rw [hv]; omega)
  rwa [hv] at h

/-- `ofNat` wraps identically below `2²⁵⁶`. -/
theorem ofNat_toNat' (n : Nat) (h : n < UInt256.size) : (UInt256.ofNat n).toNat = n := by
  show n % UInt256.size = n
  exact Nat.mod_eq_of_lt h

/-! ## (V5) The composed window facts -/

private theorem fromBytes'_replicate_zero (n : Nat) : fromBytes' (List.replicate n 0) = 0 := by
  induction n with
  | zero => rfl
  | succ m ih => rw [List.replicate_succ]; unfold fromBytes'; simp [ih]

/-- Trailing zero bytes don't change the little-endian value (re-proved; upstream's is `private`). -/
private theorem fromBytes'_append_zeros (l : List UInt8) (n : Nat) :
    fromBytes' (l ++ List.replicate n 0) = fromBytes' l := by
  induction l with
  | nil => simp [fromBytes'_replicate_zero, fromBytes']
  | cons b bs ih => simp only [List.cons_append, fromBytes', ih]

/-- Leading zero bytes don't change the big-endian value (copied from `DataLayer.lean`). -/
theorem fromBytesBigEndian_replicate_append (k : Nat) (bytes : List UInt8) :
    fromBytesBigEndian (List.replicate k 0 ++ bytes) = fromBytesBigEndian bytes := by
  unfold fromBytesBigEndian; simp only [Function.comp]
  rw [List.reverse_append, List.reverse_replicate, fromBytes'_append_zeros]

/-- The mload'd voter word's value is the big-endian value of the 22 record bytes. -/
private theorem window_val (src : ByteArray) :
    fromByteArrayBigEndian ((⟨Array.replicate 10 0⟩ : ByteArray) ++ src)
      = fromBytesBigEndian (src.data.toList) := by
  unfold fromByteArrayBigEndian
  rw [toList_data, append_data,
      show ((⟨Array.replicate 10 0⟩ : ByteArray)).data = Array.replicate 10 (0 : UInt8) from rfl,
      Array.toList_append,
      show (Array.replicate 10 (0 : UInt8)).toList = List.replicate 10 0 from rfl,
      fromBytesBigEndian_replicate_append]

/-- **(V5a) Weight decode.** `and(mload(voter window), 0xffff)` IS the big-endian value of the
    record's last two bytes — the 16-bit registered weight. -/
theorem weight_of_window (src : ByteArray) (hsrc : src.size = 22) :
    (UInt256.land
        (UInt256.ofNat (fromByteArrayBigEndian ((⟨Array.replicate 10 0⟩ : ByteArray) ++ src)))
        (⟨0xffff⟩ : UInt256)).toNat
      = fromBytesBigEndian (src.data.toList.drop 20) := by
  have hlen : (src.data.toList).length = 22 := by rw [Array.length_toList]; exact hsrc
  have hlt : fromBytesBigEndian (src.data.toList) < UInt256.size := by
    have h := fromBytesBigEndian_lt (src.data.toList)
    rw [hlen] at h
    exact lt_trans h (by unfold UInt256.size; norm_num)
  rw [window_val src, mask16_toNat, ofNat_toNat' _ hlt]
  have h := fromBytesBigEndian_mod_pow (src.data.toList) 20
  rw [hlen, show (8:ℕ) * (22 - 20) = 16 from by norm_num] at h
  rwa [show (65536:ℕ) = 2 ^ 16 from by norm_num]

/-- **(V5a bound)** The decoded weight is a 16-bit value. -/
theorem weight_of_window_lt (src : ByteArray) :
    (UInt256.land
        (UInt256.ofNat (fromByteArrayBigEndian ((⟨Array.replicate 10 0⟩ : ByteArray) ++ src)))
        (⟨0xffff⟩ : UInt256)).toNat < 2 ^ 16 := by
  rw [mask16_toNat, show (2:ℕ) ^ 16 = 65536 from by norm_num]
  exact Nat.mod_lt _ (by norm_num)

/-- **(V5b) Signer decode.** `shr(16)` of the mload'd voter word IS the big-endian value of the
    record's first 20 bytes — the signer address. -/
theorem signer_of_window (src : ByteArray) (hsrc : src.size = 22) :
    (UInt256.shiftRight
        (UInt256.ofNat (fromByteArrayBigEndian ((⟨Array.replicate 10 0⟩ : ByteArray) ++ src)))
        (⟨16⟩ : UInt256)).toNat
      = fromBytesBigEndian (src.data.toList.take 20) := by
  have hlen : (src.data.toList).length = 22 := by rw [Array.length_toList]; exact hsrc
  have hlt : fromBytesBigEndian (src.data.toList) < UInt256.size := by
    have h := fromBytesBigEndian_lt (src.data.toList)
    rw [hlen] at h
    exact lt_trans h (by unfold UInt256.size; norm_num)
  rw [window_val src, shr16_toNat, ofNat_toNat' _ hlt]
  have h := fromBytesBigEndian_div_pow (src.data.toList) 20
  rwa [hlen, show (8:ℕ) * (22 - 20) = 16 from by norm_num] at h

/-! ## Axiom audit -/

#print axioms read_inside_write
#print axioms read_zero_then_write_suffix
#print axioms read_zero_then_write_at31
#print axioms read_sig_window_r
#print axioms read_sig_window_s
#print axioms read_index_window_head
#print axioms read32_getElem!
#print axioms read32_size
#print axioms write_eq_copySlice_gen
#print axioms write_size_gen
#print axioms fromBytes'_append
#print axioms fromBytesBigEndian_append
#print axioms fromBytesBigEndian_lt
#print axioms fromBytesBigEndian_mod_pow
#print axioms fromBytesBigEndian_div_pow
#print axioms fromBytesBigEndian_mod_2_16
#print axioms fromBytesBigEndian_div_2_16
#print axioms mask16_toNat
#print axioms mask8_toNat
#print axioms shr_toNat
#print axioms shr16_toNat
#print axioms shr240_toNat
#print axioms ofNat_toNat'
#print axioms weight_of_window
#print axioms weight_of_window_lt
#print axioms signer_of_window

end RelayWindows
