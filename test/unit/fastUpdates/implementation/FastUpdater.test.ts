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

const EPOCH_LEN = 1000 as const;
const NUM_ACCOUNTS = 3 as const;
const VOTER_WEIGHT = 1000 as const;
const SUBMISSION_WINDOW = 10 as const;

const DURATION = 8 as const;
const SAMPLE_SIZE = 16
const RANGE = 2**-5
const SAMPLE_INCREASE_LIMIT = 5
const SCALE = 1 + RANGE / SAMPLE_SIZE;
const RANGE_INCREASE_PRICE = 5 as const;

const NUM_FEEDS = 250 as const;
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

contract(`FastUpdater.sol; ${getTestFile(__filename)}`, accounts => {
  let fastUpdater: FastUpdaterInstance;
  let fastUpdateIncentiveManager: FastUpdateIncentiveManagerInstance;
  let rewardManagerMock: MockContractInstance;
  let fastUpdatesConfiguration: FastUpdatesConfigurationInstance;
  let ftsoFeedPublisherInterface: FtsoFeedPublisherInstance;
  let ftsoFeedPublisherMock: MockContractInstance;
  let flareSystemMock: FlareSystemMockInstance;
  let fastUpdatesConfigurationMock: MockContractInstance;
  let sortitionKeys: SortitionKey[];
  const weights: number[] = [];
  const voters: string[] = [];
  const governance = accounts[NUM_ACCOUNTS];
  const addressUpdater = accounts[NUM_ACCOUNTS + 1];
  const flareDaemon = accounts[NUM_ACCOUNTS + 2];
  const inflation = accounts[NUM_ACCOUNTS + 3];

  beforeEach(async () => {
    if (!governance) {
      throw new Error("No governance account");
    }

    flareSystemMock = await FlareSystemMock.new(randomInt(2n ** 256n - 1n).toString(), EPOCH_LEN);

    expect(FEED_IDS.length).to.equal(NUM_FEEDS);
    expect(DECIMALS.length).to.equal(NUM_FEEDS);

    fastUpdatesConfiguration = await FastUpdatesConfiguration.new(accounts[0], governance, addressUpdater);


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

    rewardManagerMock = await MockContract.new();

    fastUpdateIncentiveManager = await FastUpdateIncentiveManager.new(
      accounts[0],
      governance,
      addressUpdater,
      RangeOrSampleFPA(SAMPLE_SIZE),
      RangeOrSampleFPA(RANGE),
      RangeOrSampleFPA(SAMPLE_INCREASE_LIMIT),
      RANGE_INCREASE_PRICE,
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
      encodeContractNames([
        Contracts.ADDRESS_UPDATER,
        Contracts.FAST_UPDATER,
      ]),
      [
        addressUpdater,
        fastUpdater.address,
      ],
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
      ]),
      [
        addressUpdater,
        flareSystemMock.address,
        fastUpdateIncentiveManager.address,
        flareSystemMock.address,
        fastUpdatesConfiguration.address,
        ftsoFeedPublisherMock.address,
      ],
      { from: addressUpdater }
    );

    await fastUpdatesConfiguration.addFeeds(
      FEED_IDS.map(id => {
        return { feedId: id, rewardBandValue: 2000, inflationShare: 200 };
      }),
      { from: governance }
    );

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

  it("should submit updates", async () => {
    let submissionBlockNum;
    for (let i = 0; i < NUM_ACCOUNTS; i++) {
      const weight = await fastUpdater.currentSortitionWeight(voters[i]);
      weights[i] = weight.toNumber();
      expect(weights[i]).to.equal(Math.ceil(4096 / NUM_ACCOUNTS));
    }

    // Fetch current feeds from the contract
    const startingFeeds: number[] = (await fastUpdater.fetchCurrentFeeds(indices))[0].map((x: BN) => x.toNumber());
    for (let i = 0; i < NUM_FEEDS; i++) {
      expect(startingFeeds[i]).to.equal(ANCHOR_FEEDS[i]);
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
    for (;;) {
      submissionBlockNum = (await web3.eth.getBlockNumber()).toString();
      const scoreCutoff = BigInt((await fastUpdater.currentScoreCutoff()).toString());
      const baseSeed = (await flareSystemMock.getSeed(await flareSystemMock.getCurrentRewardEpochId())).toString();
      for (let i = 0; i < NUM_ACCOUNTS; i++) {
        submissionBlockNum = (await web3.eth.getBlockNumber()).toString();

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
            expectEvent(tx, "FastUpdateFeedsSubmitted", { signingPolicyAddress: voters[i] });

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
      let newFeed = startingFeeds[i];
      for (let j = 0; j < numSubmitted; j++) {
        let delta = feed[i];
        if (j == 1) {
          delta = differentFeed[i];
        }

        if (delta == "+") {
          newFeed *= SCALE
        }
        if (delta == "-") {
          newFeed /= SCALE
        }
        newFeed = Math.floor(newFeed)
      }
      newFeeds.push(newFeed);
    }

    let allCurrentFeeds = await fastUpdater.fetchAllCurrentFeeds();
    expect(allCurrentFeeds[0].length).to.be.equal(NUM_FEEDS);
    let feeds: number[] = (await fastUpdater.fetchCurrentFeeds(indices))[0].map((x: BN) => x.toNumber());
    for (let i = 0; i < NUM_FEEDS; i++) {
      expect(feeds[i]).to.be.equal(newFeeds[i]);
      expect(allCurrentFeeds[1][i]).to.be.equal(newFeeds[i]);
      expect(allCurrentFeeds[2][i]).to.be.equal(DECIMALS[i]);
      expect(allCurrentFeeds[0][i]).to.be.equal(FEED_IDS[i]);
    }

    const tx = await fastUpdater.daemonize({
      from: flareDaemon,
    });
    expect(tx.receipt.gasUsed).to.be.lessThan(350000);

    feeds = (await fastUpdater.fetchCurrentFeeds(indices))[0].map((x: BN) => x.toNumber());
    allCurrentFeeds = await fastUpdater.fetchAllCurrentFeeds();
    expect(allCurrentFeeds[0].length).to.be.equal(NUM_FEEDS);
    for (let i = 0; i < NUM_FEEDS; i++) {
      expect(feeds[i]).to.be.equal(newFeeds[i]);
      expect(allCurrentFeeds[1][i]).to.be.equal(newFeeds[i]);
    }
  });

  it('should verify public key', async () => {
    const key: SortitionKey = generateSortitionKey()
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
    )
  });

  it("should daemonize and emit all current feeds and decimals", async () => {
    // increase time to move voting round
    await time.increase(12000);

    const tx = await fastUpdater.daemonize({
      from: flareDaemon,
    });

    expectEvent(tx, "FastUpdateFeeds", { feeds: ANCHOR_FEEDS.map(x => toBN(x)), decimals: DECIMALS.map(x => toBN(x)) });
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

    await expectRevert(fastUpdater.submitUpdates({
      sortitionBlock: 3,
      sortitionCredential: {
        replicate: 0,
        gamma: { x: 0, y: 0 },
        c: 0,
        s: 0,
      },
      deltas: "0x",
      signature: signature,
    }, { from: voters[0] }), "Updates no longer accepted for the given block");
  });

  it("should revert if not calling setSubmissionWindow from governance", async () => {
    await expectRevert(fastUpdater.setSubmissionWindow(2, { from: flareDaemon }), "only governance");
  });

  it("should revert submit updates if updates are not yet available", async () => {
    const signature = await ECDSASignature.signMessageHash(
      "0x1122334455667788990011223344556677889900112233445566778899001122",
      privateKeys[11].privateKey
    );

    await expectRevert(fastUpdater.submitUpdates({
      sortitionBlock: 12345,
      sortitionCredential: {
        replicate: 0,
        gamma: { x: 0, y: 0 },
        c: 0,
        s: 0,
      },
      deltas: "0x",
      signature: signature,
    }, { from: voters[0] }), "Updates not yet available for the given block");
  });

  it("should revert submit updates if more updates than available feeds", async () => {
    const signature = await ECDSASignature.signMessageHash(
      "0x1122334455667788990011223344556677889900112233445566778899001122",
      privateKeys[11].privateKey
    );
    const deltas = "0x" + new Array(FEED_IDS.length + 1).join("1");
    const currentBlock = await web3.eth.getBlockNumber();


    await expectRevert(fastUpdater.submitUpdates({
      sortitionBlock: currentBlock,
      sortitionCredential: {
        replicate: 0,
        gamma: { x: 0, y: 0 },
        c: 0,
        s: 0,
      },
      deltas: deltas,
      signature: signature,
    }, { from: voters[0] }), "More updates than available feeds");
  });

  describe("Reset and remove feeds", async () => {
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
        ]),
        [
          addressUpdater,
          flareSystemMock.address,
          fastUpdateIncentiveManager.address,
          flareSystemMock.address,
          fastUpdatesConfigurationMock.address,
          ftsoFeedPublisherMock.address,
        ],
        { from: addressUpdater }
      );
    });


    it("should revert resetting feeds if called from a wrong address", async () => {
      await expectRevert(fastUpdater.resetFeeds([0, 1], { from: accounts[80] }), "only fast updates configuration or governance");
    });

    it("should revert resetting feeds if index is not supported", async () => {
      const getFeedId = fastUpdatesConfiguration.contract.methods.getFeedId([0]).encodeABI();
      const feedId = web3.eth.abi.encodeParameters(
        ["bytes21"],
        ["0x".padEnd(42, "0")]
      );
      await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedId, feedId);
      await expectRevert(fastUpdater.resetFeeds([0], { from: governance }), "index not supported");
    });

    it("should revert resetting feeds if feed is too old", async () => {
      const getFeedId = fastUpdatesConfiguration.contract.methods.getFeedId([0]).encodeABI();
      const feedId = web3.eth.abi.encodeParameters(
        ["bytes21"],
        [FEED_IDS[0]]
      );
      await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedId, feedId);

      const getCurrentFeed = ftsoFeedPublisherInterface.contract.methods.getCurrentFeed(FEED_IDS[0]).encodeABI();
      const feed = web3.eth.abi.encodeParameters(
        ["tuple(uint32,bytes21,int32,uint16,int8)"], // IFtsoFeedPublisher.Feed (uint32 votingRoundId, bytes21 id, int32 value, uint16 turnoutBIPS, int8 decimals)
        [[0, FEED_IDS[0], ANCHOR_FEEDS[0], 6000, DECIMALS[0]]]
      );
      await ftsoFeedPublisherMock.givenCalldataReturn(getCurrentFeed, feed);

      await time.increase(1200000);
      await expectRevert(fastUpdater.resetFeeds([0], { from: governance }), "feed too old");
    });

    it("should revert resetting feeds if feed value is zero", async () => {
      const getFeedId = fastUpdatesConfiguration.contract.methods.getFeedId([0]).encodeABI();
      const feedId = web3.eth.abi.encodeParameters(
        ["bytes21"],
        [FEED_IDS[0]]
      );
      await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedId, feedId);

      const getCurrentFeed = ftsoFeedPublisherInterface.contract.methods.getCurrentFeed(FEED_IDS[0]).encodeABI();
      const feed = web3.eth.abi.encodeParameters(
        ["tuple(uint32,bytes21,int32,uint16,int8)"], // IFtsoFeedPublisher.Feed (uint32 votingRoundId, bytes21 id, int32 value, uint16 turnoutBIPS, int8 decimals)
        [[0, FEED_IDS[0], 0, 6000, DECIMALS[0]]]
      );
      await ftsoFeedPublisherMock.givenCalldataReturn(getCurrentFeed, feed);

      await expectRevert(fastUpdater.resetFeeds([0], { from: governance }), "feed value zero or negative");
    });

    it("should reset feeds", async () => {
      let indices = [0, 2, 8, 11];
      let newDecimals = [5, 6, 7, -8];
      for (let i = 0; i < indices.length; i++) {
        const getFeedId = fastUpdatesConfiguration.contract.methods.getFeedId([indices[i]]).encodeABI();
        const feedId = web3.eth.abi.encodeParameters(
          ["bytes21"],
          [FEED_IDS[i]]
        );
        await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedId, feedId);
      }

      const getFeedIds = fastUpdatesConfiguration.contract.methods.getFeedIds().encodeABI();
        const feedIds = web3.eth.abi.encodeParameters(
          ["bytes21[]"],
          [FEED_IDS]
        );
        await fastUpdatesConfigurationMock.givenCalldataReturn(getFeedIds, feedIds);

      for (let i = 0; i < indices.length; i++) {
        const getCurrentFeed = ftsoFeedPublisherInterface.contract.methods.getCurrentFeed(FEED_IDS[i]).encodeABI();
        let feed;
        feed = web3.eth.abi.encodeParameters(
          ["tuple(uint32,bytes21,int32,uint16,int8)"], // IFtsoFeedPublisher.Feed (uint32 votingRoundId, bytes21 id, int32 value, uint16 turnoutBIPS, int8 decimals)
          [[0, FEED_IDS[i], (i + 1) * 148, 6000, newDecimals[i]]]
        );
        await ftsoFeedPublisherMock.givenCalldataReturn(getCurrentFeed, feed);
      };

      let updateDecimals = DECIMALS.slice();
      let updatedAnchorFeeds = ANCHOR_FEEDS.slice();
      for (let i = 0; i < indices.length; i++) {
        updateDecimals[indices[i]] = newDecimals[i];
        updatedAnchorFeeds[indices[i]] = (i + 1) * 148;
      }

      await fastUpdater.resetFeeds(indices, { from: governance });
      let currentFeeds = await fastUpdater.fetchCurrentFeeds([0, 2, 8, 11, 13]);
      for (let i = 0; i < indices.length; i++) {
        expect(currentFeeds[0][i].toNumber()).to.equals(updatedAnchorFeeds[indices[i]]);
        expect(currentFeeds[1][i].toNumber()).to.equals(updateDecimals[indices[i]]);
      }
      expect(currentFeeds[0][4].toNumber()).to.equals(130000);
      expect(currentFeeds[1][4].toNumber()).to.equals(2);


      let allCurrentFeeds = await fastUpdater.fetchAllCurrentFeeds();
      expect(allCurrentFeeds[0].length).to.be.equal(NUM_FEEDS);
      for (let i = 0; i < NUM_FEEDS; i++) {
        expect(allCurrentFeeds[1][i]).to.be.equal(updatedAnchorFeeds[i]);
        expect(allCurrentFeeds[2][i]).to.be.equal(updateDecimals[i]);
        expect(allCurrentFeeds[0][i]).to.be.equal(FEED_IDS[i]);
      }
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
        ]),
        [
          addressUpdater,
          flareSystemMock.address,
          fastUpdateIncentiveManager.address,
          flareSystemMock.address,
          accounts[123],
          ftsoFeedPublisherMock.address,
        ],
        { from: addressUpdater }
      );

      let currentFeeds = await fastUpdater.fetchCurrentFeeds([0, 1, 28, 249]);
      expect(currentFeeds[0][0].toNumber()).to.equals(5000);
      expect(currentFeeds[0][1].toNumber()).to.equals(10000);
      expect(currentFeeds[0][2].toNumber()).to.equals(280000);
      expect(currentFeeds[0][3].toNumber()).to.equals(2490000);
      expect(currentFeeds[1][0].toNumber()).to.equals(2);
      expect(currentFeeds[1][1].toNumber()).to.equals(3);
      expect(currentFeeds[1][2].toNumber()).to.equals(2);
      expect(currentFeeds[1][3].toNumber()).to.equals(2);

      await fastUpdater.removeFeeds([0, 1, 249], { from: accounts[123] });
      currentFeeds = await fastUpdater.fetchCurrentFeeds([0, 1, 28, 249]);
      expect(currentFeeds[0][0].toNumber()).to.equals(0);
      expect(currentFeeds[0][1].toNumber()).to.equals(0);
      expect(currentFeeds[0][2].toNumber()).to.equals(280000);
      expect(currentFeeds[0][3].toNumber()).to.equals(0);
      expect(currentFeeds[1][0].toNumber()).to.equals(0);
      expect(currentFeeds[1][1].toNumber()).to.equals(0);
      expect(currentFeeds[1][2].toNumber()).to.equals(2);
      expect(currentFeeds[1][3].toNumber()).to.equals(0);
    });

  });

});