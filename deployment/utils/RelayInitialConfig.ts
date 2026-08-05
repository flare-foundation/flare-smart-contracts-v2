import { ChainParameters } from "../chain-config/chain-parameters";

export interface FeeConfig {
  protocolId: number;
  feeInWei: string;
}

/**
 * Mirror of ISafeGovernance.GovernanceConfig. `sourceChainId` is the network the Safe
 * governance Safe lives on and doubles as the Relay's signing-domain source (RLY-23: bound
 * into every signed digest and the governance digest). It MUST be explicit and NONZERO on
 * every deployment — a home deploy states its own chain id, a mirror the mirrored network's.
 * Safe governance is mandatory on every deployment; the full configuration is validated at
 * initialization.
 */
export interface GovernanceConfig {
  sourceChainId: number;
  safe: string;
  threshold: number;
  owners: string[];
  ownerConfigSafeNonce: number;
  safeNonce: number;
}

export interface RelayInitialConfig {
  initialRewardEpochId: number;
  startingVotingRoundIdForInitialRewardEpochId: number;
  initialSigningPolicyHash: string;
  randomNumberProtocolId: number;
  firstVotingRoundStartTs: number;
  votingEpochDurationSeconds: number;
  firstRewardEpochStartVotingRoundId: number;
  rewardEpochDurationInVotingEpochs: number;
  thresholdIncreaseBIPS: number;
  messageFinalizationWindowInRewardEpochs: number;
  feeCollectionAddress: string;
  feeConfigs: FeeConfig[];
  // Accounts exempt from the verify() fee at deployment (relay mode only; must be empty/absent on
  // a home deploy). Optional here — deploy boundaries default it to [] — so existing configs and
  // test fixtures that never seed exemptions need not list it.
  feeExemptAddresses?: string[];
  governance: GovernanceConfig;
}

/**
 * Builds the Safe GovernanceConfig for a Relay deployment from chain parameters.
 * Relay.initialize requires governance on EVERY deployment (home, mirror and old-relay
 * migration alike), so all five safeGovernance* parameters must be present.
 */
export function safeGovernanceFromParameters(
  parameters: ChainParameters,
  sourceChainId: number
): GovernanceConfig {
  if (
    !parameters.safeGovernanceSafe ||
    !parameters.safeGovernanceThreshold ||
    !parameters.safeGovernanceOwners ||
    parameters.safeGovernanceOwners.length === 0 ||
    parameters.safeGovernanceOwnerConfigSafeNonce == null ||
    parameters.safeGovernanceSafeNonce == null
  ) {
    throw new Error(
      "Relay deployments require the Safe governance chain parameters: safeGovernanceSafe, " +
        "safeGovernanceThreshold, safeGovernanceOwners, safeGovernanceOwnerConfigSafeNonce, safeGovernanceSafeNonce"
    );
  }
  return {
    sourceChainId,
    safe: parameters.safeGovernanceSafe,
    threshold: parameters.safeGovernanceThreshold,
    owners: parameters.safeGovernanceOwners,
    ownerConfigSafeNonce: parameters.safeGovernanceOwnerConfigSafeNonce,
    safeNonce: parameters.safeGovernanceSafeNonce,
  };
}

