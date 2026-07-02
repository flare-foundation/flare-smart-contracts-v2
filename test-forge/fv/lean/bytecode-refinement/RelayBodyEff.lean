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
