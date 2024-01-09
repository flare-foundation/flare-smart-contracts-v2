

import { ethers } from "ethers";

export interface ISigningPolicy {
  rewardEpochId: number;
  startVotingRoundId: number;
  threshold: number;
  seed: string;
  voters: string[];
  weights: number[];
}

export namespace SigningPolicy {

  //////////////////////////////////////////////////////////////////////////////
  // Signing policy byte encoding structure
  // 2 bytes - size
  // 3 bytes - rewardEpochId
  // 4 bytes - startingVotingRoundId
  // 2 bytes - threshold
  // 32 bytes - randomSeed
  // array of 'size':
  // - 20 bytes address
  // - 2 bytes weight
  // Total 43 + size * (20 + 2) bytes
  //////////////////////////////////////////////////////////////////////////////
  /**
   * Encodes signing policy into 0x-prefixed hex string representing byte encoding
   * @param policy
   * @returns
   */
  export function encode(policy: ISigningPolicy) {
    if (!policy) {
      throw Error("Signing policy is undefined");
    }
    if (!policy.voters || !policy.weights) {
      throw Error("Invalid signing policy");
    }
    if (policy.voters.length !== policy.weights.length) throw Error("Invalid signing policy");
    let signersAndWeights = "";
    const size = policy.voters.length;
    if (size > 2 ** 16 - 1) {
      throw Error("Too many signers");
    }
    for (let i = 0; i < size; i++) {
      signersAndWeights += policy.voters[i].slice(2) + policy.weights[i].toString(16).padStart(4, "0");
    }
    if (!/^0x[0-9a-f]{64}$/i.test(policy.seed)) {
      throw Error(`Invalid random seed format: ${policy.seed}`);
    }

    if (policy.rewardEpochId < 0 || policy.rewardEpochId > 2 ** 24 - 1) {
      throw Error(`Reward epoch id out of range: ${policy.rewardEpochId}`);
    }
    if (policy.startVotingRoundId < 0 || policy.startVotingRoundId > 2 ** 32 - 1) {
      throw Error(`Starting voting round id out of range: ${policy.startVotingRoundId}`);
    }
    if (policy.threshold < 0 || policy.threshold > 2 ** 16 - 1) {
      throw Error(`Threshold out of range: ${policy.threshold}`);
    }
    return (
      "0x" +
      size.toString(16).padStart(4, "0") +
      policy.rewardEpochId.toString(16).padStart(6, "0") +
      policy.startVotingRoundId.toString(16).padStart(8, "0") +
      policy.threshold.toString(16).padStart(4, "0") +
      policy.seed.slice(2) +
      signersAndWeights
    ).toLowerCase();
  }

  /**
   * Decodes signing policy from hex string (can be 0x-prefixed or not).
   * @param encodedPolicy
   * @returns
   */
  export function decode(encodedPolicy: string): ISigningPolicy {
    const encodedPolicyInternal = (encodedPolicy.startsWith("0x") ? encodedPolicy.slice(2) : encodedPolicy).toLowerCase();
    if (!/^[0-9a-f]*$/.test(encodedPolicyInternal)) {
      throw Error(`Invalid format - not hex string: ${encodedPolicy}`);
    }
    if (encodedPolicyInternal.length % 2 !== 0) {
      throw Error(`Invalid format - not even length: ${encodedPolicy.length}`);
    }
    if (encodedPolicyInternal.length < 4) {
      throw Error("Too short encoded signing policy");
    }
    const size = parseInt(encodedPolicyInternal.slice(0, 4), 16);
    const expectedLength = 86 + size * (20 + 2) * 2; //(2 + 3 + 4 + 2 + 32) * 2 = 86
    if (encodedPolicyInternal.length !== expectedLength) {
      throw Error(`Invalid encoded signing policy length: size = ${size}, length = ${encodedPolicyInternal.length}`);
    }
    const rewardEpochId = parseInt(encodedPolicyInternal.slice(4, 10), 16);
    const startingVotingRoundId = parseInt(encodedPolicyInternal.slice(10, 18), 16);
    const threshold = parseInt(encodedPolicyInternal.slice(18, 22), 16);
    const randomSeed = "0x" + encodedPolicyInternal.slice(22, 86);
    const signers: string[] = [];
    const weights: number[] = [];
    let totalWeight = 0;
    for (let i = 0; i < size; i++) {
      const start = 86 + i * 44; // 20 (address) + 2 (weight) = 44
      signers.push("0x" + encodedPolicyInternal.slice(start, start + 40));
      const weight = parseInt(encodedPolicyInternal.slice(start + 40, start + 44), 16);
      weights.push(weight);
      totalWeight += weight;
    }
    if (totalWeight > 2 ** 16 - 1) {
      throw Error(`Total weight exceeds 16-byte value: ${totalWeight}`);
    }
    return {
      rewardEpochId,
      startVotingRoundId: startingVotingRoundId,
      threshold,
      seed: randomSeed,
      voters: signers,
      weights,
    };
  }

  /**
   * Calculates signing policy hash from encoded signing policy
   * It is done by padding byte array with 0 bytes to a multiple of 32 and then
   * Sequentially hashing 32-byte chunks with keccak256
   * @param signingPolicy
   * @returns
   */
  export function hashEncoded(signingPolicy: string) {
    const signingPolicyInternal = signingPolicy.startsWith("0x") ? signingPolicy.slice(2) : signingPolicy;
    const splitted = signingPolicyInternal.match(/.{1,64}/g)!.map(x => x.padEnd(64, "0"))!;
    let hash: string = ethers.keccak256("0x" + splitted[0] + splitted[1])!;
    for (let i = 2; i < splitted!.length; i++) {
      hash = ethers.keccak256("0x" + hash.slice(2) + splitted[i])!;
    }
    return hash;
  }

  export function hash(signingPolicy: ISigningPolicy) {
    return SigningPolicy.hashEncoded(SigningPolicy.encode(signingPolicy));
  }

}
