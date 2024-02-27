import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "../scripts/Contracts";
import { WNatContract } from "../../typechain-truffle/flattened/FlareSmartContracts.sol/WNat";
import { Entity } from "../utils/Entity";
import { waitFinalize3 } from "../scripts/deploy-utils";

/**
 * This script will transfer funds from deployer account to provided accounts and wrap them.
 * It assumes that all contracts have been deployed and contract addresses
 * provided in Contracts object.
 * @dev Do not send anything out via console.log unless it is json defining the created contracts.
 */
export async function transferAndWrapFunds(
  hre: HardhatRuntimeEnvironment,
  privateKeyWithFunds: string,
  contracts: Contracts,
  entities: Entity[],
  quiet: boolean = false) {

  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  if (!quiet) {
    console.error("Transferring and wrapping funds...");
  }

  let accountWithFunds: any;

  // Get default account
  try {
    accountWithFunds = web3.eth.accounts.privateKeyToAccount(privateKeyWithFunds);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e)
  }

  // Wire up the default account that will send the transactions
  web3.eth.defaultAccount = accountWithFunds.address;

  // Get contract definitions
  const WNat: WNatContract = artifacts.require("WNat");

  // Fetch WNat contract
  const wNat = await WNat.at(contracts.getContractAddress(Contracts.WNAT));

  const funds = web3.utils.toWei("1000");
  for (const entity of entities) {
    await waitFinalize3(hre, accountWithFunds.address, () => web3.eth.sendTransaction({ from: accountWithFunds.address, to: entity.identity.address, value: funds }));
    await waitFinalize3(hre, accountWithFunds.address, () => web3.eth.sendTransaction({ from: accountWithFunds.address, to: entity.submit.address, value: funds }));
    await waitFinalize3(hre, accountWithFunds.address, () => web3.eth.sendTransaction({ from: accountWithFunds.address, to: entity.submitSignatures.address, value: funds }));
    await waitFinalize3(hre, accountWithFunds.address, () => web3.eth.sendTransaction({ from: accountWithFunds.address, to: entity.signingPolicy.address, value: funds }));
    await waitFinalize3(hre, accountWithFunds.address, () => web3.eth.sendTransaction({ from: accountWithFunds.address, to: entity.delegation.address, value: funds }));
    await waitFinalize3(hre, accountWithFunds.address, () => wNat.depositTo(entity.delegation.address, { value: entity.wrapped, from: accountWithFunds.address}));
  }
}
