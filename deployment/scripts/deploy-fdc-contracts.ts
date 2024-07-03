/**
 * This script will deploy FdcHub contract using real FlareSystemManager contract and mock contracts for the rest.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { FdcHubContract, MockContractContract } from "../../typechain-truffle";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contracts } from "./Contracts";

export async function deployFdcContracts(
  hre: HardhatRuntimeEnvironment,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  const FdcHub: FdcHubContract = artifacts.require("FdcHub");
  const MockContract: MockContractContract = artifacts.require("MockContract");

  // Define accounts in play for the deployment process
  let deployerAccount: any;

  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e);
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  const mockContract = await MockContract.new();

  const fdcHub = await FdcHub.new(mockContract.address, deployerAccount.address, deployerAccount.address);
  await fdcHub.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.REWARD_MANAGER, Contracts.INFLATION]),
    [deployerAccount.address, contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER), mockContract.address, mockContract.address]);

  if (!quiet) {
    console.error("FdcHub contract address: ", fdcHub.address);
    console.error("Deploy complete.");
  }

  function encodeContractNames(names: string[]): string[] {
    return names.map(name => encodeString(name));
  }

  function encodeString(text: string): string {
    return web3.utils.keccak256(web3.eth.abi.encodeParameters(["string"], [text]));
  }
}
