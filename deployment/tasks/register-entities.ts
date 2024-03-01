import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "../scripts/Contracts";
import { EntityManagerContract } from "../../typechain-truffle/contracts/protocol/implementation/EntityManager";
import { Entity } from "../utils/Entity";
import { waitFinalize3 } from "../scripts/deploy-utils";

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
    await waitFinalize3(hre, entity.identity.address, () => entityManager.proposeSubmitAddress(entity.submit.address, { from: entity.identity.address }));
    await waitFinalize3(hre, entity.submit.address, () => entityManager.confirmSubmitAddressRegistration(entity.identity.address, { from: entity.submit.address }));
    await waitFinalize3(hre, entity.identity.address, () => entityManager.proposeSubmitSignaturesAddress(entity.submitSignatures.address, { from: entity.identity.address }));
    await waitFinalize3(hre, entity.submitSignatures.address, () => entityManager.confirmSubmitSignaturesAddressRegistration(entity.identity.address, { from: entity.submitSignatures.address }));
    await waitFinalize3(hre, entity.identity.address, () => entityManager.proposeSigningPolicyAddress(entity.signingPolicy.address, { from: entity.identity.address }));
    await waitFinalize3(hre, entity.signingPolicy.address, () => entityManager.confirmSigningPolicyAddressRegistration(entity.identity.address, { from: entity.signingPolicy.address }));
    if (entity.delegation.privateKey) {
      await waitFinalize3(hre, entity.identity.address, () => entityManager.proposeDelegationAddress(entity.delegation.address, { from: entity.identity.address }));
      await waitFinalize3(hre, entity.delegation.address, () => entityManager.confirmDelegationAddressRegistration(entity.identity.address, { from: entity.delegation.address }));
    }
  }
}
