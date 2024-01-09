//////////////////////////////////////////////////////////////////////////////
// Interfaces
//////////////////////////////////////////////////////////////////////////////

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
}
