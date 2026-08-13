/-
  RelayFeeLayer.lean

  The fee logic of Relay.sol `verify()` as a hole-free Lean lemma set, on
  NethermindEth's EVMYulLean semantics.

  Models the native-coin fee branch of `verify()` under `feeToken == address(0)`
  and a non-exempt caller:

      uint256 fee = protocolFee[_protocolId];
      require(msg.value >= fee, "too low fee");
      if (fee > 0) feeCollectionAddress.call{value: fee}("");   // forward `fee`
      uint256 refund = msg.value - fee;
      if (refund > 0) msg.sender.call{value: refund}("");       // refund the rest
      return true;

  Property captured: **fees conserve value**.  `fee + (msg.value - fee) = msg.value`
  with no under/overflow (the `require(msg.value >= fee)` guard), and the balance
  primitive `transferBalance` — the value-movement the Yul `.CALL` performs — moves
  value without creating or destroying any (the balance analogue of the storage
  round-trip in RelayStorageLayer.lean).

  Anchored on EVMYulLean (commit 047f6307…):
    * EvmYul/UInt256.lean          — `UInt256.add`/`.sub` are Fin (2^256) arithmetic.
    * EvmYul/Maps/AccountMap.lean  — `increaseBalance`/`decreaseBalance`/`transferBalance`.
    * EvmYul/Yul/Interpreter.lean  — the Yul `.CALL` primitive uses `transferBalance`.

  Self-contained: imports `EvmYul` only. Every `#print axioms` at the bottom is a
  subset of `{propext, Classical.choice, Quot.sound}` — no sorry/native_decide.

  The ERC-20 branch (`feeToken != address(0)`, zero `msg.value`, and SafeERC20
  `transferFrom`) is outside this module. The remaining native-branch boundary (the
  exec-level `.CALL` wiring through `primCall`/`callDispatcher`) is documented in
  Section 4 — the fuel-carrying analogue of RelayStorageLayer's `sstore_eff`.
-/
import EvmYul
open EvmYul
open Batteries (RBMap)

namespace RelayFeeLayer

/-! ## Section 0.  RBMap key-ordering helpers for `AccountAddress`

`AccountMap τ = Batteries.RBMap AccountAddress (Account τ) compare`.  The Batteries
`find?`/`insert` lemmas need `Std.TransCmp compare`, which does not synthesize for the
custom `Ord AccountAddress`.  As in RelayStorageLayer.lean we transfer it from the
underlying `Nat` comparator (`compare a b = compare a.val b.val` definitionally). -/

instance addr_transcmp : Std.TransCmp (compare : AccountAddress → AccountAddress → Ordering) where
  eq_swap {a b} := Std.OrientedCmp.eq_swap
  isLE_trans {a b c} h1 h2 := Std.TransCmp.isLE_trans h1 h2

/-- Distinct addresses do not compare `.eq` (needed for `find?`-after-insert of another key). -/
theorem addr_compare_ne {a b : AccountAddress} (h : a ≠ b) : compare a b ≠ Ordering.eq := by
  intro heq
  have hnat : compare a.val b.val = Ordering.eq := heq
  exact h (Fin.ext (Nat.compare_eq_eq.mp hnat))

/-- `find?` after inserting the *same* key returns the inserted value. -/
theorem find_insert_self {τ} (σ : AccountMap τ) (k : AccountAddress) (v : Account τ) :
    (σ.insert k v).find? k = some v :=
  Batteries.RBMap.find?_insert_of_eq σ Std.ReflCmp.compare_self

