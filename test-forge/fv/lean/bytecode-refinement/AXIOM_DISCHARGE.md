# Replacing the local data-layer axioms with upstream theorems

[`DataLayer.lean`](DataLayer.lean) declares two semantic assumptions beyond Lean's standard three:
`zeroes_data` and `toByteArray_size`. `RelayLoopWindows.lean` declares the same `zeroes_data` specification
in its namespace. These declarations are part of the current proof's trust boundary.

This document gives a reproducible procedure for replacing those assumptions with theorems in a patched
checkout of the manifest-pinned EVMYulLean revision. The repository gate does not apply these patches and
continues to report the declarations as axioms.

Throughout: EVMYulLean at the pinned commit, built once —

```bash
git clone https://github.com/NethermindEth/EVMYulLean /tmp/evmyul2
cd /tmp/evmyul2 && git checkout 047f63070309f436b66c61e276ab3b6d1169265a
lake exe cache get && lake build
```

---

## Axiom 1 — `zeroes_data`

**Statement.** `(ffi.ByteArray.zeroes n).data = Array.replicate n.toNat 0`.

**Why it is an axiom downstream.** `ffi.ByteArray.zeroes` is declared `opaque` with
`@[extern "memset_zero"]` (`EvmYul/FFI/ffi.lean:17-18`). An `opaque` has no proof-level body, so *nothing*
about its value is provable — the minimal true spec must be supplied.

**The one-line upstream discharge.** Replace the `opaque` with a `def` carrying the same extern symbol:

```lean
-- EvmYul/FFI/ffi.lean — replace lines 17-18:
--   @[extern "memset_zero"]
--   opaque ByteArray.zeroes (n : USize) : ByteArray
-- with:
@[extern "memset_zero"]
def ByteArray.zeroes (n : USize) : ByteArray := ⟨Array.replicate n.toNat 0⟩
```

After this, the axiom is a theorem by definitional unfolding:

```lean
theorem zeroes_data (n : USize) : (ffi.ByteArray.zeroes n).data = Array.replicate n.toNat (0 : UInt8) := rfl
```

**Trust note.** The `@[extern]` on a `def` means compiled code runs the C `memset_zero` while proofs use the
Lean body — the standard extern contract carried by every FFI symbol in Lean core (the C code must agree with
the Lean definition). This does not enlarge the trusted base relative to EVMYulLean's existing externs; it
*shrinks* it, by giving the symbol a checkable meaning.

---

## Axiom 2 — `toByteArray_size`

**Statement.** `(UInt256.toByteArray v).size = 32`.

**Why it is an axiom downstream.** `UInt256.toByteArray v = ffi.ByteArray.zeroes ⟨32 - (BE v.toNat).size⟩ ++ BE v.toNat`
(`EvmYul/Wheels.lean:12-14`). The size argument needs the bound `(toBytes' n).length ≤ 32` for `n < 2²⁵⁶` —
which exists upstream as `toBytes'_UInt256_le` (`EvmYul/UInt256.lean:321`) but is declared **`private`**
(as is `toBytes'` itself, line 291), so it is unnameable downstream.

**The upstream patch** (two words): in `EvmYul/UInt256.lean` at the pinned commit, delete `private` from

- line 291: `private def toBytes' : ℕ → List UInt8` → `def toBytes' : ℕ → List UInt8`
- line 321: `private lemma toBytes'_UInt256_le …` → `lemma toBytes'_UInt256_le …`

then rebuild the touched modules: `lake build EvmYul.UInt256 EvmYul.Wheels EvmYul.MachineStateOps`.

**Discharge proof.** Save as `/tmp/evmyul2/ToByteArraySizeDischarge.lean` and run
`lake env lean ToByteArraySizeDischarge.lean`:

