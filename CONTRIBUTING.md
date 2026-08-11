# Contributing

If you want to contribute to this project, you MUST follow the guidelines below.

Any changes you make SHOULD be noted in the changelog.

For merge request to be accepted, it MUST pass all linter and formatter checks,
MUST pass all tests, and MUST be reviewed by at least one other contributor.

> **IMPORTANT:** If you use AI assistance (GitHub Copilot, ChatGPT, Claude, etc.)
> while contributing, you MUST disclose this in your merge request description.

## Set up your dev environment

### Hardhat

```bash
# install dependencies
pnpm --frozen-lockfile

# compile contracts
pnpm compile
```

### Foundry

```bash
# install Foundryup
curl -L https://foundry.paradigm.xyz | bash

# a nightly with foundry-rs/foundry#16100 is required: on older forge the coverage
# profile's two same-version compilation jobs collide and coverage is silently wrong
foundryup --install nightly-eb4bf9b4a0ca13f5e3ed5b5be221f37bff56a4f9

# install dependencies
forge soldeer install

# compile contracts
forge build
```

## Testing

### Hardhat

```bash
# recompile contracts before running tests
pnpm compile

# all hardhat tests
pnpm hardhat test

# only unit tests in hardhat environment
pnpm test_unit_hh

# only integration tests in hardhat environment
pnpm test_integration_hh

# generate coverage report
pnpm coverage
```

### Foundry

```bash
# all forge tests
forge test

# all tests of a test contract
forge test --mc <contract_name>

# specific test function
forge test --mt <test_name>

# generate coverage report
pnpm coverage-forge
```

The default behavior for forge test is to only display a summary of passing and failing tests. To show more information change the verbosity level with the `-v` flag:
- `-vv`: displays logs emitted during tests, including assertion errors (e.g., expected vs. actual values);
- `-vvv`: shows execution traces for failing tests, in addition to logs;
- `-vvvv`: displays execution traces for all tests and setup traces for failing tests;
- `-vvvvv`: provides the most detailed output, showing execution and setup traces for all tests, including storage changes.

## Linting and formatting

There are currently three linters included in this repository:

- `eslint` javascript linter
- `solhint` solidity linter
- `slither` solidity static analyser

### Install slither

[Slither](https://github.com/crytic/slither) is an external tool that isn't managed by project's dependencies. As such it needs to be installed manually. We provide a script that depends on installed `pip3`.

```bash
# installs slither via pip if slither executable isn't found in PATH
pnpm install-slither
```

If you wish to install slither yourself you can check their instructions [here](https://github.com/crytic/slither?tab=readme-ov-file#how-to-install).

### How to run

```bash
# run eslint on TypeScript
pnpm lint:check

# run solhint on all Solidity
pnpm lint-sol

# run slither
pnpm slither

# check formatting
pnpm format:check
```

## Deployment

Supported networks: `flare`, `songbird`, `coston`, `coston2`, `scdev` (local).

### TEE Diamond deploy (Forge)

```bash
pnpm deploy_tee_contracts <network> <fullDeploy:boolean>
```

### Diamond cut execution

```bash
pnpm tee_diamond_cut <network> <cut-config-name>
```

Cut configurations are in `deployment/cuts/<network>/`.
Internal output files are written to `deployment/output-internal/` (gitignored).
