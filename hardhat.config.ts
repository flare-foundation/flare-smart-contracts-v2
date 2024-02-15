import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-truffle5";
import "@nomiclabs/hardhat-web3";
import "@nomicfoundation/hardhat-chai-matchers";
import 'solidity-coverage';

import { HardhatUserConfig, task } from "hardhat/config";
import * as dotenv from "dotenv";
import { runSimulation } from "./deployment/tasks/run-simulation";
import { loadParameters, verifyParameters } from "./deployment/scripts/deploy-utils";
import { Contracts } from "./deployment/scripts/Contracts";
import { deployContracts } from "./deployment/scripts/deploy-contracts";
import { deploySubmissionContract } from "./deployment/scripts/deploy-submission-contract";
import { setInflationReceivers } from "./deployment/scripts/set-inflation-receivers";
import { daemonizeContracts } from "./deployment/scripts/daemonize-contracts";
import { switchToProductionMode } from "./deployment/scripts/switch-to-production-mode";
import { transferAndWrapFunds } from "./deployment/tasks/transfer-and-wrap-funds";
import { getEntityAccounts, readEntities } from "./deployment/utils/Entity";
import { registerEntities } from "./deployment/tasks/register-entities";

dotenv.config();

let fs = require('fs');

// Config
let accounts = [
  // In Truffle, default account is always the first one.
  ...(process.env.DEPLOYER_PRIVATE_KEY ? [{ privateKey: process.env.DEPLOYER_PRIVATE_KEY, balance: "100000000000000000000000000000000" }] : []),
  // First 20 accounts with 10^14 NAT each
  // Addresses:
  //   0xc783df8a850f42e7f7e57013759c285caa701eb6
  //   0xead9c93b79ae7c1591b1fb5323bd777e86e150d4
  //   0xe5904695748fe4a84b40b3fc79de2277660bd1d3
  //   0x92561f28ec438ee9831d00d1d59fbdc981b762b2
  //   0x2ffd013aaa7b5a7da93336c2251075202b33fb2b
  //   0x9fc9c2dfba3b6cf204c37a5f690619772b926e39
  //   0xfbc51a9582d031f2ceaad3959256596c5d3a5468
  //   0x84fae3d3cba24a97817b2a18c2421d462dbbce9f
  //   0xfa3bdc8709226da0da13a4d904c8b66f16c3c8ba
  //   0x6c365935ca8710200c7595f0a72eb6023a7706cd
  //   0xd7de703d9bbc4602242d0f3149e5ffcd30eb3adf
  //   0x532792b73c0c6e7565912e7039c59986f7e1dd1f
  //   0xea960515f8b4c237730f028cbacf0a28e7f45de0
  //   0x3d91185a02774c70287f6c74dd26d13dfb58ff16
  //   0x5585738127d12542a8fd6c71c19d2e4cecdab08a
  //   0x0e0b5a3f244686cf9e7811754379b9114d42f78b
  //   0x704cf59b16fd50efd575342b46ce9c5e07076a4a
  //   0x0a057a7172d0466aef80976d7e8c80647dfd35e3
  //   0x68dfc526037e9030c8f813d014919cc89e7d4d74
  //   0x26c43a1d431a4e5ee86cd55ed7ef9edf3641e901
  ...JSON.parse(fs.readFileSync('deployment/test-1020-accounts.json')).slice(0, process.env.TENDERLY == 'true' ? 150 : 2000).filter((x: any) => x.privateKey != process.env.DEPLOYER_PRIVATE_KEY),
  ...(process.env.GENESIS_GOVERNANCE_PRIVATE_KEY ? [{ privateKey: process.env.GENESIS_GOVERNANCE_PRIVATE_KEY, balance: "100000000000000000000000000000000" }] : []),
  ...(process.env.GOVERNANCE_PRIVATE_KEY ? [{ privateKey: process.env.GOVERNANCE_PRIVATE_KEY, balance: "100000000000000000000000000000000" }] : []),
  ...(process.env.SUBMISSION_DEPLOYER_PRIVATE_KEY ? [{ privateKey: process.env.SUBMISSION_DEPLOYER_PRIVATE_KEY, balance: "100000000000000000000000000000000" }] : []),
  ...(process.env.ACCOUNT_WITH_FUNDS_PRIVATE_KEY ? [{ privateKey: process.env.ACCOUNT_WITH_FUNDS_PRIVATE_KEY, balance: "100000000000000000000000000000000" }] : []),
  ...(process.env.ENTITIES_FILE_PATH ? getEntityAccounts(process.env.ENTITIES_FILE_PATH) : []),
];

