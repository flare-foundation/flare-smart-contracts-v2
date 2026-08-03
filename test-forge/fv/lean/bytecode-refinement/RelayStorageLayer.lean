/-
  RelayStorageLayer.lean

  A hole-free storage round-trip (`sstore` then `sload` returns the stored value)
  on NethermindEth's EVMYulLean `EvmYul.State`.

  Self-contained: imports `EvmYul` only. Every `#print axioms` at the bottom is
  a subset of `{propext, Classical.choice, Quot.sound}`.
-/
import EvmYul

open EvmYul
open Batteries.RBNode
open Batteries (RBNode RBSet RBMap)

namespace RelayStorageLayer

/-! ## 1. `Std.TransCmp` instances for the map key comparators

`Storage = Batteries.RBMap UInt256 UInt256 compare` and
`AddrMap α = Batteries.RBMap AccountAddress α compare`.
The Batteries round-trip lemmas need `Std.TransCmp compare`, which does not
synthesize for `UInt256`'s derived `Ord` nor `AccountAddress`'s custom `Ord`.
We build both by transferring from the underlying `Fin`/`Nat` comparators. -/

/-- The derived `compare` on `UInt256` is `(compare a.val b.val).then .eq`,
which equals `compare a.val b.val` because `o.then .eq = o`. -/
theorem uint_compare_eq (a b : UInt256) : compare a b = compare a.val b.val := by
  show (compare a.val b.val).then Ordering.eq = compare a.val b.val
  cases compare a.val b.val <;> rfl

instance uint_transcmp : Std.TransCmp (compare : UInt256 → UInt256 → Ordering) where
  eq_swap {a b} := by rw [uint_compare_eq, uint_compare_eq]; exact Std.OrientedCmp.eq_swap
  isLE_trans {a b c} h1 h2 := by
    rw [uint_compare_eq] at h1 h2 ⊢; exact Std.TransCmp.isLE_trans h1 h2

/-- `AccountAddress`'s custom `Ord` compares the underlying `Nat` `.val`, so this
holds definitionally; transfer `TransCmp` from `Nat`. -/
instance addr_transcmp : Std.TransCmp (compare : AccountAddress → AccountAddress → Ordering) where
  eq_swap {a b} := Std.OrientedCmp.eq_swap
  isLE_trans {a b c} h1 h2 := Std.TransCmp.isLE_trans h1 h2

/-! ## 2. `find? cut (erase cut ...) = none` for Batteries `RBMap`

There is no `find?_erase` lemma in the pinned Batteries RBMap API, so we derive it.
`erase` is `(del cut ·).setBlack`; `find?` ignores the root colour; and `del cut`,
on an ordered tree, removes every element on which a strict `cut` returns `.eq`. -/

universe u
variable {α : Type u}

/-- `find?` ignores the root recolouring performed by `setBlack`. -/
theorem find?_setBlack (cut : α → Ordering) (t : RBNode α) :
    (t.setBlack).find? cut = t.find? cut := by
  cases t <;> rfl

/-- Every element surviving `del cut` fails the (strict) cut, when the input is ordered. -/
theorem all_del_ne {cmp : α → α → Ordering} {cut : α → Ordering}
    [Std.TransCmp cmp] [IsStrictCut cmp cut] :
    ∀ {t : RBNode α}, t.Ordered cmp → (RBNode.del cut t).All (fun x => cut x ≠ Ordering.eq)
  | .nil, _ => trivial
  | .node c a y b, ht => by
    obtain ⟨hay, hyb, ha, hb⟩ := ht
    have ihA := all_del_ne (cut := cut) (t := a) ha
    have ihB := all_del_ne (cut := cut) (t := b) hb
    -- if `cmp x y` disagrees with `cut y`, then `x` cannot match a strict cut
    have key : ∀ {x : α}, cmp x y ≠ cut y → cut x ≠ Ordering.eq :=
      fun {x} h hx => h (IsStrictCut.exact hx)
    unfold RBNode.del
    split
    · next hy =>          -- cut y = .lt : recurse left, keep `y` and all of `b`
      have hPy : cut y ≠ Ordering.eq := by rw [hy]; decide
      have hPb : b.All (fun x => cut x ≠ Ordering.eq) := by
        refine hyb.imp (fun {x} hx => ?_)
        have hyx : cmp y x = Ordering.lt := cmpLT_iff.1 hx
        have hxy : cmp x y = Ordering.gt := Std.OrientedCmp.gt_iff_lt.2 hyx
        exact key (by rw [hxy, hy]; decide)
      split
      · exact All.balLeft ihA hPy hPb
      · exact ⟨hPy, ihA, hPb⟩
    · next hy =>          -- cut y = .gt : recurse right, keep `y` and all of `a`
      have hPy : cut y ≠ Ordering.eq := by rw [hy]; decide
      have hPa : a.All (fun x => cut x ≠ Ordering.eq) := by
        refine hay.imp (fun {x} hx => ?_)
        have hxy : cmp x y = Ordering.lt := cmpLT_iff.1 hx
        exact key (by rw [hxy, hy]; decide)
      split
      · exact All.balRight hPa hPy ihB
      · exact ⟨hPy, hPa, ihB⟩
    · next hy =>          -- cut y = .eq : drop `y`, append `a` and `b`
      have hPa : a.All (fun x => cut x ≠ Ordering.eq) := by
        refine hay.imp (fun {x} hx => ?_)
        have hxy : cmp x y = Ordering.lt := cmpLT_iff.1 hx
        exact key (by rw [hxy, hy]; decide)
      have hPb : b.All (fun x => cut x ≠ Ordering.eq) := by
        refine hyb.imp (fun {x} hx => ?_)
        have hyx : cmp y x = Ordering.lt := cmpLT_iff.1 hx
        have hxy : cmp x y = Ordering.gt := Std.OrientedCmp.gt_iff_lt.2 hyx
        exact key (by rw [hxy, hy]; decide)
      exact All.append hPa hPb

