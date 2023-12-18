import Web3 from "web3";
import { SigningPolicy, encodeECDSASignatureWithIndex, signMessageHashECDSAWithIndex } from "../../../../scripts/libs/protocol/protocol-coder";

export function defaultTestSigningPolicy(accounts: string[], N: number, singleWeight: number): SigningPolicy {
  const signingPolicyData = {
    voters: [],
    weights: [],
    rewardEpochId: 1,
    startVotingRoundId: 1,
    threshold: Math.ceil((N / 2) * singleWeight),
    publicKeyMerkleRoot: "0x0000000000000000000000000000000000000000000000000000000000000000",
    seed: "0x1122334455667788990011223344556677889900112233445566778899001122",          
  } as SigningPolicy;
  for (let i = 0; i < N; i++) {
    signingPolicyData.voters.push(accounts[i]);
    signingPolicyData.weights.push(singleWeight);
  }
  return signingPolicyData;
}

export async function generateSignatures(
  privateKeys: string[],
  messageHash: string,
  count: number,
  indices?: number[]
) {
  let signatures = ""; 
  if (indices) {
    signatures += indices.length.toString(16).padStart(4, "0");
    for (const i of indices) {
      const signature = await signMessageHashECDSAWithIndex(messageHash, privateKeys[i], i);
      signatures += encodeECDSASignatureWithIndex(signature).slice(2);
    }
    return signatures;
  }
  signatures += count.toString(16).padStart(4, "0");
  for (let i = 0; i < count; i++) {
    const signature = await signMessageHashECDSAWithIndex(messageHash, privateKeys[i], i);
    signatures += encodeECDSASignatureWithIndex(signature).slice(2);
  }
  return signatures;
}
