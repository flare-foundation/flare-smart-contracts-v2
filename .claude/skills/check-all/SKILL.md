---
name: check-all
description: Run the full pre-commit verification suite for flare-smart-contracts-v2 — Solidity build, linting, formatting, TypeScript linting, Forge tests + coverage, Hardhat integration tests, and a simulation smoke test. Use when the user asks to "check if everything still works", "verify everything", "sanity check", "pre-commit check", "is it all green", or similar whole-repo health requests.
allowed-tools:
  - Bash(forge build)
  - Bash(forge build *)
  - Bash(forge test)
  - Bash(forge test *)
  - Bash(pnpm lint-sol)
  - Bash(pnpm lint-sol *)
  - Bash(pnpm lint:check)
  - Bash(pnpm lint:check *)
  - Bash(pnpm format:check)
  - Bash(pnpm format:check *)
  - Bash(pnpm coverage-forge)
  - Bash(pnpm coverage-forge *)
  - Bash(pnpm test_integration_hh)
  - Bash(pnpm test_integration_hh *)
  - Bash(.claude/skills/check-all/scripts/smoke-sim.sh)
  - Bash(.claude/skills/check-all/scripts/smoke-sim.sh *)
---

# Check-all: Verify the repository is healthy

Run the pre-commit checklist from `CLAUDE.md` plus an integration test run and a simulation smoke test, then report results.

## What to run (default)

Run all of these even if one fails — surface every failure at the end so the user sees the full picture in one pass:

1. **`forge build`** — Solidity compilation.
2. **`pnpm lint-sol`** — Solhint on `contracts/`, `test-forge/`, `deployment/`. 0 errors required; warnings OK.
3. **`pnpm lint:check`** — ESLint on `deployment/`, `scripts/`, `test/`. 0 errors.
4. **`pnpm format:check`** — Prettier check.
5. **`forge test`** — Full Forge suite. Fast, verbose traces on failure.
6. **`pnpm coverage-forge`** — Forge coverage (rebuilds with coverage profile, reruns all tests, writes `coverage-forge/`). Slow but required.
7. **`pnpm test_integration_hh`** — Hardhat integration tests.
8. **Simulation smoke test** — see the **Simulation smoke test** section below.

## Opt-in only (do NOT run unless explicitly requested)

- **`pnpm test_unit_hh`** — Hardhat unit tests. Only run if the user says "include hardhat unit tests" or equivalent.
- **`pnpm coverage`** — Hardhat coverage. Only on explicit request.

## Execution rules

- Use `run_in_background: true` for long steps (`forge test`, `pnpm coverage-forge`, `pnpm test_integration_hh`, simulation) so you can monitor them. Foreground the fast steps (lint, format, build).
- **Invoke each command raw — no `| tee`, `| tail`, `2>&1`, or other shell pipes/redirects.** The `allowed-tools` list above only covers the bare commands (e.g. `Bash(forge build *)`); any pipe turns the call into a compound shell invocation that falls outside the allowlist and triggers a permission prompt on every run. To inspect output:
  - Foreground: the Bash tool already returns stdout.
  - Background: the harness writes stdout to its own output file — `Read` that file when you need the tail.
- Do not auto-fix. If `format:check` or `lint:check` fails, report it; don't run `:fix` variants unless the user asks.
- Do not commit anything.

## Simulation smoke test

`pnpm sim-run` runs an infinite `while (true)` loop, so there is no natural exit. The start/wait/poll/kill logic lives in [scripts/smoke-sim.sh](scripts/smoke-sim.sh) (relative to this skill folder) — just run it from the repo root:

```bash
.claude/skills/check-all/scripts/smoke-sim.sh
```

Exit code 0 = pass; nonzero = fail. On failure, the script prints the last 40 lines of `/tmp/sim-run.log` — include that in the status report.

Timeouts can be overridden via env vars (`TIMEOUT_NODE`, `TIMEOUT_START`, `TIMEOUT_VOTING`, `TIMEOUT_POLICY`); defaults cap the whole test at ~6 minutes. The script checks three markers: `[Starting simulation]`, `Voting round N finished`, and `Event RewardEpochStarted emitted`. The last one is the strongest end-to-end signal — it only fires when the full signing-policy pipeline (init → threshold signing → epoch advance) completes. Do not re-implement the polling logic here — edit the script if markers or timeouts need to change.

## Reporting

At the end, produce a compact status block:

```
forge build            ✅ / ❌
pnpm lint-sol          ✅ / ❌  (N errors, M warnings)
pnpm lint:check        ✅ / ❌
pnpm format:check      ✅ / ❌
forge test             ✅ / ❌  (N failed / M passed)
pnpm coverage-forge    ✅ / ❌
pnpm test_integration_hh ✅ / ❌
simulation smoke       ✅ / ❌  (startup Xs, voting Ys, RewardEpochStarted Zs)
```

For each ❌, show the first ~20 lines of the failure. Do not paste full logs. If everything is green, say so in one sentence and stop.