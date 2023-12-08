 import { ethers } from "ethers";

//////////////////////////////////////////////////////////////////////////////
// Interfaces
//////////////////////////////////////////////////////////////////////////////

export interface SigningPolicy {
  rewardEpochId: number;
  startingVotingRoundId: number;
  threshold: number;
  randomSeed: string;
  signers: string[];
  weights: number[];
}

export interface ECDSASignatureWithIndex {
  r: string;
  s: string;
  v: number;
  index: number;
}

export interface ProtocolMessageMerkleRoot {
  protocolId: number;
  votingRoundId: number;
  randomQualityScore: boolean;
  merkleRoot: string;
}

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
 * Encodes signing policy into hex string without 0x prefix representing byte encoding
 * @param policy
 * @returns
 */
export function encodeSigningPolicy(policy: SigningPolicy) {
  if (!policy) {
    throw Error("Signing policy is undefined");
  }
  if (!policy.signers || !policy.weights) {
    throw Error("Invalid signing policy");
  }
  if (policy.signers.length !== policy.weights.length) throw Error("Invalid signing policy");
  let signersAndWeights = "";
  const size = policy.signers.length;
  if (size > 2 ** 16 - 1) {
    throw Error("Too many signers");
  }
  for (let i = 0; i < size; i++) {
    signersAndWeights += policy.signers[i].slice(2) + policy.weights[i].toString(16).padStart(4, "0");
  }
  if (!/^0x[0-9a-f]{64}$/i.test(policy.randomSeed)) {
    throw Error(`Invalid random seed format: ${policy.randomSeed}`);
  }
  if (policy.rewardEpochId < 0 || policy.rewardEpochId > 2 ** 24 - 1) {
    throw Error(`Reward epoch id out of range: ${policy.rewardEpochId}`);
  }
  if (policy.startingVotingRoundId < 0 || policy.startingVotingRoundId > 2 ** 32 - 1) {
    throw Error(`Starting voting round id out of range: ${policy.startingVotingRoundId}`);
  }
  if (policy.threshold < 0 || policy.threshold > 2 ** 16 - 1) {
    throw Error(`Threshold out of range: ${policy.threshold}`);
  }
  return (
    "0x" +
    size.toString(16).padStart(4, "0") +
    policy.rewardEpochId.toString(16).padStart(6, "0") +
    policy.startingVotingRoundId.toString(16).padStart(8, "0") +
    policy.threshold.toString(16).padStart(4, "0") +
    policy.randomSeed.slice(2) +
    signersAndWeights
  ).toLowerCase();
}

/**
 * Decodes signing policy from hex string (can be 0x-prefixed or not).
 * @param encodedPolicy
 * @returns
 */
export function decodeSigningPolicy(encodedPolicy: string): SigningPolicy {
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
    startingVotingRoundId,
    threshold,
    randomSeed,
    signers,
    weights,
  };
}

//////////////////////////////////////////////////////////////////////////////
// Signature with index structure
// 1 byte - v
// 32 bytes - r
// 32 bytes - s
// 2 byte - index in signing policy
// Total 67 bytes
//////////////////////////////////////////////////////////////////////////////

/**
 * Encodes ECDSA signature with index into hex string without 0x prefix representing byte encoding
 * @param signature
 * @returns
 */
export function encodeECDSASignatureWithIndex(signature: ECDSASignatureWithIndex): string {
  return (
    "0x" +
    signature.v.toString(16).padStart(2, "0") +
    signature.r.slice(2) +
    signature.s.slice(2) +
    signature.index.toString(16).padStart(4, "0")
  );
}

/**
 * Decodes ECDSA signature with index from hex string (can be 0x-prefixed or not).
 * @param encodedSignature
 * @returns
 */
export function decodeECDSASignatureWithIndex(encodedSignature: string): ECDSASignatureWithIndex {
  const encodedSignatureInternal = (
    encodedSignature.startsWith("0x") ? encodedSignature.slice(2) : encodedSignature
  ).toLowerCase();
  if (!/^[0-9a-f]*$/.test(encodedSignatureInternal)) {
    throw Error(`Invalid format - not hex string: ${encodedSignature}`);
  }
  if (encodedSignatureInternal.length !== 134) {
    // (1 + 32 + 32 + 2) * 2 = 134
    throw Error(`Invalid encoded signature length: ${encodedSignatureInternal.length}`);
  }
  const v = parseInt(encodedSignatureInternal.slice(0, 2), 16);
  const r = "0x" + encodedSignatureInternal.slice(2, 66);
  const s = "0x" + encodedSignatureInternal.slice(66, 130);
  const index = parseInt(encodedSignatureInternal.slice(130, 134), 16);
  return {
    v,
    r,
    s,
    index,
  };
}

