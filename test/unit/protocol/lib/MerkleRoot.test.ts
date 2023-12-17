import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { artifacts, contract, ethers } from "hardhat";
import { MerkleTree, verifyWithMerkleProof } from "../../../../scripts/libs/merkle/MerkleTree";
import { MerkleTreeMockInstance } from "../../../../typechain-truffle/contracts/mock/MerkleTreeMock";
import { getTestFile } from "../../../utils/constants";
import { MerkleRootInstance } from "../../../../typechain-truffle/contracts/protocol/lib/MerkleRoot";
import { expectRevert } from "@openzeppelin/test-helpers";
const MerkleTreeMock = artifacts.require("MerkleTreeMock");

contract(`MerkleRoot.sol; ${getTestFile(__filename)}`, async () => {
  // let accounts: Account[];
  // let signers: SignerWithAddress[];

  const makeHashes = (i: number, shiftSeed = 0) => new Array(i).fill(0).map((x, i) => ethers.keccak256(ethers.toBeHex(shiftSeed + i)));


  let merkleTreeMock: MerkleTreeMockInstance;
  let merkleRoot: MerkleRootInstance;

  before(async () => {
    // accounts = loadAccounts(web3);
    // signers = (await ethers.getSigners()) as unknown as SignerWithAddress[];
    merkleTreeMock = await MerkleTreeMock.new();
  });

  it("Should revert if no leaves", async () => {
    // "Must have at least one leaf"
    await expectRevert(merkleTreeMock.merkleRootWithSpecificProof([], -1), "Must have at least one leaf");
  });

  it("Should revert index too big", async () => {
    // "Index too big"
    const n = 10;
    const hashes = makeHashes(n);    
    await expectRevert(merkleTreeMock.merkleRootWithSpecificProof(hashes, n), "Index too big");
  });

  
  it("Generate the same Merkle root as TS library", async () => {
    const n = 11;  // Takes long time if bigger number
    for (let len = 1; len < n; len++) {
      const hashes = makeHashes(n);
      const tree = new MerkleTree(hashes, false);
      for (let i = 0; i < tree.hashCount; i++) {
        const proof = tree.getProof(i);
        let result = await merkleTreeMock.merkleRootWithSpecificProof(hashes, i);

        expect(result[0]).to.equal(tree.root);
        const contractMerkleRoot = result[1];
        expect(contractMerkleRoot.length).to.equal(proof!.length);
        for (let j = 0; j < contractMerkleRoot.length; j++) {
          expect(contractMerkleRoot[j]).to.equal(proof![j]);
        }
      }
    }
  });
});
