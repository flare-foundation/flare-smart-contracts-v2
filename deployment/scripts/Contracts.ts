import { Readable } from "stream";

export class Contract {
  name: string;
  contractName: string;
  address: string;

  constructor(name: string, contractName: string, address: string) {
    this.name = name;
    this.contractName = contractName;
    this.address = address;
  }
}

export class Contracts {
  private contracts: Map<string, Contract>;

  public static readonly GOVERNANCE_SETTINGS = "GovernanceSettings";
  public static readonly ADDRESS_UPDATER = "AddressUpdater";
  public static readonly CLEANUP_BLOCK_NUMBER_MANAGER = "CleanupBlockNumberManager";
  public static readonly FTSO_REGISTRY = "FtsoRegistry";
  public static readonly DISTRIBUTION_TREASURY = "DistributionTreasury";
  public static readonly DISTRIBUTION_TO_DELEGATORS = "DistributionToDelegators";
  public static readonly INCENTIVE_POOL_TREASURY = "IncentivePoolTreasury";
  public static readonly INCENTIVE_POOL = "IncentivePool";
  public static readonly INCENTIVE_POOL_ALLOCATION = "IncentivePoolAllocation";
  public static readonly INITIAL_AIRDROP = "InitialAirdrop";
  public static readonly CLAIM_SETUP_MANAGER = "ClaimSetupManager";
  public static readonly ESCROW = "Escrow";
  public static readonly SUPPLY = "Supply";
  public static readonly INFLATION_ALLOCATION = "InflationAllocation";
  public static readonly INFLATION = "Inflation";
  public static readonly FTSO_REWARD_MANAGER = "FtsoRewardManager";
  public static readonly VALIDATOR_REGISTRY = "ValidatorRegistry";
  public static readonly VALIDATOR_REWARD_MANAGER = "ValidatorRewardManager";
  public static readonly ATTESTATION_PROVIDER_REWARD_MANAGER = "AttestationProviderRewardManager";
  public static readonly PRICE_SUBMITTER = "PriceSubmitter";
  public static readonly FTSO_MANAGER = "FtsoManager";
  public static readonly STATE_CONNECTOR = "StateConnector";
  public static readonly VOTER_WHITELISTER = "VoterWhitelister";
  public static readonly FLARE_DAEMON = "FlareDaemon";
  public static readonly WNAT = "WNat";
  public static readonly COMBINED_NAT = "CombinedNat";
  public static readonly GOVERNANCE_VOTE_POWER = "GovernanceVotePower";
  public static readonly POLLING_FOUNDATION = "PollingFoundation";
  public static readonly FLARE_ASSET_REGISTRY = "FlareAssetRegistry";
  public static readonly WNAT_REGISTRY_PROVIDER = "WNatRegistryProvider";
  public static readonly FLARE_CONTRACT_REGISTRY = "FlareContractRegistry";
  public static readonly POLLING_FTSO = "PollingFtso";
  public static readonly ADDRESS_BINDER = "AddressBinder";
  public static readonly P_CHAIN_STAKE_MIRROR_MULTI_SIG_VOTING = "PChainStakeMirrorMultiSigVoting";
  public static readonly P_CHAIN_STAKE_MIRROR_VERIFIER = "PChainStakeMirrorVerifier";
  public static readonly P_CHAIN_STAKE_MIRROR = "PChainStakeMirror";
  public static readonly ENTITY_MANAGER = "EntityManager";
  public static readonly FLARE_SYSTEMS_MANAGER = "FlareSystemsManager";
  public static readonly SUBMISSION = "Submission";
  public static readonly RELAY = "Relay";
  public static readonly VOTER_REGISTRY = "VoterRegistry";
  public static readonly REWARD_MANAGER = "RewardManager";
  public static readonly FLARE_SYSTEMS_CALCULATOR = "FlareSystemsCalculator";
  public static readonly WNAT_DELEGATION_FEE = "WNatDelegationFee";
  public static readonly FTSO_INFLATION_CONFIGURATIONS = "FtsoInflationConfigurations";
  public static readonly FTSO_FEED_DECIMALS = "FtsoFeedDecimals";
  public static readonly FTSO_FEED_PUBLISHER = "FtsoFeedPublisher";
  public static readonly FTSO_REWARD_OFFERS_MANAGER = "FtsoRewardOffersManager";
  public static readonly FAST_UPDATER = "FastUpdater";
  public static readonly FAST_UPDATE_INCENTIVE_MANAGER = "FastUpdateIncentiveManager";
  public static readonly FAST_UPDATES_CONFIGURATION = "FastUpdatesConfiguration";
  public static readonly FEE_CALCULATOR = "FeeCalculator";

  // NOTE: this is not exhaustive list. Constants here are defined on on-demand basis (usually motivated by tests).

  constructor() {
    // Maps a contract name to a Contract object
    this.contracts = new Map<string, Contract>();
  }

  deserializeFile(filePath: string) {
    const fs = require("fs");
    if (!fs.existsSync(filePath)) return;
    const contractsJson = fs.readFileSync(filePath);
    if (contractsJson.length == 0) return;
    this.deserializeJson(contractsJson);
  }

  async deserialize(stream: Readable) {
    const contractsJson = await this.readStream(stream);
    this.deserializeJson(contractsJson);
  }

  deserializeJson(contractsJson: string) {
    const parsedContracts = JSON.parse(contractsJson);
    parsedContracts.forEach((contract: { name: string; contractName: string, address: string; }) => {
      this.contracts.set(contract.name, contract);
    })
  }

  allContracts(): Contract[] {
    return Array.from(this.contracts.values());
  }

  getContractAddress(name: string): string {
    if (this.contracts.has(name)) {
      return this.contracts.get(name)!.address;
    } else {
      throw new Error(`${name} not found`);
    }
  }

  async getContractsMap(hre: any): Promise<any> {
    const contractsMap: any = {};
    for (let con of this.allContracts()) {
      const name = con.contractName.split(".")[0];
      const alias = con.name[0].toLowerCase() + con.name.slice(1);
      const contract = hre.artifacts.require(name as any);
      contractsMap[alias] = await contract.at(con.address);
    }
    return contractsMap;
  }

  async readStream(stream: Readable) {
    const chunks = [];
    for await (const chunk of stream) chunks.push(chunk);
    return Buffer.concat(chunks).toString('utf-8');
  }

  add(contract: Contract) {
    this.contracts.set(contract.name, contract);
  }

  serialize(): string {
    return JSON.stringify(this.allContracts(), null, 2);
  }
}
