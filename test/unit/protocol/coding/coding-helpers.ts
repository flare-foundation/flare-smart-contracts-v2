import { ECDSASignatureWithIndex, IECDSASignatureWithIndex } from "../../../../scripts/libs/protocol/ECDSASignatureWithIndex";
import { ISigningPolicy, SigningPolicy } from "../../../../scripts/libs/protocol/SigningPolicy";

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
  SigningPolicy.normalizeAddresses(signingPolicyData);
  return signingPolicyData;
}

export async function generateSignaturesEncoded(
  privateKeys: string[],
  messageHash: string,
  count: number,
  indices?: number[]
): Promise<string> {
  return ECDSASignatureWithIndex.encodeSignatureList(await generateSignatures(privateKeys, messageHash, count, indices)).slice(2)
}


export async function generateSignatures(
  privateKeys: string[],
  messageHash: string,
  count: number,
  indices?: number[]
): Promise<IECDSASignatureWithIndex[]> {
  let signatures: IECDSASignatureWithIndex[] = [];
  if (indices) {
    for (const i of indices) {
      const signature = await ECDSASignatureWithIndex.signMessageHash(messageHash, privateKeys[i], i);
      signatures.push(signature);
    }
    return signatures;
  }
  for (let i = 0; i < count; i++) {
    const signature = await ECDSASignatureWithIndex.signMessageHash(messageHash, privateKeys[i], i);
    signatures.push(signature);
  }
  return signatures;
}

