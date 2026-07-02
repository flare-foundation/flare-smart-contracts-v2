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

open EvmYul.Yul in
/-- **General `hmem` discharge** (both scratch slots). The memory after `mstore(dclear, 0)` then
    `calldatacopy(dwrite, q, len)` is the clear→copy write-pattern — clearing 32 bytes at `dclear`,
    then the `len`-byte calldata window at `dwrite`. `voter_mem_pattern` is the `(m+96, m+106, 22)`
    instance; the v-slot reads (index / v-byte / s-value) use the `(m+32, m+63, 67)` instance. -/
theorem mstore_cdc_mem (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore)
    (dclear dwrite len : Nat) (q : EvmYul.UInt256) (hlen : 0 < len)
    (hq : q.toNat + len ≤ ss.executionEnv.calldata.size)
    (hdest : dwrite + len ≤ (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 ss.toMachineState.memory dclear 32).size)
    (hdc : dclear < EvmYul.UInt256.size) (hdw : dwrite < EvmYul.UInt256.size) (hlensz : len < EvmYul.UInt256.size) :
    ((State.Ok ss vs).setMachineState ((State.Ok ss vs).toMachineState.mstore (UInt256.ofNat dclear) (UInt256.ofNat 0))
      |> fun s' => (s'.setSharedState (s'.toSharedState.calldatacopy (UInt256.ofNat dwrite) q (UInt256.ofNat len))).toMachineState.memory)
    = ByteArray.write (ss.executionEnv.calldata.extract q.toNat (q.toNat+len)) 0
        (ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 ss.toMachineState.memory dclear 32) dwrite len := by
  have hmst : (ss.toMachineState.mstore (UInt256.ofNat dclear) (UInt256.ofNat 0)).memory
      = ByteArray.write (⟨Array.replicate 32 0⟩ : ByteArray) 0 ss.toMachineState.memory dclear 32 := by
    unfold EvmYul.MachineState.mstore EvmYul.MachineState.writeWord EvmYul.writeBytes
    simp only [RelayDataLayer.mstore_zero_source, RelayWindows.ofNat_toNat' _ hdc]
  simp only [State.setMachineState, State.toMachineState, State.setSharedState, State.toSharedState,
             EvmYul.SharedState.calldatacopy, hmst,
             RelayWindows.ofNat_toNat' _ hdw, RelayWindows.ofNat_toNat' len hlensz]
  rw [RelayWindows.write_from_offset ss.executionEnv.calldata _ q.toNat dwrite len hlen hq hdest]

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

/-! ## Guard-condition evaluations (the comparison guards)

The revert-guards of `bodyL` are `If cond {revert}` for `cond` a comparison. A guard is *not taken*
(the iteration advances) exactly when `cond` evaluates to `⟨0⟩`. Here we evaluate the conditions to
their `UInt256` comparison values; `exec_If_false` then turns "`cond = ⟨0⟩`" into a no-op. `eval_range_cond`
is the range guard `gt(add(index,1), nVot)` (a depth-3 compose of `eval_add_var_lit` under `gt`); the
order/`eq` guards follow the same recipe. `primCall_GT'` (like `primCall_ISZERO'`) is the public re-proof
of the private `GT` primcall. -/

open EvmYul.Yul EvmYul.Yul.Ast in
/-- `GT` primitive call (public re-proof). -/
theorem primCall_GT' (f : Nat) (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.Yul.primCall (f+1) s Operation.GT [a,b] = .ok (s, [EvmYul.UInt256.gt a b]) := by
  unfold EvmYul.Yul.primCall; rw [if_neg (fun h => absurd h.2 (by decide))]; rfl

open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral in
/-- **Range guard condition.** `gt(add(index, 1), nVot)` evaluates to the comparison value (state
    unchanged); the guard `if gt(add(index,1), nVot) {revert}` is not taken iff `add(index,1) ≤ nVot`. -/
theorem eval_range_cond (f : Nat) (nVot : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.eval (f + 10)
      (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]) none (EvmYul.Yul.State.Ok ss vs)
      = .ok (EvmYul.Yul.State.Ok ss vs,
             EvmYul.UInt256.gt (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[IDX]!) (UInt256.ofNat 1)) nVot) := by
  refine RelayLoopLiteral.eval_primcall (f+9) Operation.GT
    [bc .ADD [V IDX, litN 1], litU nVot] (EvmYul.Yul.State.Ok ss vs)
    (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
    [EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[IDX]!) (UInt256.ofNat 1), nVot] _
    (RelayLoopLiteral.evalArgs_rev_pair (f+4) (bc .ADD [V IDX, litN 1]) (litU nVot)
      (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
      (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[IDX]!) (UInt256.ofNat 1)) nVot
      (RelayLoopLiteral.eval_lit (f+7) nVot _)
      (RelayLoopLiteral.eval_add_var_lit f IDX (UInt256.ofNat 1) (EvmYul.Yul.State.Ok ss vs)))
    (primCall_GT' (f+8) _ _ _)

/-! ## The remaining guard conditions

Every other revert-guard of `bodyL`, evaluated to its decision value by the same recipe. `primCall_LT'`/
`_EQ'`/`_OR'` are public re-proofs (the `RelayLoopLiteral` ones are file-private). The order guard is a
pure two-variable compare; the bad-s guard is `gt` of a state-changing `mload`; the returndatasize and
zero-signer guards are `iszero` of the seam readback; the bad-v guard is the depth-4
`iszero(or(eq,eq))`. The wrong-signature guard (15) and the staticcall guard (10, via
`staticcall_hyp_compose`) are the two remaining, tied to the seam. -/

section MoreGuards
open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral

/-- `LT` primitive call (public re-proof). -/
theorem primCall_LT' (f : Nat) (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.Yul.primCall (f+1) s Operation.LT [a,b] = .ok (s, [EvmYul.UInt256.lt a b]) := by
  unfold EvmYul.Yul.primCall; rw [if_neg (fun h => absurd h.2 (by decide))]; rfl
/-- `EQ` primitive call (public re-proof). -/
theorem primCall_EQ' (f : Nat) (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.Yul.primCall (f+1) s Operation.EQ [a,b] = .ok (s, [EvmYul.UInt256.eq a b]) := by
  unfold EvmYul.Yul.primCall; rw [if_neg (fun h => absurd h.2 (by decide))]; rfl
/-- `OR` primitive call (public re-proof). -/
theorem primCall_OR' (f : Nat) (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.Yul.primCall (f+1) s Operation.OR [a,b] = .ok (s, [EvmYul.UInt256.lor a b]) := by
  unfold EvmYul.Yul.primCall; rw [if_neg (fun h => absurd h.2 (by decide))]; rfl

/-- **Order guard.** `lt(index, nextUnusedIndex)` → the comparison value (state unchanged);
    not taken iff `index ≥ nextUnusedIndex` (the strict-increase discipline). -/
theorem eval_order_cond (f : Nat) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.eval (f + 6) (bc .LT [V IDX, V NUI]) none (EvmYul.Yul.State.Ok ss vs)
      = .ok (EvmYul.Yul.State.Ok ss vs,
             EvmYul.UInt256.lt ((EvmYul.Yul.State.Ok ss vs)[IDX]!) ((EvmYul.Yul.State.Ok ss vs)[NUI]!)) := by
  refine RelayLoopLiteral.eval_primcall (f+5) Operation.LT [V IDX, V NUI]
    (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
    [(EvmYul.Yul.State.Ok ss vs)[IDX]!, (EvmYul.Yul.State.Ok ss vs)[NUI]!] _
    (RelayLoopLiteral.evalArgs_rev_pair f (V IDX) (V NUI)
      (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
      ((EvmYul.Yul.State.Ok ss vs)[IDX]!) ((EvmYul.Yul.State.Ok ss vs)[NUI]!)
      (RelayLoopLiteral.eval_var (f+3) NUI (EvmYul.Yul.State.Ok ss vs))
      (RelayLoopLiteral.eval_var (f+1) IDX (EvmYul.Yul.State.Ok ss vs)))
    (primCall_LT' (f+4) _ _ _)

/-- **Bad-s guard** (generic `gt(mload(a), c)`). `gt` of a state-changing `mload` and a literal;
    for `a = m+96`, `c = SECP_HALF` this is the low-`s` malleability check. -/
theorem eval_gt_mload_lit (g : Nat) (a c : EvmYul.UInt256) (s : EvmYul.Yul.State) :
    EvmYul.Yul.eval (g + 8) (bc .GT [bc .MLOAD [Expr.Lit a], Expr.Lit c]) none s
      = .ok (s.setMachineState (s.toSharedState.toMachineState.mload a).2,
             EvmYul.UInt256.gt (s.toSharedState.toMachineState.mload a).1 c) := by
  refine RelayLoopLiteral.eval_primcall (g+7) Operation.GT
    [bc .MLOAD [Expr.Lit a], Expr.Lit c] s
    (s.setMachineState (s.toSharedState.toMachineState.mload a).2)
    (s.setMachineState (s.toSharedState.toMachineState.mload a).2)
    [(s.toSharedState.toMachineState.mload a).1, c] _
    (RelayLoopLiteral.evalArgs_rev_pair (g+2) (bc .MLOAD [Expr.Lit a]) (Expr.Lit c)
      s s (s.setMachineState (s.toSharedState.toMachineState.mload a).2)
      (s.toSharedState.toMachineState.mload a).1 c
      (RelayLoopLiteral.eval_lit (g+5) c s) (RelayLoopLiteral.eval_mload_lit g a s))
    (primCall_GT' (g+6) _ _ _)

/-- **Returndatasize guard.** `iszero(eq(returndatasize(), 32))` — passes iff the ecrecover call
    returned exactly 32 bytes. -/
theorem eval_g11 (f : Nat) (s : EvmYul.Yul.State) :
    EvmYul.Yul.eval (f + 8) (bc .ISZERO [bc .EQ [bc .RETURNDATASIZE [], litN 32]]) none s
      = .ok (s, EvmYul.UInt256.isZero (EvmYul.UInt256.eq (.ofNat s.toMachineState.returnData.size) ⟨32⟩)) := by
  exact eval_iszero (f+4) (bc .EQ [bc .RETURNDATASIZE [], litN 32]) s s
    (EvmYul.UInt256.eq (.ofNat s.toMachineState.returnData.size) ⟨32⟩)
    (RelayLoopLiteral.returndatasize_eq32_eval f s)

/-- **Zero-signer guard.** `iszero(mload(m+64))` — passes iff the recovered signer word is nonzero. -/
theorem eval_g12 (f a : Nat) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.eval (f + 6) (bc .ISZERO [bc .MLOAD [litN a]]) none (EvmYul.Yul.State.Ok ss vs)
      = .ok ((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2,
             EvmYul.UInt256.isZero ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1) := by
  exact eval_iszero (f+2) (bc .MLOAD [litN a]) (EvmYul.Yul.State.Ok ss vs)
    ((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2)
    ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1
    (RelayLoopLiteral.eval_mload_lit f (UInt256.ofNat a) (EvmYul.Yul.State.Ok ss vs))

/-- `eq(V x, c)`, pure (a leaf for the bad-v guard). -/
theorem eval_eq_var_lit (f : Nat) (x : EvmYul.Identifier) (c : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.eval (f + 6) (bc .EQ [V x, Expr.Lit c]) none (EvmYul.Yul.State.Ok ss vs)
      = .ok (EvmYul.Yul.State.Ok ss vs, EvmYul.UInt256.eq ((EvmYul.Yul.State.Ok ss vs)[x]!) c) := by
  exact RelayLoopLiteral.eval_primcall (f+5) Operation.EQ [V x, Expr.Lit c]
    (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
    [(EvmYul.Yul.State.Ok ss vs)[x]!, c] _
    (RelayLoopLiteral.evalArgs_rev_pair f (V x) (Expr.Lit c)
      (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
      ((EvmYul.Yul.State.Ok ss vs)[x]!) c
      (RelayLoopLiteral.eval_lit (f+3) c _) (RelayLoopLiteral.eval_var (f+1) x _))
    (primCall_EQ' (f+4) _ _ _)

/-- `or(eq(V x,c1), eq(V x,c2))`, pure. -/
theorem eval_or_two_eq (f : Nat) (x : EvmYul.Identifier) (c1 c2 : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.eval (f + 10) (bc .OR [bc .EQ [V x, Expr.Lit c1], bc .EQ [V x, Expr.Lit c2]]) none (EvmYul.Yul.State.Ok ss vs)
      = .ok (EvmYul.Yul.State.Ok ss vs,
             EvmYul.UInt256.lor (EvmYul.UInt256.eq ((EvmYul.Yul.State.Ok ss vs)[x]!) c1)
                                (EvmYul.UInt256.eq ((EvmYul.Yul.State.Ok ss vs)[x]!) c2)) := by
  exact RelayLoopLiteral.eval_primcall (f+9) Operation.OR
    [bc .EQ [V x, Expr.Lit c1], bc .EQ [V x, Expr.Lit c2]]
    (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
    [EvmYul.UInt256.eq ((EvmYul.Yul.State.Ok ss vs)[x]!) c1, EvmYul.UInt256.eq ((EvmYul.Yul.State.Ok ss vs)[x]!) c2] _
    (RelayLoopLiteral.evalArgs_rev_pair (f+4) (bc .EQ [V x, Expr.Lit c1]) (bc .EQ [V x, Expr.Lit c2])
      (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
      (EvmYul.UInt256.eq ((EvmYul.Yul.State.Ok ss vs)[x]!) c1) (EvmYul.UInt256.eq ((EvmYul.Yul.State.Ok ss vs)[x]!) c2)
      (eval_eq_var_lit (f+2) x c2 ss vs) (eval_eq_var_lit f x c1 ss vs))
    (primCall_OR' (f+8) _ _ _)

/-- **Bad-v guard.** `iszero(or(eq(v,27), eq(v,28)))` — passes iff `v ∈ {27, 28}` (a valid recovery id). -/
theorem eval_badv_cond (f : Nat) (x : EvmYul.Identifier) (c1 c2 : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.eval (f + 12) (bc .ISZERO [bc .OR [bc .EQ [V x, Expr.Lit c1], bc .EQ [V x, Expr.Lit c2]]]) none (EvmYul.Yul.State.Ok ss vs)
      = .ok (EvmYul.Yul.State.Ok ss vs,
             EvmYul.UInt256.isZero (EvmYul.UInt256.lor (EvmYul.UInt256.eq ((EvmYul.Yul.State.Ok ss vs)[x]!) c1)
                                (EvmYul.UInt256.eq ((EvmYul.Yul.State.Ok ss vs)[x]!) c2))) := by
  exact eval_iszero (f+8) (bc .OR [bc .EQ [V x, Expr.Lit c1], bc .EQ [V x, Expr.Lit c2]])
    (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) _ (eval_or_two_eq f x c1 c2 ss vs)

/-- **Wrong-signature guard.** `iszero(eq(mload(mr), shr(16, mload(mv))))` — the deepest guard, with
    two *state-changing* `mload`s: `shr(16, mload(mv))` (the registered signer, at the voter slot `mv`)
    evaluated first, then `mload(mr)` (the recovered signer, at `mr`). The guard is not taken iff the two
    coincide, i.e. `ecrecover` returned the registered signer (assumption MC-2). Both `mload`s thread
    their `activeWords` bump: `s → s1 → s2`. -/
theorem eval_wrongsig_cond (f mr mv : Nat) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    let s  := EvmYul.Yul.State.Ok ss vs
    let s1 := s.setMachineState (s.toSharedState.toMachineState.mload (UInt256.ofNat mv)).2
    let s2 := s1.setMachineState (s1.toSharedState.toMachineState.mload (UInt256.ofNat mr)).2
    EvmYul.Yul.eval (f + 12)
      (bc .ISZERO [bc .EQ [bc .MLOAD [litN mr], bc .SHR [litN 16, bc .MLOAD [litN mv]]]]) none s
      = .ok (s2, EvmYul.UInt256.isZero
          (EvmYul.UInt256.eq (s1.toSharedState.toMachineState.mload (UInt256.ofNat mr)).1
            (EvmYul.UInt256.shiftRight (s.toSharedState.toMachineState.mload (UInt256.ofNat mv)).1 (UInt256.ofNat 16)))) := by
  intro s s1 s2
  refine eval_iszero (f+8) (bc .EQ [bc .MLOAD [litN mr], bc .SHR [litN 16, bc .MLOAD [litN mv]]]) s s2 _ ?_
  refine RelayLoopLiteral.eval_primcall (f+9) Operation.EQ
    [bc .MLOAD [litN mr], bc .SHR [litN 16, bc .MLOAD [litN mv]]] s s2 s2
    [(s1.toSharedState.toMachineState.mload (UInt256.ofNat mr)).1,
     EvmYul.UInt256.shiftRight (s.toSharedState.toMachineState.mload (UInt256.ofNat mv)).1 (UInt256.ofNat 16)] _
    (RelayLoopLiteral.evalArgs_rev_pair (f+4) (bc .MLOAD [litN mr]) (bc .SHR [litN 16, bc .MLOAD [litN mv]])
      s s1 s2
      (s1.toSharedState.toMachineState.mload (UInt256.ofNat mr)).1
      (EvmYul.UInt256.shiftRight (s.toSharedState.toMachineState.mload (UInt256.ofNat mv)).1 (UInt256.ofNat 16))
      (RelayLoopLiteral.eval_shr_lit_mload (f+2) (UInt256.ofNat 16) (UInt256.ofNat mv) s)
      (RelayLoopLiteral.eval_mload_lit (f+2) (UInt256.ofNat mr) s1))
    (primCall_EQ' (f+8) _ _ _)

end MoreGuards

/-! ## The `Let`-statement effects

`bodyL`'s four `Let`s, each via `let_prim_eff` (which threads the RHS eval then `insert`s the bound
variable). `let_nui` is pure `add`; `let_idx`/`let_vv` read one `mload` (`shr`/`and` decode); `let_ww` is
the accounting update `weight := weight + and(mload(voter), 0xffff)` (depth-3, reusing
`eval_and_mload_lit`). These are the advance-steps that carry the loop's `index`/`nextUnusedIndex`/`v`/
`weight` locals through the body chain. -/

section LetEffects
open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral

theorem primCall_ADD' (f : Nat) (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.Yul.primCall (f+1) s Operation.ADD [a,b] = .ok (s, [EvmYul.UInt256.add a b]) := by
  unfold EvmYul.Yul.primCall; rw [if_neg (fun h => absurd h.2 (by decide))]; rfl
theorem primCall_SHR' (f : Nat) (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.Yul.primCall (f+1) s Operation.SHR [a,b] = .ok (s, [EvmYul.UInt256.shiftRight b a]) := by
  unfold EvmYul.Yul.primCall; rw [if_neg (fun h => absurd h.2 (by decide))]; rfl
theorem primCall_AND' (f : Nat) (s : EvmYul.Yul.State) (a b : EvmYul.UInt256) :
    EvmYul.Yul.primCall (f+1) s Operation.AND [a,b] = .ok (s, [EvmYul.UInt256.land a b]) := by
  unfold EvmYul.Yul.primCall; rw [if_neg (fun h => absurd h.2 (by decide))]; rfl

/-- `nextUnusedIndex := add(index, 1)` (pure). -/
theorem let_nui (f : Nat) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.exec (f + 7) (Stmt.Let [NUI] (some (bc .ADD [V IDX, litN 1]))) none (EvmYul.Yul.State.Ok ss vs)
      = .ok ((EvmYul.Yul.State.Ok ss vs).insert NUI (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[IDX]!) (UInt256.ofNat 1))) := by
  exact RelayLoopLiteral.let_prim_eff (f+6) NUI Operation.ADD [V IDX, litN 1]
    (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
    [(EvmYul.Yul.State.Ok ss vs)[IDX]!, UInt256.ofNat 1] _
    (RelayLoopLiteral.evalArgs_rev_pair (f+1) (V IDX) (litN 1)
      (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
      ((EvmYul.Yul.State.Ok ss vs)[IDX]!) (UInt256.ofNat 1)
      (RelayLoopLiteral.eval_lit (f+4) (UInt256.ofNat 1) _) (RelayLoopLiteral.eval_var (f+2) IDX _))
    (primCall_ADD' (f+5) _ _ _)

/-- `index := shr(240, mload(a))`. -/
theorem let_idx (f a : Nat) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.exec (f + 6) (Stmt.Let [IDX] (some (bc .SHR [litN 240, bc .MLOAD [litN a]]))) none (EvmYul.Yul.State.Ok ss vs)
      = .ok (((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2).insert IDX
              (EvmYul.UInt256.shiftRight ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1 (UInt256.ofNat 240))) := by
  refine RelayLoopLiteral.let_prim_eff (f+5) IDX Operation.SHR [litN 240, bc .MLOAD [litN a]]
    (EvmYul.Yul.State.Ok ss vs)
    ((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2)
    ((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2)
    [UInt256.ofNat 240, ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1] _
    (RelayLoopLiteral.evalArgs_rev_pair f (litN 240) (bc .MLOAD [litN a])
      (EvmYul.Yul.State.Ok ss vs)
      ((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2)
      ((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2)
      (UInt256.ofNat 240) ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1
      (RelayLoopLiteral.eval_mload_lit f (UInt256.ofNat a) (EvmYul.Yul.State.Ok ss vs))
      (RelayLoopLiteral.eval_lit (f+1) (UInt256.ofNat 240) _))
    (primCall_SHR' (f+4) _ _ _)

/-- `v := and(mload(a), c)`. -/
theorem let_vv (g a : Nat) (c : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.exec (g + 8) (Stmt.Let [VV] (some (bc .AND [bc .MLOAD [litN a], Expr.Lit c]))) none (EvmYul.Yul.State.Ok ss vs)
      = .ok (((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2).insert VV
              (EvmYul.UInt256.land ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1 c)) := by
  refine RelayLoopLiteral.let_prim_eff (g+7) VV Operation.AND [bc .MLOAD [litN a], Expr.Lit c]
    (EvmYul.Yul.State.Ok ss vs)
    ((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2)
    ((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2)
    [((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1, c] _
    (RelayLoopLiteral.evalArgs_rev_pair (g+2) (bc .MLOAD [litN a]) (Expr.Lit c)
      (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
      ((EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2)
      ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1 c
      (RelayLoopLiteral.eval_lit (g+5) c _) (RelayLoopLiteral.eval_mload_lit g (UInt256.ofNat a) _))
    (primCall_AND' (g+6) _ _ _)

/-- `weight := add(weight, and(mload(a), c))` — the accounting update (depth-3). -/
theorem let_ww (G a : Nat) (c : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    let se := (EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).2
    EvmYul.Yul.exec (G + 10) (Stmt.Let [WW] (some (bc .ADD [V WW, bc .AND [bc .MLOAD [litN a], Expr.Lit c]]))) none (EvmYul.Yul.State.Ok ss vs)
      = .ok (se.insert WW (EvmYul.UInt256.add (se[WW]!)
              (EvmYul.UInt256.land ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1 c))) := by
  intro se
  refine RelayLoopLiteral.let_prim_eff (G+9) WW Operation.ADD [V WW, bc .AND [bc .MLOAD [litN a], Expr.Lit c]]
    (EvmYul.Yul.State.Ok ss vs) se se
    [se[WW]!, EvmYul.UInt256.land ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1 c] _
    (RelayLoopLiteral.evalArgs_rev_pair (G+4) (V WW) (bc .AND [bc .MLOAD [litN a], Expr.Lit c])
      (EvmYul.Yul.State.Ok ss vs) se se
      (se[WW]!) (EvmYul.UInt256.land ((EvmYul.Yul.State.Ok ss vs).toSharedState.toMachineState.mload (UInt256.ofNat a)).1 c)
      (eval_and_mload_lit G (UInt256.ofNat a) c (EvmYul.Yul.State.Ok ss vs))
      (RelayLoopLiteral.eval_var (G+5) WW se))
    (primCall_ADD' (G+8) _ _ _)

end LetEffects

/-! ## The staticcall/ecrecover seam guard

`if iszero(staticcall(not(0), 1, m, 128, m+64, 32)) { revert }` — the ecrecover call. Its gas argument
`not(0)` is *not* a literal, so `staticcall_hyp_compose` (which assumes literal args) doesn't apply
directly; `hargs_staticcall` first evaluates all six arguments (`not(0)` via `step_NOT`, the rest
literals). `seam_guard_eval` then composes the per-call ecrecover hypothesis `hsc` (from
`RelayLoopLiteral.recHypothesis .success` — the OP-1/MC-2 modeling) through `eval_primcall` and
`eval_iszero`: the guard evaluates to `⟨0⟩` (not taken) and threads the state to the post-staticcall
`s1` (the recovered signer written to `m+64`). This is the seam integrated as a guard peel. -/

section SeamGuard
open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral

/-- Argument evaluation for the ecrecover `staticcall` (`not(0)` gas + five literals). -/
theorem hargs_staticcall (fuel m : Nat) (s : EvmYul.Yul.State) :
    EvmYul.Yul.reverse' (EvmYul.Yul.evalArgs (fuel + 30)
      [litN 32, litN (m+64), litN 128, litN m, litN 1, bc .NOT [litN 0]] none s)
      = .ok (s, [EvmYul.UInt256.lnot (UInt256.ofNat 0), UInt256.ofNat 1, UInt256.ofNat m,
                 UInt256.ofNat 128, UInt256.ofNat (m+64), UInt256.ofNat 32]) := by
  simp [bc, litN, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail, EvmYul.Yul.eval,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.primCall, EvmYul.Yul.head', EvmYul.Yul.cons',
        EvmYul.Yul.reverse', step_NOT]

/-- **Seam guard.** Given the per-iteration ecrecover hypothesis `hsc` (`staticcall` returns success,
    copying the recovered word to `m+64`), the guard `iszero(staticcall(...))` evaluates to `⟨0⟩` (not
    taken), threading the post-call state `s1`. -/
theorem seam_guard_eval (fuel m : Nat) (s s1 : EvmYul.Yul.State)
    (hsc : EvmYul.Yul.primCall (fuel+30) s Operation.STATICCALL
             [EvmYul.UInt256.lnot (UInt256.ofNat 0), UInt256.ofNat 1, UInt256.ofNat m,
              UInt256.ofNat 128, UInt256.ofNat (m+64), UInt256.ofNat 32] = .ok (s1, [⟨1⟩])) :
    EvmYul.Yul.eval (fuel + 33)
      (bc .ISZERO [bc .STATICCALL [bc .NOT [litN 0], litN 1, litN m, litN 128, litN (m+64), litN 32]]) none s
      = .ok (s1, ⟨0⟩) := by
  have hstc : EvmYul.Yul.eval (fuel+31)
      (bc .STATICCALL [bc .NOT [litN 0], litN 1, litN m, litN 128, litN (m+64), litN 32]) none s
      = .ok (s1, ⟨1⟩) :=
    RelayLoopLiteral.eval_primcall (fuel+30) Operation.STATICCALL
      [bc .NOT [litN 0], litN 1, litN m, litN 128, litN (m+64), litN 32] s s s1
      [EvmYul.UInt256.lnot (UInt256.ofNat 0), UInt256.ofNat 1, UInt256.ofNat m,
       UInt256.ofNat 128, UInt256.ofNat (m+64), UInt256.ofNat 32] ⟨1⟩
      (hargs_staticcall fuel m s) hsc
  have h := eval_iszero (fuel+29)
      (bc .STATICCALL [bc .NOT [litN 0], litN 1, litN m, litN 128, litN (m+64), litN 32]) s s1 ⟨1⟩ hstc
  rw [show EvmYul.UInt256.isZero (⟨1⟩ : EvmYul.UInt256) = ⟨0⟩ from by decide] at h
  exact h

end SeamGuard

/-! ## The body chaining (`exec_Block_cons_ok` assembly)

The final assembly: peel `bodyL`'s statements one at a time with `exec_Block_cons_ok`, threading the
state through each atom. `body_prefix2` is the setup segment — `mstore(m+32,0); calldatacopy(m+63, …, 67)`
— and it pins down the technique for the whole body:
* **peel** with `exec_Block_cons_ok` (one statement, fuel `−1`);
* **fuel** literals are reconciled with `rw [show … from by omega]` so the block fuel matches each atom's
  `+k` output (`mstore_lit_eff` needs `+6`, `calldatacopy1_eff` `+31`, …);
* **state** is threaded as a `let`-bound term; the `setMachineState`/`setSharedState` vs `Ok` forms are
  bridged by definitional equality inside `exact`.
The remaining statements (the `Let`s, the eight guards via `exec_If_false` + the guard-condition evals,
the staticcall seam, and the accept `return`) extend this same `calc` by more steps. -/

open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral in
/-- **Setup segment.** Executing `bodyL`'s first two statements — clear the v-slot then copy the
    67-byte signature blob — lands on the v-slot clear→copy memory pattern (its `.memory` is
    `mstore_cdc_mem (m+32) (m+63) 67`), ready for the index/v/s reads. -/
theorem body_prefix2 (fuel m sigStart : Nat) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    let s1 := (EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0))
    EvmYul.Yul.exec (fuel + 40) (Stmt.Block
      [ Stmt.ExprStmtCall (bc .MSTORE [litN (m+32), litN 0]),
        Stmt.ExprStmtCall (bc .CALLDATACOPY [litN (m+63),
          bc .ADD [bc .ADD [litN sigStart, bc .MUL [V II, litN 67]], litN 2], litN 67]) ]) none
      (EvmYul.Yul.State.Ok ss vs)
    = .ok (s1.setSharedState (s1.toSharedState.calldatacopy (UInt256.ofNat (m+63))
                (EvmYul.UInt256.add (EvmYul.UInt256.add (UInt256.ofNat sigStart)
                  (EvmYul.UInt256.mul (s1[II]!) (UInt256.ofNat 67))) (UInt256.ofNat 2)) (UInt256.ofNat 67))) := by
  intro s1
  have h1 := RelayLoopLiteral.mstore_lit_eff (fuel+33) (EvmYul.Yul.State.Ok ss vs) (UInt256.ofNat (m+32)) (UInt256.ofNat 0)
  have h2 := RelayLoopLiteral.calldatacopy1_eff (fuel+7) m sigStart
              {ss with toMachineState := (EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0)} vs
  calc EvmYul.Yul.exec (fuel + 40) (Stmt.Block [_, _]) none (EvmYul.Yul.State.Ok ss vs)
      = EvmYul.Yul.exec ((fuel+33)+6) (Stmt.Block [_]) none s1 := by
        rw [show fuel + 40 = ((fuel+33)+6)+1 from by omega]
        exact RelayLoopLiteral.exec_Block_cons_ok ((fuel+33)+6) _ [_] _ s1 h1
    _ = EvmYul.Yul.exec ((fuel+7)+31) (Stmt.Block []) none _ := by
        rw [show (fuel+33)+6 = ((fuel+7)+31)+1 from by omega]
        exact RelayLoopLiteral.exec_Block_cons_ok ((fuel+7)+31) _ [] _ _ h2
    _ = _ := by
        rw [show (fuel+7)+31 = (fuel+37)+1 from by omega]
        exact RelayLoopLiteral.exec_Block_nil (fuel+37) _

open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral in
/-- **Setup + first read.** Extending `body_prefix2` by the third statement `let index := shr(240,
    mload(m+128))`, this chains three statements — the first *read* (a `Let` whose RHS `mload`s the
    just-copied blob) is now integrated into the block execution, threading the `mload`'s `activeWords`
    bump into the state. Demonstrates the chaining scales to reads; the full `body_effL` extends this
    same `calc` through the guards (via `exec_If_false` + the guard-condition evals), the seam, and the
    accounting `Let`s. -/
theorem body_prefix3 (fuel m sigStart : Nat) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    let s1 := (EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0))
    let s2 := s1.setSharedState (s1.toSharedState.calldatacopy (UInt256.ofNat (m+63))
                (EvmYul.UInt256.add (EvmYul.UInt256.add (UInt256.ofNat sigStart)
                  (EvmYul.UInt256.mul (s1[II]!) (UInt256.ofNat 67))) (UInt256.ofNat 2)) (UInt256.ofNat 67))
    let s3 := (s2.setMachineState (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).2).insert IDX
                (EvmYul.UInt256.shiftRight (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).1 (UInt256.ofNat 240))
    EvmYul.Yul.exec (fuel + 41) (Stmt.Block
      [ Stmt.ExprStmtCall (bc .MSTORE [litN (m+32), litN 0]),
        Stmt.ExprStmtCall (bc .CALLDATACOPY [litN (m+63),
          bc .ADD [bc .ADD [litN sigStart, bc .MUL [V II, litN 67]], litN 2], litN 67]),
        Stmt.Let [IDX] (some (bc .SHR [litN 240, bc .MLOAD [litN (m+128)]])) ]) none
      (EvmYul.Yul.State.Ok ss vs)
    = .ok s3 := by
  intro s1 s2 s3
  have h1 := RelayLoopLiteral.mstore_lit_eff (fuel+34) (EvmYul.Yul.State.Ok ss vs) (UInt256.ofNat (m+32)) (UInt256.ofNat 0)
  have h2 := RelayLoopLiteral.calldatacopy1_eff (fuel+8) m sigStart
              {ss with toMachineState := (EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0)} vs
  have h3 := RelayBodyEff.let_idx (fuel+32) (m+128) s2.toSharedState vs
  calc EvmYul.Yul.exec (fuel + 41) (Stmt.Block [_, _, _]) none (EvmYul.Yul.State.Ok ss vs)
      = EvmYul.Yul.exec ((fuel+34)+6) (Stmt.Block [_, _]) none s1 := by
        rw [show fuel + 41 = ((fuel+34)+6)+1 from by omega]
        exact RelayLoopLiteral.exec_Block_cons_ok ((fuel+34)+6) _ _ _ s1 h1
    _ = EvmYul.Yul.exec ((fuel+8)+31) (Stmt.Block [_]) none s2 := by
        rw [show (fuel+34)+6 = ((fuel+8)+31)+1 from by omega]
        exact RelayLoopLiteral.exec_Block_cons_ok ((fuel+8)+31) _ _ _ s2 h2
    _ = EvmYul.Yul.exec ((fuel+32)+6) (Stmt.Block []) none s3 := by
        rw [show (fuel+8)+31 = ((fuel+32)+6)+1 from by omega]
        exact RelayLoopLiteral.exec_Block_cons_ok ((fuel+32)+6) _ [] _ s3 h3
    _ = _ := by rw [show (fuel+32)+6 = (fuel+37)+1 from by omega]; exact RelayLoopLiteral.exec_Block_nil _ _

open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral in
/-- **Setup + first read + first two guards.** Extending `body_prefix3` by the range and order guards
    (statements 4–5), this chains five statements *including guards*. Each guard `if cond {revert}` is
    peeled with `exec_If_false` under a "guard passes" hypothesis (`eval cond s3 = (s3, ⟨0⟩)`, discharged
    separately by `eval_range_cond`/`eval_order_cond` + the ValidRun conditions). This proves the last
    chaining pattern — guards in the block — composes; the full `body_effL` extends this same `calc`
    through the remaining statements (Lets, the mload-guards, the seam, the accept). -/
theorem body_prefix5 (fuel m sigStart : Nat) (nVot : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    let s1 := (EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0))
    let s2 := s1.setSharedState (s1.toSharedState.calldatacopy (UInt256.ofNat (m+63))
                (EvmYul.UInt256.add (EvmYul.UInt256.add (UInt256.ofNat sigStart)
                  (EvmYul.UInt256.mul (s1[II]!) (UInt256.ofNat 67))) (UInt256.ofNat 2)) (UInt256.ofNat 67))
    let s3 := (s2.setMachineState (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).2).insert IDX
                (EvmYul.UInt256.shiftRight (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).1 (UInt256.ofNat 240))
    EvmYul.Yul.eval (fuel+38) (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]) none s3 = .ok (s3, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+37) (bc .LT [V IDX, V NUI]) none s3 = .ok (s3, ⟨0⟩) →
    EvmYul.Yul.exec (fuel + 43) (Stmt.Block
      [ Stmt.ExprStmtCall (bc .MSTORE [litN (m+32), litN 0]),
        Stmt.ExprStmtCall (bc .CALLDATACOPY [litN (m+63),
          bc .ADD [bc .ADD [litN sigStart, bc .MUL [V II, litN 67]], litN 2], litN 67]),
        Stmt.Let [IDX] (some (bc .SHR [litN 240, bc .MLOAD [litN (m+128)]])),
        guard' (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]),
        guard' (bc .LT [V IDX, V NUI]) ]) none
      (EvmYul.Yul.State.Ok ss vs)
    = .ok s3 := by
  intro s1 s2 s3 hg4 hg5
  have h1 := RelayLoopLiteral.mstore_lit_eff (fuel+36) (EvmYul.Yul.State.Ok ss vs) (UInt256.ofNat (m+32)) (UInt256.ofNat 0)
  have h2 := RelayLoopLiteral.calldatacopy1_eff (fuel+10) m sigStart
              {ss with toMachineState := (EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0)} vs
  have h3 := RelayBodyEff.let_idx (fuel+34) (m+128) s2.toSharedState vs
  have h4 := RelayLoopLiteral.exec_If_false (fuel+38) (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]) [revert00] s3 s3 hg4
  have h5 := RelayLoopLiteral.exec_If_false (fuel+37) (bc .LT [V IDX, V NUI]) [revert00] s3 s3 hg5
  calc EvmYul.Yul.exec (fuel + 43) (Stmt.Block [_, _, _, _, _]) none (EvmYul.Yul.State.Ok ss vs)
      = EvmYul.Yul.exec ((fuel+36)+6) (Stmt.Block [_, _, _, _]) none s1 := by
        rw [show fuel + 43 = ((fuel+36)+6)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s1 h1
    _ = EvmYul.Yul.exec ((fuel+10)+31) (Stmt.Block [_, _, _]) none s2 := by
        rw [show (fuel+36)+6 = ((fuel+10)+31)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s2 h2
    _ = EvmYul.Yul.exec ((fuel+34)+6) (Stmt.Block [_, _]) none s3 := by
        rw [show (fuel+10)+31 = ((fuel+34)+6)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s3 h3
    _ = EvmYul.Yul.exec ((fuel+38)+1) (Stmt.Block [_]) none s3 := by
        rw [show (fuel+34)+6 = ((fuel+38)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s3 h4
    _ = EvmYul.Yul.exec ((fuel+37)+1) (Stmt.Block []) none s3 := by
        rw [show (fuel+38)+1 = ((fuel+37)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ [] _ s3 h5
    _ = _ := RelayLoopLiteral.exec_Block_nil (fuel+37) _

open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral in
/-- **Through the first nine statements.** Extends `body_prefix5` by `let nextUnusedIndex`, `let v`, the
    bad-`v` guard, and the bad-`s` guard — over half the body, now including a *state-changing* mload
    guard (`gt(mload(m+96), SECP_HALF)` bumps `activeWords`, threading `s7 → s9`). Every peel kind the
    body needs is exercised; the full `body_effL` extends this same `calc` by the seam guard, the
    returndatasize/zero-signer guards, the second clear→copy, the wrong-sig guard, `let weight`, and the
    accept `If`. Guard passes are arrow hypotheses (discharged by the `eval_*_cond` lemmas). -/
theorem body_prefix9 (fuel m sigStart : Nat) (nVot sHalf : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    let s1 := (EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0))
    let s2 := s1.setSharedState (s1.toSharedState.calldatacopy (UInt256.ofNat (m+63))
                (EvmYul.UInt256.add (EvmYul.UInt256.add (UInt256.ofNat sigStart)
                  (EvmYul.UInt256.mul (s1[II]!) (UInt256.ofNat 67))) (UInt256.ofNat 2)) (UInt256.ofNat 67))
    let s3 := (s2.setMachineState (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).2).insert IDX
                (EvmYul.UInt256.shiftRight (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).1 (UInt256.ofNat 240))
    let s6 := s3.insert NUI (EvmYul.UInt256.add (s3[IDX]!) (UInt256.ofNat 1))
    let s7 := (s6.setMachineState (s6.toSharedState.toMachineState.mload (UInt256.ofNat (m+32))).2).insert VV
                (EvmYul.UInt256.land (s6.toSharedState.toMachineState.mload (UInt256.ofNat (m+32))).1 (UInt256.ofNat 0xff))
    let s9 := s7.setMachineState (s7.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).2
    EvmYul.Yul.eval (fuel+55) (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]) none s3 = .ok (s3, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+54) (bc .LT [V IDX, V NUI]) none s3 = .ok (s3, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+51) (bc .ISZERO [bc .OR [bc .EQ [V VV, litN 27], bc .EQ [V VV, litN 28]]]) none s7 = .ok (s7, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+50) (bc .GT [bc .MLOAD [litN (m+96)], litU sHalf]) none s7 = .ok (s9, ⟨0⟩) →
    EvmYul.Yul.exec (fuel + 60) (Stmt.Block
      [ Stmt.ExprStmtCall (bc .MSTORE [litN (m+32), litN 0]),
        Stmt.ExprStmtCall (bc .CALLDATACOPY [litN (m+63),
          bc .ADD [bc .ADD [litN sigStart, bc .MUL [V II, litN 67]], litN 2], litN 67]),
        Stmt.Let [IDX] (some (bc .SHR [litN 240, bc .MLOAD [litN (m+128)]])),
        guard' (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]),
        guard' (bc .LT [V IDX, V NUI]),
        Stmt.Let [NUI] (some (bc .ADD [V IDX, litN 1])),
        Stmt.Let [VV] (some (bc .AND [bc .MLOAD [litN (m+32)], litN 0xff])),
        guard' (bc .ISZERO [bc .OR [bc .EQ [V VV, litN 27], bc .EQ [V VV, litN 28]]]),
        guard' (bc .GT [bc .MLOAD [litN (m+96)], litU sHalf]) ]) none
      (EvmYul.Yul.State.Ok ss vs)
    = .ok s9 := by
  intro s1 s2 s3 s6 s7 s9 hg4 hg5 hg8 hg9
  have h1 := RelayLoopLiteral.mstore_lit_eff (fuel+53) (EvmYul.Yul.State.Ok ss vs) (UInt256.ofNat (m+32)) (UInt256.ofNat 0)
  have h2 := RelayLoopLiteral.calldatacopy1_eff (fuel+27) m sigStart
              {ss with toMachineState := (EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0)} vs
  have h3 := RelayBodyEff.let_idx (fuel+51) (m+128) s2.toSharedState vs
  have h4 := RelayLoopLiteral.exec_If_false (fuel+55) (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]) [revert00] s3 s3 hg4
  have h5 := RelayLoopLiteral.exec_If_false (fuel+54) (bc .LT [V IDX, V NUI]) [revert00] s3 s3 hg5
  have h6 := RelayBodyEff.let_nui (fuel+47) s3.toSharedState s3.store
  have h7 := RelayBodyEff.let_vv (fuel+45) (m+32) (UInt256.ofNat 0xff) s6.toSharedState s6.store
  have h8 := RelayLoopLiteral.exec_If_false (fuel+51) (bc .ISZERO [bc .OR [bc .EQ [V VV, litN 27], bc .EQ [V VV, litN 28]]]) [revert00] s7 s7 hg8
  have h9 := RelayLoopLiteral.exec_If_false (fuel+50) (bc .GT [bc .MLOAD [litN (m+96)], litU sHalf]) [revert00] s7 s9 hg9
  calc EvmYul.Yul.exec (fuel + 60) (Stmt.Block [_, _, _, _, _, _, _, _, _]) none (EvmYul.Yul.State.Ok ss vs)
      = EvmYul.Yul.exec ((fuel+53)+6) (Stmt.Block [_,_,_,_,_,_,_,_]) none s1 := by
        rw [show fuel + 60 = ((fuel+53)+6)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s1 h1
    _ = EvmYul.Yul.exec ((fuel+27)+31) (Stmt.Block [_,_,_,_,_,_,_]) none s2 := by
        rw [show (fuel+53)+6 = ((fuel+27)+31)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s2 h2
    _ = EvmYul.Yul.exec ((fuel+51)+6) (Stmt.Block [_,_,_,_,_,_]) none s3 := by
        rw [show (fuel+27)+31 = ((fuel+51)+6)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s3 h3
    _ = EvmYul.Yul.exec ((fuel+55)+1) (Stmt.Block [_,_,_,_,_]) none s3 := by
        rw [show (fuel+51)+6 = ((fuel+55)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s3 h4
    _ = EvmYul.Yul.exec ((fuel+54)+1) (Stmt.Block [_,_,_,_]) none s3 := by
        rw [show (fuel+55)+1 = ((fuel+54)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s3 h5
    _ = EvmYul.Yul.exec ((fuel+47)+7) (Stmt.Block [_,_,_]) none s6 := by
        rw [show (fuel+54)+1 = ((fuel+47)+7)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s6 h6
    _ = EvmYul.Yul.exec ((fuel+45)+8) (Stmt.Block [_,_]) none s7 := by
        rw [show (fuel+47)+7 = ((fuel+45)+8)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s7 h7
    _ = EvmYul.Yul.exec ((fuel+51)+1) (Stmt.Block [_]) none s7 := by
        rw [show (fuel+45)+8 = ((fuel+51)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s7 h8
    _ = EvmYul.Yul.exec ((fuel+50)+1) (Stmt.Block []) none s9 := by
        rw [show (fuel+51)+1 = ((fuel+50)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ [] _ s9 h9
    _ = _ := RelayLoopLiteral.exec_Block_nil (fuel+50) _

open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral in
set_option maxHeartbeats 4000000 in
/-- **Full literal loop-body effect (brick 36).** Chains all seventeen statements of the
    deployed signature-verification loop body `bodyL` (transliterated from
    `relay_ir_optimized.yul:1563-1610`) through the EVMYulLean interpreter's real
    `exec`/`eval` semantics, threading genuine `mstore`/`mload`/`calldatacopy` state
    changes. Given the nine guard-condition pass hypotheses (`hg4..hg17`, one per `if`
    that must NOT revert on the advance path) and the two staticcall-produced states
    (`ss10/vs10` after the ecrecover call, `ss15/vs15` after the recovered-address
    check), the block executes to the accumulator-advanced state `s16`, where
    `s16[WW]! = s15[WW]! + (mload(m+96) & 0xffff)` — the running signing-weight sum plus
    this voter's weight. This is the literal counterpart of `RelayLoopMemRead.body_effM`;
    unlike that model it does not ASSUME memory reads are state-preserving but derives the
    full state evolution. Fuel `fuel+130` = 17 peels + interpreter overhead. -/
theorem body_effL (fuel m sigStart : Nat) (nVot thr : EvmYul.UInt256)
    (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore)
    (ss10 : EvmYul.SharedState .Yul) (vs10 : EvmYul.Yul.VarStore) (ss15 : EvmYul.SharedState .Yul) (vs15 : EvmYul.Yul.VarStore) :
    let s1 := (EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0))
    let s2 := s1.setSharedState (s1.toSharedState.calldatacopy (UInt256.ofNat (m+63))
                (EvmYul.UInt256.add (EvmYul.UInt256.add (UInt256.ofNat sigStart)
                  (EvmYul.UInt256.mul (s1[II]!) (UInt256.ofNat 67))) (UInt256.ofNat 2)) (UInt256.ofNat 67))
    let s3 := (s2.setMachineState (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).2).insert IDX
                (EvmYul.UInt256.shiftRight (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).1 (UInt256.ofNat 240))
    let s6 := s3.insert NUI (EvmYul.UInt256.add (s3[IDX]!) (UInt256.ofNat 1))
    let s7 := (s6.setMachineState (s6.toSharedState.toMachineState.mload (UInt256.ofNat (m+32))).2).insert VV
                (EvmYul.UInt256.land (s6.toSharedState.toMachineState.mload (UInt256.ofNat (m+32))).1 (UInt256.ofNat 0xff))
    let s9 := s7.setMachineState (s7.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).2
    let s10 := EvmYul.Yul.State.Ok ss10 vs10
    let s15 := EvmYul.Yul.State.Ok ss15 vs15
    let s12 := s10.setMachineState (s10.toSharedState.toMachineState.mload (UInt256.ofNat (m+64))).2
    let s13 := s12.setMachineState (s12.toMachineState.mstore (UInt256.ofNat (m+96)) (UInt256.ofNat 0))
    let s14 := s13.setSharedState (s13.toSharedState.calldatacopy (UInt256.ofNat (m+106))
                 (EvmYul.UInt256.add (UInt256.ofNat 47) (EvmYul.UInt256.mul (s13[IDX]!) (UInt256.ofNat 22))) (UInt256.ofNat 22))
    let s16 := (s15.setMachineState (s15.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).2).insert WW
                 (EvmYul.UInt256.add (s15[WW]!) (EvmYul.UInt256.land (s15.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).1 (UInt256.ofNat 65535)))
    EvmYul.Yul.eval (fuel+125) (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]) none s3 = .ok (s3, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+124) (bc .LT [V IDX, V NUI]) none s3 = .ok (s3, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+121) (bc .ISZERO [bc .OR [bc .EQ [V VV, litN 27], bc .EQ [V VV, litN 28]]]) none s7 = .ok (s7, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+120) (bc .GT [bc .MLOAD [litN (m+96)], litU SECP_HALF]) none s7 = .ok (s9, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+119) (bc .ISZERO [bc .STATICCALL [bc .NOT [litN 0], litN 1, litN m, litN 128, litN (m+64), litN 32]]) none s9 = .ok (s10, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+118) (bc .ISZERO [bc .EQ [bc .RETURNDATASIZE [], litN 32]]) none s10 = .ok (s10, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+117) (bc .ISZERO [bc .MLOAD [litN (m+64)]]) none s10 = .ok (s12, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+114) (bc .ISZERO [bc .EQ [bc .MLOAD [litN (m+64)], bc .SHR [litN 16, bc .MLOAD [litN (m+96)]]]]) none s14 = .ok (s15, ⟨0⟩) →
    EvmYul.Yul.eval (fuel+112) (bc .GT [V WW, litU thr]) none s16 = .ok (s16, ⟨0⟩) →
    EvmYul.Yul.exec (fuel + 130) (Stmt.Block (bodyL m sigStart nVot thr)) none (EvmYul.Yul.State.Ok ss vs)
    = .ok s16 := by
  intro s1 s2 s3 s6 s7 s9 s10 s15 s12 s13 s14 s16 hg4 hg5 hg8 hg9 hg10 hg11 hg12 hg15 hg17
  unfold RelayLoopLiteral.bodyL
  have h1 := RelayLoopLiteral.mstore_lit_eff (fuel+123) (EvmYul.Yul.State.Ok ss vs) (UInt256.ofNat (m+32)) (UInt256.ofNat 0)
  have h2 := RelayLoopLiteral.calldatacopy1_eff (fuel+97) m sigStart
              {ss with toMachineState := (EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0)} vs
  have h3 := RelayBodyEff.let_idx (fuel+121) (m+128) s2.toSharedState vs
  have h4 := RelayLoopLiteral.exec_If_false (fuel+125) (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]) [revert00] s3 s3 hg4
  have h5 := RelayLoopLiteral.exec_If_false (fuel+124) (bc .LT [V IDX, V NUI]) [revert00] s3 s3 hg5
  have h6 := RelayBodyEff.let_nui (fuel+117) s3.toSharedState s3.store
  have h7 := RelayBodyEff.let_vv (fuel+115) (m+32) (UInt256.ofNat 0xff) s6.toSharedState s6.store
  have h8 := RelayLoopLiteral.exec_If_false (fuel+121) (bc .ISZERO [bc .OR [bc .EQ [V VV, litN 27], bc .EQ [V VV, litN 28]]]) [revert00] s7 s7 hg8
  have h9 := RelayLoopLiteral.exec_If_false (fuel+120) (bc .GT [bc .MLOAD [litN (m+96)], litU SECP_HALF]) [revert00] s7 s9 hg9
  have h10 := RelayLoopLiteral.exec_If_false (fuel+119) (bc .ISZERO [bc .STATICCALL [bc .NOT [litN 0], litN 1, litN m, litN 128, litN (m+64), litN 32]]) [revert00] s9 s10 hg10
  have h11 := RelayLoopLiteral.exec_If_false (fuel+118) (bc .ISZERO [bc .EQ [bc .RETURNDATASIZE [], litN 32]]) [revert00] s10 s10 hg11
  have h12 := RelayLoopLiteral.exec_If_false (fuel+117) (bc .ISZERO [bc .MLOAD [litN (m+64)]]) [revert00] s10 s12 hg12
  have h13 := RelayLoopLiteral.mstore_lit_eff (fuel+111) s12 (UInt256.ofNat (m+96)) (UInt256.ofNat 0)
  have h14 := RelayLoopLiteral.calldatacopy2_eff (fuel+85) m s13.toSharedState s13.store
  have h15 := RelayLoopLiteral.exec_If_false (fuel+114) (bc .ISZERO [bc .EQ [bc .MLOAD [litN (m+64)], bc .SHR [litN 16, bc .MLOAD [litN (m+96)]]]]) [revert00] s14 s15 hg15
  have h16 := RelayBodyEff.let_ww (fuel+104) (m+96) (UInt256.ofNat 65535) s15.toSharedState s15.store
  have h17 := RelayLoopLiteral.exec_If_false (fuel+112) (bc .GT [V WW, litU thr]) [Stmt.ExprStmtCall (bc .RETURN [litN 0, litN 0])] s16 s16 hg17
  calc EvmYul.Yul.exec (fuel + 130) (Stmt.Block [_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_]) none (EvmYul.Yul.State.Ok ss vs)
      = EvmYul.Yul.exec ((fuel+123)+6) (Stmt.Block _) none s1 := by rw [show fuel + 130 = ((fuel+123)+6)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s1 h1
    _ = EvmYul.Yul.exec ((fuel+97)+31) (Stmt.Block _) none s2 := by rw [show (fuel+123)+6 = ((fuel+97)+31)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s2 h2
    _ = EvmYul.Yul.exec ((fuel+121)+6) (Stmt.Block _) none s3 := by rw [show (fuel+97)+31 = ((fuel+121)+6)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s3 h3
    _ = EvmYul.Yul.exec ((fuel+125)+1) (Stmt.Block _) none s3 := by rw [show (fuel+121)+6 = ((fuel+125)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s3 h4
    _ = EvmYul.Yul.exec ((fuel+124)+1) (Stmt.Block _) none s3 := by rw [show (fuel+125)+1 = ((fuel+124)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s3 h5
    _ = EvmYul.Yul.exec ((fuel+117)+7) (Stmt.Block _) none s6 := by rw [show (fuel+124)+1 = ((fuel+117)+7)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s6 h6
    _ = EvmYul.Yul.exec ((fuel+115)+8) (Stmt.Block _) none s7 := by rw [show (fuel+117)+7 = ((fuel+115)+8)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s7 h7
    _ = EvmYul.Yul.exec ((fuel+121)+1) (Stmt.Block _) none s7 := by rw [show (fuel+115)+8 = ((fuel+121)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s7 h8
    _ = EvmYul.Yul.exec ((fuel+120)+1) (Stmt.Block _) none s9 := by rw [show (fuel+121)+1 = ((fuel+120)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s9 h9
    _ = EvmYul.Yul.exec ((fuel+119)+1) (Stmt.Block _) none s10 := by rw [show (fuel+120)+1 = ((fuel+119)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s10 h10
    _ = EvmYul.Yul.exec ((fuel+118)+1) (Stmt.Block _) none s10 := by rw [show (fuel+119)+1 = ((fuel+118)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s10 h11
    _ = EvmYul.Yul.exec ((fuel+117)+1) (Stmt.Block _) none s12 := by rw [show (fuel+118)+1 = ((fuel+117)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s12 h12
    _ = EvmYul.Yul.exec ((fuel+111)+6) (Stmt.Block _) none s13 := by rw [show (fuel+117)+1 = ((fuel+111)+6)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s13 h13
    _ = EvmYul.Yul.exec ((fuel+85)+31) (Stmt.Block _) none s14 := by rw [show (fuel+111)+6 = ((fuel+85)+31)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s14 h14
    _ = EvmYul.Yul.exec ((fuel+114)+1) (Stmt.Block _) none s15 := by rw [show (fuel+85)+31 = ((fuel+114)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s15 h15
    _ = EvmYul.Yul.exec ((fuel+104)+10) (Stmt.Block _) none s16 := by rw [show (fuel+114)+1 = ((fuel+104)+10)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ _ _ s16 h16
    _ = EvmYul.Yul.exec ((fuel+112)+1) (Stmt.Block []) none s16 := by rw [show (fuel+104)+10 = ((fuel+112)+1)+1 from by omega]; exact RelayLoopLiteral.exec_Block_cons_ok _ _ [] _ s16 h17
    _ = _ := RelayLoopLiteral.exec_Block_nil (fuel+112) _

/-! ## The literal signature loop — induction over `body_effL` (bricks 37)

Generic `For`/`loop` control-flow bricks (ported from `RelayLoopMemRead`), the loop-condition and
post-statement effects for the *literal* loop (`condL`/`postL`), and the induction `loop_accL` that
drives the deployed `For (condL nSig) postL bodyL` through all iterations, threading the evolving
shared state (memory) that the literal body mutates — carrying a clean per-iteration body-advance
`hstep` (the contract `body_effL` fulfils). Unlike `RelayLoopMemRead.loop_accM` (constant memory,
abstract 2-statement body) this threads the real 17-statement body's state evolution. -/
section LoopLayer
open EvmYul.Yul EvmYul.Yul.Ast RelayLoopLiteral

-- ===================== ported generic bricks =====================
theorem exec_For (fuel : Nat) (c : Expr) (po bo : List Stmt) (s : EvmYul.Yul.State) :
    EvmYul.Yul.exec (fuel + 1) (Stmt.For c po bo) none s = EvmYul.Yul.loop fuel c po bo none s := by
  unfold EvmYul.Yul.exec; rfl

theorem loop_base (fuel : Nat) (c : Expr) (po bo : List Stmt) (s s₁ : EvmYul.Yul.State)
    (hc : EvmYul.Yul.eval fuel c none (EvmYul.Yul.State.mkOk s) = .ok (s₁, ⟨0⟩)) :
    EvmYul.Yul.loop (fuel + 1 + 1) c po bo none s = .ok (EvmYul.Yul.State.overwrite? s₁ s) := by
  unfold EvmYul.Yul.loop; simp only [hc]; rfl

theorem loop_step (fuel : Nat) (c : Expr) (po bo : List Stmt)
    (sa : EvmYul.SharedState .Yul) (va : EvmYul.Yul.VarStore) (s₃ : EvmYul.Yul.State)
    (sb : EvmYul.SharedState .Yul) (vb : EvmYul.Yul.VarStore) (x : EvmYul.UInt256)
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

theorem ofNat_succ (a : Nat) : UInt256.ofNat (a + 1) = UInt256.add (UInt256.ofNat a) (UInt256.ofNat 1) := by
  unfold UInt256.ofNat UInt256.add; simp only [Id.run]; congr 1; apply Fin.ext
  show (a + 1) % UInt256.size = ((a % UInt256.size) + (1 % UInt256.size)) % UInt256.size
  rw [Nat.add_mod]

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

theorem IW : II ≠ WW := by decide

set_option maxHeartbeats 4000000 in
theorem cond_effL (f : Nat) (n : EvmYul.UInt256) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.eval (f + 6) (condL n) none (EvmYul.Yul.State.Ok ss vs)
    = .ok (EvmYul.Yul.State.Ok ss vs, EvmYul.UInt256.lt ((EvmYul.Yul.State.Ok ss vs)[II]!) n) := by
  simp [condL, bc, V, litU, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.evalPrimCall, EvmYul.Yul.primCall, EvmYul.Yul.head', EvmYul.Yul.cons',
        EvmYul.Yul.reverse', RelayLoopLiteral.step_LT]

set_option maxHeartbeats 4000000 in
theorem post_effL (f : Nat) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore) :
    EvmYul.Yul.exec (f + 8) (Stmt.Block postL) none (EvmYul.Yul.State.Ok ss vs)
      = .ok ((EvmYul.Yul.State.Ok ss vs).insert II
              (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[II]!) (UInt256.ofNat 1))) := by
  have hlet : EvmYul.Yul.exec (f + 7) (Stmt.Let [II] (some (bc .ADD [V II, litN 1]))) none (EvmYul.Yul.State.Ok ss vs)
      = .ok ((EvmYul.Yul.State.Ok ss vs).insert II
              (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss vs)[II]!) (UInt256.ofNat 1))) :=
    RelayLoopLiteral.let_prim_eff (f+6) II Operation.ADD [V II, litN 1]
      (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
      [(EvmYul.Yul.State.Ok ss vs)[II]!, UInt256.ofNat 1] _
      (RelayLoopLiteral.evalArgs_rev_pair (f+1) (V II) (litN 1)
        (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs) (EvmYul.Yul.State.Ok ss vs)
        ((EvmYul.Yul.State.Ok ss vs)[II]!) (UInt256.ofNat 1)
        (RelayLoopLiteral.eval_lit (f+4) (UInt256.ofNat 1) _) (RelayLoopLiteral.eval_var (f+2) II _))
      (RelayBodyEff.primCall_ADD' (f+5) _ _ _)
  calc EvmYul.Yul.exec (f + 8) (Stmt.Block postL) none (EvmYul.Yul.State.Ok ss vs)
      = EvmYul.Yul.exec (f+7) (Stmt.Block []) none _ := by
        rw [show f + 8 = (f+7)+1 from by omega]
        exact RelayLoopLiteral.exec_Block_cons_ok (f+7) _ [] _ _ hlet
    _ = _ := by rw [show f+7 = (f+6)+1 from by omega]; exact RelayLoopLiteral.exec_Block_nil (f+6) _

-- ===================== THE LITERAL LOOP INDUCTION =====================
set_option maxHeartbeats 4000000 in
/-- **Literal loop accumulation.** Drives the deployed signature loop `For (condL nSig) postL bodyL`
    through `NN` iterations, given a per-iteration body-advance `hstep` (exactly the shape
    `RelayBodyEff.body_effL` delivers once the guard/ecrecover context is supplied): one turn of
    `bodyL` preserves the counter `i` and advances the accumulator `weight` from `acc k` to `acc (k+1)`.
    Concludes the loop lands in some `Ok`-state whose `weight` is `acc NN`. Fuel `3·j + 140`: 3 per
    iteration for the `For`/`loop`/dispatch plumbing, base ≥ 130 so `body_effL` fits. -/
theorem loop_accL (NN : Nat) (hN : NN < UInt256.size)
    (m sigStart : Nat) (nVot thr : EvmYul.UInt256)
    (acc : Nat → EvmYul.UInt256)
    (hstep : ∀ (k : Nat) (ssk : EvmYul.SharedState .Yul) (vsk : EvmYul.Yul.VarStore),
        k < NN →
        (EvmYul.Yul.State.Ok ssk vsk)[II]! = UInt256.ofNat k →
        (EvmYul.Yul.State.Ok ssk vsk)[WW]! = acc k →
        ∃ (ssk' : EvmYul.SharedState .Yul) (vsk' : EvmYul.Yul.VarStore),
          (∀ fuel, EvmYul.Yul.exec (fuel+130) (Stmt.Block (bodyL m sigStart nVot thr)) none
              (EvmYul.Yul.State.Ok ssk vsk) = .ok (EvmYul.Yul.State.Ok ssk' vsk')) ∧
          (EvmYul.Yul.State.Ok ssk' vsk')[II]! = UInt256.ofNat k ∧
          (EvmYul.Yul.State.Ok ssk' vsk')[WW]! = acc (k+1)) :
    ∀ (j a : Nat) (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore),
      a + j = NN →
      (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat a →
      (EvmYul.Yul.State.Ok ss vs)[WW]! = acc a →
      ∃ (ss' : EvmYul.SharedState .Yul) (vs' : EvmYul.Yul.VarStore),
        EvmYul.Yul.exec (3 * j + 140) (Stmt.For (condL (UInt256.ofNat NN)) postL (bodyL m sigStart nVot thr)) none
            (EvmYul.Yul.State.Ok ss vs)
          = .ok (EvmYul.Yul.State.Ok ss' vs') ∧
        (EvmYul.Yul.State.Ok ss' vs')[WW]! = acc NN := by
  intro j
  induction j with
  | zero =>
    intro a ss vs hsum hi hw
    have ha : a = NN := by omega
    refine ⟨ss, vs, ?_, by rw [hw, ha]⟩
    have hc : EvmYul.Yul.eval 137 (condL (UInt256.ofNat NN)) none (EvmYul.Yul.State.mkOk (EvmYul.Yul.State.Ok ss vs))
                = .ok (EvmYul.Yul.State.Ok ss vs, ⟨0⟩) := by
      have := cond_effL 131 (UInt256.ofNat NN) ss vs
      simp only [EvmYul.Yul.State.mkOk]
      rw [show (137 : Nat) = 131 + 6 from rfl, this, hi, ha, lt_self]
    rw [show (3 * 0 + 140) = 137 + 1 + 1 + 1 from rfl, exec_For, loop_base (fuel := 137) (hc := hc)]
    simp [EvmYul.Yul.State.overwrite?]
  | succ j ih =>
    intro a ss vs hsum hi hw
    have haN : a < NN := by omega
    have ha_sz : a < UInt256.size := by omega
    have hc : EvmYul.Yul.eval (3 * j + 140) (condL (UInt256.ofNat NN)) none (EvmYul.Yul.State.Ok ss vs)
                = .ok (EvmYul.Yul.State.Ok ss vs, UInt256.lt (UInt256.ofNat a) (UInt256.ofNat NN)) := by
      have := cond_effL (3 * j + 134) (UInt256.ofNat NN) ss vs
      rw [show (3 * j + 140) = (3 * j + 134) + 6 from by ring, this, hi]
    have hx : UInt256.lt (UInt256.ofNat a) (UInt256.ofNat NN) ≠ ⟨0⟩ := by
      rw [ne_eq, lt_eq_zero_iff, not_not]; exact (ofNat_lt ha_sz hN).mpr haN
    obtain ⟨ssb, vsb, hbody_all, hib, hwb⟩ := hstep a ss vs haN hi hw
    have hb : EvmYul.Yul.exec (3 * j + 140) (Stmt.Block (bodyL m sigStart nVot thr)) none
                (EvmYul.Yul.State.Ok ss vs) = .ok (EvmYul.Yul.State.Ok ssb vsb) := by
      have := hbody_all (3 * j + 10); rwa [show (3 * j + 10) + 130 = 3 * j + 140 from by ring] at this
    have hp := post_effL (3 * j + 132) ssb vsb
    rw [show (3 * j + 132) + 8 = 3 * j + 140 from by ring, hib] at hp
    have hstep' := loop_step (fuel := 3 * j + 140) (c := condL (UInt256.ofNat NN)) (po := postL)
                    (bo := bodyL m sigStart nVot thr)
                    (sa := ss) (va := vs) (sb := ssb) (vb := vsb)
                    (hc := hc) (hx := hx) (hb := hb) (hp := hp)
    rw [show (3 * (j + 1) + 140) = (3 * j + 140) + 1 + 1 + 1 from by ring, exec_For, hstep']
    have hic : (EvmYul.Yul.State.Ok ssb (vsb.insert II (UInt256.add (UInt256.ofNat a) (UInt256.ofNat 1))))[II]!
                 = UInt256.ofNat (a + 1) := by rw [ge_self]; exact (ofNat_succ a).symm
    have hwc : (EvmYul.Yul.State.Ok ssb (vsb.insert II (UInt256.add (UInt256.ofNat a) (UInt256.ofNat 1))))[WW]!
                 = acc (a + 1) := by rw [ge_ne ssb vsb II WW _ (Ne.symm IW), hwb]
    obtain ⟨ss', vs', hexec, hWW⟩ := ih (a + 1) ssb (vsb.insert II (UInt256.add (UInt256.ofNat a) (UInt256.ofNat 1)))
      (by omega) hic hwc
    exact ⟨ss', vs', hexec, hWW⟩


-- ===================== THE LITERAL CAPSTONE (brick 38) =====================
-- Accumulator bridge (accNat = sigLoop weight) + relay_loop_sound_literal: the literal analog of
-- RelayLoopMemRead.relay_loop_sound, composed from loop_accL (real 17-statement body) + threshold_sound.
/-- Selected voter indices: signature `k` (of `nSig`) selects voter `sigIdxAt cd sigStart k`. -/
def idxSel (cd : ByteArray) (sigStart nSig : Nat) : List Nat :=
  (List.range nSig).map (sigIdxAt cd sigStart)

/-- ℕ partial accumulator: sum of the first `k` selected voters' registered weights. -/
def accNat (cd : ByteArray) (sigStart nVot : Nat) : Nat → Nat
  | 0     => 0
  | k + 1 => accNat cd sigStart nVot k + (weightsOf cd nVot).getD (sigIdxAt cd sigStart k) 0

theorem idxSel_length (cd : ByteArray) (sigStart nSig : Nat) : (idxSel cd sigStart nSig).length = nSig := by
  simp [idxSel]

/-- `sigLoop` over an append threads its state through the first list, then the second. -/
theorem sigLoop_append (w : List Nat) (l1 l2 : List Nat) : ∀ (wt nui : Nat),
    sigLoop w wt nui (l1 ++ l2)
      = sigLoop w (sigLoop w wt nui l1).1 (sigLoop w wt nui l1).2 l2 := by
  induction l1 with
  | nil => intro wt nui; rfl
  | cons x xs ih => intro wt nui; simp only [List.cons_append, sigLoop]; exact ih _ _

/-- **Accumulator bridge.** The ℕ partial accumulator equals the abstract `sigLoop` accumulated weight
    over the selected-index list. -/
theorem accNat_eq_sigLoop (cd : ByteArray) (sigStart nVot NN : Nat) :
    accNat cd sigStart nVot NN
      = (sigLoop (weightsOf cd nVot) 0 0 (idxSel cd sigStart NN)).1 := by
  induction NN with
  | zero => rfl
  | succ n ih =>
    have hrange : idxSel cd sigStart (n + 1)
        = idxSel cd sigStart n ++ [sigIdxAt cd sigStart n] := by
      simp [idxSel, List.range_succ, List.map_append]
    rw [accNat, ih, hrange, sigLoop_append]
    simp [sigLoop]

theorem val_ofNat_of_lt (n : Nat) (h : n < UInt256.size) : (UInt256.ofNat n).val = n := by
  show (UInt256.ofNat n).val = n
  unfold UInt256.ofNat; simp only [Id.run]
  show n % UInt256.size = n
  exact Nat.mod_eq_of_lt h

-- ===================== accounting extraction (brick 39) =====================
-- The accounting half of the per-iteration `hstep`: body_effL's output state s16 carries exactly the
-- advanced accumulator (weight += selected voter's registered weight, via mload_masked_voter = hcorr)
-- and preserves the loop counter i. Machine-checks that the literal body computes the right tally.
theorem ofNat_add (x y : Nat) :
    UInt256.add (UInt256.ofNat x) (UInt256.ofNat y) = UInt256.ofNat (x + y) := by
  unfold UInt256.add UInt256.ofNat; simp only [Id.run]; congr 1; apply Fin.ext
  simp [Fin.val_add, Fin.val_ofNat, Nat.add_mod]

-- Extraction helpers: read a just-inserted / an untouched key through a `setMachineState` wrapper.
-- Stated with an ABSTRACT machine-state `M` so applying them never forces `whnf` on the (large) mload term.
theorem ins_setMS_self (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore)
    (M : EvmYul.MachineState) (k : EvmYul.Identifier) (v : EvmYul.UInt256) :
    (((EvmYul.Yul.State.Ok ss vs).setMachineState M).insert k v)[k]! = v :=
  RelayLoopLiteral.ge_self _ _ k v

theorem ins_setMS_ne (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore)
    (M : EvmYul.MachineState) (k j : EvmYul.Identifier) (v : EvmYul.UInt256) (h : j ≠ k) :
    (((EvmYul.Yul.State.Ok ss vs).setMachineState M).insert k v)[j]! = (EvmYul.Yul.State.Ok ss vs)[j]! := by
  have h1 : (((EvmYul.Yul.State.Ok ss vs).setMachineState M).insert k v)[j]!
              = ((EvmYul.Yul.State.Ok ss vs).setMachineState M)[j]! :=
    RelayLoopLiteral.ge_ne _ _ k j v h
  rw [h1]; rfl

set_option maxHeartbeats 4000000 in
/-- **Accounting extraction (WW).** `body_effL`'s output state `s16` carries exactly the advanced
    accumulator: given (a) the accumulator entering the WW-update is `accNat k` (WW untouched by the body
    until statement 16 — the ecrecover call and guards do not write `weight`), and (b) the masked weight
    read is the selected voter's registered weight (`mload_masked_voter` = hcorr, DERIVED), then
    `s16[weight]! = accNat (k+1)`. This is the machine-checked "the body adds the right weight" — the
    accounting half of the per-iteration `hstep` the capstone assumes. -/
theorem s16_ww_advance (m : Nat) (ss15 : EvmYul.SharedState .Yul) (vs15 : EvmYul.Yul.VarStore)
    (cd : ByteArray) (sigStart nVotN k : Nat)
    (hWW : (EvmYul.Yul.State.Ok ss15 vs15)[WW]! = UInt256.ofNat (accNat cd sigStart nVotN k))
    (hcorr : EvmYul.UInt256.land ((EvmYul.Yul.State.Ok ss15 vs15).toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).1 (UInt256.ofNat 65535)
               = UInt256.ofNat (voterWeightAt cd (sigIdxAt cd sigStart k)))
    (hidxlt : sigIdxAt cd sigStart k < nVotN) :
    (((EvmYul.Yul.State.Ok ss15 vs15).setMachineState ((EvmYul.Yul.State.Ok ss15 vs15).toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).2).insert WW
        (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss15 vs15)[WW]!)
          (EvmYul.UInt256.land ((EvmYul.Yul.State.Ok ss15 vs15).toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).1 (UInt256.ofNat 65535))))[WW]!
      = UInt256.ofNat (accNat cd sigStart nVotN (k + 1)) := by
  have hacc : accNat cd sigStart nVotN (k + 1)
                = accNat cd sigStart nVotN k + voterWeightAt cd (sigIdxAt cd sigStart k) := by
    rw [accNat, RelayLoopLiteral.weightsOf_getD cd nVotN (sigIdxAt cd sigStart k) hidxlt]
  rw [ins_setMS_self, hWW, hcorr, ofNat_add, hacc]

set_option maxHeartbeats 4000000 in
/-- **Counter preserved (II).** `body_effL`'s output `s16` keeps the loop counter `i` (the body writes
    only `index`/`nextUnusedIndex`/`v`/`weight`, never `i`). -/
theorem s16_ii_preserved (m : Nat) (ss15 : EvmYul.SharedState .Yul) (vs15 : EvmYul.Yul.VarStore) (k : Nat)
    (hII : (EvmYul.Yul.State.Ok ss15 vs15)[II]! = UInt256.ofNat k) :
    (((EvmYul.Yul.State.Ok ss15 vs15).setMachineState ((EvmYul.Yul.State.Ok ss15 vs15).toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).2).insert WW
        (EvmYul.UInt256.add ((EvmYul.Yul.State.Ok ss15 vs15)[WW]!)
          (EvmYul.UInt256.land ((EvmYul.Yul.State.Ok ss15 vs15).toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).1 (UInt256.ofNat 65535))))[II]!
      = UInt256.ofNat k := by
  rw [ins_setMS_ne _ _ _ WW II _ (by decide), hII]

-- ===================== hstep DERIVED: iter_advance (brick 40) =====================
set_option maxHeartbeats 4000000 in
/-- **Per-iteration advance (`iter_advance`).** Assembles `body_effL` (the executed 17-statement body) with
    the accounting extraction (`s16_ww_advance`/`s16_ii_preserved`) into exactly the per-iteration `hstep`
    that `loop_accL`/`relay_loop_sound_literal` consume: one turn of `bodyL` executes to some `Ok`-state
    that preserves the loop counter `i = k` and advances the accumulator `weight` to `accNat (k+1)`.

    The nine guard-pass hypotheses (`hg4..hg17`, one per `if` that must not revert on the advance path) and
    the two ecrecover-output states (`ss10/vs10`, `ss15/vs15`) are the **OP-1 boundary** — ecrecover is
    uninterpreted by design, so "the recovered signer matches the registered voter / v,s are valid /
    returndatasize is 32 / the index is in range and strictly increasing" enter as hypotheses (exactly the
    literal, eval-level form of `relay_loop_sound`'s `hvalid`). The accounting inputs `hWW`/`hII` (weight and
    counter entering the update — untouched by the ecrecover call and the guards) and `hcorr` (the masked
    read is the selected voter's registered weight, = `mload_masked_voter`) with `hidxlt` (index in range)
    are what make the tally provably correct. Everything else — the execution and the accounting — is
    derived from the proven `body_effL` + extraction. -/
theorem iter_advance (m sigStart : Nat) (nVot thr : EvmYul.UInt256) (cd : ByteArray) (nVotN k : Nat)
    (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore)
    (ss10 : EvmYul.SharedState .Yul) (vs10 : EvmYul.Yul.VarStore)
    (ss15 : EvmYul.SharedState .Yul) (vs15 : EvmYul.Yul.VarStore) :
    let s1 := (EvmYul.Yul.State.Ok ss vs).setMachineState ((EvmYul.Yul.State.Ok ss vs).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0))
    let s2 := s1.setSharedState (s1.toSharedState.calldatacopy (UInt256.ofNat (m+63))
                (EvmYul.UInt256.add (EvmYul.UInt256.add (UInt256.ofNat sigStart)
                  (EvmYul.UInt256.mul (s1[II]!) (UInt256.ofNat 67))) (UInt256.ofNat 2)) (UInt256.ofNat 67))
    let s3 := (s2.setMachineState (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).2).insert IDX
                (EvmYul.UInt256.shiftRight (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).1 (UInt256.ofNat 240))
    let s6 := s3.insert NUI (EvmYul.UInt256.add (s3[IDX]!) (UInt256.ofNat 1))
    let s7 := (s6.setMachineState (s6.toSharedState.toMachineState.mload (UInt256.ofNat (m+32))).2).insert VV
                (EvmYul.UInt256.land (s6.toSharedState.toMachineState.mload (UInt256.ofNat (m+32))).1 (UInt256.ofNat 0xff))
    let s9 := s7.setMachineState (s7.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).2
    let s10 := EvmYul.Yul.State.Ok ss10 vs10
    let s15 := EvmYul.Yul.State.Ok ss15 vs15
    let s12 := s10.setMachineState (s10.toSharedState.toMachineState.mload (UInt256.ofNat (m+64))).2
    let s13 := s12.setMachineState (s12.toMachineState.mstore (UInt256.ofNat (m+96)) (UInt256.ofNat 0))
    let s14 := s13.setSharedState (s13.toSharedState.calldatacopy (UInt256.ofNat (m+106))
                 (EvmYul.UInt256.add (UInt256.ofNat 47) (EvmYul.UInt256.mul (s13[IDX]!) (UInt256.ofNat 22))) (UInt256.ofNat 22))
    let s16 := (s15.setMachineState (s15.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).2).insert WW
                 (EvmYul.UInt256.add (s15[WW]!) (EvmYul.UInt256.land (s15.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).1 (UInt256.ofNat 65535)))
    (∀ fuel, EvmYul.Yul.eval (fuel+125) (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]) none s3 = .ok (s3, ⟨0⟩)) →
    (∀ fuel, EvmYul.Yul.eval (fuel+124) (bc .LT [V IDX, V NUI]) none s3 = .ok (s3, ⟨0⟩)) →
    (∀ fuel, EvmYul.Yul.eval (fuel+121) (bc .ISZERO [bc .OR [bc .EQ [V VV, litN 27], bc .EQ [V VV, litN 28]]]) none s7 = .ok (s7, ⟨0⟩)) →
    (∀ fuel, EvmYul.Yul.eval (fuel+120) (bc .GT [bc .MLOAD [litN (m+96)], litU SECP_HALF]) none s7 = .ok (s9, ⟨0⟩)) →
    (∀ fuel, EvmYul.Yul.eval (fuel+119) (bc .ISZERO [bc .STATICCALL [bc .NOT [litN 0], litN 1, litN m, litN 128, litN (m+64), litN 32]]) none s9 = .ok (s10, ⟨0⟩)) →
    (∀ fuel, EvmYul.Yul.eval (fuel+118) (bc .ISZERO [bc .EQ [bc .RETURNDATASIZE [], litN 32]]) none s10 = .ok (s10, ⟨0⟩)) →
    (∀ fuel, EvmYul.Yul.eval (fuel+117) (bc .ISZERO [bc .MLOAD [litN (m+64)]]) none s10 = .ok (s12, ⟨0⟩)) →
    (∀ fuel, EvmYul.Yul.eval (fuel+114) (bc .ISZERO [bc .EQ [bc .MLOAD [litN (m+64)], bc .SHR [litN 16, bc .MLOAD [litN (m+96)]]]]) none s14 = .ok (s15, ⟨0⟩)) →
    (∀ fuel, EvmYul.Yul.eval (fuel+112) (bc .GT [V WW, litU thr]) none s16 = .ok (s16, ⟨0⟩)) →
    (EvmYul.Yul.State.Ok ss15 vs15)[WW]! = UInt256.ofNat (accNat cd sigStart nVotN k) →
    (EvmYul.Yul.State.Ok ss15 vs15)[II]! = UInt256.ofNat k →
    EvmYul.UInt256.land ((EvmYul.Yul.State.Ok ss15 vs15).toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).1 (UInt256.ofNat 65535)
      = UInt256.ofNat (voterWeightAt cd (sigIdxAt cd sigStart k)) →
    sigIdxAt cd sigStart k < nVotN →
    ∃ (ssk' : EvmYul.SharedState .Yul) (vsk' : EvmYul.Yul.VarStore),
      (∀ fuel, EvmYul.Yul.exec (fuel+130) (Stmt.Block (bodyL m sigStart nVot thr)) none
          (EvmYul.Yul.State.Ok ss vs) = .ok (EvmYul.Yul.State.Ok ssk' vsk')) ∧
      (EvmYul.Yul.State.Ok ssk' vsk')[II]! = UInt256.ofNat k ∧
      (EvmYul.Yul.State.Ok ssk' vsk')[WW]! = UInt256.ofNat (accNat cd sigStart nVotN (k + 1)) := by
  intro s1 s2 s3 s6 s7 s9 s10 s15 s12 s13 s14 s16 hg4 hg5 hg8 hg9 hg10 hg11 hg12 hg15 hg17 hWW hII hcorr hidxlt
  refine ⟨_, _,
    fun fuel => body_effL fuel m sigStart nVot thr ss vs ss10 vs10 ss15 vs15
      (hg4 fuel) (hg5 fuel) (hg8 fuel) (hg9 fuel) (hg10 fuel) (hg11 fuel) (hg12 fuel) (hg15 fuel) (hg17 fuel),
    ?_, ?_⟩
  · exact s16_ii_preserved m ss15 vs15 k hII
  · exact s16_ww_advance m ss15 vs15 cd sigStart nVotN k hWW hcorr hidxlt

-- ===================== THE LITERAL CAPSTONE =====================
set_option maxHeartbeats 4000000 in
/-- **Relay signature loop soundness, on the validated EVM, with the LITERAL 17-statement body.**
    If the deployed loop — modeled with its *actual* transliterated body `bodyL` executed by EVMYulLean's
    validated Yul `exec`, iterated by `loop_accL` — completes with a final tally exceeding the threshold,
    then the TOTAL registered voting weight exceeds the threshold. No voter is double-counted.

    Mirrors `RelayLoopMemRead.relay_loop_sound` but with the genuine loop body (`body_effL`) rather than the
    abstract masked-read body. The external call remains an **assumption** (OP-1): `hstep` packages, per
    iteration, exactly what `body_effL` delivers — one turn of `bodyL` preserves the counter and adds the
    selected voter's registered weight — which is provable from `body_effL` once ecrecover's outcome
    (`recHypothesis`) and the guard passes (`hvalid`) are supplied. `hvalid` (`ValidRun`) is the
    strictly-increasing-in-range index discipline (guards passed, no double-count); `hnoovf` is BR-2. -/
theorem relay_loop_sound_literal
    (m sigStart : Nat) (cd : ByteArray) (nVot thr : EvmYul.UInt256) (nVotN NN : Nat)
    (hN : NN < UInt256.size)
    (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore)
    (hi : (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat 0)
    (hw : (EvmYul.Yul.State.Ok ss vs)[WW]! = UInt256.ofNat (accNat cd sigStart nVotN 0))
    (hstep : ∀ (k : Nat) (ssk : EvmYul.SharedState .Yul) (vsk : EvmYul.Yul.VarStore),
        k < NN →
        (EvmYul.Yul.State.Ok ssk vsk)[II]! = UInt256.ofNat k →
        (EvmYul.Yul.State.Ok ssk vsk)[WW]! = UInt256.ofNat (accNat cd sigStart nVotN k) →
        ∃ (ssk' : EvmYul.SharedState .Yul) (vsk' : EvmYul.Yul.VarStore),
          (∀ fuel, EvmYul.Yul.exec (fuel + 130) (Stmt.Block (bodyL m sigStart nVot thr)) none
              (EvmYul.Yul.State.Ok ssk vsk) = .ok (EvmYul.Yul.State.Ok ssk' vsk')) ∧
          (EvmYul.Yul.State.Ok ssk' vsk')[II]! = UInt256.ofNat k ∧
          (EvmYul.Yul.State.Ok ssk' vsk')[WW]! = UInt256.ofNat (accNat cd sigStart nVotN (k + 1)))
    (hvalid : ValidRun (weightsOf cd nVotN) 0 (idxSel cd sigStart NN))
    (hnoovf : accNat cd sigStart nVotN NN < UInt256.size)
    (ss' : EvmYul.SharedState .Yul) (vs' : EvmYul.Yul.VarStore)
    (hexec : EvmYul.Yul.exec (3 * NN + 140)
        (Stmt.For (condL (UInt256.ofNat NN)) postL (bodyL m sigStart nVot thr)) none
          (EvmYul.Yul.State.Ok ss vs)
        = .ok (EvmYul.Yul.State.Ok ss' vs'))
    (haccept : thr < (EvmYul.Yul.State.Ok ss' vs')[WW]!) :
    thr.val < sumTake (weightsOf cd nVotN) (weightsOf cd nVotN).length := by
  -- 1. run the literal loop induction
  obtain ⟨ss2, vs2, hexec2, hWW2⟩ :=
    RelayBodyEff.loop_accL NN hN m sigStart nVot thr
      (fun k => UInt256.ofNat (accNat cd sigStart nVotN k)) hstep NN 0 ss vs (by omega) hi hw
  -- 2. reconcile with the accept hypothesis's final state
  have heq : EvmYul.Yul.State.Ok ss' vs' = EvmYul.Yul.State.Ok ss2 vs2 := by
    rw [hexec] at hexec2; exact Except.ok.inj hexec2
  rw [heq, hWW2] at haccept
  -- 3. accept: thr.val < accNat NN   (UInt256 `<` is `.val <`; ofNat is identity under no-overflow)
  have h1 : thr.val < (UInt256.ofNat (accNat cd sigStart nVotN NN)).val := haccept
  have h2 : (UInt256.ofNat (accNat cd sigStart nVotN NN)).val = accNat cd sigStart nVotN NN :=
    val_ofNat_of_lt _ hnoovf
  have h3 : thr.val < accNat cd sigStart nVotN NN := by omega
  -- 4. accNat NN = abstract sigLoop accumulated weight
  rw [accNat_eq_sigLoop] at h3
  -- 5. transfer the abstract threshold soundness (no double-count via ValidRun)
  exact RelayLoopLiteral.threshold_sound (weightsOf cd nVotN) (idxSel cd sigStart NN) thr.val hvalid h3


-- ===================== hstep DISCHARGED: full derived soundness (brick 41) =====================
/-- Per-iteration OP-1 premise: entering the body at index `k` with state `(ssk, vsk)`, there exist
    ecrecover-output states such that the nine guards pass (execution does not revert) and the accounting
    inputs hold (weight/counter preserved into the update; the masked read is the selected voter's weight).
    This is the literal, eval-level statement of `relay_loop_sound`'s `hvalid` + the (now derived) `hcorr`. -/
def IterPremise (m sigStart : Nat) (nVot thr : EvmYul.UInt256) (cd : ByteArray) (nVotN k : Nat)
    (ssk : EvmYul.SharedState .Yul) (vsk : EvmYul.Yul.VarStore) : Prop :=
  ∃ (ss10 : EvmYul.SharedState .Yul) (vs10 : EvmYul.Yul.VarStore)
    (ss15 : EvmYul.SharedState .Yul) (vs15 : EvmYul.Yul.VarStore),
    let s1 := (EvmYul.Yul.State.Ok ssk vsk).setMachineState ((EvmYul.Yul.State.Ok ssk vsk).toMachineState.mstore (UInt256.ofNat (m+32)) (UInt256.ofNat 0))
    let s2 := s1.setSharedState (s1.toSharedState.calldatacopy (UInt256.ofNat (m+63))
                (EvmYul.UInt256.add (EvmYul.UInt256.add (UInt256.ofNat sigStart)
                  (EvmYul.UInt256.mul (s1[II]!) (UInt256.ofNat 67))) (UInt256.ofNat 2)) (UInt256.ofNat 67))
    let s3 := (s2.setMachineState (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).2).insert IDX
                (EvmYul.UInt256.shiftRight (s2.toSharedState.toMachineState.mload (UInt256.ofNat (m+128))).1 (UInt256.ofNat 240))
    let s6 := s3.insert NUI (EvmYul.UInt256.add (s3[IDX]!) (UInt256.ofNat 1))
    let s7 := (s6.setMachineState (s6.toSharedState.toMachineState.mload (UInt256.ofNat (m+32))).2).insert VV
                (EvmYul.UInt256.land (s6.toSharedState.toMachineState.mload (UInt256.ofNat (m+32))).1 (UInt256.ofNat 0xff))
    let s9 := s7.setMachineState (s7.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).2
    let s10 := EvmYul.Yul.State.Ok ss10 vs10
    let s15 := EvmYul.Yul.State.Ok ss15 vs15
    let s12 := s10.setMachineState (s10.toSharedState.toMachineState.mload (UInt256.ofNat (m+64))).2
    let s13 := s12.setMachineState (s12.toMachineState.mstore (UInt256.ofNat (m+96)) (UInt256.ofNat 0))
    let s14 := s13.setSharedState (s13.toSharedState.calldatacopy (UInt256.ofNat (m+106))
                 (EvmYul.UInt256.add (UInt256.ofNat 47) (EvmYul.UInt256.mul (s13[IDX]!) (UInt256.ofNat 22))) (UInt256.ofNat 22))
    let s16 := (s15.setMachineState (s15.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).2).insert WW
                 (EvmYul.UInt256.add (s15[WW]!) (EvmYul.UInt256.land (s15.toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).1 (UInt256.ofNat 65535)))
    (∀ fuel, EvmYul.Yul.eval (fuel+125) (bc .GT [bc .ADD [V IDX, litN 1], litU nVot]) none s3 = .ok (s3, ⟨0⟩)) ∧
    (∀ fuel, EvmYul.Yul.eval (fuel+124) (bc .LT [V IDX, V NUI]) none s3 = .ok (s3, ⟨0⟩)) ∧
    (∀ fuel, EvmYul.Yul.eval (fuel+121) (bc .ISZERO [bc .OR [bc .EQ [V VV, litN 27], bc .EQ [V VV, litN 28]]]) none s7 = .ok (s7, ⟨0⟩)) ∧
    (∀ fuel, EvmYul.Yul.eval (fuel+120) (bc .GT [bc .MLOAD [litN (m+96)], litU SECP_HALF]) none s7 = .ok (s9, ⟨0⟩)) ∧
    (∀ fuel, EvmYul.Yul.eval (fuel+119) (bc .ISZERO [bc .STATICCALL [bc .NOT [litN 0], litN 1, litN m, litN 128, litN (m+64), litN 32]]) none s9 = .ok (s10, ⟨0⟩)) ∧
    (∀ fuel, EvmYul.Yul.eval (fuel+118) (bc .ISZERO [bc .EQ [bc .RETURNDATASIZE [], litN 32]]) none s10 = .ok (s10, ⟨0⟩)) ∧
    (∀ fuel, EvmYul.Yul.eval (fuel+117) (bc .ISZERO [bc .MLOAD [litN (m+64)]]) none s10 = .ok (s12, ⟨0⟩)) ∧
    (∀ fuel, EvmYul.Yul.eval (fuel+114) (bc .ISZERO [bc .EQ [bc .MLOAD [litN (m+64)], bc .SHR [litN 16, bc .MLOAD [litN (m+96)]]]]) none s14 = .ok (s15, ⟨0⟩)) ∧
    (∀ fuel, EvmYul.Yul.eval (fuel+112) (bc .GT [V WW, litU thr]) none s16 = .ok (s16, ⟨0⟩)) ∧
    (EvmYul.Yul.State.Ok ss15 vs15)[WW]! = UInt256.ofNat (accNat cd sigStart nVotN k) ∧
    (EvmYul.Yul.State.Ok ss15 vs15)[II]! = UInt256.ofNat k ∧
    EvmYul.UInt256.land ((EvmYul.Yul.State.Ok ss15 vs15).toSharedState.toMachineState.mload (UInt256.ofNat (m+96))).1 (UInt256.ofNat 65535)
      = UInt256.ofNat (voterWeightAt cd (sigIdxAt cd sigStart k)) ∧
    sigIdxAt cd sigStart k < nVotN

set_option maxHeartbeats 4000000 in
/-- **Relay signature loop soundness with `hstep` DERIVED.** The literal capstone
    `relay_loop_sound_literal` assumed a per-iteration advance `hstep`; here it is discharged by
    `iter_advance`, so the only remaining hypotheses are the per-iteration OP-1 facts (`hiters`, i.e.
    `IterPremise` at each valid entering state) plus `hvalid`/`hnoovf`/the accept. If the deployed loop —
    its ACTUAL transliterated body executed by validated Yul `exec` — completes with a final tally
    exceeding the threshold, the total registered voting weight exceeds it; no voter is double-counted. -/
theorem relay_loop_sound_literal_derived
    (m sigStart : Nat) (cd : ByteArray) (nVot thr : EvmYul.UInt256) (nVotN NN : Nat)
    (hN : NN < UInt256.size)
    (ss : EvmYul.SharedState .Yul) (vs : EvmYul.Yul.VarStore)
    (hi : (EvmYul.Yul.State.Ok ss vs)[II]! = UInt256.ofNat 0)
    (hw : (EvmYul.Yul.State.Ok ss vs)[WW]! = UInt256.ofNat (accNat cd sigStart nVotN 0))
    (hiters : ∀ (k : Nat) (ssk : EvmYul.SharedState .Yul) (vsk : EvmYul.Yul.VarStore),
        k < NN →
        (EvmYul.Yul.State.Ok ssk vsk)[II]! = UInt256.ofNat k →
        (EvmYul.Yul.State.Ok ssk vsk)[WW]! = UInt256.ofNat (accNat cd sigStart nVotN k) →
        IterPremise m sigStart nVot thr cd nVotN k ssk vsk)
    (hvalid : ValidRun (weightsOf cd nVotN) 0 (idxSel cd sigStart NN))
    (hnoovf : accNat cd sigStart nVotN NN < UInt256.size)
    (ss' : EvmYul.SharedState .Yul) (vs' : EvmYul.Yul.VarStore)
    (hexec : EvmYul.Yul.exec (3 * NN + 140)
        (Stmt.For (condL (UInt256.ofNat NN)) postL (bodyL m sigStart nVot thr)) none
          (EvmYul.Yul.State.Ok ss vs)
        = .ok (EvmYul.Yul.State.Ok ss' vs'))
    (haccept : thr < (EvmYul.Yul.State.Ok ss' vs')[WW]!) :
    thr.val < sumTake (weightsOf cd nVotN) (weightsOf cd nVotN).length := by
  refine relay_loop_sound_literal m sigStart cd nVot thr nVotN NN hN ss vs hi hw ?_ hvalid hnoovf ss' vs' hexec haccept
  intro k ssk vsk hk hII hWW
  obtain ⟨ss10, vs10, ss15, vs15, hg4, hg5, hg8, hg9, hg10, hg11, hg12, hg15, hg17, hWW15, hII15, hcorr, hidxlt⟩ :=
    hiters k ssk vsk hk hII hWW
  exact iter_advance m sigStart nVot thr cd nVotN k ssk vsk ss10 vs10 ss15 vs15
    hg4 hg5 hg8 hg9 hg10 hg11 hg12 hg15 hg17 hWW15 hII15 hcorr hidxlt


end LoopLayer

#print axioms relay_loop_sound_literal_derived
#print axioms relay_loop_sound_literal
#print axioms iter_advance
#print axioms s16_ww_advance
#print axioms s16_ii_preserved
#print axioms accNat_eq_sigLoop
#print axioms loop_accL
#print axioms cond_effL
#print axioms post_effL
#print axioms body_effL
#print axioms body_prefix9
#print axioms RelayBodyEff.seam_guard_eval
#print axioms body_prefix5
#print axioms body_prefix3
#print axioms RelayBodyEff.let_nui
#print axioms RelayBodyEff.let_idx
#print axioms RelayBodyEff.let_vv
#print axioms RelayBodyEff.let_ww
#print axioms body_prefix2

end RelayBodyEff

#print axioms RelayBodyEff.voter_weight_pure
#print axioms RelayBodyEff.voter_signer_pure
#print axioms RelayBodyEff.mload_masked_voter
#print axioms RelayBodyEff.mload_shr_voter
#print axioms RelayBodyEff.voter_mem_pattern
#print axioms RelayBodyEff.mstore_cdc_mem
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
#print axioms RelayBodyEff.eval_range_cond
#print axioms RelayBodyEff.eval_order_cond
#print axioms RelayBodyEff.eval_gt_mload_lit
#print axioms RelayBodyEff.eval_g11
#print axioms RelayBodyEff.eval_g12
#print axioms RelayBodyEff.eval_badv_cond
#print axioms RelayBodyEff.eval_wrongsig_cond
