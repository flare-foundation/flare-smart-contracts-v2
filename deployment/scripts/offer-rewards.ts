import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "./Contracts";
import { FlareSystemsManagerContract, FtsoRewardOffersManagerContract } from "../../typechain-truffle";
import { EpochSettings } from "../utils/EpochSettings";
import { FtsoRewardOffersManagerInstance } from "../../typechain-truffle/contracts/ftso/implementation/FtsoRewardOffersManager";
import { sleepFor } from "../utils/time";
import { FtsoConfigurations } from "../../scripts/libs/protocol/FtsoConfigurations";
import { ChainParameters } from "../chain-config/chain-parameters";

const feedCount = 10;
const rewardEpochOffsetSec = 10;

export async function offerRewards(
  hre: HardhatRuntimeEnvironment,
  contracts: Contracts,
  parameters: ChainParameters,
  /** Will offer rewards now without waiting for next reward epoch start. */
  runNow: boolean
) {
  const epochSettings = await getEpochSettings(contracts);

  const offerSender = hre.web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  const offers = generateOffers(feedCount);

  const FtsoRewardOffersManager: FtsoRewardOffersManagerContract = artifacts.require("FtsoRewardOffersManager");
  const offerManager = await FtsoRewardOffersManager.at(
    contracts.getContractAddress(Contracts.FTSO_REWARD_OFFERS_MANAGER)
  );

  if (runNow) {
    await runOfferRewards(epochSettings, offerManager, offers, offerSender.address);
  }

  function scheduleOfferRewardsActions() {
    const time = Date.now();
    const nextEpochStartMs = epochSettings.nextRewardEpochStartMs(time);

    setTimeout(async () => {
      scheduleOfferRewardsActions();
      await runOfferRewards(epochSettings, offerManager, offers, offerSender.address);
    }, nextEpochStartMs - time + rewardEpochOffsetSec * 1000);
  }
  scheduleOfferRewardsActions();

  while (true) {
    await sleepFor(1000);
  }
}

async function runOfferRewards(
  epochSettings: EpochSettings,
  ofm: FtsoRewardOffersManagerInstance,
  offers: any[],
  offerSender: string
) {
  const nextRewardEpochId = epochSettings.rewardEpochForTime(Date.now()) + 1;

  const batchSize = 75;
  const offerBatches = [];
  for (let i = 0; i < offers.length; i += batchSize) {
    const batch = offers.slice(i, i + batchSize);
    offerBatches.push(batch);
  }

  for (const batch of offerBatches) {
    let rewards = 0;
    for (const offer of batch) {
      rewards += offer.amount;
    }
    try {
      await ofm.offerRewards(nextRewardEpochId, batch, { value: rewards.toString(), from: offerSender });
      console.log(`Rewards offered: ${batch.length}`);
      await sleepFor(500);
    } catch (e) {
      console.error("Rewards not offered: " + e);
    }
  }
}

function generateOffers(n: number) {
  const offers = [];
  for (let i = 0; i < n; i++) {
    offers.push({
      amount: 25000000,
      feedName: FtsoConfigurations.encodeFeedName(i.toString()),
      minRewardedTurnoutBIPS: 5000,
      primaryBandRewardSharePPM: 450000,
      secondaryBandWidthPPM: 50000,
      claimBackAddress: "0x0000000000000000000000000000000000000000",
    });
  }
  return offers;
}

async function getEpochSettings(contracts: Contracts) {
  const FlareSystemsManager: FlareSystemsManagerContract = artifacts.require("FlareSystemsManager");
  const fsm = await FlareSystemsManager.at(contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER));

  const epochSettings = new EpochSettings(
    (await fsm.firstRewardEpochStartTs()).toNumber(),
    (await fsm.rewardEpochDurationSeconds()).toNumber(),
    (await fsm.firstVotingRoundStartTs()).toNumber(),
    (await fsm.votingEpochDurationSeconds()).toNumber(),
    (await fsm.newSigningPolicyInitializationStartSeconds()).toNumber(),
    (await fsm.voterRegistrationMinDurationSeconds()).toNumber(),
    (await fsm.voterRegistrationMinDurationBlocks()).toNumber()
  );
  return epochSettings;
}
