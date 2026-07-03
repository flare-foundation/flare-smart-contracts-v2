#!/usr/bin/env python3
"""Regression gate for the Lean bytecode-refinement proofs.

Type-checks every file under `test-forge/fv/lean/bytecode-refinement/` against the *pinned* NethermindEth
EVMYulLean semantics and enforces that the results stay **hole-free**: `lake env lean` must exit 0 (no
`error:`), and every `#print axioms` line must list only allowed axioms — no `sorryAx`, no `native_decide`,
nothing beyond the standard three plus the two documented, upstream-dischargeable data-layer specs.

This complements `verify_fv.py` (the Halmos gate); together they keep both FV strands from silently
regressing. It is deliberately independent of Lake's own success reporting: a file that still *builds* but
acquired a `sorry` would pass `lake` yet must fail here.

Usage (CI sets EVMYUL_DIR to the built EVMYulLean checkout):
    EVMYUL_DIR=/path/to/evmyul lake_env=... python3 test-forge/fv/lean/verify_lean.py
Locally, EVMYUL_DIR defaults to /tmp/evmyul2 (the working checkout used during development).

Exit code 0 = all files type-check and are hole-free; 1 = any error / disallowed axiom.
"""

from __future__ import annotations
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# --- configuration -----------------------------------------------------------------------------------

# Pinned EVMYulLean commit the proofs were checked against (documented across the docs ladder + READMEs).
PINNED_COMMIT = "047f63070309f436b66c61e276ab3b6d1169265a"

# The only axioms a hole-free result may depend on: Lean's three foundational axioms, plus the two
# documented upstream-dischargeable data-layer specs (see AXIOM_DISCHARGE.md). Matched by FULL name.
ALLOWED_AXIOMS = {
    "propext",
    "Classical.choice",
    "Quot.sound",
    "RelayWindows.zeroes_data",
    "RelayDataLayer.zeroes_data",
    "RelayDataLayer.toByteArray_size",
}

# Self-contained files (import only EvmYul.*): checked directly.
STANDALONE = [
    "RelayBytecodeRefinement.lean",
    "DataLayer.lean",
    "RelayLoopMemRead.lean",
    "RelayLoopWindows.lean",
    "RelayLoopLiteral.lean",
    "RelayStorageLayer.lean",
]
# The one integration file: imports the three siblings, so they must be compiled into the package lib first
# (a plain LEAN_PATH prepend does NOT work — Lean will not fall through to it).
INTEGRATION = "RelayBodyEff.lean"
INTEGRATION_DEPS = ["DataLayer", "RelayLoopWindows", "RelayLoopLiteral"]

# Tokens that must never appear in a checked file's output or source (proof holes / cheats).
FORBIDDEN_TOKENS = ["sorryAx", "native_decide"]

FV_LEAN_DIR = Path(__file__).resolve().parent / "bytecode-refinement"


def run_lean(evmyul: Path, target: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["lake", "env", "lean", target],
        cwd=evmyul, capture_output=True, text=True,
    )


def axiom_lines(output: str) -> list[str]:
    # `#print axioms foo` prints:  'foo' depends on axioms: [a, b, c]   (possibly wrapped over lines)
    joined = re.sub(r"\s+", " ", output)
    return re.findall(r"depends on axioms: \[([^\]]*)\]", joined)


def audit_output(name: str, cp: subprocess.CompletedProcess) -> list[str]:
    """Return a list of problems (empty = clean)."""
    problems: list[str] = []
    out = cp.stdout + "\n" + cp.stderr
    if cp.returncode != 0 or re.search(r"^.*error:", out, re.MULTILINE):
        # surface the first few error lines
        errs = [l for l in out.splitlines() if "error:" in l][:5]
        problems.append(f"{name}: lean reported errors (exit {cp.returncode}):\n    " + "\n    ".join(errs or [out[-400:]]))
    for tok in FORBIDDEN_TOKENS:
        if tok in out:
            problems.append(f"{name}: forbidden token '{tok}' in output (proof hole / cheat)")
    groups = axiom_lines(out)
    if not groups:
        problems.append(f"{name}: no `#print axioms` output found — the file must audit its results")
    for g in groups:
        axs = [a.strip() for a in g.split(",") if a.strip()]
        bad = [a for a in axs if a not in ALLOWED_AXIOMS]
        if bad:
            problems.append(f"{name}: disallowed axiom(s): {bad}")
    return problems


def main() -> int:
    evmyul = Path(os.environ.get("EVMYUL_DIR", "/tmp/evmyul2")).resolve()
    if not (evmyul / "lakefile.lean").exists() and not (evmyul / "lakefile.toml").exists():
        print(f"ERROR: EVMYUL_DIR={evmyul} is not a Lake project (expected the built EVMYulLean checkout).")
        print(f"       Clone + build it pinned to {PINNED_COMMIT} (see test-forge/fv/lean/bytecode-refinement/README.md).")
        return 1

    print(f"Lean FV gate — EVMYulLean at {evmyul} (pinned {PINNED_COMMIT[:12]})")
    # stage the FV files into the checkout
    for f in STANDALONE + [INTEGRATION]:
        shutil.copy(FV_LEAN_DIR / f, evmyul / f)

    all_problems: list[str] = []

    for f in STANDALONE:
        print(f"  checking {f} ...", flush=True)
        all_problems += audit_output(f, run_lean(evmyul, f))

    # compile the integration file's deps into the package lib, then check it
    lib = evmyul / ".lake" / "build" / "lib" / "lean"
    lib.mkdir(parents=True, exist_ok=True)
    for dep in INTEGRATION_DEPS:
        cp = subprocess.run(
            ["lake", "env", "lean", f"{dep}.lean", "-o", str(lib / f"{dep}.olean")],
            cwd=evmyul, capture_output=True, text=True,
        )
        if cp.returncode != 0:
            all_problems.append(f"{dep} (olean build for {INTEGRATION}): exit {cp.returncode}\n    " + cp.stderr[-400:])
    print(f"  checking {INTEGRATION} ...", flush=True)
    all_problems += audit_output(INTEGRATION, run_lean(evmyul, INTEGRATION))

    print()
    if all_problems:
        print("FAIL — the Lean bytecode-refinement proofs are not hole-free:")
        for p in all_problems:
            print("  ✗ " + p)
        return 1
    print(f"PASS — all {len(STANDALONE) + 1} files type-check and are hole-free "
          f"(axioms ⊆ {sorted(ALLOWED_AXIOMS)}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
