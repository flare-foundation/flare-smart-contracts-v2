import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "../scripts/Contracts";
import { EntityManagerContract } from "../../typechain-truffle/contracts/protocol/implementation/EntityManager";
import { Entity } from "../utils/Entity";

/**
 * This script will register all entity addresses on entity manager.
 * It assumes that all contracts have been deployed and contract addresses
 * provided in Contracts object.
 * @dev Do not send anything out via console.log unless it is json defining the created contracts.
 */
export async function registerEntities(
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
    await entityManager.proposeSubmitAddress(entity.submit.address, { from: entity.identity.address });
    await entityManager.confirmSubmitAddressRegistration(entity.identity.address, { from: entity.submit.address });
    await entityManager.proposeSubmitSignaturesAddress(entity.submitSignatures.address, { from: entity.identity.address });
    await entityManager.confirmSubmitSignaturesAddressRegistration(entity.identity.address, { from: entity.submitSignatures.address });
    await entityManager.proposeSigningPolicyAddress(entity.signingPolicy.address, { from: entity.identity.address });
    await entityManager.confirmSigningPolicyAddressRegistration(entity.identity.address, { from: entity.signingPolicy.address });
    await entityManager.proposeDelegationAddress(entity.delegation.address, { from: entity.identity.address });
    await entityManager.confirmDelegationAddressRegistration(entity.identity.address, { from: entity.delegation.address });
  }
}
