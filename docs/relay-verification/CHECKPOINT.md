# Relay.sol Formal Verification — Working Checkpoint

> **Purpose of this file:** durable, self-contained progress log of the Relay.sol
> verification + hardening engagement, so any fresh session (or reader) can resume/audit
> without re-deriving prior work. Historically kept outside the repo; moved into
> `docs/relay-verification/` on 2026-07-15 so the engagement record is self-contained in-repo.
> **Keep this file updated** as phases complete. Last updated: 2026-07-26.
> Reading order: the ⭐ banners at the top are current; numbered sections below are the
> chronological history (oldest at the bottom of each era). The polished, audit-facing
> account is `docs/relay-verification/` — this file is the raw engineering log behind it.
> Fresh clone? Start at the repo-root `CLAUDE.md` and run `./scripts/bootstrap-fv.sh`
> (creates the in-repo `./.venv-halmos` reference toolchain and runs the Halmos gate).

---

## ⭐ 2026-08-10 — Safe (GSS) governance RETIRED; Relay is owner+timelock governed

The cross-chain Safe-signature governance (SafeGoverned/SafeInstructions, the Safe suites,
the GSS FV harness and both GSS CI gates) was removed before any deployment. Relay now
inherits `OwnableWithTimelock` (per-chain owner; queue/execute/cancel with a deploy-seeded
duration ≤ 7 days; four guarded setters incl. `setSigningPolicySetter`; UUPS upgrade
through the same queue) — current design: `docs/relay-governance.md`.
`docs/safe-governance.md` is deleted; references to it (and to the GSS suites) in the
history below are the engagement record — recover the material from git history. Every FV
gate stays deliberately red pending the re-baseline onto the owner-timelock source (the
verification manifest still pins the retired `gss_*` inventories; drop them then).

---

## ⭐ 2026-08-03 — RLY-23 revised to ORIGIN binding (source-chain immutable, mirrors enabled)

RLY-23's chain-domain binding was re-based from *runtime* `chainid()` (destination binding) to a
**configured source-network immutable `sourceChainId`** (origin binding), after clarifying the deployment
model: a Relay is deployed on remote chains precisely to **relay messages signed on the source network**
(Flare 14 / Songbird 19), so the digest must commit to the *source* the signatures originate from — not the
chain the Relay runs on.

- **One immutable, unified with governance.** The former `governanceSourceChainId` is renamed `sourceChainId`
  and now feeds BOTH the signing wrap and the GSS Safe digest (same origin network). Governance-enable keys on
  the governance fields only (source is always set). `RelayInitialConfig.sourceChainId`: `0` ⇒ `block.chainid`
  (home); a mirror sets the origin explicitly.
- **Home-force.** A deployment with a live `signingPolicySetter` (Flare/Songbird home, protocol signs locally)
  must have `sourceChainId == block.chainid` — enforced in the constructor *after* the governance
  deployment-shape checks, so `InvalidGovernanceDeployment` still wins for a governance+setter mix.
- **Three wrap sites** bind the immutable (threaded into the Yul as `_sourceChainId`, née `_scid` / a pre-assembly local `srcChainId`):
  `calculateSigningPolicyHash`, the Mode≥1 message-hash line, `_initializeSigningPolicy`.
  `verifyCustomSignature` inherits it via its `relay()` self-call.
- **Mirrors enabled; fork trade-off accepted.** The same signatures verify on the home Relay and every mirror
  of the same source (the point of a relay); cross-source separation (14 vs 19) still holds. Because the id is
  an immutable, a chain-id-changing fork no longer fails closed (documented trade-off).

**Tests** — `RelayChainDomain.t.sol` 8→**10** (added `test_mirror_acceptsForeignSourceMessages`,
`test_homeDeploy_forcesMatchingSource`; replaced `test_fork_failsClosed` with
`test_fork_immutableSource_doesNotFailClosed`). Foundry full tree **969** green; Hardhat Relay 53 / coding 7 /
Submission 3. **FV re-baselined**: optimized-Yul snapshot regenerated (wrap sites now emit `loadimmutable`;
signature-loop body byte-unchanged, shifted +18 IR lines — Lean citations updated), Certora munged tree
re-derived, **Halmos 102/102 green** (venv; +1 proof over the prior 101 —
`RelayConstructorFV.check_ctor_homeForce_rejectsForeignSource` covers the new home-force guard; the local
forge-version pin `1.5.0`≠`1.7.1` is a CI-only guard, not a proof failure). Docs updated: `docs/relay-fixes.md` RLY-23 section + table row + status; L3 count; L4/L7/L10/L13
`chainid`→`sourceChainId`. **Not run here (CI / off-CI):** the Lean hole-free gate (needs the pinned
EVMYulLean checkout), Kontrol Docker, Certora cloud. The 2026-07-23 entry below describes the **superseded**
runtime-`chainid` form.

---

## ⭐ 2026-07-26 — GSS coverage and evidence closure

The GSS review was extended from example-based integration coverage to an exact,
fail-closed evidence pipeline:

- Halmos now includes `GSSGovernanceFV`: 13 post-recovery signer/action proofs
  plus 2 reachability controls. The full exact gate is **101/101** (71 proofs,
  30 validated controls, zero bounded loops or violations).
- The exact GSS test gate is **36/36**: 30 real-Safe unit/differential tests, 3
  production-shape tests, and 3 state-machine tests. Differential fuzzing runs
  256 cases per property; the invariant runs 128x128 = 16,384 handler calls with
  zero handler reverts.
- Production rehearsal deploys exact Gnosis Safe v1.3.0 NPM release artifact
  bytecode, reproduces the recorded 11-owner/threshold-6 Flare shape, executes
  successful Safe calldata through two target Relays, and fits the maximum
  256-entry batch in 7,508,970 test gas.
- `verify-gss-source-safe.js` pins 20 source-Safe facts at Flare block
  65,907,987: block identity, proxy/singleton/fallback code hashes, v1.3.0,
  11 canonical EOA owners, threshold 6, nonce 998, no modules, and zero guard.
  This is a reproducible snapshot, not permission to skip a pre-deployment refresh.
- Both current Certora configs compile and typecheck under the pinned local gate
  (CLI 8.16.1, Java 21, solc 0.8.27, exact two-keyword munge). A current cloud
  prover run still requires `CERTORAKEY` and remains mandatory before claiming
  parametric all-functions GSS proofs.
- The bundle now requires exactly eight reports: deployment, revert ABI,
  artifact parity, GSS tests, source Safe, Halmos, Lean, and Certora local. It
  rejects dirty release trees; `--allow-dirty` produces development-only evidence.

Recorded local regression evidence: full Foundry **967/967**, Hardhat unit
**139/139**, Hardhat integration **36/36**, Lean **9 files / 165 axiom audits**,
legacy assembly reverts **37/37**, FV gate unit tests **35/35**, artifact parity
creation/runtime/IR SHA-256 `40fce992…5e034` / `f132e72f…bc15` /
`d3841471…d74c`, and a development eight-report bundle. A clean-tree bundle and
the current Certora cloud verdict cannot be produced while these review changes
remain intentionally uncommitted.

Accepted design risk DR-08: a threshold-signed, never-executed future fee action
at Safe nonce `uint256.max` can exhaust a target's fee sequence. This is not an
unprivileged bypass; it is the sharpest consequence of accepting gap-tolerant
monotonic bearer authorization without source execution proof. Official-relayer
policy admits only confirmed successful Flare Safe executions as defense in depth,
while the security model deliberately treats the owner threshold itself as authority.

## ⭐ 2026-07-25 — Alternative GSS timing, migration, and reproducibility review

> Historical checkpoint; the 2026-07-26 banner supersedes its test/proof counts.

An adversarial pass on `relay-fix-3-gss` re-derived the GSS protocol from
out-of-order delivery, owner-set reincarnation, Safe cancellation, target
deployment timing, and production migration. The detailed finding ledger and
runbooks are in [`docs/safe-governance.md`](../safe-governance.md), section 17.

Implemented hardening:

- owner configuration hashes now include their activation Safe nonce, so
  returning to the same owner tuple creates a new generation and cannot revive
  old signed actions;
- delayed owner rotations remain installable after a higher old-generation fee,
  but they do not lower the global fee high-water mark; a lower-nonce fee under
  the new generation is rejected;
- each relevant target action consumes its Safe nonce globally, preventing two
  conflicting signed actions at the same nonce from both applying locally;
- fee batches are nonempty, capped at 256, and strictly ordered by
  `(targetChainId, protocolId)` in both checker and Relay. This aligns their
  grammars, eliminates quadratic duplicate scans, and makes the maximum batch
  executable (7.44M gas in the real-Safe Forge test);
- deployment distinguishes the owner-generation nonce from the replay-floor
  snapshot, emits both, and documents a signing pause plus same-owner generation
  bump because a replay floor cannot revoke pre-signed future-nonce actions;
- the source checker exposes whether its admitted generation exactly matches the
  live Safe; deployment must require this before seeding a target, because a
  staged owner rotation cannot be canceled or superseded until the Safe adopts
  the proposed configuration;
- pre-RLY-23 signing-policy migration now requires an explicit `legacy` or
  `chain-bound` old-hash scheme and tests wrap-once, pass-through, and
  fail-closed behavior.

The review also caught a proof-pipeline bug: Halmos 0.3.3 requests AST output
from Forge without forcing recompilation, so a preceding ordinary incremental
build could leave changed AST-less artifacts that Halmos silently skipped. The
exact gate now checks Foundry 1.7.1 and force-builds AST-complete artifacts
before Halmos; its regression test pins `--force`, `--ast`, and the required
extra outputs.

Current local evidence on the final source:

- full Forge suite green; GSS real-Safe suite **27/27**;
- Hardhat compile **250 files**, affected suites **95/95**, TypeScript clean,
  production GSS/Relay Solhint clean;
- FV Python gates **27/27**; legacy `relay()` revert ABI **37/37**;
- artifact parity green: creation semantic SHA-256
  `cd3d0e644b08906fd56c7bd417b92724579331deee0a4d36b8f3765ce5f905f2`,
  runtime `dd32fc178de8f8683b033cf3beaf3dcc3f5a26b89321bd67637940fcda538e61`,
  optimized IR `f5209e989093cd3bc4170b26992e4dd399aafdbdaa0ed7f76c27802e6dd2f443`;
- exact Halmos gate **86/86** (58 proofs + 28 validated reachability controls);
- Lean gate **9 files / 165 declared axiom audits**;
- Certora munge self-check green (exactly two visibility changes); current GSS
  cloud run remains pending;
- documentation link gate and `git diff --check` green.

Accepted current design boundary: Relay proves threshold authorization, not
canonical source execution. Safe cancellation/failure does not revoke copied
signatures, conflicting signed transactions can produce first-delivery divergence
across targets, a higher fee nonce suppresses lower signed fees, removed owners
remain authorized on lagging targets, and signatures are not bound to one Relay address.
Safe modules can also perturb the helper checker. Cryptographic closure requires
a Flare execution proof or a separately signed
expiry/revocation/deployment epoch. The current controls and alternative designs
are recorded in [`safe-governance.md` section 16](../safe-governance.md#16-accepted-design-risks-and-alternatives).

## ⭐ 2026-07-24 — GSS governance branch and proof boundary

Branch `relay-fix-3-gss` removes the unused legacy `governanceFeeSetup` path and
adds Safe v1.3.0 governance for owner configuration and target-specific protocol
fees. The implementation specification and current security boundary are in
[`docs/safe-governance.md`](../safe-governance.md).

The core Halmos manifest is now 86 checks (58 proofs and 28 reachability
controls); the deleted legacy nonce harness is not relabeled as a GSS proof.
The optimized-Yul snapshot has been regenerated and compiler parity remains
exact. GSS has real-Safe integration coverage, while dedicated
Halmos/Kontrol/Lean properties and a current Certora cloud rerun remain open.

## ⭐ 2026-07-23 — RLY-23 CHAIN-DOMAIN BINDING landed + FV re-baselined

> **⚠️ SUPERSEDED by the 2026-08-03 banner (origin binding).** This entry describes the original
> *runtime-`chainid()`* (destination) form. The current code binds a configured **`sourceChainId`
> immutable** (origin), so the `keccak256(chainid ‖ …)` / "fork fails closed" statements below are
> historical, not current. See the top banner and `docs/relay-fixes.md` RLY-23.

New hardening finding **RLY-23** (beyond the original audit set): the `relay()` signature paths bound no
chain/deployment identifier, so a voter quorum's signatures minted on one network were valid bearer
credentials on any other network's Relay with an overlapping policy (Flare↔Songbird cross-chain replay;
`relay()` is permissionless + roots write-once ⇒ first-writer poisoning). **Fix:** bind both the stored
signing-policy hash and every signed message digest to `keccak256(chainid ‖ hash)` via the runtime `CHAINID`
opcode, at three wrap sites (`calculateSigningPolicyHash` tail, the Mode≥1 message-hash line,
`_initializeSigningPolicy`). Runtime (not deploy-time) chainid ⇒ a chain-id-changing fork fails closed.
Committed `4fe4f634` (contract + off-chain libs + deploy scripts + `RelayChainDomain.t.sol`), then extended by
`463d150c` (legacy-migration A/B: `contracts/mock/RelayMainDeployed.sol` + an 8th chain-domain test), then
the FV re-baseline in a follow-up pass (this checkpoint, uncommitted):

