import Web3 from "web3";

export interface IECDSASignatureWithIndex {
  r: string;
  s: string;
  v: number;
  index: number;
}

const web3 = new Web3();
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
   * Encodes list of signatures with indices into 0x-prefixed hex string representing byte encoding
   * First 2 bytes are number of signatures
   * @param signatures 
   * @returns 
   */
  export function encodeSignatureList(signatures: IECDSASignatureWithIndex[]): string {    
    let encoded = "0x" + signatures.length.toString(16).padStart(4, "0");
    for (const signature of signatures) {
      encoded += encode(signature).slice(2);
    }
    return encoded;
  }

  /**
   * Decodes list of signatures with indices from hex string (can be 0x-prefixed or not).
   * @param encoded 
   * @returns 
   */
  export function decodeSignatureList(encoded: string): IECDSASignatureWithIndex[] {
    const encodedInternal = encoded.startsWith("0x") ? encoded.slice(2) : encoded;
    if(!/^[0-9a-f]*$/.test(encodedInternal)) {
      throw Error(`Invalid format - not hex string: ${encoded}`);
    }
    if(encodedInternal.length < 4) {
      throw Error(`Invalid encoded signature list length: ${encodedInternal.length}`);
    }
    const count = parseInt(encodedInternal.slice(0, 4), 16);
    if(encodedInternal.length !== 4 + count * 134) {
      throw Error(`Invalid encoded signature list length: ${encodedInternal.length}`);
    }
    let signatures: IECDSASignatureWithIndex[] = [];
    for (let i = 0; i < count; i++) {
      const signature = decode("0x" + encodedInternal.slice(4 + i * 134, 4 + (i + 1) * 134));
      signatures.push(signature);
    }
    return signatures;
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

  /**
   * Recovers signer address from message hash and signature
   * @param messageHash 
   * @param signature 
   * @returns 
   */
  export function recoverSigner(messageHash: string, signature: IECDSASignatureWithIndex): string {
    return web3.eth.accounts.recover(messageHash, "0x" + signature.v.toString(16), signature.r, signature.s).toLowerCase();
  }

  /**
   * Compares two signatures with indices
   * @param a 
   * @param b 
   * @returns 
   */
  export function equals(a: IECDSASignatureWithIndex, b: IECDSASignatureWithIndex): boolean {
    return a.v === b.v && a.r === b.r && a.s === b.s && a.index === b.index;
  }

}
