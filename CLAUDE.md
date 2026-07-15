# Agent onboarding — Relay.sol verification & hardening engagement

This repo hosts Flare's smart contracts. The active engagement — **formal verification + hardening of
`contracts/protocol/implementation/Relay.sol`** — lives on branch **`relay-fix-3`** (MR !135). If you are
not on it: `git switch relay-fix-3`.

## Read in this order

1. [`docs/relay-verification/00-README.md`](docs/relay-verification/00-README.md) — the audience-facing
   account (12-level ladder: tutorial → audit → reproducibility). Skim L2 + L10 first.
2. [`docs/relay-verification/CHECKPOINT.md`](docs/relay-verification/CHECKPOINT.md) — the raw engagement
   log. **The ⭐ banners at the top are the current state and the resume point.**
3. [`test-forge/fv/README.md`](test-forge/fv/README.md) — how to read/run the FV suites (Halmos, Kontrol,
   Lean, Certora).
4. [`docs/relay-verification/CONCEPTS.md`](docs/relay-verification/CONCEPTS.md) — plain-words explanations
   of the concepts (SMT, k-induction, CEX, psAt, …), if any are unfamiliar.

## Toolchain bootstrap

```bash
./scripts/bootstrap-fv.sh          # node deps, forge build, ./.venv-halmos (from the lock), Halmos gate
./scripts/bootstrap-fv.sh --lean   # + pinned EVMYulLean at /tmp/evmyul2 (~30-60 min) + Lean gate
```

The Halmos venv `./.venv-halmos` is the **reference toolchain** (gitignored; reconstructed from
`test-forge/fv/requirements-halmos.lock`). Judge FV verdicts **only** from this venv or CI — a stray local
install has been observed to misreport nonlinear proofs at identical package versions.

## Hard rules (they bite)

- **Never edit `/tmp/evmyul2/EvmYul/**`** — the pinned EVMYulLean (commit `047f6307…`) is read-only ground
  truth. Check Lean files with `lake env lean <file>` only; **never `lake build`** in that checkout.
- **Hole-free bar for Lean results:** `#print axioms` ⊆ `{propext, Classical.choice, Quot.sound}` plus the
  two documented data-layer specs (`zeroes_data`, `toByteArray_size`). No `sorry`, no `native_decide`.
  Enforced by `test-forge/fv/lean/verify_lean.py`.
- **Deferred contract issues stay deferred:** RLY-05/08/12 and RLY-07 are comment-only in `Relay.sol` — do
  not "fix" them (see `docs/relay-fixes.md`).
- **Git:** the server rejects unsigned commits and unverified committer emails. Required local config:
  `git config user.email alen@abelium.eu && git config gpg.format ssh &&
  git config user.signingkey ~/.ssh/id_ed25519.pub && git config commit.gpgsign true`.
  Commit/push only when the user asks.

## The gates (green = healthy)

| Gate | Command | Checks |
|------|---------|--------|
| Halmos | `HALMOS=$PWD/.venv-halmos/bin/halmos .venv-halmos/bin/python test-forge/fv/verify_fv.py` | exact 89-check inventory vs `test-forge/fv/verification-manifest.json`: 60 proofs PASS + 29 reachability controls with validated counterexamples |
| Lean | `EVMYUL_DIR=/tmp/evmyul2 python3 test-forge/fv/lean/verify_lean.py` | all proof files hole-free vs the pinned semantics |
| Artifact parity | `test-forge/fv/verify_relay_artifact.py` | FV solc output ≡ deployment artifact; optimized Yul ≡ the committed Lean source snapshot |
| Doc links | `python3 docs/relay-verification/verify_links.py --check` (`--fix` to repair) | symbol-addressed code links in the docs stay current |
| Kontrol | `test-forge/fv/kontrol/run.sh` in the Docker image (see its README) | 9 proofs + 4 CEX-by-design vs its manifest |

CI runs the first four (`test-fv-halmos`, `test-fv-lean`, `test-doc-links`, artifact parity inside the
Halmos job). Certora runs are cloud + key — see `certora/README.md` for the run matrix and how to judge
`SUCCESS` / `SANITY_FAIL` / `FAIL`.