```lean
import EvmYul.Wheels
import EvmYul.MachineStateOps
open EvmYul

namespace AxiomDischarge

-- Axiom 1's spec (or, after the Axiom-1 patch above, replace this with the `rfl` theorem and the
-- final axiom list below drops to the standard three).
axiom zeroes_data (n : USize) : (ffi.ByteArray.zeroes n).data = Array.replicate n.toNat (0 : UInt8)

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

theorem size_append (a b : ByteArray) : (a ++ b).size = a.size + b.size := by
  show (a ++ b).data.size = a.data.size + b.data.size
  rw [append_data]; simp [Array.size_append]

theorem zeroes_size (n : USize) : (ffi.ByteArray.zeroes n).size = n.toNat := by
  show (ffi.ByteArray.zeroes n).data.size = n.toNat
  rw [zeroes_data]; simp

private theorem tba_loop (l : List UInt8) (r : ByteArray) :
    (List.toByteArray.loop l r).data = r.data ++ l.toArray := by
  induction l generalizing r with
  | nil => simp [List.toByteArray.loop]
  | cons b bs ih => rw [List.toByteArray.loop, ih]; simp [ByteArray.push]

theorem ltba (l : List UInt8) : (List.toByteArray l).data.toList = l := by
  show (List.toByteArray.loop l ByteArray.empty).data.toList = l
  rw [tba_loop, show ByteArray.empty.data = #[] from rfl]; simp

theorem BE_size (n : Nat) : (BE n).size = (toBytesBigEndian n).length := by
  show (List.toByteArray (toBytesBigEndian n)).data.size = _
  rw [← Array.length_toList, ltba]

-- Uses the un-private'd upstream bound `toBytes'_UInt256_le`.
theorem toBytesBigEndian_len_le (v : UInt256) : (toBytesBigEndian v.toNat).length ≤ 32 := by
  show (List.reverse (toBytes' v.toNat)).length ≤ 32
  rw [List.length_reverse]; exact toBytes'_UInt256_le v.val.isLt

theorem numBits_big : (32:Nat) < 2 ^ System.Platform.numBits := by
  rcases System.Platform.numBits_eq with h | h <;> rw [h] <;> norm_num

theorem usize_sub_lit (k : Nat) (hk : k ≤ 32) :
    (⟨32 - k⟩ : USize).toNat = 32 - k := by
  show (((32 : BitVec System.Platform.numBits) - (k : BitVec System.Platform.numBits))).toNat = 32 - k
  have hb := numBits_big
  have e1 : ((k : BitVec System.Platform.numBits)).toNat = k := by
    show k % 2 ^ System.Platform.numBits = k; exact Nat.mod_eq_of_lt (by omega)
  have e2 : ((32 : BitVec System.Platform.numBits)).toNat = 32 := by
    show 32 % 2 ^ System.Platform.numBits = 32; exact Nat.mod_eq_of_lt (by omega)
  rw [BitVec.toNat_sub, e1, e2,
      show 2 ^ System.Platform.numBits - k + 32 = 2 ^ System.Platform.numBits + (32 - k) by omega,
      Nat.add_mod_left, Nat.mod_eq_of_lt (show 32 - k < 2 ^ System.Platform.numBits by omega)]

theorem toByteArray_size (v : UInt256) : (UInt256.toByteArray v).size = 32 := by
  unfold UInt256.toByteArray
  rw [size_append, zeroes_size]
  have hle : (BE v.toNat).size ≤ 32 := by rw [BE_size]; exact toBytesBigEndian_len_le v
  rw [usize_sub_lit _ hle]; omega

#print axioms toByteArray_size

end AxiomDischarge
```

**Expected output** with EVMYulLean `047f6307` and the visibility patch:

```
'AxiomDischarge.toByteArray_size' depends on axioms: [propext, Classical.choice, Quot.sound, AxiomDischarge.zeroes_data]
```

This shows that `toByteArray_size` depends only on `zeroes_data` in addition to Lean's standard axioms.
Applying the first patch as well replaces that dependency with the `zeroes_data` theorem.

---

## Summary

| Axiom | Blocker at `047f6307` | Upstream fix | Discharge after fix |
|---|---|---|---|
| `zeroes_data` | `opaque` FFI symbol | `opaque` → `def … := ⟨Array.replicate n.toNat 0⟩` (keep `@[extern]`) | `rfl` |
| `toByteArray_size` | `private` bound `toBytes'_UInt256_le` | delete two `private`s in `EvmYul/UInt256.lean` | proof above |

After applying both patches, `DataLayer.lean` and `RelayLoopWindows.lean` can replace their local axiom
declarations with the corresponding theorems. Without those patches, the manifest allowlist and generated
report must continue to identify all three namespace-qualified declarations as semantic assumptions.