function getChainConfigParameters(chainConfig: string | undefined) {
  if (chainConfig) {
    const parameters = loadParameters(`deployment/chain-config/${chainConfig}.json`);

    // inject private keys from .env, if they exist
    if (process.env.SUBMISSION_DEPLOYER_PRIVATE_KEY) {
      parameters.submissionDeployerPrivateKey = process.env.SUBMISSION_DEPLOYER_PRIVATE_KEY
    }
    if (process.env.DEPLOYER_PRIVATE_KEY) {
      parameters.deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY
    }
    if (process.env.GENESIS_GOVERNANCE_PRIVATE_KEY) {
      parameters.genesisGovernancePrivateKey = process.env.GENESIS_GOVERNANCE_PRIVATE_KEY
    }
    if (process.env.GOVERNANCE_PRIVATE_KEY) {
      parameters.governancePrivateKey = process.env.GOVERNANCE_PRIVATE_KEY
    }
    if (process.env.GOVERNANCE_PUBLIC_KEY) {
      parameters.governancePublicKey = process.env.GOVERNANCE_PUBLIC_KEY
    }
    if (process.env.GOVERNANCE_EXECUTOR_PUBLIC_KEY) {
      parameters.governanceExecutorPublicKey = process.env.GOVERNANCE_EXECUTOR_PUBLIC_KEY
    }
    verifyParameters(parameters);
    return parameters;
  } else {
    return undefined;
  }
}

function readContracts(network: string, filePath?: string): Contracts {
  const contracts = new Contracts();
  contracts.deserializeFile(filePath || (`deployment/deploys/${network}.json`));
  return contracts;
}

// Tasks

task("run-simulation", `Runs local simulation.`) // prettier-ignore
  .addOptionalParam("voters", "Number of voters to simulate", "4")
  .setAction(async (args, hre, _runSuper) => {
    await runSimulation(hre, accounts, +args.voters);
  });

task("transfer-and-wrap-funds", `Transfer and wrap funds.`)
  .setAction(async (args, hre, _runSuper) => {
    if (!process.env.CHAIN_CONFIG) {
      throw Error("CHAIN_CONFIG environment variable not set.")
    }
    if (!process.env.OLD_CONTRACTS_PATH) {
      throw Error("OLD_CONTRACTS_PATH environment variable not set. Must be json file path.")
    }
    if (!process.env.ENTITIES_FILE_PATH) {
      throw Error("ENTITIES_FILE_PATH environment variable not set. Must be json file path.")
    }
    if (!process.env.ACCOUNT_WITH_FUNDS_PRIVATE_KEY) {
      throw Error("ACCOUNT_WITH_FUNDS_PRIVATE_KEY environment variable not set.")
    }
    const network = process.env.CHAIN_CONFIG;
    const oldContracts = readContracts(network, process.env.OLD_CONTRACTS_PATH);
    const entities = readEntities(process.env.ENTITIES_FILE_PATH);
    await transferAndWrapFunds(hre, process.env.ACCOUNT_WITH_FUNDS_PRIVATE_KEY, oldContracts, entities, args.quiet);
  });

task("register-entities", `Entities registration.`)
  .setAction(async (args, hre, _runSuper) => {
    if (!process.env.CHAIN_CONFIG) {
      throw Error("CHAIN_CONFIG environment variable not set.")
    }
    if (!process.env.ENTITIES_FILE_PATH) {
      throw Error("ENTITIES_FILE_PATH environment variable not set. Must be json file path.")
    }
    const network = process.env.CHAIN_CONFIG;
    const contracts = readContracts(network);
    const entities = readEntities(process.env.ENTITIES_FILE_PATH!);
    await registerEntities(hre, contracts, entities, args.quiet);
  });

task("deploy-submission-contract", "Deploy submission contract")
.addFlag("quiet", "Suppress console output")
.setAction(async (args, hre, runSuper) => {
  if (!process.env.OLD_CONTRACTS_PATH) {
    throw Error("OLD_CONTRACTS_PATH environment variable not set. Must be json file path.")
  }
  const parameters = getChainConfigParameters(process.env.CHAIN_CONFIG);
  if (parameters) {
    const network = process.env.CHAIN_CONFIG!;
    const oldContracts = readContracts(network, process.env.OLD_CONTRACTS_PATH);
    await deploySubmissionContract(hre, oldContracts, parameters, args.quiet);
  } else {
    throw Error("CHAIN_CONFIG environment variable not set. Must be parameter json file name.")
  }
});

task("deploy-contracts", "Deploy contracts")
  .addFlag("quiet", "Suppress console output")
  .setAction(async (args, hre, runSuper) => {
    if (!process.env.OLD_CONTRACTS_PATH) {
      throw Error("OLD_CONTRACTS_PATH environment variable not set. Must be json file path.")
    }
    const parameters = getChainConfigParameters(process.env.CHAIN_CONFIG);
    if (parameters) {
      const network = process.env.CHAIN_CONFIG!;
      const oldContracts = readContracts(network, process.env.OLD_CONTRACTS_PATH);
      const contracts = readContracts(network);
      await deployContracts(hre, oldContracts, contracts, parameters, args.quiet);
    } else {
      throw Error("CHAIN_CONFIG environment variable not set. Must be parameter json file name.")
    }
  });

