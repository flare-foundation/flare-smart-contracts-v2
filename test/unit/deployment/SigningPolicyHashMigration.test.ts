import { expect } from "chai";
import { ethers } from "ethers";
import {
  legacyPolicyContentHash,
  reconstructSigningPolicy,
  signingPolicyHashForMigration,
  SigningPolicyReconstructionSources,
} from "../../../deployment/utils/SigningPolicyHashMigration";
import { ISigningPolicy, SigningPolicy } from "../../../scripts/libs/protocol/SigningPolicy";

describe("SigningPolicyHashMigration", () => {
  const chainId = 14;
  const rewardEpochId = 101;
  const startVotingRoundId = 343360;
  const snapshotBlock = 123456;

  const identityVoters = ["0x" + "10".repeat(20), "0x" + "11".repeat(20)];
  const policyVoters = ["0x" + "20".repeat(20), "0x" + "21".repeat(20)];
  const weights = [300, 300];
  const threshold = 330;
  const seed = ethers.keccak256(ethers.toUtf8Bytes("policy-seed"));

  const policy: ISigningPolicy = {
    rewardEpochId,
    startVotingRoundId,
    threshold,
    seed,
    voters: policyVoters,
    weights,
  };
  const encoded = SigningPolicy.encode(policy);

  function sources(storedHash: string): SigningPolicyReconstructionSources {
    return {
      oldRelay: {
        toSigningPolicyHash: async () => storedHash,
      },
      flareSystemsManager: {
        getSeed: async () => BigInt(seed),
        getThreshold: async () => threshold,
      },
      voterRegistry: {
        getRegisteredVotersAndNormalisedWeights: async () => ({ 0: identityVoters, 1: weights }),
        newSigningPolicyInitializationStartBlockNumber: async () => snapshotBlock,
      },
      entityManager: {
        getSigningPolicyAddresses: async (voters, blockNumber) => {
          expect(voters).to.deep.equal(identityVoters);
          expect(Number(blockNumber.toString())).to.equal(snapshotBlock);
          return policyVoters;
        },
      },
    };
  }

  it("computes the retired chained fold (zero-padded 32-byte chunks)", () => {
    // 43 + 2*22 = 87 bytes -> 3 chunks, the last zero-padded on the right.
    const data = encoded.slice(2);
    const chunks = data.match(/.{1,64}/g)!.map((x) => x.padEnd(64, "0"));
    let expected = ethers.keccak256("0x" + chunks[0] + chunks[1]);
    for (let i = 2; i < chunks.length; i++) {
      expected = ethers.keccak256("0x" + expected.slice(2) + chunks[i]);
    }
    expect(legacyPolicyContentHash(encoded)).to.equal(expected);
  });

  it("reconstructs the signing policy from the chain reads", async () => {
    const reconstructed = await reconstructSigningPolicy(sources(ethers.ZeroHash), rewardEpochId, startVotingRoundId);
    expect(SigningPolicy.encode(reconstructed)).to.equal(encoded);
  });

  it("legacy stored hash: verifies the reconstruction and re-hashes under the single-keccak scheme", async () => {
    const result = await signingPolicyHashForMigration(
      sources(legacyPolicyContentHash(encoded)),
      rewardEpochId,
      startVotingRoundId,
      chainId
    );
    expect(result).to.equal(SigningPolicy.hashEncoded(encoded, chainId));
    expect(result).to.equal(ethers.keccak256(ethers.solidityPacked(["uint256", "bytes"], [chainId, encoded])));
  });

  it("new-scheme stored hash: still reconstructs and verifies (no pass-through branch)", async () => {
    const stored = SigningPolicy.hashEncoded(encoded, chainId);
    const result = await signingPolicyHashForMigration(sources(stored), rewardEpochId, startVotingRoundId, chainId);
    expect(result).to.equal(stored);
  });

  it("fails closed when the stored hash matches neither hash of the reconstruction", async () => {
    const wrong = ethers.keccak256(ethers.toUtf8Bytes("not the reconstructed policy"));
    await expect(
      signingPolicyHashForMigration(sources(wrong), rewardEpochId, startVotingRoundId, chainId)
    ).to.be.rejectedWith("matches neither hash of the reconstructed signing policy");
  });

  it("rejects zero and malformed stored hashes", async () => {
    await expect(
      signingPolicyHashForMigration(sources(ethers.ZeroHash), rewardEpochId, startVotingRoundId, chainId)
    ).to.be.rejectedWith("Invalid old Relay signing policy hash");
    await expect(
      signingPolicyHashForMigration(sources("0x12"), rewardEpochId, startVotingRoundId, chainId)
    ).to.be.rejectedWith("Invalid old Relay signing policy hash");
  });
});
