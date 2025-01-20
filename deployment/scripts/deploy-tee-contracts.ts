/**
 * This script will deploy TEE contracts.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from "./deploy-utils";
import { TeeRegistryContract } from "../../typechain-truffle/contracts/tee/implementation/TeeRegistry";
import { TeeWalletConfigContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletConfig";
import { TeeWalletManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletManager";

export async function deployTeeContracts(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  const TeeRegistry: TeeRegistryContract = artifacts.require("TeeRegistry");
  const TeeWalletConfig: TeeWalletConfigContract = artifacts.require("TeeWalletConfig");
  const TeeWalletManager: TeeWalletManagerContract = artifacts.require("TeeWalletManager");

  // Define accounts in play for the deployment process
  let deployerAccount: any;

  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e);
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  const governanceSettings = oldContracts.getContractAddress(Contracts.GOVERNANCE_SETTINGS);
  const addressUpdater = oldContracts.getContractAddress(Contracts.ADDRESS_UPDATER);
  const flareSystemsManager = contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER);

  // deploy contracts
  const teeRegistry = await TeeRegistry.new(governanceSettings, deployerAccount.address, deployerAccount.address);
  spewNewContractInfo(contracts, null, TeeRegistry.contractName, `TeeRegistry.sol`, teeRegistry.address, quiet);

  const teeWalletConfig = await TeeWalletConfig.new(governanceSettings, deployerAccount.address, deployerAccount.address);
  spewNewContractInfo(contracts, null, TeeWalletConfig.contractName, `TeeWalletConfig.sol`, teeWalletConfig.address, quiet);

  const teeWalletManager = await TeeWalletManager.new(governanceSettings, deployerAccount.address, deployerAccount.address);
  spewNewContractInfo(contracts, null, TeeWalletManager.contractName, `TeeWalletManager.sol`, teeWalletManager.address, quiet);

  // update contract addresses
  await teeRegistry.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER]),
    [addressUpdater]);

  await teeWalletConfig.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_REGISTRY]),
    [addressUpdater, teeRegistry.address]);

  await teeWalletManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_CONFIG, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeWalletConfig.address, flareSystemsManager]);

  // switch to production mode
  await teeRegistry.switchToProductionMode();
  await teeWalletConfig.switchToProductionMode();
  await teeWalletManager.switchToProductionMode();

  contracts.serialize();
  if (!quiet) {
    console.error("Deploy complete.");
  }

  function encodeContractNames(names: string[]): string[] {
    return names.map(name => encodeString(name));
  }

  function encodeString(text: string): string {
    return web3.utils.keccak256(web3.eth.abi.encodeParameters(["string"], [text]));
  }
}
