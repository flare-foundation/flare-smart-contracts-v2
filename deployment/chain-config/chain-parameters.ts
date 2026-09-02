// mapped to integer in JSON schema
export type integer = number;

export interface ChainParameters {
  // JSON schema url
  $schema?: string;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Initial settings

  /**
   * The initial offset in reward epochs.
   */
  initialRewardEpochOffset: integer;

  /**
   * The initial random vote power block selection size in blocks (e.g. 1000).
   */
  initialRandomVotePowerBlockSelectionSize: integer;

  /**
   * Voters used in the initial reward epoch id.
   */
  initialVoters: string[];

  /**
   * Normalised weights (sum < 2^16) of the voters used in the initial reward epoch id.
   */
  initialNormalisedWeights: integer[];

  /**
   * Threshold used in the initial reward epoch id - should be less then the sum of the normalised weights.
   */
  initialThreshold: integer;

  /**
   * The initial voter data to be set in entity manager.
   */
  initialVoterData: InitialVoterData[];

  /**
   * Indicates whether this is a test deployment (local, scdev, etc.)
   */
  testDeployment: boolean;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Governance

  /**
   * Submission deployer private key. Overriden if provided in `.env` file as `SUBMISSION_DEPLOYER_PRIVATE_KEY`
   */
  submissionDeployerPrivateKey: string;

  /**
   * Deployer private key. Overriden if provided in `.env` file as `DEPLOYER_PRIVATE_KEY`
   */
  deployerPrivateKey: string;

  /**
   * Genesis governance private key (the key used as governance during deploy).
   * Overriden if set in `.env` file as `GENESIS_GOVERNANCE_PRIVATE_KEY`.
   */
  genesisGovernancePrivateKey: string;

  /**
   * Governance public key (the key to which governance is transferred after deploy).
   * Overriden if provided in `.env` file as `GOVERNANCE_PUBLIC_KEY`.
   */
  governancePublicKey: string;

  /**
   * Governance private key (the private part of `governancePublicKey`).
   * Overriden if provided in `.env` file as `GOVERNANCE_PRIVATE_KEY`.
   * Note: this is only used in test deploys. In production, governance is a multisig address and there is no private key.
   */
  governancePrivateKey: string;

  /**
   * The timelock in seconds to use for all governance operations (the time that has to pass before any governance operation is executed).
   * It safeguards the system against bad governance decisions or hijacked governance.
   */
  governanceTimelock: integer;

  /**
   * The public key of the executor (the account that is allowed to execute governance operations once the timelock expires).
   * Overriden if provided in `.env` file as `GOVERNANCE_EXECUTOR_PUBLIC_KEY`.
   */
  governanceExecutorPublicKey: string;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Flare systems protocol

  /**
   * Timestamp of the first voting round start (in seconds since Unix epoch).
   */
  firstVotingRoundStartTs: integer;

  /**
   * The duration of a voting epoch in seconds.
   */
  votingEpochDurationSeconds: integer;

  /**
   * The start voting round id of the first reward epoch.
   */
  firstRewardEpochStartVotingRoundId: integer;

  /**
   * The duration of a reward epoch in voting epochs.
   */
  rewardEpochDurationInVotingEpochs: integer;

  /**
   * The increase of the threshold in BIPS for relaying the merkle root with the old signing policy (must be more than 100%).
   */
  relayThresholdIncreaseBIPS: integer;

  /**
   * If reward epoch of a message is less then `lastInitializedRewardEpoch - messageFinalizationWindowInRewardEpochs`
   * the relaying of a message is not allowed.
   */
  messageFinalizationWindowInRewardEpochs: integer;

  /**
   * The time in seconds before the end of the reward epoch when the new signing policy initialization starts (e.g. 2 hours).
   */
  newSigningPolicyInitializationStartSeconds: integer;

