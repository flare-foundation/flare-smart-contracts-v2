import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "../deployment/scripts/Contracts";
import { AddressUpdaterContract } from "../typechain-truffle/flattened/FlareSmartContracts.sol/AddressUpdater";
import axios from "axios";

export async function checkAddressUpdater(hre: HardhatRuntimeEnvironment, contracts: Contracts) {
  interface Contract {
    name: string;
    contractName: string;
    address: string;
  }

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  const AddressUpdater: AddressUpdaterContract = artifacts.require("AddressUpdater");
  const network = hre.network.name;
  const oldContractsPath = `https://gitlab.com/flarenetwork/flare-smart-contracts/-/raw/${network}_network_deployed_code/deployment/deploys/${network}.json`;
  const response = await axios.get(oldContractsPath);
  const oldContracts: Contract[] = response.data;

  // get AddressUpdater address
  const addressUpdaterContract = oldContracts.find((c: Contract) => c.name === "AddressUpdater");
  if (!addressUpdaterContract) throw new Error("AddressUpdater not found");
  const addressUpdater = await AddressUpdater.at(addressUpdaterContract.address);

  // check new contracts
  for (const contract of contracts.allContracts()) {
    if (exclude(contract)) continue;
    const address = await addressUpdater.getContractAddress(contract.name);
    if (address === ZERO_ADDRESS) {
      console.log(`Contract ${contract.name} is not in AddressUpdater`);
    } else if (address !== contract.address) {
      console.log(`Contract ${contract.name} address doesn't match: ${address} !== ${contract.address}`);
    }
  }

  // check old contracts
  for (const contract of oldContracts) {
    if (exclude(contract)) continue;
    const address = await addressUpdater.getContractAddress(contract.name);
    if (address === ZERO_ADDRESS) {
      console.log(`Contract ${contract.name} is not in AddressUpdater`);
    } else if (address !== contract.address) {
      console.log(`Contract ${contract.name} address doesn't match: ${address} !== ${contract.address}`);
    }
  }
}

const excludedContractNames = [
  "FtsoProxy.sol",
  "WNatRegistryProvider.sol",
  "RNatAccount.sol",
  "DelegationAccount.sol",
  "USDTSwapper.sol",
  "SFlrCustomFeed.sol",
];

function exclude(contract: { name: string; contractName: string }): boolean {
  return contract.name.endsWith("Implementation") || excludedContractNames.includes(contract.contractName);
}
