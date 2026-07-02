import EvmYul.Wheels
import EvmYul.MachineStateOps
open EvmYul

/-!
# BR-1 (data layer) — foundation bricks

Work toward discharging **BR-1** from the claims ledger: that each signature-loop iteration's accumulated
value is the registered weight `mload(weights[i]) = w[i]`. This file collects the **hole-free** sub-results
of that data-layer refinement, committed incrementally (no `sorry`/`admit`).

## The two upstream-dischargeable specs

These proofs add exactly two assumptions beyond Lean's standard three (`propext`, `Classical.choice`,
`Quot.sound`), both *access-modifier limitations* rather than trust assumptions:

1. `zeroes_data` — `ffi.ByteArray.zeroes` (EVMYulLean's `@[extern "memset_zero"]`) is declared `opaque`, so
   it has no proof-level content. We give its minimal, obviously-true spec. Dischargeable upstream by
   changing `opaque ByteArray.zeroes` to a real `def … @[implemented_by memset_zero]`.
2. `toByteArray_size` — `UInt256.toByteArray` always yields 32 bytes. **Verified** provable (short proof,
   below) but blocked downstream because the supporting bound `toBytes'_UInt256_le` is `private`. Exposing
   that one upstream lemma turns this axiom into a theorem.

Both become theorems with one-line upstream edits; neither is a semantic assumption about the EVM.
**The exact upstream patches and the verified discharge proofs are archived in `AXIOM_DISCHARGE.md`**
(this directory) — the "verified provable" claims are reproducible from there, not anecdotal.

## Status (see `docs/relay-verification/10-claims-ledger-trust-and-residual.md` §10.5)

* **Byte-decode round-trip — DONE** (`fromBytesBigEndian_toBytesBigEndian`).
* **Memory keystone — DONE** (`keystone`): `copySlice`/`extract` round-trip, *no* `zeroes` axiom.
* **ByteArray memory round-trip — DONE** (`mem_roundtrip`): `readWithPadding (write …) … = src`, against
  EVMYulLean's actual `ByteArray.write`/`readWithPadding`. This is the heart of `mload∘mstore`.
* **Value decode — DONE** (`ofNat_toNat`, `size_append`, `toList_data`, and `fromByteArray_toByteArray`:
  `fromByteArrayBigEndian (v.toByteArray) = v.toNat`, via the `toList`/`toByteArray` loop invariants + the
  leading-zero argument).
* **MachineState `mstore`/`mload` wrapping — DONE** (`mstore_lookupMemory`, `mstore_mload`): on EVMYulLean's
  validated `MachineState`, `(mstore a v).mload a = v` whenever the buffer has room and the active-word
  count does not overflow. Discharges the `activeWords`/size guard and composes the byte layer; this is the
  operational `mload∘mstore = id` for a 32-byte word.
* **`& 0xffff` weight mask — DONE** (`mask16_toNat`, `mask16_of_lt`): `and(x, 0xffff)` extracts the low 16
  bits (`= x.toNat mod 2¹⁶`), and is the identity on a 16-bit registered weight. *No* axioms beyond the
  standard three. This is the masked weight read at `Relay.sol:1327`.
* **Data-layer capstone — DONE** (`weight_read`): a 16-bit weight written to a 32-byte slot is recovered by
  the deployed read pattern `and(mload(slot), 0xffff)` under EVMYulLean's validated `MachineState` —
  i.e. `mload(weights[i]) & 0xffff = w[i]` for one slot, the heart of BR-1.
* **Consumed by**: the memory-reading ∀N loop and the simulation relation `R` in `RelayLoopMemRead.lean` —
  whose **accounting core is complete** (`relay_loop_sound`: the deployed loop accepts ⟹ total registered
  weight > threshold, ∀N; `weight_read` below discharges its per-slot data-layer hypothesis; the
  selection/validity half of `R` remains its stated hypotheses). This file supplies the bounded data-layer
  bricks that composition rests on; no fact about the *read* itself remains open.

New to this suite? See `../../README.md` §3 (how to read a Lean proof + re-check it). Orientation: this file
reasons about EVMYulLean's *real* `ByteArray`/`MachineState` operations. Lean 4.22 has no `ByteArray` lemma
layer, so the proofs deliberately descend to the underlying `Array` via `ByteArray.ext` (two `ByteArray`s are
equal iff their `.data` arrays are). The two `axiom`s below (`zeroes_data`, `toByteArray_size`) are documented
*upstream-dischargeable specs* — one for an `opaque` FFI symbol, one for a `private` upstream bound — not
semantic assumptions; each `#print axioms` at the bottom shows exactly which results depend on them.
-/

namespace RelayDataLayer

/-- The minimal spec for the `opaque ffi.ByteArray.zeroes` (`memset_zero`). The single documented trust
    addition; dischargeable upstream (`opaque → def + @[implemented_by]`). -/
axiom zeroes_data (n : USize) : (ffi.ByteArray.zeroes n).data = Array.replicate n.toNat (0 : UInt8)

/-- BR-1 brick: the big-endian byte encode/decode is the identity, about EVMYulLean's real functions. -/
theorem fromBytesBigEndian_toBytesBigEndian (n : Nat) :
    fromBytesBigEndian (toBytesBigEndian n) = n := by
  simp [fromBytesBigEndian, toBytesBigEndian]

/-- Value-decode brick: `ofNat ∘ toNat = id` on `UInt256`. -/
theorem ofNat_toNat (v : UInt256) : UInt256.ofNat v.toNat = v := by
  unfold UInt256.ofNat UInt256.toNat
  simp only [Id.run]
  apply congrArg UInt256.mk; apply Fin.ext
  show v.val.val % UInt256.size = v.val.val
  exact Nat.mod_eq_of_lt v.val.isLt

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

/-- `ByteArray` append adds sizes (no ByteArray `size_append` exists on Lean 4.22). -/
theorem size_append (a b : ByteArray) : (a ++ b).size = a.size + b.size := by
  show (a ++ b).data.size = a.data.size + b.data.size
  rw [append_data]; simp [Array.size_append]

/-- `ByteArray.get!` agrees with `data.toList` indexing (helper for `toList_data`). -/
private theorem get!_eq (bs : ByteArray) (i : Nat) (h : i < bs.size) :
    bs.get! i = bs.data.toList[i]'(by rw [Array.length_toList]; exact h) := by
  obtain ⟨d⟩ := bs
  have h' : i < d.size := h
  show d[i]! = d.toList[i]
  rw [Array.getElem_toList]; exact getElem!_pos d i h'

/-- Loop invariant of `ByteArray.toList.loop`: it reverses its accumulator and appends the data tail. -/
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

/-- `ByteArray.toList = data.toList` (no such lemma on Lean 4.22; proved via the loop invariant). -/
theorem toList_data (bs : ByteArray) : bs.toList = bs.data.toList := by
  show ByteArray.toList.loop bs 0 [] = bs.data.toList
  rw [toList_loop]; simp

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

/-! ## Value decode: `fromByteArrayBigEndian (v.toByteArray) = v.toNat` -/

/-- `List.toByteArray.loop` invariant: it appends the consumed list (as an array) to its accumulator. -/
private theorem tba_loop (l : List UInt8) (r : ByteArray) :
    (List.toByteArray.loop l r).data = r.data ++ l.toArray := by
  induction l generalizing r with
  | nil => simp [List.toByteArray.loop]
  | cons b bs ih => rw [List.toByteArray.loop, ih]; simp [ByteArray.push]

/-- `(List.toByteArray l).data.toList = l` (no such lemma on Lean 4.22). -/
private theorem ltba (l : List UInt8) : (List.toByteArray l).data.toList = l := by
  show (List.toByteArray.loop l ByteArray.empty).data.toList = l
  rw [tba_loop, show ByteArray.empty.data = #[] from rfl]; simp

private theorem fromBytes'_replicate_zero (n : Nat) : fromBytes' (List.replicate n 0) = 0 := by
  induction n with
  | zero => rfl
  | succ m ih => rw [List.replicate_succ]; unfold fromBytes'; simp [ih]

/-- Trailing zero bytes don't change the little-endian value (re-proved; EVMYulLean's is `private`). -/
private theorem fromBytes'_append_zeros (l : List UInt8) (n : Nat) :
    fromBytes' (l ++ List.replicate n 0) = fromBytes' l := by
  induction l with
  | nil => simp [fromBytes'_replicate_zero, fromBytes']
  | cons b bs ih => simp only [List.cons_append, fromBytes', ih]

/-- Leading zero bytes don't change the big-endian value. -/
private theorem fromBytesBigEndian_replicate_append (k : Nat) (bytes : List UInt8) :
    fromBytesBigEndian (List.replicate k 0 ++ bytes) = fromBytesBigEndian bytes := by
  unfold fromBytesBigEndian; simp only [Function.comp]
  rw [List.reverse_append, List.reverse_replicate, fromBytes'_append_zeros]

/-- **Value decode.** Decoding `v.toByteArray` (32-byte big-endian with leading zero pad) recovers `v.toNat`
    — against EVMYulLean's actual `fromByteArrayBigEndian`/`toByteArray`. With `ofNat_toNat` and
    `mem_roundtrip` this is what makes `(mstore a v).mload a = v`. -/
theorem fromByteArray_toByteArray (v : UInt256) : fromByteArrayBigEndian v.toByteArray = v.toNat := by
  have hrepl : ∀ k, (Array.replicate k (0:UInt8)).toList = List.replicate k 0 := fun _ => rfl
  have hbe : (BE v.toNat).data.toList = toBytesBigEndian v.toNat := ltba (toBytesBigEndian v.toNat)
  unfold fromByteArrayBigEndian UInt256.toByteArray
  rw [toList_data, append_data, zeroes_data, Array.toList_append, hrepl, hbe,
      fromBytesBigEndian_replicate_append, fromBytesBigEndian_toBytesBigEndian]

/-! ## MachineState wrapping: `(mstore a v).mload a = v` (the `activeWords`/size guard)

This composes the byte-level results above into a statement about EVMYulLean's actual
`MachineState.mstore`/`mload`/`lookupMemory`. `lookupMemory` is guarded by
`addr ≥ memory.size ∨ addr ≥ activeWords * 32`; we discharge both disjuncts from the store's effect on
`memory.size` and `activeWords`, then read the slot back through `mem_roundtrip` +
`fromByteArray_toByteArray` + `ofNat_toNat`. -/

-- The `rfl`/`show` steps below reduce EVMYulLean's `mstore`/`lookupMemory`/`Fin`-arithmetic by `whnf`,
-- which exceeds the 200k default; the byte-layer proofs above stay well under it.
set_option maxHeartbeats 1000000

/-- `UInt256` order is `toNat` order (definitional). -/
theorem lt_toNat (a b : UInt256) : (a < b) = (a.toNat < b.toNat) := rfl
theorem le_toNat (a b : UInt256) : (a ≤ b) = (a.toNat ≤ b.toNat) := rfl

/-- `(ofNat m) * ⟨32⟩` has `toNat = m * 32` when `m * 32` does not overflow `2²⁵⁶`. -/
theorem mul32_toNat (m : Nat) (h : m * 32 < UInt256.size) :
    ((UInt256.ofNat m) * (⟨32⟩ : UInt256)).toNat = m * 32 := by
  show ((UInt256.ofNat m).val * ((⟨32⟩ : UInt256)).val).val = m * 32
  rw [Fin.val_mul]
  have hm : (UInt256.ofNat m).val.val = m := by
    show m % UInt256.size = m; exact Nat.mod_eq_of_lt (by omega)
  have h32 : ((⟨32⟩ : UInt256)).val.val = 32 := by
    show 32 % UInt256.size = 32; exact Nat.mod_eq_of_lt (by unfold UInt256.size; omega)
  rw [hm, h32]; exact Nat.mod_eq_of_lt h

/-- The post-`mstore` active-word count always covers the slot just written: `a.toNat < M(…) * 32`. -/
theorem M_lb (s d : Nat) : d < MachineState.M s d 32 * 32 := by
  have hM : MachineState.M s d 32 = max s ((d + 32 + 31) / 32) := rfl
  rw [hM]; omega

/-- **MachineState round-trip (guard discharged).** Given the encoded word is 32 bytes (`h32`), the
    buffer has room (`hmem`), and the active-word count does not overflow (`hM32`), reading the just-stored
    slot back through EVMYulLean's real `lookupMemory` returns the value. This is the wrapping of
    `mem_roundtrip` + `fromByteArray_toByteArray` + `ofNat_toNat` into the operational `mstore`. -/
theorem mstore_lookupMemory (ms : MachineState) (a v : UInt256)
    (h32 : (v.toByteArray).size = 32)
    (hmem : a.toNat + 32 ≤ ms.memory.size)
    (hM32 : MachineState.M ms.activeWords.toNat a.toNat 32 * 32 < UInt256.size) :
    (ms.mstore a v).lookupMemory a = v := by
  have hmemeq : (ms.mstore a v).memory = ByteArray.write v.toByteArray 0 ms.memory a.toNat 32 := rfl
  have haw : (ms.mstore a v).activeWords
      = UInt256.ofNat (MachineState.M ms.activeWords.toNat a.toNat 32) := rfl
  have hsize : (ms.mstore a v).memory.size = ms.memory.size := by
    rw [hmemeq, write_eq_copySlice v.toByteArray ms.memory a.toNat h32 hmem,
        copySlice_size v.toByteArray ms.memory a.toNat h32 hmem]
  have hg1 : ¬ a.toNat ≥ (ms.mstore a v).memory.size := by rw [hsize]; omega
  have hg2 : ¬ a ≥ (ms.mstore a v).activeWords * (⟨32⟩ : UInt256) := by
    rw [ge_iff_le, le_toNat, haw, mul32_toNat _ hM32]
    exact Nat.not_le.mpr (M_lb _ _)
  unfold MachineState.lookupMemory
  rw [if_neg (not_or.mpr ⟨hg1, hg2⟩)]
  show UInt256.ofNat
      (fromByteArrayBigEndian (ByteArray.readWithPadding (ms.mstore a v).memory a.toNat 32)) = v
  rw [hmemeq, mem_roundtrip v.toByteArray ms.memory a.toNat h32 hmem, fromByteArray_toByteArray,
      ofNat_toNat]

/-- Same, phrased on `mload` (whose value component is `lookupMemory`). -/
theorem mstore_mload_val (ms : MachineState) (a v : UInt256)
    (h32 : (v.toByteArray).size = 32)
    (hmem : a.toNat + 32 ≤ ms.memory.size)
    (hM32 : MachineState.M ms.activeWords.toNat a.toNat 32 * 32 < UInt256.size) :
    ((ms.mstore a v).mload a).1 = v := by
  simp only [MachineState.mload]
  exact mstore_lookupMemory ms a v h32 hmem hM32

/-- The **second** (and final) upstream-dischargeable spec, sibling to `zeroes_data`: EVMYulLean's
    `UInt256.toByteArray` always yields exactly 32 bytes. This is TRUE and **verified** — its discharge is a
    short proof: `(toBytesBigEndian v.toNat).length ≤ 32` (from the existing upstream bound
    `toBytes'_UInt256_le`) plus the `zeroes ++ BE` size split (`size_append`, `zeroes_size`, and the USize
    literal). It is blocked downstream *only* because `toBytes'_UInt256_le` is declared `private`; exposing
    that one lemma upstream turns this axiom into a theorem. Like `zeroes_data`, this is an access-modifier
    limitation, not a trust assumption. (Discharge proof verified against a locally-patched EVMYulLean.) -/
axiom toByteArray_size (v : UInt256) : (UInt256.toByteArray v).size = 32

/-- **Unconditional MachineState round-trip.** Storing `v` at `a` and loading it back returns `v`, whenever
    the buffer has room and the active-word count does not overflow — the 32-byte-ness of the encoded word
    is supplied by `toByteArray_size`. This is the operational `mload∘mstore = id` for a single 32-byte
    word, against EVMYulLean's validated `MachineState`. -/
theorem mstore_mload (ms : MachineState) (a v : UInt256)
    (hmem : a.toNat + 32 ≤ ms.memory.size)
    (hM32 : MachineState.M ms.activeWords.toNat a.toNat 32 * 32 < UInt256.size) :
    ((ms.mstore a v).mload a).1 = v :=
  mstore_mload_val ms a v (toByteArray_size v) hmem hM32

/-! ## The `& 0xffff` weight mask (Relay.sol:1327, `and(mload(…), 0xffff)`) -/

/-- Bitwise AND with `0xffff` is reduction mod 2¹⁶ (proved bit-by-bit; no `zeroes_data`). -/
theorem land_65535 (n : Nat) : n &&& 65535 = n % 65536 := by
  have h1 : (65535 : Nat) = 2 ^ 16 - 1 := by norm_num
  have h2 : (65536 : Nat) = 2 ^ 16 := by norm_num
  rw [h1, h2]
  apply Nat.eq_of_testBit_eq
  intro i
  rw [Nat.testBit_and, Nat.testBit_two_pow_sub_one, Nat.testBit_mod_two_pow, Bool.and_comm]

/-- `toNat` is injective on `UInt256`. -/
theorem toNat_inj {a b : UInt256} (h : a.toNat = b.toNat) : a = b := by
  obtain ⟨a⟩ := a; obtain ⟨b⟩ := b
  apply congrArg UInt256.mk; apply Fin.ext; exact h

/-- **Weight mask.** `and(x, 0xffff)` on EVMYulLean's `UInt256.land` extracts the low 16 bits: its value
    is `x.toNat mod 2¹⁶`. This is the weight read at `Relay.sol:1327`. -/
theorem mask16_toNat (x : UInt256) :
    (UInt256.land x (⟨0xffff⟩ : UInt256)).toNat = x.toNat % 65536 := by
  have hb : ((⟨0xffff⟩ : UInt256)).val.val = 65535 := by
    show 0xffff % UInt256.size = 65535
    exact Nat.mod_eq_of_lt (by unfold UInt256.size; omega)
  show (Fin.land x.val (⟨0xffff⟩ : UInt256).val).val = x.toNat % 65536
  rw [show (Fin.land x.val (⟨0xffff⟩ : UInt256).val).val
        = (x.val.val &&& (⟨0xffff⟩ : UInt256).val.val) % UInt256.size from rfl, hb, land_65535]
  exact Nat.mod_eq_of_lt (lt_trans (Nat.mod_lt _ (by norm_num)) (by unfold UInt256.size; omega))

/-- A value already below 2¹⁶ is unchanged by the `& 0xffff` mask: registered weights are 16-bit
    (`totalWeight < 2¹⁶`, `Relay.sol:350`), so the mask is the identity on a stored weight. -/
theorem mask16_of_lt (x : UInt256) (h : x.toNat < 65536) :
    UInt256.land x (⟨0xffff⟩ : UInt256) = x :=
  toNat_inj (by rw [mask16_toNat, Nat.mod_eq_of_lt h])

/-! ## BR-1 data-layer capstone (bounded part) -/

/-- **The data-layer read, end to end.** A 16-bit weight `w` written into a 32-byte memory slot is
    recovered by the deployed contract's actual read pattern — `and(mload(slot), 0xffff)` — executed under
    EVMYulLean's validated `MachineState`. This is exactly the BR-1 data-layer claim
    "`mload(weights[i]) & 0xffff = w[i]`" for one slot: it composes the byte-decode round-trip
    (`mem_roundtrip`/`fromByteArray_toByteArray`), the `mstore`/`mload` guard discharge (`mstore_mload`),
    and the weight mask (`mask16_of_lt`). Hole-free modulo the two documented upstream-dischargeable specs.

    What remains for full BR-1 (the simulation relation `R`, §10.5 item iv) is *plumbing this into the
    ∀N loop*: identifying the per-iteration slot from the calldata/memory layout and transferring
    `RelaySigLoop.threshold_sound` — not any further fact about the read itself. -/
theorem weight_read (ms : MachineState) (slot w : UInt256)
    (hw : w.toNat < 65536)
    (hmem : slot.toNat + 32 ≤ ms.memory.size)
    (hM32 : MachineState.M ms.activeWords.toNat slot.toNat 32 * 32 < UInt256.size) :
    UInt256.land ((ms.mstore slot w).mload slot).1 (⟨0xffff⟩ : UInt256) = w := by
  rw [mstore_mload ms slot w hmem hM32]; exact mask16_of_lt w hw

/-! ## The `mstore(slot, 0)` zero-init source (for the literal loop-body model)

The deployed loop precedes each scratch-slot `calldatacopy` with `mstore(slot, 0)` to clear the word,
so that `and(mload(slot), 0xffff)` (weight) and `shr(16, mload(slot))` (signer) see zeros in the
high, uncopied bytes rather than stale data from a previous iteration. The window lemmas in
`RelayLoopWindows` (`read_zero_then_write_*`, `signer_of_window`) model that clear as a write of the
literal source `⟨Array.replicate 32 0⟩`. The interpreter, however, writes `(UInt256.ofNat 0).toByteArray`
(what `MachineState.mstore` stores for the Yul literal `0`). `mstore_zero_source` reconciles the two. -/

/-- **Base-256 uniqueness at zero.** A little-endian byte list decodes to `0` iff it is all zeros
    (each digit of a base-`2^8` expansion of `0` must vanish). -/
theorem fromBytes'_eq_zero (l : List UInt8) (h : fromBytes' l = 0) :
    l = List.replicate l.length 0 := by
  induction l with
  | nil => rfl
  | cons b bs ih =>
    unfold fromBytes' at h
    have hconv : b.toFin.val = b.toNat := rfl
    have hbs : fromBytes' bs = 0 := by omega
    have hbn : b.toNat = 0 := by omega
    have hb0 : b = 0 := UInt8.toNat.inj (by rw [hbn]; rfl)
    simp only [List.length_cons, List.replicate_succ]
    rw [hb0]
    exact congrArg (0 :: ·) (ih hbs)

/-- **mstore-zero bridge.** The Yul literal `0` (`UInt256.ofNat 0`) stored by `mstore(slot, 0)` has
    the 32-byte all-zero encoding — exactly the `⟨Array.replicate 32 0⟩` source the window lemmas in
    `RelayLoopWindows` (`read_zero_then_write_*`, `signer_of_window`) assume. Derived with **no new
    assumption**: `toByteArray_size` (size 32) + the `fromByteArray_toByteArray` roundtrip (decodes to
    `0`) + base-256 uniqueness (`fromBytes'_eq_zero`) force every byte to `0`. -/
theorem mstore_zero_source :
    (UInt256.ofNat 0).toByteArray = (⟨Array.replicate 32 0⟩ : ByteArray) := by
  have hsz : (UInt256.ofNat 0).toByteArray.size = 32 := toByteArray_size _
  have hszl : (UInt256.ofNat 0).toByteArray.data.toList.length = 32 := by
    rw [Array.length_toList]; exact hsz
  have hval0 : (UInt256.ofNat 0).toNat = 0 := by decide
  have hval : fromBytes' ((UInt256.ofNat 0).toByteArray.data.toList.reverse) = 0 := by
    have hr := fromByteArray_toByteArray (UInt256.ofNat 0)
    rw [hval0] at hr
    unfold fromByteArrayBigEndian fromBytesBigEndian at hr
    rw [toList_data] at hr
    simpa [Function.comp] using hr
  have hrev : (UInt256.ofNat 0).toByteArray.data.toList.reverse = List.replicate 32 0 := by
    have hlen : ((UInt256.ofNat 0).toByteArray.data.toList.reverse).length = 32 := by
      rw [List.length_reverse]; exact hszl
    rw [fromBytes'_eq_zero _ hval, hlen]
  have htl : (UInt256.ofNat 0).toByteArray.data.toList = List.replicate 32 0 := by
    have hcr := congrArg List.reverse hrev
    rwa [List.reverse_reverse, List.reverse_replicate] at hcr
  apply ByteArray.ext
  apply Array.toList_inj.mp
  rw [htl, Array.toList_replicate]

#print axioms fromBytesBigEndian_toBytesBigEndian
#print axioms keystone
#print axioms mem_roundtrip
#print axioms fromByteArray_toByteArray
#print axioms mstore_lookupMemory
#print axioms mstore_mload
#print axioms mask16_toNat
#print axioms mask16_of_lt
#print axioms weight_read
#print axioms fromBytes'_eq_zero
#print axioms mstore_zero_source
end RelayDataLayer
