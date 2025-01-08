/**
 * This script will deploy FdcHub contract using real FlareSystemManager contract and mock contracts for the rest.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contracts } from "./Contracts";
import { FdcHubContract } from "../../typechain-truffle/contracts/fdc/implementation/FdcHub";
import { FdcInflationConfigurationsContract } from "../../typechain-truffle/contracts/fdc/implementation/FdcInflationConfigurations";
import { FdcRequestFeeConfigurationsContract } from "../../typechain-truffle/contracts/fdc/implementation/FdcRequestFeeConfigurations";
import { spewNewContractInfo } from "./deploy-utils";
import { FdcVerificationContract } from "../../typechain-truffle/contracts/fdc/implementation/FdcVerification";

export async function deployFdcContracts(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  const FdcHub: FdcHubContract = artifacts.require("FdcHub");
  const FdcInflationConfigurations: FdcInflationConfigurationsContract = artifacts.require("FdcInflationConfigurations");
  const FdcRequestFeeConfigurations: FdcRequestFeeConfigurationsContract = artifacts.require("FdcRequestFeeConfigurations");
  const FdcVerification: FdcVerificationContract = artifacts.require("FdcVerification");

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
  const relay = contracts.getContractAddress(Contracts.RELAY);

  // deploy contracts
  const fdcHub = await FdcHub.new(governanceSettings, deployerAccount.address, deployerAccount.address, parameters.fdcRequestsOffsetSeconds);
  spewNewContractInfo(contracts, null, FdcHub.contractName, `FdcHub.sol`, fdcHub.address, quiet);
  const fdcInflationConfigurations = await FdcInflationConfigurations.new(governanceSettings, deployerAccount.address, deployerAccount.address);
  spewNewContractInfo(contracts, null, FdcInflationConfigurations.contractName, `FdcInflationConfigurations.sol`, fdcInflationConfigurations.address, quiet);
  const fdcRequestFeeConfigurations = await FdcRequestFeeConfigurations.new(governanceSettings, deployerAccount.address);
  spewNewContractInfo(contracts, null, FdcRequestFeeConfigurations.contractName, `FdcRequestFeeConfigurations.sol`, fdcRequestFeeConfigurations.address, quiet);
  const fdcVerification = await FdcVerification.new(deployerAccount.address, parameters.fdcProtocolId);
  spewNewContractInfo(contracts, null, FdcVerification.contractName, `FdcVerification.sol`, fdcVerification.address, quiet);

  // update contract addresses
  await fdcHub.updateContractAddresses(
    encodeContractNames([
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.REWARD_MANAGER,
      Contracts.INFLATION,
      Contracts.FDC_INFLATION_CONFIGURATIONS,
      Contracts.FDC_REQUEST_FEE_CONFIGURATIONS
    ]),
    [
      addressUpdater,
      contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER),
      contracts.getContractAddress(Contracts.REWARD_MANAGER),
      oldContracts.getContractAddress(Contracts.INFLATION),
      fdcInflationConfigurations.address,
      fdcRequestFeeConfigurations.address
    ]);

  await fdcInflationConfigurations.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FDC_REQUEST_FEE_CONFIGURATIONS]),
    [addressUpdater, fdcRequestFeeConfigurations.address]);

  await fdcVerification.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.RELAY]),
    [addressUpdater, relay]);

  // set fdc request fee configurations
  for (const fdcRequestFee of parameters.fdcRequestFees) {
    await fdcRequestFeeConfigurations.setTypeAndSourceFee(
      web3.utils.utf8ToHex(fdcRequestFee.attestationType).padEnd(66, "0"),
      web3.utils.utf8ToHex(fdcRequestFee.source).padEnd(66, "0"),
      fdcRequestFee.feeWei
    );
  }

  // set fdc inflation configurations
  const fdcConfigurations = [];
  for (const fdcInflationConfiguration of parameters.fdcInflationConfigurations) {
    const configuration = {
      attestationType: web3.utils.utf8ToHex(fdcInflationConfiguration.attestationType).padEnd(66, "0"),
      source: web3.utils.utf8ToHex(fdcInflationConfiguration.source).padEnd(66, "0"),
      inflationShare: fdcInflationConfiguration.inflationShare,
      minRequestsThreshold: fdcInflationConfiguration.minRequestsThreshold,
      mode: fdcInflationConfiguration.mode,
    };
    fdcConfigurations.push(configuration);
  }
  await fdcInflationConfigurations.addFdcConfigurations(fdcConfigurations);

  // switch to production mode
  await fdcHub.switchToProductionMode();
  await fdcInflationConfigurations.switchToProductionMode();
  await fdcRequestFeeConfigurations.switchToProductionMode();

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
