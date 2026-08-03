import { ethers } from "ethers";

/**
 * RLY-23: chain-domain binding.
 *
 * The Relay contract binds both the stored signing-policy hash and every signed message digest
 * to the chain it runs on:
 *
 *   chainBoundHash(hash, chainId) = keccak256(uint256(chainId) ‖ bytes32(hash))   (64 bytes)
 *
 * On-chain the id is read at runtime (CHAINID opcode), so off-chain code must use the chain id
 * of the network the target Relay is deployed on. Signatures over unbound (pre-RLY-23) digests
 * are rejected by the contract, and signatures produced for one network are rejected by every
 * other network's Relay even under a fully overlapping voter set.
 *
 * @param hash 0x-prefixed 32-byte hex string (a content hash: policy hash or message hash)
 * @param chainId the chain id of the network the target Relay is deployed on
 * @returns 0x-prefixed 32-byte hex string
 */
export function chainBoundHash(hash: string, chainId: number | bigint): string {
  if (!/^0x[0-9a-fA-F]{64}$/.test(hash)) {
    throw Error(`Invalid hash format: ${hash}`);
  }
  return ethers.keccak256(ethers.solidityPacked(["uint256", "bytes32"], [chainId, hash]));
}
