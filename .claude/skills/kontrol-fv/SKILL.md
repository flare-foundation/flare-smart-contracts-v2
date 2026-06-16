---
name: kontrol-fv
description: >-
  Formal verification of EVM smart contracts (esp. Flare Relay.sol) with Halmos (bounded) and Kontrol
  (unbounded/inductive). Use when asked to write, run, debug, or extend FV proofs / symbolic tests /
  loop invariants for Solidity or inline-assembly contracts, set up the Halmos or Kontrol toolchain,
  generate invariants with AI, or guard proofs against vacuity. Encodes the modeling contract, harness
  patterns, the decoupled-oracle and anti-vacuity techniques, the loop-bound trap, and provisioning recipes.
---

# Formal Verification of EVM contracts with Halmos + Kontrol (AI-driven)

This skill packages a working methodology for FV of EVM contracts — proven on Flare `Relay.sol`
(~930 lines of inline assembly). Two tools, by capability:

- **Halmos** (a16z) — fast *bounded* symbolic execution on Foundry tests. Loops unrolled to a fixed
  count. Use for the bulk: per-shape ∀-proofs (fixed signer count K, fixed Merkle depth). Pip-installable.
- **Kontrol** (Runtime Verification / KEVM) — *unbounded/inductive* via loop invariants + multi-tx
  induction over a validated EVM semantics. Use only for what Halmos structurally can't reach.

Order of work: **Halmos first** (broad, cheap, bounded), **Kontrol only for the unbounded frontier**.

## 1. The modeling contract — state it before any proof

Separate **cryptography (assumed)** from **accounting (proved)**. A "PASS" is meaningful only relative to:

- **A1 keccak256 = injective uninterpreted function** (sound given collision-resistance).
- **A2 ecrecover = uninterpreted function** `E(hash,v,r,s)→address`. The solver may set `E(...) = voters[i]`
  freely — this gives the adversary *more* power, so accounting invariants that survive hold a fortiori
  under real ECDSA. **A2′ (out of scope):** ECDSA unforgeability — proves "only voters' sigs count"; we
  state it, don't prove it. So: machine-check the *on-chain accounting*; *assume* the crypto.
- **A3 bounded loops** — Halmos unrolls to K; results are ∀-over-inputs *at each fixed shape K*, not all K.
- **A4 distinct voters (= the trusted-setter / RLY-06 premise)** — strict index-increase proves no *index*
  double-counted; "no *signer* double-counted" additionally needs `vm.assume(distinct(voters))`.
- **A5 solver/precompile defaults** — gas ignored; `staticcall(0x01)` intercepted as `E`; symbolic calldata.

Write these into a `docs/*-fv.md` modeling-contract doc so every PASS has a precise meaning.

## 2. Halmos harness patterns (hard-won — violating these silently breaks proofs)

1. **setUp must be single-path.** The usual unit-test base uses `vm.addr`/`vm.sign`/sorting → Halmos
   "Multiple paths were found in setUp" and aborts. Either `function setUp() public override {}` and deploy
   *inside* each `check_` (required when policy/weights/threshold are symbolic), or use a fully-CONCRETE
   setUp with fixed addresses (no `vm.addr`). Voters need no real keypairs — ecrecover is uninterpreted.
2. **THE LOOP-BOUND TRAP.** `halmos.toml` `loop = N` (default **2**) unrolls every loop N times. A signature
   loop runs once per signature, so at the default any test with 3+ signatures has its accepting iteration
   **truncated → the proof passes VACUOUSLY**. Set `loop ≥ max iterations on the path` (signer count,
   Merkle depth). This bit us hard: 3-sig proofs looked sound at loop=2 but were vacuous.
3. **ANTI-VACUITY CONTROL — mandatory.** Every negative property (`assert(!accept)` / `assert(revert)`)
   MUST be paired with a reachability control at the SAME config that `assert(!ok)` and is **expected to
   produce a COUNTEREXAMPLE** (proving the accept path is live). If a reachability control ever PASSES, the
   guarded proofs are vacuous — treat it as a hard failure. Name controls with `reach` in the function name.
4. **Stack-too-deep.** Bundle signatures in `struct Sig { uint8 v; bytes32 r; bytes32 s; }`; keep `check_`
   params ≲ 10; push work into helpers.
5. **Reuse ecrecover independence.** The same `(v,r,s)` triple can match different messages' signers because
   `E(h1,..)` and `E(h2,..)` are independent — lets one Sig serve multiple relays (keeps stack low).
6. **Calldata layout (Relay.relay):** `abi.encodePacked(selector, signingPolicy, message(38B), sigs[, trailer])`.
   sigs = `uint16(count)` then per-sig `(uint8 v, bytes32 r, bytes32 s, uint16 index)` (67B). Policy prefix =
   `uint16 numVoters + uint24 rewardEpochId + uint32 startVotingRoundId + uint16 threshold + bytes32 seed`
   (43B), then per voter `address(20) + uint16 weight`. Random trailer = `randomNumber(32) + proof nodes`.

## 3. The DECOUPLED-ORACLE technique (for binding / no-forgery properties)