/-- `find? cut (del cut t) = none` on an ordered tree for a strict cut. -/
theorem find?_del_eq_none {cmp : α → α → Ordering} {cut : α → Ordering}
    [Std.TransCmp cmp] [IsStrictCut cmp cut] {t : RBNode α} (ht : t.Ordered cmp) :
    RBNode.find? cut (RBNode.del cut t) = none := by
  have hall := all_del_ne (cmp := cmp) (cut := cut) ht
  cases hfind : RBNode.find? cut (RBNode.del cut t) with
  | none => rfl
  | some x =>
    have hx_mem : x ∈ RBNode.del cut t := find?_some_mem hfind
    have hx_eq : cut x = Ordering.eq := find?_some_eq_eq hfind
    exact absurd hx_eq ((All_def.1 hall) x hx_mem)

/-- `RBSet.findP?` after erasing by the same cut is `none`. -/
theorem RBSet_findP?_erase_self {cmp' : α → α → Ordering} [Std.TransCmp cmp']
    (t : RBSet α cmp') (cut : α → Ordering) [IsStrictCut cmp' cut] :
    (RBSet.erase t cut).findP? cut = none := by
  show RBNode.find? cut ((RBNode.del cut t.1).setBlack) = none
  rw [find?_setBlack]
  exact find?_del_eq_none t.2.out.1

/-- `RBMap.find?` after erasing the same key is `none`. -/
theorem RBMap_find?_erase_self {β : Type u} {cmp : α → α → Ordering}
    [Std.TransCmp cmp] (t : RBMap α β cmp) (k : α) :
    (t.erase k).find? k = none := by
  show ((RBSet.erase t (cmp k ·.1)).findP? (cmp k ·.1)).map (·.2) = none
  rw [RBSet_findP?_erase_self]
  rfl

/-! ## 3. `UInt256` equality from `BEq`

`UInt256` derives `BEq` but has no `LawfulBEq` instance; however the derived
`BEq` reduces to the `Fin` one, which is lawful. -/
theorem uint_eq_of_beq {a b : UInt256} (h : (a == b) = true) : a = b := by
  cases a with
  | mk av =>
    cases b with
    | mk bv =>
      have h' : (av == bv) = true := h
      have : av = bv := eq_of_beq h'
      rw [this]

/-! ## 4. Storage round-trip on an `Account` -/

/-- Storing `v` at key `k` and reading it back yields `v`, in both the
`insert` (`v ≠ 0`) and `erase` (`v = 0`) branches of `updateStorage`. -/
theorem updateStorage_lookupStorage {τ} (acc : Account τ) (k v : UInt256) :
    (acc.updateStorage k v).lookupStorage k = v := by
  unfold Account.lookupStorage Account.updateStorage
  split
  · next h =>          -- v == default : storage erased, read back the default 0
    show (acc.storage.erase k).findD k ⟨0⟩ = v
    rw [Batteries.RBMap.findD, RBMap_find?_erase_self]
    exact (uint_eq_of_beq h).symm
  · next _ =>          -- v ≠ default : storage inserted
    show (acc.storage.insert k v).findD k ⟨0⟩ = v
    rw [Batteries.RBMap.findD, Batteries.RBMap.find?_insert_of_eq _ Std.ReflCmp.compare_self]
    rfl

