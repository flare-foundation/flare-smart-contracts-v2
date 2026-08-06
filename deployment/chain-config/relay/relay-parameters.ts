// mapped to integer in JSON schema
export type integer = number;

/**
 * A single protocol-fee configuration for a mirror (relay-mode) Relay deployment.
 */
export interface RelayFeeConfig {
  /**
   * Protocol id the fee applies to. A single byte in relay messages (uint8), and must be > 1.
   */
  protocolId: integer;

  /**
   * Fee in wei charged for verify() of this protocol. Decimal string (may exceed 2^64).
   */
  feeInWei: string;
}

/**
 * One mirror (relay-mode) target of a source. Keyed in `mirrors` by a human blockchain name
 * (e.g. "arbitrum"); the `chainId` here is asserted against the live `block.chainid` at deploy
 * time, so running the deploy against the wrong RPC fails fast.
 */
export interface RelayMirrorConfig {
  /**
   * The target chain id. Checked against `block.chainid` at deploy time.
   */
  chainId: integer;

  /**
   * The per-chain UUPS upgrade owner (Relay.owner()): the chain's designated multisig. Does
   * not exist on the Flare registry, so it is configured here.
   */
  relayOwner: string;

  /**
   * Recipient of collected verify() fees. Must be nonzero (a zero recipient would burn fees).
   */
  feeCollectionAddress: string;

  /**
   * Per-protocol verify() fees seeded at deployment.
   */
  feeConfigs: RelayFeeConfig[];

  /**
   * Accounts exempt from the verify() fee, seeded at deployment (e.g. DVN adapters), so they
   * are exempt from block one with no governance round-trip. May be empty.
   */
  feeExemptAddresses: string[];
}

/**
 * The source's own home (setter-mode) Relay deployment settings. Protocol addresses are read
 * from the on-chain FlareContractRegistry and the epoch/protocol params are inherited from the
 * currently deployed Relay's stateData() (four are handshake-enforced to match it anyway; the
 * rest are preserved across a redeploy), so the ONLY thing configured here is the migration
 * scheme, which is not recoverable from a stored hash.
 */
export interface RelayHomeConfig {
  /**
   * How to interpret the old Relay's stored signing-policy hash: "legacy" wraps a pre-RLY-23
   * content hash once with the source chain id, "chain-bound" passes an already-wrapped hash
   * through. See docs/safe-governance.md §15.1.
   */
  oldRelayPolicyHashScheme: "legacy" | "chain-bound";
}

/**
 * Per-SOURCE parameters for the Safe-governed Relay Forge deployment scripts in
 * deployment/scripts/relay/. One file per source chain (flare.json, coston2.json, …): it holds
 * the source's own home deployment plus the full list of mirror targets that mirror this source
 * — a single reviewed inventory, so mirror deployments cannot drift from a shared base and every
 * field can be required.
 *
 * No protocol ADDRESSES are configured for the home deployment: on a Flare network every address
 * (the governance Safe via GovernanceSettings.getGovernanceAddress(), FlareSystemsManager, the
 * old Relay, AddressUpdater) is read from the on-chain FlareContractRegistry, and the Safe owner
 * set/threshold/nonces are read live from the Safe. Mirrors carry only their own chain-specific
 * addresses (relayOwner, feeCollectionAddress) plus the shared `expectedDeployer`; their protocol
 * parameters come from the live source snapshot, so they cannot drift per chain.
 */
export interface RelayDeployParameters {
  // JSON schema url
  $schema?: string;

  /**
   * The designated deployer EOA — the permanent address authority for the deployer- and
   * source-scoped Relay proxy CREATE3 salt. Shared by the home deployment and EVERY mirror of
   * this source: the SAME EOA must perform all of them for the source's Relay address to match
   * across chains. Must be present, nonzero, and equal to the broadcasting key.
   */
  expectedDeployer: string;

  /**
   * This source's own home (setter-mode) deployment.
   */
  home: RelayHomeConfig;

  /**
   * Relay-mode mirror targets of this source, keyed by blockchain name. Optional — a source may
   * have no mirrors. The deploy selects an entry by name and asserts its `chainId` matches the
   * live chain.
   */
  mirrors?: { [chainName: string]: RelayMirrorConfig };
}
