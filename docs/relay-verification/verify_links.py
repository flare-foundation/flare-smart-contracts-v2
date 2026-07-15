#!/usr/bin/env python3
"""Symbol-addressed code links for the verification docs — checker & fixer.

PROBLEM. The ladder docs reference hundreds of test/proof artifacts (`check_*`, `prove_*`,
`test_*`, Lean theorems, Certora rules). Links that carry line numbers rot as code moves, and
GitHub/GitLab disagree on range anchors (GitHub `#L10-L20`, GitLab `#L10-20`) — only
single-line anchors `#L10` render on BOTH platforms.

CONVENTION (enforced here). A code link is *symbol-addressed*: its link text is the symbol
name (backticked), its target is the defining file, and its anchor is the single line of the
definition — recomputed from the sources, never hand-maintained:

    [`check_bridge_1sig`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L76)

This script (a) builds a symbol index from the verification sources, (b) refreshes the
anchor of every existing symbol link, (c) turns every plain backticked mention of an
indexed, unambiguous symbol into such a link, and (d) bounds-checks legacy `File.sol:NNN`
anchors whose line number is itself the documented claim (those are verified, not rewritten).
Fenced code blocks and headings are left untouched. Ambiguous names (defined in several
files) are only linked when written qualified (`Namespace.name`) or already linked to their
file; plain ambiguous mentions are skipped and reported.

USAGE:
    python3 docs/relay-verification/verify_links.py --check   # CI gate: exit 1 if any link is stale/missing
    python3 docs/relay-verification/verify_links.py --fix     # rewrite the docs in place

Run --fix after renaming/moving any check/proof/theorem, or after editing indexed sources —
the CI job (`test-doc-links`) fails until the docs are regenerated.
"""

from __future__ import annotations
import argparse
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# ---- what we index -------------------------------------------------------------------------

SOL_SOURCES = [
    "test-forge/fv/*.t.sol",
    "test-forge/fv/kontrol/*.t.sol",
    "test-forge/unit/protocol/implementation/Relay.t.sol",
]
LEAN_SOURCES = [
    "test-forge/fv/lean/RelaySigLoop.lean",
    "test-forge/fv/lean/bytecode-refinement/*.lean",
]
SPEC_SOURCES = ["certora/specs/*.spec"]
PY_SOURCES = ["test-forge/fv/verify_fv.py", "test-forge/fv/lean/verify_lean.py"]

# docs the convention applies to
DOCS = [
    "docs/relay-verification/*.md",
    "docs/relay-verification-summary.md",
    "test-forge/fv/README.md",
    "test-forge/fv/lean/bytecode-refinement/README.md",
]

# plain (unqualified) mentions are auto-linked only for these name shapes — the artifact
# namespaces that are unique by construction and unambiguous to a reader
AUTOLINK_RE = re.compile(r"^(check_|prove_|test_)\w+$")

DEF_PATTERNS = {
    ".sol": re.compile(r"^\s*(?:function|contract|library|interface)\s+(\w+)"),
    ".lean": re.compile(r"^\s*(?:theorem|lemma|def|abbrev|structure|inductive|instance)\s+([\w.]+)"),
    ".spec": re.compile(r"^\s*(?:rule|invariant|definition|ghost|hook)\s+(\w+)"),
    ".py": re.compile(r"^\s*def\s+(\w+)"),
}
NAMESPACE_RE = re.compile(r"^\s*namespace\s+([\w.]+)")   # Lean
CONTRACT_RE = re.compile(r"^\s*(?:contract|library|interface)\s+(\w+)")  # Solidity scopes


def _expand(patterns: list[str]) -> list[Path]:
    out: list[Path] = []
    for pat in patterns:
        out += sorted(REPO.glob(pat))
    return out