/-! ## 5. `sstore` preserves `executionEnv` and inserts into `accountMap` -/

/-- `sstore` leaves `executionEnv.codeOwner` unchanged (present-account branch). -/
theorem sstore_codeOwner {τ} (self : State τ) (k v : UInt256) (acc : Account τ)
    (hpresent : self.lookupAccount self.executionEnv.codeOwner = some acc) :
    (State.sstore self k v).executionEnv.codeOwner = self.executionEnv.codeOwner := by
  unfold State.sstore
  simp only [hpresent, Option.option]
  rfl

/-- `sstore` sets the owner's account to `acc.updateStorage k v` in `accountMap`. -/
theorem sstore_accountMap {τ} (self : State τ) (k v : UInt256) (acc : Account τ)
    (hpresent : self.lookupAccount self.executionEnv.codeOwner = some acc) :
    (State.sstore self k v).accountMap
      = self.accountMap.insert self.executionEnv.codeOwner (acc.updateStorage k v) := by
  unfold State.sstore
  simp only [hpresent, Option.option]
  rfl

/-! ## 6. The storage round-trip on `State` -/

theorem sstore_sload {τ} (self : EvmYul.State τ) (k v : EvmYul.UInt256)
    (acc : EvmYul.Account τ)
    (hpresent : self.lookupAccount self.executionEnv.codeOwner = some acc) :
    ((EvmYul.State.sstore self k v).sload k).2 = v := by
  -- `(sload s k).2` is definitionally the `.option` of `s`'s owner account
  show Option.option (⟨0⟩ : UInt256) (Account.lookupStorage (k := k))
        ((State.sstore self k v).lookupAccount
          (State.sstore self k v).executionEnv.codeOwner) = v
  -- reduce the codeOwner used by `sload` to the original one
  rw [sstore_codeOwner self k v acc hpresent]
  -- the owner's account after `sstore` is exactly `acc.updateStorage k v`
  have hla : (State.sstore self k v).lookupAccount self.executionEnv.codeOwner
      = some (acc.updateStorage k v) := by
    unfold State.lookupAccount
    rw [sstore_accountMap self k v acc hpresent]
    exact Batteries.RBMap.find?_insert_of_eq _ Std.ReflCmp.compare_self
  rw [hla]
  -- `Option.option ⟨0⟩ (·.lookupStorage k) (some ..) = (..).lookupStorage k = v`
  show (acc.updateStorage k v).lookupStorage k = v
  exact updateStorage_lookupStorage acc k v

/-! ## 7. The exec-level SSTORE effect and the storage-write-reads-back composition

We now lift the `State`-level round trip to NethermindEth's real Yul interpreter
(`EvmYul.Yul.exec`/`execPrimCall`/`primCall`/`step`), modelling Relay.sol's accept-branch
storage write `sstore(merkleRootsPrivate[protocolId][votingRoundId], merkleRoot)`
(`Relay.sol:1394`). The nested-mapping slot is the deterministic key `K`; we prove that
executing `sstore(K, v)` then loading `K` back yields `v`.

Two subtleties versus the pure `State`-level facts above:

* **`step` shape.** SSTORE is a state-transformer op with no stack output, so
  `step .Yul SSTORE none s [key, val]` dispatches (via `dispatchBinaryStateOp .Yul State.sstore`,
  `Semantics.lean:372`) through `Yul.binaryStateOp`, which applies `State.sstore` to `s.toState`
  and writes the result back with `Yul.State.setState`. Hence the post-state is
  `s.setState (State.sstore s.toState key val)` and the returned literal is `none`.

* **The static-mode permission guard.** `primCall` (`Yul/Interpreter.lean:70`) throws
  `.StaticModeViolation` when `¬s.executionEnv.perm ∧ prim ∈ [.SSTORE, …]`. A normal
  (non-`staticcall`) `relay()` call has `perm = true`, so we take `hperm : s.executionEnv.perm = true`
  (the `perm` flag reached through `EvmYul.Yul.State.executionEnv`). Rewriting with `hperm` collapses
  the guard's condition to `False`, so the `if` takes the else branch and no exception is thrown. -/

/-- With no bind variables the post-call `multifill'` is the identity (all three `State` shapes). -/
theorem multifill_nil (s : EvmYul.Yul.State) : EvmYul.Yul.State.multifill [] [] s = s := by
  cases s <;> rfl

