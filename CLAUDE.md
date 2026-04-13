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

- **Solidity version**: 0.8.27+ (compiled with 0.8.30)
- **EVM version**: cancun
- **Node**: >=22
- **Foundry**: forge must be in PATH (default: `~/.foundry/bin/forge`)
- **Optimizer**: enabled, 200 runs, `via_ir = false`

### Forge

Config in `foundry.toml`. Dependencies managed via Soldeer.

Key remappings (in `remappings.txt`):
- `@openzeppelin/contracts/` → `dependencies/@openzeppelin-contracts-5.4.0/`
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

### Linting

- Solidity: `pnpm lint-sol` — checks contracts, test-forge, and deployment .sol files
- TypeScript: `pnpm lint:check` — checks deployment, scripts, and test .ts files
- Fix all linter **errors** before considering work done (warnings can be ignored)
- Common rules: max line length 119 characters, named imports, proper function ordering

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

## Diamond Proxy (EIP-2535) Refactoring Guide

Reference architecture for refactoring existing contracts into the Diamond proxy pattern.
Uses Flare governance (`GovernedBase`/`GovernedProxyImplementation`) instead of ERC-173 OwnershipFacet.
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
      GovernedBase.sol               # Timelock + governance logic (already exists in this repo)
      GovernedProxyImplementation.sol # GovernedBase for proxies/facets (anti-selfdestruct)
      Governed.sol                   # GovernedBase for non-proxy contracts

  <domain>/
    implementation/
      <MainController>.sol           # Diamond root (inherits Diamond, acts as entry point)
    facets/
      DiamondCutFacet.sol            # Facet add/replace/remove (inherits GovernedProxyImplementation)
      <Domain>Facet.sol              # One per domain — thin wrappers calling libraries
      <Domain>Init.sol               # One-time initialization (called via diamondCut init)
    library/
      <Domain>.sol                   # Core logic per domain, with ERC-7201 namespaced storage
    interface/
      II<Domain>.sol                 # Internal interfaces (II prefix) — used between facets/libraries
    proxy/
      <Entity>Proxy.sol              # Optional beacon proxies managed by Diamond

  userInterfaces/
    I<Domain>Facet.sol               # Public interfaces (I prefix) — exposed to external callers
    facets/
      II<FacetName>.sol              # Full facet interfaces (admin + public)
```

### Key Pattern 1: Facet = Thin Wrapper, Library = Logic

```solidity
// Facet (thin wrapper with access control via GovernedProxyImplementation)
contract ConfigFacet is GovernedProxyImplementation {
    function setParam(address _param) external onlyGovernance {
        Config.setParam(_param);
    }
    function getParam() external view returns (address) {
        return Config.getParam();
    }
}

// Library (contains all logic and storage)
library Config {
    struct State {
        address param;
        uint256 fee;
    }
    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("<namespace>.Config.State")) - 1)
    ) & ~bytes32(uint256(0xff));

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

Every library must use its own isolated storage slot:

```solidity
bytes32 internal constant STATE_POSITION = keccak256(
    abi.encode(uint256(keccak256("<namespace>.<LibName>.State")) - 1)
) & ~bytes32(uint256(0xff));
```

- Each library has its own isolated storage slot — no collision between libraries sharing Diamond's storage context
- State struct contains all mappings/arrays/values for that domain
- All access goes through `getState()` which returns a storage pointer

### Key Pattern 3: Interface Naming Convention

| Prefix | Location | Purpose | Example |
|--------|----------|---------|---------|
| `I` | `userInterfaces/` | Public API for external callers | `IConfigFacet` |
| `II` | `<domain>/interface/` | Internal/admin — extends I-interface | `IIConfigFacet` |

The aggregate `II<MainController>` interface inherits ALL `II*` interfaces and represents the full Diamond API.

### Key Pattern 4: Access Control via GovernedProxyImplementation

Facets that need governance protection inherit `GovernedProxyImplementation` (from `contracts/governance/`).
This replaces both OwnershipFacet and any custom Timelock — GovernedBase has timelock built in.

```solidity
// GovernedBase provides these modifiers:
// - onlyGovernance — in production mode, records timelocked call; before production, executes immediately
// - onlyImmediateGovernance — always requires governance address directly, no timelock

// DiamondCutFacet uses governance instead of LibDiamond.enforceIsContractOwner()
contract DiamondCutFacet is IDiamondCut, GovernedProxyImplementation {
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
2. After `switchToProductionMode()`: governance calls record timelocked calls, executors execute after timelock expires
3. `executeGovernanceCall(selector)` — executor calls after timelock to execute pending call
4. `cancelGovernanceCall(selector)` — governance can cancel pending calls

**GovernedProxyImplementation** sets governance to a dummy address (`0x...1111`) in its constructor to prevent direct use of the implementation contract. The real `initialise(governanceSettings, initialGovernance)` is called through the proxy/diamond init.

### Key Pattern 5: Initialization

```solidity
contract MyInit is GovernedProxyImplementation {
    function init(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _param1,
        uint256 _param2
    )
        external
    {
        // Initialize governance (from GovernedBase)
        GovernedBase.initialise(_governanceSettings, _initialGovernance);

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
Must call `GovernedBase.initialise()` to set up governance — this replaces `owner` setup.

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
   - DiamondCutFacet, DiamondLoupeFacet
   - All domain facets
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
   - `facets/<Domain>Facet.sol` — thin wrapper inheriting `GovernedProxyImplementation`, using `onlyGovernance` modifier
   - `userInterfaces/I<Domain>Facet.sol` — public interface
   - `interface/II<Domain>Facet.sol` — extends public interface with admin functions
3. **Create aggregate interface** — `II<MainController>` inheriting all `II*` interfaces
4. **Create DiamondCutFacet** — inherits `GovernedProxyImplementation`, uses `onlyGovernance` instead of `LibDiamond.enforceIsContractOwner()`
5. **Create Init contract** — calls `GovernedBase.initialise()` + initializes all library states
6. **Migrate storage** — convert contract storage to ERC-7201 namespaced library storage
7. **Update deployment scripts** — deploy facets with simple `new`, build cuts, deploy Diamond
8. **Update selector extraction** — add new facet to the helper script, filter against aggregate interface
9. **Copy diamond infrastructure** — `Diamond.sol`, `LibDiamond.sol`, `DiamondLoupeFacet.sol`, all diamond interfaces
10. **Reuse existing governance** — `GovernedBase.sol`, `GovernedProxyImplementation.sol` already in `contracts/governance/`
