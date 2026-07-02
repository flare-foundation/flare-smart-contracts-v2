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

end RelayBodyEff

#print axioms RelayBodyEff.voter_weight_pure
#print axioms RelayBodyEff.voter_signer_pure
#print axioms RelayBodyEff.mload_masked_voter
#print axioms RelayBodyEff.mload_shr_voter
