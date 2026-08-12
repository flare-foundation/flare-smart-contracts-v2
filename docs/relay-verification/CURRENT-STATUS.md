# Relay formal-verification status

> **Authority and date.** This page is the only current-results summary in this
> documentation set. It was refreshed on 2026-08-12 after pulling
> `relay-owner-timelock` at
> `d5af7136c03d6bab83307b0f4bd49101b8792e40`. Relay now contains an FDC2
> threshold override transported with EIP-1153 transient storage, and
> setter-mode initialization rejects a nonzero fee collector. The local
> deployment, ABI, artifact, Halmos, Lean, and Certora-front-end reports have
> now been regenerated against this HEAD and manifest
> `7ae2208f96a520f477b528ee808909f87e9402247bacab00e04052fa02ec2cb1`.
> Each local report passes, but each is development-only solely because the
> generation checkout was dirty. The aggregate bundle also passes as
> development-only. A supplemental Certora cloud import is PARTIAL: its
> threshold configuration passes, while scalar and write-once remain partial
> because of 24 sanity failures.

## Current evidence

| Gate                          | Current observation on `d5af7136…`                                                                                                                                                                                                              | Evidence boundary / next action                                                                                                  |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Deployment provenance         | **PASS, development-only.** Report SHA-256 `44468783…`.                                                                                                                                                                                         | Re-run from a clean tree for release eligibility.                                                                                |
| Relay custom-error ABI        | **PASS, development-only:** 37/37 assembly selectors. Report SHA-256 `1fb2ca10…`.                                                                                                                                                               | Re-run from a clean tree for release eligibility.                                                                                |
| Deployment/FV artifact parity | **PASS, development-only.** The solc 0.8.35/Cancun/O200/viaIR artifact and regenerated optimized Yul match. Report SHA-256 `0b2a7518…`.                                                                                                         | Re-run from a clean tree for release eligibility.                                                                                |
| Halmos                        | **PASS, development-only:** 123/123 = 86 proofs + 37 validated reachability controls, 0 violations. Report SHA-256 `f591eb78…`.                                                                                                                 | Bounded symbolic evidence only; re-run clean for release eligibility.                                                            |
| Lean                          | **PASS, development-only:** 9/9 files and 183 axiom audits. Report SHA-256 `82fff1ff…`.                                                                                                                                                         | The protocol-1 composition retains an explicit `hsetupThreshold` seam; re-run clean for release eligibility.                     |
| Certora local                 | **PASS, development-only:** 3/3 configs, 15 rules, 0 local violations. Report SHA-256 `9d3ce039…`.                                                                                                                                              | Compilation/munging/CVL typecheck evidence, **not** a prover verdict.                                                            |
| Certora cloud                 | **PARTIAL, supplemental.** Threshold PASS; scalar and write-once PARTIAL. Across the three jobs: 308 `SUCCESS`, 2 validated `SATISFIED`, 24 `SANITY_FAIL`, and 0 semantic counterexamples, `UNKNOWN`, or `TIMEOUT`. Report SHA-256 `93d09d86…`. | The sanity failures prevent promotion of the affected method/rule pairs. This imported report is not a local-bundle constituent. |
| Regression tests              | **Current tests PASS:** full Forge 2,079/2,079; Relay unit file 70/70; exact-BIPS suite 11/11 with 512 fuzz executions; governance 39/39; FDC2 53/53; Hardhat Relay 53/53; FV utilities 109/109.                                                | Add a proof-aware end-to-end FDC2/header regression before enabling nonzero-threshold consumers.                                 |
| Evidence bundle               | **PASS, development-only.** It validates all six current in-process reports. Report SHA-256 `be386d63acdd336b99ab84c64cb0f32ba9c3bafbba02b17164ebd176b7e4f64a`.                                                                                 | `release_eligible=false` solely because the worktree was dirty at generation start/end; re-run clean for release.                |
| Kontrol                       | **Historical/model-only.**                                                                                                                                                                                                                      | Revalidate the model if it is to support current release claims.                                                                 |

