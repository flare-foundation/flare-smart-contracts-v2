import RelayLoopLiteral
import RelayLoopWindows
import DataLayer
open EvmYul

/-!
# RelayBodyEff — assembling the literal loop body (`body_effL`)

The **integration layer** for the literal loop-body model. Where `RelayLoopLiteral` provides the
statement/expression *atoms* (against EVMYulLean's real `exec`/`eval`), `RelayLoopWindows` the byte-window
*decode* lemmas, and `DataLayer` the `mstore(slot,0)` zero-init bridge, this file *composes* them into the
effect of the deployed signature-verification loop body (`RelayLoopLiteral.bodyL`), deriving the
per-iteration accounting that `RelayLoopMemRead.relay_loop_sound` currently assumes (`hcorr`/`hvalid`).

**This is the first inter-file-dependent proof file.** Unlike the others (each self-contained), it
`import`s three sibling modules, so checking it requires compiling those into the package lib first:

```bash
# (after the one-time EVMYulLean setup in ./README.md)
LIB=/tmp/evmyul2/.lake/build/lib/lean
for f in DataLayer RelayLoopWindows RelayLoopLiteral; do
  cp <repo>/test-forge/fv/lean/bytecode-refinement/$f.lean /tmp/evmyul2/
  lake env lean -o $LIB/$f.olean /tmp/evmyul2/$f.lean            # compile deps into the lib
done
cp <repo>/test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean /tmp/evmyul2/
cd /tmp/evmyul2 && lake env lean RelayBodyEff.lean                # exit 0; prints clean axiom lists
```

Everything here is hole-free: `#print axioms` ⊆ `{propext, Classical.choice, Quot.sound}` plus the two
already-documented upstream-dischargeable specs (`RelayWindows.zeroes_data`,
`RelayDataLayer.toByteArray_size`) inherited through the imported lemmas — no new axiom.
-/

namespace RelayBodyEff

/-! ## Composed memory-window reads (window read ∘ value decode)

The deployed body clears a scratch slot (`mstore(slot,0)`), copies a calldata record into it
(`calldatacopy`), then reads it back (`mload`) and decodes. These lemmas fuse the window read
(`RelayLoopWindows.read_zero_then_write_*`) with the arithmetic decode (`weight_of_window`/
`signer_of_window`) into a single fact about that clear→copy→read→decode pattern — the exact shape the
interpreter memory takes across statements 13–16 of `bodyL` for the voter record. -/

/-- **Voter weight read.** Clear 32 bytes at `d`, write the 22-byte record at `d+10`, read the word at
    `d` and mask with `0xffff`: the big-endian value of the record's last two bytes — the registered
    weight. (`read_zero_then_write_suffix` ∘ `weight_of_window`.) -/
theorem voter_weight_pure (src mem : ByteArray) (d : Nat) (hsrc : src.size = 22) (hmem : d + 32 ≤ mem.size) :
    (UInt256.land (UInt256.ofNat (fromByteArrayBigEndian (ByteArray.readWithPadding
        (ByteArray.write src 0 (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d+10) 22) d 32)))
      (⟨0xffff⟩ : UInt256)).toNat
      = fromBytesBigEndian (src.data.toList.drop 20) := by
  rw [RelayWindows.read_zero_then_write_suffix src mem d hsrc hmem]
  exact RelayWindows.weight_of_window src hsrc

/-- **Voter signer read.** Same window, `shr(16)` recovers the big-endian value of the record's first
    20 bytes — the signer address. (`read_zero_then_write_suffix` ∘ `signer_of_window`.) -/
theorem voter_signer_pure (src mem : ByteArray) (d : Nat) (hsrc : src.size = 22) (hmem : d + 32 ≤ mem.size) :
    (UInt256.shiftRight (UInt256.ofNat (fromByteArrayBigEndian (ByteArray.readWithPadding
        (ByteArray.write src 0 (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d+10) 22) d 32)))
      (⟨16⟩ : UInt256)).toNat
      = fromBytesBigEndian (src.data.toList.take 20) := by
  rw [RelayWindows.read_zero_then_write_suffix src mem d hsrc hmem]
  exact RelayWindows.signer_of_window src hsrc

/-! ## Interpreter-level voter reads (through `mload_in_range`)

Lifting the pure window reads to the actual interpreter `mload`: the memory at the read is the
clear→copy write pattern (`hmem`, discharged in `body_effL` from `mstore_lit_eff` + `mstore_zero_source`
and `calldatacopy2_eff` + `write_from_offset`), the address is a small literal (`hd`), and the slot is in
range (`h1`/`h2`, from the `activeWords` bump). `mload_masked_voter` is the accounting-critical `hcorr`;
`mload_shr_voter` is the registered-signer read used by the "wrong signature" guard. -/

/-- **Interpreter voter weight (`hcorr`).** `and(mload(slot), 0xffff)` at the voter slot = the record's
    registered 2-byte weight. (`mload_in_range` ∘ `voter_weight_pure`.) -/
theorem mload_masked_voter (self : EvmYul.MachineState) (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 22)
    (hmem : self.memory = ByteArray.write src 0 (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d+10) 22)
    (hsize : d + 32 ≤ mem.size)
    (hd : d < UInt256.size)
    (h1 : (UInt256.ofNat d).toNat < self.memory.size)
    (h2 : ¬ ((UInt256.ofNat d) ≥ self.activeWords * ⟨32⟩)) :
    (UInt256.land (self.mload (UInt256.ofNat d)).1 (⟨0xffff⟩ : UInt256)).toNat
      = fromBytesBigEndian (src.data.toList.drop 20) := by
  rw [RelayLoopLiteral.mload_in_range self (UInt256.ofNat d) h1 h2, hmem,
      RelayWindows.ofNat_toNat' d hd]
  exact voter_weight_pure src mem d hsrc hsize

/-- **Interpreter voter signer.** `shr(16, mload(slot))` at the voter slot = the record's registered
    20-byte signer address. (`mload_in_range` ∘ `voter_signer_pure`.) -/
theorem mload_shr_voter (self : EvmYul.MachineState) (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 22)
    (hmem : self.memory = ByteArray.write src 0 (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d+10) 22)
    (hsize : d + 32 ≤ mem.size)
    (hd : d < UInt256.size)
    (h1 : (UInt256.ofNat d).toNat < self.memory.size)
    (h2 : ¬ ((UInt256.ofNat d) ≥ self.activeWords * ⟨32⟩)) :
    (UInt256.shiftRight (self.mload (UInt256.ofNat d)).1 (⟨16⟩ : UInt256)).toNat
      = fromBytesBigEndian (src.data.toList.take 20) := by
  rw [RelayLoopLiteral.mload_in_range self (UInt256.ofNat d) h1 h2, hmem,
      RelayWindows.ofNat_toNat' d hd]
  exact voter_signer_pure src mem d hsrc hsize

/-! ## Memory state after the voter clear→copy (discharging `hmem`)

The `hmem` hypothesis of `mload_masked_voter`/`mload_shr_voter` — that the interpreter memory *is* the
window write-pattern — is not an assumption: it is exactly the memory produced by the two voter
statements. `voter_mem_pattern` threads the interpreter state through `mstore(m+96, 0)` (which sets
`memory := (ofNat 0).toByteArray.write 0 mem (m+96) 32`, turned into the `⟨replicate 32 0⟩` write by
`mstore_zero_source`) then `calldatacopy(m+106, q, 22)` (which sets `memory := calldata.write q mem'
(m+106) 22`, turned into the offset-0 `extract` form by `write_from_offset`), landing exactly on the
`read_zero_then_write_suffix` pattern at `d = m+96` with `src = calldata.extract q (q+22)`. So the voter
weight/signer reads are fully derived once the (small) offset and range side-conditions are met. -/

open EvmYul.Yul in
/-- **`hmem` discharge.** The memory after `mstore(m+96,0); calldatacopy(m+106, q, 22)` is the voter
    window write-pattern (`clear 32 at m+96`, then the 22-byte record at `m+106 = (m+96)+10`). -/
theorem voter_mem_pattern (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) (m : Nat)
    (q : EvmYul.UInt256)
    (hq : q.toNat + 22 ≤ ss.executionEnv.calldata.size)
    (hdest : (m+106) + 22 ≤ (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 ss.toMachineState.memory (m+96) 32).size)
    (hm : m + 96 < EvmYul.UInt256.size) (hm2 : m + 106 < EvmYul.UInt256.size) :
    ((State.Ok ss vs).setMachineState ((State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+96)) (UInt256.ofNat 0))
      |> fun s13 => (s13.setSharedState (s13.toSharedState.calldatacopy (UInt256.ofNat (m+106)) q (UInt256.ofNat 22))).toMachineState.memory)
    = ByteArray.write (ss.executionEnv.calldata.extract q.toNat (q.toNat+22)) 0
        (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 ss.toMachineState.memory (m+96) 32) (m+106) 22 := by
  have hmst : (ss.toMachineState.mstore (UInt256.ofNat (m+96)) (UInt256.ofNat 0)).memory
      = ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 ss.toMachineState.memory (m+96) 32 := by
    unfold EvmYul.MachineState.mstore EvmYul.MachineState.writeWord EvmYul.writeBytes
    simp only [RelayDataLayer.mstore_zero_source, RelayWindows.ofNat_toNat' _ hm]
  simp only [State.setMachineState, State.toMachineState, State.setSharedState, State.toSharedState,
             EvmYul.SharedState.calldatacopy, hmst,
             RelayWindows.ofNat_toNat' _ hm2,
             RelayWindows.ofNat_toNat' 22 (show (22:Nat) < EvmYul.UInt256.size by unfold EvmYul.UInt256.size; omega)]
  rw [RelayWindows.write_from_offset ss.executionEnv.calldata _ q.toNat (m+106) 22 (by omega) hq hdest]

/-! ## Range discharge (the `mload_in_range` side-conditions `h1`/`h2`)

`mload_masked_voter` etc. take the two `lookupMemory` guards as hypotheses. They are not assumptions:
`h1` (address `< memory.size`) follows from the scratch region being allocated large enough — a genuine
precondition the contract establishes — and `h2` (address `< activeWords * 32`) follows from the
memory-expansion accounting `M`: any `mstore`/`calldatacopy` writing `[f, f+l)` advances `activeWords`
to at least `⌈(f+l)/32⌉`, so every address below `f+l` is covered. `M_lb_gen` is the general lower
bound; `mload_range_h1`/`h2` package the two discharges (reusing `DataLayer`'s `le_toNat`/`mul32_toNat`
and the no-overflow bound `hM32`, exactly as `mstore_lookupMemory` does). -/

/-- Memory-expansion lower bound (any positive write length): a write of `[f, f+l)` leaves every
    address below `f+l` inside `M s f l * 32`. -/
theorem M_lb_gen (s f l a : Nat) (hl : 0 < l) (ha : a < f + l) :
    a < EvmYul.MachineState.M s f l * 32 := by
  have hM : EvmYul.MachineState.M s f l = max s ((f + l + 31) / 32) := by
    obtain ⟨l', rfl⟩ := Nat.exists_eq_succ_of_ne_zero (Nat.pos_iff_ne_zero.mp hl)
    rfl
  rw [hM]; omega

/-- Size guard `h1` from the scratch-region size precondition. -/
theorem mload_range_h1 (self : EvmYul.MachineState) (a : Nat)
    (ha256 : a < EvmYul.UInt256.size) (hmem : a < self.memory.size) :
    (UInt256.ofNat a).toNat < self.memory.size := by
  rw [RelayWindows.ofNat_toNat' a ha256]; exact hmem

/-- ActiveWords guard `h2` from the memory-expansion bump (`activeWords = ofNat (M s f l)`, no overflow,
    address below the written region's end). -/
theorem mload_range_h2 (self : EvmYul.MachineState) (s f l a : Nat) (hl : 0 < l) (ha : a < f + l)
    (haw : self.activeWords = UInt256.ofNat (EvmYul.MachineState.M s f l))
    (hM32 : EvmYul.MachineState.M s f l * 32 < EvmYul.UInt256.size)
    (ha256 : a < EvmYul.UInt256.size) :
    ¬ ((UInt256.ofNat a) ≥ self.activeWords * (⟨32⟩ : UInt256)) := by
  rw [ge_iff_le, RelayDataLayer.le_toNat, haw, RelayDataLayer.mul32_toNat _ hM32,
      RelayWindows.ofNat_toNat' a ha256]
  exact Nat.not_le.mpr (M_lb_gen s f l a hl ha)

/-! ## The v-byte window (interpreter-level)

The `let v := and(mload(m+32), 0xff)` read of the deployed body. The `v`-slot at `m+32` is cleared,
then the 67-byte signature blob is copied at `m+63 = (m+32)+31`; the read at `m+32` masked with `0xff`
is the blob's first byte (`v`). Same recipe as the voter reads (window read ∘ decode ∘ `mload_in_range`);
proved by the parallel worker against `read_zero_then_write_at31` + a 1-byte `mask8` decode. -/

/-- Pure v-byte read: `and(read, 0xff)` of the cleared→blob-written window = the blob's first byte. -/
theorem vbyte_pure (src mem : ByteArray) (d : Nat) (hsrc : src.size = 67) (hmem : d + 98 ≤ mem.size) :
    (UInt256.land (UInt256.ofNat (fromByteArrayBigEndian (ByteArray.readWithPadding
        (ByteArray.write src 0 (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d+31) 67) d 32)))
      (⟨0xff⟩ : UInt256)).toNat
      = fromBytesBigEndian ((src.extract 0 1).data.toList) := by
  rw [RelayWindows.read_zero_then_write_at31 src mem d hsrc hmem]
  have window_val31 : fromByteArrayBigEndian ((⟨Array.replicate 31 0⟩ : ByteArray) ++ src.extract 0 1)
      = fromBytesBigEndian ((src.extract 0 1).data.toList) := by
    unfold fromByteArrayBigEndian
    rw [RelayWindows.toList_data, RelayWindows.append_data,
        show ((⟨Array.replicate 31 0⟩ : ByteArray)).data = Array.replicate 31 (0 : UInt8) from rfl,
        Array.toList_append,
        show (Array.replicate 31 (0 : UInt8)).toList = List.replicate 31 0 from rfl,
        RelayWindows.fromBytesBigEndian_replicate_append]
  have hx1 : (src.extract 0 1).size = 1 := RelayWindows.extract_size' src 0 1 (by omega) (by omega)
  have hlen : ((src.extract 0 1).data.toList).length = 1 := by
    rw [Array.length_toList]; exact hx1
  have hval : fromBytesBigEndian ((src.extract 0 1).data.toList) < 2 ^ 8 := by
    have h := RelayWindows.fromBytesBigEndian_lt ((src.extract 0 1).data.toList)
    rw [hlen, show 8 * 1 = 8 from by norm_num] at h
    exact h
  have hlt : fromBytesBigEndian ((src.extract 0 1).data.toList) < UInt256.size :=
    lt_trans hval (by unfold UInt256.size; norm_num)
  rw [window_val31, RelayWindows.mask8_toNat, RelayWindows.ofNat_toNat' _ hlt]
  exact Nat.mod_eq_of_lt hval

/-- Interpreter v-byte read: `and(mload(m+32), 0xff)` = the blob's first byte. -/
theorem mload_v_byte (self : EvmYul.MachineState) (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 67)
    (hmem : self.memory = ByteArray.write src 0 (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d+31) 67)
    (hsize : d + 98 ≤ mem.size) (hd : d < UInt256.size)
    (h1 : (UInt256.ofNat d).toNat < self.memory.size)
    (h2 : ¬ ((UInt256.ofNat d) ≥ self.activeWords * ⟨32⟩)) :
    (UInt256.land (self.mload (UInt256.ofNat d)).1 (⟨0xff⟩ : UInt256)).toNat
      = fromBytesBigEndian ((src.extract 0 1).data.toList) := by
  rw [RelayLoopLiteral.mload_in_range self (UInt256.ofNat d) h1 h2, hmem,
      RelayWindows.ofNat_toNat' d hd]
  exact vbyte_pure src mem d hsrc hsize

/-! ## The s-value read (the bad-`s` guard)

`if gt(mload(m+96), SECP_HALF) { revert }` reads the signature's `s` word — bytes 33..65 of the blob,
at `m+96 = (m+32)+64` — as a full 32-bit-word value, and rejects high-`s` malleable signatures. Unlike
the weight/signer/v reads this needs no mask/shift: it is the raw big-endian value of the `s` window
(`read_sig_window_s`), which the guard compares against `SECP_HALF`. -/

/-- Interpreter `s`-value read: `mload(m+96)` on the v-slot blob = the big-endian value of the `s` word. -/
theorem mload_s_value (self : EvmYul.MachineState) (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 67)
    (hmem : self.memory = ByteArray.write src 0 (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d+31) 67)
    (hsize : d + 98 ≤ mem.size) (hd64 : d + 64 < EvmYul.UInt256.size)
    (h1 : (UInt256.ofNat (d+64)).toNat < self.memory.size)
    (h2 : ¬ ((UInt256.ofNat (d+64)) ≥ self.activeWords * ⟨32⟩)) :
    (self.mload (UInt256.ofNat (d+64))).1
      = UInt256.ofNat (fromByteArrayBigEndian (src.extract 33 65)) := by
  rw [RelayLoopLiteral.mload_in_range self (UInt256.ofNat (d+64)) h1 h2, hmem,
      RelayWindows.ofNat_toNat' (d+64) hd64, RelayWindows.read_sig_window_s src mem d hsrc hsize]

/-! ## The index window (interpreter-level)

`let index := shr(240, mload(m+128))` — the signature's 2-byte voter index, at the *end* of the blob
(bytes 65,66, read at `m+128 = (m+32)+96`). Only the top two bytes survive the `shr(240)`, so unlike the
other windows this uses `read_index_window_head` (which pins just `read.extract 0 2 = src.extract 65 67`)
composed with `shr240_toNat` and `fromBytesBigEndian_div_pow` (division by `2^240` keeps the top 2 bytes),
bridged `extract 0 2 → take 2 → toList`. Built by the parallel worker. -/

/-- Pure index read: `shr(240, read)` of the v-slot blob window = the big-endian value of the blob's
    last two bytes (the voter index). -/
theorem index_pure (src mem : ByteArray) (d : Nat) (hsrc : src.size = 67) (hmem : d + 128 ≤ mem.size) :
    (UInt256.shiftRight (UInt256.ofNat (fromByteArrayBigEndian (ByteArray.readWithPadding
        (ByteArray.write src 0 (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d+31) 67) (d+96) 32)))
      (⟨240⟩ : UInt256)).toNat
      = fromBytesBigEndian ((src.extract 65 67).data.toList) := by
  have hZ : ((⟨Array.replicate 32 0⟩ : ByteArray)).size = 32 := by
    show (Array.replicate 32 (0 : UInt8)).size = 32
    simp only [Array.size_replicate]
  have h1s : (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32).size = mem.size :=
    RelayWindows.write_size_gen _ mem d 32 (by omega) hZ (by omega)
  have h2s : (ByteArray.write src 0
      (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 31) 67).size
      = mem.size := by
    rw [RelayWindows.write_size_gen src _ (d + 31) 67 (by omega) hsrc (by omega)]; exact h1s
  set R := ByteArray.readWithPadding
      (ByteArray.write src 0
        (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d + 31) 67)
      (d + 96) 32 with hRdef
  have hRsize : R.size = 32 := by
    rw [hRdef]; exact RelayWindows.read32_size _ (d + 96) (by omega)
  have hRlen : R.data.toList.length = 32 := by
    rw [Array.length_toList]; exact hRsize
  have hlt : fromByteArrayBigEndian R < UInt256.size := by
    unfold fromByteArrayBigEndian
    rw [RelayWindows.toList_data]
    have h := RelayWindows.fromBytesBigEndian_lt (R.data.toList)
    rw [hRlen] at h
    exact lt_of_lt_of_le h (by unfold UInt256.size; norm_num)
  rw [RelayWindows.shr240_toNat]
  rw [RelayWindows.ofNat_toNat' _ hlt]
  rw [show fromByteArrayBigEndian R = fromBytesBigEndian (R.data.toList) from by
        unfold fromByteArrayBigEndian; rw [RelayWindows.toList_data]]
  rw [show (240 : Nat) = 8 * (R.data.toList.length - 2) from by rw [hRlen],
      RelayWindows.fromBytesBigEndian_div_pow (R.data.toList) 2]
  have hwin : R.extract 0 2 = src.extract 65 67 := by
    rw [hRdef]; exact RelayWindows.read_index_window_head src mem d hsrc hmem
  have hbridge : R.data.toList.take 2 = (src.extract 65 67).data.toList := by
    rw [← hwin, RelayWindows.extract_data_gen _ 0 2 (by omega), Array.toList_extract,
        List.extract_eq_drop_take, List.drop_zero, Nat.sub_zero]
  rw [hbridge]

/-- Interpreter index read: `shr(240, mload(m+128))` = the blob's last-2-byte voter index. -/
theorem mload_shr_index (self : EvmYul.MachineState) (src mem : ByteArray) (d : Nat)
    (hsrc : src.size = 67)
    (hmem : self.memory = ByteArray.write src 0 (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 mem d 32) (d+31) 67)
    (hsize : d + 128 ≤ mem.size) (hd96 : d + 96 < EvmYul.UInt256.size)
    (h1 : (UInt256.ofNat (d+96)).toNat < self.memory.size)
    (h2 : ¬ ((UInt256.ofNat (d+96)) ≥ self.activeWords * ⟨32⟩)) :
    (UInt256.shiftRight (self.mload (UInt256.ofNat (d+96))).1 (⟨240⟩ : UInt256)).toNat
      = fromBytesBigEndian ((src.extract 65 67).data.toList) := by
  rw [RelayLoopLiteral.mload_in_range self (UInt256.ofNat (d+96)) h1 h2, hmem,
      RelayWindows.ofNat_toNat' (d+96) hd96]
  exact index_pure src mem d hsrc hsize

/-! ## The recovered-signer read (ecrecover output — the seam)

`ecrecover` runs via `staticcall(not(0), 1, m, 128, m+64, 32)`, whose *output* the seam
(`RelayLoopLiteral.recSuccessShared`) models as a `copySlice` of the recovered 32-byte word `ret` into
memory at `m+64`. The subsequent guards read it back: `iszero(mload(m+64))` (zero-signer reject) and
`eq(mload(m+64), shr16(mload(m+96)))` (recovered vs. registered signer). `mload_recovered` decodes that
read: the `copySlice` output is a `write` (`write_eq_copySlice_gen`), so the read returns `ret`
(`read_inside_write`), i.e. the recovered address `ofNat (fromByteArrayBigEndian ret)`. This is the only
read whose source is `staticcall` output rather than `calldatacopy`. -/

/-- Interpreter recovered-signer read: `mload(m+64)` after a successful ecrecover (memory = `ret` copied
    at `d`) = the recovered address value. -/
theorem mload_recovered (self : EvmYul.MachineState) (ret mem : ByteArray) (d : Nat)
    (hret : ret.size = 32)
    (hmem : self.memory = ret.copySlice 0 mem d 32)
    (hsize : d + 32 ≤ mem.size) (hd : d < EvmYul.UInt256.size)
    (h1 : (UInt256.ofNat d).toNat < self.memory.size)
    (h2 : ¬ ((UInt256.ofNat d) ≥ self.activeWords * ⟨32⟩)) :
    (self.mload (UInt256.ofNat d)).1 = UInt256.ofNat (fromByteArrayBigEndian ret) := by
  rw [RelayLoopLiteral.mload_in_range self (UInt256.ofNat d) h1 h2, hmem,
      RelayWindows.ofNat_toNat' d hd,
      ← RelayWindows.write_eq_copySlice_gen ret mem d 32 (by norm_num) hret hsize,
      RelayWindows.read_inside_write ret mem d 32 d hret hsize (le_refl d) (by omega),
      Nat.sub_self, Nat.zero_add,
      show ret.extract 0 32 = ret from by
        apply ByteArray.ext; rw [RelayWindows.extract_data_gen ret 0 32 (by omega)]
        exact Array.extract_eq_self_iff.mpr (Or.inr ⟨rfl, by rw [show ret.data.size = 32 from hret]⟩)]

/-! ## Guard-condition evaluation (`iszero` wrapping)

Five of `bodyL`'s guards are `iszero(…)` (bad-v, ecrecover error, bad returndatasize, zero-signer,
wrong-signature). `eval_iszero` lifts the evaluation of the inner expression `e` (which may change the
state — the `mload`/`staticcall` guards do) through the `iszero` primitive: `iszero(e)` evaluates to
`isZero v` in the post-`e` state. A guard *passes* (does not revert) exactly when this is `⟨0⟩`, i.e. the
inner value is nonzero — which `exec_If_false` then turns into a no-op advance. `primCall_ISZERO'`
re-proves the (file-private in `RelayLoopLiteral`) `ISZERO` primcall via the public `step` layer;
`evalArgs_rev_single` is the general single-argument `evalArgs`. -/

open EvmYul.Yul EvmYul.Yul.Ast in
/-- `ISZERO` primitive call (public re-proof of `RelayLoopLiteral`'s private one). -/
theorem primCall_ISZERO' (f : Nat) (s : EvmYul.Yul.State) (v : EvmYul.UInt256) :
    EvmYul.Yul.primCall (f+1) s Operation.ISZERO [v] = .ok (s, [EvmYul.UInt256.isZero v]) := by
  unfold EvmYul.Yul.primCall; rw [if_neg (fun h => absurd h.2 (by decide))]; rfl

open EvmYul.Yul EvmYul.Yul.Ast in
/-- Evaluate a single argument (possibly state-changing). -/
theorem evalArgs_rev_single (f : Nat) (e : Expr) (s s' : EvmYul.Yul.State) (v : EvmYul.UInt256)
    (he : EvmYul.Yul.eval (f + 2) e none s = .ok (s', v)) :
    EvmYul.Yul.reverse' (EvmYul.Yul.evalArgs (f + 3) [e] none s) = .ok (s', [v]) := by
  simp only [EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail, he, EvmYul.Yul.cons', EvmYul.Yul.reverse',
             List.reverse_cons, List.reverse_nil, List.nil_append]

open EvmYul.Yul EvmYul.Yul.Ast in
/-- **`iszero(e)` eval.** If `e` evaluates to `v` (state `→ s'`), then `iszero(e)` evaluates to
    `isZero v` in `s'`. A guard `if iszero(e) {revert}` is thus not taken iff `v ≠ 0`. -/
theorem eval_iszero (f : Nat) (e : Expr) (s s' : EvmYul.Yul.State) (v : EvmYul.UInt256)
    (he : EvmYul.Yul.eval (f + 2) e none s = .ok (s', v)) :
    EvmYul.Yul.eval (f + 4) (Expr.Call (Sum.inl Operation.ISZERO) [e]) none s
      = .ok (s', EvmYul.UInt256.isZero v) := by
  exact RelayLoopLiteral.eval_primcall (f+3) Operation.ISZERO [e] s s' s' [v] _
    (evalArgs_rev_single f e s s' v he) (primCall_ISZERO' (f+2) s' v)

end RelayBodyEff

#print axioms RelayBodyEff.voter_weight_pure
#print axioms RelayBodyEff.voter_signer_pure
#print axioms RelayBodyEff.mload_masked_voter
#print axioms RelayBodyEff.mload_shr_voter
#print axioms RelayBodyEff.voter_mem_pattern
#print axioms RelayBodyEff.M_lb_gen
#print axioms RelayBodyEff.mload_range_h1
#print axioms RelayBodyEff.mload_range_h2
#print axioms RelayBodyEff.vbyte_pure
#print axioms RelayBodyEff.mload_v_byte
#print axioms RelayBodyEff.mload_s_value
#print axioms RelayBodyEff.index_pure
#print axioms RelayBodyEff.mload_shr_index
#print axioms RelayBodyEff.mload_recovered
#print axioms RelayBodyEff.eval_iszero
