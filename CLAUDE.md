# Flare Smart Contracts V2

Solidity smart contracts implementing the Top Level Protocol on Flare Network. Dual test framework: Hardhat (TypeScript) and Foundry (Forge/Solidity).

## Security

- Never read `.env` files or any file that may contain secrets, private keys, or credentials
- Never commit `.env` files, private keys, or secrets to git
- Never read or write any file outside the project folder or the open VSCode workspace
- Never expose secret values in logs, comments, or output

## Quick Reference

```bash
# Install dependencies
pnpm install

# Compile contracts (Hardhat + typechain)
pnpm compile

# Forge build
forge build

# Run Hardhat unit tests
pnpm test_unit_hh

# Run Hardhat integration tests
pnpm test_integration_hh

# Run all Forge tests
forge test

# Run specific Forge test file
forge test --match-contract TeeVerificationTest

# Run specific Forge test
forge test --match-test testConfirmAvailability -vvv

# Lint Solidity (contracts + tests + deployment)
pnpm lint-sol

# Lint TypeScript
pnpm lint:check

# Check formatting
pnpm format:check

# Coverage (Forge)
pnpm coverage-forge
```

## Pre-commit Checklist

After making changes, run these before committing:

```bash
forge build                # Solidity compilation
pnpm lint-sol              # Solidity linting (0 errors)
pnpm lint:check            # TypeScript linting (0 errors)
pnpm format:check          # Prettier formatting
pnpm coverage-forge        # Coverage (runs all Forge tests)
```

In a Claude Code session, invoke the [`check-all`](./.claude/skills/check-all/SKILL.md) skill (or say "run the pre-commit checks") to run the full checklist plus the Hardhat integration tests and a simulation smoke test in one pass, with a compact status block at the end.

