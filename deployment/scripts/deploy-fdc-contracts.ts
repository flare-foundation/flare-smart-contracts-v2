/**
 * This script will deploy all FDC contracts.
 * It will output, on stdout, a json encoded list of contracts
 * that were deployed. It will write out to stderr, status info
 * as it executes.
 * @dev Do not send anything out via console.log unless it is
 * json defining the created contracts.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { FdcHubContract } from "../../typechain-truffle";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from "./deploy-utils";

export async function deployFdcContracts(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts, 
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;
  const BN = web3.utils.toBN;

  const FdcHub: FdcHubContract = artifacts.require("FdcHub");

  // Define accounts in play for the deployment process
  let deployerAccount: any;
  // Define repository for created contracts
  // const contracts = new Contracts();

  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e);
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  // const governanceSettings = oldContracts.getContractAddress(Contracts.GOVERNANCE_SETTINGS);

  const fdcHub = await FdcHub.new({ from: deployerAccount.address });
  spewNewContractInfo(contracts, null, FdcHub.contractName, `FdcHub.sol`, fdcHub.address, quiet);

  if (!quiet) {
    console.error("Contracts in JSON:");
    console.log(contracts.serialize());
    console.error("Deploy complete.");
  }
}