def build_index() -> tuple[dict, dict, dict]:
    """Return (by_name, by_qualified, file_lines).

    by_name:      name -> list of (repo_rel_path, line_no)     (all definition sites)
    by_qualified: 'Scope.name' -> (repo_rel_path, line_no)     (Lean namespace / Sol contract)
    file_lines:   repo_rel_path -> line count (for bounds checks)
    """
    by_name: dict[str, list] = {}
    by_qual: dict[str, tuple] = {}
    file_lines: dict[str, int] = {}

    for f in _expand(SOL_SOURCES + LEAN_SOURCES + SPEC_SOURCES + PY_SOURCES):
        rel = f.relative_to(REPO).as_posix()
        lines = f.read_text(encoding="utf-8").splitlines()
        file_lines[rel] = len(lines)
        pat = DEF_PATTERNS.get(f.suffix)
        if pat is None:
            continue
        scopes: list[str] = []
        for i, line in enumerate(lines, start=1):
            ns = NAMESPACE_RE.match(line) if f.suffix == ".lean" else None
            if ns:
                scopes.append(ns.group(1))
            sc = CONTRACT_RE.match(line) if f.suffix == ".sol" else None
            m = pat.match(line)
            if m:
                name = m.group(1).split(".")[-1]
                by_name.setdefault(name, []).append((rel, i))
                for scope in scopes[-1:] if scopes else []:
                    by_qual.setdefault(f"{scope}.{name}", (rel, i))
                if sc:  # the contract line itself
                    by_name.setdefault(sc.group(1), []).append((rel, i))
            if sc and not m:
                scopes = [sc.group(1)]
                by_name.setdefault(sc.group(1), []).append((rel, i))
                # contract members are qualified Contract.name
        # second pass for Sol member qualification
        if f.suffix == ".sol":
            scope = None
            for i, line in enumerate(lines, start=1):
                sm = CONTRACT_RE.match(line)
                if sm:
                    scope = sm.group(1)
                fm = re.match(r"^\s*function\s+(\w+)", line)
                if fm and scope:
                    by_qual.setdefault(f"{scope}.{fm.group(1)}", (rel, i))
    return by_name, by_qual, file_lines


# ---- markdown machinery ---------------------------------------------------------------------

FENCE_RE = re.compile(r"^(```|~~~)")
# an existing markdown link whose text is a single backticked identifier
SYMLINK_RE = re.compile(r"\[`([\w.]+)`\]\(([^)#\s]+)(#L\d+)?\)")
# any link with a #L anchor (for bounds-checking the non-symbol ones)
ANYANCHOR_RE = re.compile(r"\[([^\]]+)\]\(([^)#\s]+)#L(\d+)\)")
# a plain backticked identifier that is NOT link text: not preceded by '[', not followed by ']('
PLAIN_RE = re.compile(r"(?<!\[)`([\w.]+)`(?!\]\()")


def resolve(base_dir: Path, target: str) -> str | None:
    """Resolve a doc-relative link target to a repo-relative posix path (None if outside/missing)."""
    p = (base_dir / target).resolve()
    try:
        return p.relative_to(REPO).as_posix()
    except ValueError:
        return None


def relhref(doc_dir: Path, repo_rel: str) -> str:
    return os.path.relpath(REPO / repo_rel, start=doc_dir).replace(os.sep, "/")