  /**
   * The maximal random acquisition duration in seconds (e.g. 8 hour).
   */
  randomAcquisitionMaxDurationSeconds: integer;

  /**
   * The maximal random acquisition duration in blocks (e.g. 15000 blocks).
   */
  randomAcquisitionMaxDurationBlocks: integer;

  /**
   *  The minimal number of voting rounds delay for switching to the new signing policy (e.g. 3).
   */
  newSigningPolicyMinNumberOfVotingRoundsDelay: integer;

  /**
   * The minimal duration of voter registration phase in seconds (e.g. 30 minutes).
   */
  voterRegistrationMinDurationSeconds: integer;

  /**
   * The minimal duration of voter registration phase in blocks (e.g. 900 blocks).
   */
  voterRegistrationMinDurationBlocks: integer;

  /**
   * The minimal duration of uptime vote submission phase in seconds (e.g. 10 minutes).
   */
  submitUptimeVoteMinDurationSeconds: integer;

  /**
   * The minimal duration of uptime vote submission phase in blocks (e.g. 300 blocks).
   */
  submitUptimeVoteMinDurationBlocks: integer;

  /**
   * The threshold for the signing policy in PPM (must be less then 100%, e.g. 50%).
   */
  signingPolicyThresholdPPM: integer;

  /**
   * The minimal number of voters for the signing policy (e.g. 10).
   */
  signingPolicyMinNumberOfVoters: integer;

  /**
   * The reward expiry offset in seconds (e.g. 90 days).
   */
  rewardExpiryOffsetSeconds: integer;

  /**
   * The reward manager id is used to identify the reward manager contract in the Flare Systems Manager contract (e.g. chain id).
   */
  rewardManagerId: integer;

  /**
   * Max number of nodes per entity (e.g. 4).
   */
  maxNodeIdsPerEntity: integer;

  /**
   * Max number of voters per reward epoch (e.g. 100).
   */
  maxVotersPerRewardEpoch: integer;

  /**
   * The WNat cap used in signing policy weight, in PPM (e.g. 2.5%).
   */
  wNatCapPPM: integer;

  /**
   * The non-punishable new signing policy sign phase duration in seconds (e.g. 20 minutes).
   */
  signingPolicySignNonPunishableDurationSeconds: integer;

  /**
   * The non-punishable new signing policy sign phase duration in blocks (e.g. 600 blocks).
   */
  signingPolicySignNonPunishableDurationBlocks: integer;

  /**
   * Number of blocks for new signing policy sign phase (in addition to non-punishable blocks) after which all rewards are burned (e.g. 600 blocks).
   */
  signingPolicySignNoRewardsDurationBlocks: integer;

  /**
   * Multiplier applied to node staking weights when computing voter registration weight (e.g. 5).
   */
  stakingFactor: integer;

  /**
   * Fee percentage update timelock measured in reward epochs (must be more than 1, e.g. 3).
   */
  feePercentageUpdateOffset: integer;

  /**
   * Default fee percentage, in BIPS (e.g. 20%).
   */
  defaultFeePercentageBIPS: integer;

  /**
   * Minimum fee percentage value voters can set, in BIPS (e.g. 20%).
   */
  minFeeBIPS: integer;

  /**
   * Indicates whether the P-chain stake is enabled.
   */
  pChainStakeEnabled: boolean;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // FTSO system settings

  /**
   * The FTSO protocol id - used for random number generation.
   */
  ftsoProtocolId: integer;

  /**
   * The minimal reward offer value in NAT (e.g. 1,000,000).
   */
  minimalRewardsOfferValueNAT: integer;

  /**
   * Feed decimals update timelock measured in reward epochs (must be more than 1, e.g. 3).
   */
  decimalsUpdateOffset: integer;

  /**
   * Default feed decimals (e.g. 5).
   */
  defaultDecimals: integer;

  /**
   * Feed history size (e.g. 200).
   */
  feedsHistorySize: integer;

