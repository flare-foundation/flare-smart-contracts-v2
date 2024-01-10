import Web3 from "web3";
export interface IECDSASignature {
  r: string;
  s: string;
  v: number;
}

export namespace ECDSASignature {
  /**
   * Encodes ECDSA signature into 0x-prefixed hex string representing byte encoding
   * @param signature
   * @returns
   */
  export function encode(signature: IECDSASignature): string {
    return (
      "0x" +
      signature.v.toString(16).padStart(2, "0") +
      signature.r.slice(2) +
      signature.s.slice(2)
    );
  }

  /**
   * Decodes ECDSA signature with index from hex string (can be 0x-prefixed or not).
   * @param encodedSignature
   * @returns
   */
  export function decode(encodedSignature: string): IECDSASignature {
    const encodedSignatureInternal = (
      encodedSignature.startsWith("0x") ? encodedSignature.slice(2) : encodedSignature
    ).toLowerCase();
    if (!/^[0-9a-f]*$/.test(encodedSignatureInternal)) {
      throw Error(`Invalid format - not hex string: ${encodedSignature}`);
    }
    if (encodedSignatureInternal.length !== 130) {
      // (1 + 32 + 32) * 2 = 134
      throw Error(`Invalid encoded signature length: ${encodedSignatureInternal.length}`);
    }
    const v = parseInt(encodedSignatureInternal.slice(0, 2), 16);
    const r = "0x" + encodedSignatureInternal.slice(2, 66);
    const s = "0x" + encodedSignatureInternal.slice(66, 130);
    return {
      v,
      r,
      s,
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
  ): Promise<IECDSASignature> {
    if (!/^0x[0-9a-f]{64}$/i.test(messageHash)) {
      throw Error(`Invalid message hash format: ${messageHash}`);
    }
    const web3 = new Web3();
    let signatureObject = web3.eth.accounts.sign(messageHash, privateKey);
    return {
      v: parseInt(signatureObject.v.slice(2), 16),
      r: signatureObject.r,
      s: signatureObject.s
    } as IECDSASignature;
  }  
}