To machine-check that an on-chain value equals a committed value (not just argue it "by construction"),
build the signed commitment from an **independent symbolic oracle** decoupled from the input the contract
reads, then assert `accept ⟹ contractValue == oracle`. Example (P4 value binding / P5 isSecure): build the
Merkle root from `leaf(vrid, committedValue, lb)` with `lb` an independent bit; the contract recomputes its
leaf from *its* rule and reverts unless it reproduces the root, so `accept ⟹ (b!=0) == lb` *proves* the
contract's rule is exactly `(b!=0)` — catching a divergent rule (e.g. `b & 1`). A by-construction harness
that uses the same rule on both sides is circular and would pass vacuously. **Always decouple the oracle.**

## 4. Threshold-soundness in TIGHT (per-prefix) form

The accept gate fires on the *first prefix* whose running weight exceeds threshold. So `accept ⟹ total > thr`
is a loose over-approximation (misses premature-accept bugs). Prove the tight form: for K = 1,2,3 provide K
sigs, `vm.assume(Σ provided weights ≤ thr)`, prove cannot-accept. For the threshold-INCREASE path (cross-epoch,
`messageRewardEpochId > policy epoch`), the effective threshold is `thr * thresholdIncreaseBIPS / 10000`.

## 5. Running Halmos + the CI gate

- Build dir: this repo uses `out = artifacts-forge`, so Halmos needs `--forge-build-out artifacts-forge`
  (persisted in `halmos.toml`, alongside `loop = 6`).
- `HALMOS=halmos halmos --contract <C> --function check_`. Halmos exits non-zero whenever ANY check has a
  counterexample (the reachability controls do, by design) — so **judge from JSON, not the exit code.**
- `test-forge/fv/verify_fv.py` is the CI gate: runs the suite, requires every proof to PASS and every
  `reach*` control to produce a counterexample; an unexpected reachability PASS = hard "vacuity alarm".
  CI job `test-fv-halmos` (python:3.12 image + `pip install --user halmos` + foundryup + node_modules cache).

## 6. Kontrol (unbounded / inductive)

Use for: unbounded-K loop invariants; arbitrary-length multi-tx invariants; memory-slot (`M_0..M_8`)
non-collision lemmas. Properties are Foundry `prove_*` tests + (for unbounded loops) a **loop invariant**.

**Provisioning (the part that breaks):** Kontrol installs via Nix (`kup install kontrol`). On a host where
the user is NOT a trusted Nix user (`nix show-config | grep trusted-users`), the RV binary cache can't be
added → use a **root Docker container** (`nixos/nix`) where `--accept-flake-config` lets Nix use the RV
cache (downloads, no source build). KNOWN UPSTREAM BUG (2026): recent releases fail nix eval with
`callPackageWith: ... required argument "solc_0_8_13"` because nixpkgs removed that solc (security bug,
nixpkgs#182498) while Kontrol still references it. Work-arounds, cheapest first: (a) `--override-input` the
solc/nixpkgs input to a commit that still has `solc_0_8_13`; (b) a Kontrol release predating the removal;
(c) the README "build from source" path (`kup install k... --version $(cat deps/k_release)` + `uv run kdist
build "kontrol.*"`) which bypasses the broken nix `kontrol/default.nix`; (d) RV's `kontrol` GitHub Action
(pins a tested toolchain); (e) wait for upstream fix; or use **Certora** for the same unbounded obligations.
Bake the working setup into a reusable `kontrol-local` Docker image. See `docs/relay-fv.md §9`.

**Run:** `kontrol build` (kompiles the project to KEVM — heavy, slow, memory-hungry) then
`kontrol prove --match-test '<Contract>.<test>'`. Reuse the Halmos `test-forge/fv` harnesses (or use
**Chimera** for write-once harnesses across Halmos+Kontrol+Echidna+Medusa).

## 7. AI-driven invariant discovery (the efficiency lever)

The hard, expert part of an unbounded proof is *finding the loop invariant*. Drive it with AI:

1. **Propose** a candidate invariant (RAG-seed from known quorum/threshold invariants — cf. PropertyGPT's
   retrieval-augmented property generation; FLAMES for synthesis). For the signature loop, the invariant is
   roughly: *after iteration k, `weight = Σ_{matched j} weights[index_j]` over strictly-increasing in-range
   indices, hence `weight ≤ Σ distinct registered weights`; and `nextUnusedIndex` strictly increasing.*
2. **Check** with Kontrol (`kontrol prove`).
3. **Refine** from the failed goal / counterexample — propose helper lemmas/simplification rules (cf.
   LLM-inferred Dafny helper assertions). Repeat.

AI accelerates the *human* side (spec, invariant, lemma, counterexample triage, vacuity tooling, provisioning
diagnosis). The trust still rests on Kontrol+Z3 machine-checking — never accept an AI-asserted invariant as
proven; only a tool-checked result counts.

## 8. Reference resources

- Skills/MCP: `awesome-solidity-skills`, Foundry MCP, Slither MCP, a Z3/SMT MCP; MCP "Build with Agent Skills".
- Methodology: PropertyGPT (NDSS 2024, RAG invariant generation), FLAMES (invariant synthesis), LLM Dafny
  helper-assertion inference. Chimera (Recon-Fuzz) for multi-tool harnesses.
- This engagement's records: `docs/relay-fv.md` (modeling contract §1–3, obligations §4, caveats §6, audit
  §7, Phase-2/Kontrol §9), `test-forge/fv/*` (8+ harnesses), `halmos.toml`, `verify_fv.py`.