  /**
   * The feed decimals used in the FTSO system.
   */
  feedDecimalsList: FeedDecimals[];

  /**
   * The inflation configurations for the FTSO protocol.
   */
  ftsoInflationConfigurations: FtsoInflationConfiguration[];

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // General settings
  /**
   * The inflation receivers.
   */
  inflationReceivers: InflationReceiver[];

  /**
   * Flare daemonized contracts. Order matters. Inflation should be first.
   */
  flareDaemonizedContracts: FlareDaemonizedContract[];

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Polling Foundation

  /**
   * Array of proposers that can create a proposal
   */
  proposers: string[];

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Polling Management Group

  /**
   * Address of maintainer of PollingManagementGroup contract.
   */
  maintainer: string;

  /**
   * Period (in seconds) between creation of proposal and voting start time.
   */
  votingDelaySeconds: integer;

  /**
   * Length (in seconds) of voting period.
   */
  votingPeriodSeconds: integer;

  /**
   * Threshold (in BIPS) for proposal to potentially be accepted. If less than thresholdConditionBIPS of total vote power participates in vote, proposal can't be accepted.
   */
  thresholdConditionBIPS: integer;

  /**
   * Majority condition (in BIPS) for proposal to be accepted. If less than majorityConditionBIPS votes in favor, proposal can't be accepted.
   */
  majorityConditionBIPS: integer;

  /**
   * Cost of creating proposal (in NAT). It is paid by the proposer.
   */
  proposalFeeValueNAT: integer;

  /**
   * Number of last epochs with initialised rewards in which data provider needs to earn rewards in order to be accepted to the management group.
   */
  addAfterRewardedEpochs: integer;

  /**
   * Number of last consecutive epochs in which data provider should not be chilled in order to be accepted to the management group.
   */
  addAfterNotChilledEpochs: integer;

  /**
   * Number of last epochs with initialised rewards in which data provider should not earn rewards in order to be eligible for removal from the management group.
   */
  removeAfterNotRewardedEpochs: integer;

  /**
   * Number of last relevant proposals to check for not voting. Proposal is relevant if quorum was achieved and voting has ended.
   */
  removeAfterEligibleProposals: integer;
  /**
   * In how many of removeAfterEligibleProposals proposals should data provider not participate (vote) in order to be eligible for removal from the management group.
   */
  removeAfterNonParticipatingProposals: integer;

  /**
   * Number of days for which member is removed from the management group.
   */
  removeForDays: integer;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // P-chain stake mirror verifier

  /**
   * Min duration of P-chain stake in days, recommended value 14 days
   */
  pChainStakeMirrorMinDurationDays: integer;

  /**
   * Max duration of P-chain stake in days, recommended value 365 days
   */
  pChainStakeMirrorMaxDurationDays: integer;

  /**
   * Min amount of P-chain stake. In whole native units, not Wei. Recommended value 50.000.
   */
  pChainStakeMirrorMinAmountNAT: integer;

  /**
   * Max amount of P-chain stake. In whole native units, not Wei. Recommended value 200.000.000.
   */
  pChainStakeMirrorMaxAmountNAT: integer;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Fast updates

  /**
   * The base sample size.
   */
  baseSampleSize: string;

  /**
   * The base range.
   */
  baseRange: string;

  /**
   * The sample increase limit.
   */
  sampleIncreaseLimit: string;

  /**
   * The range increase limit.
   */
  rangeIncreaseLimit: string;

  /**
   * The sample size increase price. In Wei.
   */
  sampleSizeIncreasePriceWei: integer;

  /**
   * The range increase price. In whole native units, not Wei.
   */
  rangeIncreasePriceNAT: integer;

  /**
   * The incentive offer duration in blocks.
   */
  incentiveOfferDurationBlocks: integer;

  /**
   *  The submission window in blocks.
   */
  submissionWindowBlocks: integer;

