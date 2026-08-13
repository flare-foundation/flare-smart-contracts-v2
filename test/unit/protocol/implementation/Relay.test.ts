import { expectCustomError } from "../../../utils/custom-errors";
import { deployRelayProxy } from "../../../utils/relay-deploy";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { constants, expectEvent, expectRevert } from "@openzeppelin/test-helpers";
import { artifacts, config, contract, ethers, expect } from "hardhat";
import { HardhatNetworkAccountConfig } from "hardhat/types";
import { RelayInitialConfig } from "../../../../deployment/utils/RelayInitialConfig";
import {
  IProtocolMessageMerkleRoot,
  ProtocolMessageMerkleRoot,
} from "../../../../scripts/libs/protocol/ProtocolMessageMerkleRoot";
import { RelayMessage } from "../../../../scripts/libs/protocol/RelayMessage";
import { ISigningPolicy, SigningPolicy } from "../../../../scripts/libs/protocol/SigningPolicy";
import { RelayInstance } from "../../../../typechain-truffle";
import { MerkleTree, verifyWithMerkleProof } from "../../../utils/MerkleTree";
import { getTestFile } from "../../../utils/constants";
import { toBN } from "../../../utils/test-helpers";
import { defaultTestSigningPolicy, generateSignatures, generateSignaturesEncoded } from "../coding/coding-helpers";
import { RelayContract } from "../../../../typechain-truffle";
import { IECDSASignatureWithIndex } from "../../../../scripts/libs/protocol/ECDSASignatureWithIndex";

const Relay: RelayContract = artifacts.require("Relay");

const BURN_ADDRESS = "0x000000000000000000000000000000000000dEaD";
const COVERAGE = process.env.COVERAGE === "1" || process.env.COVERAGE === "true";

interface StateDataRaw {
  [key: number]: BN | boolean;
}
function stateDataName(stateDataRaw: StateDataRaw) {
  return {
    randomNumberProtocolId: stateDataRaw[0] as BN,
    firstVotingRoundStartTs: stateDataRaw[1] as BN,
    votingEpochDurationSeconds: stateDataRaw[2] as BN,
    firstRewardEpochStartVotingRoundId: stateDataRaw[3] as BN,
    rewardEpochDurationInVotingEpochs: stateDataRaw[4] as BN,
    thresholdIncreaseBIPS: stateDataRaw[5] as BN,
    randomVotingRoundId: stateDataRaw[6] as BN,
    isSecureRandom: stateDataRaw[7] as boolean,
    lastInitializedRewardEpoch: stateDataRaw[8] as BN,
    noSigningPolicyRelay: stateDataRaw[9] as boolean,
    messageFinalizationWindowInRewardEpochs: stateDataRaw[10] as BN,
  };
}

interface GetRandomNumberRaw {
  0: BN;
  1: boolean;
  2: BN;
}
function getRandomNumberName(getRandomNumberRaw: GetRandomNumberRaw) {
  return {
    _randomNumber: getRandomNumberRaw[0],
    _isSecureRandom: getRandomNumberRaw[1],
    _randomTimestamp: getRandomNumberRaw[2],
  };
}

export interface RandomResult {
  readonly votingRoundId: number;
  readonly value: string; // 0x-prefixed bytes32 encoded uint256
  readonly isSecure: boolean;
}

function toHex32(x: string | number) {
  return web3.utils.leftPad(web3.utils.toHex(x), 64);
}

function hashRandomResult(randomResult: RandomResult): string {
  return web3.utils.soliditySha3(
    toHex32(randomResult.votingRoundId) +
      toHex32(randomResult.value).slice(2) +
      toHex32(randomResult.isSecure ? 1 : 0).slice(2)
  )!;
}

function randomNumberWithMerkleProof(randomResult: RandomResult, n = 100) {
  const randomNumberHash = hashRandomResult(randomResult);
  const hashes = [randomNumberHash];
  for (let i = 0; i < n; i++) {
    hashes.push(web3.utils.randomHex(32));
  }

  const merkleTree = new MerkleTree(hashes);
  return {
    merkleRoot: merkleTree.root,
    leaf: randomNumberHash,
    proof: merkleTree.getProof(randomNumberHash),
  };
}

function prepareDataWithRandom(messageData: IProtocolMessageMerkleRoot, randomNumber = 100) {
  const randomNumberResult: RandomResult = {
    votingRoundId: messageData.votingRoundId,
    value: toHex32(randomNumber),
    isSecure: messageData.isSecureRandom,
  };
  const { leaf, merkleRoot, proof } = randomNumberWithMerkleProof(randomNumberResult);
  messageData.merkleRoot = merkleRoot!;
  const relayData = {
    isRandomNumberGeneratingProtocolMessage: true,
    randomNumber: randomNumberResult.value,
    merkleProof: proof!,
  };
  return { randomNumberResult, relayData, randomNumberLeaf: leaf };
}

function prepareDeterministicDataWithRandom(
  messageData: IProtocolMessageMerkleRoot,
  randomNumber: number,
  numberOfLeaves: number
) {
  const randomNumberResult: RandomResult = {
    votingRoundId: messageData.votingRoundId,
    value: toHex32(randomNumber),
    isSecure: messageData.isSecureRandom,
  };
  const randomNumberLeaf = hashRandomResult(randomNumberResult);
  const leaves = [randomNumberLeaf];
  for (let i = 1; i < numberOfLeaves; i++) {
    leaves.push(ethers.keccak256(ethers.solidityPacked(["string", "uint256"], ["relay-gas-leaf", i])));
  }
  const merkleTree = new MerkleTree(leaves);
  const merkleProof = merkleTree.getProof(randomNumberLeaf)!;
  messageData.merkleRoot = merkleTree.root!;
  return {
    randomNumberResult,
    randomNumberLeaf,
    numberOfLeaves: merkleTree.hashCount,
    relayData: {
      isRandomNumberGeneratingProtocolMessage: true,
      randomNumber: randomNumberResult.value,
      merkleProof,
    },
  };
}

function generateForgedSignatures(voters: string[], count: number): IECDSASignatureWithIndex[] {
  const signatures: IECDSASignatureWithIndex[] = [];
  for (let i = 0; i < count; i++) {
    // Use a valid v (27) and low s so the canonical-signature checks pass; r = 0 is an
    // invalid recovery input, so ecrecover returns empty and the returndatasize check is exercised.
    void voters;
    signatures.push({
      v: 27,
      r: "0x" + "0".repeat(64),
      s: "0x0000000000000000000000000000000000000000000000000000000000000001",
      index: i,
    });
  }
  return signatures;
}

