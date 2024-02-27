import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "./Contracts";
import { FlareSystemsManagerContract, FtsoRewardOffersManagerContract } from "../../typechain-truffle";
import { FtsoRewardOffersManagerInstance } from "../../typechain-truffle/contracts/ftso/implementation/FtsoRewardOffersManager";
import { FtsoConfigurations } from "../../scripts/libs/protocol/FtsoConfigurations";
import { ChainParameters } from "../chain-config/chain-parameters";
import { sleep } from "../tasks/run-simulation";
import { FlareSystemsManagerInstance } from "../../typechain-truffle/contracts/protocol/implementation/FlareSystemsManager";

export async function offerRewards(
  hre: HardhatRuntimeEnvironment,
  offerSenderKey: string,
  contracts: Contracts,
  parameters: ChainParameters
) {
  const offerSender = hre.web3.eth.accounts.privateKeyToAccount(offerSenderKey);

  const feeds = parameters.ftsoInflationConfigurations[0].feedNames;
  const offers = generateOffers(feeds, parameters.minimalRewardsOfferValueNAT, offerSender.address);

  const FtsoRewardOffersManager: FtsoRewardOffersManagerContract = artifacts.require("FtsoRewardOffersManager");
  const offerManager = await FtsoRewardOffersManager.at(
    contracts.getContractAddress(Contracts.FTSO_REWARD_OFFERS_MANAGER)
  );

  const FlareSystemsManager: FlareSystemsManagerContract = artifacts.require("FlareSystemsManager");
  const systemsManager: FlareSystemsManagerInstance = await FlareSystemsManager.at(
    contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER)
  );
  const currentRewardEpochId = (await systemsManager.getCurrentRewardEpochId()).toNumber();

  await runOfferRewards(currentRewardEpochId + 1, offerManager, offers, offerSender.address);
}

async function runOfferRewards(
  nextRewardEpochId: number,
  ofm: FtsoRewardOffersManagerInstance,
  offers: any[],
  offerSender: string
) {
  const batchSize = 75;
  const offerBatches = [];
  for (let i = 0; i < offers.length; i += batchSize) {
    const batch = offers.slice(i, i + batchSize);
    offerBatches.push(batch);
  }

  for (const batch of offerBatches) {
    let rewards = web3.utils.toBN(0);
    for (const offer of batch) {
      rewards = rewards.add(web3.utils.toBN(offer.amount));
    }
    try {
      console.log("Offering rewards..., total value: " + rewards.toString());
      await ofm.offerRewards(nextRewardEpochId, batch, { value: rewards.toString(), from: offerSender });
      console.log(`Rewards offered: ${batch.length}`);
      await sleep(500);
    } catch (e) {
      console.error("Rewards not offered: " + e);
    }
  }
}

function generateOffers(feeds: string[], amountNat: number, offerSender: string) {
  const offers = [];
  const amount = web3.utils.toWei(amountNat.toString());
  for (const feed of feeds) {
    offers.push({
      amount: amount,
      feedName: FtsoConfigurations.encodeFeedName(feed),
      minRewardedTurnoutBIPS: 5000,
      primaryBandRewardSharePPM: 450000,
      secondaryBandWidthPPM: 50000,
      claimBackAddress: offerSender,
    });
  }
  return offers;
}