set_option maxHeartbeats 1000000 in
/-- `step` of SSTORE at the Yul level: a stack-output-free state transformer that applies
`EvmYul.State.sstore` to `s.toState` and writes it back via `setState` (returned literal `none`). -/
theorem step_SSTORE (s : EvmYul.Yul.State) (key val : EvmYul.UInt256) :
    EvmYul.step (τ := .Yul) Operation.SSTORE none s [key, val]
      = .ok (s.setState (EvmYul.State.sstore s.toState key val), none) := by
  unfold EvmYul.step; rfl

set_option maxHeartbeats 4000000 in
/-- **Exec-level `sstore(key, val)` effect.** Executing the statement `sstore(key, val)` (literal
arguments) through the full `exec → execPrimCall → primCall → step` plumbing writes the value at
`key`, yielding the post-state `s.setState (State.sstore s.toState key val)`. The static-mode guard
of `primCall` is discharged by `hperm : s.executionEnv.perm = true`. Fuel offset `+6` (as
`mstore_lit_eff`). -/
theorem sstore_eff (fuel : Nat) (s : EvmYul.Yul.State) (key val : EvmYul.UInt256)
    (hperm : s.executionEnv.perm = true) :
    EvmYul.Yul.exec (fuel + 6)
      (EvmYul.Yul.Ast.Stmt.ExprStmtCall
        (EvmYul.Yul.Ast.Expr.Call (Sum.inl Operation.SSTORE)
          [EvmYul.Yul.Ast.Expr.Lit key, EvmYul.Yul.Ast.Expr.Lit val])) none s
    = .ok (s.setState (EvmYul.State.sstore s.toState key val)) := by
  simp [EvmYul.Yul.exec, EvmYul.Yul.eval, EvmYul.Yul.evalArgs, EvmYul.Yul.evalTail,
        EvmYul.Yul.execPrimCall, EvmYul.Yul.primCall,
        EvmYul.Yul.cons', EvmYul.Yul.reverse', EvmYul.Yul.multifill', step_SSTORE, multifill_nil,
        hperm]

set_option maxHeartbeats 4000000 in
/-- **Storage write reads back (the R5.3 payoff).** Executing `sstore(K, v)` and then loading slot
`K` back yields exactly `v`. Composes `sstore_eff` (the post-exec state is `State.sstore s.toState K v`)
with `sstore_sload` (that state reads `K` back as `v`), given the owner account is present. This is
the "the relayed Merkle root is stored and reads back at its deterministic nested-mapping slot" fact
for Relay.sol's accept branch (`Relay.sol:1394`). -/
theorem sstore_reads_back (fuel : Nat) (s : EvmYul.Yul.State) (K v : EvmYul.UInt256)
    (acc : EvmYul.Account .Yul)
    (hperm : s.executionEnv.perm = true)
    (hpresent : s.toState.lookupAccount s.toState.executionEnv.codeOwner = some acc) :
    ∃ post, EvmYul.Yul.exec (fuel + 6)
        (EvmYul.Yul.Ast.Stmt.ExprStmtCall
          (EvmYul.Yul.Ast.Expr.Call (Sum.inl Operation.SSTORE)
            [EvmYul.Yul.Ast.Expr.Lit K, EvmYul.Yul.Ast.Expr.Lit v])) none s
        = .ok post ∧ (post.toState.sload K).2 = v := by
  refine ⟨_, sstore_eff fuel s K v hperm, ?_⟩
  cases s with
  | Ok ss vs =>
    show ((EvmYul.State.sstore ss.toState K v).sload K).2 = v
    exact sstore_sload ss.toState K v acc hpresent
  | OutOfFuel => exact absurd hperm (by decide)
  | Checkpoint j =>
    have hf : (EvmYul.Yul.State.Checkpoint j).executionEnv.perm = false := rfl
    rw [hf] at hperm
    exact absurd hperm (by decide)

/-! ## 8. Hole-freeness checks -/

#print axioms uint_transcmp
#print axioms addr_transcmp
#print axioms find?_del_eq_none
#print axioms RBMap_find?_erase_self
#print axioms uint_eq_of_beq
#print axioms updateStorage_lookupStorage
#print axioms sstore_codeOwner
#print axioms sstore_accountMap
#print axioms sstore_sload
#print axioms multifill_nil
#print axioms step_SSTORE
#print axioms sstore_eff
#print axioms sstore_reads_back

end RelayStorageLayer