//////////////////////////////////////////////////////////////////////////////
// Protocol message merkle root structure
// 1 byte - protocolId
// 4 bytes - votingRoundId
// 1 byte - randomQualityScore
// 32 bytes - merkleRoot
// Total 38 bytes
//////////////////////////////////////////////////////////////////////////////

/**
 *
 * @param message
 * @returns
 */
export function encodeProtocolMessageMerkleRoot(message: ProtocolMessageMerkleRoot): string {
  if (!message) {
    throw Error("Signed message is undefined");
  }
  if (!message.merkleRoot) {
    throw Error("Invalid signed message");
  }
  if (!/^0x[0-9a-f]{64}$/i.test(message.merkleRoot)) {
    throw Error(`Invalid merkle root format: ${message.merkleRoot}`);
  }
  if (message.protocolId < 0 || message.protocolId > 2 ** 8 - 1) {
    throw Error(`Protocol id out of range: ${message.protocolId}`);
  }
  if (message.votingRoundId < 0 || message.votingRoundId > 2 ** 32 - 1) {
    throw Error(`Voting round id out of range: ${message.votingRoundId}`);
  }
  return (
    "0x" +
    message.protocolId.toString(16).padStart(2, "0") +
    message.votingRoundId.toString(16).padStart(8, "0") +
    (message.randomQualityScore ? 1 : 0).toString(16).padStart(2, "0") +
    message.merkleRoot.slice(2)
  ).toLowerCase();
}

/**
 * Decodes signed message from hex string (can be 0x-prefixed or not).
 * @param encodedMessage
 * @returns
 */
export function decodeProtocolMessageMerkleRoot(encodedMessage: string): ProtocolMessageMerkleRoot {
  const encodedMessageInternal = encodedMessage.startsWith("0x") ? encodedMessage.slice(2) : encodedMessage;
  // (1 + 4 + 1 + 32) * 2 = 38 * 2 = 76
  if (!/^[0-9a-f]{76}$/.test(encodedMessageInternal)) {
    throw Error(`Invalid format - not hex string: ${encodedMessage}`);
  }
  const protocolId = parseInt(encodedMessageInternal.slice(0, 2), 16);
  const votingRoundId = parseInt(encodedMessageInternal.slice(2, 10), 16);
  const encodedRandomQualityScore = encodedMessageInternal.slice(10, 12);
  let randomQualityScore = false;
  if (encodedRandomQualityScore === "00") {
    randomQualityScore = false;
  } else if (encodedRandomQualityScore === "01") {
    randomQualityScore = true;
  } else {
    throw Error("Invalid random quality score");
  }
  const merkleRoot = "0x" + encodedMessageInternal.slice(12, 76);
  return {
    protocolId,
    votingRoundId,
    randomQualityScore,
    merkleRoot,
  };
}

//////////////////////////////////////////////////////////////////////////////
// Signing policy hash calculation
// It is done by padding byte array with 0 bytes to a multiple of 32 and then
// Sequentially hashing 32-byte chunks with soliditySha3
//////////////////////////////////////////////////////////////////////////////

/**
 * Calculates signing policy hash from encoded signing policy
 * @param signingPolicy
 * @returns
 */
export function signingPolicyHash(signingPolicy: string) {
  const signingPolicyInternal = signingPolicy.startsWith("0x") ? signingPolicy.slice(2) : signingPolicy;
  const splitted = signingPolicyInternal.match(/.{1,64}/g)!.map(x => x.padEnd(64, "0"))!;
  let hash: string = ethers.keccak256("0x" + splitted[0] + splitted[1])!;

  for (let i = 2; i < splitted!.length; i++) {
    hash = ethers.keccak256("0x" + hash.slice(2) + splitted[i])!;
  }
  return hash;
}

/**
 * Signs message hash with ECDSA using private key
 * @param messageHash 
 * @param privateKey 
 * @param index 
 * @returns 
 */
export async function signMessageHashECDSAWithIndex(
  messageHash: string,
  privateKey: string,
  index: number
): Promise<ECDSASignatureWithIndex> {
  if (!/^0x[0-9a-f]{64}$/i.test(messageHash)) {
    throw Error(`Invalid message hash format: ${messageHash}`);
  }
  const wallet = new ethers.Wallet(privateKey);
  const sigBytes = await wallet.signMessage(ethers.toBeArray(messageHash));
  const sig = ethers.Signature.from(sigBytes);
  return {
    v: sig.v,
    r: sig.r,
    s: sig.s,
    index,
  };
}
