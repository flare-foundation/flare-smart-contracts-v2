
import { expectRevert } from '@openzeppelin/test-helpers';
import { getTestFile } from "../../../utils/constants";
import { EntityManagerInstance } from '../../../../typechain-truffle/contracts/protocol/implementation/EntityManager';

const EntityManager = artifacts.require("EntityManager");

contract(`EntityManager.sol; ${getTestFile(__filename)}`, async accounts => {

  let entityManager: EntityManagerInstance;

  beforeEach(async () => {
    entityManager = await EntityManager.new(accounts[0], accounts[1], 4);
  });

  it("Should set node id", async () => {
    let block = await web3.eth.getBlockNumber();
    expect((await entityManager.getNodeIdsOfAt(accounts[1], block)).length).to.equals(0);

    let nodeId1 = "0x1234567890123456789012345678901234567890"
    await entityManager.registerNodeId(nodeId1, { from: accounts[1] });
    let nodeIds = await entityManager.getNodeIdsOfAt(accounts[1], block + 1)
    expect(nodeIds.length).to.equals(1);
    expect(nodeIds[0]).to.equals(nodeId1);

    let register = entityManager.registerNodeId(nodeId1, { from: accounts[1] });
    await expectRevert(register, "node id already registered");
  });

});
