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
   * Fee charged for verify() of this protocol, in native wei — or in base units of `feeToken`
   * when the mirror configures one. Decimal string (may exceed 2^64). Must be nonzero — a
   * free protocol is expressed by omitting it from feeConfigs.
   */
  fee: string;
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
   * The per-chain owner (Relay.owner()): the chain's designated multisig, authorizing the fee
   * setters and UUPS upgrades through the owner-timelock. Does not exist on the Flare
   * registry, so it is configured here.
   */
  relayOwner: string;

  /**
   * Recipient of collected verify() fees. Must be nonzero (a zero recipient would burn fees).
   */
  feeCollectionAddress: string;

  /**
   * Initial owner-timelock duration in seconds applied to the owner's fee setters and
   * upgrades (see IOwnableWithTimelock). At most 7 days (604800); 0 makes owner calls
   * immediate.
   */
  timelockDurationSeconds: integer;

  /**
   * Per-protocol verify() fees seeded at deployment.
   */
  feeConfigs: RelayFeeConfig[];

  /**
   * ERC-20 token address the verify() fee is paid in (via allowance + transferFrom, pulled
   * straight to feeCollectionAddress). For chains without a spendable native token (e.g.
   * Tempo, where msg.value is always 0). Required — state the zero address explicitly for
   * fees in the native coin. When nonzero, every `fee` in feeConfigs is denominated in this
   * token's base units, and the token must be a standard exact-transfer ERC-20 —
   * fee-on-transfer or rebasing tokens are unsupported.
   */
  feeToken: string;

  /**
   * Accounts exempt from the verify() fee, seeded at deployment (e.g. DVN adapters), so they
   * are exempt from block one with no governance round-trip. May be empty.
   */
  feeExemptAddresses: string[];
}

/**
 * The source's own home (setter-mode) Relay deployment settings. Protocol addresses are read
 * from the on-chain FlareContractRegistry, the epoch/protocol params are inherited from the
 * currently deployed Relay's stateData() (four are handshake-enforced to match it anyway; the
 * rest are preserved across a redeploy), and the initial signing-policy hash is always
 * reconstructed from chain state and verified against the old Relay — so the only thing
 * configured here is the owner-timelock duration.
 */
export interface RelayHomeConfig {
  /**
   * Initial owner-timelock duration in seconds applied to the owner's fee setters and
   * upgrades (see IOwnableWithTimelock). At most 7 days (604800); 0 makes owner calls
   * immediate (reasonable on home chains where the owner is the governance multisig, itself
   * behind Flare's governance timelock).
   */
  timelockDurationSeconds: integer;
}

/**
 * Per-SOURCE parameters for the owner-governed Relay Forge deployment scripts in
 * deployment/scripts/relay/. One file per source chain (flare.json, coston2.json, …): it holds
 * the source's own home deployment plus the full list of mirror targets that mirror this source
 * — a single reviewed inventory, so mirror deployments cannot drift from a shared base and every
 * field can be required.
 *
 * No protocol ADDRESSES are configured for the home deployment: on a Flare network every address
 * (the Relay owner via GovernanceSettings.getGovernanceAddress(), FlareSystemsManager, the old
 * Relay) is read from the on-chain FlareContractRegistry. Mirrors carry only their own
 * chain-specific values (relayOwner, feeCollectionAddress, timelockDurationSeconds, fees) plus
 * the shared `expectedDeployer`; their protocol parameters come from the live source snapshot,
 * so they cannot drift per chain.
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