  /**
   * The feed configurations.
   */
  feedConfigurations: FeedConfiguration[];

  /**
   * The default fee for fetching fast update feeds. In Wei.
   */
  defaultFeeWei: string;

  /**
   * The list of old FTSOs.
   */
  ftsoProxies: FtsoProxy[];

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // RNat

  /**
   * The RNat token name.
   */
  rNatName: string;

  /**
   * The RNat token symbol.
   */
  rNatSymbol: string;

  /**
   * The RNat manager address.
   */
  rNatManager: string;

  /**
   * The RNat first month start timestamp.
   */
  rNatFirstMonthStartTs: integer;

  /**
   * The RNat funding address.
   */
  rNatFundingAddress: string;

  /**
   * Indicates if RNat is funded by incentive pool.
   */
  rNatFundedByIncentivePool: boolean;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // FDC protocol settings

  /**
   *  The FDC protocol id.
   */
  fdcProtocolId: integer;

  /**
   *  The requests offset (in seconds).
   */
  fdcRequestsOffsetSeconds: integer;

  /**
   *  The supported requests fee configurations.
   */
  fdcRequestFees: FdcRequestFee[];

  /**
   * The inflation configurations for the FDC protocol.
   */
  fdcInflationConfigurations: FdcInflationConfiguration[];

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // TEE settings

  /**
   * List of supported TEE platforms ()
   */
  teeSupportedPlatforms: string[];

  /**
   * List of supported TEE key types and signing algorithms
   */
  teeSupportedKeyTypesWithSigningAlgos: TeeKeyTypeWithSigningAlgos[];

  /**
   * The default fee for TEE operations. In Wei.
   */
  teeDefaultFeeWei: string;

  /**
   * The TEE availability check validity duration, in seconds (e.g. 1 day).
   * In order to receive rewards, TEE must be checked for availability at least once in this period.
   */
  teeAvailabilityCheckValidityDurationSeconds: integer;

  /**
   * The signing policy validity duration, in reward epochs (e.g. 10).
   * Used when extending availability or putting tee machine into production:
   * - in case of registration, the check is done for the initial signing policy,
   * - in other cases, the check is done for the last confirmed signing policy.
   */
  teeSigningPolicyValidityDurationInRewardEpochs: integer;

  /**
   * The TEE challenge validity duration (used for TEE availability check), in seconds (e.g. 30 minutes).
   */
  teeChallengeValidityDurationSeconds: integer;

  /**
   * If true, anyone can call IExtensionManager.register() from day 1 (the global
   * extension-owner allowlist starts in "allow all" mode). If false, registration
   * is closed at deploy time and governance must seed / open the allowlist later.
   * Reserved-id minting via registerReserved() is always governance-only and is
   * unaffected by this flag.
   */
  teePublicExtensionCreationEnabled: boolean;

  /**
   * Grace period (in seconds) applied after each per-extension emergency unpause.
   * While this window is open, the third-party expired-availability branch of
   * IMachineManager.pause() is blocked, so machine owners have time to refresh
   * their availability attestation without anyone immediately suspending their
   * still-PRODUCTION machines. Must be in [30 min (1800s), 24h (86400s)] on-chain.
   */
  teeEmergencyUnpauseGracePeriodSeconds: integer;

  /**
   * The amount of rewards that are distributed to TEE owners, in PPM (e.g. 10%).
   */
  teeOwnersPPM: integer;

  /**
   * The TEE operation fees.
   */
  teeOperationFees: TeeOperationFee[];

  // TEE oracle settings

  /**
   * The reserved TEE extension id serving the TEE oracle feeds. Minted by governance via
   * `IExtensionManager.registerReserved`.
   */
  teeOracleExtensionId: integer;

  /**
   * The TEE oracle feeds. One `TeeOracleFeedStore` is deployed per entry, all served by
   * a single `TeeOracleInstructionsSender` on `teeOracleExtensionId` — one machine fleet
   * can serve multiple oracles.
   */
  teeOracleFeeds: TeeOracleFeed[];

