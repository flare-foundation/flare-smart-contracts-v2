import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "./Contracts";
import { EntityManagerContract, FlareSystemsCalculatorContract, FlareSystemsManagerContract, FtsoFeedDecimalsContract, FtsoFeedPublisherContract, FtsoInflationConfigurationsContract, FtsoRewardOffersManagerContract, RewardManagerContract, FtsoRewardManagerProxyContract, SubmissionContract, VoterRegistryContract } from "../../typechain-truffle";
import { ChainParameters } from "../chain-config/chain-parameters";

type Account = ReturnType<typeof web3.eth.accounts.privateKeyToAccount>;

export async function switchToProductionMode(hre: HardhatRuntimeEnvironment, contracts: Contracts, parameters: ChainParameters, quiet: boolean = false) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts as Truffle.Artifacts;

  // Turn over governance
  if (!quiet) {
    console.error("Switching to production mode...");
  }

  // Define accounts in play for the deployment process
  let deployerAccount: Account;

  // Get deployer account
  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e)
  }

  if (!quiet) {
    console.error(`Switching to production from deployer address ${deployerAccount.address}`);
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  // Contract definitions
  const EntityManager: EntityManagerContract = artifacts.require("EntityManager");
  const VoterRegistry: VoterRegistryContract = artifacts.require("VoterRegistry");
  const FlareSystemsCalculator: FlareSystemsCalculatorContract = artifacts.require("FlareSystemsCalculator");
  const FlareSystemsManager: FlareSystemsManagerContract = artifacts.require("FlareSystemsManager");
  const RewardManager: RewardManagerContract = artifacts.require("RewardManager");
  const FtsoRewardManagerProxy: FtsoRewardManagerProxyContract = artifacts.require("FtsoRewardManagerProxy");
  const Submission: SubmissionContract = artifacts.require("Submission");
  const FtsoInflationConfigurations: FtsoInflationConfigurationsContract = artifacts.require("FtsoInflationConfigurations");
  const FtsoRewardOffersManager: FtsoRewardOffersManagerContract = artifacts.require("FtsoRewardOffersManager");
  const FtsoFeedDecimals: FtsoFeedDecimalsContract = artifacts.require("FtsoFeedDecimals");
  const FtsoFeedPublisher: FtsoFeedPublisherContract = artifacts.require("FtsoFeedPublisher");

  // Get deployed contracts
  const entityManager = await EntityManager.at(contracts.getContractAddress(Contracts.ENTITY_MANAGER));
  const voterRegistry = await VoterRegistry.at(contracts.getContractAddress(Contracts.VOTER_REGISTRY));
  const flareSystemsCalculator = await FlareSystemsCalculator.at(contracts.getContractAddress(Contracts.FLARE_SYSTEMS_CALCULATOR));
  const flareSystemsManager = await FlareSystemsManager.at(contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER));
  const rewardManager = await RewardManager.at(contracts.getContractAddress(Contracts.REWARD_MANAGER));
  const ftsoRewardManagerProxy = await FtsoRewardManagerProxy.at(contracts.getContractAddress(Contracts.FTSO_REWARD_MANAGER));
  const submission = await Submission.at(contracts.getContractAddress(Contracts.SUBMISSION));
  const ftsoInflationConfigurations = await FtsoInflationConfigurations.at(contracts.getContractAddress(Contracts.FTSO_INFLATION_CONFIGURATIONS));
  const ftsoRewardOffersManager = await FtsoRewardOffersManager.at(contracts.getContractAddress(Contracts.FTSO_REWARD_OFFERS_MANAGER));
  const ftsoFeedDecimals = await FtsoFeedDecimals.at(contracts.getContractAddress(Contracts.FTSO_FEED_DECIMALS));
  const ftsoFeedPublisher = await FtsoFeedPublisher.at(contracts.getContractAddress(Contracts.FTSO_FEED_PUBLISHER));


  // switch to production mode
  await entityManager.switchToProductionMode();
  await voterRegistry.switchToProductionMode();
  await flareSystemsCalculator.switchToProductionMode();
  await flareSystemsManager.switchToProductionMode();
  await rewardManager.switchToProductionMode();
  await ftsoRewardManagerProxy.switchToProductionMode();
  if (parameters.testDeployment) {
    await submission.switchToProductionMode({ from: parameters.governancePublicKey });
  }
  await ftsoInflationConfigurations.switchToProductionMode();
  await ftsoRewardOffersManager.switchToProductionMode();
  await ftsoFeedDecimals.switchToProductionMode();
  await ftsoFeedPublisher.switchToProductionMode();
}
