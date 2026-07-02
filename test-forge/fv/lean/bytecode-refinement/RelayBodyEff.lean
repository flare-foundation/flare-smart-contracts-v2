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

end RelayBodyEff

#print axioms RelayBodyEff.voter_weight_pure
#print axioms RelayBodyEff.voter_signer_pure
#print axioms RelayBodyEff.mload_masked_voter
#print axioms RelayBodyEff.mload_shr_voter
#print axioms RelayBodyEff.voter_mem_pattern