  /**
   * The destination address the TEE oracle feed stores forward collected read fees to.
   * Matches FastUpdater's live fee destination (the burn address) on all networks.
   */
  teeOracleFeeDestinationAddress: string;

  /**
   * The account-based TEE payment configurations.
   */
  teePaymentsConfigurations: TeePaymentsConfiguration[];

  /**
   * The UTXO-based TEE payment configurations.
   */
  teePaymentsUtxoConfigurations: TeePaymentsUtxoConfiguration[];

  /**
   * The minimal threshold for FDC2 in BIPS (e.g. 30%).
   */
  fdc2MinThresholdBIPS: integer;

  /**
   * The default number of TEEs used in FDC2.
   */
  fdc2DefaultNumberOfTees: integer;

  /**
   *  The supported FDC2 requests fee configurations.
   */
  fdc2RequestFees: Fdc2RequestFee[];

  /**
   * The inflation configurations for the FDC2 protocol.
   */
  fdc2InflationConfigurations: Fdc2InflationConfiguration[];
}

export interface FtsoInflationConfiguration {
  /**
   * List of feed ids for this configuration.
   */
  feedIds: FeedId[];

  /**
   * Inflation share/weight for this configuration.
   */
  inflationShare: integer;

  /**
   * Minimal reward eligibility turnout threshold in BIPS (e.g. 30%).
   */
  minRewardedTurnoutBIPS: integer;

  /**
   * Primary band reward share in PPM (e.g 60%).
   */
  primaryBandRewardSharePPM: integer;

  /**
   * Secondary band width in PPM (parts per million) in relation to the median (e.g. 1%).
   */
  secondaryBandWidthPPMs: integer[];

  /**
   * Rewards split mode (0 means equally, 1 means random,...).
   */
  mode: integer;
}

export interface InitialVoterData {
  /**
   * The voter address (cold wallet).
   */
  voter: string;

  /**
   * The delegation address (ftso v1 address).
   */
  delegationAddress: string;

  /**
   * The node ids to be associated with the voter.
   */
  nodeIds: string[];
}

export interface FeedDecimals {
  /**
   * The feed id.
   */
  feedId: FeedId;

  /**
   * The feed decimals.
   */
  decimals: integer;
}

export interface FeedConfiguration {
  /**
   * The feed id.
   */
  feedId: FeedId;

  /**
   * The reward band value (interpreted off-chain) in relation to the median.
   */
  rewardBandValue: integer;

  /**
   * The inflation share/weight.
   */
  inflationShare: integer;
}

export interface InflationReceiver {
  /**
   * Indicates whether the contract is part of old repo (flare-smart-contracts).
   */
  oldContract: boolean;

  /**
   * The inflation receiver contract name.
   */
  contractName: string;

  /**
   * The inflation sharing BIPS.
   */
  sharingBIPS: integer;

  /**
   * The inflation top up type.
   */
  topUpType: integer;

  /**
   * The inflation top up factorx100.
   */
  topUpFactorx100: integer;
}

export interface FlareDaemonizedContract {
  /**
   * Indicates whether the contract is part of old repo (flare-smart-contracts).
   */
  oldContract: boolean;

  /**
   * The daemonized contract name.
   */
  contractName: string;

  /**
   * The daemonized contract gas limit.
   */
  gasLimit: integer;
}

export interface FeedId {
  /**
   * The feed category (super category and type).
   * super category: 0 (0x00) - 31 (0x1f) normal, 32 (0x20) - 63 (0x3f) custom, ...
   * type: 0 - none, 1 - crypto, 2 - FX, 3 - commodity, 4 - stock,...
   * e.g. 1 (0x01) - normal crypto, 33 (0x21) - custom crypto,...
   */
  category: integer;

  /**
   * The feed name.
   */
  name: string;
}

