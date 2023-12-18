import { assert, expect } from "chai";
import { ethers } from "ethers";
import { MerkleTree, commitHash, merkleRootAndProofFromLeaves, verifyWithMerkleProof } from "../../scripts/libs/merkle/MerkleTree";

describe(`Merkle Tree`, () => {
    const makeHashes = (i: number, shiftSeed = 0) => new Array(i).fill(0).map((x, i) => ethers.keccak256(ethers.toBeHex(shiftSeed + i)));

    describe("General functionalities", () => {
        it("Should be able to create empty tree form empty array", () => {
            const tree = new MerkleTree([]);
            assert(tree.hashCount === 0);
            assert(tree.root === undefined);
            assert(tree.sortedHashes.length === 0);
            assert(tree.tree.length === 0);
            assert(tree.getHash(1) === undefined);
            assert(tree.getProof(1) === undefined);
        });

        it("Should tree for n hashes have 2*n - 1 nodes", () => {
            for (let i = 1; i < 10; i++) {
                const hashes = makeHashes(i);
                const tree = new MerkleTree(hashes);
                assert(tree.tree.length === 2 * i - 1);
                assert(tree.hashCount === i);
            }
        });

        it("Should leaves match to initial hashes", () => {
            for (let i = 1; i < 10; i++) {
                const hashes = makeHashes(i);
                const tree = new MerkleTree(hashes);
                const sortedHashes = tree.sortedHashes;
                for (let j = 0; j < i; j++) {
                    assert(sortedHashes.indexOf(hashes[j]) >= 0);
                }
            }
        });

        it("Should omit duplicates", () => {
            const tree = new MerkleTree(["0x11", "0x11", "0x22"].map((x) => ethers.zeroPadBytes(x, 32)));
            assert(tree.tree.length === 3);
        });


        it("Should merkle proof work for up to 10 hashes", () => {
            for (let i = 95; i < 100; i++) {
                const hashes = makeHashes(i);
                const tree = new MerkleTree(hashes);
                for (let j = 0; j < tree.hashCount; j++) {
                    const leaf = tree.getHash(j);
                    const proof = tree.getProof(j);
                    const ver = verifyWithMerkleProof(leaf!, proof!, tree.root!);
                    expect(ver).to.be.eq(true);
                }
            }
        });

        it("Should merkle proof work for up to 10 hashes without sorting and deduplication", () => {
            for (let i = 95; i < 100; i++) {
                let hashes = makeHashes(Math.floor(i / 2));
                hashes = [...hashes, ...hashes];
                if (i % 2 === 1) {
                    hashes.push(hashes[0]);
                }
                const tree = new MerkleTree(hashes, false);
                expect(tree.sortedHashes.length).to.be.eq(hashes.length);
                for (let j = 0; j < tree.hashCount; j++) {
                    const leaf = tree.getHash(j);
                    const proof = tree.getProof(j);
                    const ver = verifyWithMerkleProof(leaf!, proof!, tree.root!);
                    expect(ver).to.be.eq(true);
                }
            }
        });


        it("Should reject insufficient data", () => {
            for (let i = 95; i < 100; i++) {
                const hashes = makeHashes(i);
                const tree = new MerkleTree(hashes);
                assert(!verifyWithMerkleProof(tree.getHash(i)!, [], tree.root!));
                assert(!verifyWithMerkleProof("", tree.getProof(i)!, tree.root!));
                assert(!verifyWithMerkleProof(tree.getHash(i)!, tree.getProof(i)!, ""));
            }
        });

        it("Should reject false proof", () => {
            for (let i = 95; i < 100; i++) {
                const hashes1 = makeHashes(i);
                const hashes2 = makeHashes(i, 1000);
                const tree1 = new MerkleTree(hashes1);
                const tree2 = new MerkleTree(hashes2);
                for (let j = 0; j < i; j++) {
                    expect(verifyWithMerkleProof(tree1.getHash(j)!, tree1.getProof(j)!, tree1.root!)).to.be.true;
                    expect(verifyWithMerkleProof(tree1.getHash(j)!, tree2.getProof(j)!, tree1.root!)).to.be.false;
                    assert(!verifyWithMerkleProof(tree1.getHash(j)!, tree1.getProof(j)!, tree2.root!));
                }
            }
        });

        it("Should prepare commit hash", () => {
            const merkleRoot = new MerkleTree(makeHashes(55)).root!;
            const address = "0x780023EE3B120dc5bDd21422eAfe691D9f37818D";
            const randomNum = ethers.zeroPadValue(ethers.toBeArray(1289), 32);
            assert(commitHash(merkleRoot, randomNum, address).slice(0, 2) === "0x");
        });
    });
    
    describe("Roots and proof from the leaves", () => {
        it("Should calculate Merkle roots and proofs from the list", () => {
            const n = 17;  // Takes long time if bigger number
            for (let len = 1; len < n; len++) {
                const hashes = makeHashes(n);
                const tree = new MerkleTree(hashes, false);
                for (let i = 0; i < tree.hashCount; i++) {
                    const proof = tree.getProof(i);
                    let result = merkleRootAndProofFromLeaves(hashes, i);

                    expect(result[0]).to.equal(tree.root);
                    const merkleProof = result[1]!;
                    expect(merkleProof.length).to.equal(proof!.length);
                    for (let j = 0; j < merkleProof.length; j++) {
                        expect(merkleProof[j]).to.equal(proof![j]);
                    }
                }
            }
        });
    });


});






