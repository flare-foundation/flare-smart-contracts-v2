
import * as elliptic from "elliptic"
import { sha256, keccak, ripemd160 } from 'ethereumjs-util';
const EC: typeof elliptic.ec = elliptic.ec
const ec: elliptic.ec = new EC("secp256k1")

import BN from "bn.js";

export function privateKeyToPublicKeyPair(privateKey: Buffer): Buffer[] {
  const keyPair = ec.keyFromPrivate(privateKey).getPublic();
  const x = keyPair.getX().toBuffer(undefined, 32);
  const y = keyPair.getY().toBuffer(undefined, 32);
  return [x, y];
}

export function compressPublicKey(x: Buffer, y: Buffer): Buffer {
  const prefix = ((new BN(y)).isEven()) ? 0x02 : 0x03;
  return Buffer.concat([Buffer.from([prefix]), x]);
}

export function encodePublicKey(x: Buffer, y: Buffer, compress: boolean): Buffer {
  return (compress) ? compressPublicKey(x, y) : Buffer.concat([Buffer.from([0x04]), x, y]);
}

export function publicPairToPublicKeyWith0xPrefix(x: Buffer, y: Buffer): string {
  return `0x${x.toString('hex')}${y.toString('hex')}`
}

export function publicKeyToAvalancheAddress(x: Buffer, y: Buffer) {
  const compressed = compressPublicKey(x, y);
  return ripemd160(sha256(compressed), false);
}

export function publicKeyToEthereumAddress(x: Buffer, y: Buffer) {
  return keccak(Buffer.concat([x, y])).slice(-20);
}