import { ECDSASignatureWithIndex } from "../../../../scripts/libs/protocol/ECDSASignatureWithIndex";
import { ISigningPolicy } from "../../../../scripts/libs/protocol/SigningPolicy";

export function defaultTestSigningPolicy(accounts: string[], N: number, singleWeight: number): ISigningPolicy {
  const signingPolicyData = {
    voters: [],
    weights: [],
    rewardEpochId: 1,
    startVotingRoundId: 1,
    threshold: Math.ceil((N / 2) * singleWeight),
    seed: "0x1122334455667788990011223344556677889900112233445566778899001122",          
  } as ISigningPolicy;
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
      const signature = await ECDSASignatureWithIndex.signMessageHash(messageHash, privateKeys[i], i);
      signatures += ECDSASignatureWithIndex.encode(signature).slice(2);
    }
    return signatures;
  }
  signatures += count.toString(16).padStart(4, "0");
  for (let i = 0; i < count; i++) {
    const signature = await ECDSASignatureWithIndex.signMessageHash(messageHash, privateKeys[i], i);
    signatures += ECDSASignatureWithIndex.encode(signature).slice(2);
  }
  return signatures;
}