- **Halmos gate — GREEN, 89/89** (60 proofs + 29 controls, 0 violations) re-run from `./.venv-halmos` against
  the new bytecode. The accounting proofs are digest-agnostic (the digest is an opaque input); no new check
  added. A *symbolic* cross-chain-rejection proof is intentionally omitted — under uninterpreted `ecrecover`
  the solver can forge recovery to any voter under any digest, so cross-chain resistance is cryptographic and
  correctly stays at R0 (concrete, real ECDSA).
- **Artifact parity** — optimized-Yul snapshot `relay_ir_optimized.yul` regenerated with pinned solc 0.8.27
  (validated forge-version-independent: forge 1.5 and 1.7.1 emit identical `.iropt`; committed & generated
  agree on the `var_leaf` naming convention). Deployment/verification semantic bytecode hashes are computed at
  gate time (no committed constant), so nothing else to update.
- **Certora** — munged tree re-derived (`munge.sh`, self-verified: exactly the 2 visibility changes); storage
  invariants are hash-construction-agnostic, so the run matrix pattern is unchanged (cloud re-run pending, off-CI).
- **Lean — GREEN** (9 files, 165 axiom audits, hole-free) re-run against a freshly-built pinned EVMYulLean.
  No proof file edited: the wrap lands in the pre-loop setup region (inside the explicit `hsetup` boundary);
  the 17-statement loop body is byte-unchanged, shifted +4 IR lines. Updated the stale Yul line-number
  citations (1563-1610 → 1567-1614; 1584 → 1588) in `RelayLoopLiteral.lean`/`RelayBodyEff.lean` (comments;
  proofs verify unchanged).
- **Docs** — `docs/relay-fixes.md` RLY-23 section + table row + status (Foundry +8 to 67, full tree 947); L2
  executive table; L4 (`RelayPolicyHashFV` now symbolically covers the policy-hash chain wrap); L7 (setup-region
  RLY-23 note); L10 ledger (rows 15/15b/15c: chain-binding *structure* proven at R2, cross-chain *rejection* at
  R0); L13 T1-b (cross-chain half closed, same-chain residual remains); 03 inventory; `verify_links.py --fix`.
  CHECKPOINT (this banner + historical §3 annotation).

**Resume point:** all four local gates green (Halmos 89/89, Lean 9-file, doc-links, munge self-verify);
once committed+pushed, CI on `relay-fix-3` (`test-fv-halmos` incl. artifact parity, `test-fv-lean`,
`test-doc-links`) should be green — watch the first `test-fv-lean` run (clones+builds EVMYulLean) and the
artifact-parity step (needs pinned forge 1.7.1, which local 1.5 can't certify — snapshot validated
forge-version-independent). Off-CI confirmations left: the **Certora cloud** re-run (munge is ready) and the
**Kontrol** Docker re-run (harness unaffected — the digest is a free symbol in the loop model). The RLY-23
coordinated cutover (validators + all deployments + off-chain libs sign the new digest at a reward-epoch
boundary) is a deployment-time action, out of repo scope. **These FV-rebaseline changes are uncommitted** —
staged for inspection, per the commit-only-when-asked rule.

---

## ⭐ 2026-07-05 — ENGAGEMENT MATERIALLY COMPLETE + RECORDED NEXT STEPS (not started)

Both goals are materially complete on `relay-fix-3` (MR !135), everything committed + pushed:
- **FV stack through R5** (bricks ≤49): literal loop model + early return + storage (`sstore_sload`) +
  mode dispatch (`dispatch_routes_verify`) + accept-write (`sstore_reads_back`) + end-to-end composition
  (`relay_dispatch_loop_accept`) + fee conservation (`RelayFeeLayer.lean`) — all hole-free, CI-gated by
  `test-forge/fv/lean/verify_lean.py` (**8 files**, job `test-fv-lean`).
- **Hardening**: RLY fixes done/tested/reviewed; RLY-05/08/12 + RLY-07 deferred (comments only).
- **Docs**: 13-file ladder + hardening docs reviewed twice, consistent (R5 redefinition reconciled,
  two-goals framing added, Lean gate documented in L11).

**NEXT STEPS (recorded 2026-07-05; user directed: do NOT address yet):**

*Close-out (recommended, small):*
1. **Confirm CI green on GitLab** — `test-fv-lean` runs locally but no runner execution observed yet
   (it clones + builds EVMYulLean; first run slow, could hit runner limits/timeouts). Check MR !135
   pipeline; fix runner-env surprises.
2. **Final reconfirm sweep** — all suites on tip (Lean 8-file gate, Foundry 59, Foundry FV, Hardhat 54,
   EndToEnd 36, Halmos 89) so the MR hand-off states verified numbers.
3. **Hand MR !135 to review/merge.**

*Optional deepening (diminishing returns, each checkpointable; ROI order):*
4. **Upstream axiom discharge** — PR the two documented patches (`zeroes_data`, `toByteArray_size`;
   archived in `test-forge/fv/lean/bytecode-refinement/AXIOM_DISCHARGE.md`) to NethermindEth/EVMYulLean;
   once merged + re-pinned, axiom list drops to the pure standard three. Cheap; external latency only.
5. **D3 reconciliation** — remodel accept as the deployed break→write→return (vs `return(0,0)`), folding
   the R5.3 accept-write into the composition. Closes the last substantive registered deviation. Days.
6. **Exec-level `.CALL` layer** — `call_eff` analog of `sstore_eff` (primCall/callDispatcher), anchoring
   fee conservation at exec level instead of the `transferBalance` primitive. Days, mostly plumbing.
