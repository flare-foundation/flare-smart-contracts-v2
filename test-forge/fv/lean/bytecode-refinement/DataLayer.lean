import EvmYul.UInt256
open EvmYul

/-!
# BR-1 (data layer) — foundation bricks

Work toward discharging **BR-1** from the claims ledger: that each signature-loop iteration's accumulated
value is the registered weight `mload(weights[i]) = w[i]`. This file collects the **hole-free** sub-results
of that data-layer refinement, committed incrementally (no `sorry`/`admit`).

Status (see the verification docs, `docs/relay-verification/10-claims-ledger-trust-and-residual.md` §10.5):

* **Byte-decode round-trip — DONE (below).** The big-endian encode/decode is the identity, proved about
  EVMYulLean's actual public functions (it reuses EVMYulLean's existing `@[simp] fromBytes'_toBytes'`,
  which fires downstream even though it is `private`).
* **Keystone (`mload∘mstore` round-trip) — reduced, in progress.** It collapses (via the
  `ffi.ByteArray.zeroes` spec) to `(src.copySlice 0 mem d 32).extract d (d+32) = src`, which `ByteArray.ext`
  turns into a pure `Array.extract`/`append` goal. EVMYulLean's pinned **Lean 4.22.0 has no ByteArray
  lemma layer**, so this must be proven at the `Array.data` level (4.22's `Init/Data/Array/Extract.lean`
  has the needed lemmas) — feasible, no fundamental obstacle, but multi-day Array work.
-/

namespace RelayDataLayer

/-- BR-1 brick: the big-endian byte encode/decode is the identity, about EVMYulLean's real functions. -/
theorem fromBytesBigEndian_toBytesBigEndian (n : Nat) :
    fromBytesBigEndian (toBytesBigEndian n) = n := by
  simp [fromBytesBigEndian, toBytesBigEndian]

#print axioms fromBytesBigEndian_toBytesBigEndian
end RelayDataLayer
