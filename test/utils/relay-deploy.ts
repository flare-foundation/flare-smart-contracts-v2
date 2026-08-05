import { artifacts } from "hardhat";
import { RelayInstance } from "../../typechain-truffle";
import { GovernanceConfig, RelayInitialConfig } from "../../deployment/utils/RelayInitialConfig";

/**
 * Per-chain owner placeholder for tests that do not exercise upgrades:
 * Relay's OZ Ownable initializer requires a non-zero owner address.
 */
export const RELAY_TEST_GOVERNANCE = "0x1000000000000000000000000000000000000001";

// Safe placeholders for fixtures that do not exercise governance actions.
export const RELAY_TEST_SAFE = "0x1000000000000000000000000000000000000002";
export const RELAY_TEST_SAFE_OWNER = "0x1000000000000000000000000000000000000003";

/**
 * Minimal valid Safe governance block (deployments require it in setter mode; the source
 * chain id must be explicit and nonzero everywhere): the single owner has no known private
 * key, so processSafeMessage can never verify — effectively inert.
 */
export function testGovernanceConfig(sourceChainId: number): GovernanceConfig {
  return {
    sourceChainId,
    safe: RELAY_TEST_SAFE,
    threshold: 1,
    owners: [RELAY_TEST_SAFE_OWNER],
    ownerConfigSafeNonce: 0,
    safeNonce: 0,
  };
}

/**
 * Drop-in replacement for the pre-proxy `Relay.new(config, setter, oldRelay)`:
 * deploys a Relay implementation + RelayProxy (which runs `initialize` atomically in its
 * constructor) and returns the proxied Relay handle.
 */
export async function deployRelayProxy(
  relayInitialConfig: RelayInitialConfig,
  signingPolicySetter: string,
  oldRelay: string,
  initialOwner: string = RELAY_TEST_GOVERNANCE
): Promise<RelayInstance> {
  const Relay = artifacts.require("Relay");
  const RelayProxy = artifacts.require("RelayProxy");
  const implementation = await Relay.new();
  const proxy = await RelayProxy.new(
    implementation.address,
    { ...relayInitialConfig, feeExemptAddresses: relayInitialConfig.feeExemptAddresses ?? [] },
    signingPolicySetter,
    oldRelay,
    initialOwner
  );
  return Relay.at(proxy.address);
}
