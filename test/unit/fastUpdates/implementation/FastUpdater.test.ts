import type { BytesLike } from "ethers";
import { sha256 } from "ethers";
import { toChecksumAddress } from "ethereumjs-util";

import privateKeys from "../../../../deployment/test-1020-accounts.json";
import * as util from "../../../utils/key-to-address";
import { Sign, generateSortitionKey, generateVerifiableRandomnessProof, randomInt } from "../../../utils/sortition";
import type { Proof, Signature, SortitionKey } from "../../../utils/sortition";
import { RangeOrSampleFPA } from "../../../utils/fixed-point-arithmetic";
import type {
  FastUpdateIncentiveManagerContract,
  FastUpdateIncentiveManagerInstance,
} from "../../../../typechain-truffle/contracts/fastUpdates/implementation/FastUpdateIncentiveManager";
import type {
  FastUpdaterContract,
  FastUpdaterInstance,
} from "../../../../typechain-truffle/contracts/fastUpdates/implementation/FastUpdater";
import type {
  FlareSystemMockContract,
  FlareSystemMockInstance,
} from "../../../../typechain-truffle/contracts/fastUpdates/mock/FlareSystemMock";
import { ECDSASignature } from "../../../../scripts/libs/protocol/ECDSASignature";
import { getTestFile } from "../../../utils/constants";
import { encodeContractNames } from "../../../utils/test-helpers";
import { Contracts } from "../../../../deployment/scripts/Contracts";
import {
  MockContractContract,
  MockContractInstance,
} from "../../../../typechain-truffle/@gnosis.pm/mock-contract/contracts/MockContract.sol/MockContract";
import { constants, expectEvent, expectRevert, time } from "@openzeppelin/test-helpers";
import {
  FtsoFeedPublisherContract,
  FtsoFeedPublisherInstance,
} from "../../../../typechain-truffle/contracts/ftso/implementation/FtsoFeedPublisher";
import {
  FastUpdatesConfigurationContract,
  FastUpdatesConfigurationInstance,
} from "../../../../typechain-truffle/contracts/fastUpdates/implementation/FastUpdatesConfiguration";
import { FtsoConfigurations } from "../../../../scripts/libs/protocol/FtsoConfigurations";
import { encodePacked, toBN } from "web3-utils";

const FastUpdater = artifacts.require("FastUpdater") as FastUpdaterContract;
const FastUpdateIncentiveManager = artifacts.require(
  "FastUpdateIncentiveManager"
) as FastUpdateIncentiveManagerContract;
const FastUpdatesConfiguration = artifacts.require("FastUpdatesConfiguration") as FastUpdatesConfigurationContract;
const FtsoFeedPublisher = artifacts.require("FtsoFeedPublisher") as FtsoFeedPublisherContract;
const FlareSystemMock = artifacts.require("FlareSystemMock") as FlareSystemMockContract;
const MockContract = artifacts.require("MockContract") as MockContractContract;

let TEST_REWARD_EPOCH: bigint;

const BURN_ADDRESS = "0x000000000000000000000000000000000000dEaD";

const EPOCH_LEN = 1000 as const;
const NUM_ACCOUNTS = 3 as const;
const VOTER_WEIGHT = 1000 as const;
const SUBMISSION_WINDOW = 10 as const;

const DURATION = 8 as const;
const SAMPLE_SIZE = 8;
const RANGE = 2 ** -13;
const SAMPLE_INCREASE_LIMIT = 0.5;
const RANGE_INCREASE_LIMIT = 16 * RANGE;
const SCALE = 1 + RANGE / SAMPLE_SIZE;
const RANGE_INCREASE_PRICE = BigInt(10) ** BigInt(24);
const SAMPLE_SIZE_INCREASE_PRICE = 1425;

const NUM_FEEDS: number = 1000;
const FEED_IDS = [
  FtsoConfigurations.encodeFeedId({ category: 1, name: "BTC/USD" }),
  FtsoConfigurations.encodeFeedId({ category: 1, name: "ETH/USD" }),
];
for (let i = 2; i < NUM_FEEDS; i++) {
  FEED_IDS.push(FtsoConfigurations.encodeFeedId({ category: 1, name: `Test${i}/USD` }));
}
const ANCHOR_FEEDS = [5000, 10000, 20000, 30000, 40000, 50000, 60000, 70000];
for (let i = 8; i < NUM_FEEDS; i++) {
  ANCHOR_FEEDS.push(i * 10000);
}
const DECIMALS = [2, 3];
for (let i = 2; i < NUM_FEEDS; i++) {
  DECIMALS.push(2);
}
const indices: number[] = [];
for (let i = 0; i < NUM_FEEDS; i++) {
  indices.push(i);
}

function shuffleArray(array: any[]) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
}