task("set-inflation-receivers", "Set inflation receivers")
  .addFlag("quiet", "Suppress console output")
  .setAction(async (args, hre, runSuper) => {
    if (!process.env.OLD_CONTRACTS_PATH) {
      throw Error("OLD_CONTRACTS_PATH environment variable not set. Must be json file path.")
    }
    const parameters = getChainConfigParameters(process.env.CHAIN_CONFIG);
    if (parameters) {
      const network = process.env.CHAIN_CONFIG!;
      const oldContracts = readContracts(network, process.env.OLD_CONTRACTS_PATH);
      const contracts = readContracts(network);
      await setInflationReceivers(hre, oldContracts, contracts, parameters, args.quiet);
    } else {
      throw Error("CHAIN_CONFIG environment variable not set. Must be parameter json file name.")
    }
  });

task("daemonize-contracts", "Daemonize contracts")
  .addFlag("quiet", "Suppress console output")
  .setAction(async (args, hre, runSuper) => {
    if (!process.env.OLD_CONTRACTS_PATH) {
      throw Error("OLD_CONTRACTS_PATH environment variable not set. Must be json file path.")
    }
    const parameters = getChainConfigParameters(process.env.CHAIN_CONFIG);
    if (parameters) {
      const network = process.env.CHAIN_CONFIG!;
      const oldContracts = readContracts(network, process.env.OLD_CONTRACTS_PATH);
      const contracts = readContracts(network);
      await daemonizeContracts(hre, oldContracts, contracts, parameters, args.quiet);
    } else {
      throw Error("CHAIN_CONFIG environment variable not set. Must be parameter json file name.")
    }
  });

task("switch-to-production-mode", "Switch to production mode")
  .addFlag("quiet", "Suppress console output")
  .setAction(async (args, hre, runSuper) => {
    const parameters = getChainConfigParameters(process.env.CHAIN_CONFIG);
    if (parameters) {
      const network = process.env.CHAIN_CONFIG!;
      const contracts = readContracts(network);
      await switchToProductionMode(hre, contracts, parameters, args.quiet);
    } else {
      throw Error("CHAIN_CONFIG environment variable not set. Must be parameter json file name.")
    }
  });

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          evmVersion: "london",
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
    overrides: {
      "contracts/mock/Imports.sol": {
        version: "0.6.12",
        settings: {},
      },
      "@gnosis.pm/mock-contract/contracts/MockContract.sol": {
        version: "0.6.12",
        settings: {},
      },
      // EXTRA_OVERRIDES
    },
  },

  mocha: {
    timeout: 100000000,
  },

  defaultNetwork: "hardhat",

  networks: {
    scdev: {
      url: "http://127.0.0.1:9650/ext/bc/C/rpc",
      gas: 8000000,
      timeout: 40000,
      accounts: accounts.map((x: any) => x.privateKey),
    },
    staging: {
      url: process.env.STAGING_RPC || "http://127.0.0.1:9650/ext/bc/C/rpc",
      timeout: 40000,
      accounts: accounts.map((x: any) => x.privateKey),
    },
    songbird: {
      url: process.env.SONGBIRD_RPC || "https://songbird-api.flare.network/ext/C/rpc",
      gas: 8000000,
      timeout: 40000,
      accounts: accounts.map((x: any) => x.privateKey),
    },
    flare: {
      url: process.env.FLARE_RPC || "https://flare-api.flare.network/ext/C/rpc",
      gas: 8000000,
      timeout: 40000,
      accounts: accounts.map((x: any) => x.privateKey),
    },
    coston: {
      url: process.env.COSTON_RPC || "https://coston-api.flare.network/ext/C/rpc",
      gas: 8000000,
      timeout: 40000,
      accounts: accounts.map((x: any) => x.privateKey),
    },
    coston2: {
      url: process.env.COSTON2_RPC || "https://coston2-api.flare.network/ext/C/rpc",
      gas: 8000000,
      timeout: 40000,
      accounts: accounts.map((x: any) => x.privateKey),
    },
    hardhat: {
      accounts,
      initialDate: "2021-01-01", // no time - get UTC @ 00:00:00
      blockGasLimit: 125000000, // 10x ETH gas
      /*
        Normally each Truffle smart contract interaction that modifies state results in a transaction mined in a new block
        with a +1s block timestamp. This is problematic because we need perform multiple smart contract actions
        in the same price epoch, and the block timestamps end up not fitting into an epoch duration, causing test failures.
        Enabling consecutive blocks with the same timestamp is not perfect, but it alleviates this problem.
        A better solution would be manual mining and packing multiple e.g. setup transactions into a single block with a controlled
        timestamp, but that  would make test code more complex and seems to be not very well supported by Truffle.
      */
      allowBlocksWithSameTimestamp: true,
    },
    local: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
  },
  paths: {
    sources: "./contracts/",
    tests: process.env.TEST_PATH || "test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
