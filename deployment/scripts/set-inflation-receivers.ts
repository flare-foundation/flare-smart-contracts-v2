import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "./Contracts";
import { ChainParameters, integer } from "../chain-config/chain-parameters";

/**
 * This script will set inflation receivers on Inflation contract.
 * It assumes that all contracts have been deployed and contract addresses
 * provided in Contracts object.
 * @dev Do not send anything out via console.log unless it is json defining the created contracts.
 */
export async function setInflationReceivers(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false) {

  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  if (!quiet) {
    console.error("Setting inflation receivers...");
  }

  // Define accounts in play for the deployment process
  let deployerAccount: any;
  let genesisGovernanceAccount: any;

  // Get deployer account
  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e)
  }

  try {
    genesisGovernanceAccount = web3.eth.accounts.privateKeyToAccount(parameters.genesisGovernancePrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e)
  }

  if (!quiet) {
    console.error(`Setting inflation receivers with address ${deployerAccount.address}`)
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  // Get contract definitions
  const Inflation = artifacts.require("IIInflation");
  const InflationAllocation = artifacts.require("IIInflationAllocation");

  // Fetch inflation contracts
  const inflation = await Inflation.at(oldContracts.getContractAddress(Contracts.INFLATION));
  const inflationAllocation = await InflationAllocation.at(oldContracts.getContractAddress(Contracts.INFLATION_ALLOCATION));

  // Set inflation topup configuration
  const receiversAddresses: string[] = [];
  const inflationSharingBIPS: integer[] = [];

  for (const ir of parameters.inflationReceivers) {
    if (!quiet) {
      console.error(`Registering ${ir.contractName} on inflation with topup type ${ir.topUpType}, topup factor (x100) ${ir.topUpFactorx100} and sharing BIPS ${ir.sharingBIPS}`);
    }
    const receiverAddress = ir.oldContract ? oldContracts.getContractAddress(ir.contractName) : contracts.getContractAddress(ir.contractName);
    await inflation.setTopupConfiguration(receiverAddress, ir.topUpType, ir.topUpFactorx100);
    receiversAddresses.push(receiverAddress);
    inflationSharingBIPS.push(ir.sharingBIPS);
  }
  // Set inflation sharing percentages
  await inflationAllocation.setSharingPercentages(receiversAddresses, inflationSharingBIPS);
}
