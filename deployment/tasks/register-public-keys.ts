import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "../scripts/Contracts";
import { EntityManagerContract } from "../../typechain-truffle/contracts/protocol/implementation/EntityManager";
import { Entity } from "../utils/Entity";
import { waitFinalize3 } from "../scripts/deploy-utils";
import { ParseSortitionKey, Sign, Signature, SortitionKey } from "../../test/utils/sortition";
import { sha256 } from "ethers";

/**
 * This script will register all entity's public key on entity manager.
 * It assumes that all contracts have been deployed and contract addresses
 * provided in Contracts object.
 * @dev Do not send anything out via console.log unless it is json defining the created contracts.
 */
export async function registerPublicKeys(
  hre: HardhatRuntimeEnvironment,
  contracts: Contracts,
  entities: Entity[],
  quiet: boolean = false) {

  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  if (!quiet) {
    console.error("Public key registration...");
  }

  // Get contract definitions
  const EntityManager: EntityManagerContract = artifacts.require("EntityManager");

  // Fetch EntityManager contract
  const entityManager = await EntityManager.at(contracts.getContractAddress(Contracts.ENTITY_MANAGER));

  for (const entity of entities) {
    const key: SortitionKey = ParseSortitionKey(entity.sortition.privateKey);
    const msg = sha256(web3.utils.encodePacked(entity.identity.address)!);

    const signature: Signature = Sign(key, msg);
    const pkx = "0x" + web3.utils.padLeft(key.pk.x.toString(16), 64);
    const pky = "0x" + web3.utils.padLeft(key.pk.y.toString(16), 64);

    await waitFinalize3(hre, entity.identity.address, () =>
      entityManager.registerPublicKey(
        pkx,
        pky,
        web3.eth.abi.encodeParameters(
          ["uint256", "uint256", "uint256"],
          [signature.s.toString(), signature.r.x.toString(), signature.r.y.toString()]
        ),
        { from: entity.identity.address }
      )
    );
  }
}
