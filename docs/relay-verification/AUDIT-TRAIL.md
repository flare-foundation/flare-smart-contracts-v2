# Current formal-verification audit trail

This audit trail maps each current assurance objective to the mechanism that
checks it and the normalized evidence that records the result.

## Source-to-evidence chain

```text
Relay.sol + interfaces + harnesses/specifications
                       |
                       v
          verification-manifest.json
             /         |          \
            v          v           v
      artifact/ABI   Halmos     Lean/Certora
          gates       gate         gates
             \         |          /
              v        v         v
              normalized JSON reports
                       |
                       v
               relay-fv-bundle.json
```

The formal-report arrows are machine-checked. A release-eligible bundle rejects
different source revisions, manifest hashes, compiler settings, dirty-state
generation, imported diagnostic inputs, missing inventories, and incompatible
report schemas. `--allow-dirty` can produce a development-only bundle. Concrete
Foundry results are supplementary unless a normalized Foundry report is added to
the bundle.

## Traceability matrix

| Assurance objective | Mechanism | Source artifact | Normalized evidence |
| --- | --- | --- | --- |
| Production target identity | lock-recreated deployment compile and provenance capture | `scripts/relay-artifact-provenance.js`, Hardhat config and locks | generated `relay-deployment.json` |
| Assembly custom-error ABI | selector/interface/use-count and canonical four-byte revert scan | manifest ABI inventory, `Relay.sol`, `IRelay.sol` | generated `relay-custom-error-abi.json` |
| FV/deployment program equality and layout drift | compiler/settings check, metadata-stripped bytecode comparison, optimized-Yul byte comparison, normalized sequential-storage-layout comparison | `verify_relay_artifact.py`, committed Yul and `relay_storage_layout.json` baselines | generated `relay-artifact-parity.json` |
| Bounded signature-slot accounting | symbolic compiled-bytecode execution plus accepting reachability witnesses | `RelaySigFV`, `RelaySigParamFV`, `RelayModelBridgeFV` | generated `relay-halmos.json` |
| Canonical signature gates and precompile ABI | bounded symbolic execution; concrete EVM precompile tests are supplementary | `RelayCanonicalityFV`, `RelayEcrecoverSymbolicFV`, `RelayEcrecoverABI` | generated Halmos report; separate Foundry output |
| Epoch/policy state machine and `oldRelay` mode compatibility | bounded symbolic compiled-bytecode execution | epoch, delay, window, rotation, mode, and `RelayConstructorFV` harnesses listed by manifest | generated `relay-halmos.json` |
| Random/Merkle binding | bounded symbolic compiled-bytecode execution | random binding, monotonicity, security normalization, and Merkle harnesses | generated `relay-halmos.json` |
| Local native fee and return semantics | bounded symbolic compiled-bytecode execution plus native-balance Lean lemmas | fee-conservation, verify-fee, return-discriminator harnesses, and `RelayFeeLayer.lean` | generated Halmos and Lean reports |
| Pre-boundary delegated value flow | bounded symbolic execution of the real proxy against compatible observable sources; CVL external-call value/target observations | `RelayOldRelayFeeFV` zero-value, full-refund, getter-independence, and positive-fee fail-closed checks; `oldRelayDelegationForwardsNoValueAndRefundsOnSuccess` | generated Halmos report; Certora cloud report only when current and complete |
| Token fee and fee-table semantics | bounded symbolic execution against a deterministic exact-transfer ERC-20; storage CVL rules where declared | `RelayFeeTokenFV`, constructor/owner-mode harnesses, and manifest-declared Certora rules | generated Halmos report; Certora cloud report only when current and complete |
| Owner/timelock/UUPS modeled behavior | bounded symbolic execution; CVL transition rules; concrete governance tests are supplementary | access-control and owner-timelock harnesses, including duplicate-queue ETA replacement and queued-call survival across ownership transfer; `ownershipTransferPreservesQueuedCall` | generated Halmos report and separate Foundry output; Certora cloud report only when current and complete |
| Exact protocol-1 threshold arithmetic | bounded compiled-bytecode checks and unbounded Lean arithmetic | threshold override/scaling harnesses and `RelaySigLoop.lean` | generated Halmos and Lean reports |
| Unbounded policy-slot threshold theorem | Lean induction over arbitrary policy/signature lengths | `RelaySigLoop.lean` | generated `relay-lean.json` |
| Conditional EVM/Yul refinement | Lean proof over pinned EVMYulLean semantics | `lean/bytecode-refinement/*.lean` | generated `relay-lean.json` |
| CVL configuration/rule integrity | exact munge, compile, and CVL typecheck | `certora/Relay*.conf`, `certora/specs/*.spec` | generated `relay-certora-local.json` |
| CVL prover outcomes | cloud prover plus normalized logs/job archives | manifest-declared Certora configs | generated `relay-certora-cloud.json`, when current and complete |
| Cross-gate consistency | report schema, source/manifest/tool/provenance checks | `verify_bundle.py` | generated `relay-fv-bundle.json` |

The manifest is authoritative for the exact harness, theorem, and rule
inventory; representative names above are navigation aids.

The storage snapshot is the current first-deployment sequential Solidity layout.
The comparison is a future-upgrade review tripwire: a slot, offset, order, or
type change in the compiler-emitted `storageLayout` output is rejected until
explicitly reviewed and rebaselined. ERC-7201 namespaces and EIP-1153 transient
slots are outside the snapshot. It makes no compatibility claim about unknown
future implementation behavior.

## Claim interpretation trail

For each assurance objective, review in this order:

1. the exact property and assumptions in
   [`10-claims-ledger-trust-and-residual.md`](10-claims-ledger-trust-and-residual.md);
2. the harness/theorem/specification statement;
3. the corresponding manifest entry;
4. the constituent report's tool result and generation provenance; and
5. the aggregate bundle's source/manifest consistency decision.

The current security findings in
[`../relay-security-review.md`](../relay-security-review.md) identify inputs that
positive proof fixtures may exclude. Those findings remain open unless the
contract enforces the premise and a regression/proof covers every admission or
state-transition path.

## Evidence maintenance rule

Any change to Relay source, interfaces used by Relay, compiler settings,
deployment build inputs, proof harnesses, Lean files, Certora files, manifest, or
normalized gate logic requires regeneration of every affected report followed by
the aggregate bundle. Documentation changes alone do not alter a theorem, but a
release bundle still requires a clean committed tree so provenance is exact.
