/**
 * This script will deploy TEE contracts.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from "./deploy-utils";
import { TEERegistryContract } from "../../typechain-truffle/contracts/tee/implementation/TEERegistry";
import { TEEConfigContract } from "../../typechain-truffle/contracts/tee/implementation/TEEConfig";
import { TEEWalletContract } from "../../typechain-truffle/contracts/tee/implementation/TEEWallet";

export async function deployTeeContracts(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  const TeeRegistry: TEERegistryContract = artifacts.require("TeeRegistry");
  const TeeConfig: TEEConfigContract = artifacts.require("TeeConfig");
  const TeeWallet: TEEWalletContract = artifacts.require("TeeWallet");

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
  spewNewContractInfo(contracts, null, TeeRegistry.contractName, `TEERegistry.sol`, teeRegistry.address, quiet);

  const teeConfig = await TeeConfig.new(governanceSettings, deployerAccount.address, deployerAccount.address);
  spewNewContractInfo(contracts, null, TeeConfig.contractName, `TEEConfig.sol`, teeConfig.address, quiet);

  const teeWallet = await TeeWallet.new(governanceSettings, deployerAccount.address, deployerAccount.address);
  spewNewContractInfo(contracts, null, TeeWallet.contractName, `TEEWallet.sol`, teeWallet.address, quiet);

  // update contract addresses
  await teeRegistry.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER]),
    [addressUpdater]);

  await teeConfig.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_REGISTRY]),
    [addressUpdater, teeRegistry.address]);

  await teeWallet.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_CONFIG, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeConfig.address, flareSystemsManager]);

  // switch to production mode
  await teeRegistry.switchToProductionMode();
  await teeConfig.switchToProductionMode();
  await teeWallet.switchToProductionMode();

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