Also: **update [`docs/specs/`](./docs/specs/) to reflect any code changes you made** — see the [Documentation](#documentation) section below.

## Documentation

Protocol docs live under [`docs/specs/`](./docs/specs/), organized by sub-protocol (FSP, FTSO, FDC, FCC) plus the cross-cutting modules (governance, staking, RNat, inflation). Docs are written **code-first**: every claim should be traceable to a `.sol` file on the current branch, and citations use markdown links of the form `[ContractName](../../../contracts/.../X.sol)`.

**Whenever code changes, update the matching docs in the same PR.** Specifically:

- **Add / remove a contract, facet, library, or public method** → update the relevant module doc(s) and [`docs/specs/ApiReference.md`](./docs/specs/ApiReference.md) if a public `I*` interface is added, removed, or has its surface changed.
- **Change behavior** (method semantics, events emitted, modifiers, state transitions, validation rules, fee math, access control) → update the prose that describes it. Re-read the affected doc end-to-end after the code change to make sure the surrounding context still holds.
- **Rename** a contract, function, or field → update every prose citation. Code-symbol citations in docs must match the actual code verbatim (including British spellings like `normalisedWeights` when the field is named that way).
- **Update** event signatures, error names, or struct shapes → propagate to any doc that quotes the shape.

Trivial changes (whitespace, comment-only edits, test-only edits, pure refactors that preserve behavior, NatSpec updates, formatting) don't require doc updates. The goal is that `docs/specs/` always reflects current contract behavior on this branch.

If the doc change is non-trivial, consider committing it as a separate `docs:` commit alongside the code commit rather than bundling everything into one large diff.

## Project Structure

```
contracts/              # Solidity source (Hardhat src)
├── protocol/           # Core protocol (Relay, Submission, FlareSystemsManager)
├── tee/                # TEE (Trusted Execution Environment) contracts
├── fdc/                # Flare Data Connector v1
├── fdc2/               # Flare Data Connector v2
├── ftso/               # FTSO (Flare Time Series Oracle)
├── fastUpdates/        # Fast updates contracts
├── adapters/           # Chainlink adapters
├── governance/         # Governance contracts
├── userInterfaces/     # Public interfaces (IRelay, ITee*, IFdc2*, etc.)
├── mock/               # Mock contracts for testing
└── utils/              # Shared utilities (AddressUpdatable, etc.)
test/                   # Hardhat tests (TypeScript, Mocha/Chai)
├── unit/
├── integration/
└── utils/
test-forge/             # Forge tests (Solidity)
├── unit/               # Mirrors contracts/ structure
├── integration/
├── mock/
└── utils/
deployment/             # Deploy scripts, chain configs, tasks
├── chain-config/       # Per-network parameters (coston2.json, flare.json, etc.)
├── scripts/            # Deploy/redeploy scripts
├── tasks/              # Hardhat tasks (simulation, registration, etc.)
└── utils/              # Deploy utilities, epoch settings
scripts/                # Utility scripts, protocol libs
├── libs/protocol/      # TS encoding/decoding (RelayMessage, SigningPolicy, etc.)
└── libs/mock/          # Mock finalizer, signer emulators
```

## Build & Test

- **Solidity version**: 0.8.27+; the TEE / diamond / governance namespaced-storage contracts require **0.8.35** for the built-in `erc7201(...)` helper, so **0.8.35** is the floor. Hardhat is pinned there; forge resolves the newest compatible release its `svm` list carries, currently 0.8.36
- **EVM version**: cancun
- **Node**: >=24 (`engines` in `package.json`)
- **Foundry**: forge must be in PATH (default: `~/.foundry/bin/forge`); **nightly `eb4bf9b4` (1.8.0-nightly, 2026-08-10) or later required**. `stable` (v1.7.1) does carry solc `0.8.35`, but predates two things this repo needs: solar >= v0.2.0, without which the `erc7201(...)` builtin is rejected, and [foundry-rs/foundry#16100](https://github.com/foundry-rs/foundry/pull/16100), without which `forge coverage` silently drops sources whenever one solc version has two compilation jobs — which `[profile.coverage]` deliberately creates, so coverage is wrong on anything older. Install with `foundryup --install nightly-eb4bf9b4a0ca13f5e3ed5b5be221f37bff56a4f9`.
- **Hardhat**: **2.28.6** (pinned in `package.json`) — earlier 2.x mis-resolves solc `0.8.35` to the `0.8.35-pre.1` build that upstream lists first, which fails the `^0.8.35` pragma. Hardhat 3.x is a breaking rewrite and is not supported.
- **Optimizer**: enabled, 200 runs, `via_ir = true` — needed to keep `TeePaymentsUtxo` under the contract size limit. RNat, OZ's `P256`, `NodePossessionVerifier` and the mocks are pinned back to `via_ir = false` by `compilation_restrictions` (Yul stack / unimplemented-feature issues); `[profile.coverage]` inverts this, since coverage forces viaIR off and a few contracts only compile with it.

### Forge

Config in `foundry.toml`. Dependencies managed via Soldeer.

Key remappings (in `remappings.txt`):
- `@openzeppelin/contracts/` → `dependencies/@openzeppelin-contracts-5.6.1/`
- `forge-std/` → `dependencies/forge-std-1.10.0/src/`
- `@flarenetwork/flare-periphery-contracts/flare/` → `dependencies/flare-periphery-0.1.38/src/flare/`

### Hardhat

Config in `hardhat.config.ts`. Uses Truffle5 + Web3 + Ethers plugins. Typechain generates types for ethers-v6, truffle-v5, and web3-v1.

## Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). No co-authored-by lines.

| Type | When to use |
| ---- | ----------- |
| `feat` | Adding new features or functionality |
| `fix` | Fixing a bug |
| `refactor` | Restructuring code without changing behavior |
| `test` | Adding or updating tests |
| `docs` | Documentation changes |
| `chore` | Maintenance tasks (dependencies, tooling, etc.) |
| `ci` | CI/CD pipeline changes |
| `chore(release)` | Creating a release |
| `chore(deploy)` | Updating deploy parameters and scripts |

`fix`, `feat`, and `refactor` modify production/audit-scoped code. `chore` and `test` should not modify audit-scoped files.

## Coding Conventions

### Solidity Function Definition Formatting

All Solidity contracts and interfaces (excluding tests) must follow these formatting rules.

#### Parameters
- If there are input parameters, each must be on its own line
- Closing `)` on its own line at function indent level (4 spaces)
- All input and output parameters must start with `_` (except in `try/catch` blocks)

#### Visibility and Modifiers
- Visibility (`external`, `external view`, `public`, `public view`, `internal`, `internal view`, `private`, `private view`) on its own line (8 spaces indent)
- Keywords like `virtual`, `override`, `payable` stay on the visibility line (e.g., `public payable virtual override`)
- Custom modifiers (e.g., `onlyGovernance`, `onlyOwner(...)`) each on their own line after visibility (8 spaces indent)

#### Returns
- `returns` keyword must have a space before `(`: `returns (` not `returns(`
- Single return parameter: stays on one line with `returns`
- Multiple return parameters: each on its own line (12 spaces indent), closing `)` on its own line (8 spaces indent)

#### Braces
- For contracts (not interfaces), opening `{` on its own line at function indent level (4 spaces)
- For interfaces, functions end with `;`

#### No-parameter Functions
- Same rules apply: visibility on new line, returns split to new lines when multiple

#### Example (contract, with params and multiple returns)
```solidity
    function getTeeGovernance(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold
        )
    {
        // ...
    }
```

#### Example (contract, with modifiers)
```solidity
    function upgradeToAndCall(
        address _newImplementation,
        bytes memory _data
    )
        public payable virtual override
        onlyGovernance
    {
        super.upgradeToAndCall(_newImplementation, _data);
    }
```

#### Example (interface, single return)
```solidity
    function getOpType()
        external view
        returns (bytes32);
```

#### Example (no params, multiple returns)
```solidity
    function getCosigners()
        external view
        returns (
            address[] memory _cosigners,
            uint64 _cosignersThreshold
        );
```

### Naming Conventions

- Internal methods (unless in libraries) and private methods must start with `_`
- All input and output parameters must start with `_` (except in `try/catch` blocks)
- Public/external methods and non-parameter variables should not start with `_`

### Errors and Events Placement

**All custom errors and events must be declared in the public user interface (`I*` under `contracts/userInterfaces/`), never in the implementation contract.** The implementation just uses them by name (since it `is I*`, the error/event is in scope).

This applies to:
- Custom errors used in `require(..., MyError())` or `revert MyError(...)`
- Events emitted by the contract

Rationale: external callers, tests, and other contracts consume the ABI via the interface. Declaring errors/events on the interface keeps them in the public surface, lets consumers reference them as `IMyContract.MyError.selector` / `IMyContract.MyEvent`, and avoids the duplication or drift that happens when they live on the implementation.

This rule applies to **new code only** — do not retroactively move errors/events on legacy contracts (`FdcHub`, `FdcInflationConfigurations`, etc.) that use the older string-`require` or implementation-declared style; touch them only if you're already changing the file's behavior.

### File / Contract Layout Ordering

Solhint enforces the Solidity style-guide ordering (`ordering` rule). When you add or move declarations inside a contract / library / interface, keep this order — getting it wrong yields warnings like *"struct definition can not go after contract constant declaration"* or *"internal function can not go after internal view function"*.

Inside a contract / library / interface:

1. **Type declarations** — `struct`, `enum`
2. **State variables / constants**
3. **Events**
4. **Errors**
5. **Modifiers**
6. **Functions**, in this group order:
   1. constructor → `receive` → `fallback`
   2. `external`
   3. `public`
   4. `internal`
   5. `private`

Within each function visibility group, mutability ordering is **non-view/non-pure first**, then `view`, then `pure`. A non-view internal function placed after an internal view function fires *"internal function can not go after internal view function"*.

If you add a new helper to a library that already mixes view/non-view in the wrong order (pre-existing warning), keep matching the file's local style — don't retroactively reorder unrelated declarations.

### Linting

- Solidity: `pnpm lint-sol` — checks contracts, test-forge, and deployment .sol files
- TypeScript: `pnpm lint:check` — checks deployment, scripts, and test .ts files
- Fix all linter **errors** before considering work done (warnings can be ignored)
- Common rules: max line length 119 characters, named imports, layout / function ordering (see [File / Contract Layout Ordering](#file--contract-layout-ordering))

### Forge Test Conventions

- Test contract names end with `Test` (e.g., `TeeVerificationTest`)
- Test function names start with `test` (e.g., `testConfirmAvailability`)
- Revert tests: `testRevert<MethodName><ErrorName>` or `test<MethodName>Revert<ErrorName>`
- Use `vm.mockCall` for external contract dependencies
- Mock helpers follow pattern: `_mock<Action>` (e.g., `_mockGetTeeMachineStatus`)
- Storage variables for proof structs; use `.push()` for dynamic arrays on storage structs
- Tests that need governance: `vm.prank(initialGovernance)`
- Use `vm.expectEmit()` before the call that should emit
- Use `vm.expectRevert(...)` before the call that should revert

## Deployment

Networks: `flare`, `songbird`, `coston`, `coston2`, `scdev` (local)

```bash
# Full local deploy
pnpm full_deploy_local_hardhat

# Simulation
pnpm sim-node          # Start local node
pnpm sim-run           # Run simulation
```

Chain parameters are in `deployment/chain-config/<network>.json`.

## Governance primitives — which to use

Two governance stacks live in this repo. Both implement the same on-chain semantics (timelock, propose/execute via governance settings, executors); they differ in **how state is stored** and **how the public ABI is exposed**.

| Stack | Storage | Timelock key | Errors | Used by |
|-------|---------|--------------|--------|---------|
| Legacy: [`GovernedBase`](contracts/governance/implementation/GovernedBase.sol) / [`GovernedProxyImplementation`](contracts/governance/implementation/GovernedProxyImplementation.sol) / [`Governed`](contracts/governance/implementation/Governed.sol) | Fixed contract slots 0..N | `bytes4` selector; full encoded call stored on-chain | `require(..., "only governance")` strings | Every production-deployed contract today: `FdcHub`, `FtsoRewardOffersManager`, `ValidatorRewardOffersManager`, `FastUpdateIncentiveManager`, `ChainlinkAdapter`, `FtsoV2Proxy`, `EntityManager`, `FlareSystemsManager`, etc. |
| New: [`FlareGovernance` library](contracts/governance/lib/FlareGovernance.sol) + [`FlareGovernedAccess`](contracts/governance/implementation/FlareGovernedAccess.sol) (modifiers only) + [`FlareGovernedBase`](contracts/governance/implementation/FlareGovernedBase.sol) (modifiers + 7 public functions) | ERC-7201 namespaced slot (`flare.FlareGovernance.State`) | Hash-keyed (`keccak256(encodedCall)` stored; executor supplies full calldata at execution time) | Custom errors / events on [`IFlareGovernance`](contracts/userInterfaces/IFlareGovernance.sol) (e.g. `OnlyGovernance.selector`) | TEE Diamond facets (via `FlareGovernedAccess`) + [`DiamondGovernanceFacet`](contracts/tee/facets/DiamondGovernanceFacet.sol) (via `FlareGovernedBase`); [`FlareUpgradeableBase`](contracts/governance/implementation/FlareUpgradeableBase.sol)-derived UUPS contracts in FDC2 and TEE non-Diamond modules. |

When writing new code:

- **New UUPS proxy implementation** → inherit `FlareUpgradeableBase` (which already brings `FlareGovernedBase` + `UUPSUpgradeable` + `AddressUpdatable`). Use `onlyGovernance` from the inherited base. Use `IFlareGovernance.OnlyGovernance.selector` in revert tests.
- **New TEE Diamond facet** → inherit `FlareGovernedAccess` (modifiers only, no public functions). Only `DiamondGovernanceFacet` exposes the public governance API on the Diamond — never replicate those selectors on other facets.
- **Touching an existing legacy contract** → keep it on `GovernedBase`. Do not silently migrate; an in-place storage-layout swap from fixed slots → ERC-7201 namespace is incompatible with UUPS impl-swaps on already-deployed proxies. Migrate only with explicit redeployment scope.

## Diamond Proxy (EIP-2535) Refactoring Guide

Reference architecture for refactoring existing contracts into the Diamond proxy pattern.
Uses Flare governance (`FlareGovernance` library + `FlareGovernedAccess` / `FlareGovernedBase` for new diamonds; `GovernedBase`/`GovernedProxyImplementation` for legacy contracts) instead of ERC-173 OwnershipFacet.
Same pattern as FAssets AssetManager: https://github.com/flare-foundation/fassets

### Architecture Overview

The Diamond pattern splits a large contract into **facets** (logic modules) behind a single proxy.
All facets share the Diamond's storage via `delegatecall`. External callers interact with one address.

```
User → Diamond.fallback() → lookup selector → delegatecall Facet → Facet calls Library → Library reads/writes namespaced storage
```

### Diamond Project Structure

```
contracts/
  diamond/
    implementation/Diamond.sol       # Core proxy with fallback routing
    libraries/LibDiamond.sol         # Storage, addFunctions/replaceFunctions/removeFunctions
    facets/DiamondLoupeFacet.sol      # EIP-2535 introspection (facets, selectors)
    interfaces/                      # IDiamond, IDiamondCut, IDiamondLoupe, IERC165

  governance/
    implementation/
      FlareGovernedAccess.sol        # Modifiers only; anti-selfdestruct constructor (for non-governance facets)
      FlareGovernedBase.sol          # FlareGovernedAccess + public governance API (for the governance facet + FlareUpgradeableBase)
      FlareUpgradeableBase.sol       # FlareGovernedBase + UUPSUpgradeable + AddressUpdatable (for non-Diamond UUPS contracts)
      GovernedBase.sol               # Legacy stack — used by production contracts not on the new library
      GovernedProxyImplementation.sol # Legacy stack — for legacy UUPS impls
      Governed.sol                   # Legacy stack — for legacy non-proxy contracts
    lib/
      FlareGovernance.sol            # Library with ERC-7201 namespaced storage + hash-based timelock
    interface/
      IIFlareGovernance.sol          # Internal interface (cancelGovernanceCall, switchToProductionMode)

  <domain>/
    implementation/
      <MainController>.sol           # Diamond root (inherits Diamond, acts as entry point)
    facets/
      DiamondGovernanceFacet.sol     # diamondCut + public governance API (inherits FlareGovernedBase). Only facet to expose governance selectors.
      <Domain>Facet.sol              # One per domain — thin wrappers calling libraries
      <Domain>Init.sol               # One-time initialization (called via diamondCut init)
    library/
      <Domain>.sol                   # Core logic per domain, with ERC-7201 namespaced storage
    interface/
      II<Domain>.sol                 # Internal interfaces (II prefix) — used between facets/libraries
    proxy/
      <Entity>Proxy.sol              # Optional beacon proxies managed by Diamond

  userInterfaces/
    I<Domain>.sol                    # Public interfaces (I prefix) — exposed to external callers
```

### Key Pattern 1: Facet = Thin Wrapper, Library = Logic

```solidity
// Facet (thin wrapper with access control via FlareGovernedAccess — modifiers only, no public functions)
contract ConfigFacet is FlareGovernedAccess {
    function setParam(address _param) external onlyGovernance {
        Config.setParam(_param);
    }
    function getParam() external view returns (address) {
        return Config.getParam();
    }
}

// Library (contains all logic and storage)
library Config {
    /// @custom:storage-location erc7201:<namespace>.Config.State
    struct State {
        address param;
        uint256 fee;
    }
    bytes32 internal constant STATE_POSITION = bytes32(erc7201("<namespace>.Config.State"));

    function getState() internal pure returns (State storage _state) {
        bytes32 position = STATE_POSITION;
        assembly { _state.slot := position }
    }
    function setParam(address _param) internal {
        require(_param != address(0), InvalidParam());
        getState().param = _param;
    }
    function getParam() internal view returns (address) {
        return getState().param;
    }
}
```

### Key Pattern 2: ERC-7201 Namespaced Storage

Every library must use its own isolated storage slot, computed with the solc **0.8.35 built-in `erc7201(...)` helper** (not the legacy manual `keccak256(abi.encode(... - 1)) & ~0xff` formula — same value, but the builtin is the canonical form this repo uses):

```solidity
/// @custom:storage-location erc7201:<namespace>.<LibName>.State
struct State {
    /* fields */
}

bytes32 internal constant STATE_POSITION = bytes32(erc7201("<namespace>.<LibName>.State"));
```

- **`@custom:storage-location` annotation is mandatory** on every namespaced State struct. The string after `erc7201:` must match the `erc7201(...)` argument verbatim — tooling (Foundry, OZ upgrade tooling, static analyzers) relies on the match to verify storage layout.
- **Toolchain note:** Forge's `solar` frontend only understands the `erc7201(...)` builtin from v0.2.0 (first shipped in the 2026-07-08 nightly). On anything older, `forge build` and `forge coverage` report a false-positive "unresolved symbol erc7201" on these contracts while solc compiles them fine — which is part of why the toolchain floor is a nightly rather than `stable`.
- **Namespace prefix indicates scope.** Module-specific libraries use the module name (e.g. `tee.MachineManager.State` for [contracts/tee/library/MachineManager.sol](contracts/tee/library/MachineManager.sol)). Project-wide libraries use the `flare` prefix (e.g. `flare.FlareGovernance.State`, `flare.LibDiamond.DiamondStorage`, `flare.diamond.AddressUpdatable.ADDRESS_STORAGE_POSITION`).
- Each library has its own isolated storage slot — no collision between libraries sharing Diamond's storage context.
- State struct contains all mappings/arrays/values for that domain.
- All access goes through `getState()` which returns a storage pointer.
- **For security-sensitive libraries** (governance and similar), consider making `getState()` and `STATE_POSITION` `private` and exposing only specific field accessors (e.g. `governanceSettings()`, `productionMode()`). [`FlareGovernance`](contracts/governance/lib/FlareGovernance.sol) follows this stricter pattern — same posture as OZ `Initializable._getInitializableStorage()` and legacy `GovernedBase`'s private state vars. The default `internal` pattern shown above is fine for everything else.

### Key Pattern 3: Interface Naming Convention

| Prefix | Location | Purpose | Example |
|--------|----------|---------|---------|
| `I` | `userInterfaces/` | Public API for external callers — anything they would call to use the contract, plus **every event and error** the contract emits / raises | `IConfig` |
| `II` | `<domain>/interface/` | Internal/admin — extends `I` and adds Flare-governance-only methods. Used by Diamond facets and also by UUPS / standalone contracts that want to split their admin surface from their public surface | `IIConfig` |

**Where to declare what:**
- Methods callable by external users (read getters, ordinary actions, owner-gated mutators where the "owner" is a project / extension / wallet owner, not Flare governance) → `I*`.
- Methods callable only by Flare governance (`onlyGovernance` or `onlyImmediateGovernance` from the new `FlareGovernance` stack) → `II*`.
- **All events and errors → `I*`**, regardless of which method emits / raises them. This matches the broader rule in [Errors and Events Placement](#errors-and-events-placement): a single shared ABI for every consumer.

Interface names do NOT carry a `Facet` suffix even when they describe a single EIP-2535 facet's API — the suffix belongs on the *contract* (e.g., `ConfigFacet`), not on the interface that describes its behavior.

The aggregate `II<MainController>` interface inherits ALL `II*` interfaces and represents the full Diamond API.

### Key Pattern 4: Access Control via FlareGovernedAccess / FlareGovernedBase

Diamond facets that need governance protection inherit `FlareGovernedAccess` (modifiers only, no public functions — see [`contracts/governance/implementation/FlareGovernedAccess.sol`](contracts/governance/implementation/FlareGovernedAccess.sol)). Only the dedicated governance facet inherits `FlareGovernedBase`, which adds the seven public governance functions on top — preventing duplicate-selector pollution across the Diamond. Both abstracts are backed by the `FlareGovernance` library (ERC-7201 namespaced storage, hash-based timelock).

```solidity
// FlareGovernedAccess / FlareGovernedBase provide these modifiers:
// - onlyGovernance — in production mode, records timelocked call; before production, executes immediately
// - onlyImmediateGovernance — always requires governance address directly, no timelock

// DiamondGovernanceFacet bundles diamondCut + the public governance API (it inherits FlareGovernedBase).
// All other facets inherit FlareGovernedAccess (modifiers only — no public governance selectors).
contract DiamondGovernanceFacet is IIDiamondGovernance, FlareGovernedBase {
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    )
        external override
        onlyGovernance
    {
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
```

**Governance lifecycle:**
1. Before `switchToProductionMode()`: `initialGovernance` (deployer) can call all `onlyGovernance` functions immediately
2. After `switchToProductionMode()`: governance calls record timelocked calls (storing only `keccak256(encodedCall)`), executors execute after timelock expires by supplying the full encoded call
3. `executeGovernanceCall(bytes encodedCall)` — executor submits the full calldata; the hash is verified against the stored hash
4. `cancelGovernanceCall(bytes encodedCall)` — governance can cancel pending calls

**`FlareGovernedAccess` / `FlareGovernedBase`** set governance to a dummy address (`0x...1111`) in their constructor to prevent direct use of the implementation/facet contract. The real `FlareGovernance.initialise(governanceSettings, initialGovernance)` is called through the proxy/diamond init.

### Key Pattern 5: Initialization

The new stack layers OpenZeppelin's [`Initializable`](dependencies/@openzeppelin-contracts-5.4.0/proxy/utils/Initializable.sol) on top of the `FlareGovernance` library. `FlareGovernedAccess` already inherits `Initializable` and calls `_disableInitializers()` in its constructor; concrete `initialize(...)` / `init(...)` external entry points carry the `initializer` modifier; internal helpers like `initializeBase(...)` carry `onlyInitializing`. Future versioned migrations use `reinitializer(uint64 version)`.

```solidity
contract MyInit is Initializable, AddressUpdatable {
    constructor() AddressUpdatable(address(1)) {
        _disableInitializers();
    }

    function init(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _param1,
        uint256 _param2
    )
        external
        initializer
    {
        // Initialize governance (FlareGovernance ERC-7201 namespaced storage)
        FlareGovernance.initialise(_governanceSettings, _initialGovernance);

        // Register ERC-165 interfaces
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;

        // Initialize library states
        Config.State storage state = Config.getState();
        state.param1 = _param1;
        state.param2 = _param2;
    }
}
```

Called once during deployment via `diamondCut(cuts, initAddress, initCalldata)`.
The `initializer` modifier (OZ) is the primary re-init guard; `FlareGovernance.initialise()` keeps its own `bool initialised` check as defense-in-depth (catches in-place UUPS upgrades where OZ's slot is virgin but the FlareGovernance state is already set).

### Key Pattern 6: Selector Registration

Selectors are extracted from compiled artifacts via a helper script that:
1. Loads the facet's ABI from `artifacts/<FacetName>.sol/<FacetName>.json`
2. Filters to only functions that exist in the aggregate interface (`II<MainController>`)
3. Returns the matching `bytes4[]` selectors

This ensures only intended functions are exposed through the Diamond.
The `autoDeleteMethodsNotInInterface` option in cut configs automatically removes selectors not in the interface during upgrades.

### Diamond Deployment Flow

#### Initial Deployment

1. Deploy all facet contracts (simple `new` / CREATE):
   - DiamondGovernanceFacet (the only facet exposing the public governance API + `diamondCut`), DiamondLoupeFacet
   - All domain facets (inherit `FlareGovernedAccess` — modifiers only)
   - Init contract
2. Build FacetCut[] array — for each facet, intersect its ABI with the aggregate interface
3. Encode init calldata with `GovernanceSettings` address, `initialGovernance`, and domain parameters
4. Deploy Diamond: `new MainController(diamondCuts, initAddress, initCalldata)`
   - Constructor calls `LibDiamond.diamondCut()` which registers all facets and delegatecalls init
5. Post-deployment configuration (while still in non-production mode, governance calls execute immediately)
6. Call `switchToProductionMode()` when ready — enables timelocks

#### Upgrade Flow (Config-Driven)

Config JSON:
```json
{
  "diamond": ["MainController"],
  "autoDeleteMethodsNotInInterface": ["II<MainController>"],
  "facets": [
    { "contract": "FacetA", "exposedInterfaces": ["II<MainController>"] },
    { "contract": "FacetB", "exposedInterfaces": ["II<MainController>"] }
  ],
  "init": {
    "contract": "MigrationInit",
    "method": "init",
    "args": ["0x...", "100"]
  }
}
```

The upgrade script:
1. Reads deployed facet addresses from `deployment/deploys/<network>.json`
2. Compares on-chain bytecode with compiled artifacts — reuses if matching, redeploys if changed
3. Reads current Diamond state via DiamondLoupe
4. Computes minimal FacetCut[] (Add new selectors, Replace changed ones, Remove old ones)
5. `autoDeleteMethodsNotInInterface` removes any deployed selectors not in the aggregate interface
6. If not in production mode: executes directly
7. If in production mode: outputs calldata for governance to submit (goes through timelock)

#### Helper Scripts

- Selector extraction script — extracts selectors for a facet, filtered against the aggregate interface
- `deployment/utils/build-cut.ts` — computes minimal diamond cut from current loupe state vs new facets
- `deployment/utils/format-cut.ts` — pretty-prints diamond cut data
- `deployment/utils/update-facet-address.ts` — updates deployed address registry

### Refactoring Checklist: Converting Existing Contracts to Diamond

1. **Identify domains** — group related functions (e.g., all config operations, all fee operations)
2. **For each domain, create:**
   - `library/<Domain>.sol` — move logic here, add ERC-7201 State struct
   - `facets/<Domain>Facet.sol` — thin wrapper inheriting `FlareGovernedAccess`, using `onlyGovernance` modifier
   - `userInterfaces/I<Domain>.sol` — public interface
   - `interface/II<Domain>.sol` — extends public interface with admin functions
3. **Create aggregate interface** — `II<MainController>` inheriting all `II*` interfaces
4. **Create DiamondGovernanceFacet** — inherits `FlareGovernedBase` (full public governance API), exposes `diamondCut` gated by `onlyGovernance`
5. **Create Init contract** — calls `FlareGovernance.initialise()` + initializes all library states
6. **Migrate storage** — convert contract storage to ERC-7201 namespaced library storage
7. **Update deployment scripts** — deploy facets with simple `new`, build cuts, deploy Diamond
8. **Update selector extraction** — add new facet to the helper script, filter against aggregate interface
9. **Copy diamond infrastructure** — `Diamond.sol`, `LibDiamond.sol`, `DiamondLoupeFacet.sol`, all diamond interfaces
10. **Reuse existing governance** — `FlareGovernance.sol` library + `FlareGovernedAccess.sol` + `FlareGovernedBase.sol` already in `contracts/governance/`

---

# Relay.sol verification & hardening engagement (merged from relay-fix-3)

This branch also carries the **formal verification + hardening of
`contracts/protocol/implementation/Relay.sol`** (originally branch `relay-fix-3`, MR !135).
The cross-chain Safe (GSS) governance that was later merged here has been retired before
any deployment; Relay is now governed by a per-chain owner + timelock — see
[`docs/relay-governance.md`](docs/relay-governance.md).

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

## The gates (green = healthy)

| Gate | Command | Checks |
|------|---------|--------|
| Halmos | `HALMOS=$PWD/.venv-halmos/bin/halmos .venv-halmos/bin/python test-forge/fv/verify_fv.py` | exact 89-check inventory vs `test-forge/fv/verification-manifest.json`: 60 proofs PASS + 29 reachability controls with validated counterexamples |
| Lean | `EVMYUL_DIR=/tmp/evmyul2 python3 test-forge/fv/lean/verify_lean.py` | all proof files hole-free vs the pinned semantics |
| Artifact parity | `test-forge/fv/verify_relay_artifact.py` | FV solc output ≡ deployment artifact; optimized Yul ≡ the committed Lean source snapshot |
| Doc links | `python3 docs/relay-verification/verify_links.py --check` (`--fix` to repair) | symbol-addressed code links in the docs stay current |
| Kontrol | `test-forge/fv/kontrol/run.sh` in the Docker image (see its README) | 14 proofs + 6 CEX-by-design vs its manifest (signature loop at N=3 **and** N=5, plus random monotonicity) |

**NOTE (owner-timelock upgradeable refactor):** the Relay governance refactor on this branch
(OwnableWithTimelock base, UUPS proxies, solc 0.8.35; the retired Safe/GSS design and its
suites are gone) deliberately leaves the FV gates red pending a full re-baseline (manifest
hash pins — including dropping the retired `gss_*` inventories and `check_gss_*` entries —
Lean Yul snapshot, Certora munge, Kontrol, compiler re-pins). Do not "fix" the gates
piecemeal; the re-baseline is a dedicated follow-up task.
