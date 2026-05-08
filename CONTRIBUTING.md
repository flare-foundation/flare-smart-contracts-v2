# Contributing

If you want to contribute to this project, you MUST follow the guidelines below.

Any changes you make SHOULD be noted in the changelog.

For merge request to be accepted, it MUST pass all linter and formatter checks,
MUST pass all tests, and MUST be reviewed by at least one other contributor.

## Set up your dev environment

### Hardhat

```bash
# install dependencies
yarn --frozen-lockfile

# compile contracts
yarn compile
```

### Foundry

```bash
# install Foundryup
curl -L https://foundry.paradigm.xyz | bash
foundryup

# install dependencies
forge soldeer install

# compile contracts
forge build
```

## Testing


### Hardhat

#### How to run

```bash
# recompile contracts before running tests
yarn compile

# all hardhat tests
yarn hardhat test

# only unit tests in hardhat environment
yarn test_unit_hh

# only integration tests in hardhat environment
yarn test_integration_hh

# generate coverage report
yarn coverage
```

### Foundry

#### How to run

```bash
# all forge tests
forge test

# all tests of a test contract
forge test --mc <contract_name>

# specific test function
forge test --mt <test_name>

# generate coverage report
yarn coverage-forge
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
yarn install-slither
```

If you wish to install slither yourself you can check their instructions [here](https://github.com/crytic/slither?tab=readme-ov-file#how-to-install).

### How to run

```bash
# run eslint
yarn eslint

# run solhint
yarn lint

# run solhint on forge test contracts
yarn lint-forge

# run slither
yarn slither
```