The six current local reports bind reviewed source revision `d5af7136…` and manifest `7ae2208f…`.
Their `release_eligible=false` status is attributable solely to the dirty
generation tree, not a failed local obligation. The aggregate bundle validates
all six and has the same development-only boundary. That distinction does not
make them release evidence: a clean, commit-bound rerun and release-eligible
replacement bundle remain required. The current supplemental Certora cloud
report is not a bundle constituent and its PARTIAL status must not be promoted
to an unrestricted proof verdict. The normalized jobs are
[scalar](https://prover.certora.com/output/3798318/96136f4b1ce349889963c722745f6d8a),
[threshold](https://prover.certora.com/output/3798318/a133698c16d54e7cb4a518a3251dd73a),
and
[write-once](https://prover.certora.com/output/3798318/5f29c9d404134b7aa3578484455bf424).

## Security boundary the proofs do not remove

Increasing signature indices prevents a policy **slot** from being counted
twice. It does not make voter addresses unique. All threshold/accounting claims
are therefore conditional on the signing policy containing distinct voter
addresses. The current implementation does not enforce that condition and a
duplicate address can supply multiple signatures for different slots. See
[`13-residual-weaknesses.md`](13-residual-weaknesses.md) for the live issue and
fix proposal.

The UUPS rules also stop at the trusted-upgrade boundary: they check the current
implementation's authorization path and selected storage invariants, not the
semantics of arbitrary replacement bytecode.

The new Relay threshold function is a raw verification primitive. Its
`_messageHash` and `_thresholdBIPS` parameters are independent, so Relay cannot
prove that the threshold equals the value authenticated in an FDC2 response
header. A secure nonzero-threshold consumer must derive it from the signed
header and enforce the matching request, reward-epoch, owner/freshness/replay,
and cosigner policy. Existing in-tree consumers require `thresholdBIPS == 0`;
the nonzero feature remains unintegrated.

The current working tree now computes
`floor(totalWeight * thresholdBIPS / 10000)` and retains the strict `>`
comparison. This is exactly equivalent to
`signedWeight * 10000 > totalWeight * thresholdBIPS`. Concrete tests cover the
3999/4000 boundary, 6000 equality, 9999 with full weight, and a differential
fuzz property. The local rebaseline now covers this rule in three complementary
ways: bounded Halmos checks exercise exact BIPS boundaries,
fallback/isolation, cleanup, rollback, and address scope; Lean proves
floor/strict cross-product equivalence, no wrap, fallback/isolation, and
strict-loop composition; and the passing Certora threshold cloud job proves
the pure exact-arithmetic lemma and that `_thresholdBIPS >= 10000` fails before any
`SSTORE`, `TSTORE`, or external `CALL`. Successful forwarding, transient
cleanup/rollback, and mode isolation are Halmos/Lean claims, not Certora
claims; Certora does not link the pure lemma to the successful Yul-local path.
The Lean refinement capstone deliberately retains
`hsetupThreshold` for the unextracted
`TSTORE -> self-call -> TLOAD -> threshold-local` call-frame seam. Certora local
remains front-end evidence rather than a cloud proof verdict.

Protocol-ID 1 now executes EIP-1153 `TLOAD`, including calls through the legacy
custom-signature entry point. Halmos covers the modeled transient cleanup,
caught-revert rollback, and address-scope behavior, but target-chain
transient-storage support remains a deployment prerequisite rather than a
property established by these reports.

## Exact reproduction commands

Run from the repository root. A current release claim requires reports produced
from the same clean commit.

```bash
# Deployment provenance, assembly custom-error ABI, and bytecode/IR parity
pnpm compile
node scripts/relay-artifact-provenance.js \
  --output verification-reports/relay-deployment.json
python3 test-forge/fv/verify_relay_custom_error_abi.py \
  --report-output verification-reports/relay-custom-error-abi.json
FORGE=/path/to/manifest-pinned-forge .venv-halmos/bin/python \
  test-forge/fv/verify_relay_artifact.py \
  --deployment-report verification-reports/relay-deployment.json \
  --report-output verification-reports/relay-artifact-parity.json

# Exact Halmos manifest gate
FORGE=/path/to/manifest-pinned-forge HALMOS=.venv-halmos/bin/halmos \
  .venv-halmos/bin/python \
  test-forge/fv/verify_fv.py \
  --report-output verification-reports/relay-halmos.json

# Certora front end (not a cloud proof)
python3 test-forge/fv/verify_certora_local.py \
  --solc /path/to/solc-0.8.35 \
  --report-output verification-reports/relay-certora-local.json

# Certora cloud proofs, requiring CERTORAKEY
./certora/munge.sh
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-threshold.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-writeonce.conf --solc /path/to/solc-0.8.35

# Normalize the authoritative result blocks and bind each log to its job archive
python3 test-forge/fv/verify_certora_cloud.py \
  --run certora/Relay.conf=/path/to/scalar.log=/path/to/scalar-submission.zip \
  --run certora/Relay-threshold.conf=/path/to/threshold.log=/path/to/threshold-submission.zip \
  --run certora/Relay-writeonce.conf=/path/to/writeonce.log=/path/to/writeonce-submission.zip \
  --report verification-reports/relay-certora-cloud.json

# Existing Lean proof/refinement gate
EVMYUL_DIR=/path/to/pinned/EVMYulLean \
  python3 test-forge/fv/lean/verify_lean.py \
  --report-output verification-reports/relay-lean.json

# Aggregate the current reports on a clean checkout
python3 test-forge/fv/verify_bundle.py \
  --output verification-reports/relay-fv-bundle.json
```

For a development-only bundle in a dirty checkout, add `--allow-dirty`. That
override does not make the evidence releasable: it records
`release_eligible=false`.

Both Forge-using gates fail closed unless the executable reports the exact
Foundry version/commit pinned by the manifest. Detailed prerequisites and tool pins are in
[`11-reproducibility.md`](11-reproducibility.md). Earlier chapters preserve
historical reasoning and results, but their old counts, compiler versions, and
Safe/GSS claims are not current evidence.
