# R0/R1 — concrete and fuzz-test foundation

Foundry tests establish the executable fixtures reused by the formal harnesses.
They also pin behavior that is more directly reviewed as examples than as an
abstract theorem: initialization, error selectors, native/token fee transfers, proxy context,
timelock lifecycle, migration delegation, event/state agreement, and malformed
calldata handling.

## Required role

Foundation tests provide:

- valid signing-policy and signature encoders;
- success witnesses for symbolic reachability checks;
- exact boundary cases for strict threshold comparisons;
- differential checks between high-level and assembly encodings;
- regressions that exercise the security findings mapped to the test suite; and
- interface/ABI behavior used by integrations.

They are not a substitute for symbolic or inductive coverage.

## Relay-focused command

Use the Foundry executable pinned by
[`verification-manifest.json`](../../test-forge/fv/verification-manifest.json):

```bash
FORGE=/path/to/manifest-pinned-forge
$FORGE test \
  --match-path 'test-forge/unit/protocol/implementation/Relay*.t.sol'
```

Run the complete repository suite before release because Relay shares proxy,
governance, deployment, FDC, and consumer-facing interfaces with tests outside
the focused path.

## Open security-regression obligations

The current focused tests do not cover every finding from the current review.
The following cases remain missing or incomplete test obligations:

- a repeated address at distinct policy indices;
- zero and duplicate voters on every policy-admission path;
- positive total policy weight;
- a terminal and excessively future random round;
- live-getter arithmetic at the maximum accepted round;
- equality of initial policy start and migration boundary;
- current-random continuity during `oldRelay` migration;
- monotonic policy starts;
- the first accepted random at round zero; and
- timelock behavior across owner and implementation generation changes.

Future tests for behavior that remains vulnerable should first be explicit
counterexample regressions. After remediation, each must become a rejection or
invariant regression.
