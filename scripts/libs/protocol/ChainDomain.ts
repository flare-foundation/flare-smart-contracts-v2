import { ethers } from "ethers";

/**
 * RLY-23: chain-domain binding.
 *
 * The Relay contract binds both the stored signing-policy hash and every signed message digest
 * to the configured source network — the chain where the protocol's voter consensus is anchored
 * (Flare/Songbird), NOT the chain the Relay happens to run on:
 *
 *   chainBoundHash(hash, chainId) = keccak256(uint256(chainId) ‖ bytes32(hash))   (64 bytes)
 *
 * On-chain the id is a deploy-time immutable (`relay.sourceChainId()`); on a home deployment it
 * equals the deployment chain, and on a mirror it is the mirrored source network's id. Off-chain
 * code must pass that configured source id — so the SAME signatures verify on the home Relay and on
 * every mirror of the same source, while signatures for one source are rejected by a Relay bound to
 * a different source, even under a fully overlapping voter set. Pre-RLY-23 (unbound) digests are dead.
 *
 * @param hash 0x-prefixed 32-byte hex string (a content hash: policy hash or message hash)
 * @param chainId the configured source chain id (`relay.sourceChainId()`)
 * @returns 0x-prefixed 32-byte hex string
 */
export function chainBoundHash(hash: string, chainId: number | bigint): string {
  if (!/^0x[0-9a-fA-F]{64}$/.test(hash)) {
    throw Error(`Invalid hash format: ${hash}`);
  }
  return ethers.keccak256(ethers.solidityPacked(["uint256", "bytes32"], [chainId, hash]));
}
