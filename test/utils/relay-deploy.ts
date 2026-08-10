import { artifacts } from "hardhat";
import { RelayInstance } from "../../typechain-truffle";
import { RelayInitialConfig } from "../../deployment/utils/RelayInitialConfig";

/**
 * Per-chain owner placeholder for tests that do not exercise owner actions:
 * Relay's OwnableWithTimelock initializer requires a non-zero owner address.
 */
export const RELAY_TEST_GOVERNANCE = "0x1000000000000000000000000000000000000001";

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