export interface FtsoProxy {
  /**
   * The ftso feed id.
   */
  feedId: FeedId;

  /**
   * The FTSO symbol.
   */
  symbol: string;
}

export interface FdcRequestFee {
  /**
   * The attestation type.
   */
  attestationType: string;

  /**
   * The source.
   */
  source: string;

  /**
   * The fee per request. In Wei.
   */
  feeWei: string;
}

export interface FdcInflationConfiguration {
  /**
   * The attestation type.
   */
  attestationType: string;

  /**
   * The source.
   */
  source: string;

  /**
   * Inflation share/weight for this configuration.
   */
  inflationShare: integer;

  /**
   * Minimal reward eligibility threshold in number of request.
   */
  minRequestsThreshold: integer;

  /**
   * Mode (additional settings interpreted on the client side off-chain).
   */
  mode: integer;
}

export interface TeeKeyTypeWithSigningAlgos {
  /**
   * Key type - e.g. EVM, XRP,...
   */
  keyType: string;

  /**
   * Supported signing algorithms for the key type - e.g. keccak256-secp256k1-ecdsa, sha512half-secp256k1-ecdsa,...
   */
  signingAlgos: string[];
}

export interface TeePaymentsSourceConfig {
  /**
   * Source id string (e.g., "XRP", "ETH").
   */
  sourceId: string;

  /**
   * Maximum number of (factor, delay) pairs allowed in a fee schedule for this source.
   */
  maxFeeSchedules: integer;

  /**
   * Maximum delay (in seconds) allowed in a fee schedule entry for this source.
   */
  maxFeeDelaySeconds: integer;
}

export interface TeePaymentsUtxoSourceConfig {
  /**
   * Source id string (e.g., "BTC", "DOGE").
   */
  sourceId: string;
}

export interface TeePaymentsConfiguration {
  /**
   * Payment operation type - F_XRP, F_EVM,...
   */
  opType: string;

  /**
   * Key type - XRP, EVM,...
   */
  keyType: string;

  /**
   * Per-source id configuration (source id + fee schedule limits).
   */
  sourceConfigs: TeePaymentsSourceConfig[];
}

export interface TeePaymentsUtxoConfiguration {
  /**
   * Payment operation type - F_BTC, F_DOGE,...
   */
  opType: string;

  /**
   * Key type - BTC, DOGE,...
   */
  keyType: string;

  /**
   * Per-source id configuration (source id only).
   */
  sourceConfigs: TeePaymentsUtxoSourceConfig[];

  /**
   *  Max batch size.
   */
  maxBatchSize: integer;

  /**
   *  Max batch duration in seconds.
   */
  maxBatchDurationSeconds: integer;

  /**
   *  Anchor reuse delay in seconds (how long after a batch closes before an anchor can be reused).
   */
  anchorReuseDelaySeconds: integer;
}

export interface TeeOperationFee {
  /**
   * The operation type.
   */
  opType: string;

  /**
   * The operation command.
   */
  opCommand: string;

  /**
   * The fee per operation type + command. In Wei.
   */
  feeWei: string;
}

export interface TeeOracleFeed {
  /**
   * The registry name for this feed's TeeOracleFeedStore instance (e.g. "UsdxFeedStore").
   */
  registryName: string;

  /**
   * The feed category (first byte of the feed id). Must be in the FTSO custom feed
   * range [32, 64).
   */
  feedCategory: integer;

  /**
   * The feed name (up to 20 ASCII characters), e.g. "USDX/USD". The feed id is
   * `bytes21(category byte || name || zero padding)`.
   */
  feedName: string;

  /**
   * The number of distinct PRODUCTION TEE machine signatures one feed-update submission must
   * carry, each over that machine's own observation at the same INSTANT — one shared `observedAt`;
   * responses to different requests emitted in the same block share it and may be combined; the
   * store stores the
   * median of them. Must be in [1, 32]. A fresh deployment uses 1 — the fleet must actually
   * have this many PRODUCTION machines running the feed's latest published configuration, which
   * nothing on chain can check, so raise it with the governance `setSubmissionPolicy` setter
   * once it does.
   */
  requiredSignatures: integer;