contract(`FastUpdater.sol; ${getTestFile(__filename)}`, accounts => {
  let fastUpdater: FastUpdaterInstance;
  let fastUpdateIncentiveManager: FastUpdateIncentiveManagerInstance;
  let rewardManagerMock: MockContractInstance;
  let fastUpdatesConfiguration: FastUpdatesConfigurationInstance;
  let ftsoFeedPublisherInterface: FtsoFeedPublisherInstance;
  let ftsoFeedPublisherMock: MockContractInstance;
  let flareSystemMock: FlareSystemMockInstance;
  let fastUpdatesConfigurationMock: MockContractInstance;
  let feeCalculatorMock: MockContractInstance;
  let sortitionKeys: SortitionKey[];
  const weights: number[] = [];
  const voters: string[] = [];
  const governance = accounts[NUM_ACCOUNTS];
  const addressUpdater = accounts[NUM_ACCOUNTS + 1];
  const flareDaemon = accounts[NUM_ACCOUNTS + 2];
  const inflation = accounts[NUM_ACCOUNTS + 3];

  before(async () => {
    expect(FEED_IDS.length).to.equal(NUM_FEEDS);
    expect(DECIMALS.length).to.equal(NUM_FEEDS);

    ftsoFeedPublisherInterface = await FtsoFeedPublisher.new(accounts[0], accounts[0], accounts[0], 100, 200);
    ftsoFeedPublisherMock = await MockContract.new();
    for (let i = 0; i < NUM_FEEDS; i++) {
      const getCurrentFeed = ftsoFeedPublisherInterface.contract.methods.getCurrentFeed(FEED_IDS[i]).encodeABI();
      const feed = web3.eth.abi.encodeParameters(
        ["tuple(uint32,bytes21,int32,uint16,int8)"], // IFtsoFeedPublisher.Feed (uint32 votingRoundId, bytes21 id, int32 value, uint16 turnoutBIPS, int8 decimals)
        [[0, FEED_IDS[i], ANCHOR_FEEDS[i], 6000, DECIMALS[i]]]
      );
      await ftsoFeedPublisherMock.givenCalldataReturn(getCurrentFeed, feed);
    }

    feeCalculatorMock = await MockContract.new();
    const calculateFee = web3.utils.sha3("calculateFeeByIndices(uint256[])")!.slice(0, 10);
    await feeCalculatorMock.givenMethodReturnUint(calculateFee, 1);
  });

  beforeEach(async () => {
    if (!governance) {
      throw new Error("No governance account");
    }

    flareSystemMock = await FlareSystemMock.new(randomInt(2n ** 256n - 1n).toString(), EPOCH_LEN);

    fastUpdatesConfiguration = await FastUpdatesConfiguration.new(accounts[0], governance, addressUpdater);

    rewardManagerMock = await MockContract.new();

    fastUpdateIncentiveManager = await FastUpdateIncentiveManager.new(
      accounts[0],
      governance,
      addressUpdater,
      RangeOrSampleFPA(SAMPLE_SIZE),
      RangeOrSampleFPA(RANGE),
      RangeOrSampleFPA(SAMPLE_INCREASE_LIMIT),
      RangeOrSampleFPA(RANGE_INCREASE_LIMIT),
      SAMPLE_SIZE_INCREASE_PRICE,
      RANGE_INCREASE_PRICE.toString(),
      DURATION
    );

    TEST_REWARD_EPOCH = BigInt((await flareSystemMock.getCurrentRewardEpochId()).toString());

    sortitionKeys = new Array<SortitionKey>(NUM_ACCOUNTS);
    for (let i = 0; i < NUM_ACCOUNTS; i++) {
      const key: SortitionKey = generateSortitionKey();
      sortitionKeys[i] = key;
      const x = "0x" + web3.utils.padLeft(key.pk.x.toString(16), 64);
      const y = "0x" + web3.utils.padLeft(key.pk.y.toString(16), 64);
      const policy = {
        pk1: x,
        pk2: y,
        weight: VOTER_WEIGHT,
      };

      let prvKey = privateKeys[i + 1].privateKey.slice(2);
      let prvkeyBuffer = Buffer.from(prvKey, "hex");
      let [x2, y2] = util.privateKeyToPublicKeyPair(prvkeyBuffer);
      let addr = toChecksumAddress("0x" + util.publicKeyToEthereumAddress(x2, y2).toString("hex"));
      voters.push(addr);
      await flareSystemMock.registerAsVoter(TEST_REWARD_EPOCH.toString(), addr, policy);
    }

    // Create local instance of Fast Updater contract
    fastUpdater = await FastUpdater.new(
      accounts[0],
      governance,
      addressUpdater,
      flareDaemon,
      await time.latest(),
      90,
      SUBMISSION_WINDOW
    );
    await fastUpdater.setFeeDestination(BURN_ADDRESS, { from: governance });

    await fastUpdateIncentiveManager.updateContractAddresses(
      encodeContractNames([
        Contracts.ADDRESS_UPDATER,
        Contracts.FLARE_SYSTEMS_MANAGER,
        Contracts.INFLATION,
        Contracts.REWARD_MANAGER,
        Contracts.FAST_UPDATER,
        Contracts.FAST_UPDATES_CONFIGURATION,
      ]),
      [
        addressUpdater,
        flareSystemMock.address,
        inflation,
        rewardManagerMock.address,
        fastUpdater.address,
        fastUpdatesConfiguration.address,
      ],
      { from: addressUpdater }
    );

    await fastUpdatesConfiguration.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FAST_UPDATER]),
      [addressUpdater, fastUpdater.address],
      { from: addressUpdater }
    );

    await fastUpdater.updateContractAddresses(
      encodeContractNames([
        Contracts.ADDRESS_UPDATER,
        Contracts.FLARE_SYSTEMS_MANAGER,
        Contracts.FAST_UPDATE_INCENTIVE_MANAGER,
        Contracts.VOTER_REGISTRY,
        Contracts.FAST_UPDATES_CONFIGURATION,
        Contracts.FTSO_FEED_PUBLISHER,
        Contracts.FEE_CALCULATOR,
      ]),
      [
        addressUpdater,
        flareSystemMock.address,
        fastUpdateIncentiveManager.address,
        flareSystemMock.address,
        fastUpdatesConfiguration.address,
        ftsoFeedPublisherMock.address,
        feeCalculatorMock.address
      ],
      { from: addressUpdater }
    );

    // so that the circular list of score cutoff values is filled
    for (let i = 0; i <= SUBMISSION_WINDOW; i++) {
      const tx = await fastUpdater.daemonize({
        from: flareDaemon,
      });
      expect(tx.receipt.gasUsed).to.be.lessThan(4000000);
    }
  });

  describe("Tests with 1000 feeds", async () => {
    beforeEach(async () => {
      await fastUpdatesConfiguration.addFeeds(
        FEED_IDS.slice(0, NUM_FEEDS / 2).map(id => {
          return { feedId: id, rewardBandValue: 2000, inflationShare: 200 };
        }),
        { from: governance }
      );
      await fastUpdatesConfiguration.addFeeds(
        FEED_IDS.slice(NUM_FEEDS / 2, NUM_FEEDS).map(id => {
          return { feedId: id, rewardBandValue: 2000, inflationShare: 200 };
        }),
        { from: governance }
      );
    });

    it("should submit updates", async () => {
      let submissionBlockNum;
      for (let i = 0; i < NUM_ACCOUNTS; i++) {
        const weight = await fastUpdater.currentSortitionWeight(voters[i]);
        weights[i] = weight.toNumber();
        expect(weights[i]).to.equal(Math.ceil(4096 / NUM_ACCOUNTS));
      }

      // Fetch current feeds from the contract
      const startingFeeds = await fastUpdater.fetchCurrentFeeds.call(indices, { value: "1" });
      const startingFeedsVal: number[] = startingFeeds[0].map((x: BN) => x.toNumber());
      const startingFeedsDec: number[] = startingFeeds[1].map((x: BN) => x.toNumber());
      var expectedFeeds: number[] = [];
      var expectedDecimals: number[] = [];
      for (let i = 0; i < NUM_FEEDS; i++) {
        expectedFeeds[i] = ANCHOR_FEEDS[i];
        expectedDecimals[i] = DECIMALS[i];
        while (Math.floor(expectedFeeds[i] * (SCALE - 1)) < 8) {
          expectedFeeds[i] *= 10;
          expectedDecimals[i] += 1;
        }

        expect(startingFeedsVal[i]).to.equal(expectedFeeds[i]);
        expect(startingFeedsDec[i]).to.equal(expectedDecimals[i]);
      }

      // Make feed updates to the contract
      // test with feeds of various length
      let feed = "+--+00--".repeat(16);
      let deltas = "0x" + "7d0f".repeat(16);
      const differentFeed = "-+0000++".repeat(8) + "-+00";
      let differentDeltas = "d005".repeat(8) + "d0";
      deltas += differentDeltas;
      feed += differentFeed;
      differentDeltas = "0x" + differentDeltas;

      let numSubmitted = 0;
      while (true) {
        submissionBlockNum = (await web3.eth.getBlockNumber()).toString();
        const baseSeed = (await flareSystemMock.getSeed(await flareSystemMock.getCurrentRewardEpochId())).toString();
        for (let i = 0; i < NUM_ACCOUNTS; i++) {
          submissionBlockNum = (await web3.eth.getBlockNumber()).toString();
          const scoreCutoff = BigInt((await fastUpdater.blockScoreCutoff(submissionBlockNum)).toString());

          for (let rep = 0; rep < (weights[i] ?? 0); rep++) {
            const repStr = rep.toString();
            const proof: Proof = generateVerifiableRandomnessProof(
              sortitionKeys[i] as SortitionKey,
              baseSeed,
              submissionBlockNum,
              repStr
            );

            const sortitionCredential = {
              replicate: repStr,
              gamma: {
                x: proof.gamma.x.toString(),
                y: proof.gamma.y.toString(),
              },
              c: proof.c.toString(),
              s: proof.s.toString(),
            };

            if (proof.gamma.x < scoreCutoff) {
              let update = deltas;
              if (numSubmitted == 1) {
                // use a different update with different length for this test
                update = differentDeltas;
              }

              const msg = web3.eth.abi.encodeParameters(
                ["uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "bytes"],
                [
                  submissionBlockNum,
                  repStr,
                  proof.gamma.x.toString(),
                  proof.gamma.y.toString(),
                  proof.c.toString(),
                  proof.s.toString(),
                  update,
                ]
              );
              const signature = await ECDSASignature.signMessageHash(
                sha256(msg as BytesLike),
                privateKeys[i + 1].privateKey
              );

              const newFastUpdate = {
                sortitionBlock: submissionBlockNum,
                sortitionCredential: sortitionCredential,
                deltas: update,
                signature: signature,
              };

              // Submit updates to the contract
              const tx = await fastUpdater.submitUpdates(newFastUpdate, {
                from: accounts[0],
              });
              expect(tx.receipt.gasUsed).to.be.lessThan(300000);
              console.log(`Gas used for submitting updates: ${tx.receipt.gasUsed}`);
              expectEvent(tx, "FastUpdateFeedsSubmitted", { signingPolicyAddress: voters[i] });
              expect((await fastUpdater.numberOfUpdatesInBlock(await web3.eth.getBlockNumber())).toNumber()).to.be.gt(
                0
              );

              let caughtError = false;
              try {
                // test if submitting again gives error
                await fastUpdater.submitUpdates(newFastUpdate, {
                  from: voters[i],
                });
              } catch (e) {
                expect(e).to.be.not.empty;
                caughtError = true;
              }
              expect(caughtError).to.equal(true);

              numSubmitted++;
              if (numSubmitted >= 2) break;
            }
          }
          if (numSubmitted >= 2) break;
        }
        if (numSubmitted > 0) break;
      }

      // See effect of feed updates made
      let newFeeds: number[] = [];
      for (let i = 0; i < NUM_FEEDS; i++) {
        let newFeed = startingFeedsVal[i];
        for (let j = 0; j < numSubmitted; j++) {
          let delta = feed[i];
          if (j == 1) {
            delta = differentFeed[i];
          }

          if (delta == "+") {
            newFeed *= SCALE;
          }
          if (delta == "-") {
            newFeed /= SCALE;
          }
          newFeed = Math.floor(newFeed);
        }
        newFeeds.push(newFeed);
      }

      shuffleArray(indices);
      let allCurrentFeeds = await fastUpdater.fetchAllCurrentFeeds.call({ value: "1" });
      expect(allCurrentFeeds[0].length).to.be.equal(NUM_FEEDS);
      let feeds = await fastUpdater.fetchCurrentFeeds.call(indices, { value: "1" });
      let feedsVal: number[] = feeds[0].map((x: BN) => x.toNumber());
      let feedsDec: number[] = feeds[1].map((x: BN) => x.toNumber());
      for (let i = 0; i < NUM_FEEDS; i++) {
        const index = indices.indexOf(i);
        expect(feedsVal[index]).to.be.equal(newFeeds[i]);
        expect(feedsDec[index]).to.be.equal(expectedDecimals[i]);
        expect(allCurrentFeeds[1][i]).to.be.equal(newFeeds[i]);
        expect(allCurrentFeeds[2][i]).to.be.equal(expectedDecimals[i]);
        expect(allCurrentFeeds[0][i]).to.be.equal(FEED_IDS[i]);
      }

      const tx = await fastUpdater.daemonize({
        from: flareDaemon,
      });
      expect(tx.receipt.gasUsed).to.be.lessThan(4000000);

      // set addresses that can fetch the feeds for free
      await fastUpdater.setFreeFetchAddresses([accounts[0], accounts[123]], { from: governance });

      expect(await fastUpdater.getFreeFetchAddresses()).to.be.deep.equal([accounts[0], accounts[123]]);

      // accounts[0] can fetch the feeds for free
      feedsVal = (await fastUpdater.fetchCurrentFeeds.call(indices, { value: "0" }))[0].map((x: BN) => x.toNumber());
      // accounts[1] still needs to pay
      await expectRevert(fastUpdater.fetchCurrentFeeds(indices, { value: "0", from: accounts[1] }), "too low fee");

      // accounts[0] still needs to pay if calling fetchAllCurrentFeeds
      await expectRevert(fastUpdater.fetchAllCurrentFeeds({ value: "0" }), "too low fee");
      allCurrentFeeds = await fastUpdater.fetchAllCurrentFeeds.call({ value: "1" });
      expect(allCurrentFeeds[0].length).to.be.equal(NUM_FEEDS);
      for (let i = 0; i < NUM_FEEDS; i++) {
        const index = indices.indexOf(i);
        expect(feedsVal[index]).to.be.equal(newFeeds[i]);
        expect(allCurrentFeeds[1][i]).to.be.equal(newFeeds[i]);
      }

      const noOfUpdates = await fastUpdater.numberOfUpdates(10);
      expect(noOfUpdates.reduce((a, b) => a + b.toNumber(), 0)).to.be.equal(numSubmitted);

      // destination fee address should receive the fee
      const balanceBefore = await web3.eth.getBalance(BURN_ADDRESS);
      await fastUpdater.fetchCurrentFeeds(indices, { value: "1", from: accounts[1] });
      expect(Number(await web3.eth.getBalance(BURN_ADDRESS)) - (Number(balanceBefore))).to.be.equal(1);
    });

    it("should daemonize and emit all current feeds and decimals", async () => {
      // increase time to move voting round
      await time.increase(12000);

      const tx = await fastUpdater.daemonize({
        from: flareDaemon,
      });

      var expectedFeeds: number[] = [];
      var expectedDecimals: number[] = [];
      for (let i = 0; i < NUM_FEEDS; i++) {
        expectedFeeds[i] = ANCHOR_FEEDS[i];
        expectedDecimals[i] = DECIMALS[i];
        while (Math.floor(expectedFeeds[i] * (SCALE - 1)) < 8) {
          expectedFeeds[i] *= 10;
          expectedDecimals[i] += 1;
        }
      }

      expectEvent(tx, "FastUpdateFeeds", {
        feeds: expectedFeeds.map(x => toBN(x)),
        decimals: expectedDecimals.map(x => toBN(x)),
      });
    });
  });

  describe("Basic tests", async () => {
    beforeEach(async () => {
      await fastUpdatesConfiguration.addFeeds(
        FEED_IDS.slice(0, 20).map(id => {
          return { feedId: id, rewardBandValue: 2000, inflationShare: 200 };
        }),
        { from: governance }
      );
    });

    it("should revert fetching feeds if the index bigger than the number of feeds", async () => {
      await expectRevert.unspecified(fastUpdater.fetchCurrentFeeds([0, 1, NUM_FEEDS + 2], { value: "1" }));
    });

    it("should revert if deploying contract with invalid parameters", async () => {
      await expectRevert(
        FastUpdater.new(
          accounts[0],
          governance,
          addressUpdater,
          constants.ZERO_ADDRESS,
          await time.latest(),
          90,
          SUBMISSION_WINDOW
        ),
        "flare daemon zero"
      );

      await expectRevert(
        FastUpdater.new(
          accounts[0],
          governance,
          addressUpdater,
          flareDaemon,
          await time.latest(),
          0,
          SUBMISSION_WINDOW
        ),
        "voting epoch duration zero"
      );
    });

    it("should verify public key", async () => {
      const key: SortitionKey = generateSortitionKey();
      const msg = sha256(encodePacked({ value: voters[1], type: "address" }) ?? "");

      const signature: Signature = Sign(key, msg);
      const pkx = "0x" + web3.utils.padLeft(key.pk.x.toString(16), 64);
      const pky = "0x" + web3.utils.padLeft(key.pk.y.toString(16), 64);
      await fastUpdater.verifyPublicKey(
        voters[1],
        pkx,
        pky,
        web3.eth.abi.encodeParameters(
          ["uint256", "uint256", "uint256"],
          [signature.s.toString(), signature.r.x.toString(), signature.r.y.toString()]
        )
      );
    });

    it("should revert if submitting updates without registering public key", async () => {
      const policy = {
        pk1: "0x" + "0".repeat(64),
        pk2: "0x" + "0".repeat(64),
        weight: VOTER_WEIGHT,
      };

      let prvKey = privateKeys[11].privateKey.slice(2);
      let prvkeyBuffer = Buffer.from(prvKey, "hex");
      let [x2, y2] = util.privateKeyToPublicKeyPair(prvkeyBuffer);
      let addr = toChecksumAddress("0x" + util.publicKeyToEthereumAddress(x2, y2).toString("hex"));
      await flareSystemMock.registerAsVoter(TEST_REWARD_EPOCH.toString(), addr, policy);
      const signature = await ECDSASignature.signMessageHash(
        "0x1122334455667788990011223344556677889900112233445566778899001122",
        privateKeys[11].privateKey
      );

      await expectRevert(
        fastUpdater.submitUpdates(
          {
            sortitionBlock: (await web3.eth.getBlockNumber()).toString(),
            sortitionCredential: {
              replicate: 0,
              gamma: { x: 0, y: 0 },
              c: 0,
              s: 0,
            },
            deltas: "0x",
            signature: signature,
          },
          { from: voters[0] }
        ),
        "Public key not registered"
      );
    });

    it("should revert if not calling daemonize from flare daemon", async () => {
      await expectRevert(fastUpdater.daemonize({ from: governance }), "only flare daemon");
    });

    it("should set submission window and revert submitting updates if block too high", async () => {
      const signature = await ECDSASignature.signMessageHash(
        "0x1122334455667788990011223344556677889900112233445566778899001122",
        privateKeys[11].privateKey
      );

      await fastUpdater.setSubmissionWindow(2, { from: governance });
      expect((await fastUpdater.submissionWindow()).toNumber()).to.equal(2);

      await expectRevert(
        fastUpdater.submitUpdates(
          {
            sortitionBlock: 3,
            sortitionCredential: {
              replicate: 0,
              gamma: { x: 0, y: 0 },
              c: 0,
              s: 0,
            },
            deltas: "0x",
            signature: signature,
          },
          { from: voters[0] }
        ),
        "Updates no longer accepted for the given block"
      );
    });

    it("should revert if not calling setSubmissionWindow from governance", async () => {
      await expectRevert(fastUpdater.setSubmissionWindow(2, { from: flareDaemon }), "only governance");
    });

    it("should revert setting too big setSubmissionWindow", async () => {
      await expectRevert(fastUpdater.setSubmissionWindow(100, { from: governance }), "Submission window too big");
    });

    it("should revert getting numberOfUpdates too far into the past", async () => {
      await expectRevert(fastUpdater.numberOfUpdates(101), "History size too big");
    });

    it("should revert getting numberOfUpdatesInBlock for future block or too far into the past", async () => {
      const currentBlockNumber = await web3.eth.getBlockNumber();
      await expectRevert(
        fastUpdater.numberOfUpdatesInBlock(currentBlockNumber + 1),
        "The given block is no longer or not yet available"
      );
      if (currentBlockNumber < 100) {
        await time.advanceBlockTo(100);
      }
      await expectRevert(fastUpdater.numberOfUpdatesInBlock(0), "The given block is no longer or not yet available");
    });

    it("should revert submit updates if updates are not yet available", async () => {
      const signature = await ECDSASignature.signMessageHash(
        "0x1122334455667788990011223344556677889900112233445566778899001122",
        privateKeys[11].privateKey
      );

      await expectRevert(
        fastUpdater.submitUpdates(
          {
            sortitionBlock: 12345,
            sortitionCredential: {
              replicate: 0,
              gamma: { x: 0, y: 0 },
              c: 0,
              s: 0,
            },
            deltas: "0x",
            signature: signature,
          },
          { from: voters[0] }
        ),
        "Updates not yet available for the given block"
      );
    });

    it("should revert submit updates if more updates than available feeds", async () => {
      const signature = await ECDSASignature.signMessageHash(
        "0x1122334455667788990011223344556677889900112233445566778899001122",
        privateKeys[11].privateKey
      );
      const deltas = "0x" + new Array(FEED_IDS.length + 1).join("1");
      const currentBlock = await web3.eth.getBlockNumber();

      await expectRevert(
        fastUpdater.submitUpdates(
          {
            sortitionBlock: currentBlock,
            sortitionCredential: {
              replicate: 0,
              gamma: { x: 0, y: 0 },
              c: 0,
              s: 0,
            },
            deltas: deltas,
            signature: signature,
          },
          { from: voters[0] }
        ),
        "More updates than available feeds"
      );
    });

    it("should increase the score cutoff", async () => {
      const rangeIncrease = RangeOrSampleFPA(RANGE);
      const rangeLimit = RangeOrSampleFPA(4 * RANGE);
      const offer = {
        rangeIncrease: rangeIncrease.toString(),
        rangeLimit: rangeLimit.toString(),
      };
      let blockNum = await web3.eth.getBlockNumber();
      const scoreCutoff = BigInt((await fastUpdater.blockScoreCutoff(blockNum.toString())).toString());

      await fastUpdateIncentiveManager.offerIncentive(offer, {
        from: accounts[1],
        value: "1000000000000000000000000000",
      });

      await fastUpdater.daemonize({
        from: flareDaemon,
      });

      const oldScoreCutoff = BigInt((await fastUpdater.blockScoreCutoff(blockNum.toString())).toString());
      expect(oldScoreCutoff).to.be.equal(scoreCutoff);

      blockNum = await web3.eth.getBlockNumber();
      const newScoreCutoff = BigInt((await fastUpdater.blockScoreCutoff((blockNum + 1).toString())).toString());

      expect(newScoreCutoff).to.be.greaterThan(scoreCutoff);

      await expectRevert(
        fastUpdater.blockScoreCutoff((blockNum + 2).toString()),
        "score cutoff not available for the given block"
      );
      await expectRevert(
        fastUpdater.blockScoreCutoff((blockNum - SUBMISSION_WINDOW).toString()),
        "score cutoff not available for the given block"
      );
    });

    it("should revert fetching current feeds when sending fee if address is on free fetch list", async () => {
      await fastUpdater.setFreeFetchAddresses([accounts[0]], { from: governance });
      await fastUpdater.setFeeDestination(BURN_ADDRESS, { from: governance });
      await expectRevert(fastUpdater.fetchCurrentFeeds([0, 1], { value: "100", from: accounts[0] }), "no fee expected");
    });

    it("should revert setting fee destination to address zero", async () => {
      await expectRevert(fastUpdater.setFeeDestination(constants.ZERO_ADDRESS, { from: governance }), "address zero");
    });

    it("should set destination fee address", async () => {
      await fastUpdater.setFeeDestination(BURN_ADDRESS, { from: governance });
      expect(await fastUpdater.feeDestination()).to.be.equal(BURN_ADDRESS);
    });

    it("should revert setting fee destination if not from governance", async () => {
      await expectRevert(fastUpdater.setFeeDestination(constants.ZERO_ADDRESS), "only governance");
    });

    it("should revert setting free fetch addresses if not from governance", async () => {
      await expectRevert(fastUpdater.setFreeFetchAddresses([]), "only governance");
    });

    describe("Remove and reset feeds", async () => {
      beforeEach(async () => {
        fastUpdatesConfigurationMock = await MockContract.new();

        await fastUpdater.updateContractAddresses(
          encodeContractNames([
            Contracts.ADDRESS_UPDATER,
            Contracts.FLARE_SYSTEMS_MANAGER,
            Contracts.FAST_UPDATE_INCENTIVE_MANAGER,
            Contracts.VOTER_REGISTRY,
            Contracts.FAST_UPDATES_CONFIGURATION,
            Contracts.FTSO_FEED_PUBLISHER,
            Contracts.FEE_CALCULATOR,
          ]),
          [
            addressUpdater,
            flareSystemMock.address,
            fastUpdateIncentiveManager.address,
            flareSystemMock.address,
            fastUpdatesConfigurationMock.address,
            ftsoFeedPublisherMock.address,
            feeCalculatorMock.address
          ],
          { from: addressUpdater }
        );
      });

      it("should revert removing feeds if called from a wrong address", async () => {
        await expectRevert(fastUpdater.removeFeeds([0, 1], { from: governance }), "only fast updates configuration");
      });

      it("should remove feeds", async () => {
        await fastUpdater.updateContractAddresses(
          encodeContractNames([
            Contracts.ADDRESS_UPDATER,
            Contracts.FLARE_SYSTEMS_MANAGER,
            Contracts.FAST_UPDATE_INCENTIVE_MANAGER,
            Contracts.VOTER_REGISTRY,
            Contracts.FAST_UPDATES_CONFIGURATION,
            Contracts.FTSO_FEED_PUBLISHER,
            Contracts.FEE_CALCULATOR
          ]),
          [
            addressUpdater,
            flareSystemMock.address,
            fastUpdateIncentiveManager.address,
            flareSystemMock.address,
            accounts[123],
            ftsoFeedPublisherMock.address,
            feeCalculatorMock.address
          ],
          { from: addressUpdater }
        );

        let currentFeeds = await fastUpdater.fetchCurrentFeeds.call([0, 1, 8, 19], { value: "1" });
        expect(currentFeeds[0][0].toNumber()).to.equals(5000000);
        expect(currentFeeds[0][1].toNumber()).to.equals(1000000);
        expect(currentFeeds[0][2].toNumber()).to.equals(800000);
        expect(currentFeeds[0][3].toNumber()).to.equals(1900000);
        expect(currentFeeds[1][0].toNumber()).to.equals(5);
        expect(currentFeeds[1][1].toNumber()).to.equals(5);
        expect(currentFeeds[1][2].toNumber()).to.equals(3);
        expect(currentFeeds[1][3].toNumber()).to.equals(3);

        await fastUpdater.removeFeeds([0, 1, 19], { from: accounts[123] });
        currentFeeds = await fastUpdater.fetchCurrentFeeds.call([0, 1, 8, 19], { value: "1" });
        expect(currentFeeds[0][0].toNumber()).to.equals(0);
        expect(currentFeeds[0][1].toNumber()).to.equals(0);
        expect(currentFeeds[0][2].toNumber()).to.equals(800000);
        expect(currentFeeds[0][3].toNumber()).to.equals(0);
        expect(currentFeeds[1][0].toNumber()).to.equals(0);
        expect(currentFeeds[1][1].toNumber()).to.equals(0);
        expect(currentFeeds[1][2].toNumber()).to.equals(3);
        expect(currentFeeds[1][3].toNumber()).to.equals(0);
      });

      it("should revert resetting feeds if called from a wrong address", async () => {
        await expectRevert(
          fastUpdater.resetFeeds([0, 1], { from: accounts[80] }),
          "only fast updates configuration or governance"
        );
      });

      it("should revert resetting feeds if index is not supported", async () => {
        const getFeedId = fastUpdatesConfiguration.contract.methods.getFeedId([0]).encodeABI();
        const feedId = web3.eth.abi.encodeParameters(["bytes21"], ["0x".padEnd(42, "0")]);
        await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedId, feedId);
        await expectRevert(fastUpdater.resetFeeds([0], { from: governance }), "index not supported");
      });

      it("should revert resetting feeds if feed is too old", async () => {
        const getFeedId = fastUpdatesConfiguration.contract.methods.getFeedId([0]).encodeABI();
        const feedId = web3.eth.abi.encodeParameters(["bytes21"], [FEED_IDS[0]]);
        await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedId, feedId);

        await time.increase(1200000);
        await expectRevert(fastUpdater.resetFeeds([0], { from: governance }), "feed too old");
      });

      it("should revert resetting feeds if feed value is zero", async () => {
        const getFeedId = fastUpdatesConfiguration.contract.methods.getFeedId([5]).encodeABI();
        const encodedFeedId = FtsoConfigurations.encodeFeedId({ category: 1, name: "TestValue0/USD" });
        const feedId = web3.eth.abi.encodeParameters(["bytes21"], [encodedFeedId]);
        await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedId, feedId);

        const getCurrentFeed = ftsoFeedPublisherInterface.contract.methods.getCurrentFeed(encodedFeedId).encodeABI();
        const feed = web3.eth.abi.encodeParameters(
          ["tuple(uint32,bytes21,int32,uint16,int8)"], // IFtsoFeedPublisher.Feed (uint32 votingRoundId, bytes21 id, int32 value, uint16 turnoutBIPS, int8 decimals)
          [[0, encodedFeedId, 0, 6000, 5]]
        );
        await ftsoFeedPublisherMock.givenCalldataReturn(getCurrentFeed, feed);

        await expectRevert(fastUpdater.resetFeeds([5], { from: governance }), "feed value zero or negative");
      });

      it("should reset feeds", async () => {
        let indices = [0, 2, 8, 11];
        let newDecimals = [5, 6, 7, -8];
        for (let i = 0; i < indices.length; i++) {
          const getFeedId = fastUpdatesConfiguration.contract.methods.getFeedId([indices[i]]).encodeABI();
          const feedId = web3.eth.abi.encodeParameters(["bytes21"], [FEED_IDS[i]]);
          await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedId, feedId);
        }

        const getFeedIds = fastUpdatesConfiguration.contract.methods.getFeedIds().encodeABI();
        const feedIds = web3.eth.abi.encodeParameters(["bytes21[]"], [FEED_IDS.slice(0, 20)]);
        await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedIds, feedIds);

        for (let i = 0; i < indices.length; i++) {
          const getCurrentFeed = ftsoFeedPublisherInterface.contract.methods.getCurrentFeed(FEED_IDS[i]).encodeABI();
          let feed;
          feed = web3.eth.abi.encodeParameters(
            ["tuple(uint32,bytes21,int32,uint16,int8)"], // IFtsoFeedPublisher.Feed (uint32 votingRoundId, bytes21 id, int32 value, uint16 turnoutBIPS, int8 decimals)
            [[0, FEED_IDS[i], (i + 1) * 148, 6000, newDecimals[i]]]
          );
          await ftsoFeedPublisherMock.givenCalldataReturn(getCurrentFeed, feed);
        }

        let updateDecimals = DECIMALS.slice();
        let updatedAnchorFeeds = ANCHOR_FEEDS.slice();
        for (let i = 0; i < indices.length; i++) {
          updateDecimals[indices[i]] = newDecimals[i];
          updatedAnchorFeeds[indices[i]] = (i + 1) * 148;
          while (Math.floor(updatedAnchorFeeds[indices[i]] * (SCALE - 1)) < 8) {
            updatedAnchorFeeds[indices[i]] *= 10;
            updateDecimals[indices[i]] += 1;
          }
        }

        await fastUpdater.resetFeeds(indices, { from: governance });
        let currentFeeds = await fastUpdater.fetchCurrentFeeds.call([0, 2, 8, 11, 13], { value: "1" });
        for (let i = 0; i < indices.length; i++) {
          expect(currentFeeds[0][i].toNumber()).to.equals(updatedAnchorFeeds[indices[i]]);
          expect(currentFeeds[1][i].toNumber()).to.equals(updateDecimals[indices[i]]);
        }
        expect(currentFeeds[0][4].toNumber()).to.equals(1300000);
        expect(currentFeeds[1][4].toNumber()).to.equals(3);

        let allCurrentFeeds = await fastUpdater.fetchAllCurrentFeeds.call({ value: "1" });
        expect(allCurrentFeeds[0].length).to.be.equal(20);
        for (let i = 0; i < 20; i++) {
          while (Math.floor(updatedAnchorFeeds[i] * (SCALE - 1)) < 8) {
            updatedAnchorFeeds[i] *= 10;
            updateDecimals[i] += 1;
          }
          expect(allCurrentFeeds[1][i]).to.be.equal(updatedAnchorFeeds[i]);
          expect(allCurrentFeeds[2][i]).to.be.equal(updateDecimals[i]);
          expect(allCurrentFeeds[0][i]).to.be.equal(FEED_IDS[i]);
        }
      });
    });
  });
});
