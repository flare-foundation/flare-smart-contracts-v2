import { SigningPolicy, encodeECDSASignatureWithIndex, signMessageHashECDSAWithIndex } from "../../../../scripts/libs/protocol/protocol-coder";

export function defaultTestSigningPolicy(accounts: string[], N: number, singleWeight: number): SigningPolicy {
  const signingPolicyData = {
    signers: [],
    weights: [],
    rewardEpochId: 1,
    startingVotingRoundId: 1,
    threshold: Math.ceil((N / 2) * singleWeight),
    randomSeed: "0x1122334455667788990011223344556677889900112233445566778899001122",
  } as SigningPolicy;
  for (let i = 0; i < N; i++) {
    signingPolicyData.signers.push(accounts[i]);
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
    for (const i of indices) {
      const signature = await signMessageHashECDSAWithIndex(messageHash, privateKeys[i], i);
      signatures += encodeECDSASignatureWithIndex(signature).slice(2);
    }
    return signatures;
  }
  for (let i = 0; i < count; i++) {
    const signature = await signMessageHashECDSAWithIndex(messageHash, privateKeys[i], i);
    signatures += encodeECDSASignatureWithIndex(signature).slice(2);
  }
  return signatures;
}