  /**
   * The relative term of the accepted deviation between the contributed values, in BIPS of
   * `abs(median)`. The deviation bound is
   * `allowed = maxSpreadAbsolute (rescaled) + maxSpreadBIPS * abs(median) / 10000`, and a
   * submission is rejected on the spread AT the median position — not on `max - min`: for four or
   * more signatures the tails are excluded from this test, still evaluated by the flagging
   * check, and named in `FeedOutliers` only when their deviation exceeds the bound. That spread
   * is the gap between the two bracketing values for an EVEN count,
   * and HALF of it for an ODD one, so a raw bracketing gap of up to `2 * allowed + 1` still
   * lands at an odd count. Note the two tests use
   * `allowed` with different metrics and neither dominates the other: at an EVEN count rejection
   * bites at half the per-machine displacement flagging does, while at an ODD count the judged
   * spread is the MEAN of the two gaps flanking the median and so bites up to 2x LATER than
   * flagging — which is why an accepted batch can name an outlier from N = 3 on. Size this from
   * the rejection side for liveness, but do not read either test as implying the other. Must be at most 10000 (100%). 100 (1%) matches FAssets' live flare configuration.
   */
  maxSpreadBIPS: integer;

  /**
   * The absolute term of the accepted deviation, always in units of `10^-8` — a FIXED reference
   * scale, rescaled to each submission's own normalisation scale before use, so the setting's
   * real-world meaning does not move with the `decimals` the enclaves happen to pick. To ask for
   * a real-world tolerance `T` in the feed's own units, set `T * 1e8`. As a decimal string; at
   * most 2^64 - 1. Zero gives a purely relative bound; a non-zero value is what keeps the bound
   * usable for a feed hovering at or near zero, where the relative term alone collapses to zero.
   * With both terms zero the rule is parity-split: at an ODD count the two values at the median
   * position may differ by one unit of the batch's scale, because the spread halves and floors;
   * at an EVEN count the spread is the raw gap, so they must match exactly. Values outside the
   * bracketing pair (they first exist at an even count of 4 or an odd count of 5) never enter
   * the rejection spread — the flagging still judges them: every machine further than the bound
   * from the median is named. Two traps the contract cannot check, because the scale is the
   * enclaves' choice and is only known per batch: the rescale FLOORS, so a value below one unit
   * of the batch's own scale (`< 10^(8 - decimals)`) silently becomes zero; and at a batch
   * the bound goes inert as soon as the RESCALED value reaches the largest reachable deviation
   * (~4.3e17), i.e. when `maxSpreadAbsolute * 10^(decimals - 8) >= 4.3e17` — which a `T = 1`
   * setting hits at `decimals >= 18` — disabling the rejection and the flagging alike;
   * `decimals >= 29` additionally short-circuits straight to that clamp for any non-zero value.
   * Pin the enclave's `decimals` per feed and size against it.
   */
  maxSpreadAbsolute: string;
}

export interface Fdc2RequestFee {
  /**
   * The attestation type.
   */
  attestationType: string;

  /**
   * The source.
   */
  source: string;

  /**
   * The fee per request. In Wei.
   */
  feeWei: string;
}

export interface Fdc2InflationConfiguration {
  /**
   * The attestation type.
   */
  attestationType: string;

  /**
   * The source.
   */
  source: string;

  /**
   * Inflation share/weight for this configuration.
   */
  inflationShare: integer;

  /**
   * Minimal reward eligibility threshold in number of requests.
   */
  minRequestsThreshold: integer;

  /**
   * Mode (additional settings interpreted on the client side off-chain).
   */
  mode: integer;
}
