import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-truffle5";
import "@nomiclabs/hardhat-web3";
import "@nomicfoundation/hardhat-chai-matchers";
import 'solidity-coverage';

import { HardhatUserConfig, task } from "hardhat/config";
import * as dotenv from "dotenv";
import { runSimulation } from "./deployment/tasks/run-simulation";

dotenv.config();

let fs = require('fs');

// Tasks

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
];

// Tasks

task("run-simulation", `Runs local simulation.`) // prettier-ignore
  .addOptionalParam("voters", "Number of voters to simulate", "4")
  .setAction(async (args, hre, _runSuper) => {
    await runSimulation(hre, accounts, +args.voters);
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
      timeout: 40000,
      accounts: accounts.map((x: any) => x.privateKey),
    },
    flare: {
      url: process.env.FLARE_RPC || "https://flare-api.flare.network/ext/C/rpc",
      timeout: 40000,
      accounts: accounts.map((x: any) => x.privateKey),
    },
    coston: {
      url: process.env.COSTON_RPC || "https://coston-api.flare.network/ext/C/rpc",
      timeout: 40000,
      accounts: accounts.map((x: any) => x.privateKey),
    },
    coston2: {
      url: process.env.COSTON2_RPC || "https://coston2-api.flare.network/ext/C/rpc",
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