function encodeForgedSignatures(signatures: IECDSASignatureWithIndex[]): string {
  let encoded = signatures.length.toString(16).padStart(4, "0");
  for (const sig of signatures) {
    encoded += sig.v.toString(16).padStart(2, "0");
    encoded += sig.r.slice(2);
    encoded += sig.s.slice(2);
    encoded += sig.index.toString(16).padStart(4, "0");
  }
  return encoded;
}
contract(`Relay.sol; ${getTestFile(__filename)}`, () => {
  // let accounts: Account[];
  let signers: SignerWithAddress[];
  const accountPrivateKeys = (config.networks.hardhat.accounts as HardhatNetworkAccountConfig[]).map(
    (x) => x.privateKey
  );
  let relay: RelayInstance;
  // ethers handle bound to the IRelay ABI — used only to decode typed custom errors in matchers.
  let relayIface: any;
  // Policy hashes and signed message digests are source-chain-bound; set in before().
  let chainId: number;
  const selector = ethers.keccak256(ethers.toUtf8Bytes("relay()")).slice(0, 10);
  const N = 100;
  const singleWeight = 500;
  // The next two should match the contract settings
  const firstVotingRoundStartSec = 1636070400;
  const votingRoundDurationSec = 90;
  const firstRewardEpochVotingRoundId = 1000;
  const rewardEpochDurationInVotingEpochs = 3360; // 3.5 days
  const votingRoundId = 4411;
  const rewardEpochId = Math.floor((votingRoundId - firstRewardEpochVotingRoundId) / rewardEpochDurationInVotingEpochs);
  let signingPolicyData: ISigningPolicy;
  const randomNumberProtocolId = 15;
  const THRESHOLD_INCREASE = 12000;
  const MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS = 3;
  let newSigningPolicyDataRelayed: ISigningPolicy;

  const testVotingRoundId = votingRoundId + 100;

  const firstVotingRoundInRewardEpoch = (rewardEpochId: number) =>
    firstRewardEpochVotingRoundId + rewardEpochDurationInVotingEpochs * rewardEpochId;

  const prepareFullData = async (signingPolicyData: ISigningPolicy, newSigningPolicyData: ISigningPolicy) => {
    const localHash = SigningPolicy.hash(newSigningPolicyData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, localHash, N / 2 + 1);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      newSigningPolicy: newSigningPolicyData,
    };
    return RelayMessage.encode(relayMessage);
  };

  before(async () => {
    // accounts = loadAccounts(web3);
    chainId = await web3.eth.getChainId();
    signers = (await ethers.getSigners()) as unknown as SignerWithAddress[];
    signingPolicyData = defaultTestSigningPolicy(
      signers.map((x) => x.address),
      N,
      singleWeight
    );
    signingPolicyData.rewardEpochId = rewardEpochId;
    signingPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
    const signingPolicy = SigningPolicy.encode(signingPolicyData);
    const localHash = SigningPolicy.hashEncoded(signingPolicy, chainId);

    const relayInitialConfig: RelayInitialConfig = {
      initialRewardEpochId: signingPolicyData.rewardEpochId,
      startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
      initialSigningPolicyHash: localHash,
      randomNumberProtocolId: randomNumberProtocolId,
      firstVotingRoundStartTs: firstVotingRoundStartSec,
      votingEpochDurationSeconds: votingRoundDurationSec,
      firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
      rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
      thresholdIncreaseBIPS: THRESHOLD_INCREASE,
      messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
      feeCollectionAddress: BURN_ADDRESS,
      feeConfigs: [],
      sourceChainId: chainId,
      timelockDurationSeconds: 0,
    };

    relay = await deployRelayProxy(relayInitialConfig, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
    relayIface = await ethers.getContractAt("IRelay", relay.address);
  });

  let merkleRoot: string;
  let messageData: IProtocolMessageMerkleRoot;

  beforeEach(async () => {
    merkleRoot = ethers.hexlify(ethers.randomBytes(32));
    messageData = {
      protocolId: randomNumberProtocolId,
      votingRoundId,
      isSecureRandom: true,
      merkleRoot,
    } as IProtocolMessageMerkleRoot;
  });

  it("Should initial signing policy be initialized", async () => {
    const signingPolicy = SigningPolicy.encode(signingPolicyData);
    const result = await relay.lastInitializedRewardEpochData();
    const _lastInitializedRewardEpoch = result[0];
    const _startingVotingRoundIdForLastInitializedRewardEpoch = result[1];
    expect(_lastInitializedRewardEpoch.toString()).to.equal(signingPolicyData.rewardEpochId.toString());
    expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(
      signingPolicyData.startVotingRoundId.toString()
    );
  });

  it("Should relay a message for random number generating protocol", async () => {
    const { randomNumberResult, relayData } = prepareDataWithRandom(messageData, 100);
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData, chainId);
    const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: messageData,
      ...relayData,
    };

    const fullData = RelayMessage.encode(relayMessage);
    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    });
    await expectEvent.inTransaction(receipt.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(messageData.protocolId),
      votingRoundId: toBN(messageData.votingRoundId),
      isSecureRandom: messageData.isSecureRandom,
      merkleRoot: messageData.merkleRoot,
    });
    await expectEvent.inTransaction(receipt.transactionHash, relay, "RandomNumberRelayed", {
      votingRoundId: toBN(messageData.votingRoundId),
      randomNumber: toBN(randomNumberResult.value),
      isSecureRandom: messageData.isSecureRandom,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    expect(await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)).to.equal(true);

    const rawStateData = await relay.stateData();
    const stateData = stateDataName(rawStateData);
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(messageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(messageData.votingRoundId.toString());
    expect(stateData.isSecureRandom.toString()).to.be.equal(messageData.isSecureRandom.toString());

    // Round-trip the relay message (without the random-number trailer, which RelayMessage.decode
    // does not parse) through encode/decode to verify the message body encoding.
    const relayMessageNoTrailer = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: messageData,
    };
    const fullDataNoTrailer = RelayMessage.encode(relayMessageNoTrailer);
    expect(RelayMessage.decode(fullDataNoTrailer)).not.to.throw;
    const decodedRelayMessage = RelayMessage.decode(fullDataNoTrailer);

    expect(RelayMessage.equals(relayMessageNoTrailer, decodedRelayMessage)).to.be.true;
    const getRandomNumberRaw = await relay.getRandomNumber();
    const { _randomNumber, _isSecureRandom, _randomTimestamp } = getRandomNumberName(getRandomNumberRaw);
    expect(_isSecureRandom).to.be.true;
    expect(_randomNumber.toString()).to.equal(toBN(randomNumberResult.value).toString());
    expect(_randomTimestamp.toNumber()).to.equal(
      firstVotingRoundStartSec + votingRoundDurationSec * (messageData.votingRoundId + 1)
    );
    expect((await relay.getVotingRoundId(_randomTimestamp)).toNumber()).to.be.equal(
      toBN(messageData.votingRoundId + 1)
    );
  });

  it("Should finalize a 100-leaf random-number tree with 50 signatures within 390k gas", async () => {
    const gasPolicy = defaultTestSigningPolicy(
      signers.map((x) => x.address),
      N,
      100
    );
    gasPolicy.rewardEpochId = rewardEpochId;
    gasPolicy.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
    // relay() accepts only signedWeight > threshold. The first 49 signatures total 4,900;
    // signature 50 adds 101 and is therefore the first one to cross the 5,000 threshold.
    gasPolicy.weights[49] = 101;
    gasPolicy.weights[99] = 99;
    gasPolicy.threshold = 5_000;

    const gasRelay = await deployRelayProxy(
      {
        initialRewardEpochId: gasPolicy.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: gasPolicy.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(gasPolicy, chainId),
        randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      },
      constants.ZERO_ADDRESS,
      constants.ZERO_ADDRESS
    );
    const gasMessageData = {
      protocolId: randomNumberProtocolId,
      votingRoundId,
      isSecureRandom: true,
      merkleRoot: "",
    } as IProtocolMessageMerkleRoot;
    const { numberOfLeaves, relayData } = prepareDeterministicDataWithRandom(gasMessageData, 100, N);
    const messageHash = ProtocolMessageMerkleRoot.hash(gasMessageData, chainId);
    const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2);
    const fullData = RelayMessage.encode({
      signingPolicy: gasPolicy,
      signatures,
      protocolMessageMerkleRoot: gasMessageData,
      ...relayData,
    });

    const weightAfter49Signatures = gasPolicy.weights.slice(0, 49).reduce((sum, weight) => sum + weight, 0);
    const weightAfter50Signatures = gasPolicy.weights.slice(0, 50).reduce((sum, weight) => sum + weight, 0);
    expect(gasPolicy.weights.reduce((sum, weight) => sum + weight, 0)).to.equal(10_000);
    expect(weightAfter49Signatures).to.equal(4_900).and.to.be.at.most(gasPolicy.threshold);
    expect(weightAfter50Signatures).to.equal(5_001).and.to.be.greaterThan(gasPolicy.threshold);
    expect(signatures).to.have.length(50);
    expect(numberOfLeaves).to.equal(100);
    expect(relayData.merkleProof).to.have.length(7);
    expect(ethers.getBytes(selector + fullData.slice(2))).to.have.length(5_893);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: gasRelay.address,
      data: selector + fullData.slice(2),
    });
    const gasUsed = receipt.gasUsed;
    // Solidity coverage instrumentation changes the deployed bytecode and invalidates this production-build baseline.
    if (!COVERAGE) {
      expect(gasUsed).to.be.lessThan(390_000);
    }
    expect(await gasRelay.isFinalized(randomNumberProtocolId, votingRoundId)).to.equal(true);
    const finalizedRandom = await gasRelay.getRandomNumberHistorical(votingRoundId);
    expect(finalizedRandom[0].toString()).to.equal(toBN(100).toString());
    expect(finalizedRandom[1]).to.equal(true);
    console.log(`Gas used for 100-voter, 50-signature random finalization: ${gasUsed}`);
  });

  it("Should relay a message for non random number generating protocol", async () => {
    messageData.protocolId++;
    messageData.isSecureRandom = false;
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData, chainId);
    const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: messageData,
    };

    const fullData = RelayMessage.encode(relayMessage);
    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    });
    await expectEvent.inTransaction(receipt.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(messageData.protocolId),
      votingRoundId: toBN(messageData.votingRoundId),
      isSecureRandom: messageData.isSecureRandom,
      merkleRoot: merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    expect(await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)).to.equal(true);

    const stateDataRaw = await relay.stateData();
    const stateData = stateDataName(stateDataRaw);
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(randomNumberProtocolId.toString());
    // because of the previous test
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(messageData.votingRoundId.toString());
    // expect(stateData.isSecureRandom.toString()).to.be.equal(messageData.isSecureRandom.toString());

    expect(RelayMessage.decode(fullData)).not.to.throw;
    const decodedRelayMessage = RelayMessage.decode(fullData);

    expect(RelayMessage.equals(relayMessage, decodedRelayMessage)).to.be.true;
    const getRandomNumberRaw = await relay.getRandomNumber();
    const { _randomNumber, _isSecureRandom, _randomTimestamp } = getRandomNumberName(getRandomNumberRaw);
    // Because of previous test: the random pointer is NOT updated by a non-random-number protocol
    // relay, so it still reflects the value relayed in the previous test (votingRoundId 4411, value 100).
    expect(_isSecureRandom).to.be.true;
    expect(_randomNumber.toString()).to.equal(toBN(100).toString());
    expect(_randomTimestamp.toNumber()).to.equal(
      firstVotingRoundStartSec + votingRoundDurationSec * (messageData.votingRoundId + 1)
    );
    expect((await relay.getVotingRoundId(_randomTimestamp)).toNumber()).to.be.equal(
      toBN(messageData.votingRoundId + 1)
    );
  });

  it("Should fail to relay a message due to low weight", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;

    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "NotEnoughWeight");
  });

  it("Should fail to relay a Mode-2 message with a zero merkle root", async () => {
    const newMessageData = { ...messageData };
    newMessageData.protocolId = randomNumberProtocolId + 1; // non-random protocol
    newMessageData.votingRoundId++;
    newMessageData.merkleRoot = ethers.ZeroHash;
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
    const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);
    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
    };
    const fullData = RelayMessage.encode(relayMessage);
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "ZeroMerkleRoot");
  });

  it("Should fail to relay a message due to non increasing signature indices", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, messageHash, 0, [0, 1, 2, 2, 1]);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "IndexOutOfOrder");
  });

  it("Should fail to relay a message due signature indices out of range", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;

    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, messageHash, 0, [0, 1, 2, 101]);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "IndexOutOfRange");
  });

  it("Should fail to relay a message due too short data for metadata", async () => {
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + "0000",
      })
    ).to.be.revertedWithCustomError(relayIface, "InvalidSignPolicyMetadata");
  });

  it("Should fail to relay a message on mismatch of signing policy length", async () => {
    const signingPolicy = SigningPolicy.encode(signingPolicyData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy.slice(0, -2),
      })
    ).to.be.revertedWithCustomError(relayIface, "InvalidSignPolicyLength");
  });

  it("Should fail due to signing policy hash mismatch", async () => {
    const signingPolicy = SigningPolicy.encode(signingPolicyData).slice(2);
    const tweakedSigningPolicy =
      signingPolicy.slice(0, -2) + ((parseInt(signingPolicy.slice(-2), 16) + 1) % 256).toString(16).padStart(2, "0");

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + tweakedSigningPolicy + "00",
      })
    ).to.be.revertedWithCustomError(relayIface, "SigningPolicyHashMismatch");
  });

  it("Should fail to relay a message due to too short message", async () => {
    const signingPolicy = SigningPolicy.encode(signingPolicyData).slice(2);
    const fullMessage = ProtocolMessageMerkleRoot.encode(messageData).slice(2);
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage.slice(0, -2),
      })
    ).to.be.revertedWithCustomError(relayIface, "TooShortMessage");
  });

  it("Should fail to relay message due to delayed signing policy", async () => {
    // "Delayed sign policy"
    const newSigningPolicyData = { ...signingPolicyData };
    newSigningPolicyData.startVotingRoundId = votingRoundId + 1;
    const signingPolicy = SigningPolicy.encode(newSigningPolicyData);

    const relayInitialConfig: RelayInitialConfig = {
      initialRewardEpochId: newSigningPolicyData.rewardEpochId,
      startingVotingRoundIdForInitialRewardEpochId: newSigningPolicyData.startVotingRoundId,
      initialSigningPolicyHash: SigningPolicy.hashEncoded(signingPolicy, chainId),
      randomNumberProtocolId: randomNumberProtocolId,
      firstVotingRoundStartTs: firstVotingRoundStartSec,
      votingEpochDurationSeconds: votingRoundDurationSec,
      firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
      rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
      thresholdIncreaseBIPS: THRESHOLD_INCREASE,
      messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
      feeCollectionAddress: BURN_ADDRESS,
      feeConfigs: [],
      sourceChainId: chainId,
      timelockDurationSeconds: 0,
    };

    const relay2 = await deployRelayProxy(relayInitialConfig, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);

    const fullMessage = ProtocolMessageMerkleRoot.encode(messageData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay2.address,
        data: selector + signingPolicy.slice(2) + fullMessage,
      })
    ).to.be.revertedWithCustomError(relayIface, "DelayedSignPolicy");
  });

  it("Should fail to relay a message due to wrong signing policy reward epoch id", async () => {
    const newMessageData = { ...messageData };
    // newMessageData.votingRoundId = votingRoundId - rewardEpochDurationInVotingEpochs; // shift to previous reward epoch
    newMessageData.votingRoundId = 1; // shift to previous reward epoch
    let fullMessage = ProtocolMessageMerkleRoot.encode(newMessageData).slice(2);
    const signingPolicy = SigningPolicy.encode(signingPolicyData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage,
      })
    ).to.be.revertedWithCustomError(relayIface, "InvalidVotingRoundId");

    newMessageData.votingRoundId = votingRoundId - rewardEpochDurationInVotingEpochs; // shift to one epoch after next reward epoch
    fullMessage = ProtocolMessageMerkleRoot.encode(newMessageData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage,
      })
    ).to.be.revertedWithCustomError(relayIface, "WrongSignPolicyRewardEpoch");

    newMessageData.votingRoundId = votingRoundId + 2 * rewardEpochDurationInVotingEpochs; // shift to one epoch after next reward epoch
    fullMessage = ProtocolMessageMerkleRoot.encode(newMessageData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage + "0000",
      })
    ).to.be.revertedWithCustomError(relayIface, "NotEnoughWeight");

    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs; // shift to next reward epoch
    fullMessage = ProtocolMessageMerkleRoot.encode(newMessageData).slice(2);

    // should be able to use previous reward epoch signing policy, but since no signatures count is provided, should fail
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage,
      })
    ).to.be.revertedWithCustomError(relayIface, "NoSignatureCount");

    // should be able to use previous reward epoch signing policy, but since 0 are provided, it should fail
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage + "0000",
      })
    ).to.be.revertedWithCustomError(relayIface, "NotEnoughWeight");
  });

  it("Should relay a message with old signing policy and 20% signatures more", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs; // shift to next reward epoch
    const { relayData } = prepareDataWithRandom(newMessageData, 100);
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatureObjects = await generateSignatures(accountPrivateKeys, messageHash, Math.round(N * 0.6) + 1);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures: signatureObjects,
      protocolMessageMerkleRoot: newMessageData,
      ...relayData,
    };
    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    });
    await expectEvent.inTransaction(receipt.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(newMessageData.protocolId),
      votingRoundId: toBN(newMessageData.votingRoundId),
      isSecureRandom: newMessageData.isSecureRandom,
      merkleRoot: newMessageData.merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    expect(await relay.isFinalized(newMessageData.protocolId, newMessageData.votingRoundId)).to.equal(true);

    const stateDataRaw = await relay.stateData();
    const stateData = stateDataName(stateDataRaw);
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(newMessageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(newMessageData.votingRoundId.toString());
    expect(stateData.isSecureRandom.toString()).to.be.equal(newMessageData.isSecureRandom.toString());
  });

  it("Should fail to relay a message with old signing policy and less then 20%+ more weight", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = firstVotingRoundInRewardEpoch(signingPolicyData.rewardEpochId + 1) + 5; //votingRoundId + rewardEpochDurationInVotingEpochs + 1; // shift to next reward epoch
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, messageHash, Math.round(N * 0.6));

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "NotEnoughWeight");
  });

  it("Should relay a new signing policy", async () => {
    newSigningPolicyDataRelayed = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyDataRelayed.rewardEpochId + 1;
    newSigningPolicyDataRelayed.rewardEpochId = newRewardEpoch;
    newSigningPolicyDataRelayed.voters = newSigningPolicyDataRelayed.voters.slice(0, 50);
    newSigningPolicyDataRelayed.weights = newSigningPolicyDataRelayed.weights.slice(0, 50);
    newSigningPolicyDataRelayed.threshold = Math.round(newSigningPolicyDataRelayed.threshold / 2);
    newSigningPolicyDataRelayed.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch) + 10; // create a delay

    const localHash = SigningPolicy.hash(newSigningPolicyDataRelayed, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, localHash, N / 2 + 1);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      newSigningPolicy: newSigningPolicyDataRelayed,
    };

    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    });
    await expectEvent.inTransaction(receipt.transactionHash, relay, "SigningPolicyRelayed", {
      rewardEpochId: toBN(newSigningPolicyDataRelayed.rewardEpochId),
    });
    const result = await relay.lastInitializedRewardEpochData();
    const _lastInitializedRewardEpoch = result[0];
    const _startingVotingRoundIdForLastInitializedRewardEpoch = result[1];
    expect(_lastInitializedRewardEpoch.toString()).to.equal(newRewardEpoch.toString());
    expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(
      newSigningPolicyDataRelayed.startVotingRoundId.toString()
    );
    console.log("Gas used:", receipt?.gasUsed?.toString());
  });

  it("Should relay several signing policies and fail relaying a too old message", async () => {
    const signingPolicy = SigningPolicy.encode(signingPolicyData);
    const localHash0 = SigningPolicy.hashEncoded(signingPolicy, chainId);

    const relayInitialConfig: RelayInitialConfig = {
      initialRewardEpochId: signingPolicyData.rewardEpochId,
      startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
      initialSigningPolicyHash: localHash0,
      randomNumberProtocolId: randomNumberProtocolId,
      firstVotingRoundStartTs: firstVotingRoundStartSec,
      votingEpochDurationSeconds: votingRoundDurationSec,
      firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
      rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
      thresholdIncreaseBIPS: THRESHOLD_INCREASE,
      messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
      feeCollectionAddress: BURN_ADDRESS,
      feeConfigs: [],
      sourceChainId: chainId,
      timelockDurationSeconds: 0,
    };

    const relay2 = await deployRelayProxy(relayInitialConfig, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);

    let lastSigningPolicyData = signingPolicyData;
    for (
      let i = signingPolicyData.rewardEpochId + 1;
      i < signingPolicyData.rewardEpochId + MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS + 2;
      i++
    ) {
      const newSigningPolicyDataRelayed = { ...signingPolicyData };
      const newRewardEpoch = i;
      newSigningPolicyDataRelayed.rewardEpochId = newRewardEpoch;
      newSigningPolicyDataRelayed.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);

      const localHash = SigningPolicy.hash(newSigningPolicyDataRelayed, chainId);

      const signatures = await generateSignatures(accountPrivateKeys, localHash, N / 2 + 1);

      const relayMessage = {
        signingPolicy: lastSigningPolicyData,
        signatures,
        newSigningPolicy: newSigningPolicyDataRelayed,
      };

      const fullData = RelayMessage.encode(relayMessage);

      // const hashBefore = await relay.toSigningPolicyHash(newRewardEpoch, {from: signers[10].address});
      // expect(hashBefore).to.equal(ZERO_BYTES32);

      const receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay2.address,
        data: selector + fullData.slice(2),
      });
      await expectEvent.inTransaction(receipt.transactionHash, relay2, "SigningPolicyRelayed", {
        rewardEpochId: toBN(newSigningPolicyDataRelayed.rewardEpochId),
      });
      const result = await relay2.lastInitializedRewardEpochData();
      const _lastInitializedRewardEpoch = result[0];
      const _startingVotingRoundIdForLastInitializedRewardEpoch = result[1];
      expect(_lastInitializedRewardEpoch.toString()).to.equal(newRewardEpoch.toString());
      expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(
        newSigningPolicyDataRelayed.startVotingRoundId.toString()
      );
      lastSigningPolicyData = newSigningPolicyDataRelayed;
    }

    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
    const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay2.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "MessageTooOld");
  });

  it("Should fail to relay an already relayed message by old signing policy with a new signing policy", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs; // shift to next reward epoch
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const newSigningPolicyData = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.threshold = Math.round(newSigningPolicyData.threshold / 2);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch) + 10;

    const signatures = await generateSignatures(accountPrivateKeys, messageHash, 26);

    const relayMessage = {
      signingPolicy: newSigningPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "AlreadyRelayed");
  });

  it("Should relay a message with new signing policy", async () => {
    const newSigningPolicyData = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;

    const newMessageData = { ...messageData };
    // newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs - 1; // shift to next reward epoch
    newMessageData.votingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch) + 12;
    const { relayData } = prepareDataWithRandom(newMessageData, 100);
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch) + 10;
    newSigningPolicyData.threshold = Math.round(newSigningPolicyData.threshold / 2);

    const signatures = await generateSignatures(accountPrivateKeys, messageHash, 26);

    const relayMessage = {
      signingPolicy: newSigningPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
      ...relayData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    });
    await expectEvent.inTransaction(receipt.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(newMessageData.protocolId),
      votingRoundId: toBN(newMessageData.votingRoundId),
      isSecureRandom: newMessageData.isSecureRandom,
      merkleRoot: newMessageData.merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    expect(await relay.isFinalized(newMessageData.protocolId, newMessageData.votingRoundId)).to.equal(true);

    const stateDataRaw = await relay.stateData();
    const stateData = stateDataName(stateDataRaw);
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(newMessageData.protocolId.toString());
    // This votingRoundId is lower than the current live pointer, so the
    // live random pointer does not regress to it; the per-round value is still stored and queryable.
    expect(toBN(stateData.randomVotingRoundId).toNumber()).to.be.at.least(newMessageData.votingRoundId);
    const historical = getRandomNumberName(await relay.getRandomNumberHistorical(newMessageData.votingRoundId));
    expect(historical._randomNumber.toString()).to.be.equal(toBN(100).toString());
    expect(historical._isSecureRandom.toString()).to.be.equal(newMessageData.isSecureRandom.toString());
  });

  it("Should relay a message with old signing policy and less then 20%+ more weight after delayed reward epoch initialization", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = firstVotingRoundInRewardEpoch(signingPolicyData.rewardEpochId + 1) + 9; // new startingVotingRoundId is on +10
    const { relayData } = prepareDataWithRandom(newMessageData, 100);
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, messageHash, Math.round(N * 0.6));

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
      ...relayData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    });
    await expectEvent.inTransaction(receipt.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(newMessageData.protocolId),
      votingRoundId: toBN(newMessageData.votingRoundId),
      isSecureRandom: newMessageData.isSecureRandom,
      merkleRoot: newMessageData.merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    expect(await relay.isFinalized(newMessageData.protocolId, newMessageData.votingRoundId)).to.equal(true);

    const stateDataRaw = await relay.stateData();
    const stateData = stateDataName(stateDataRaw);
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(newMessageData.protocolId.toString());
    // This votingRoundId is lower than the current live pointer, so the
    // live random pointer does not regress to it; the per-round value is still stored and queryable.
    expect(toBN(stateData.randomVotingRoundId).toNumber()).to.be.at.least(newMessageData.votingRoundId);
    const historical = getRandomNumberName(await relay.getRandomNumberHistorical(newMessageData.votingRoundId));
    expect(historical._randomNumber.toString()).to.be.equal(toBN(100).toString());
    expect(historical._isSecureRandom.toString()).to.be.equal(newMessageData.isSecureRandom.toString());
  });

  it("Should fail to relay a message with old signing policy when a new was initialized and votingRoundId is over startingVotingRoundId", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = firstVotingRoundInRewardEpoch(signingPolicyData.rewardEpochId + 1) + 10; // new startingVotingRoundId is on +10
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, messageHash, Math.round(N * 0.6));

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "MustUseNewSignPolicy");
  });

  it("Should fail to relay a new signing policy due to not provided new sign policy size", async () => {
    // "No new sign policy size"

    const newSigningPolicyData = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);

    const signingPolicy = SigningPolicy.encode(signingPolicyData).slice(2);
    const fullData = signingPolicy + "00";

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWithCustomError(relayIface, "NoNewSignPolicySize");
  });

  it("Should fail to relay a new signing policy due to wrong size of new signing policy", async () => {
    // "Wrong size for new sign policy"
    const newSigningPolicyData = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);

    let newSigningPolicy = SigningPolicy.encode(newSigningPolicyData).slice(2);
    const signingPolicy = SigningPolicy.encode(signingPolicyData).slice(2);
    newSigningPolicy =
      (parseInt(newSigningPolicy.slice(0, 4), 16) + 1).toString(16).padStart(4, "0") + newSigningPolicy.slice(4);
    const fullData = signingPolicy + "00" + newSigningPolicy;

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWithCustomError(relayIface, "WrongSizeForNewSignPolicy");
  });

  it("Should fail to relay a new signing policy due to not providing last initialized signing policy for relaying new signing policy", async () => {
    // "Not next reward epoch"
    const newSigningPolicyData = { ...signingPolicyData };
    const result = await relay.lastInitializedRewardEpochData();
    const _lastInitializedRewardEpoch = result[0];
    const newRewardEpoch = parseInt(_lastInitializedRewardEpoch.toString()) + 2;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = SigningPolicy.hash(newSigningPolicyData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, localHash, N / 4 + 1);

    const relayMessage = {
      signingPolicy: newSigningPolicyDataRelayed,
      signatures,
      newSigningPolicy: newSigningPolicyData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "NotNextRewardEpoch");
  });

  it("Should fail to relay a new signing policy due to provided new signing policy for a wrong reward epoch", async () => {
    // "Not next reward epoch"
    const newSigningPolicyData = { ...signingPolicyData };
    const result = await relay.lastInitializedRewardEpochData();
    const _lastInitializedRewardEpoch = result[0];
    const newRewardEpoch = parseInt(_lastInitializedRewardEpoch.toString()) + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = SigningPolicy.hash(newSigningPolicyData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, localHash, N / 4 + 1);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      newSigningPolicy: newSigningPolicyData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "NotWithLastInitialized");
  });

  it("Should fail to relay a new signing policy due to wrong length of signature data", async () => {
    // "Not enough signatures"
    const newSigningPolicyData = { ...signingPolicyData };
    const result = await relay.lastInitializedRewardEpochData();
    const _lastInitializedRewardEpoch = result[0];
    const newRewardEpoch = parseInt(_lastInitializedRewardEpoch.toString()) + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    const weightSum = newSigningPolicyData.weights.reduce((a, b) => a + b, 0);
    newSigningPolicyData.threshold = Math.ceil(weightSum / 2);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = SigningPolicy.hash(newSigningPolicyData, chainId);
    const signatures = await generateSignaturesEncoded(accountPrivateKeys, localHash, N / 4 + 1);
    const newSigningPolicy = SigningPolicy.encode(newSigningPolicyData).slice(2);
    const signingPolicy = SigningPolicy.encode(newSigningPolicyDataRelayed).slice(2);
    const fullData = signingPolicy + "00" + newSigningPolicy + signatures.slice(0, -2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWithCustomError(relayIface, "NotEnoughSignatures");
  });

  it("Should fail to relay a new signing policy due to a wrong signature", async () => {
    // "Wrong signature"
    const newSigningPolicyData = { ...signingPolicyData };
    const result = await relay.lastInitializedRewardEpochData();
    const _lastInitializedRewardEpoch = result[0];
    const newRewardEpoch = parseInt(_lastInitializedRewardEpoch.toString()) + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    const weightSum = newSigningPolicyData.weights.reduce((a, b) => a + b, 0);
    newSigningPolicyData.threshold = Math.ceil(weightSum / 2);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = SigningPolicy.hash(newSigningPolicyData, chainId);
    const signatures = await generateSignaturesEncoded(accountPrivateKeys, localHash, N / 4 + 1);
    const newSigningPolicy = SigningPolicy.encode(newSigningPolicyData).slice(2);
    const signingPolicy = SigningPolicy.encode(newSigningPolicyDataRelayed).slice(2);
    const tweakedSignatures =
      signatures.slice(0, -6) +
      ((parseInt(signatures.slice(-6, -4), 16) + 1) % 256).toString(16).padStart(2, "0") +
      signatures.slice(-4);
    const fullData = signingPolicy + "00" + newSigningPolicy + tweakedSignatures;
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWithCustomError(relayIface, "WrongSignature");
  });
  it("Should fail to relay a message due to message already relayed", async () => {
    // "Already relayed"

    const messageHash = ProtocolMessageMerkleRoot.hash(messageData, chainId);

    const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: messageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWithCustomError(relayIface, "AlreadyRelayed");
  });

  describe("Direct signing policy setup", () => {
    it("Should directly set the signing policy", async () => {
      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay2 = await deployRelayProxy(relayInitialConfig, signers[0].address, constants.ZERO_ADDRESS);

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newSigningPolicyData.rewardEpochId);

      expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
        startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
        voters: newSigningPolicyData.voters,
        seed: toBN(newSigningPolicyData.seed),
        threshold: toBN(newSigningPolicyData.threshold),
        weights: newSigningPolicyData.weights.map((x) => toBN(x)),
        signingPolicyBytes: SigningPolicy.encode(newSigningPolicyData),
      });

      // console.dir(receipt);
      const result = await relay2.lastInitializedRewardEpochData();
      const _lastInitializedRewardEpoch = result[0];
      const _startingVotingRoundIdForLastInitializedRewardEpoch = result[1];
      expect(_lastInitializedRewardEpoch.toString()).to.equal(newSigningPolicyData.rewardEpochId.toString());
      expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(
        newSigningPolicyData.startVotingRoundId.toString()
      );
    });

    it("Should fail to directly set the signing policy due to wrong reward epoch", async () => {
      // "not next reward epoch"
      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay2 = await deployRelayProxy(relayInitialConfig, signers[0].address, constants.ZERO_ADDRESS);

      const newSigningPolicyData = { ...signingPolicyData };

      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "NotNextRewardEpoch");
      newSigningPolicyData.rewardEpochId += 2;
      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "NotNextRewardEpoch");
    });

    it("Should fail to directly set or relay the signing policy due to policy being trivial", async () => {
      // "must be non-trivial"

      const relayInitialConfig2: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay2 = await deployRelayProxy(relayInitialConfig2, signers[0].address, constants.ZERO_ADDRESS);

      const relayInitialConfig3: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay3 = await deployRelayProxy(relayInitialConfig3, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.voters = [];
      newSigningPolicyData.weights = [];
      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyEmpty");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWithCustomError(relayIface, "SigningPolicyEmpty");
    });

    it("Should fail due to voters and weights length mismatch", async () => {
      // "size mismatch"
      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay2 = await deployRelayProxy(relayInitialConfig, signers[0].address, constants.ZERO_ADDRESS);

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.weights = [];
      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "VotersWeightsSizeMismatch");
    });

    it("Should fail due to wrong setter", async () => {
      // "only sign policy setter"
      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay2 = await deployRelayProxy(relayInitialConfig, signers[0].address, constants.ZERO_ADDRESS);

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      await expectCustomError(
        relay2.setSigningPolicy(newSigningPolicyData, { from: signers[1].address }),
        "OnlySigningPolicySetterRole"
      );
    });

    it("Should fail to directly set the signing policy due to sum of weight being below threshold", async () => {
      // "not next reward epoch"
      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay2 = await deployRelayProxy(relayInitialConfig, signers[0].address, constants.ZERO_ADDRESS);

      const newSigningPolicyData = {
        ...signingPolicyData,
        rewardEpochId: signingPolicyData.rewardEpochId + 1,
        weights: [...signingPolicyData.weights],
      };
      let totalWeight = 0;
      for (let i = 0; i < newSigningPolicyData.weights.length; i++) {
        newSigningPolicyData.weights[i] = Math.floor(newSigningPolicyData.weights[i] / 3);
        totalWeight += newSigningPolicyData.weights[i];
      }
      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "ThresholdTooHigh");
      const dif = newSigningPolicyData.threshold - totalWeight;
      newSigningPolicyData.weights[0] += dif;
      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "ThresholdTooHigh");
      // newSigningPolicyData.weights[0] += 1;
      // expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized",
      //   {
      //     rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
      //     startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
      //     voters: newSigningPolicyData.voters,
      //     seed: toBN(newSigningPolicyData.seed),
      //     threshold: toBN(newSigningPolicyData.threshold),
      //     weights: newSigningPolicyData.weights.map(x => toBN(x)),
      //     signingPolicyBytes: SigningPolicy.encode(newSigningPolicyData)
      //   });
    });

    it("Should fail to relay new signing policy due to policy setter being set", async () => {
      const signingPolicy = SigningPolicy.encode(signingPolicyData);
      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hashEncoded(signingPolicy, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay2 = await deployRelayProxy(relayInitialConfig, signers[0].address, constants.ZERO_ADDRESS);

      const newSigningPolicyData = { ...signingPolicyData };
      const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
      newSigningPolicyData.rewardEpochId = newRewardEpoch;
      newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
      newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
      newSigningPolicyData.threshold = Math.round(newSigningPolicyData.threshold / 2);
      newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch) + 10; // create a delay
      const localHash = SigningPolicy.hash(newSigningPolicyData, chainId);

      const signatures = await generateSignatures(accountPrivateKeys, localHash, N / 2 + 1);

      const relayMessage = {
        signingPolicy: signingPolicyData,
        signatures,
        newSigningPolicy: newSigningPolicyData,
      };

      const fullData = RelayMessage.encode(relayMessage);

      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay2.address,
          data: selector + fullData.slice(2),
        })
      ).to.be.revertedWithCustomError(relayIface, "SignPolicyRelayDisabled");
    });

    it("Should fail directly setup voters with wrong number of voters", async () => {
      const newSigningPolicyData = defaultTestSigningPolicy(
        signers.map((x) => x.address),
        301, // max is 300
        200
      );
      newSigningPolicyData.rewardEpochId = signingPolicyData.rewardEpochId + 1;

      const relayInitialConfig2: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay2 = await deployRelayProxy(relayInitialConfig2, signers[0].address, constants.ZERO_ADDRESS);

      const relayInitialConfig3: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay3 = await deployRelayProxy(relayInitialConfig3, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);

      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "TooManyVoters");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWithCustomError(relayIface, "TooManyVoters");

      newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 300);
      newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 300);
      expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
        startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
        voters: newSigningPolicyData.voters,
        seed: toBN(newSigningPolicyData.seed),
        threshold: toBN(newSigningPolicyData.threshold),
        weights: newSigningPolicyData.weights.map((x) => toBN(x)),
        signingPolicyBytes: SigningPolicy.encode(newSigningPolicyData),
      });

      // Coverage: the relay() Mode-1 assembly path must ACCEPT exactly MAX_VOTERS (300), not only reject 301.
      const receipt300 = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay3.address,
        data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
      });
      await expectEvent.inTransaction(receipt300.transactionHash, relay3, "SigningPolicyRelayed", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
      });
    });

    it("Should fail due to total weight be too big or not in sync with threshold limits", async () => {
      const newSigningPolicyData = { ...signingPolicyData, weights: [...signingPolicyData.weights] };
      const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
      newSigningPolicyData.rewardEpochId = newRewardEpoch;
      newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);

      let totalWeight = 0;
      for (const weight of newSigningPolicyData.weights) {
        totalWeight += weight;
      }

      const relayInitialConfig2: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay2 = await deployRelayProxy(relayInitialConfig2, signers[0].address, constants.ZERO_ADDRESS);

      const relayInitialConfig3: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay3 = await deployRelayProxy(relayInitialConfig3, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);

      newSigningPolicyData.weights[0] = 2 ** 16 - 1;
      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "TotalWeightTooBig");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWithCustomError(relayIface, "TotalWeightTooBig");

      newSigningPolicyData.weights[0] = newSigningPolicyData.weights[1] + 1;
      newSigningPolicyData.threshold = Math.floor(totalWeight / 2);
      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "ThresholdTooLow");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWithCustomError(relayIface, "ThresholdTooLow");

      newSigningPolicyData.weights[0] = newSigningPolicyData.weights[1];
      newSigningPolicyData.threshold = Math.floor(totalWeight / 2) - 1;
      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "ThresholdTooLow");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWithCustomError(relayIface, "ThresholdTooLow");

      expect(totalWeight).to.equal(50000); // further tests are designed assuming 50000!
      newSigningPolicyData.threshold = Math.floor(totalWeight / 2);
      expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
        startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
        voters: newSigningPolicyData.voters,
        seed: toBN(newSigningPolicyData.seed),
        threshold: toBN(newSigningPolicyData.threshold),
        weights: newSigningPolicyData.weights.map((x) => toBN(x)),
        signingPolicyBytes: SigningPolicy.encode(newSigningPolicyData),
      });

      let receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay3.address,
        data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
      });

      await expectEvent.inTransaction(receipt.transactionHash, relay3, "SigningPolicyRelayed", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
      });

      const lastRelayedSigningPolicy = { ...newSigningPolicyData };

      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.threshold = Math.floor(totalWeight * 0.66) + 1;
      await expectCustomError(relay2.setSigningPolicy(newSigningPolicyData), "ThresholdTooHigh");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(lastRelayedSigningPolicy, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWithCustomError(relayIface, "ThresholdTooHigh");

      newSigningPolicyData.threshold = Math.floor(totalWeight * 0.66);
      expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
        startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
        voters: newSigningPolicyData.voters,
        seed: toBN(newSigningPolicyData.seed),
        threshold: toBN(newSigningPolicyData.threshold),
        weights: newSigningPolicyData.weights.map((x) => toBN(x)),
        signingPolicyBytes: SigningPolicy.encode(newSigningPolicyData),
      });

      receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay3.address,
        data: selector + (await prepareFullData(lastRelayedSigningPolicy, newSigningPolicyData)).slice(2),
      });

      await expectEvent.inTransaction(receipt.transactionHash, relay3, "SigningPolicyRelayed", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
      });
    });
  });

  describe("Verification", () => {
    it("Should verification work", async () => {
      const signingPolicyData = defaultTestSigningPolicy(
        signers.map((x) => x.address),
        N,
        singleWeight
      );
      signingPolicyData.rewardEpochId = rewardEpochId;
      signingPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
      const signingPolicy = SigningPolicy.encode(signingPolicyData);
      const localHash = SigningPolicy.hashEncoded(signingPolicy, chainId);

      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: localHash,
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [
          {
            protocolId: 17,
            fee: "1000",
          },
        ],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay = await deployRelayProxy(relayInitialConfig, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);

      const makeHashes = (i: number, shiftSeed = 0) =>
        new Array(i).fill(0).map((x, i) => ethers.keccak256(ethers.toBeHex(shiftSeed + i)));
      const hashes = makeHashes(100);
      const tree = new MerkleTree(hashes);
      const specificHash = hashes[10];

      const proof = tree.getProof(specificHash) ?? [];
      const newMessageData = { ...messageData };
      newMessageData.merkleRoot = tree.root!;
      const specificVotingRoundId = newMessageData.votingRoundId + 5;
      newMessageData.votingRoundId = specificVotingRoundId;
      newMessageData.protocolId = randomNumberProtocolId + 1; // non-random number protocol
      let messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
      let signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

      let relayMessage = {
        signingPolicy: signingPolicyData,
        signatures,
        protocolMessageMerkleRoot: newMessageData,
      };

      let fullData = RelayMessage.encode(relayMessage);
      let receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      });
      expect(verifyWithMerkleProof(specificHash, proof, tree.root!)).to.be.true;
      const oldBalance = Number(await web3.eth.getBalance(BURN_ADDRESS));
      await relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof);

      newMessageData.protocolId = 17;

      messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
      signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

      relayMessage = {
        signingPolicy: signingPolicyData,
        signatures,
        protocolMessageMerkleRoot: newMessageData,
      };

      fullData = RelayMessage.encode(relayMessage);

      receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      });

      await expectCustomError(
        relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof),
        "TooLowFee"
      );
      await expectCustomError(
        relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof, { value: "999" }),
        "TooLowFee"
      );
      await relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof, {
        value: "1000",
      });
      const newBalance = Number(await web3.eth.getBalance(BURN_ADDRESS));
      expect(newBalance - oldBalance).to.equal(1000);

      // Overpayment is refunded; feeCollection receives only the fee (1000), not the full 2000.
      const beforeOverpay = Number(await web3.eth.getBalance(BURN_ADDRESS));
      await relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof, {
        value: "2000",
      });
      const afterOverpay = Number(await web3.eth.getBalance(BURN_ADDRESS));
      expect(afterOverpay - beforeOverpay).to.equal(1000);
    });

    it("Should verification work with an ERC-20 fee token", async () => {
      // Mirror-on-Tempo shape: verify() fees are paid in a 6-decimals stablecoin via
      // allowance + transferFrom (msg.value must be 0), pulled straight to the collector.
      const ERC20Mock = artifacts.require("ERC20Mock");
      const feeToken = await ERC20Mock.new("USDT0", "USDT0", 6);

      const signingPolicyData = defaultTestSigningPolicy(
        signers.map((x) => x.address),
        N,
        singleWeight
      );
      signingPolicyData.rewardEpochId = rewardEpochId;
      signingPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
      const signingPolicy = SigningPolicy.encode(signingPolicyData);
      const localHash = SigningPolicy.hashEncoded(signingPolicy, chainId);

      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: localHash,
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [
          {
            protocolId: 17,
            fee: "1000",
          },
        ],
        feeToken: feeToken.address,
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay = await deployRelayProxy(relayInitialConfig, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
      expect(await relay.feeToken()).to.equal(feeToken.address);
      // The deprecated wei-named getter fails closed in token mode; the primary getter serves it.
      expect((await relay.protocolFee(17)).toString()).to.equal("1000");
      await expectCustomError(relay.protocolFeeInWei(17), "FeeTokenActive");

      // Finalize a root for protocol 17.
      const makeHashes = (i: number, shiftSeed = 0) =>
        new Array(i).fill(0).map((x, i) => ethers.keccak256(ethers.toBeHex(shiftSeed + i)));
      const hashes = makeHashes(100);
      const tree = new MerkleTree(hashes);
      const specificHash = hashes[10];
      const proof = tree.getProof(specificHash) ?? [];
      const newMessageData = { ...messageData };
      newMessageData.merkleRoot = tree.root!;
      newMessageData.votingRoundId = newMessageData.votingRoundId + 5;
      newMessageData.protocolId = 17;
      const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
      const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);
      const fullData = RelayMessage.encode({
        signingPolicy: signingPolicyData,
        signatures,
        protocolMessageMerkleRoot: newMessageData,
      });
      await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      });

      // Without an allowance the token itself rejects the pull.
      await feeToken.mintAmount(signers[0].address, "5000");
      await expectCustomError(
        relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof),
        "ERC20InsufficientAllowance"
      );

      // Attached native value is rejected — the fee is paid exclusively in the token.
      await feeToken.approve(relay.address, "1000");
      await expectCustomError(
        relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof, { value: "1" }),
        "MsgValueNotAllowed"
      );

      // The exact fee lands at the collector in tokens; the caller pays exactly the fee.
      await relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof);
      expect((await feeToken.balanceOf(BURN_ADDRESS)).toString()).to.equal("1000");
      expect((await feeToken.balanceOf(signers[0].address)).toString()).to.equal("4000");
      expect((await feeToken.balanceOf(relay.address)).toString()).to.equal("0");
    });

    it("Should reject verification against an unfinalized (zero) root", async () => {
      const signingPolicyData = defaultTestSigningPolicy(
        signers.map((x) => x.address),
        N,
        singleWeight
      );
      signingPolicyData.rewardEpochId = rewardEpochId;
      signingPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
      const localHash = SigningPolicy.hashEncoded(SigningPolicy.encode(signingPolicyData), chainId);
      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: localHash,
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };
      const relay = await deployRelayProxy(relayInitialConfig, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
      // Nothing is relayed for protocol 16 / round 12345, so the stored root is zero and verification
      // must revert even for a zero leaf with an empty proof.
      await expectCustomError(
        relay.verify(randomNumberProtocolId + 1, 12345, constants.ZERO_BYTES32, []),
        "NotFinalized"
      );
    });
  });

  describe("Constructor validation", () => {
    function baseConfig(): RelayInitialConfig {
      const sp = defaultTestSigningPolicy(
        signers.map((x) => x.address),
        N,
        singleWeight
      );
      sp.rewardEpochId = rewardEpochId;
      sp.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
      return {
        initialRewardEpochId: sp.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: sp.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hashEncoded(SigningPolicy.encode(sp), chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };
    }

    it("Should deploy with a valid config (sanity)", async () => {
      await deployRelayProxy(baseConfig(), constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
    });

    it("rejects zero rewardEpochDurationInVotingEpochs", async () => {
      const cfg = baseConfig();
      cfg.rewardEpochDurationInVotingEpochs = 0;
      await expectCustomError(
        deployRelayProxy(cfg, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS),
        "RewardEpochDurationZero"
      );
    });

    it("rejects zero votingEpochDurationSeconds", async () => {
      const cfg = baseConfig();
      cfg.votingEpochDurationSeconds = 0;
      await expectCustomError(
        deployRelayProxy(cfg, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS),
        "VotingEpochDurationZero"
      );
    });

    it("rejects zero feeCollectionAddress in relay mode", async () => {
      const cfg = baseConfig();
      cfg.feeCollectionAddress = constants.ZERO_ADDRESS;
      await expectCustomError(
        deployRelayProxy(cfg, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS),
        "FeeCollectionAddressZero"
      );
    });

    it("allows zero feeCollectionAddress in setter mode", async () => {
      const cfg = baseConfig();
      cfg.feeCollectionAddress = constants.ZERO_ADDRESS;
      await deployRelayProxy(cfg, signers[0].address, constants.ZERO_ADDRESS); // signingPolicySetter != 0
    });
  });

  describe("Custom hash signing", () => {
    it("Should verification work", async () => {
      const signingPolicyData = defaultTestSigningPolicy(
        signers.map((x) => x.address),
        N,
        singleWeight
      );
      signingPolicyData.rewardEpochId = rewardEpochId;
      signingPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
      const signingPolicy = SigningPolicy.encode(signingPolicyData);
      const localHash = SigningPolicy.hashEncoded(signingPolicy, chainId);

      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: localHash,
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay = await deployRelayProxy(relayInitialConfig, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);

      const specificHash = web3.utils.keccak256("Something");

      const newMessageData = { ...messageData };
      newMessageData.merkleRoot = specificHash;
      newMessageData.votingRoundId = 0;
      newMessageData.isSecureRandom = false;
      newMessageData.protocolId = 1;
      const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
      const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

      const relayMessage = {
        signingPolicy: signingPolicyData,
        signatures,
        protocolMessageMerkleRoot: newMessageData,
      };

      let fullData = RelayMessage.encode(relayMessage);
      const result = await web3.eth.call({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      });
      expect(result.slice(0, 66)).to.equal(newMessageData.merkleRoot);
      expect(parseInt(result.slice(66), 16)).to.equal(rewardEpochId);
      newMessageData.votingRoundId = 1;
      fullData = RelayMessage.encode(relayMessage);
      await expectCustomError(
        web3.eth.sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: selector + fullData.slice(2),
        }),
        "WrongMessageFormat"
      );
      newMessageData.votingRoundId = 0;
      newMessageData.isSecureRandom = true;
      fullData = RelayMessage.encode(relayMessage);
      await expectCustomError(
        web3.eth.sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: selector + fullData.slice(2),
        }),
        "WrongMessageFormat2"
      );
    });
  });

  describe("Random number test", () => {
    it("Should historical random number work", async () => {
      const signingPolicyData = defaultTestSigningPolicy(
        signers.map((x) => x.address),
        N,
        singleWeight
      );
      signingPolicyData.rewardEpochId = rewardEpochId;
      signingPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
      const signingPolicy = SigningPolicy.encode(signingPolicyData);
      const localHash = SigningPolicy.hashEncoded(signingPolicy, chainId);

      const relayInitialConfig: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: localHash,
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay = await deployRelayProxy(relayInitialConfig, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);

      const hashes = new Map<number, string>();
      const isSecure = new Map<number, boolean>();
      const randomNumbers = new Map<number, string>();
      const startVotingRoundId = signingPolicyData.startVotingRoundId;
      const MAX_NUM = 1000;
      const STEP = 39;
      for (let i = 0; i < MAX_NUM; i += STEP) {
        const random = Math.random() > 0.5;
        isSecure.set(startVotingRoundId + i, random);
        const newMessageData = {
          merkleRoot: "", // will be set in prepareDataWithRandom
          votingRoundId: startVotingRoundId + i,
          isSecureRandom: random,
          protocolId: randomNumberProtocolId,
        };
        const { randomNumberResult, relayData } = prepareDataWithRandom(newMessageData, 100 + i);
        hashes.set(startVotingRoundId + i, newMessageData.merkleRoot);
        randomNumbers.set(startVotingRoundId + i, randomNumberResult.value);
        const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
        const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

        const relayMessage = {
          signingPolicy: signingPolicyData,
          signatures,
          protocolMessageMerkleRoot: newMessageData,
          ...relayData,
        };

        const fullData = RelayMessage.encode(relayMessage);
        await web3.eth.sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: selector + fullData.slice(2),
        });

        const getRandomNumberRaw = await relay.getRandomNumber();
        let { _randomNumber, _isSecureRandom, _randomTimestamp } = getRandomNumberName(getRandomNumberRaw);
        expect(_isSecureRandom).to.equal(random);
        expect(_randomNumber.toString()).to.equal(BigInt(randomNumberResult.value).toString());
        expect(_randomTimestamp.toNumber()).to.equal(
          firstVotingRoundStartSec + votingRoundDurationSec * (newMessageData.votingRoundId + 1)
        );
        expect((await relay.getVotingRoundId(_randomTimestamp)).toNumber()).to.be.equal(
          toBN(newMessageData.votingRoundId + 1)
        );

        const getRandomNumberHistoricalRaw = await relay.getRandomNumberHistorical(newMessageData.votingRoundId);
        ({ _randomNumber, _isSecureRandom, _randomTimestamp } = getRandomNumberName(getRandomNumberHistoricalRaw));
        expect(_randomNumber.toString()).to.equal(BigInt(randomNumberResult.value).toString());
        expect(_randomTimestamp.toNumber()).to.equal(
          firstVotingRoundStartSec + votingRoundDurationSec * (newMessageData.votingRoundId + 1)
        );
        expect(_isSecureRandom).to.equal(random);
      }

      for (let i = 0; i < MAX_NUM; i++) {
        const votingRoundId = startVotingRoundId + i;
        if (hashes.get(votingRoundId)) {
          const getRandomNumberHistoricalRaw = await relay.getRandomNumberHistorical(votingRoundId);
          const { _randomNumber, _isSecureRandom, _randomTimestamp } =
            getRandomNumberName(getRandomNumberHistoricalRaw);
          expect(_randomNumber.toString()).to.equal(BigInt(randomNumbers.get(votingRoundId)!).toString());
          expect(_randomTimestamp.toNumber()).to.equal(
            firstVotingRoundStartSec + votingRoundDurationSec * (votingRoundId + 1)
          );
          expect(_isSecureRandom).to.equal(isSecure.get(votingRoundId));
        } else {
          await expectCustomError(relay.getRandomNumberHistorical(votingRoundId), "NoRandomNumber");
        }
      }
    });
  });

  describe("Usage with old relay contract", () => {
    it("Should have old relay contract match", async () => {
      const relayInitialConfig1: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relay1 = await deployRelayProxy(relayInitialConfig1, signers[0].address, constants.ZERO_ADDRESS);

      // Old-relay migration is home-only: a relay-mode (mirror) deployment must not carry an old
      // relay — its verify() fees would entangle with the old relay's fee schedule.
      await expectCustomError(
        deployRelayProxy(relayInitialConfig1, constants.ZERO_ADDRESS, relay1.address),
        "OldRelayNotAllowedInRelayMode"
      );

      // A setter-mode new deployment against a relay-mode old relay is incompatible.
      const relayModeOld = await deployRelayProxy(relayInitialConfig1, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
      await expectCustomError(
        deployRelayProxy(relayInitialConfig1, signers[1].address, relayModeOld.address),
        "OldRelayIncompatible"
      );

      await expectCustomError(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            thresholdIncreaseBIPS: 9000,
          },
          signers[1].address,
          relay1.address
        ),
        "ThresholdIncreaseTooSmall"
      );

      await expectCustomError(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            startingVotingRoundIdForInitialRewardEpochId: 0,
          },
          signers[1].address,
          relay1.address
        ),
        "InvalidInitialStartingVotingRoundId"
      );

      await expectCustomError(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            firstRewardEpochStartVotingRoundId: 1000000000,
          },
          signers[1].address,
          relay1.address
        ),
        "InvalidInitialStartingVotingRoundId"
      );

      await expectCustomError(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            initialRewardEpochId: 100000,
          },
          signers[1].address,
          relay1.address
        ),
        "InvalidInitialStartingVotingRoundId"
      );

      await expectCustomError(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            rewardEpochDurationInVotingEpochs: 10000,
          },
          signers[1].address,
          relay1.address
        ),
        "InvalidInitialStartingVotingRoundId"
      );

      await expectCustomError(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            startingVotingRoundIdForInitialRewardEpochId: 0,
          },
          signers[1].address,
          relay1.address
        ),
        "InvalidInitialStartingVotingRoundId"
      );

      await expectRevert(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            randomNumberProtocolId: 0,
          },
          signers[1].address,
          relay1.address
        ),
        "InvalidRandomNumberProtocolId"
      );

      await expectRevert(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            feeConfigs: [
              {
                protocolId: 17,
                fee: "1000",
              },
            ],
          },
          signers[1].address,
          relay1.address
        ),
        "FeeConfigNotAllowed"
      );

      await expectRevert(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            feeConfigs: [
              {
                protocolId: 1,
                fee: "1000",
              },
            ],
          },
          constants.ZERO_ADDRESS,
          relay1.address
        ),
        "InvalidProtocolId"
      );

      await expectRevert(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            firstVotingRoundStartTs: relayInitialConfig1.firstVotingRoundStartTs + 1,
          },
          signers[1].address,
          relay1.address
        ),
        "OldRelayWrongStartTs"
      );

      await expectRevert(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            rewardEpochDurationInVotingEpochs: relayInitialConfig1.rewardEpochDurationInVotingEpochs - 1,
          },
          signers[1].address,
          relay1.address
        ),
        "OldRelayWrongRewardEpochDuration"
      );

      await expectRevert(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            firstRewardEpochStartVotingRoundId: relayInitialConfig1.firstRewardEpochStartVotingRoundId - 1,
          },
          signers[1].address,
          relay1.address
        ),
        "OldRelayWrongFirstRewardEpochStart"
      );

      await expectRevert(
        deployRelayProxy(
          {
            ...relayInitialConfig1,
            votingEpochDurationSeconds: relayInitialConfig1.votingEpochDurationSeconds - 1,
          },
          signers[1].address,
          relay1.address
        ),
        "OldRelayWrongVotingEpochDuration"
      );
    });
    it("Should verify on old and new relay contract", async () => {
      const switchOffset = 2;
      const messageDataBase = {
        ...messageData,
        votingRoundId: messageData.votingRoundId + rewardEpochDurationInVotingEpochs, // shift to next reward epoch
      };
      const votingRoundIdBase = messageDataBase.votingRoundId;

      const newSigningPolicyData = { ...signingPolicyData };
      const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
      newSigningPolicyData.rewardEpochId = newRewardEpoch;
      const newSigningPolicyHash = SigningPolicy.hash(newSigningPolicyData, chainId);

      const relayInitialConfigOldFlare: RelayInitialConfig = {
        initialRewardEpochId: signingPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: signingPolicyData.startVotingRoundId,
        initialSigningPolicyHash: SigningPolicy.hash(signingPolicyData, chainId),
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relayInitialConfigNewFlare: RelayInitialConfig = {
        initialRewardEpochId: newSigningPolicyData.rewardEpochId,
        startingVotingRoundIdForInitialRewardEpochId: votingRoundIdBase + switchOffset,
        initialSigningPolicyHash: newSigningPolicyHash,
        randomNumberProtocolId: randomNumberProtocolId,
        firstVotingRoundStartTs: firstVotingRoundStartSec,
        votingEpochDurationSeconds: votingRoundDurationSec,
        firstRewardEpochStartVotingRoundId: firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs: rewardEpochDurationInVotingEpochs,
        thresholdIncreaseBIPS: THRESHOLD_INCREASE,
        messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
        feeCollectionAddress: BURN_ADDRESS,
        feeConfigs: [],
        sourceChainId: chainId,
        timelockDurationSeconds: 0,
      };

      const relayOldFlare = await deployRelayProxy(
        relayInitialConfigOldFlare,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

      const relayInitialConfigOldRelay: RelayInitialConfig = {
        ...relayInitialConfigOldFlare,
      };

      const relayOldRelay = await deployRelayProxy(
        relayInitialConfigOldRelay,
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS
      );

      const relayNewFlare = await deployRelayProxy(
        relayInitialConfigNewFlare,
        signers[0].address,
        relayOldFlare.address
      );

      // Old-relay migration is home-only: a relay-mode deployment with an old relay is rejected,
      // so there is no relay-mode old->new migration pair to test — only the Flare (setter-mode)
      // pair delegates below the boundary.
      await expectCustomError(
        deployRelayProxy({ ...relayInitialConfigNewFlare }, constants.ZERO_ADDRESS, relayOldRelay.address),
        "OldRelayNotAllowedInRelayMode"
      );

      // Relay two merkle roots for random generating protocol and another protocol at
      // firstVotingRoundInRewardEpoch and firstVotingRoundInRewardEpoch + 1.
      // Relay this on the Flare (setter-mode) old/new pair and the standalone relay-mode contract
      // (relay-mode migration pairs are rejected — old relay is home-only).
      // The new relay contract is set to start with firstRewardEpochVotingRoundId + 2.
      // Relay merkle roots also for firstVotingRoundInRewardEpoch + 2 and +3.

      const isFlare = new Map<RelayInstance, boolean>();
      isFlare.set(relayOldFlare, true);
      isFlare.set(relayOldRelay, false);
      isFlare.set(relayNewFlare, true);
      const isNew = new Map<RelayInstance, boolean>();
      isNew.set(relayOldFlare, false);
      isNew.set(relayOldRelay, false);
      isNew.set(relayNewFlare, true);

      const allRelays = [relayOldFlare, relayOldRelay, relayNewFlare];

      const votingRoundIdAndProtocolIdToMerkleRoot = new Map<string, string>();
      const votingRoundIdAndProtocolIdExampleLeaf = new Map<string, string>();
      const votingRoundIdAndProtocolIdExampleProof = new Map<string, string[]>();

      // set new signing policy on old flare contract
      await relayOldFlare.setSigningPolicy(newSigningPolicyData);

      const signaturesSP = await generateSignatures(accountPrivateKeys, newSigningPolicyHash, N / 2 + 1);

      const relayMessageSP = {
        signingPolicy: signingPolicyData,
        signatures: signaturesSP,
        newSigningPolicy: newSigningPolicyData,
      };

      const fullDataSP = RelayMessage.encode(relayMessageSP);

      const receiptSP = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relayOldRelay.address,
        data: selector + fullDataSP.slice(2),
      });
      await expectEvent.inTransaction(receiptSP.transactionHash, relayOldRelay, "SigningPolicyRelayed", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
      });

      for (let votingRoundOffset = 0; votingRoundOffset <= 4; votingRoundOffset++) {
        const randomNumber = 100 + votingRoundOffset;
        const isOldRelaying = votingRoundOffset < switchOffset;
        for (const protocolId of [randomNumberProtocolId, randomNumberProtocolId + 1]) {
          const isRandomNumberProtocol = protocolId === randomNumberProtocolId;
          const newMessageDataTmp = {
            ...messageDataBase,
            votingRoundId: votingRoundIdBase + votingRoundOffset,
            protocolId,
            isSecureRandom: isRandomNumberProtocol,
          };
          const newMessageData = newMessageDataTmp;
          let leaf: string;
          let proof: string[];
          let relayData = {};
          if (isRandomNumberProtocol) {
            // For the random-number protocol the merkle root must contain the random-number leaf
            // (so the appended random-number trailer verifies); use that leaf/proof as the example.
            const prepared = prepareDataWithRandom(newMessageData, randomNumber);
            leaf = prepared.randomNumberLeaf;
            proof = prepared.relayData.merkleProof;
            relayData = prepared.relayData;
          } else {
            // initialize a random merkle root
            newMessageData.merkleRoot = ethers.hexlify(ethers.randomBytes(32));
            leaf = newMessageData.merkleRoot;
            proof = [];
          }
          votingRoundIdAndProtocolIdToMerkleRoot.set(
            `${votingRoundIdBase + votingRoundOffset}-${protocolId}`,
            newMessageData.merkleRoot
          );
          votingRoundIdAndProtocolIdExampleLeaf.set(`${votingRoundIdBase + votingRoundOffset}-${protocolId}`, leaf);
          votingRoundIdAndProtocolIdExampleProof.set(`${votingRoundIdBase + votingRoundOffset}-${protocolId}`, proof);
          const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
          const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

          const relayMessage = {
            signingPolicy: newSigningPolicyData,
            signatures,
            protocolMessageMerkleRoot: newMessageData,
            ...relayData,
          };

          const fullData = RelayMessage.encode(relayMessage);
          for (const relayContract of allRelays) {
            // skip relaying to new relay contracts
            if (isOldRelaying && isNew.get(relayContract)!) {
              continue;
            }
            // skip relaying to old relay contracts
            if (!isOldRelaying && !isNew.get(relayContract)!) {
              continue;
            }

            const receipt = await web3.eth.sendTransaction({
              from: signers[0].address,
              to: relayContract.address,
              data: selector + fullData.slice(2),
            });
            await expectEvent.inTransaction(receipt.transactionHash, relayContract, "ProtocolMessageRelayed", {
              protocolId: toBN(newMessageData.protocolId),
              votingRoundId: toBN(newMessageData.votingRoundId),
              isSecureRandom: newMessageData.isSecureRandom,
              merkleRoot: newMessageData.merkleRoot,
            });
          }
        }
      }
      // Verification tests
      for (const relayContract of allRelays) {
        // skip non Flare contracts
        for (let votingRoundOffset = 0; votingRoundOffset <= 4; votingRoundOffset++) {
          const isOldRelaying = votingRoundOffset < switchOffset;

          const votingRoundId = votingRoundIdBase + votingRoundOffset;
          for (const protocolId of [randomNumberProtocolId, randomNumberProtocolId + 1]) {
            if (!isFlare.get(relayContract)!) {
              // Test non-flare contracts for successful/expected finalization
              const isFinalized = await relayContract.isFinalized(protocolId, votingRoundId);
              expect(isFinalized).to.equal(isNew.get(relayContract) || isOldRelaying);
              continue;
            }

            const merkleRoot = votingRoundIdAndProtocolIdToMerkleRoot.get(`${votingRoundId}-${protocolId}`)!;

            // check if merkle trees match on old relaying contracts when isOldRelaying is true and
            // check that merkle trees match on new relaying contracts when isOldRelaying is false
            // In all other cases merkle trees should be zero
            const value = isFlare.get(relayContract)! ? "0" : "1000";
            if (isOldRelaying) {
              if (isNew.get(relayContract)!) {
                // new relay contract, old relaying - should be zero
                const merkleRootFromContract = await relayContract.merkleRoots(protocolId, votingRoundId);
                // the call should redirect to old relay contract
                expect(merkleRootFromContract).to.equal(merkleRoot);
                const isFinalized = await relayContract.isFinalized(protocolId, votingRoundId);
                expect(isFinalized).to.equal(true);
                expect(
                  await relayContract.verify.call(
                    protocolId,
                    votingRoundId,
                    votingRoundIdAndProtocolIdExampleLeaf.get(`${votingRoundId}-${protocolId}`)!,
                    votingRoundIdAndProtocolIdExampleProof.get(`${votingRoundId}-${protocolId}`)!,
                    { value }
                  )
                ).to.equal(true);
              } else {
                // old relay contract, old relaying - should match
                const merkleRootFromContract = await relayContract.merkleRoots(protocolId, votingRoundId);
                expect(merkleRootFromContract).to.equal(merkleRoot);
                const isFinalized = await relayContract.isFinalized(protocolId, votingRoundId);
                expect(isFinalized).to.equal(true);
                expect(
                  await relayContract.verify.call(
                    protocolId,
                    votingRoundId,
                    votingRoundIdAndProtocolIdExampleLeaf.get(`${votingRoundId}-${protocolId}`)!,
                    votingRoundIdAndProtocolIdExampleProof.get(`${votingRoundId}-${protocolId}`)!,
                    { value }
                  )
                ).to.equal(true);
              }
            } else {
              if (isNew.get(relayContract)!) {
                // new relay contract, new relaying - should match
                const merkleRootFromContract = await relayContract.merkleRoots(protocolId, votingRoundId);
                expect(merkleRootFromContract).to.equal(merkleRoot);
                const isFinalized = await relayContract.isFinalized(protocolId, votingRoundId);
                expect(isFinalized).to.equal(true);
                expect(
                  await relayContract.verify.call(
                    protocolId,
                    votingRoundId,
                    votingRoundIdAndProtocolIdExampleLeaf.get(`${votingRoundId}-${protocolId}`)!,
                    votingRoundIdAndProtocolIdExampleProof.get(`${votingRoundId}-${protocolId}`)!,
                    { value }
                  )
                ).to.equal(true);
              } else {
                // old relay contract, new relaying - should be zero
                const merkleRootFromContract = await relayContract.merkleRoots(protocolId, votingRoundId);
                expect(merkleRootFromContract).to.equal(constants.ZERO_BYTES32);
                const isFinalized = await relayContract.isFinalized(protocolId, votingRoundId);
                expect(isFinalized).to.equal(false);
              }
            }
          }
        }
      }

      let oldRelayRewardEpochId = await relayOldFlare.toSigningPolicyHash(newRewardEpoch - 1);
      let newRelayRewardEpochId = await relayNewFlare.toSigningPolicyHash(newRewardEpoch - 1);
      expect(oldRelayRewardEpochId).to.equal(newRelayRewardEpochId);

      oldRelayRewardEpochId = await relayOldFlare.toSigningPolicyHash(newRewardEpoch);
      newRelayRewardEpochId = await relayNewFlare.toSigningPolicyHash(newRewardEpoch);
      expect(oldRelayRewardEpochId).to.equal(newRelayRewardEpochId);
      expect(await relayNewFlare.initialRewardEpochId()).to.equal(toBN(newRewardEpoch));
      expect(await relayOldFlare.initialRewardEpochId()).to.equal(toBN(newRewardEpoch - 1));
    });
  });

  describe("Ecrecover return size check", () => {
    it("Baseline: legitimate relay with real signatures succeeds", async () => {
      const merkleRoot = ethers.hexlify(ethers.randomBytes(32));
      const messageData: IProtocolMessageMerkleRoot = {
        protocolId: randomNumberProtocolId,
        // votingRoundId,
        votingRoundId: testVotingRoundId,
        isSecureRandom: true,
        merkleRoot,
      };

      const { relayData } = prepareDataWithRandom(messageData, 100);
      const messageHash = ProtocolMessageMerkleRoot.hash(messageData, chainId);
      const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

      const relayMessage = {
        signingPolicy: signingPolicyData,
        signatures,
        protocolMessageMerkleRoot: messageData,
        ...relayData,
      };

      const fullData = RelayMessage.encode(relayMessage);

      const receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      });

      await expectEvent.inTransaction(receipt.transactionHash, relay, "ProtocolMessageRelayed", {
        protocolId: toBN(messageData.protocolId),
        votingRoundId: toBN(messageData.votingRoundId),
        isSecureRandom: messageData.isSecureRandom,
        merkleRoot: messageData.merkleRoot,
      });

      expect(await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)).to.equal(true);
    });

    it("Check for return data size", async () => {
      // const attackVotingRoundId = votingRoundId + 1;
      const attackVotingRoundId = testVotingRoundId + 1;
      const attackMerkleRoot = "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef";

      const messageData: IProtocolMessageMerkleRoot = {
        protocolId: randomNumberProtocolId,
        votingRoundId: attackVotingRoundId,
        isSecureRandom: true,
        merkleRoot: attackMerkleRoot,
      };

      expect(await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)).to.equal(false);

      const signingPolicyEncoded = SigningPolicy.encode(signingPolicyData).slice(2);
      const messageEncoded = ProtocolMessageMerkleRoot.encode(messageData).slice(2);

      const requiredSigners = N / 2 + 1;
      const forgedSigs = generateForgedSignatures(signingPolicyData.voters, requiredSigners);

      const signaturesEncoded = encodeForgedSignatures(forgedSigs);

      const fullCalldata = selector + signingPolicyEncoded + messageEncoded + signaturesEncoded;

      // const receipt = await web3.eth.sendTransaction({
      //   from: signers[0].address,
      //   to: relay.address,
      //   data: fullCalldata,
      // });

      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: fullCalldata,
        })
      ).to.be.revertedWithCustomError(relayIface, "EcrecoverReturnedBadData");

      expect(await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)).to.equal(false);
    });

    it("Check for return data size, differnet protocol id", async () => {
      const attackProtocolId = randomNumberProtocolId + 1;
      // const attackVotingRoundId = votingRoundId + 2;
      const attackVotingRoundId = testVotingRoundId + 2;
      const attackMerkleRoot = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

      const messageData: IProtocolMessageMerkleRoot = {
        protocolId: attackProtocolId,
        votingRoundId: attackVotingRoundId,
        isSecureRandom: false,
        merkleRoot: attackMerkleRoot,
      };

      expect(await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)).to.equal(false);

      const signingPolicyEncoded = SigningPolicy.encode(signingPolicyData).slice(2);
      const messageEncoded = ProtocolMessageMerkleRoot.encode(messageData).slice(2);

      const requiredSigners = N / 2 + 1;
      const forgedSigs = generateForgedSignatures(signingPolicyData.voters, requiredSigners);
      const signaturesEncoded = encodeForgedSignatures(forgedSigs);

      const fullCalldata = selector + signingPolicyEncoded + messageEncoded + signaturesEncoded;

      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: fullCalldata,
        })
      ).to.be.revertedWithCustomError(relayIface, "EcrecoverReturnedBadData");

      expect(await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)).to.equal(false);
    });

    it("Sanity check: v=0 forged sig is rejected by the canonical-signature check", async () => {
      // const attackVotingRoundId = votingRoundId + 4;
      const attackVotingRoundId = testVotingRoundId + 4;
      const messageData: IProtocolMessageMerkleRoot = {
        protocolId: randomNumberProtocolId,
        votingRoundId: attackVotingRoundId,
        isSecureRandom: true,
        merkleRoot: "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      };

      const signingPolicyEncoded = SigningPolicy.encode(signingPolicyData).slice(2);
      const messageEncoded = ProtocolMessageMerkleRoot.encode(messageData).slice(2);

      const badSigs: IECDSASignatureWithIndex[] = [];
      for (let i = 0; i < N / 2 + 1; i++) {
        badSigs.push({
          v: 0,
          r: "0x" + "0".repeat(24) + "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
          s: "0x0000000000000000000000000000000000000000000000000000000000000001",
          index: i,
        });
      }
      const signaturesEncoded = encodeForgedSignatures(badSigs);
      const fullCalldata = selector + signingPolicyEncoded + messageEncoded + signaturesEncoded;

      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: fullCalldata,
        })
      ).to.be.revertedWithCustomError(relayIface, "BadV");
    });

    it("High-s forged signature is rejected", async () => {
      const attackVotingRoundId = testVotingRoundId + 5;
      const messageData: IProtocolMessageMerkleRoot = {
        protocolId: randomNumberProtocolId + 1, // non-random protocol (no trailer needed; reverts before)
        votingRoundId: attackVotingRoundId,
        isSecureRandom: false,
        merkleRoot: "0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
      };
      const signingPolicyEncoded = SigningPolicy.encode(signingPolicyData).slice(2);
      const messageEncoded = ProtocolMessageMerkleRoot.encode(messageData).slice(2);
      const badSigs: IECDSASignatureWithIndex[] = [];
      for (let i = 0; i < N / 2 + 1; i++) {
        badSigs.push({
          v: 27,
          r: "0x0000000000000000000000000000000000000000000000000000000000000001",
          s: "0x8000000000000000000000000000000000000000000000000000000000000001", // > secp256k1n/2
          index: i,
        });
      }
      const signaturesEncoded = encodeForgedSignatures(badSigs);
      const fullCalldata = selector + signingPolicyEncoded + messageEncoded + signaturesEncoded;
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: fullCalldata,
        })
      ).to.be.revertedWithCustomError(relayIface, "BadS");
    });
  });
});
