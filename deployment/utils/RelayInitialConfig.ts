export interface FeeConfig {
  protocolId: number;
  // Fee in native wei, or in feeToken base units when the deployment configures a fee token.
  fee: string;
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
  // ERC-20 the verify() fee is paid in; zero/absent = native coin. Relay (mirror) mode only —
  // must be zero/absent on a home deploy. Optional here — deploy boundaries default it to the
  // zero address — so existing configs and test fixtures need not list it.
  feeToken?: string;
  // Accounts exempt from the verify() fee at deployment (relay mode only; must be empty/absent on
  // a home deploy). Optional here — deploy boundaries default it to [] — so existing configs and
  // test fixtures that never seed exemptions need not list it.
  feeExemptAddresses?: string[];
  // Source network id, bound into every stored policy hash and signed digest. MUST be
  // explicit and NONZERO on every deployment — a home deploy states its own chain id (enforced
  // on-chain), a mirror the mirrored network's.
  sourceChainId: number;
  // Initial owner-timelock duration in seconds applied to the owner's fee setters and upgrades
  // (see IOwnableWithTimelock). At most 7 days; 0 makes owner calls immediate.
  timelockDurationSeconds: number;
}