def process_doc(doc: Path, by_name: dict, by_qual: dict, file_lines: dict):
    """Return (new_text, changes, problems). Never touches fenced blocks or headings."""
    doc_dir = doc.parent
    changes: list[str] = []
    problems: list[str] = []
    skipped_ambiguous: set[str] = set()

    def lookup(name: str):
        """name (possibly qualified) -> (repo_rel, line) | None; record ambiguity."""
        if "." in name:
            hit = by_qual.get(name)
            return hit
        sites = by_name.get(name, [])
        uniq = sorted({s for s in sites})
        if len(uniq) == 1:
            return uniq[0]
        if len(uniq) > 1:
            skipped_ambiguous.add(name)
        return None

    def fix_symlinks(line: str) -> str:
        def sub(m: re.Match) -> str:
            name, target, anchor = m.group(1), m.group(2), m.group(3)
            repo_rel = resolve(doc_dir, target)
            if repo_rel is None or repo_rel not in file_lines:
                return m.group(0)  # link to something we don't index — leave alone
            # find the symbol in the *linked* file (link target disambiguates)
            short = name.split(".")[-1]
            site = next((ln for (f, ln) in by_name.get(short, []) if f == repo_rel), None)
            if site is None:
                return m.group(0)  # text isn't a symbol of that file (e.g. a file-name link)
            want = f"#L{site}"
            if anchor != want:
                changes.append(f"{doc.name}: [`{name}`]({target}{anchor or ''}) -> {want}")
                return f"[`{name}`]({target}{want})"
            return m.group(0)
        return SYMLINK_RE.sub(sub, line)

    def add_links(line: str) -> str:
        def sub(m: re.Match) -> str:
            name = m.group(1)
            if not (AUTOLINK_RE.match(name) or "." in name):
                return m.group(0)
            hit = lookup(name)
            if hit is None:
                return m.group(0)
            repo_rel, ln = hit
            href = f"{relhref(doc_dir, repo_rel)}#L{ln}"
            changes.append(f"{doc.name}: link `{name}` -> {repo_rel}#L{ln}")
            return f"[`{name}`]({href})"
        return PLAIN_RE.sub(sub, line)

    def bounds_check(line: str, lineno: int) -> None:
        for m in ANYANCHOR_RE.finditer(line):
            repo_rel = resolve(doc_dir, m.group(2))
            if repo_rel is None:
                continue
            target = REPO / repo_rel
            if not target.exists():
                problems.append(f"{doc.name}:{lineno}: dangling link target {m.group(2)}")
                continue
            n = file_lines.get(repo_rel) or len(target.read_text(encoding="utf-8").splitlines())
            file_lines[repo_rel] = n
            if int(m.group(3)) > n:
                problems.append(
                    f"{doc.name}:{lineno}: anchor #L{m.group(3)} beyond end of {repo_rel} ({n} lines)")

    out: list[str] = []
    in_fence = False
    for lineno, line in enumerate(doc.read_text(encoding="utf-8").splitlines(), start=1):
        if FENCE_RE.match(line.strip()):
            in_fence = not in_fence
            out.append(line)
            continue
        if in_fence or line.lstrip().startswith("#"):
            out.append(line)
            continue
        line = fix_symlinks(line)
        line = add_links(line)
        bounds_check(line, lineno)
        out.append(line)

    if skipped_ambiguous:
        problems.append(
            f"{doc.name}: ambiguous (multi-definition) names left unlinked: "
            + ", ".join(sorted(skipped_ambiguous)))
    return "\n".join(out) + "\n", changes, problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="verify; exit 1 if a --fix would change anything")
    mode.add_argument("--fix", action="store_true", help="rewrite the docs in place")
    args = ap.parse_args()

    by_name, by_qual, file_lines = build_index()
    print(f"[links] index: {sum(len(v) for v in by_name.values())} definition sites, "
          f"{len(by_qual)} qualified names, {len(file_lines)} files")

    all_changes: list[str] = []
    hard_problems: list[str] = []
    # Engagement-log files are historical records: exempt from auto-linking so code moves
    # never churn their text (they are prose logs, not navigable reference docs).
    SKIP_DOCS = {"CHECKPOINT.md", "CONCEPTS.md"}
    for doc in _expand(DOCS):
        if doc.name == Path(__file__).name or doc.name in SKIP_DOCS:
            continue
        new_text, changes, problems = process_doc(doc, by_name, by_qual, file_lines)
        all_changes += changes
        # ambiguity notes are informational; dangling/out-of-range are hard problems
        hard_problems += [p for p in problems if "ambiguous" not in p]
        info = [p for p in problems if "ambiguous" in p]
        for p in info:
            print(f"[links] note: {p}")
        if args.fix and new_text != doc.read_text(encoding="utf-8"):
            doc.write_text(new_text, encoding="utf-8")

    for c in all_changes:
        print(("[links] fixed: " if args.fix else "[links] STALE: ") + c)
    for p in hard_problems:
        print("[links] PROBLEM: " + p)

    if args.check and (all_changes or hard_problems):
        print(f"\n[links] FAIL — {len(all_changes)} stale/missing link(s), "
              f"{len(hard_problems)} problem(s). Run: python3 docs/relay-verification/verify_links.py --fix")
        return 1
    if hard_problems:
        print(f"\n[links] {len(hard_problems)} problem(s) need manual attention (see above).")
        return 1
    print(f"[links] OK — {len(all_changes) if args.fix else 0} link(s) updated, all anchors current.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