/-- `find?` after inserting a *different* key is unaffected. -/
theorem find_insert_ne {τ} (σ : AccountMap τ) (k k' : AccountAddress) (v : Account τ)
    (h : k' ≠ k) : (σ.insert k v).find? k' = σ.find? k' :=
  Batteries.RBMap.find?_insert_of_ne σ (addr_compare_ne h)

/-! ## Section 0'.  `decreaseBalance` / `increaseBalance` success characterizations -/

/-- If `A` is present with enough balance, `decreaseBalance` succeeds by writing back
`A ↦ {accA with balance := accA.balance - amt}`. -/
theorem decreaseBalance_some {τ} (σ : AccountMap τ) (A : AccountAddress) (amt : UInt256)
    (accA : Account τ) (hA : σ.find? A = some accA) (hbal : ¬ accA.balance < amt) :
    σ.decreaseBalance τ A amt = some (σ.insert A {accA with balance := accA.balance - amt}) := by
  unfold AccountMap.decreaseBalance
  rw [hA]
  simp only [hbal, if_false]

/-- If `B` is present, `increaseBalance` writes back `B ↦ {accB with balance := accB.balance + amt}`. -/
theorem increaseBalance_some {τ} (σ : AccountMap τ) (B : AccountAddress) (amt : UInt256)
    (accB : Account τ) (hB : σ.find? B = some accB) :
    σ.increaseBalance τ B amt = σ.insert B {accB with balance := accB.balance + amt} := by
  unfold AccountMap.increaseBalance
  rw [hB]

/-! ## Section 1.  Fee-conservation arithmetic (the core)

`UInt256` is `Fin (2^256)`; `UInt256.add`/`.sub` are the `Fin` group operations. -/

/-- **Fee conservation at the word (Fin) level.**  `fee + (msgValue - fee) = msgValue`
as 256-bit words — the additive-group identity `a + (b - a) = b`, so no wraparound.
(The `require(msg.value >= fee)` guard `h` is recorded but not needed at this level.) -/
theorem fee_conservation (fee msgValue : EvmYul.UInt256) (h : fee.val ≤ msgValue.val) :
    (EvmYul.UInt256.add fee (EvmYul.UInt256.sub msgValue fee)).val = msgValue.val := by
  show fee.val + (msgValue.val - fee.val) = msgValue.val
  exact add_sub_cancel fee.val msgValue.val

/-- Under the `require` guard, the refund `msgValue - fee` is the *true* (non-wrapping)
subtraction: its Nat value is `msgValue.toNat - fee.toNat`. -/
theorem refund_toNat (fee msgValue : EvmYul.UInt256) (h : fee.val ≤ msgValue.val) :
    (EvmYul.UInt256.sub msgValue fee).toNat = msgValue.toNat - fee.toNat := by
  show (msgValue.val - fee.val).val = msgValue.val.val - fee.val.val
  exact Fin.sub_val_of_le h

/-- **Fee conservation at the integer (Nat) level.**  `fee + refund = msgValue` as
naturals with *no* modular reduction: no ETH is created or destroyed.  Needs the guard `h`. -/
theorem fee_conservation_toNat (fee msgValue : EvmYul.UInt256) (h : fee.val ≤ msgValue.val) :
    fee.toNat + (EvmYul.UInt256.sub msgValue fee).toNat = msgValue.toNat := by
  rw [refund_toNat fee msgValue h]
  have hle : fee.toNat ≤ msgValue.toNat := h
  omega

/-- The refund never exceeds `msgValue` (no double-spend). -/
theorem refund_le (fee msgValue : EvmYul.UInt256) (h : fee.val ≤ msgValue.val) :
    (EvmYul.UInt256.sub msgValue fee).toNat ≤ msgValue.toNat := by
  rw [refund_toNat fee msgValue h]
  omega

/-! ## Section 2.  `transferBalance` conservation (the balance-primitive anchor)

The Yul `.CALL` primitive moves `value` from caller to callee via
`accountMap.transferBalance .Yul codeOwner address value`. -/

/-- **Full characterization of a successful `transferBalance`.**  For `A ≠ B`, both present,
`A` funded (`¬ accA.balance < amt`), the transfer succeeds and the resulting map is exactly
`A`'s balance decreased by `amt` and `B`'s increased by `amt`. -/
theorem transferBalance_eq {τ} (σ : AccountMap τ) (A B : AccountAddress) (amt : UInt256)
    (accA accB : Account τ) (hAB : A ≠ B)
    (hA : σ.find? A = some accA) (hB : σ.find? B = some accB) (hbal : ¬ accA.balance < amt) :
    σ.transferBalance τ A B amt
      = some ((σ.insert A {accA with balance := accA.balance - amt}).insert B
                {accB with balance := accB.balance + amt}) := by
  have hB' : (σ.insert A {accA with balance := accA.balance - amt}).find? B = some accB := by
    rw [find_insert_ne σ A B {accA with balance := accA.balance - amt} (Ne.symm hAB)]
    exact hB
  unfold AccountMap.transferBalance
  rw [decreaseBalance_some σ A amt accA hA hbal]
  show some (AccountMap.increaseBalance τ
              (σ.insert A {accA with balance := accA.balance - amt}) B amt) = _
  rw [increaseBalance_some (σ.insert A {accA with balance := accA.balance - amt}) B amt accB hB']

/-- **`transferBalance` conserves value (word level).**  After transferring `amt` from `A`
to `B` (`A ≠ B`, both present, `A` funded): `A`'s new balance is `accA.balance - amt`, `B`'s is
`accB.balance + amt`, and the *modular sum* of the two balances is invariant — no ETH is
created or destroyed at the 256-bit-word level. -/
theorem transfer_conservation {τ} (σ : AccountMap τ) (A B : AccountAddress) (amt : UInt256)
    (accA accB : Account τ) (hAB : A ≠ B)
    (hA : σ.find? A = some accA) (hB : σ.find? B = some accB) (hbal : ¬ accA.balance < amt) :
    ∃ σ' bA bB,
      σ.transferBalance τ A B amt = some σ' ∧
      σ'.find? A = some bA ∧ σ'.find? B = some bB ∧
      bA.balance = EvmYul.UInt256.sub accA.balance amt ∧
      bB.balance = EvmYul.UInt256.add accB.balance amt ∧
      (EvmYul.UInt256.add bA.balance bB.balance).val
        = (EvmYul.UInt256.add accA.balance accB.balance).val := by
  refine ⟨_, {accA with balance := accA.balance - amt}, {accB with balance := accB.balance + amt},
    transferBalance_eq σ A B amt accA accB hAB hA hB hbal, ?_, ?_, rfl, rfl, ?_⟩
  · rw [find_insert_ne _ B A _ hAB, find_insert_self]
  · rw [find_insert_self]
  · show (accA.balance.val - amt.val) + (accB.balance.val + amt.val)
        = accA.balance.val + accB.balance.val
    abel

/-- **`transferBalance` conserves value (integer level).**  With the recipient's balance not
overflowing (`accB.balance.toNat + amt.toNat < 2^256`), the *natural-number* sum of the two
balances is exactly preserved: no ETH created or destroyed. -/
theorem transfer_conservation_toNat {τ} (σ : AccountMap τ) (A B : AccountAddress) (amt : UInt256)
    (accA accB : Account τ) (hAB : A ≠ B)
    (hA : σ.find? A = some accA) (hB : σ.find? B = some accB) (hbal : ¬ accA.balance < amt)
    (hnoof : accB.balance.toNat + amt.toNat < EvmYul.UInt256.size) :
    ∃ σ' bA bB,
      σ.transferBalance τ A B amt = some σ' ∧
      σ'.find? A = some bA ∧ σ'.find? B = some bB ∧
      bA.balance.toNat + bB.balance.toNat = accA.balance.toNat + accB.balance.toNat := by
  refine ⟨_, {accA with balance := accA.balance - amt}, {accB with balance := accB.balance + amt},
    transferBalance_eq σ A B amt accA accB hAB hA hB hbal, ?_, ?_, ?_⟩
  · rw [find_insert_ne _ B A _ hAB, find_insert_self]
  · rw [find_insert_self]
  · have hle : amt.val ≤ accA.balance.val := le_of_not_gt hbal
    have hsubA : ({accA with balance := accA.balance - amt} : Account τ).balance.toNat
                  = accA.balance.toNat - amt.toNat := Fin.sub_val_of_le hle
    have haddB : ({accB with balance := accB.balance + amt} : Account τ).balance.toNat
                  = accB.balance.toNat + amt.toNat := Fin.val_add_eq_of_add_lt hnoof
    rw [hsubA, haddB]
    have hle' : amt.toNat ≤ accA.balance.toNat := hle
    omega

/-! ## Section 3.  Two-transfer net-zero for the caller (native-fee composition)

In native-fee mode, `verify()` forwards `fee` to `collector` and
`refund = msgValue - fee` to `sender`, both from the caller `codeOwner`.
Composing two `transferBalance`s, the caller's balance drops by exactly
`fee + refund = msgValue`. -/

/-- **Caller balance delta across the fee-forwarding.**  Executing
`transferBalance O collector fee` then `transferBalance O sender (msgValue - fee)`
(both succeed; `O`, `collector`, `sender` pairwise distinct and present; funded at each step)
leaves the caller `O`'s balance decreased by exactly `msgValue`:
`bO.balance = accO.balance - msgValue` (word level). Combines Section 1 (`fee + refund = msgValue`)
with Section 2 (per-transfer from-balance). -/
theorem two_transfer_caller_delta {τ} (σ : AccountMap τ)
    (O collector sender : AccountAddress) (fee msgValue : UInt256)
    (accO accCol accSen : Account τ)
    (hOcol : O ≠ collector) (hOsen : O ≠ sender) (hColsen : collector ≠ sender)
    (hO : σ.find? O = some accO)
    (hCol : σ.find? collector = some accCol)
    (hSen : σ.find? sender = some accSen)
    (hfee : fee.val ≤ msgValue.val)
    (hbal1 : ¬ accO.balance < fee)
    (hbal2 : ¬ (EvmYul.UInt256.sub accO.balance fee) < EvmYul.UInt256.sub msgValue fee) :
    ∃ σ1 σ2 bO,
      σ.transferBalance τ O collector fee = some σ1 ∧
      σ1.transferBalance τ O sender (EvmYul.UInt256.sub msgValue fee) = some σ2 ∧
      σ2.find? O = some bO ∧
      bO.balance.val = (EvmYul.UInt256.sub accO.balance msgValue).val := by
  -- transfer 1: O → collector, fee
  have ht1 := transferBalance_eq σ O collector fee accO accCol hOcol hO hCol hbal1
  -- caller present after transfer 1 (O ≠ collector)
  have hO1 : ((σ.insert O {accO with balance := accO.balance - fee}).insert collector
                {accCol with balance := accCol.balance + fee}).find? O
              = some {accO with balance := accO.balance - fee} := by
    rw [find_insert_ne _ collector O _ hOcol, find_insert_self]
  -- sender preserved after transfer 1 (sender ≠ O, sender ≠ collector)
  have hSen1 : ((σ.insert O {accO with balance := accO.balance - fee}).insert collector
                {accCol with balance := accCol.balance + fee}).find? sender = some accSen := by
    rw [find_insert_ne _ collector sender _ (Ne.symm hColsen),
        find_insert_ne _ O sender _ (Ne.symm hOsen), hSen]
  -- caller still funded for the refund
  have hbal2' : ¬ ({accO with balance := accO.balance - fee} : Account τ).balance
                    < EvmYul.UInt256.sub msgValue fee := hbal2
  -- transfer 2: O → sender, refund
  have ht2 := transferBalance_eq
    ((σ.insert O {accO with balance := accO.balance - fee}).insert collector
        {accCol with balance := accCol.balance + fee})
    O sender (EvmYul.UInt256.sub msgValue fee) {accO with balance := accO.balance - fee} accSen
    hOsen hO1 hSen1 hbal2'
  refine ⟨_, _, {({accO with balance := accO.balance - fee} : Account τ) with
                  balance := ({accO with balance := accO.balance - fee} : Account τ).balance
                              - EvmYul.UInt256.sub msgValue fee},
    ht1, ht2, ?_, ?_⟩
  · rw [find_insert_ne _ sender O _ hOsen, find_insert_self]
  · show (accO.balance.val - fee.val) - (msgValue.val - fee.val) = accO.balance.val - msgValue.val
    abel

/-- **Net-zero for the caller.**  If the caller received exactly `msgValue` on entry
(`accO.balance = Binitial + msgValue`), then after forwarding `fee` and refunding `msgValue - fee`
its balance is back to `Binitial`: the fee-forwarding is value-neutral for the caller. -/
theorem two_transfer_caller_net_zero {τ} (σ : AccountMap τ)
    (O collector sender : AccountAddress) (fee msgValue Binitial : UInt256)
    (accO accCol accSen : Account τ)
    (hOcol : O ≠ collector) (hOsen : O ≠ sender) (hColsen : collector ≠ sender)
    (hO : σ.find? O = some accO)
    (hCol : σ.find? collector = some accCol)
    (hSen : σ.find? sender = some accSen)
    (hfee : fee.val ≤ msgValue.val)
    (hbal1 : ¬ accO.balance < fee)
    (hbal2 : ¬ (EvmYul.UInt256.sub accO.balance fee) < EvmYul.UInt256.sub msgValue fee)
    (hentry : accO.balance = EvmYul.UInt256.add Binitial msgValue) :
    ∃ σ1 σ2 bO,
      σ.transferBalance τ O collector fee = some σ1 ∧
      σ1.transferBalance τ O sender (EvmYul.UInt256.sub msgValue fee) = some σ2 ∧
      σ2.find? O = some bO ∧
      bO.balance.val = Binitial.val := by
  obtain ⟨σ1, σ2, bO, h1, h2, h3, hdelta⟩ :=
    two_transfer_caller_delta σ O collector sender fee msgValue accO accCol accSen
      hOcol hOsen hColsen hO hCol hSen hfee hbal1 hbal2
  refine ⟨σ1, σ2, bO, h1, h2, h3, ?_⟩
  rw [hdelta, hentry]
  show (Binitial.val + msgValue.val) - msgValue.val = Binitial.val
  abel

/-! ## Section 4.  Explicit boundaries

Sections 2-3 anchor conservation at the **balance primitive** `AccountMap.transferBalance`,
which is precisely the value-movement the Yul `.CALL` primitive performs through
`transferBalance .Yul codeOwner address value`.

This module is conditional on the native-fee branch (`feeToken == address(0)`) and
does not model ERC-20 balances, allowances, return conventions, SafeERC20, or the
EnumerableSet-backed fee-table replacement logic.

Within the native branch, what is **not** covered here is wiring Relay.sol's
`feeCollectionAddress.call{value: fee}("")` through the *full* exec-level `.CALL`
path in `EvmYul.Yul.primCall`/`callDispatcher`:
  * decoding the 7 stack args and `AccountAddress.ofUInt256 address_arg`;
  * the static-mode / depth-1024 / insufficient-funds branches
    (each returning a `buildContractCallEmptyReturnState`);
  * the empty-calldata/empty-return-data callee contract semantics and the
    `callDispatcher fuel₁` recursion (fuel-bounded) with memory `copySlice` of return data.
That "value/call layer" is a separate, fuel-carrying exec-level obligation (the analogue of
RelayStorageLayer's `sstore_eff`, but for `.CALL`) and is left as the remaining boundary.
The `transferBalance`-level facts above are the faithful balance-semantics core that any such
exec-level result would ultimately reduce to.

Native value conservation is also covered at bounded scope by the Halmos harnesses
`RelayVerifyFeeFV` and `RelayFeeConservationFV`; this Lean layer adds the unbounded
balance-primitive semantics.
-/

/-! ## Section 5.  Hole-freeness checks (each ⊆ {propext, Classical.choice, Quot.sound}) -/

#print axioms addr_compare_ne
#print axioms find_insert_self
#print axioms find_insert_ne
#print axioms decreaseBalance_some
#print axioms increaseBalance_some
-- Item 1
#print axioms fee_conservation
#print axioms refund_toNat
#print axioms fee_conservation_toNat
#print axioms refund_le
-- Item 2
#print axioms transferBalance_eq
#print axioms transfer_conservation
#print axioms transfer_conservation_toNat
-- Item 3
#print axioms two_transfer_caller_delta
#print axioms two_transfer_caller_net_zero

end RelayFeeLayer
