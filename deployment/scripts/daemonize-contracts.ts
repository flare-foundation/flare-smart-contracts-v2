import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "./Contracts";
import { ChainParameters } from "../chain-config/chain-parameters";

/**
 * This script will register all required contracts to the FlareDaemon.
 * It assumes that all contracts have been deployed and contract addresses
 * provided in Contracts object.
 * @dev Do not send anything out via console.log unless it is json defining the created contracts.
 */
export async function daemonizeContracts(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false) {

  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  if (!quiet) {
    console.error("Daemonizing contracts...");
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
    console.error(`Set daemonized contracts with address ${deployerAccount.address}`)
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  // Get contract definitions
  const FlareDaemon = artifacts.require("IIFlareDaemon");

  // Fetch flare daemon
  const flareDaemon = await FlareDaemon.at(oldContracts.getContractAddress(Contracts.FLARE_DAEMON));

  // Register daemonized contracts to the daemon...order matters. Inflation first.
  const registrations: DaemonizedContract[] = [];

  for (const fdc of parameters.flareDaemonizedContracts) {
    if (!quiet) {
      console.error(`Registering ${fdc.contractName} with gas limit ${fdc.gasLimit}`);
    }
    registrations.push({
      daemonizedContract: fdc.oldContract ? oldContracts.getContractAddress(fdc.contractName) : contracts.getContractAddress(fdc.contractName),
      gasLimit: fdc.gasLimit
    });
  }

  await flareDaemon.registerToDaemonize(registrations, { from: genesisGovernanceAccount.address });
}

interface DaemonizedContract {
  daemonizedContract: string;
  gasLimit: number;
}
