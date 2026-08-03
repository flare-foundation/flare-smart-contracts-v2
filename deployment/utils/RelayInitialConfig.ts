export interface FeeConfig {
  protocolId: number;
  feeInWei: string;
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
  // Source network id: the chain whose voter consensus this Relay verifies (and, on a mirror, where the
  // GSS governance Safe lives). RLY-23: bound into every signed digest and the governance digest.
  // 0 => defaults to block.chainid (home deploy). A mirror MUST set the mirrored network's id explicitly.
  sourceChainId: number;
  governanceSafe: string;
  governanceThreshold: number;
  governanceOwners: string[];
  governanceOwnerConfigSafeNonce: number;
  governanceSafeNonce: number;
}