7. **Discharge the `hsetup` hypothesis** — literally model the ~hundreds of setup lines between dispatch
   and loop (`dispatch_setup_loop_accept`'s hypothesis). Months-scale, lowest ROI; the hypothesis-based
   boundary is already honest and documented.

*Assessed (2026-07-05):* **powdr-labs' formally verified Yul→EVM compiler in Lean**
(https://powdr.org/blog/yul-compiler). Three Lean-4 repos, Apache-2.0, all very early:
- `yul-semantics`: independent dialect-parametric Yul semantics (big-step relational ground truth +
  fuel-indexed interpreter with a PROVEN adequacy theorem). EVM dialect = BitVec 256, FULL builtin set incl.
  calldatacopy/staticcall/keccak256/mstore/sstore. Explicitly EVMYulLean-inspired but independent. 42 commits.
- `evm-semantics`: relational EVM semantics; passes 11 conformance suites (VMTests, GeneralStateTests
  legacy+modern, EEST state/tx/blockchain) with ZERO correctness failures; full precompiles incl. ecrecover;
  per-fork gas. Mostly AI-generated + human-reviewed, self-described draft. Mirrors EVMYulLean structure.
- `yul-compiler`: verified Yul→EVM compiler (Yul→Asm→Instr→ByteArray), `compile_correct` (Yul final state ⟹
  corresponding EVM final state, bounded gas), no `sorry`. **Coverage TODAY excludes ~everything relay()'s
  assembly is made of**: no mstore (no memory writes), no calldatacopy, no staticcall, no keccak256, no
  objects, no switch, no multi-returns; stack≤16; no optimizer. 16 commits, differential examples only.
  Lean v4.31.0 (ours pinned 4.22.0 via EVMYulLean → any bridge is a separate project).

**Usefulness verdict:**
(a) *solc-backend trust gap* (our "ceiling" row): compile_correct is exactly the missing-bridge SHAPE —
    Yul-level theorem + verified compilation ⟹ bytecode-level theorem, discharging the trust in solc's
    unverified Yul→bytecode backend (which even Verity/LFG-Labs punts on — pinned solc 0.8.33 unverified).
    NOT usable now (coverage), the right long-term vector. WATCH the repo.
(b) *A-EVM cross-validation* (ledger: "hardenable by cross-validation"): ACTIONABLE NOW — differential-run
    our 17-statement bodyL + the control-flow shapes we rely on (For/If/Let/calldatacopy/mload/mstore)
    through powdr's adequacy-proven Yul interpreter vs EVMYulLean's exec. Agreement hardens A-EVM's
    weaker half (the Yul control-flow layer, validated only by Yul semantic tests); disagreement = real
    finding for either project. Days-scale, checkpointable. => recorded as next-step N1 below.
(c) *Ecosystem signal*: Lean consolidating as the EVM-FV substrate (EVMYulLean, powdr×3, Verity); their
    AI-assisted+kernel-checked methodology mirrors ours; their evm-semantics ecrecover precompile could
    someday anchor the mechanical (ABI) half of our OP-1 against a second semantics.

*Also in progress (2026-07-07):* **`CONCEPTS.md`** (this dir, outside the repo) — collecting plain-words
explanations of engagement concepts (entries: SMT solver; Halmos↔Kontrol bridge; which-bytecode), to become
an FAQ / explanation pages (likely under `docs/relay-verification/`) at the end. Add future explanations
there as they're produced.

*Housekeeping (2026-07-07):* (a) THIS FOLDER is now a **local-only git repo** (no remote by design):
`.gitignore` excludes the contract repo / `.venv-halmos` / `.claude`; tracked = CHECKPOINT.md + CONCEPTS.md.
Commit here after meaningful checkpoint/concepts updates. (b) `.venv-halmos` is now **reconstructible from
the repo**: `test-forge/fv/requirements-halmos.lock` (full freeze; recreate = `python3.11 -m venv
.venv-halmos && pip install -r …lock`), CI pins halmos==0.3.3 + z3-solver==4.12.6.0 (commit d8775699).
JUDGE FV VERDICTS FROM THIS VENV (or CI) — a different local install misreported the 3 nonlinear proofs at
identical halmos/z3 versions (2026-07-07). (c) Doc code-links are symbol-addressed + CI-enforced:
`docs/relay-verification/verify_links.py --fix` after renames (job `test-doc-links`, commit 9b682e50).

*C-1 DISCHARGE ATTEMPT (2026-07-15, IN PROGRESS — user requested addressing the Certora wall):*
Research (agent, from Certora docs): ALL_SSTORE/ALL_SLOAD raw hooks exist (require `-enableStorageSplitting
false`); with splitting OFF, storage = one SMT array + injective hashing model (keccak locs ≠ slots 0-10000)
→ aliasing havoc gone WITHOUT ghosts. Ghost route = fallback only (regular not persistent ghosts; circular
require-in-ALL_SLOAD trap documented). RESULTS (all runs ~90s, prover.certora.com/output/3798318/<id>):
- Phase A (via-ir, 3 scalar rules, splitting off + optimistic_hashing 512): **19/21 fns SUCCESS**
  (non-vacuous incl governanceFeeSetup/verify); relay()+setSigningPolicy SANITY_FAIL (paths pruned). 8e14cd3b.
- A2 (default hashing): governanceFeeSetup genuinely FAILs (keccak of unbounded msg > 224 default bound) →
  hashing flags load-bearing; vacuity on the 2 assembly fns persists → intrinsic to splitting-off. bb56456c.
- A3 (LEGACY codegen, solc_via_ir false — main compile OK, only Certora autofinder hits stack-too-deep):
  **20/21** — setSigningPolicy PROVEN under legacy; only relay() vacuous. 757ee100.
- Phase B (write-once rules restated over munged-harness getters — certora/munge.sh regenerates
  certora/munged/ with EXACTLY 2 visibility changes private→internal, self-verifying; RelayHarness.sol adds
  policyHashAt/merkleRootAt raw readers; DSA unusable): via-ir **21/23**, same 2 fns vacuous. 01afed2b.
- B2 (legacy): merkleRoot 22/23; policyHashWriteOnce **REAL COUNTEREXAMPLE on setSigningPolicy** — the
  parametric rule from arbitrary storage hits unreachable state (hash[E]≠0 ∧ lastInit=E−1) whence rewrite is
  legit. f4777ba7. FIX: reachable-state link `require epoch <= lastInitializedRewardEpoch` added to the rule
  (documented in-spec). B3 (legacy, with link): **both write-once 22/23, only relay() vacuous**. d6877cf6.
- B1b (via-ir with link): **21/23**, no regression. 9406f186.
CONSOLIDATED & PUSHED (2026-07-15): certora/README.md rewritten (run matrix + anonymousKey report links +
munge/harness architecture + relay() residual); docs swept (00/02/05/10/11/12/summary: C-1 rows "blocked" →
"proven for all fns except relay()"); committed as TWO commits by pathset (user's choice — tree carried ~44
files of uncommitted EXTERNAL manifest-hardening work interleaved in shared docs): 555fe133 (hardening as
found + shared-doc C-1 edits) + ab2c6d89 (certora package). PUSH RULES CHANGED server-side: committer email
must be verified (alen@abelium.eu) AND commits must be SIGNED — repo git config now: user.email=alen@abelium.eu,
gpg.format=ssh, user.signingkey=~/.ssh/id_ed25519.pub, commit.gpgsign=true. Task DONE.
RESIDUAL: relay() vacuity under splitting-off in BOTH codegens — intrinsic path-modeling limit; ghost route
CANNOT fix it (hooks require splitting-off → same vacuity). relay() covered by Halmos/Kontrol/Lean instead.
FILES (uncommitted yet): certora/Relay-rawstorage{,-A2,-A3}.conf, Relay-writeonce{,-B2}.conf, munge.sh,
munged/ tree, harness/RelayHarness.sol, specs/RelayWriteOnce.spec (+reachability link). TODO after B1b:
rewrite certora/README.md (run matrix + architecture + residual), docs sweep (02:182 executive row,
05 §5.2 table, 10 C-1 rows + proven-bar :22, 11 §11.4, 00 result para, 12 lesson, summary), verify_links,
commit+push, memory. Toolchain: certoraRun 8.16.1 at ~/Library/Python/3.11/bin, solc ~/.local/solc/solc-0.8.27,
java /usr/local/opt/openjdk/bin, key ~/.config/certora.env (source, never print).

*ONBOARDING SELF-CONTAINED & VALIDATED (2026-07-15):* fresh-clone path proven end-to-end from origin:
`git clone -b relay-fix-3 … && ./scripts/bootstrap-fv.sh` → node deps (yarn, or pinned `npx yarn@1.22.22` —
npm-ci is WRONG for this yarn.lock repo, caught by rehearsal), forge build, in-repo `./.venv-halmos` from
the lock, Halmos gate green (89/89, 60/60, 29/29, 0 violations), `git status` clean. Agent entry point =
repo-root `CLAUDE.md` (auto-loaded; reading order, hard rules, git signing config, gate table). Commits
9933d0bc / 9c9b4f2c / 31ca4a7c. The parent-folder venv is legacy.

*PIPELINE HEALED (2026-07-15, all green incl. first-ever test-fv-bundle run):* two LATENT defects exposed
when pushes resumed after 8 idle days — neither caused by the new commits. (1) `test-unit-forge` +
`test-fv-halmos` (tagged flarenetwork-md) sourced node_modules ONLY from runner-local cache, which the
untagged build-smart-contracts job can never seed → evicted cache = permanently red. Fix (ad2351c8): cache
demoted to optimization — deterministic fallback (apt node + pinned `npx yarn@1.22.22`), cache-nodejs-rw
(pull-push) so the first run re-seeds the tagged runner, test-unit-forge moved off non-root foundry:stable
onto the digest-pinned python image + checksummed Foundry v1.7.1 (same as the halmos job). (2)
`test-fv-bundle` had NEVER actually executed (always skipped behind the halmos failure); first run exposed
a phantom `git -C flare-smart-contracts-v2` from the retired dual-folder layout. Fix (03b82238): bundle
records the single canonical commit. Lesson: a green pipeline can mask never-run jobs and warm-cache luck.

*Recorded powdr follow-ups (NOT started):*
- **N1 (actionable now, days):** differential cross-validation harness — bodyL/loop fragments through
  powdr yul-semantics interpreter vs EVMYulLean exec; document agreement in L10 (A-EVM row).
- **N2 (watch):** yul-compiler coverage of mstore/calldatacopy/staticcall/keccak256/objects; when it accepts
  relay-shaped Yul, revisit the transport bridge (restate Yul-level results against powdr semantics, push
  through compile_correct) — would supersede item 7 (hsetup) in value as the ceiling-discharge route.
- **N3 (one-liner, next doc touch):** note in L10 residual roadmap naming the verified-Yul-compiler path
  as the emerging discharge route for solc-backend trust.

---

## ⭐ 2026-07-01 — CURRENT STATUS (superseded by the 2026-07-05 banner above; historical)

The engagement is now well past Gap B. On `relay-fix-3` (MR !135), all in
`flare-smart-contracts-v2`:
- **BR-1 / the full simulation relation `R` — COMPLETE.** `test-forge/fv/lean/bytecode-refinement/RelayLoopMemRead.lean:relay_loop_sound`
  proves ∀N: the deployed loop (real `mload(slot)&0xffff` body on validated EVMYulLean) accepts ⟹ total
  registered weight > threshold. Data layer proven in `…/DataLayer.lean` (`weight_read`, `mem_roundtrip`, …).
- **OP-1 (ecrecover empty-return failure ABI) — internalized both concretely and symbolically**
  (`test-forge/fv/RelayEcrecoverABI.t.sol` + `test-forge/fv/RelayEcrecoverSymbolicFV.t.sol`).
- **Docs**: the 13-level ladder `docs/relay-verification/` + the FV primer `test-forge/fv/README.md` are
  the authoritative tutorial/audit/repro record; EVMYulLean is pinned to `047f6307` (2025-09-24).
- **Foundry `Relay.t.sol`: 59 tests**; Halmos gate: 85 checks (57 proofs / 28 reach), 0 violations.

**The fuller, always-current log is the memory file** `~/.claude/projects/-Users-alen-Kingston-delo-abelium-flare-relay-verification/memory/relay-fv-engagement.md`.

> **Rename note:** the file called `gapB/GapB_close.lean` below was renamed to
> `test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean` (namespace `RelayBytecodeRefinement`).
> The historical Gap-B section is retained below for provenance only.

---

## 2026-06-20 — GAP B CLOSED (bytecode-level ∀N refinement, hole-free) [historical]

**Resume point: there is no open Gap-B work.** The Stop-hook goal ("close Gap B properly") is met.

- **File:** `flare-smart-contracts-v2/test-forge/fv/lean/gapB/GapB_close.lean` (later renamed to
  `…/bytecode-refinement/RelayBytecodeRefinement.lean`) — self-contained; built/checked against the
  **validated** NethermindEth EVMYulLean semantics under `/tmp/evmyul2` via `lake env lean` (EXIT 0).
- **Capstone theorems, all hole-free** — axioms exactly `[propext, Classical.choice, Quot.sound]`
  (NO `sorryAx`/`sorry`/extra `axiom`), re-verified from the *git-committed* copy from scratch:
  - `loop_acc` — induction on iteration count (fuel `3*m+10`): encoded For-loop run by validated `exec`
    accumulates `absAcc a m w` into `WW`, increments `II`.
  - `bytecode_loop_correct` (∀N<2²⁵⁶) — `exec (3*N+10) (For (cond N) post body) (Ok ss vs) = .ok (Ok ss vs')
    ∧ (Ok ss vs')[WW]! = absAcc 0 N ⟨0⟩`. Validated semantics computes the full accumulation for **all** N.
  - `bytecode_threshold_sound` (∀N) — accept (final `WW` > thr) ⇒ total accumulated weight > thr. This is
    `RelaySigLoop.threshold_sound` (Phase A, abstract ∀N∀K) **lifted onto the real bytecode semantics**.
- **Residual (single validated assumption, per fidelity ladder):** the data layer — `mload(sig_i)` yields
  the registered weight `w_i` — rests on EVMYulLean's FFI ByteArray memory model and is differentially
  validated (`absAcc`'s index-sum mirrors `RelaySigLoop.sumTake` over the registered weights). Everything
  from loop control flow → accumulation → threshold soundness is machine-checked end to end.
- **Why this matters:** closes the "abstract-model vs real-execution" gap that bounded tools (Halmos, fixed
  N) and Kontrol/Certora (both blocked by Relay's hand-rolled inline-assembly storage) could not bridge.
- **Full detail / how-to-resume-the-toolchain:** `test-forge/fv/lean/gapB/PROGRESS.md` (STATUS banner).

---

## 0. Mission

Two parallel goals on the Flare **`Relay.sol`** contract:
1. **Formal verification** — primary focus: the `relay()` function and **signature verification**.
2. **Make it robust** — address remaining audit issues.

Approach ordered by the user: **research first** (Act framework / Anja Petkovic Komel / Argot
+ wider EVM FV landscape + the existing audit reports), collect all data, *then decide the strategy together.*

Research anchors requested:
- https://anjapetkovic.com/ , https://www.argot.org/ , https://github.com/argotorg
- FMF Ljubljana talk "From smart contracts to proof assistants: the Act verification framework
  for Ethereum smart contracts": https://www.fmf.uni-lj.si/sl/obvestila/dogodek/2608/
- GitLab audit reports repo: https://gitlab.com/flarenetwork/support-software/ai-audit-reports

---

## 1. Key paths

| What | Path |
|---|---|
| Working dir (top) | `/Users/alen/Kingston/delo/abelium/flare/relay-verification` |
| Contract repo | `…/relay-verification/flare-smart-contracts-v2` (git, branch `zellic_audit`) |
| **Relay.sol** | `…/flare-smart-contracts-v2/contracts/protocol/implementation/Relay.sol` (1554 lines) |
| IIRelay (internal iface, `SigningPolicy` struct) | `…/contracts/protocol/interface/IIRelay.sol` |
| IRelay (public iface, `RelayInitialConfig`/`RelayGovernanceConfig`/`FeeConfig`, events) | `…/contracts/userInterfaces/IRelay.sol` |
| Off-chain reference encoder/validator (de-facto spec) | `…/scripts/libs/protocol/RelayMessage.ts` |
| Signature/byte encoders | `…/scripts/libs/protocol/{ECDSASignatureWithIndex,SigningPolicy,ProtocolMessageMerkleRoot}.ts` |
| Existing tests (Hardhat/TS, example-based, 2706 lines) | `…/test/unit/protocol/implementation/Relay.test.ts` |
| Foundry config (FV-relevant) | `…/foundry.toml`, `…/remappings.txt`, `…/test-forge/` |
| Audit reports clone (GitLab, private; git@…) | `/Users/alen/Kingston/delo/abelium/flare/ai-audits/ai-audit-reports` |
| **Dedicated Relay audit (best source, 658 ln, 2026-04-17, Opus 4.7)** | `…/ai-audit-reports/reports/gitlab_flarenetwork/fsp/flare-smart-contracts-v2/2026_04_17_alen_opus_4.7_relay/report.md` |
| Full v2 audit (1139 ln) | `…/2026_04_17_alen_opus_4.7_full/report.md` |
| Older Relay audit (119 ln, 2026-02-19) | `…/20_02_2026_alen_opus/report/protocol/relay.md` |
| Gemini protocol audit | `…/20_02_2026_alen_gemini/report/report-protocol.md` |

---

## 2. Branch reality check (IMPORTANT — already verified)

- Current checkout branch: **`zellic_audit`** (HEAD `91f0f2fa`).
- **`Relay.sol` is byte-identical between `main` and `zellic_audit`** (`git diff main zellic_audit -- …/Relay.sol` = 0 lines).
- The Relay fixes ("Relay audit 2 fix", "relay governanceFee fix", "Ecrecover returnsize check",
  random-number fix) are **already merged into `main`**. CHANGELOG v1.0.3 (2026-02-23) = "Fixed: Relay contract".
- Branch diff vs main is only **FDC + deployment/config** files (FdcVerification, IXRPPayment*, deploy json, package.json, yarn.lock).
- ⇒ "Relay on this branch vs main" is a no-op. Meaningful comparison = **current Relay.sol vs audit findings**.
- **Contract repo has NO `develop` branch** (`git ls-remote origin develop` → "couldn't find remote ref"). So the user's "use develop branch" instruction applies to the **ai-audit-reports** repo, not the contract. Contract work stays on current Relay.sol (= main).
- **User directives (2026-06-14):** FV = research-only for now, explore ALL options (don't commit to one). Issues = collect the COMPLETE list first; fixes later go on a **separate branch** (selected issues only). → see §10/§11.

---

## 3. Contract model (verified by reading source)

`relay()` (Relay.sol L459-1393) is ~930 lines of hand-written **inline assembly**. Three paths:
- **Mode 1** `protocolId == 0` (L911-1069): relay/rotate a **new signing policy** (must be next reward epoch; threshold-consistency check; writes new policy hash + startingVotingRoundId; emits `SigningPolicyRelayed`).
- **Mode 2** `protocolId > 1` (L766-906, 1219-1382): publish **Merkle root** for (protocolId, votingRoundId); random-number protocol updates `stateData` + `isSecureRandomMap`; emits `ProtocolMessageRelayed`.
- **Custom-signature** `protocolId == 1` (L801-817, 1229-1236): returns `(merkleRoot, rewardEpochId)`; **does NOT persist anything**. Used by `verifyCustomSignature()` (L428) and `governanceFeeSetup()` (L438).

**Signature verification core (L1108-1388):** *(historical line numbers; predates RLY-23. The RLY-23
digest below was later revised from `chainid` to the configured `sourceChainId` immutable — 2026-08-03 banner.)*
- Prefixed hash `keccak256("\x19Ethereum Signed Message:\n32" ‖ messageHash)` built in slot 0 (L1110-1112).
  **Post-RLY-23 (2026-07-23):** `messageHash` is now the chain-bound digest `keccak256(chainid ‖ keccak256(message))`
  (and the signing-policy hash is `keccak256(chainid ‖ contentFold)`); the prefix step is otherwise unchanged. See
  the top ⭐ banner and `docs/relay-fixes.md` RLY-23.
- Loop over `numberOfSignatures`; each signature is 67 bytes = `v(1) ‖ r(32) ‖ s(32) ‖ index(2)`.
- `index` bounds-checked (`index < numberOfVoters`) and forced **strictly increasing** (`nextUnusedIndex`) ⇒ no double-count, neutralizes malleability.
- `ecrecover` via `staticcall(0x01,…)`; checks `returndatasize()==32`; compares recovered addr to policy `voters[index]`; accumulates `weights[index]`.
- Accept when `weight > threshold` (returns/stores per mode). Else falls through to `revert NotEnoughWeight()` (L1392; the former `revert("Not enough weight")` string).

**Byte layouts (constants in Relay.sol L64-176; encoders in scripts/libs):**
- Signing policy prefix 43 B = numVoters(2) ‖ rewardEpochId(3) ‖ startVotingRoundId(4) ‖ threshold(2) ‖ seed(32); then per-voter 22 B = addr(20) ‖ weight(2). `rewardEpochId` is `uint24`.
- Message 38 B = protocolId(1) ‖ votingRoundId(4) ‖ isSecureRandom(1) ‖ merkleRoot(32).
- Signature-list = count(2) then 67 B each.
- `RelayMessage.encode(msg, verify=true)` (RelayMessage.ts L31-89) reproduces the **exact** acceptance predicate (index ascending, recovered==policy voter, totalWeight > threshold). **This is the cleanest reference spec for equivalence checking.**

Constants: `THRESHOLD_BIPS=10000`, `MAX_VOTERS=300`, `MIN_THRESHOLD_BIPS=5000`, `MAX_THRESHOLD_BIPS=6600`.

---

## 4. Consolidated remaining issues (cross-checked across 3 audit reports; presence confirmed in current source)

| ID | Sev | Issue | Location | Confirmed present? |
|---|---|---|---|---|
| **H-01** | High | `governanceFeeSetup` **replay** — `protocolId==1` path never records a consumed-marker; no nonce/timestamp in `RelayGovernanceConfig`; fee written *before* verify | `governanceFeeSetup` L438-454 (fee write L442-446); relay() return L1229-1236; "Already relayed" check L797 always reads `merkleRootsPrivate[1][0]==0` | **YES** |
| **HIGH-01** | High (Feb) / omitted (Apr) | `verify()` accepts proof against **uninitialized (zero) Merkle root** (zero leaf + empty proof ⇒ `0==0` true) | `verify()` L1398-1421 (no `root != 0` guard at L1407-1410) | **YES** (re-confirm severity/exploitability w/ user) |
| L-01 | Low | `getRandomNumber()` returns deterministic `keccak256(abi.encode(0))` in bootstrap window (vs `getRandomNumberHistorical` which reverts) | L1453-1469 | YES |
| L-02 | Low | `verify()` does not refund fee **overpayment** (sweeps full `msg.value`) | L1412-1418 | YES |
| M/N | Med→Note | `feeCollectionAddress` immutable, no setter; no constructor zero-check when feeConfigs present | L191, L253 | YES |
| N-01 | Note | No `mload(M_2)==0` zero-signer guard in asm; `setSigningPolicy` no zero/duplicate voter check (mitigated by `returndatasize==32`) | L1164-1200; L297-423 | YES |
| N-03 | Note | ECDSA `s`-malleability + `v∉{27,28}` unchecked (neutralized by strict index ordering; defence-in-depth only) | L1136-1200 | YES |
| N-04 | Note | `lastInitializedRewardEpoch - 1` underflow (unreachable given +1-monotonic invariant) | L449-453 | YES |
| N-06 | Note | `bytes3(rewardEpochId)` truncation above 2^24 (~47 yrs away) | L334-348 | YES |
| N-07 | Note | `verifyCustomSignature` state-mutating; a `view` variant would aid off-chain sim | L428-433, L1533-1553 | YES |
| N-08 | Note | Hard-coded event-signature string literals in asm (no compile-time ABI sync) | L1067-1068, L1293-1294, L1375-1376 | YES |
| INFO | Info | `ecrecover` returndatasize check present (good); memory-slot reuse correct; event-sig hashes correct; `calculateSigningPolicyHash` no off-by-one | — | confirmed in reports |

**Robustness/testing gap:** existing tests are Hardhat/TS example-based only. No tests for: H-01 replay, zero-root `verify`, signature malleability, zero-address signer. **No Foundry/symbolic test for Relay at all** (no `Relay.t.sol`).

---

## 5. FV tooling readiness (verified)

- Repo **is Foundry-enabled** (`foundry.toml`: src=contracts, test=test-forge, evm_version=cancun, optimizer 200; soldeer deps forge-std 1.10, OZ 5.4, flare-periphery). ⇒ **Halmos and Kontrol can consume it directly.**
- **No** existing halmos/certora/kontrol/hevm config (greenfield FV setup).
- **No** `Relay.t.sol` in `test-forge/` (Relay only has the Hardhat test).
- `RelayMessage.ts encode(verify=true)` = ready-made reference predicate.

---

## 6. Research workflow (web half) — IN PROGRESS

- **Run ID:** `wf_8d6a89c7-80e` · **Task ID:** `wjbxi249j` · status at last check: **running**.
- **Script:** `/Users/alen/.claude/projects/-Users-alen-Kingston-delo-abelium-flare-relay-verification/989cdb1c-587d-4680-96d7-c37f65597775/workflows/scripts/relay-fv-research-wf_8d6a89c7-80e.js`
- **Resume after a reset:** `Workflow({scriptPath: "<above>", resumeFromRunId: "wf_8d6a89c7-80e"})` (cached agents return instantly). Same-session only; if a new session, just re-run the script fresh.
- **Covers (11 research + 11 adversarial-verify agents):** Anja Petkovic Komel · FMF talk · **Act** framework (Coq/Isabelle backends + hevm bytecode refinement) · **Argot/argotorg** org+repos · **hevm** (symbolic + `equivalence` + Foundry tests; precompile/ecrecover modeling) · **KEVM/Kontrol** · **Certora** (CVL, ecrecover summary, inline-asm support, Gnosis Safe etc.) · **Halmos** + Echidna/Medusa/ItyFuzz · how tools model **ecrecover/ECDSA** · verifying **assembly-heavy** contracts (SMTChecker can't do inline asm) · **relay/bridge/threshold-multisig FV prior art**.
- Results returned to main agent as `{research:[…], verifications:[…]}` — **fold into §7 when received**, then write the synthesis.

### Load-bearing claims being verified (must confirm before relying on them)
1. Act → Coq and/or Isabelle/HOL proof obligations (not just SMT).
2. Act+hevm prove **bytecode refines the Act spec** ⇒ inline assembly handled natively (bytecode-level).
3. hevm = symbolic exec + `equivalence` + symbolic Foundry tests, SMT (z3/cvc5/bitwuzla).
4. argotorg/Argot maintains Act+hevm; grew out of EF FV effort.
5. Anja Petkovic Komel ∈ Argot/EF FV; proof-assistant/type-theory background; works on Act.
6. **No mainstream tool computes real ECDSA**; ecrecover modeled abstract/uninterpreted ⇒ proofs rest on stated ecrecover assumptions.
7. solc **SMTChecker does not support inline assembly** ⇒ unsuitable alone for Relay.
8. Halmos = bytecode-level symbolic over Foundry tests; ecrecover → fresh symbolic address.
9. KEVM = full EVM semantics in K; Kontrol over Foundry; bytecode-level.
10. FMF talk = pipeline from EVM contracts to proof-assistant proofs via Act.
11. Certora = partial inline-asm support; ecrecover via summary; verified Gnosis Safe etc.

---

## 7. Research synthesis  — ✅ DONE (workflow wf_8d6a89c7-80e, 22 agents, 2026-06-14)

Full parsed results: workflow output `/private/tmp/claude-502/…/tasks/wjbxi249j.output`;
per-topic digest `…/989cdb1c-…/tool-results/b5ee146tk.txt`.

### People / org
- **Anja Petković Komel**: FV researcher at **Argot Collective** (since Jul 2025; anja@argot.org); prev EF FV team (Mar–Jun 2025); postdoc TU Wien; PhD U. Ljubljana under Andrej Bauer (dependent type theory, **Andromeda 2** prover, equality checking). Co-author of **Act** (arXiv 2604.02955, Apr 2026) and **CheckMate** (game-theoretic security, CCS'23). ORCID 0000-0001-7203-6641.
- **Argot Collective**: non-profit, ~25 former-EF staff, largest EF spin-out (announced Devcon SEA, Oct/Nov 2024); EF 3-yr grant. Maintains **Solidity, hevm, Act, Fe, Sourcify, ethdebug, solcore, yul-isabelle**. GitHub org `argotorg`.
- **FMF talk** (`dogodek/2608`): page is **404**, no Wayback snapshot → abstract unrecoverable. Verifier places the Act talk at **ETH Prague 2026** ("Specifying and verifying Ethereum smart contracts"); content reconstructed from Act docs + arXiv. Treat FMF venue as unverified; content is solid.

### The Act framework (the requested approach)
- High-level behavioral **spec language** for EVM contracts (state-transition system; `constructor/behaviour/iff/storage/returns/case/ensures/invariants`); seL4-style refinement philosophy. v0.2.0 (Jan 30 2026). Case studies: ERC20, Uniswap V2.
- **Two backends**: (1) **hevm** — *automatically* proves compiled EVM bytecode implements the Act spec (symbolic exec + SMT cvc5/z3/bitwuzla); (2) **Rocq/Coq** — exports spec as a transition system for **manual proofs of arbitrary-complexity** invariants. "Proof chain right down to bytecode." (Lean listed on her site but NOT implemented; **Isabelle is NOT a backend** — earlier assumption corrected.)
- **Limitations:** ❌ unbounded loops; ❌ aliased contract refs; equiv toolchain target is **Solidity/Vyper** source ("Currently in v0.2.0, Solidity and Vyper are supported"); historically weak dynamic/compound-type proofs; SMT can't do symbolic exponentiation.

### ⭐ THE PIVOTAL FINDING (drives strategy)
**hevm — Act's automatic backend — does NOT model `ecrecover` (0x01) symbolically.** Source `EVM.hs executePrecompile` case `0x1` = `forceConcreteBuf input "ECRECOVER"` with `-- TODO: support symbolic variant`. Only SHA256 (0x2) is available as an uninterpreted fn for symbolic args. ⇒ Symbolically executing `relay()` with hevm/Act **stalls at the precompile** the moment signatures are symbolic. Relay's whole critical path is signature recovery, so this is a **real, current blocker** for a pure Act/hevm all-inputs proof of the signature path.
- **Tools that DO model ecrecover as uninterpreted (so they reason over all symbolic signatures):** **Certora** (CVL ghost fn + optional axioms), **Halmos** (`f_ecrecover` Z3 uninterpreted, deterministic), **KEVM/Kontrol** (`#symEcrec` / `smtlib(ecrec)`). These are better suited than hevm/Act on the ecrecover point *today*.

### ecrecover / ECDSA modeling (universal truths)
- **No tool proves the cryptography.** Abstract/uninterpreted ecrecover gives exactly ONE free property: **determinism** (same `(hash,v,r,s)`→same address). hevm forces concrete instead.
- **Provable over abstract ecrecover:** index strictly-increasing ⇒ each policy slot counted ≤once (dedup); weight-accumulation correctness; threshold comparison; no overflow; **accept ⇒ Σ weights of distinct authorized voters > threshold**.
- **Must ASSUME (trust boundary):** non-forgeability (modeled by leaving recovered addr symbolic/arbitrary and proving logic correct ∀ addresses); ecrecover→0 on failure; determinism.
- Malleability: Relay checks neither low-`s` nor `v∈{27,28}`, but **strictly-increasing index neutralizes double-count** (= Gnosis Safe's owner-sorted dedup).

### Prior art = the template
- **Runtime Verification proved Gnosis Safe `checkSignatures` in KEVM** (bytecode-level): accept iff ≥threshold valid sigs from owners, **sorted by owner address** (dedup). Found: signatureSplit no bounds-check, `v∈{0,1}` contract-sig handling, **reentrancy (EIP-1271 call before nonce++)**, missing recovery-param checks. **Strongest template for Relay** (same property family; Relay's strictly-increasing index ≈ Safe's owner-sort).
- Certora: Safe v1.5.0 (Signatures.spec abstracts crypto), LayerZero Endpoint V2, Aave Starknet/L2 bridges.
- SMTChecker: explicitly **does not fully support assembly** (sound over-approx → false positives) ⇒ unusable for proving `relay()` properties. Bytecode-level tools handle assembly natively.
- hevm `equivalence` tutorial = optimized-vs-reference pattern (the natural Relay shape: assembly `relay()` vs clean reference) — but same ecrecover-concretization caveat applies.

---

## 8. Decision menu (PRESENT TO USER — pick FV path + robustness scope)

All paths are **bytecode-level** (assembly forces this) and share the **abstract-ecrecover trust boundary**.

- **A — Halmos (Foundry-native symbolic tests). RECOMMENDED FIRST.** Lowest friction (Foundry already here). Uninterpreted `f_ecrecover` ⇒ prove core properties ∀ symbolic signatures/policies, bounded by `--loop` on N: no double-count, accept⇒weight>threshold over distinct authorized voters, index bounds, no overflow, per-mode replay. Bounded (fix N≤k). Produces `Relay.t.sol` reusable by Kontrol. Fast ROI.
- **B — KEVM / Kontrol (deductive, strongest).** Mirrors the Gnosis Safe precedent exactly. Inductive loop invariants (not just bounded unrolling) ⇒ unbounded signature loop. Highest assurance; heaviest effort / K expertise. Uninterpreted ecrecover.
- **C — Act + Rocq + hevm (the requested "north-star").** Write human-readable Act spec of `relay()`; prove invariants in **Rocq**; link spec↔bytecode via hevm. Most elegant + best for engaging Argot/Komel. **Caveats:** hevm symbolic-ecrecover gap blocks the signature-path bytecode link today (works with concrete sigs / awaits hevm extension); no-unbounded-loops; Solidity/Vyper target. Best as spec+documentation layer now, full link later.
- **D — Certora.** Industrial; ghost ecrecover + axioms; proven on Safe/bridges. Commercial license; **risk:** inline-assembly `sload/sstore` can defeat its storage analysis/hooks (Relay is raw-asm storage).

**Recommended hybrid (staged):** (1) robustness fixes now (independent of tool); (2) `Relay.t.sol` + **Halmos** for fast bounded proofs + regression net; (3) escalate signature loop to **KEVM/Kontrol** (Gnosis-Safe-style); (4) **Act/Rocq** spec as north-star + engage Argot; (5) document abstract-ecrecover boundary everywhere.

### Robustness track (independent of FV tool; do in parallel)
1. **H-01 replay** — add consumed-marker (e.g. `mapping(bytes32=>bool)` on messageHash) or a `nonce` in `RelayGovernanceConfig`; move fee-write to *after* `_verifyCustomSignature`.
2. **Zero-root `verify()`** — decide whether to add `require(root != 0)` (HIGH-01; confirm exploitability/severity with user).
3. Defence-in-depth: zero/duplicate-voter check in `setSigningPolicy`; `mload(M_2)==0` zero-signer guard; underflow guard on `lastInitializedRewardEpoch-1`; `getRandomNumber` revert-on-empty (match historical); `verify()` overpayment refund; `feeCollectionAddress` setter + constructor zero-check; event-signature regression test; optional low-`s`/`v` checks.
4. Add **`Relay.t.sol`** Foundry suite (also the Halmos/Kontrol substrate). Current tests are Hardhat/TS example-based only; no malleability/replay/zero-addr/zero-root tests.

---

## 9. Resume protocol (read this first if resuming)

1. Read this file end-to-end.
2. Check research workflow: `TaskOutput(task_id="wjbxi249j", block=false)`. If `completed`, results are in the workflow return value / transcript dir `…/989cdb1c-…/subagents/workflows/wf_8d6a89c7-80e`. If a new session (task gone), re-run the script (path in §6) fresh.
3. Fill §7 (synthesis) and §8 (decision menu); present to user. **Do not start implementing** FV/fixes until the user picks a strategy (they asked to "decide from there").
4. Nothing has been modified in the contract repo yet — this is still research/planning phase. No git commits made.

---

## 10. ai-audit-reports `develop` sweep — COMPLETE Relay issue inventory (2026-06-14)

- Audit clone `/Users/alen/Kingston/delo/abelium/flare/ai-audits/ai-audit-reports` updated via SSH; now on branch **`develop`** (HEAD `489db35`). Much richer than `main`: per-run reports under `reports/gitlab.com/flarenetwork/FSP/flare-smart-contracts-v2/<run>/` (each: `report.md`, `valid_issues.md`, `handout.md`, `process.yaml`). No central issue DB (`reports/_state` only has branch-retirement manifests).
- **fscv2 runs:** 2026-05-20 gemini, 05-21 codex/gpt-5, 05-22 gemini, 05-23 deep-audit (opencode), **05-23 deep-creative (opus-4-7) [76KB, the cited "05-24-deep-creative"]**, 05-26 deepseek, 05-29 deep-sweep (opus-4-8), **06-10 robustness-exactness-soundness (opus-4-8) [173KB, the cited "fscv2-robustness-0610", newest/most thorough]**.
- `valid_issues.md`: deep-creative's is **empty** (issues only in report.md); robustness-0610's lists 10 confirmed Mediums (M-01..M-10) — Relay ones are **M-07 & M-10 (same issue)**.

### Master deduplicated Relay issue list (across all develop runs + earlier dedicated relay audits). Severity = latest-triage consensus. All confirmed present in current Relay.sol unless noted.

| ID | Sev | Essence | Source(s) | Agent's 12? |
|---|---|---|---|---|
| RLY-01 | Med (orig High) | `verify()` returns true vs **zero/unset Merkle root** (zero leaf + empty proof ⇒ 0==0). Bounded: no in-repo prod consumer routes through `relay.verify()`. | DC #H-01, RB #L-29, (≈Feb HIGH-01) | ✓ (#H-01) |
| RLY-02 | Med | **`governanceFeeSetup` replay**: signed digest omits a nonce AND `address(this)` ⇒ within-window re-application + **cross-deployment** replay after a redeploy/migration. Fix: bind `address(this)`+nonce, move fee-write after verify. | DC #M-01, deep-sweep, (≈Apr H-01) | ✓ (#M-01) |
| RLY-03 | Med | **Random pointer non-monotonic**: a stale, never-relayed within-window random round can be relayed AFTER a newer one (permissionless) ⇒ `randomVotingRoundId` regresses ⇒ stale/predictable random + timestamp served to FTSO clients & FlareSystemsManager vote-power-block selection. Fix: only advance pointer if `votingRoundId > stored`. **NEW (not in earlier dedicated audits).** | RB #M-07 = #M-10 | ✓ (#M-07) |
| RLY-04 | Low | Mode-2 `relay()` accepts `merkleRoot==0` finalization ⇒ breaks `isFinalized`, event spam. | DC #L-01 | ✓ |
| RLY-05 | Low | Threshold scaling by `thresholdIncreaseBIPS` uses **truncating division** (≤1 weight-unit bias toward attacker). | DC #L-02 | ✓ |
| RLY-06 | Low | `setSigningPolicy`/Mode-1 don't reject **address(0) voters**; also **no duplicate-voter** check. | DC #L-03, opencode #520 | ✓ (zero only) |
| RLY-07 | Low | `_verifyCustomSignature` self-call validated only by a **35-byte return-length sentinel** (brittle encoding). | DC #L-04 | ✓ |
| RLY-08 | Low | Mode-1 writes policy state **before** signature aggregate verified (atomicity-safe today). | DC #L-05, (≈Feb LOW-03) | ✓ |
| RLY-09 | Low | "Already relayed" sentinel coupled to merkle-root storage instead of a dedicated finalized flag (upgrade fragility). | DC #L-06 | ✓ |
| RLY-10 | Low | `feeCollectionAddress` not validated non-zero ⇒ fees burned; also **no setter**. | RB #L-31, (≈Feb MED-01/LOW-02) | ✓ |
| RLY-11 | Low | Constructor doesn't validate positivity of `rewardEpochDurationInVotingEpochs`/`votingEpochDurationSeconds` (**div-by-zero**). | RB #L-30 | ✓ |
| RLY-12 | Low | Legacy random getters (`FtsoProxy`/`PriceSubmitterProxy`) drop `_isSecureRandom` ⇒ V1 consumers get insecure randomness. (in fscV1 proxies, not Relay.sol) | RB #L-14 | ✓ |
| **RLY-13** | Note (opencode: High) | **OldRelay fallback in `verify()`** forwards `msg.value` to `oldRelay.verify` then doesn't revert if it returns `false` ⇒ fee lost in migration window. | opencode #H-04 (L1402-1403) | ✗ **MISSED** |
| **RLY-14** | Note | Mode-2B accepts any non-zero `isSecureRandom` byte (not normalized to {0,1}). | DC #N-01 | ✗ **MISSED** |
| **RLY-15** | Note | `verify()` accepts `_leaf == root` with empty proof when finalized ⇒ relies on domain-separated leaf encoding off-chain. | DC #N-02 | ✗ **MISSED** |
| RLY-16 | Note | ECDSA **s-malleability / v∉{27,28}** unchecked (neutralized by strict index ordering; defence-in-depth). | Apr N-03 | d-i-d |
| RLY-17 | Note | `lastInitializedRewardEpoch-1` underflow unreachable (monotonic invariant). | Apr N-04 / Feb MED-02 | d-i-d |
| RLY-18 | Note | No `mload(M_2)==0` zero-signer guard in assembly. | Apr N-01 | d-i-d |
| RLY-19 | Note | `bytes3(rewardEpochId)` truncation above 2^24 (~47 yr). | Apr N-06 | d-i-d |
| RLY-20 | Note | `getRandomNumber` returns deterministic `keccak256(0)` in bootstrap window (≈ RLY-04 family). | Apr L-01 | — |
| RLY-21 | Note | `verify()` no overpayment refund (related to RLY-13). | Apr L-02 | — |
| RLY-22 | Note | `verifyCustomSignature` could have a `view` variant; hardcoded event-sig literals (maintainability). | Apr N-07/N-08 | — |

---

## 11. Reconciliation of the other agent's 12-issue list + directives

- **The 12 cited issues are all real and the verdicts are reasonable** (deep-creative #H-01,#M-01,#L-01..#L-06; robustness-0610 #M-07,#L-14,#L-30,#L-31; dedupe #M-10→#M-07 and #L-29→#H-01 is correct).
- **But it is INCOMPLETE** (user was right — "there are more issues"). Missing: **RLY-13 (OldRelay fallback fund loss, opencode #H-04)**, **RLY-14 (isSecureRandom normalization, #N-01)**, **RLY-15 (leaf==root, #N-02)**, the **duplicate-voter** half of RLY-06, and the earlier dedicated-relay-audit defence-in-depth notes (RLY-16..RLY-22).
- **Provenance caveat:** the agent's folder slugs partly don't match the actual `develop` tree — e.g. "06-01-deep-sc-v2" and "fscv2-deep-0528" have **no matching run** (actual fscv2 runs are 05-20/05-21/05-22/05-23×2/05-26/05-29/06-10). Its "05-24-deep-creative" = the 05-23 deep-creative run; "fscv2-robustness-0610" = the 06-10 run. Treat its provenance refs as approximate; this inventory is verified against the real `develop` folders.
- **Substantive priority:** RLY-02 (gov-fee replay) and RLY-03 (random-pointer monotonicity) are the two clear Mediums to fix; RLY-01 (zero-root verify) is the historically-High-rated one (now bounded). RLY-13 deserves a look despite being a Note.

### Plan per user directives
1. **Now:** complete-issue collection — DONE (this section). 
2. **Next:** when user approves, implement **selected** fixes on a **separate branch** of the contract repo (no `develop` exists → branch off current/`main`, e.g. `relay-robustness`). Do NOT edit Relay.sol until issue selection is agreed.
3. **FV:** keep researching ALL options (Halmos / KEVM-Kontrol / Act+Rocq / Certora); no commitment yet. Each FV harness also serves as a regression net for the fixes.

---

## 12. Implementation progress — `relay-fix-3` (uncommitted; live as of 2026-06-14)

Branch `relay-fix-3` off `origin/main` (`264dab74`). Fix doc: `flare-smart-contracts-v2/docs/relay-fixes.md` (per-issue source of truth). Deps installed (Hardhat + Foundry). Baseline before changes: Hardhat 46 passing.

- **RLY-02 (gov-fee replay) — ✅ DONE.** `IRelay.RelayGovernanceConfig` +`nonce`; `RelayGovernanceFeeConfigured` event; `governanceFeeNonce` (strictly-increasing); digest binds `address(this)`; fee-write after verify. Tests: Hardhat 46 passing; Foundry `Relay.t.sol` 4 passing (incl. signing-policy-hash self-check).
- **RLY-03 (true Merkle-proven random, folds in RLY-14) — ✅ DONE.** `toRandomNumberPrivate` mapping; `processRandomMerkleProof` asm helper; calldata trailer `randomNumber(32)+proof` after sigs; leaf `keccak256(votingRoundId||value||isSecure)` (branch format, unchanged off-chain); monotonicity guard (live pointer only advances for newer round; historical always stored); RLY-14 isSecureRandom normalization; NEW event `RandomNumberRelayed`; `ProtocolMessageRelayed` kept; getters read `toRandomNumberPrivate`; kept main's ecrecover/oldRelay/stateData() (no branch regressions). New slots M_7=224, M_8=256. Off-chain `RelayMessage.ts` encode-trailer ported (decode-trailer = minor follow-up). Tests: **Foundry 8 passing**, **Hardhat 46 passing**. Adversarial 6-lens asm review (wf `wjwtmdgac`): no defects; one negligible LOW accepted (`getRandomNumberHistorical` value-0 sentinel, ~2⁻²⁵⁶). Recorded in docs/relay-fixes.md.

**Decisions locked:** scope = substantive set (RLY-02,03,01,13,21,10,11,06,04); RLY-03 = true-random redesign w/ monotonicity; tests = Hardhat + Foundry; leaf format fixed to branch's. NO commits until user confirms.

**Resume:** **ALL agreed fixes + selected notes DONE & green (uncommitted).** Implemented+tested: RLY-02, RLY-03(+RLY-14), RLY-01, RLY-13, RLY-21, RLY-10, RLY-11, RLY-04, RLY-16, RLY-17, RLY-18, RLY-22. Documented: RLY-06, RLY-07, RLY-09, RLY-15, RLY-19, RLY-20. Deferred: RLY-05, RLY-08, RLY-12. Tests: **Foundry 21 passing, Hardhat (Relay) 54 passing**; Submission unit green. Per-issue detail in `docs/relay-fixes.md`.

⚠️ **EndToEnd integration test (`test/integration/EndToEnd.test.ts`): RLY-03 broke it** (baseline 36/36 → ~20 fail) because it relays the random protocol the old way (no value+proof trailer) and asserts `getCurrentRandom()==keccak256(root)`. Fixed `relay2` feeCollection (RLY-10). The random-relay migration is being done by background agent **a638bea882ea17111** (only edits EndToEnd.test.ts; target 36/36; reference = `relay-fix-random-2` branch's EndToEnd.test.ts).

✅ **DONE — committed + MR opened.** EndToEnd restored to 36/36 (random-relay trailer migration). Commit `ab272a73` on `relay-fix-3` (8 files: Relay.sol, IIRelay.sol, IRelay.sol, RelayMessage.ts, Relay.test.ts, EndToEnd.test.ts, test-forge/.../Relay.t.sol, docs/relay-fixes.md). Pushed to `origin/relay-fix-3`. **MR !135 → main:** https://gitlab.com/flarenetwork/FSP/flare-smart-contracts-v2/-/merge_requests/135
Final green: Foundry 21 · Hardhat Relay 54 · EndToEnd 36 · Submission green.

NEXT (open): watch MR !135 CI; address review feedback. Deferred items remain (RLY-05/08/12) + the FV phase (Halmos/Kontrol/Act on relay()/signature verification, reusing test-forge/.../Relay.t.sol). RLY-07's full typed-discriminator and RLY-03's RelayMessage.decode-trailer are tracked as follow-ups in docs/relay-fixes.md.

---

## 13. Security review + post-review hardening — ✅ DONE & PUSHED (2026-06-14)

Did a security review of the updated contract + test coverage. Report: **`docs/relay-security-review.md`** (adversarial multi-agent, 46 agents; no critical/high; 1 Medium + Low cluster; signature/threshold core + RLY-03 random confirmed sound). User selected which to implement; all done, tested, committed, pushed.

**Implemented (commit `463fd59c` on `relay-fix-3`, follow-up to `ab272a73`; pushed → MR !135 auto-updated):**
- **M-1 (Medium) ✅** — `verify()` oldRelay fallback forwards only `oldRelay.protocolFeeInWei`, requires `msg.value >= oldFee` + old-relay success, refunds the rest (honours RLY-21 contract uniformly). `MockOldRelay` gained `protocolFeeInWei`.
- **L-1 (Low) ✅** — `getRandomNumberHistorical` gates presence on `merkleRootsPrivate[randomNumberProtocolId][vrid] != 0` (RLY-04 ⇒ non-zero roots), returns value (may be 0). Kills the value-0 sentinel collision.
- **L-4 (Low) ✅** — constructor `require(initialSigningPolicyHash != 0)`.
- **L-2 / L-3 📝** — `IRelay` NatSpec: verify() refund is value-bearing (caller must receive ETH); verifyCustomSignature is an unbound oracle (callers must domain-separate).
- **L-6 📝 (downgraded)** — start-round monotonicity left to the trusted setter as a **code comment**, NOT an on-chain require: the require pre-empted an existing voters-count test and conflicts with valid setter configs. (Like RLY-06/L-8.)
- **L-7 📝** — comment: `votingRoundId==0`-first-round random under-report edge is unreachable in production.
- **L-5** — nonce kept **strictly-increasing** (user's choice; trade-off documented). No code change.

**Coverage added (Foundry `Relay.t.sol`):** High — `test_random_monotonicity_acrossRewardEpochs`; Medium — `test_random_malformedTrailerLength_reverts`, `test_random_deepMerkleProof`, `test_random_isSecureNormalization`, `test_threshold_exactBoundary_strictGreater`, `test_verify_feeReceiverReverts`, `test_verify_refundReceiverReverts` (+ `RevertingReceiver` helper).

**Final green:** **Foundry 31 passing · Hardhat Relay 54 + Submission + EndToEnd 36 = 93 passing.** Working tree clean.

NEXT (open): watch MR !135 CI; address review feedback. Remaining Low coverage gaps + Halmos/Kontrol FV invariants (see review doc §"Formal-verification opportunities") are deferred — the natural next phase is the FV track on `relay()`/signature verification.

---

## 14. Round-2 re-review of the UPDATED contract — ✅ DONE & PUSHED (2026-06-15)

Re-reviewed `Relay.sol` @ `463fd59c` (after Round-1 M-1/L-1/L-4 landed) via an 80-agent adversarial workflow (11 dimensions × 3-lens verify + 2 coverage angles + completeness critic). **Verdict: CLEAN — zero findings survived.** The fixes introduced no new defect; the assembly core was independently re-confirmed sound (memory layout, ecrecover overlap, governanceFeeSetup reentrancy). The one substantive open question — **silent shadowing** (new-relay Mode-2 write below the old-relay read boundary) — I verified **unreachable** by reading the gates ("Wrong sign policy reward epoch" + "Delayed sign policy" + constructor invariant ⇒ every write `votingRoundId ≥ startingVotingRoundIdForInitialRewardEpochId`). Full report: `docs/relay-security-review.md` → "Round 2".

User selected: **all four coverage bundles + doc-only for critic items.** Implemented, tested, committed (`58b811ef` on `relay-fix-3`), pushed → MR !135.
- **Coverage: Foundry `Relay.t.sol` 31 → 52, Hardhat 93.** Added M-1 fallback fee edges (too-low-fee / exact-fee-no-refund / zero-fee-full-refund), governanceFeeSetup negatives (invalid-protocol-id, setter-mode), verifyCustomSignature direct, verify() merkle-proof-invalid / invalid-protocol-id, relay-mode getter lockouts, getVotingRoundId before-start, getRandomNumber pre-relay default, "No random number" short trailer, oldRelay read-delegation (MockOldRelay extended), signature index/zero-sig checks, constructor oldRelay-incompat + timing mismatch, relay()-path accept-300-voters (Hardhat), reentrancy DiD. New test helpers: `MockOldRelaySetterMode`, `ReentrantReceiver`, `MockOldRelay` sentinel getters.
- **Skipped (documented, low value):** exact totalWeight 65535/65536 off-by-one (already covered qualitatively + fragile); Foundry "Message too old" window (covered in Hardhat).
- **Doc-only contract changes:** L-6 transitive-via-signed-hash note, RLY-06 index-ordering linkage, shadowing-unreachable invariant, migration-handshake note. `messageFinalizationWindow` bound + `uint32+1` getter edge left as Info.

Working tree clean. NEXT (open): MR !135 CI; the FV track (Halmos/Kontrol on the now-richer `Relay.t.sol` harness) remains the natural next phase.

---

## 15. FV track Phase 0/1 — IN PROGRESS (2026-06-15). See `flare-smart-contracts-v2/docs/relay-fv.md`.

**Phase 0 DONE.** Halmos 0.3.3 + z3 4.12.6 in isolated venv `../.venv-halmos` (outside repo). Toolchain proven (`test-forge/fv/HalmosSmoke.t.sol`: 1 PASS + 1 expected CEX). Repo builds to `artifacts-forge` ⇒ Halmos needs `--forge-build-out artifacts-forge` (persisted in `halmos.toml`). Modeling contract (uninterpreted keccak/ecrecover = prove accounting, assume crypto; bounded K; RLY-06 distinct-voters as formal premise) written in `docs/relay-fv.md`.

**Phase 1 — FIRST VALID BOUNDED PROOFS (2026-06-15).** `test-forge/fv/RelaySigFV.t.sol` on the real `relay()` (concrete N=5/weight 100/threshold 260 policy, symbolic sigs): `check_threshold_twoVoters_cannotAccept` PASS, `check_noDoubleCount_duplicateIndex_cannotAccept` PASS, `check_reachability_threeVoters_canAccept` → counterexample (non-vacuity confirmed). ~0.7s.

**ROOT CAUSE of the earlier "accept unreachable" puzzle = Halmos `--loop` default 2** (silently truncates relay()'s per-signature loop ⇒ 3+ sig accept paths cut off ⇒ vacuous passes). Proven by: 3-sig reachability is fast-UNSAT at loop 2 (even with 8-min solver budget) but flips to a counterexample at `--loop 4`. **Fixed in `halmos.toml` (`loop = 6`).** The in-test reachability control is the standing tripwire. (The author's hint — relay-only mode doesn't enforce `setSigningPolicy`'s minimal threshold on the constructor-set initial policy; only relayed policies hit `checkThresholdConsistency` at `:1109` — enabled the sub-minimal-threshold bisect that cracked it.) Diagnostic probes deleted. NEXT: P3–P8 (see `docs/relay-fv.md`).

**PARAMETRIC P1/P2 DONE + AUDITED (2026-06-15).** `test-forge/fv/RelaySigParamFV.t.sol` (symbolic weights+threshold, deployed in-check, empty setUp): `check_threshold_{1,2,3}sig_param` PASS (TIGHT per-prefix threshold soundness — closed the audit's only Medium, the total-sum-vs-accept-point looseness), `check_noDoubleCount_{tailDup,headDup}_param` PASS (`[0,1,1]`/`[0,0,1]`), `check_reachability_param` → counterexample (non-vacuity). 5 passed; 1 failed(by design). A 4-lens adversarial-audit workflow (wf_07b454b0-13b) returned **valid-with-documented-caveats, zero mustFix**. 7 standing caveats recorded in `docs/relay-fv.md` §6 (bounded shape K≤3; same-epoch only; anti-vacuity is a CI process control not static; distinct-voters A4 constructional; crypto assumed A1/A2; conservative input widening). Two harness bugs fixed en route: missing setUp override (multiple-paths) and a vacuous-in-reverse no-double-count (symbolic thr let accept fire before the duplicate; fixed with `vm.assume(w0+w1<=thr)`). FV files: `RelaySigFV.t.sol` (fixed), `RelaySigParamFV.t.sol` (parametric), `halmos.toml` (loop=6), `docs/relay-fv.md` (modeling contract + caveats). Committed `290acbed`, pushed to origin/relay-fix-3 (MR !135).

**P3–P8 DONE + AUDITED (2026-06-15).** Designed in parallel via workflow wf_ff84217f-556 (5 agents, one per obligation), verified centrally. 5 new harnesses, ALL GREEN: `RelayCanonicalityFV` (P3, 2+1cex), `RelayReturnDiscriminatorFV` (P6, 3+2cex), `RelayFeeConservationFV` (P7, 1+1cex), `RelayIsSecureNormFV` (P5, 4+3cex), `RelayPolicyHashFV` (P8, 3+1cex). Adversarial audit wf_7967c76d-067 → **valid-with-caveats, no false PASS**; 2 P5 mustFix applied: (1) leaf-normalization upgraded from by-construction to MACHINE-CHECKED via an independent decoupled leaf bit (`check_leafNorm_machineChecked`: accept ⟹ (b!=0)==lb, catches a b&1 divergence) + b>1 reachability; (2) docs P5 sink list corrected (proven sinks = leaf/stored-map-bit/live-flag; emitted-event field shares the same isSecure local, noted not separately asserted). `docs/relay-fv.md` updated (P3-P8 ✅, §7 audit). FULL FV SUITE: 7 contracts, 16 PASS + 9 reachability counterexamples, loop=6. Deleted diagnostic probes' STALE artifacts in artifacts-forge (sources long gone). **P4 DONE (2026-06-16) — PHASE 1 COMPLETE (P1–P8 ✅).** `RelayRandomBindingFV` (random-proof VALUE binding, decoupled-oracle/machine-checked like P5): `check_p4_uncommittedValue_cannotStore` PASS (no forgery — value≠committed can't store), `check_p4_storedEqualsCommitted` PASS (accept⟹stored==committed), `check_p4_reachability` cex. Committed (pending push). All 8 Phase-1 obligations proved bounded with reachability controls; signature/threshold (P1/P2) + random binding (P4/P5) have machine-checked decoupled forms; two audit rounds = no false PASS. CI ANTI-VACUITY GATE DONE (2026-06-16, commit 42e4d2dc): `test-forge/fv/verify_fv.py` + GitLab job `test-fv-halmos` (.gitlab-ci.yml, foundry:stable + pip halmos, rules-scoped to Relay/fv/halmos.toml changes). Enforces: all proof checks PASS + all reachability controls produce CEX; an unexpected reachability PASS = hard "vacuity alarm". Validated locally: loop=6 -> exit 0 (33 checks: 22 proofs + 11 reachability live); --loop 2 -> exit 1, 7 vacuity alarms. **CI job GREEN in the real pipeline (commit f79ada7f, test-fv-halmos success 3m16s, pipeline success).** Took 4 CI-env fix commits: the runner's foundry:stable image is non-root with no python/curl, so switched to image python:3.12 + `pip install --user halmos` + foundryup (root-agnostic, write under $HOME), and added `needs: build-smart-contracts` + the cache-nodejs cache so forge build resolves node_modules remappings (@gnosis.pm). Commits: 506176a8/c6d9782a/f79ada7f (+ earlier 42e4d2dc added the gate). REMAINING (was) = Phase-2/Kontrol: unbounded K via loop invariant, cross-epoch no-double-count, random monotonicity across relay() sequences, deeper Merkle/NV≤300, M_0..M_8 non-collision lemmas.

## 16. PHASE 2 STARTED (2026-06-16). See docs/relay-fv.md §9.
**Bounded Phase-2 done in Halmos** (2 new harnesses, both green + reachability-gated): `RelayCrossEpochFV` (cross-epoch no-double-count + threshold soundness on the x1.2 threshold-increase path; closes §6 caveat 2 for the bounded shape) and `RelayRandomMonotonicityFV` (2-call multi-tx random monotonicity: stale relay doesn't regress live pointer / advances / both historical retained). Full FV suite now 10 contracts, 40 checks (27 proofs + 13 reachability cex), CI gate green.
**Kontrol BLOCKED by an UPSTREAM packaging bug (updated 2026-06-16, after Docker became available).** Docker came up (Docker Desktop, aarch64 VM, 4GB); confirmed the RV binary cache WORKS in a root nixos/nix container via `--accept-flake-config` (downloads, 0 source builds). BUT every install path fails at nix EVALUATION with: `callPackageWith: Function called without required argument "solc_0_8_13" ... did you mean solc_0_8_33/31/32` — kontrol's solc input references solc_0_8_13, removed from current nixpkgs. Reproduced via `nix run github:runtimeverification/kontrol` at HEAD + pinned v1.0.248 + v1.0.241, AND via `kup install kontrol` (root, in-container). It is NOT our env — a clean `kup install kontrol` today hits this. REMAINING unbounded obligations (need Kontrol): unbounded-K threshold/no-double-count via loop invariant; arbitrary-length monotonicity; M_0..M_8 non-collision KEVM lemma. PATHS (docs/relay-fv.md §9): (1) a Kontrol pin predating the nixpkgs solc removal / `--override-input` an old nixpkgs / RV's kontrol GitHub Action / wait for upstream fix; (2) Certora Prover (peer tool, no nix dep). kup installed on host (~/.nix-profile/bin/kup, non-trusted-user so host install also can't add cache). Docker image runtimeverification/kontrol does NOT exist publicly (Docker Hub + GHCR checked). UNCOMMITTED: RelayCrossEpochFV.t.sol, RelayRandomMonotonicityFV.t.sol, docs/relay-fv.md edits. FV files now: RelaySigFV, RelaySigParamFV, RelayCanonicalityFV, RelayReturnDiscriminatorFV, RelayFeeConservationFV, RelayIsSecureNormFV, RelayPolicyHashFV, RelayRandomBindingFV (8 contracts) + halmos.toml + docs/relay-fv.md.

## 17. kontrol-fv SKILL + Kontrol provisioning (2026-06-16)
**SKILL DONE & PUSHED** (`dc2d360f`): `flare-smart-contracts-v2/.claude/skills/kontrol-fv/SKILL.md`. Reusable Claude Code skill encoding the whole FV methodology — modeling contract A1–A5, Halmos harness patterns (single-path setUp, THE loop-bound trap, mandatory anti-vacuity `reach*` controls, exact relay() calldata layout, struct-bundling, ecrecover-independence reuse), the DECOUPLED-ORACLE technique (P4/P5), tight per-prefix threshold form, the verify_fv.py CI gate, Kontrol provisioning recipe + the upstream solc bug, and the AI invariant-discovery loop (propose→Kontrol-check→refine; PropertyGPT/FLAMES/Dafny-assertion style). Also committed the 2 Phase-2 harnesses earlier (68f965f3).

**Kontrol provisioning — deeper diagnosis (2026-06-16).** Pinpointed the upstream bug precisely via `nix flake metadata`: solc comes from the `foundry` input = shazow/foundry.nix; kontrol's `nix/kontrol/default.nix:25` does `callPackageWith` requiring `solc_0_8_13`, but the resolved foundry.nix overlay now offers only `solc_0_8_31/32/33` (dropped 0_8_13). **CONFIRMED `--override-input nixpkgs github:nixos/nixpkgs/69493a13...` (RV's own pin, which HAS solc_0_8_13) has ZERO effect** — same error — because the solc lookup is in the foundry overlay scope, not the nixpkgs input. So flag-level fixes (override-input) do NOT work. Remaining clean path = the README FROM-SOURCE build (`kup install k.openssl.secp256k1 --version v$(cat deps/k_release)` + `uv run kdist build "kontrol.*"`) which bypasses the broken `nix/kontrol/default.nix`.
**Source-build attempt → blocked by RAM.** Script `/tmp/kontrol_build.sh` (6 phases) in a detached `nixos/nix` container `kontrol-build`. Phase-1 fix: `nix profile install --priority 4 nixpkgs#git nixpkgs#uv` (the base image already provides `which` → file-collision; dropped it). Phases 1–2 OK (tooling + clone v1.0.248). **Phase 3 (`kup install k…`) OOM-KILLED (exit 247) at Docker's 3.8 GB default** — even the K install needs more, before the heavy kdist kompile. HOST HAS 64 GB; Docker VM was only 3.827 GiB (no memoryMiB override in settings). Could NOT edit Docker Desktop settings programmatically — `~/Library/Group Containers/group.com.docker/settings{,-store}.json` is macOS-TCC-protected (PermissionError; this shell lacks Full Disk Access). USER CHOSE to bump Docker RAM to 16 GB via GUI (Settings→Resources→Memory→16GB→Apply&Restart) and have me retry. A background watcher (poll `docker info` Total Memory; auto-relaunch `kontrol-build` when ≥8 GiB) is running. RESUME: once Docker is at 16 GB, the build runs `/tmp/kontrol_build.sh`; phase 5 (KEVM kdist kompile) is the heavy step to watch. If it succeeds → `docker commit kontrol-build kontrol-local` for a reusable image; bake the working invocation into docs/relay-fv.md §9 + the skill §6.

## 18. ✅ KONTROL INFRASTRUCTURE ESTABLISHED (2026-06-17) — image `kontrol-local:1.0.248`
**Kontrol 1.0.248 BUILT & VERIFIED** in Docker. Reusable image `kontrol-local:1.0.248` (17.5 GB) committed; a FRESH container off it reports `Kontrol version: 1.0.248`, kompile present, kdist dir `/root/.cache/kdist-f0c2234` populated (evm-semantics.plugin 56M, kontrol.base 148M, kontrol.aux 318M, kontrol.keccak 315M, kontrol.full 323M), java 17.0.20. Foundry/forge being added → re-commit.

THE WORKING RECIPE (every blocker + fix; the flake/`kup install kontrol` path is upstream-broken via solc_0_8_13 and was BYPASSED with a from-source build):
1. **Run x86_64, NOT aarch64.** RV's binary cache has NO aarch64-linux Haskell backend (kore) → would source-build kore and fail on `time-compat` test suite. On Apple Silicon use `docker run --platform linux/amd64` (Rosetta). x86_64 cache is fully populated (kore/llvm-backend fetched, not built).
2. **Docker VM ≥ 16 GB** (default 3.8 GB OOMs even the K install). GUI: Settings→Resources→Memory. (Host has 64 GB; settings file is macOS-TCC-protected, can't edit from shell.)
3. **RV cachix caches, correct mode:** `nix profile install nixpkgs#cachix` then `cachix use k-framework-binary -m root-nixconf` + `cachix use k-framework -m root-nixconf` (mode is `root-nixconf`/`user-nixconf`/`nixos`, NOT `nixconf`). The `-binary` cache holds the prebuilt Haskell backend — without it 120 derivations (incl time-compat, kore) source-build. Keys it writes: k-framework-binary.cachix.org-1:pJedQ8iG19BW3v/DMMmiRVtwRBGO3fyMv2Ws0OpBADs= and k-framework.cachix.org-1:jeyMXB2h28gpNRjuVkehg+zLj62ma1RnyyopA/20yFE=.
4. **nix.conf:** `experimental-features = nix-command flakes`, `accept-flake-config = true`, `filter-syscalls = false`, `sandbox = false` (last two fix QEMU/Rosetta `seccomp BPF Invalid argument`).
5. **`ulimit -s 1048576`** before any nix call (emulated Nix evaluator stack-overflows on the kore pkg set otherwise).
6. **K install:** `nix profile install github:runtimeverification/kup --accept-flake-config` then `kup install k.openssl.secp256k1 --version v$(cat deps/k_release)` (=v7.1.334). kore/llvm-backend/clang fetched from cache (~7 min).
7. **uv MUST use a nix python, not its own download:** `nix profile install nixpkgs#python311`; `export UV_PYTHON_DOWNLOADS=never`; `uv sync --python "$(command -v python3.11)"`. (uv's standalone CPython is a generic-FHS binary → `rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2` on NixOS.)
8. **kdist build needs JDK17 + a full C/C++ toolchain for the plugin** (`uv run kdist build kontrol.*`): `nix profile install nixpkgs#jdk17`; `export JAVA_HOME=$(dirname $(dirname $(readlink -f $(command -v java))))`. Toolchain (install ONE AT A TIME — `nix profile install` is transactional, one collision aborts the batch; do NOT add `which`/`gcc` (gcc collides clang on cc/c++ → use clang only)): `gnumake cmake pkg-config clang binutils flex bison git perl gnused gawk gnugrep findutils diffutils coreutils openssl openssl.dev gmp gmp.dev mpfr mpfr.dev boost boost.dev secp256k1 secp256k1.dev cryptopp procps autoconf automake libtool`. Env: `CPATH/C_INCLUDE_PATH/CPLUS_INCLUDE_PATH=$HOME/.nix-profile/include`, `LIBRARY_PATH/LD_LIBRARY_PATH=$HOME/.nix-profile/lib`, `PKG_CONFIG_PATH=$HOME/.nix-profile/lib/pkgconfig`, `CMAKE_PREFIX_PATH=$HOME/.nix-profile`, and **`CMAKE_POLICY_VERSION_MINIMUM=3.5`** (nixpkgs CMake is v4, rejects libff's old cmake_minimum_required). Plugin compiles vendored libff/cryptopp/blst/c-kzg: blst hardcodes `clang++` (need clang) + uses `sed`/`perl` (NixOS minimal lacks them).
9. **Emulated kompile is BRUTALLY slow** (~3–4 h PER target; full kontrol.* ≈ 16 h wall-clock on this box). The kdist wrapper `ProcessPoolExecutor` may DEADLOCK at the end AFTER all targets finish `status=0` — harmless: artifacts are built, `uv run kontrol version` works; just commit the container.
Build scripts saved: `/tmp/kontrol_build.sh` (phases 1-5 from scratch), `/tmp/kontrol_phase5.sh` (toolchain+kdist on top of `kontrol-stage:base`). Intermediate image `kontrol-stage:base` (14 GB, K+venv, pre-kdist) also kept for fast iteration.
RUN KONTROL: `docker run --platform linux/amd64 -v <repo>:/work kontrol-local:1.0.248 sh -lc 'export PATH=$HOME/.nix-profile/bin:$PATH; cd /work && kontrol build ...'`.
NEXT (Phase 2 unbounded proofs): add forge (done/in-progress), mount the repo, adapt a Halmos harness to a kontrol `prove_*` test, `kontrol build` then `kontrol prove` — but each prove is very slow under emulation; consider this a decision point with the user re: scope/time.

### 18b. END-TO-END VALIDATED (2026-06-17) — first real Kontrol proof PASSED + timings
Image `kontrol-local:ready` (18.5 GB) is COMPLETE and PROVING. forge added (forge 1.7.1-dev). Two more fixes were needed after the first commit:
- **forge's svm solc fails on NixOS/Rosetta** (`Broken pipe`/generic-FHS ELF) → use a **nix solc** (`nix profile install nixpkgs#solc` = 0.8.33) and point foundry.toml `solc = '<path>'` (pragma ^0.8.13 compiles fine on 0.8.33).
- **THE `kontrol build` BLOCKER = a stale `SoftFileLock`.** kdist's end-of-run multiprocessing deadlock had left `kontrol.base` unfinished AND its soft-lock file `…/kdist-*/kontrol/base.lock` on disk, which got committed into the image. pyk `_kdist._lock` uses `filelock.SoftFileLock` (acquire = create file, NOT released on process death) → every later build polled it forever (`hrtimer_nanosleep`). FIX: `find <kdist> -name '*.lock' -delete` + rebuild `kontrol.base` (`uv run kdist build kontrol.base --force`). Also patched `_kdist.py` build() to a SERIAL in-process loop (replace `ProcessPoolExecutor(...spawn...)`) as insurance — the multiprocessing pool itself deadlocks under Rosetta (workers block on futex/nanosleep; spawn AND fork). kontrol.base rebuilt in ~5 min once unlocked; all 4 kontrol.* targets now have mainModule.txt, no locks; serial patch baked into the image.
- **VALIDATED PROVE** (self-contained harness `/tmp/ktest`, a 2-signature Relay threshold-accounting model = our P2, run via `docker run --platform linux/amd64 -v /tmp/ktest:/work kontrol-local:ready sh /work/run.sh`): `prove_threshold_twoVoters_cannotAccept` → **PROOF PASSED**; paired anti-vacuity control `prove_reachability_canAccept` → **FAILED/counterexample** (acceptance reachable when w0>thr) ⇒ non-vacuous. **TIMINGS: forge=0s, kontrol build=146s, kontrol prove=148s (both fns), total ~5 min.** So the multi-hour cost was the ONE-TIME KEVM kompile (baked in); per-proof cost is ~minutes, NOT "overnight". The earlier "16h" was ~7h active build + ~8h post-build deadlock/sleep; Docker uses Rosetta 2 (fast), not slow QEMU-TCG. Run scripts: `/tmp/ktest/{foundry.toml,test/RelayThresholdProof.t.sol,run.sh}` (run.sh installs nix solc + writes foundry.toml + times the 3 phases). Skill §6 + this section hold the full recipe.

### 18c. ✅ PHASE-2 UNBOUNDED SIGNATURE-LOOP PROOF — MACHINE-CHECKED IN KONTROL (2026-06-17)
The unbounded-in-K signature-loop weight invariant is PROVEN. Harness saved in repo at
`test-forge/fv/kontrol/{RelaySigLoopFV.t.sol,run.sh,foundry.toml}` (uncommitted). Designed via a 7-agent
Workflow (3 formulations → synthesize → 3 adversarial reviewers); the reviewers REJECTED the first synthesis
(decoupled-ghost = smuggled conclusion; lemmas were x==x tautologies; k-induction not mechanized) — caught
before it could masquerade as a proof. CORRECTED harness: k-induction (base + single fully-symbolic
preservation step) over a GROUNDED prefix-sum invariant INV(weight,nextUnusedIndex):=weight<=psAt(nui) &&
nui<=N, where psAt is COMPUTED from the symbolic per-voter weights via conditional scalar logic (no array).
**VERDICTS (kontrol-local:ready, N=3, single core): 5 PROVE PASSED + 2 anti-vacuity controls FAILED=CEX**
— prove_base_invariant PASS, prove_step_preserves_invariant PASS (the inductive step), prove_lemma_prefix_monotone
PASS, prove_accept_implies_threshold_exceeded PASS, prove_insufficientWeight_cannotAccept PASS;
prove_reach_stepNeedsGuard CEX (G2/no-double-count guard is load-bearing), prove_reach_acceptIsPossible CEX
(accept path live). Non-vacuous, genuine. TIMING: forge 1s, kontrol build 494s, kontrol prove 2425s (~40min)
single core. **Kontrol-execution gotchas solved en route (all now in run.sh + the recipe):** (a) Kontrol 1.0.248
CANNOT symbolically encode fixed-size ARRAY params (`uint256[5]`) → pass weights as scalars; (b) host-mounted
build dir persists → must `rm -rf out kout .kontrol` before rebuild or kontrol reuses stale kompile; (c) `kontrol
build`'s LLVM-backend parallel compile DEADLOCKS under Rosetta (workers on pipe_read) → run `--cpuset-cpus="0"`
(single core) for the build; (d) default `--fail-fast` aborts the run when the reach controls fail-by-design →
use `--no-fail-fast`; (e) symbolic-INDEX reads into a memory array blow up state space (49min+, mem-growing) →
compute psAt via conditional scalars instead; (f) SMT init `Unknown "timeout"` under slow emulated Z3 → raise
`--smt-timeout 120000` (+ `--smt-retry-limit`, `--force-sequential`); (g) Solidity-0.8 overflow checks on weight
sums create spurious overflow-branch FAILURES, and an `_bound()` assume-helper perturbed the init SMT into a
multi-hour stuck-at-init → fix by typing weights as **uint16** (type-enforced 16-bit bound = Relay's WEIGHT_MASK
semantics; no assumes, no overflow branch, clean init). HONEST CAVEATS (in the harness header): N (voter count)
concrete (model bound; K genuinely unbounded — the step's symbolic pre-state ranges over all INV-states);
base+step compose to ∀K by the meta-level induction PRINCIPLE (Kontrol 1.0.248 has no native loop-invariant, so
the composition itself isn't machine-checked); proves a faithful Solidity MODEL of the loop body (bytecode side
at K<=3 covered by Halmos RelaySigParamFV; a bmc-depth-1 model/bytecode equivalence would fully bridge it).

## 19. PHASE 3 robustness verification — IN PROGRESS (2026-06-19). See docs/relay-phase3-plan.md
Concrete 7-step plan authored via a 5-analyst workflow grounded in reading Relay.sol (docs/relay-phase3-plan.md).
Steps: (1) regression net, (2) assembly review, (3) T1 bytecode<->model Kontrol bridge, (4) state-machine,
(5) Merkle soundness, (6) integration/reentrancy/DoS, (7) unbounded Kontrol generalizations.

**VERIFIED THIS PHASE (all Halmos unless noted; each with a paired anti-vacuity reach control; pushed to relay-fix-3):**
- R5 cross-epoch threshold-scaling never weakens the gate — RelayThresholdScalingFV (needs --solver-timeout-assertion 0).
- L1 setSigningPolicy strict +1 epoch advance — RelayEpochAdvanceFV.
- AC-1 setSigningPolicy access control (only setter) — RelayAccessControlFV.
- AC-11 + L4 + RLY-11 constructor config validation — RelayConstructorFV.
- AC-10 / RLY-02 governance nonce replay protection (MULTI-TX, symbolic nonce) — RelayGovernanceNonceFV.
- L8 cross-epoch "Must use new sign policy" gate (MULTI-STEP: setSigningPolicy-advance + cross-epoch relay) — RelayMustUseNewPolicyFV.
- L3 message finalization window "too old" (MULTI-STEP: 6-epoch advance) — RelayFinalizationWindowFV.
- M2 + M3/M8 Merkle proof-path soundness (proof-element forgery + alignment) — RelayMerkleProofFV.
- "Delayed sign policy" gate — RelayDelayedPolicyFV.
- "Wrong sign policy reward epoch" gate — RelayWrongEpochFV.
- AC-9 / RLY-21 verify() fee conservation — RelayVerifyFeeFV.
=> **The ENTIRE relay() epoch decision matrix (Relay.sol:743-754) is formally verified**: wrong-epoch /
delayed / too-old / threshold-increase / must-use-new-policy. Plus Phase 1-2 (P1-P8 + unbounded sig-loop + random monotonicity).

**MULTI-STEP HARNESS TECHNIQUE (reusable):** setter-mode deploy, then advance lastInitializedRewardEpoch via
repeated setSigningPolicy calls in setUp (concrete, single-path), then relay(); the reach control's CEX confirms
the elaborate setup genuinely reaches acceptance (non-vacuous). For multi-tx (AC-10) use try/catch over a
2-call sequence with `if (ok1) assert(!ok2)`.

**DOCUMENT-CLASS items closed** (docs/relay-phase3-documented-items.md, per the plan's own tool assignment):
AC-3 (no-write-on-revert = EVM revert-atomicity + gate proofs), R1/R2 (reentrancy: verify() has no sstore RLY-21;
nonce write post-verify), M4 (OZ MerkleProof call-site in scope, internals assumed), R6/R7 (far-future arithmetic
386yr/47yr accepted out-of-scope). Step-2 assembly review: docs/relay-assembly-review.md (3 mutating entries, no
delegatecall/fallback, M_5 dual-use flagged, totalWeight<2^16 confirms the uint16 model).

**REMAINING (genuinely hard, scoped in docs):**
- AC-6 Mode-1 (relay-only) new-policy threshold consistency — needs a protocolId==0 relay message with embedded
  policy (intricate; no template). DEFERRED to avoid a vacuous harness.
- T1 bytecode<->model bmc-depth-1 Kontrol bridge (Step 3) — authoring-heavy linchpin.
- Step 7 symbolic-N: unbounded sig-loop verified at N=3 and N=5 (Kontrol); N=10 (PACKED-weights encoding to
  dodge stack-too-deep + Kontrol array limits) RUNNING in background (/tmp/ksig10, kontrol-local:ready,
  single-core). Full symbolic-N risks state explosion; documented fallback = parametric N in {2,3,5,10,300}.
HALMOS harnesses now: the Phase-1/2 set + RelayThresholdScalingFV, RelayEpochAdvanceFV, RelayAccessControlFV,
RelayConstructorFV, RelayGovernanceNonceFV, RelayMustUseNewPolicyFV, RelayFinalizationWindowFV, RelayMerkleProofFV,
RelayDelayedPolicyFV, RelayWrongEpochFV, RelayVerifyFeeFV. Latest pushed HEAD: b7aa0f5a (relay-fix-3).
