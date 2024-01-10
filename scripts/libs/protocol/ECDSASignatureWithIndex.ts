import Web3 from "web3";

export interface IECDSASignatureWithIndex {
  r: string;
  s: string;
  v: number;
  index: number;
}

export namespace ECDSASignatureWithIndex {
  //////////////////////////////////////////////////////////////////////////////
  // Signature with index structure
  // 1 byte - v
  // 32 bytes - r
  // 32 bytes - s
  // 2 byte - index in signing policy
  // Total 67 bytes
  //////////////////////////////////////////////////////////////////////////////
  /**
   * Encodes ECDSA signature with index into 0x-prefixed hex string representing byte encoding
   * @param signature
   * @returns
   */
  export function encode(signature: IECDSASignatureWithIndex): string {
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
  export function decode(encodedSignature: string): IECDSASignatureWithIndex {
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

  /**
   * Signs message hash with ECDSA using private key
   * @param messageHash 
   * @param privateKey 
   * @param index 
   * @returns 
   */
  export async function signMessageHash(
    messageHash: string,
    privateKey: string,
    index: number
  ): Promise<IECDSASignatureWithIndex> {
    if (!/^0x[0-9a-f]{64}$/i.test(messageHash)) {
      throw Error(`Invalid message hash format: ${messageHash}`);
    }
    const web3 = new Web3();
    let signatureObject = web3.eth.accounts.sign(messageHash, privateKey);
    return {
      v: parseInt(signatureObject.v.slice(2), 16),
      r: signatureObject.r,
      s: signatureObject.s,
      index,
    } as IECDSASignatureWithIndex;

    // The next code occasionally does not work well
    // Example is first private key and the message:
    // {
    //   protocolId: 15,
    //   votingRoundId: 4111,
    //   randomQualityScore: true,
    //   merkleRoot: '0x29c81c1d44d6d822982fa1d09e09bde8db25fb8df6cd03b6e8d6c3bea1d512f6'
    // }
    // TODO: find out why

    /*
    const wallet = new ethers.Wallet(privateKey);
    const sigBytes = await wallet.signMessage(ethers.toBeArray(messageHash));
    const sig = ethers.Signature.from(sigBytes);
    console.log("SIG")
    console.dir(sig)
    return {
      v: sig.v,
      r: sig.r,
      s: sig.s,
      index,
    };
    */
  }
}
