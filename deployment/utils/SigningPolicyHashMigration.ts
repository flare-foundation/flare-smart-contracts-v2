import { ethers } from "ethers";
import { ISigningPolicy, SigningPolicy } from "../../scripts/libs/protocol/SigningPolicy";

const ZERO_HASH = `0x${"00".repeat(32)}`;

/** BN / BigNumber / number — anything whose decimal string is the value. */
interface Numberish {
  toString(): string;
}

/** The chain reads needed to reconstruct a reward epoch's signing policy (truffle instances fit). */
export interface SigningPolicyReconstructionSources {
  oldRelay: {
    toSigningPolicyHash(rewardEpochId: number): Promise<string>;
  };
  flareSystemsManager: {
    getSeed(rewardEpochId: number): Promise<Numberish>;
    getThreshold(rewardEpochId: number): Promise<Numberish>;
  };
  voterRegistry: {
    getRegisteredVotersAndNormalisedWeights(rewardEpochId: number): Promise<{ 0: string[]; 1: Numberish[] }>;
    newSigningPolicyInitializationStartBlockNumber(rewardEpochId: number): Promise<Numberish>;
  };
  entityManager: {
    getSigningPolicyAddresses(voters: string[], blockNumber: Numberish): Promise<string[]>;
  };
}

/**
 * The migration-compatible chained-fold signing-policy content hash: the encoded
 * policy is zero-padded to a multiple of 32 bytes, the first two 32-byte chunks are hashed
 * together, and every further chunk is folded in with keccak256(hash ‖ chunk). Used ONLY to
 * verify that a policy reconstructed from chain state is byte-identical to the source Relay's
 * policy — never to seed the target Relay.
 */
export function legacyPolicyContentHash(encodedPolicy: string): string {
  const data = encodedPolicy.startsWith("0x") ? encodedPolicy.slice(2) : encodedPolicy;
  const chunks = data.match(/.{1,64}/g)!.map((x) => x.padEnd(64, "0"));
  if (chunks.length < 2) {
    throw Error("Encoded signing policy too short");
  }
  let hash = ethers.keccak256("0x" + chunks[0] + chunks[1]);
  for (let i = 2; i < chunks.length; i++) {
    hash = ethers.keccak256("0x" + hash.slice(2) + chunks[i]);
  }
  return hash;
}

/**
 * Reconstructs the full signing policy of a reward epoch from chain state:
 *   1. (identity voters, normalised weights) from VoterRegistry
 *   2. voter identity -> signing-policy address via EntityManager at the policy's registration
 *      snapshot block (checkpointed state, callable any time later)
 *   3. seed / threshold from FlareSystemsManager
 * Mirrors FlareSystemsManager._initializeNextSigningPolicy / VoterRegistry.createSigningPolicySnapshot.
 */
export async function reconstructSigningPolicy(
  sources: SigningPolicyReconstructionSources,
  rewardEpochId: number,
  startVotingRoundId: number
): Promise<ISigningPolicy> {
  const votersAndWeights = await sources.voterRegistry.getRegisteredVotersAndNormalisedWeights(rewardEpochId);
  const identityVoters = votersAndWeights[0];
  const weights = votersAndWeights[1].map((w) => Number(w.toString()));
  const snapshotBlock = await sources.voterRegistry.newSigningPolicyInitializationStartBlockNumber(rewardEpochId);
  if (snapshotBlock.toString() === "0") {
    throw Error(`Signing policy snapshot block not set for reward epoch ${rewardEpochId}`);
  }
  const policyVoters = await sources.entityManager.getSigningPolicyAddresses(identityVoters, snapshotBlock);
  const seed = await sources.flareSystemsManager.getSeed(rewardEpochId);
  const threshold = await sources.flareSystemsManager.getThreshold(rewardEpochId);
  return {
    rewardEpochId,
    startVotingRoundId,
    threshold: Number(threshold.toString()),
    seed: "0x" + BigInt(seed.toString()).toString(16).padStart(64, "0"),
    voters: [...policyVoters],
    weights,
  };
}

/**
 * The initial signing-policy hash for a target Relay, migrated from the source Relay for the given
 * reward epoch.
 *
 * ALWAYS reconstructs and verifies — there is deliberately no scheme parameter and no
 * pass-through branch (a mistaken caller could otherwise seed the target Relay with a hash no
 * policy can satisfy). The full policy is reconstructed from chain state and the source Relay's
 * stored hash must equal one of the two supported hashes of the reconstructed bytes: the
 * chained-fold migration format or the source-bound single-keccak format. Either way the
 * reconstruction is proven byte-exact against the source contract, and the returned value is
 * the source-bound single-keccak hash,
 * keccak256(sourceChainId ‖ encoded policy).
 */
export async function signingPolicyHashForMigration(
  sources: SigningPolicyReconstructionSources,
  rewardEpochId: number,
  startVotingRoundId: number,
  chainId: number | bigint
): Promise<string> {
  const oldHash = await sources.oldRelay.toSigningPolicyHash(rewardEpochId);
  if (!/^0x[0-9a-fA-F]{64}$/.test(oldHash) || oldHash.toLowerCase() === ZERO_HASH) {
    throw Error(`Invalid old Relay signing policy hash: ${oldHash}`);
  }
  const policy = await reconstructSigningPolicy(sources, rewardEpochId, startVotingRoundId);
  const encoded = SigningPolicy.encode(policy);
  // Byte-exact reconstruction proof against the source Relay before seeding the target.
  const newHash = SigningPolicy.hashEncoded(encoded, chainId);
  const storedHash = oldHash.toLowerCase();
  if (storedHash !== legacyPolicyContentHash(encoded) && storedHash !== newHash.toLowerCase()) {
    throw Error(
      `Old Relay's stored policy hash (${oldHash}) for reward epoch ${rewardEpochId} matches ` +
        `neither hash of the reconstructed signing policy`
    );
  }
  return newHash;
}
