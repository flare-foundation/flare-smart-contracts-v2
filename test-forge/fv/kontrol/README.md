# Kontrol (unbounded / inductive) FV proofs for Relay.sol

Machine-checked **unbounded** proofs of Relay's signature-loop and random-pointer invariants — the
properties the bounded Halmos suite (`test-forge/fv/*`) structurally cannot reach (Halmos unrolls loops
to a fixed depth; these are ∀-over-the-iteration-count via k-induction).

## Contents (≈ 30 KB — this is all that lives in git)

| file | what it is |
|------|------------|
| `RelaySigLoopFV.t.sol`   | unbounded-in-K signature-loop **weight invariant** (`weight ≤ prefixSum(nextUnusedIndex)`), via k-induction over a grounded prefix sum. 5 PROVE + 2 anti-vacuity controls. |
| `RelaySigLoopFV_N5.t.sol`| the **same** weight-invariant proof re-validated at **N=5** voters (identical structure, five `uint16` weights; K still unbounded). 5 PROVE + 2 controls. |
| `RelayRandomMonoFV.t.sol`| unbounded **random-pointer monotonicity** (a stale relay never regresses the live round). 4 PROVE + 2 controls. |
| `run.sh`                 | the build+prove recipe (checks pinned tool versions, self-provisions the pinned solc if the image lacks it, writes `foundry.toml`, runs `forge build` → `kontrol build` → `kontrol prove`, then validates JUnit). It matches **all three** harnesses. |
| `verification-manifest.json` / `verify_kontrol.py` | exact 14-proof + 6-control inventory (20 checks) and fail-closed JUnit verdict gate. |
| `foundry.toml`           | minimal Foundry config. |
| `Dockerfile`             | **fully pinned, reproducible** Kontrol 1.0.248 toolchain (see below). |

## Latest verdicts (Kontrol 1.0.248, `kontrol-local:ready`)

`RelaySigLoopFV` (N=3 voter model) and `RelaySigLoopFV_N5` (the N=5 re-validation — a committed harness, not
a one-off; identical 5 PROVE + 2 CEX, prove ~2.25 h):
`prove_base_invariant` ✅ · `prove_step_preserves_invariant` ✅ · `prove_lemma_prefix_monotone` ✅ ·
`prove_accept_implies_threshold_exceeded` ✅ · `prove_insufficientWeight_cannotAccept` ✅ ·
`prove_reach_stepNeedsGuard` → counterexample (G2/no-double-count guard is load-bearing) ·
`prove_reach_acceptIsPossible` → counterexample (accept path live).

`RelayRandomMonoFV`:
`prove_base_monotone` ✅ · `prove_step_monotone` ✅ · `prove_step_staleDoesNotRegress` ✅ ·
`prove_step_advancesToNewer` ✅ · `prove_reach_canAdvance` → CEX · `prove_reach_canStayStale` → CEX.

Each negative proof is paired with a reachability control that MUST counterexample — a control that
"proves" instead is a vacuity alarm.

## Reproducibility — what is pinned

- **Kontrol** `v1.0.248`, **K** `v7.1.334` (`deps/k_release`), and the entire K/kore/kdist closure are
  pinned by Kontrol's own `flake.lock` + `uv.lock` and fetched deterministically from RV's binary cache.
- The **toolchain layer** (clang, cmake, jdk17, python3.11, foundry, solc, crypto libs) is pinned in the
  `Dockerfile` to **`nixpkgs @ 9eac87a…`** (the exact commit the proofs were checked with) and the **base
  image by sha256 digest**. So `docker build` reproduces the same toolchain byte-for-byte.

A clean Nix *flake* is not used because Kontrol's own nix packaging is upstream-broken (it references
`solc_0_8_13`, removed from nixpkgs); the pinned Dockerfile is the reproducible record instead.

## Build the toolchain image (one-time)

Best on a **native x86_64 Linux host** (CI or a Linux box) — fast and no emulation:

```bash
docker build -f test-forge/fv/kontrol/Dockerfile -t kontrol-local:ready .
```

On Apple Silicon add `--platform linux/amd64` (slower, via Rosetta; the kdist build is pinned to one core
so it is deadlock-safe). Image size ≈ 18.5 GB; the irreducible artifact is the 1.2 GB kompiled KEVM kdist.
For a team, build once and `docker push` to the GitLab Container Registry so others `docker pull` it
instead of rebuilding.

## Run a proof

On Apple Silicon / any emulated (amd64-on-arm) host, pin the container to a **single core** — the
multi-worker `kore-rpc-booster` backend deadlocks under emulation (observed to wedge at 4 cores; 1 core
proves cleanly):

```bash
docker run --rm --platform linux/amd64 --cpuset-cpus=0 \
  -v "$PWD/test-forge/fv/kontrol":/work kontrol-local:ready sh /work/run.sh
```

`run.sh` copies the harnesses into a clean container-internal project with the standard `test/` layout
(required so kontrol's JUnit writer emits `test%Contract` ids — a root layout crashes it), then:
`forge build` (≈1 s) → `kontrol build` (≈8–18 min, reuses the baked kdist) → one `kontrol prove` over all
three harnesses → `verify_kontrol.py`. The full 20-check run is **long at one core** (the N=5 signature loop
alone is ≈2.25 h; the whole suite several hours) — drop an alternative from run.sh's `--match-test` to
reproduce a subset. The prover's nonzero exit is expected (reachability controls fail by design) but not
ignored: `verify_kontrol.py` jointly validates the exit, exact JUnit inventory, proof passes, and concrete
control failures. Errors, skips, pending/incomplete proofs, and drift fail closed.

## Honest caveats (also in each harness header)

1. **N (voter count) is a concrete model bound**; the proof structure is parametric in N. **K (the number
   of signatures / relays) is the genuinely unbounded dimension** — the inductive step's pre-state is fully
   symbolic and ranges over every invariant-state, so discharging it once covers all iteration counts.
2. **base + step compose to ∀K by the standard induction principle applied at the meta level.** Kontrol
   1.0.248 exposes no native Solidity loop-invariant/cut-point, so that composition is not itself
   machine-checked — each piece is.
3. These check a faithful **Solidity model** of the loop body, not Relay's actual inline-assembly bytecode.
   The bytecode side at K ≤ 3 is covered by the Halmos suite (`RelaySigParamFV`). A bmc-depth-1
   model↔bytecode equivalence obligation would fully bridge the gap (future work).
