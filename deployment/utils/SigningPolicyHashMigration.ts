import { chainBoundHash } from "../../scripts/libs/protocol/ChainDomain";

export type SigningPolicyHashScheme = "legacy" | "chain-bound";

const ZERO_HASH = `0x${"00".repeat(32)}`;

/**
 * Converts the old Relay's stored policy hash into the scheme required by the
 * new Relay. The caller must choose the old scheme explicitly; guessing from a
 * nonzero bytes32 value cannot distinguish a legacy content hash from an
 * already chain-bound hash.
 */
export function signingPolicyHashForMigration(
  oldHash: string,
  chainId: number | bigint,
  oldScheme: string
): string {
  if (!/^0x[0-9a-fA-F]{64}$/.test(oldHash) || oldHash.toLowerCase() === ZERO_HASH) {
    throw Error(`Invalid old Relay signing policy hash: ${oldHash}`);
  }
  if (oldScheme === "legacy") {
    return chainBoundHash(oldHash, chainId);
  }
  if (oldScheme === "chain-bound") {
    return oldHash;
  }
  throw Error(
    `Invalid old Relay policy hash scheme '${oldScheme}'; expected 'legacy' or 'chain-bound'`
  );
}
