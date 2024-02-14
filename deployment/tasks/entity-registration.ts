import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "../scripts/Contracts";
import { EntityManagerContract } from "../../typechain-truffle/contracts/protocol/implementation/EntityManager";
import { Entity } from "../utils/Entity";

/**
 * This script will register all addresses on entity manager.
 * It assumes that all contracts have been deployed and contract addresses
 * provided in Contracts object.
 * @dev Do not send anything out via console.log unless it is json defining the created contracts.
 */
export async function entityRegistration(
  hre: HardhatRuntimeEnvironment,
  contracts: Contracts,
  entities: Entity[],
  quiet: boolean = false) {

  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  if (!quiet) {
    console.error("Entity registration...");
  }

  // Get contract definitions
  const EntityManager: EntityManagerContract = artifacts.require("EntityManager");

  // Fetch EntityManager contract
  const entityManager = await EntityManager.at(contracts.getContractAddress(Contracts.ENTITY_MANAGER));

  for (const entity of entities) {
    const identityAddress = web3.eth.accounts.privateKeyToAccount(entity.identity.privateKey).address;
    const submitAddress = web3.eth.accounts.privateKeyToAccount(entity.submit.privateKey).address;
    await entityManager.proposeSubmitAddress(submitAddress, { from: identityAddress });
    await entityManager.confirmSubmitAddressRegistration(identityAddress, { from: submitAddress });
    const submitSignaturesAddress = web3.eth.accounts.privateKeyToAccount(entity.submitSignatures.privateKey).address;
    await entityManager.proposeSubmitSignaturesAddress(submitSignaturesAddress, { from: identityAddress });
    await entityManager.confirmSubmitSignaturesAddressRegistration(identityAddress, { from: submitSignaturesAddress });
    const signingPolicyAddress = web3.eth.accounts.privateKeyToAccount(entity.signingPolicy.privateKey).address;
    await entityManager.proposeSigningPolicyAddress(signingPolicyAddress, { from: identityAddress });
    await entityManager.confirmSigningPolicyAddressRegistration(identityAddress, { from: signingPolicyAddress });
    const delegationAddress = web3.eth.accounts.privateKeyToAccount(entity.delegation.privateKey).address;
    await entityManager.proposeDelegationAddress(delegationAddress, { from: identityAddress });
    await entityManager.confirmDelegationAddressRegistration(identityAddress, { from: delegationAddress });
  }
}
