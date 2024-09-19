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
    signingPolicySignNonPunishableDurationBlocks : integer;

    /**
     * Number of blocks for new signing policy sign phase (in addition to non-punishable blocks) after which all rewards are burned (e.g. 600 blocks).
     */
    signingPolicySignNoRewardsDurationBlocks: integer;

    /**
     * Fee percentage update timelock measured in reward epochs (must be more than 1, e.g. 3).
     */
    feePercentageUpdateOffset: integer;

    /**
     * Default fee percentage, in BIPS (e.g. 20%).
     */
    defaultFeePercentageBIPS: integer;

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
    // Polling Ftso

    /**
     * Address of maintainer of PollingFtso contract.
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
     * The feed category (0 - none, 1 - crypto, 2 - FX, 3 - commodity, 4 - stock, ...).
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
