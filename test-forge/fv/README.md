# `test-forge/fv/` — the Relay formal-verification suite (a reader's guide)

This directory holds the machine-checked proofs about `Relay.sol`. The narrative,
audit-facing companion is [`docs/relay-verification/`](../../docs/relay-verification/),
starting at [`00-README.md`](../../docs/relay-verification/00-README.md). This file
explains how to read, run, and audit the verification tooling.

The exact manifest defines the Halmos proof and reachability inventories. It
covers signing-policy admission and rotation, `relay()`, Merkle proofs,
randomness, native/token fees and fee-table replacement, owner timelocks/UUPS,
protocol-1 threshold overrides, source-domain policy hashing, and `oldRelay`
mode and value-flow behavior. The reproducible gates below establish a verdict for the
checked-out source; durable prose does not duplicate mutable check counts.

---

## 1. The one-paragraph mental model

We prove related properties at increasing fidelity. Foundry runs the **real compiled bytecode** on
concrete and random inputs. **Halmos** runs the Solidity harness **symbolically** — every
function argument becomes a logical variable and the [SMT solver](../../docs/relay-verification/CONCEPTS.md#smt-solver) either proves the assertion for _all_ inputs
(in a bounded region) or returns a concrete counterexample. **Lean + EVMYulLean** lifts the signature-loop
accounting argument to a `∀N` theorem against a validated model of the EVM. Cryptography
(`ecrecover`, `keccak`) is never proved — it is modeled as
an **uninterpreted function**, which is the sound, conservative choice (see §5).

New to the vocabulary (SMT, induction, CEX, psAt)? The plain-words FAQ is
[`docs/relay-verification/CONCEPTS.md`](../../docs/relay-verification/CONCEPTS.md).

If you read only one thing next, read a small proof end to end:
[`RelaySigFV.t.sol`](RelaySigFV.t.sol) (Halmos) and [`lean/RelaySigLoop.lean`](lean/RelaySigLoop.lean) (Lean).

---

## 2. Reading a Halmos proof (`*FV.t.sol`)

A Halmos harness is an ordinary Foundry test contract, but functions named **`check_…`** are read by Halmos
as **proof obligations**, not example runs. The translation to logic:

| Solidity in a `check_` function                         | Logical meaning                                                            |
| ------------------------------------------------------- | -------------------------------------------------------------------------- |
| the function's **parameters** (`uint8 v, bytes32 r, …`) | **universally quantified** symbolic inputs (∀)                             |
| `vm.assume(P);`                                         | a **hypothesis** — restrict the ∀ to states where `P` holds                |
| `assert(Q);`                                            | the **goal** — Halmos proves `Q` on every path, or prints a counterexample |
| a call into `Relay`                                     | symbolic execution of the **real compiled bytecode**                       |
| `ecrecover` / precompile `0x01`                         | an **uninterpreted function** (see §5)                                     |

So `check_threshold_twoVoters_cannotAccept(...)` reads: _for all signatures, two voters carrying weight
≤ threshold can never make `relay()` accept._ Halmos discharges it by symbolic execution + SMT (z3 / cvc5 /
bitwuzla). A **pass** means "no counterexample exists in the bounded region"; a **fail** prints the exact
calldata that breaks the property.

**Two non-obvious things a newcomer must know:**

1. **Loop unrolling (`--loop`).** Halmos unrolls loops a fixed number of times (default **2**). `relay()`'s
   signature loop runs once per signature, so at the default bound a proof about 3+ signatures silently has
   its accepting iteration _truncated_ — the accept path looks unreachable and negative properties pass
   **vacuously** (true, but for the wrong reason). This project sets `loop = 6` in
   [`../../halmos.toml`](../../halmos.toml). Reachability controls fail closed if the configured bound
   cannot reach the intended acceptance path.

2. **The anti-vacuity control.** Because a vacuous pass is worthless, every harness carries a **reachability
   control** that asserts the _negation_ of a reachable event, so Halmos **must refute it with a [witness](../../docs/relay-verification/CONCEPTS.md#reachability-and-vacuity)**.
   The gate script
   [`verify_fv.py`](verify_fv.py) enforces both halves: every `check_` proof must PASS **and** every
   declared control must produce a **validated counterexample model**. A timeout, stuck path, exception,
   all-revert result, invalid model, or truncated loop is never accepted as a witness.

### 2.1 The proof and compatibility inventories (normative)

[`verification-manifest.json`](verification-manifest.json) is the source of truth for expected behavior:

| Rule                                                 | Where established                                    | Effect                                                                                                          |
| ---------------------------------------------------- | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| name starts with **`check_`**                        | the manifest's `function_prefix` is passed to Halmos | Halmos discovers the symbolic obligation                                                                        |
| identifier is in `halmos.proofs`                     | explicit manifest entry                              | only Halmos exit code `PASS` is healthy                                                                         |
| identifier is in `halmos.reachability`               | explicit manifest entry                              | only exit code `COUNTEREXAMPLE` with a validated model is healthy                                               |
| result is missing or undeclared                      | exact set comparison in `verify_fv.py`               | hard failure; deleting or silently adding a check cannot leave CI green                                         |
| assembly error is in `relay_custom_error_abi.errors` | explicit signature, selector, and use count          | `verify_relay_custom_error_abi.py` rejects selector/interface/use-site drift or non-canonical four-byte reverts |

Consequences to respect when adding checks:

- Add the fully-qualified identifier to exactly one manifest list. The `reach` naming convention is
  a readability aid; explicit manifest membership controls the machine verdict.
- **Every `check_` function carries a matching `EXPECT:` line** in the comment block directly above it, so
  the intent is readable at the function and greppable against the convention:
  - proofs end with `EXPECT: PASS` (canonical dedicated line: `// EXPECT: PASS (proof).`),
  - reachability controls with `EXPECT: COUNTEREXAMPLE` (canonical:
    `// EXPECT: COUNTEREXAMPLE (reachability control).`).

Run the whole gate the way CI does (`test-fv-halmos`). Fresh clone? `./scripts/bootstrap-fv.sh` sets up
everything (node deps, forge build, the reference venv `./.venv-halmos`) and ends by running this gate:

```bash
python3 test-forge/fv/verify_relay_custom_error_abi.py \
  --report-output verification-reports/relay-custom-error-abi.json
FORGE=/path/to/manifest-pinned-forge HALMOS=$PWD/.venv-halmos/bin/halmos \
  .venv-halmos/bin/python test-forge/fv/verify_fv.py \
  --report-output verification-reports/relay-halmos.json
```

The first command enforces the current `relay()` assembly custom-error ABI. The
exact manifest pins the constants, error signatures, selectors, use counts, and
canonical four-byte revert encoding.

Before invoking Halmos, the proof gate clean-installs the checksummed Soldeer tree,
checks the pinned Foundry version/commit, and force-rebuilds the complete FV harness
tree with solc 0.8.35, Cancun, optimizer 200, and viaIR. Both that build and Halmos's
internal Forge build are confined to the manifest-derived `test-forge/fv` source/test
root under a sanitized, audited Foundry environment. Repository-wide compiler-profile
variants and path restrictions are disabled, so Halmos consumes one unambiguous artifact
per contract and unrelated mixed-version sources cannot enter the proof build. The gate pins the tracked config, loop bound,
artifact directory, and Z3 solver on the child command, then hashes and audits the exact
compiler settings, source binding, and semantic bytecode of Relay,
RelayProxy, and all declaring harness contracts before and after symbolic
execution. Any extra Halmos CLI arguments are diagnostic-only and can never mint
release evidence.

CI also runs [`verify_relay_artifact.py`](verify_relay_artifact.py). It recompiles Relay with the pinned FV
compiler, proves that its metadata-stripped creation and runtime bytecode equal the Hardhat deployment
artifact, byte-compares the generated optimized Yul with the committed Lean source snapshot, and compares
the compiler-normalized sequential Solidity storage layout with the committed first-deployment baseline.
Solidity's `storageLayout` output does not enumerate state addressed through ERC-7201 namespace constants
(including OpenZeppelin `Initializable`) or EIP-1153 transient slots. Those are outside this layout snapshot
and require their separate source-level and behavioral checks. The sequential-layout comparison is a
future-upgrade drift tripwire, not a proof of compatibility with unknown future code. The gate emits
normalized JSON evidence consumed by the final bundle gate.

Every normalized report captures HEAD plus a hash/count of the complete Git
porcelain state at gate start and end. Only a passing in-process run that starts
and ends on the same clean HEAD is release eligible. Imported Halmos JSON
(`--results-input`) is explicitly development-only and content-bound by its raw
SHA-256; imported Forge artifact/IR inputs and custom-error source overrides receive
the same diagnostic-only treatment. Release evidence must come from each verifier's
in-process build/tool child. The Forge gates replace and hash ignored Soldeer inputs;
the deployment gate force-recreates lock-pinned node modules and Hardhat outputs;
and the Lean gate requires clean pinned EVMYulLean/package checkouts, refreshes the
pinned Lake caches, and clean-rebuilds EVMYul before importing it. Restoring a dirty checkout after a run cannot promote
that report. The
bundle rejects any development-only constituent unless `--allow-dirty` is used,
in which case the bundle itself remains development-only.

---

## 3. Reading a Lean proof (`lean/…`)

The R4 proofs are in [Lean 4](lean/) and are checked against **EVMYulLean** (NethermindEth's Lean
formalization of EVM/Yul, itself validated against the standard `ethereum/tests` EVM conformance suite, incl. EEST-generated fixtures). Two entry points:

- [`lean/RelaySigLoop.lean`](lean/RelaySigLoop.lean) — the abstract `∀N ∀K` accounting proof, pure `ℕ`/`List`,
  no EVM. `threshold_sound` unconditionally says _accept ⟹ total registered policy-slot weight > threshold_
  under its indexed-run premises. Only the stronger distinct-signer interpretation requires unique voter
  addresses at admission.
- [`lean/bytecode-refinement/`](lean/bytecode-refinement/) — the same soundness lifted onto a loop executed by
  the _validated EVM semantics_, for all N. See its [`README.md`](lean/bytecode-refinement/README.md).

The Lean fee layer covers the local native-coin branch under
`feeToken == address(0)`. Pre-boundary `oldRelay` delegation is covered by its
bounded compiled-bytecode harness and, when a current complete cloud report is
available, CVL external-call observations. ERC-20 `transferFrom`, SafeERC20
return behavior, allowances, and enumerable fee-table replacement are covered
only by the bounded Solidity/CVL layers and retain the standard
exact-transfer-token assumption.

**"[Hole-free](../../docs/relay-verification/CONCEPTS.md#hole-free-lean-proof-and-axiom-audit)" is a precise claim, and you can check it yourself.** Every declared audited result has a
`#print axioms` directive. A proof is trusted when that list is a subset of
`[propext, Classical.choice, Quot.sound]` — Lean's three standard
axioms — with **no `sorryAx`** (no gaps) and **no `Lean.ofReduceBool`** (no `native_decide`). The manifest
also explicitly allows three local axioms: `RelayDataLayer.zeroes_data`,
`RelayDataLayer.toByteArray_size`, and `RelayWindows.zeroes_data`. They are semantic assumptions of the
current proofs. [`lean/bytecode-refinement/AXIOM_DISCHARGE.md`](lean/bytecode-refinement/AXIOM_DISCHARGE.md)
documents how upstream definitions/visibility changes would let these declarations be replaced by
theorems. To re-check:

```bash
git clone https://github.com/NethermindEth/EVMYulLean /tmp/evmyul2
cd /tmp/evmyul2 && git checkout 047f63070309f436b66c61e276ab3b6d1169265a  # pinned by the manifest
lake exe cache get && lake clean && lake build EvmYul           # Lean 4.22.0
cp <repo>/test-forge/fv/lean/RelaySigLoop.lean . && lake env lean RelaySigLoop.lean   # exit 0
```

---

## 4. Certora

[`../../certora/specs/RelayInvariants.spec`](../../certora/specs/RelayInvariants.spec) specifies storage
  invariants in CVL. External boundaries use explicit summaries: queued execution pessimistically
  dispatches the five modeled owner calls, while unmatched external calls use an ECF fallback that
  cannot mutate Relay storage; `ecrecover` remains nondeterministic. The fee-token rules cover
  setter-mode exclusion, native-getter behavior, fee mapping/enumeration lockstep, reserved IDs,
  proof-before-token-call ordering, and the configured token call target. They do not model ERC-20
  balance deltas; the exact-transfer Halmos fixture covers that bounded behavior under the standard-token
  assumption. The write-once/timelock specification also observes zero-value
  `oldRelay` delegation with a full-refund witness and preservation of sampled
  queued-call state across ownership transfer. Those are cloud proof claims only
  when the normalized report is current and complete.
  [`verify_certora_local.py`](verify_certora_local.py) fail-closes on compiler,
  CVL typecheck, config, toolchain, and munge drift. It is not a cloud-proof
  substitute.

---

## 5. Cryptography is assumed, not proved — and why that is sound

`ecrecover` and `keccak256` are modeled as **uninterpreted functions**: deterministic (same inputs → same
output) but otherwise unconstrained. For `ecrecover` this hands the _adversary more power than reality_ — when
hunting a counterexample the solver may freely make the recovered signer equal any voter it likes. Any
accounting invariant that survives this (e.g. "cannot accept below total policy-slot weight" or "no slot index
is reused") therefore holds _a fortiori_ under real ECDSA. Distinct voter addresses
are a separate policy-admission premise and are not currently enforced on-chain.
What is **not** proved is "a non-voter cannot forge a signature" — that is ECDSA
unforgeability, a cryptographic fact outside the EVM model.

One subtlety is load-bearing: the **precompile `0x01` does not
revert on a bad signature** — it returns _success with empty return data_ (`returndatasize()==0`) and leaves
the caller's output buffer _stale_. This differs from Solidity's high-level `ecrecover`, which returns
`address(0)`. `Relay.sol` calls the precompile in raw assembly, so it must guard with `staticcall` success +
`returndatasize()==32` + non-zero signer. That failure ABI is pinned concretely by
[`RelayEcrecoverABI.t.sol`](RelayEcrecoverABI.t.sol) (real EVM) and proved symbolically by
[`RelayEcrecoverSymbolicFV.t.sol`](RelayEcrecoverSymbolicFV.t.sol), with the trust boundary recorded in
[`docs/relay-verification/10-…`](../../docs/relay-verification/10-claims-ledger-trust-and-residual.md)).

The full trust base — every assumption, where it lives, and how it is discharged — is the claims ledger:
[`docs/relay-verification/10-claims-ledger-trust-and-residual.md`](../../docs/relay-verification/10-claims-ledger-trust-and-residual.md).

---

## 6. File map

**Signature loop / threshold accounting (the core property).**
[`RelaySigFV.t.sol`](RelaySigFV.t.sol) · [`RelaySigParamFV.t.sol`](RelaySigParamFV.t.sol) ·
[`RelayCanonicalityFV.t.sol`](RelayCanonicalityFV.t.sol) (bad-`v`/high-`s` gates) ·
[`RelayModelBridgeFV.t.sol`](RelayModelBridgeFV.t.sol) (bytecode ↔ prefix-sum model).

**ecrecover failure ABI.** [`RelayEcrecoverABI.t.sol`](RelayEcrecoverABI.t.sol) (concrete) ·
[`RelayEcrecoverSymbolicFV.t.sol`](RelayEcrecoverSymbolicFV.t.sol) (symbolic return-data and zero-signer guards).

**Epoch / policy-rotation decision matrix.** [`RelayWrongEpochFV.t.sol`](RelayWrongEpochFV.t.sol) ·
[`RelayDelayedPolicyFV.t.sol`](RelayDelayedPolicyFV.t.sol) ·
[`RelayFinalizationWindowFV.t.sol`](RelayFinalizationWindowFV.t.sol) ·
[`RelayCrossEpochFV.t.sol`](RelayCrossEpochFV.t.sol) ·
[`RelayMustUseNewPolicyFV.t.sol`](RelayMustUseNewPolicyFV.t.sol) ·
[`RelayThresholdScalingFV.t.sol`](RelayThresholdScalingFV.t.sol) ·
[`RelayThresholdConsistencyFV.t.sol`](RelayThresholdConsistencyFV.t.sol) ·
[`RelayThresholdOverrideFV.t.sol`](RelayThresholdOverrideFV.t.sol) ·
[`RelayModeOneFV.t.sol`](RelayModeOneFV.t.sol) · [`RelayEpochAdvanceFV.t.sol`](RelayEpochAdvanceFV.t.sol).

**Randomness / Merkle / fees / misc.** [`RelayRandomMonotonicityFV.t.sol`](RelayRandomMonotonicityFV.t.sol) ·
[`RelayRandomBindingFV.t.sol`](RelayRandomBindingFV.t.sol) ·
[`RelayIsSecureNormFV.t.sol`](RelayIsSecureNormFV.t.sol) ·
[`RelayMerkleProofFV.t.sol`](RelayMerkleProofFV.t.sol) · [`RelayMerkleFoldFV.t.sol`](RelayMerkleFoldFV.t.sol) ·
[`RelayVerifyFeeFV.t.sol`](RelayVerifyFeeFV.t.sol) ·
[`RelayFeeConservationFV.t.sol`](RelayFeeConservationFV.t.sol) ·
[`RelayOldRelayFeeFV.t.sol`](RelayOldRelayFeeFV.t.sol) ·
[`RelayFeeTokenFV.t.sol`](RelayFeeTokenFV.t.sol) ·
[`RelayPolicyHashFV.t.sol`](RelayPolicyHashFV.t.sol) · [`RelaySigParamFV.t.sol`](RelaySigParamFV.t.sol) ·
[`RelayReturnDiscriminatorFV.t.sol`](RelayReturnDiscriminatorFV.t.sol) ·
[`RelayAccessControlFV.t.sol`](RelayAccessControlFV.t.sol) ·
[`RelayConstructorFV.t.sol`](RelayConstructorFV.t.sol) ·
[`RelayOwnerTimelockFV.t.sol`](RelayOwnerTimelockFV.t.sol).

**Harness base + gate + Lean.** [`../unit/protocol/implementation/Relay.t.sol`](../unit/protocol/implementation/Relay.t.sol)
(the shared `RelayTestBase` calldata encoders, reused by the Halmos harnesses) ·
[`verify_fv.py`](verify_fv.py) (the Halmos gate) · [`lean/`](lean/) (Lean proofs).

Do not cite the Halmos inventory as a proof of ECDSA or arbitrary token
semantics. Lean covers indexed accounting, the protocol-1 threshold seam, and
local native-fee balance primitives—not cryptography, delegated/token value
flow, or the complete self-call frame. Certora's local gate establishes compilation, munging, and CVL
typechecking; it is not a cloud prover verdict. Consult the current generated
reports and the claims ledger for the exact evidence boundary.
