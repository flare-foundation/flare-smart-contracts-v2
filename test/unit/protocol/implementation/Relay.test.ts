import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { constants, expectEvent, expectRevert } from "@openzeppelin/test-helpers";
import { artifacts, config, contract, ethers, expect } from "hardhat";
import { HardhatNetworkAccountConfig } from "hardhat/types";
import { RelayInitialConfig } from "../../../../deployment/utils/RelayInitialConfig";
import { IProtocolMessageMerkleRoot, ProtocolMessageMerkleRoot } from "../../../../scripts/libs/protocol/ProtocolMessageMerkleRoot";
import { RelayMessage } from "../../../../scripts/libs/protocol/RelayMessage";
import {
  ISigningPolicy,
  SigningPolicy
} from "../../../../scripts/libs/protocol/SigningPolicy";
import { RelayInstance } from "../../../../typechain-truffle";
import { MerkleTree, verifyWithMerkleProof } from "../../../utils/MerkleTree";
import { getTestFile } from "../../../utils/constants";
import { toBN } from "../../../utils/test-helpers";
import { defaultTestSigningPolicy, generateSignatures, generateSignaturesEncoded } from "../coding/coding-helpers";
import { RelayContract } from "../../../../typechain-truffle";
import { ParamType } from "ethers";
import { IECDSASignatureWithIndex } from "../../../../scripts/libs/protocol/ECDSASignatureWithIndex";
const coder = ethers.AbiCoder.defaultAbiCoder();

const Relay: RelayContract = artifacts.require("Relay");

const BURN_ADDRESS = "0x000000000000000000000000000000000000dEaD";

interface FeeConfig {
  protocolId: number;
  feeInWei: string;
}

interface RelayGovernanceConfig {
  descriptionHash: string;
  chainId: number;
  nonce: number;
  newFeeConfigs: FeeConfig[];
}

const RelayGovernanceConfigABI = {
  "components": [
    {
      "internalType": "bytes32",
      "name": "descriptionHash",
      "type": "bytes32"
    },
    {
      "internalType": "uint256",
      "name": "chainId",
      "type": "uint256"
    },
    {
      "internalType": "uint256",
      "name": "nonce",
      "type": "uint256"
    },
    {
      "components": [
        {
          "internalType": "uint8",
          "name": "protocolId",
          "type": "uint8"
        },
        {
          "internalType": "uint256",
          "name": "feeInWei",
          "type": "uint256"
        }
      ],
      "internalType": "struct IRelay.FeeConfig[]",
      "name": "newFeeConfigs",
      "type": "tuple[]"
    }
  ],
  "internalType": "struct IRelay.RelayGovernanceConfig",
  "name": "_config",
  "type": "tuple"
}

function hashRelayGovernanceConfig(config: RelayGovernanceConfig, relayAddress: string): string {
  const paramType = ParamType.from(RelayGovernanceConfigABI);
  // Must mirror Relay.governanceFeeSetup: keccak256(abi.encode(_config, address(this))).
  const abiEncoded = coder.encode([paramType, ParamType.from("address")], [config, relayAddress]);
  return ethers.keccak256(abiEncoded);
}

interface StateDataRaw {
  [key: number]: BN | boolean;
}
function stateDataName(stateDataRaw: StateDataRaw) {
  return {
    randomNumberProtocolId: stateDataRaw[0],
    firstVotingRoundStartTs: stateDataRaw[1],
    votingEpochDurationSeconds: stateDataRaw[2],
    firstRewardEpochStartVotingRoundId: stateDataRaw[3],
    rewardEpochDurationInVotingEpochs: stateDataRaw[4],
    thresholdIncreaseBIPS: stateDataRaw[5],
    randomVotingRoundId: stateDataRaw[6],
    isSecureRandom: stateDataRaw[7],
    lastInitializedRewardEpoch: stateDataRaw[8],
    noSigningPolicyRelay: stateDataRaw[9],
    messageFinalizationWindowInRewardEpochs: stateDataRaw[10],
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
  return web3.utils.soliditySha3(toHex32(randomResult.votingRoundId) + toHex32(randomResult.value).slice(2) + toHex32(randomResult.isSecure ? 1 : 0).slice(2))!;
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
    proof: merkleTree.getProof(randomNumberHash)
  }
}

function prepareDataWithRandom(messageData: IProtocolMessageMerkleRoot, randomNumber = 100) {
  const randomNumberResult: RandomResult = {
    votingRoundId: messageData.votingRoundId,
    value: toHex32(randomNumber),
    isSecure: messageData.isSecureRandom
  }
  const { leaf, merkleRoot, proof } = randomNumberWithMerkleProof(randomNumberResult)!;
  messageData.merkleRoot = merkleRoot!;
  const relayData = {
    isRandomNumberGeneratingProtocolMessage: true,
    randomNumber: randomNumberResult.value,
    merkleProof: proof!
  };
  return { randomNumberResult, relayData, randomNumberLeaf: leaf };
}



function generateForgedSignatures(
  voters: string[],
  count: number
): IECDSASignatureWithIndex[] {
  const signatures: IECDSASignatureWithIndex[] = [];
  for (let i = 0; i < count; i++) {
    // RLY-16: use a valid v (27) and low s so the canonical-signature checks pass; r = 0 is an
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

function encodeForgedSignatures(
  signatures: IECDSASignatureWithIndex[]
): string {
  let encoded = signatures.length.toString(16).padStart(4, "0");
  for (const sig of signatures) {
    encoded += sig.v.toString(16).padStart(2, "0");
    encoded += sig.r.slice(2);
    encoded += sig.s.slice(2);
    encoded += sig.index.toString(16).padStart(4, "0");
  }
  return encoded;
}
const relayGovernanceDescriptionHash = web3.utils.keccak256("RelayGovernance");

contract(`Relay.sol; ${getTestFile(__filename)}`, () => {
  // let accounts: Account[];
  let signers: SignerWithAddress[];
  const accountPrivateKeys = (config.networks.hardhat.accounts as HardhatNetworkAccountConfig[]).map(x => x.privateKey);
  let relay: RelayInstance;
  // RLY-23: policy hashes and signed message digests are chain-bound; set in before().
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



  const firstVotingRoundInRewardEpoch = (rewardEpochId: number) => firstRewardEpochVotingRoundId + rewardEpochDurationInVotingEpochs * rewardEpochId;

  const prepareFullData = async (signingPolicyData: ISigningPolicy, newSigningPolicyData: ISigningPolicy) => {
    const localHash = SigningPolicy.hash(newSigningPolicyData, chainId);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 2 + 1
    );

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      newSigningPolicy: newSigningPolicyData
    };
    return RelayMessage.encode(relayMessage);
  }

  before(async () => {
    // accounts = loadAccounts(web3);
    chainId = await web3.eth.getChainId();
    signers = (await ethers.getSigners()) as unknown as SignerWithAddress[];
    signingPolicyData = defaultTestSigningPolicy(
      signers.map(x => x.address),
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
      feeConfigs: []
    }

    relay = await Relay.new(
      relayInitialConfig,
      constants.ZERO_ADDRESS,
      constants.ZERO_ADDRESS
    );
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
    expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(signingPolicyData.startVotingRoundId.toString());
  });

  it("Should relay a message for random number generating protocol", async () => {
    const { randomNumberResult, relayData } = prepareDataWithRandom(messageData, 100);
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData, chainId);
    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      N / 2 + 1
    );

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: messageData,
      ...relayData
    };

    const fullData = RelayMessage.encode(relayMessage);
    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    })
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
    expect(_randomTimestamp.toNumber()).to.equal(firstVotingRoundStartSec + votingRoundDurationSec * (messageData.votingRoundId + 1));
    expect((await relay.getVotingRoundId(_randomTimestamp)).toNumber()).to.be.equal(toBN(messageData.votingRoundId + 1));
  });

  it("Should relay a message for non random number generating protocol", async () => {
    messageData.protocolId++;
    messageData.isSecureRandom = false;
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData, chainId);
    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      N / 2 + 1
    );

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
    })
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
    expect(_randomTimestamp.toNumber()).to.equal(firstVotingRoundStartSec + votingRoundDurationSec * (messageData.votingRoundId + 1));
    expect((await relay.getVotingRoundId(_randomTimestamp)).toNumber()).to.be.equal(toBN(messageData.votingRoundId + 1));
  });

  it("Should fail to relay a message due to low weight", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;

    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      N / 2
    );

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
    ).to.be.revertedWith("Not enough weight");
  });

  it("Should fail to relay a Mode-2 message with a zero merkle root [RLY-04]", async () => {
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
    ).to.be.revertedWith("zero merkle root");
  });

  it("Should fail to relay a message due to non increasing signature indices", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      0,
      [0, 1, 2, 2, 1]
    );

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
    ).to.be.revertedWith("Index out of order");
  });

  it("Should fail to relay a message due signature indices out of range", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;

    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      0,
      [0, 1, 2, 101]
    );

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
    ).to.be.revertedWith("Index out of range");
  });

  it("Should fail to relay a message due too short data for metadata", async () => {
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + "0000",
      })
    ).to.be.revertedWith("Invalid sign policy metadata");
  });

  it("Should fail to relay a message on mismatch of signing policy length", async () => {
    const signingPolicy = SigningPolicy.encode(signingPolicyData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy.slice(0, -2),
      })
    ).to.be.revertedWith("Invalid sign policy length");
  });

  it("Should fail due to signing policy hash mismatch", async () => {
    const signingPolicy = SigningPolicy.encode(signingPolicyData).slice(2);
    const tweakedSigningPolicy = signingPolicy.slice(0, -2) + ((parseInt(signingPolicy.slice(-2), 16) + 1) % 256).toString(16).padStart(2, "0");

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + tweakedSigningPolicy + "00",
      })
    ).to.be.revertedWith("Signing policy hash mismatch");
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
    ).to.be.revertedWith("Too short message");
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
      feeConfigs: []
    }

    const relay2 = await Relay.new(
      relayInitialConfig,
      constants.ZERO_ADDRESS,
      constants.ZERO_ADDRESS
    );

    const fullMessage = ProtocolMessageMerkleRoot.encode(messageData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay2.address,
        data: selector + signingPolicy.slice(2) + fullMessage
      })
    ).to.be.revertedWith("Delayed sign policy");

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
        data: selector + signingPolicy + fullMessage
      })
    ).to.be.revertedWith("Invalid voting round id");

    newMessageData.votingRoundId = votingRoundId - rewardEpochDurationInVotingEpochs; // shift to one epoch after next reward epoch
    fullMessage = ProtocolMessageMerkleRoot.encode(newMessageData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage
      })
    ).to.be.revertedWith("Wrong sign policy reward epoch");


    newMessageData.votingRoundId = votingRoundId + 2 * rewardEpochDurationInVotingEpochs; // shift to one epoch after next reward epoch
    fullMessage = ProtocolMessageMerkleRoot.encode(newMessageData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage + "0000"
      })
    ).to.be.revertedWith("Not enough weight");

    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs; // shift to next reward epoch
    fullMessage = ProtocolMessageMerkleRoot.encode(newMessageData).slice(2);

    // should be able to use previous reward epoch signing policy, but since no signatures count is provided, should fail
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage
      })
    ).to.be.revertedWith("No signature count");

    // should be able to use previous reward epoch signing policy, but since 0 are provided, it should fail
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage + "0000"
      })
    ).to.be.revertedWith("Not enough weight");
  });

  it("Should relay a message with old signing policy and 20% signatures more", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs; // shift to next reward epoch
    const { relayData } = prepareDataWithRandom(newMessageData, 100);
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatureObjects = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      Math.round(N * 0.6) + 1
    );

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures: signatureObjects,
      protocolMessageMerkleRoot: newMessageData,
      ...relayData
    };
    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    })
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
    newMessageData.votingRoundId = firstVotingRoundInRewardEpoch(signingPolicyData.rewardEpochId + 1) + 5;//votingRoundId + rewardEpochDurationInVotingEpochs + 1; // shift to next reward epoch
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      Math.round(N * 0.6)
    );

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
    ).to.be.revertedWith("Not enough weight");
  });

  it("Should relay a new signing policy", async () => {
    newSigningPolicyDataRelayed = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyDataRelayed.rewardEpochId + 1;
    newSigningPolicyDataRelayed.rewardEpochId = newRewardEpoch;
    newSigningPolicyDataRelayed.voters = newSigningPolicyDataRelayed.voters.slice(0, 50);
    newSigningPolicyDataRelayed.weights = newSigningPolicyDataRelayed.weights.slice(0, 50);
    newSigningPolicyDataRelayed.threshold = Math.round(newSigningPolicyDataRelayed.threshold / 2);
    newSigningPolicyDataRelayed.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch) + 10;  // create a delay

    const localHash = SigningPolicy.hash(newSigningPolicyDataRelayed, chainId);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 2 + 1
    );

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      newSigningPolicy: newSigningPolicyDataRelayed
    };

    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    })
    await expectEvent.inTransaction(receipt.transactionHash, relay, "SigningPolicyRelayed", {
      rewardEpochId: toBN(newSigningPolicyDataRelayed.rewardEpochId),
    });
    const result = await relay.lastInitializedRewardEpochData();
    const _lastInitializedRewardEpoch = result[0];
    const _startingVotingRoundIdForLastInitializedRewardEpoch = result[1];
    expect(_lastInitializedRewardEpoch.toString()).to.equal(newRewardEpoch.toString());
    expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(newSigningPolicyDataRelayed.startVotingRoundId.toString());
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
      feeConfigs: []
    }

    const relay2 = await Relay.new(
      relayInitialConfig,
      constants.ZERO_ADDRESS,
      constants.ZERO_ADDRESS
    );

    let lastSigningPolicyData = signingPolicyData;
    for (let i = signingPolicyData.rewardEpochId + 1; i < signingPolicyData.rewardEpochId + MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS + 2; i++) {
      const newSigningPolicyDataRelayed = { ...signingPolicyData };
      const newRewardEpoch = i;
      newSigningPolicyDataRelayed.rewardEpochId = newRewardEpoch;
      newSigningPolicyDataRelayed.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);

      const localHash = SigningPolicy.hash(newSigningPolicyDataRelayed, chainId);

      const signatures = await generateSignatures(
        accountPrivateKeys,
        localHash,
        N / 2 + 1
      );

      const relayMessage = {
        signingPolicy: lastSigningPolicyData,
        signatures,
        newSigningPolicy: newSigningPolicyDataRelayed
      };

      const fullData = RelayMessage.encode(relayMessage);

      // const hashBefore = await relay.toSigningPolicyHash(newRewardEpoch, {from: signers[10].address});
      // expect(hashBefore).to.equal(ZERO_BYTES32);

      const receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay2.address,
        data: selector + fullData.slice(2),
      })
      await expectEvent.inTransaction(receipt.transactionHash, relay2, "SigningPolicyRelayed", {
        rewardEpochId: toBN(newSigningPolicyDataRelayed.rewardEpochId),
      });
      const result = await relay2.lastInitializedRewardEpochData();
      const _lastInitializedRewardEpoch = result[0];
      const _startingVotingRoundIdForLastInitializedRewardEpoch = result[1];
      expect(_lastInitializedRewardEpoch.toString()).to.equal(newRewardEpoch.toString());
      expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(newSigningPolicyDataRelayed.startVotingRoundId.toString());
      lastSigningPolicyData = newSigningPolicyDataRelayed;
    }

    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      N / 2 + 1
    );

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
    ).to.be.revertedWith("Message too old");

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

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      26
    );

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
    ).to.be.revertedWith("Already relayed");
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

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      26
    );

    const relayMessage = {
      signingPolicy: newSigningPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
      ...relayData
    };

    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    })
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
    // RLY-03 monotonicity: this votingRoundId is lower than the one relayed by a previous test, so the
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

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      Math.round(N * 0.6)
    );

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: newMessageData,
      ...relayData
    };

    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    })
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
    // RLY-03 monotonicity: this votingRoundId is lower than the one relayed by a previous test, so the
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

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      Math.round(N * 0.6)
    );

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
    ).to.be.revertedWith("Must use new sign policy");
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
    ).to.be.revertedWith("No new sign policy size");
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
    newSigningPolicy = (parseInt(newSigningPolicy.slice(0, 4), 16) + 1).toString(16).padStart(4, "0") + newSigningPolicy.slice(4);
    const fullData = signingPolicy + "00" + newSigningPolicy;

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Wrong size for new sign policy");

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

    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 4 + 1
    );

    const relayMessage = {
      signingPolicy: newSigningPolicyDataRelayed,
      signatures,
      newSigningPolicy: newSigningPolicyData
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWith("Not next reward epoch");
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

    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 4 + 1
    );

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      newSigningPolicy: newSigningPolicyData
    };

    const fullData = RelayMessage.encode(relayMessage);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      })
    ).to.be.revertedWith("Not with last intialized");
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
    const signatures = await generateSignaturesEncoded(
      accountPrivateKeys,
      localHash,
      N / 4 + 1
    );
    const newSigningPolicy = SigningPolicy.encode(newSigningPolicyData).slice(2);
    const signingPolicy = SigningPolicy.encode(newSigningPolicyDataRelayed).slice(2);
    const fullData = signingPolicy + "00" + newSigningPolicy + signatures.slice(0, -2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Not enough signatures");
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
    const signatures = await generateSignaturesEncoded(
      accountPrivateKeys,
      localHash,
      N / 4 + 1
    );
    const newSigningPolicy = SigningPolicy.encode(newSigningPolicyData).slice(2);
    const signingPolicy = SigningPolicy.encode(newSigningPolicyDataRelayed).slice(2);
    const tweakedSignatures = signatures.slice(0, -6) + ((parseInt(signatures.slice(-6, -4), 16) + 1) % 256).toString(16).padStart(2, "0") + signatures.slice(-4);
    const fullData = signingPolicy + "00" + newSigningPolicy + tweakedSignatures;
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Wrong signature");
  });
  it("Should fail to relay a message due to message already relayed", async () => {
    // "Already relayed"

    const messageHash = ProtocolMessageMerkleRoot.hash(messageData, chainId);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      N / 2 + 1
    );

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
    ).to.be.revertedWith("Already relayed");
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
        feeConfigs: []
      }

      const relay2 = await Relay.new(
        relayInitialConfig,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newSigningPolicyData.rewardEpochId);

      expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized",
        {
          rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
          startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
          voters: newSigningPolicyData.voters,
          seed: toBN(newSigningPolicyData.seed),
          threshold: toBN(newSigningPolicyData.threshold),
          weights: newSigningPolicyData.weights.map(x => toBN(x)),
          signingPolicyBytes: SigningPolicy.encode(newSigningPolicyData)
        });


      // console.dir(receipt);
      const result = await relay2.lastInitializedRewardEpochData();
      const _lastInitializedRewardEpoch = result[0];
      const _startingVotingRoundIdForLastInitializedRewardEpoch = result[1];
      expect(_lastInitializedRewardEpoch.toString()).to.equal(newSigningPolicyData.rewardEpochId.toString());
      expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(newSigningPolicyData.startVotingRoundId.toString());

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
        feeConfigs: []
      }

      const relay2 = await Relay.new(
        relayInitialConfig,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

      const newSigningPolicyData = { ...signingPolicyData };

      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "not next reward epoch");
      newSigningPolicyData.rewardEpochId += 2;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "not next reward epoch");

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
        feeConfigs: []
      }

      const relay2 = await Relay.new(
        relayInitialConfig2,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

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
        feeConfigs: []
      }

      const relay3 = await Relay.new(
        relayInitialConfig3,
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS
      );

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.voters = [];
      newSigningPolicyData.weights = [];
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "must be non-trivial");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWith("must be non-trivial");
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
        feeConfigs: []
      }

      const relay2 = await Relay.new(
        relayInitialConfig,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.weights = [];
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "size mismatch");

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
        feeConfigs: []
      }

      const relay2 = await Relay.new(
        relayInitialConfig,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData, { from: signers[1].address }), "only sign policy setter");
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
        feeConfigs: []
      }

      const relay2 = await Relay.new(
        relayInitialConfig,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

      const newSigningPolicyData = { ...signingPolicyData, rewardEpochId: signingPolicyData.rewardEpochId + 1, weights: [...signingPolicyData.weights] };
      let totalWeight = 0;
      for (let i = 0; i < newSigningPolicyData.weights.length; i++) {
        newSigningPolicyData.weights[i] = Math.floor(newSigningPolicyData.weights[i] / 3);
        totalWeight += newSigningPolicyData.weights[i];
      }
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "too big threshold");
      const dif = newSigningPolicyData.threshold - totalWeight;
      newSigningPolicyData.weights[0] += dif;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "too big threshold");
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
        feeConfigs: []
      }

      const relay2 = await Relay.new(
        relayInitialConfig,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

      const newSigningPolicyData = { ...signingPolicyData };
      const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
      newSigningPolicyData.rewardEpochId = newRewardEpoch;
      newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
      newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
      newSigningPolicyData.threshold = Math.round(newSigningPolicyData.threshold / 2);
      newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch) + 10;  // create a delay
      const localHash = SigningPolicy.hash(newSigningPolicyData, chainId);

      const signatures = await generateSignatures(
        accountPrivateKeys,
        localHash,
        N / 2 + 1
      );

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
      ).to.be.revertedWith("Sign policy relay disabled");
    });

    it("Should fail directly setup voters with wrong number of voters", async () => {
      const newSigningPolicyData = defaultTestSigningPolicy(
        signers.map(x => x.address),
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
        feeConfigs: []
      }

      const relay2 = await Relay.new(
        relayInitialConfig2,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

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
        feeConfigs: []
      }

      const relay3 = await Relay.new(
        relayInitialConfig3,
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS
      );

      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "too many voters");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWith("too many voters");

      newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 300);
      newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 300);
      expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized",
        {
          rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
          startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
          voters: newSigningPolicyData.voters,
          seed: toBN(newSigningPolicyData.seed),
          threshold: toBN(newSigningPolicyData.threshold),
          weights: newSigningPolicyData.weights.map(x => toBN(x)),
          signingPolicyBytes: SigningPolicy.encode(newSigningPolicyData)
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
        feeConfigs: []
      }

      const relay2 = await Relay.new(
        relayInitialConfig2,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

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
        feeConfigs: []
      }

      const relay3 = await Relay.new(
        relayInitialConfig3,
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS
      );

      newSigningPolicyData.weights[0] = 2 ** 16 - 1;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "total weight too big");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWith("total weight too big");

      newSigningPolicyData.weights[0] = newSigningPolicyData.weights[1] + 1;
      newSigningPolicyData.threshold = Math.floor(totalWeight / 2);
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "too small threshold");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWith("too small threshold");

      newSigningPolicyData.weights[0] = newSigningPolicyData.weights[1];
      newSigningPolicyData.threshold = Math.floor(totalWeight / 2) - 1;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "too small threshold");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWith("too small threshold");


      expect(totalWeight).to.equal(50000);  // further tests are designed assuming 50000!
      newSigningPolicyData.threshold = Math.floor(totalWeight / 2);
      expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized",
        {
          rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
          startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
          voters: newSigningPolicyData.voters,
          seed: toBN(newSigningPolicyData.seed),
          threshold: toBN(newSigningPolicyData.threshold),
          weights: newSigningPolicyData.weights.map(x => toBN(x)),
          signingPolicyBytes: SigningPolicy.encode(newSigningPolicyData)
        });

      let receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay3.address,
        data: selector + (await prepareFullData(signingPolicyData, newSigningPolicyData)).slice(2),
      })

      await expectEvent.inTransaction(receipt.transactionHash, relay3, "SigningPolicyRelayed", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
      });

      const lastRelayedSigningPolicy = { ...newSigningPolicyData };

      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.threshold = Math.floor(totalWeight * 0.66) + 1;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "too big threshold");
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay3.address,
          data: selector + (await prepareFullData(lastRelayedSigningPolicy, newSigningPolicyData)).slice(2),
        })
      ).to.be.revertedWith("too big threshold");


      newSigningPolicyData.threshold = Math.floor(totalWeight * 0.66);
      expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized",
        {
          rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
          startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
          voters: newSigningPolicyData.voters,
          seed: toBN(newSigningPolicyData.seed),
          threshold: toBN(newSigningPolicyData.threshold),
          weights: newSigningPolicyData.weights.map(x => toBN(x)),
          signingPolicyBytes: SigningPolicy.encode(newSigningPolicyData)
        });

      receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay3.address,
        data: selector + (await prepareFullData(lastRelayedSigningPolicy, newSigningPolicyData)).slice(2),
      })

      await expectEvent.inTransaction(receipt.transactionHash, relay3, "SigningPolicyRelayed", {
        rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
      });

    });

  });

  describe("Verification", () => {
    it("Should verification work", async () => {
      const signingPolicyData = defaultTestSigningPolicy(
        signers.map(x => x.address),
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
        feeConfigs: [{
          protocolId: 17,
          feeInWei: "1000"
        }]
      }

      const relay = await Relay.new(
        relayInitialConfig,
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS
      );

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
      let signatures = await generateSignatures(
        accountPrivateKeys,
        messageHash,
        N / 2 + 1
      );

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
      })
      expect(verifyWithMerkleProof(specificHash, proof, tree.root!)).to.be.true;
      const oldBalance = Number(await web3.eth.getBalance(BURN_ADDRESS));
      await relay.verify(
        newMessageData.protocolId,
        newMessageData.votingRoundId,
        specificHash,
        proof
      );

      newMessageData.protocolId = 17;

      messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
      signatures = await generateSignatures(
        accountPrivateKeys,
        messageHash,
        N / 2 + 1
      );

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
      })

      await expectRevert(relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof), "too low fee");
      await expectRevert(relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof, { value: "999" }), "too low fee");
      await relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof, { value: "1000" });
      const newBalance = Number(await web3.eth.getBalance(BURN_ADDRESS));
      expect(newBalance - oldBalance).to.equal(1000);

      // RLY-21: overpayment is refunded; feeCollection receives only the fee (1000), not the full 2000.
      const beforeOverpay = Number(await web3.eth.getBalance(BURN_ADDRESS));
      await relay.verify(newMessageData.protocolId, newMessageData.votingRoundId, specificHash, proof, { value: "2000" });
      const afterOverpay = Number(await web3.eth.getBalance(BURN_ADDRESS));
      expect(afterOverpay - beforeOverpay).to.equal(1000);
    });

    it("Should reject verification against an unfinalized (zero) root [RLY-01]", async () => {
      const signingPolicyData = defaultTestSigningPolicy(signers.map(x => x.address), N, singleWeight);
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
        feeConfigs: []
      };
      const relay = await Relay.new(relayInitialConfig, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
      // Nothing relayed for protocol 16 / round 12345 -> stored root is zero. A zero leaf with an
      // empty proof would previously have returned true; it must now revert.
      await expectRevert(
        relay.verify(randomNumberProtocolId + 1, 12345, constants.ZERO_BYTES32, []),
        "not finalized"
      );
    });
  });

  describe("Constructor validation [RLY-10/RLY-11]", () => {
    function baseConfig(): RelayInitialConfig {
      const sp = defaultTestSigningPolicy(signers.map(x => x.address), N, singleWeight);
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
        feeConfigs: []
      };
    }

    it("Should deploy with a valid config (sanity)", async () => {
      await Relay.new(baseConfig(), constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
    });

    it("RLY-11: rejects zero rewardEpochDurationInVotingEpochs", async () => {
      const cfg = baseConfig();
      cfg.rewardEpochDurationInVotingEpochs = 0;
      await expectRevert(Relay.new(cfg, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS), "reward epoch duration zero");
    });

    it("RLY-11: rejects zero votingEpochDurationSeconds", async () => {
      const cfg = baseConfig();
      cfg.votingEpochDurationSeconds = 0;
      await expectRevert(Relay.new(cfg, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS), "voting epoch duration zero");
    });

    it("RLY-10: rejects zero feeCollectionAddress in relay mode", async () => {
      const cfg = baseConfig();
      cfg.feeCollectionAddress = constants.ZERO_ADDRESS;
      await expectRevert(Relay.new(cfg, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS), "fee collection address zero");
    });

    it("RLY-10: allows zero feeCollectionAddress in setter mode", async () => {
      const cfg = baseConfig();
      cfg.feeCollectionAddress = constants.ZERO_ADDRESS;
      await Relay.new(cfg, signers[0].address, constants.ZERO_ADDRESS); // signingPolicySetter != 0
    });
  });

  describe("Custom hash signing", () => {
    it("Should verification work", async () => {
      const signingPolicyData = defaultTestSigningPolicy(
        signers.map(x => x.address),
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
        feeConfigs: []
      }

      const relay = await Relay.new(
        relayInitialConfig,
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS
      );

      const specificHash = web3.utils.keccak256("Something");

      const newMessageData = { ...messageData };
      newMessageData.merkleRoot = specificHash;
      newMessageData.votingRoundId = 0;
      newMessageData.isSecureRandom = false;
      newMessageData.protocolId = 1;
      const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
      const signatures = await generateSignatures(
        accountPrivateKeys,
        messageHash,
        N / 2 + 1
      );

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
      })
      expect(result.slice(0, 66)).to.equal(newMessageData.merkleRoot);
      expect(parseInt(result.slice(66), 16)).to.equal(rewardEpochId);
      newMessageData.votingRoundId = 1;
      fullData = RelayMessage.encode(relayMessage);
      await expectRevert(web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      }), "Wrong message format");
      newMessageData.votingRoundId = 0;
      newMessageData.isSecureRandom = true;
      fullData = RelayMessage.encode(relayMessage);
      await expectRevert(web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      }), "Wrong message format2");
    });
  });

  describe("Governance fee changing", () => {
    it("Should fee be changed through signer governance", async () => {
      const signingPolicyData = defaultTestSigningPolicy(
        signers.map(x => x.address),
        N,
        singleWeight
      );
      signingPolicyData.rewardEpochId = rewardEpochId;
      signingPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
      const signingPolicy = SigningPolicy.encode(signingPolicyData);
      const localHash = SigningPolicy.hashEncoded(signingPolicy, chainId);

      async function relayNewSigningPolicy(newRewardEpochId: number, relayAddress: string) {
        const prevSigningPolicyData = { ...signingPolicyData };
        prevSigningPolicyData.rewardEpochId = newRewardEpochId - 1;
        const newSigningPolicyDataRelayed = { ...signingPolicyData };
        newSigningPolicyDataRelayed.rewardEpochId = newRewardEpochId;
        const localHash = SigningPolicy.hash(newSigningPolicyDataRelayed, chainId);
        const signatures = await generateSignatures(
          accountPrivateKeys,
          localHash,
          N / 2 + 1
        );
        const relayMessage = {
          signingPolicy: prevSigningPolicyData,
          signatures,
          newSigningPolicy: newSigningPolicyDataRelayed
        };
        const fullData = RelayMessage.encode(relayMessage);

        return await web3.eth.sendTransaction({
          from: signers[0].address,
          to: relayAddress,
          data: selector + fullData.slice(2),
        })
      }

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
        feeConfigs: []
      }

      const relay = await Relay.new(
        relayInitialConfig,
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS
      );

      // chainId: the file-level value (set in before()) is used both for the RLY-23 digest
      // binding above and for the RelayGovernanceConfig.chainId field below.

      const NEW_FEE = "1000";
      const newRelayGovernanceConfig: RelayGovernanceConfig = {
        descriptionHash: relayGovernanceDescriptionHash,
        chainId,
        nonce: 1,
        newFeeConfigs: [
          {
            protocolId: 2,
            feeInWei: NEW_FEE
          }
        ]
      }

      async function prepareRelayMessage(config: RelayGovernanceConfig, numSignatures = N / 2 + 1, protocolId = 1, votingRoundId = 0, newRewardEpochId?: number) {
        const newMessageData = { ...messageData };
        newMessageData.merkleRoot = hashRelayGovernanceConfig(config, relay.address);
        newMessageData.votingRoundId = votingRoundId;
        newMessageData.isSecureRandom = false;
        newMessageData.protocolId = protocolId;
        const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
        const signatures = await generateSignatures(
          accountPrivateKeys,
          messageHash,
          numSignatures
        );

        const tmpSigningPolicyData = { ...signingPolicyData };
        if (newRewardEpochId) {
          tmpSigningPolicyData.rewardEpochId = rewardEpochId;
        }
        const relayMessage = {
          signingPolicy: tmpSigningPolicyData,
          signatures,
          protocolMessageMerkleRoot: newMessageData,
        };
        const fullData = RelayMessage.encode(relayMessage);
        return selector + fullData.slice(2)
      }
      for (const feeChange of newRelayGovernanceConfig.newFeeConfigs) {
        expect((await relay.protocolFeeInWei(feeChange.protocolId)).toString()).to.equal("0");
        const setupTx = await relay.governanceFeeSetup(await prepareRelayMessage(newRelayGovernanceConfig), newRelayGovernanceConfig);
        expectEvent(setupTx, "RelayGovernanceFeeConfigured", { feeInWei: NEW_FEE, nonce: "1" });
        expect((await relay.protocolFeeInWei(feeChange.protocolId)).toString()).to.equal(NEW_FEE);
      }
      expect((await relay.governanceFeeNonce()).toString()).to.equal("1");

      // RLY-02: replaying an accepted governance message is rejected (nonce did not increase).
      await expectRevert(
        relay.governanceFeeSetup(await prepareRelayMessage(newRelayGovernanceConfig), newRelayGovernanceConfig),
        "nonce too low"
      );

      // RLY-02: a strictly-greater (non-sequential) nonce is accepted.
      const bumpConfig: RelayGovernanceConfig = {
        descriptionHash: relayGovernanceDescriptionHash,
        chainId,
        nonce: 5,
        newFeeConfigs: [{ protocolId: 2, feeInWei: "2000" }]
      };
      await relay.governanceFeeSetup(await prepareRelayMessage(bumpConfig), bumpConfig);
      expect((await relay.protocolFeeInWei(2)).toString()).to.equal("2000");
      expect((await relay.governanceFeeNonce()).toString()).to.equal("5");

      // RLY-02: a nonce <= the current one (3 < 5) is rejected, even though > the original nonce.
      const staleConfig: RelayGovernanceConfig = {
        descriptionHash: relayGovernanceDescriptionHash,
        chainId,
        nonce: 3,
        newFeeConfigs: [{ protocolId: 2, feeInWei: "3000" }]
      };
      await expectRevert(
        relay.governanceFeeSetup(await prepareRelayMessage(staleConfig), staleConfig),
        "nonce too low"
      );
      expect((await relay.protocolFeeInWei(2)).toString()).to.equal("2000");

      newRelayGovernanceConfig.descriptionHash = web3.utils.keccak256("Something else");
      await expectRevert(relay.governanceFeeSetup(await prepareRelayMessage(newRelayGovernanceConfig), newRelayGovernanceConfig), "wrong description hash");
      newRelayGovernanceConfig.descriptionHash = relayGovernanceDescriptionHash;
      newRelayGovernanceConfig.chainId = newRelayGovernanceConfig.chainId + 1;
      await expectRevert(relay.governanceFeeSetup(await prepareRelayMessage(newRelayGovernanceConfig), newRelayGovernanceConfig), "wrong chain id");
      newRelayGovernanceConfig.chainId = newRelayGovernanceConfig.chainId - 1;
      await expectRevert(relay.governanceFeeSetup(await prepareRelayMessage(newRelayGovernanceConfig, Math.round(N / 4)), newRelayGovernanceConfig), "Verification failed");
      await expectRevert(relay.governanceFeeSetup(await prepareRelayMessage(newRelayGovernanceConfig, N / 2 + 1, 5, signingPolicyData.startVotingRoundId), newRelayGovernanceConfig), "Wrong verification data");

      const tmpRelayGovernanceConfig = { ...newRelayGovernanceConfig };
      tmpRelayGovernanceConfig.newFeeConfigs = tmpRelayGovernanceConfig.newFeeConfigs.map(x => ({ ...x }));
      tmpRelayGovernanceConfig.newFeeConfigs[0].feeInWei = NEW_FEE + "1";
      await expectRevert(relay.governanceFeeSetup(await prepareRelayMessage(newRelayGovernanceConfig), tmpRelayGovernanceConfig), "Invalid config hash");

      await relayNewSigningPolicy(signingPolicyData.rewardEpochId + 1, relay.address);
      await relayNewSigningPolicy(signingPolicyData.rewardEpochId + 2, relay.address);
      await expectRevert(relay.governanceFeeSetup(await prepareRelayMessage(newRelayGovernanceConfig), newRelayGovernanceConfig), "too old signing policy");
    });
  });

  describe("Random number test", () => {
    it("Should historical random number work", async () => {
      const signingPolicyData = defaultTestSigningPolicy(
        signers.map(x => x.address),
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
        feeConfigs: []
      }

      const relay = await Relay.new(
        relayInitialConfig,
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS
      );

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
          protocolId: randomNumberProtocolId
        };
        const { randomNumberResult, relayData } = prepareDataWithRandom(newMessageData, 100 + i);
        hashes.set(startVotingRoundId + i, newMessageData.merkleRoot);
        randomNumbers.set(startVotingRoundId + i, randomNumberResult.value);
        const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
        const signatures = await generateSignatures(
          accountPrivateKeys,
          messageHash,
          N / 2 + 1
        );

        const relayMessage = {
          signingPolicy: signingPolicyData,
          signatures,
          protocolMessageMerkleRoot: newMessageData,
          ...relayData
        };

        const fullData = RelayMessage.encode(relayMessage);
        await web3.eth.sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: selector + fullData.slice(2),
        })

        const getRandomNumberRaw = await relay.getRandomNumber();
        let { _randomNumber, _isSecureRandom, _randomTimestamp } = getRandomNumberName(getRandomNumberRaw);
        expect(_isSecureRandom).to.equal(random);
        expect(_randomNumber.toString()).to.equal(BigInt(randomNumberResult.value).toString());
        expect(_randomTimestamp.toNumber()).to.equal(firstVotingRoundStartSec + votingRoundDurationSec * (newMessageData.votingRoundId + 1));
        expect((await relay.getVotingRoundId(_randomTimestamp)).toNumber()).to.be.equal(toBN(newMessageData.votingRoundId + 1));

        const getRandomNumberHistoricalRaw = await relay.getRandomNumberHistorical(newMessageData.votingRoundId);
        ({ _randomNumber, _isSecureRandom, _randomTimestamp } = getRandomNumberName(getRandomNumberHistoricalRaw));
        expect(_randomNumber.toString()).to.equal(BigInt(randomNumberResult.value).toString());
        expect(_randomTimestamp.toNumber()).to.equal(firstVotingRoundStartSec + votingRoundDurationSec * (newMessageData.votingRoundId + 1));
        expect(_isSecureRandom).to.equal(random);
      }

      for (let i = 0; i < MAX_NUM; i++) {
        const votingRoundId = startVotingRoundId + i;
        if (hashes.get(votingRoundId)) {
          const getRandomNumberHistoricalRaw = await relay.getRandomNumberHistorical(votingRoundId);
          const { _randomNumber, _isSecureRandom, _randomTimestamp } = getRandomNumberName(getRandomNumberHistoricalRaw);
          expect(_randomNumber.toString()).to.equal(BigInt(randomNumbers.get(votingRoundId)!).toString());
          expect(_randomTimestamp.toNumber()).to.equal(firstVotingRoundStartSec + votingRoundDurationSec * (votingRoundId + 1));
          expect(_isSecureRandom).to.equal(isSecure.get(votingRoundId));
        } else {
          await expectRevert(relay.getRandomNumberHistorical(votingRoundId), "no random number");
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
        feeConfigs: []
      }

      const relay1 = await Relay.new(
        relayInitialConfig1,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

      await expectRevert(
        Relay.new(
          relayInitialConfig1,
          constants.ZERO_ADDRESS,
          relay1.address
        ), "old relay incompatible"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            thresholdIncreaseBIPS: 9000
          },
          signers[1].address,
          relay1.address
        ), "threshold increase too small"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            startingVotingRoundIdForInitialRewardEpochId: 0
          },
          signers[1].address,
          relay1.address
        ), "invalid initial starting voting round id"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            firstRewardEpochStartVotingRoundId: 1000000000
          },
          signers[1].address,
          relay1.address
        ), "invalid initial starting voting round id"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            initialRewardEpochId: 100000
          },
          signers[1].address,
          relay1.address
        ), "invalid initial starting voting round id"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            rewardEpochDurationInVotingEpochs: 10000
          },
          signers[1].address,
          relay1.address
        ), "invalid initial starting voting round id"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            startingVotingRoundIdForInitialRewardEpochId: 0
          },
          signers[1].address,
          relay1.address
        ), "invalid initial starting voting round id"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            randomNumberProtocolId: 0
          },
          signers[1].address,
          relay1.address
        ), "random number protocol id must be > 1"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            feeConfigs: [{
              protocolId: 17,
              feeInWei: "1000"
            }]
          },
          signers[1].address,
          relay1.address
        ), "fee cannot be set"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            feeConfigs: [{
              protocolId: 1,
              feeInWei: "1000"
            }]
          },
          constants.ZERO_ADDRESS,
          relay1.address
        ), "invalid protocol id"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            firstVotingRoundStartTs: relayInitialConfig1.firstVotingRoundStartTs + 1
          },
          signers[1].address,
          relay1.address
        ), "wrong start ts"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            rewardEpochDurationInVotingEpochs: relayInitialConfig1.rewardEpochDurationInVotingEpochs - 1
          },
          signers[1].address,
          relay1.address
        ), "wrong reward epoch duration"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            firstRewardEpochStartVotingRoundId: relayInitialConfig1.firstRewardEpochStartVotingRoundId - 1
          },
          signers[1].address,
          relay1.address
        ), "wrong first reward epoch start"
      )

      await expectRevert(
        Relay.new(
          {
            ...relayInitialConfig1,
            votingEpochDurationSeconds: relayInitialConfig1.votingEpochDurationSeconds - 1
          },
          signers[1].address,
          relay1.address
        ), "wrong voting epoch duration"
      )

    })
    it("Should verify on old and new relay contract", async () => {
      const switchOffset = 2;
      const messageDataBase = {
        ...messageData,
        votingRoundId: messageData.votingRoundId + rewardEpochDurationInVotingEpochs // shift to next reward epoch
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
        feeConfigs: []
      }

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
        feeConfigs: []
      }

      const relayOldFlare = await Relay.new(
        relayInitialConfigOldFlare,
        signers[0].address,
        constants.ZERO_ADDRESS
      );

      const relayInitialConfigOldRelay: RelayInitialConfig = {
        ...relayInitialConfigOldFlare,
      }

      const relayOldRelay = await Relay.new(
        relayInitialConfigOldRelay,
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS
      );

      const relayNewFlare = await Relay.new(
        relayInitialConfigNewFlare,
        signers[0].address,
        relayOldFlare.address
      );

      const relayInitialConfigNewRelay: RelayInitialConfig = {
        ...relayInitialConfigNewFlare,
      }

      const relayNewRelay = await Relay.new(
        relayInitialConfigNewRelay,
        constants.ZERO_ADDRESS,
        relayOldRelay.address
      );

      // Relay two merkle roots for random generating protocol and another protocol at
      // firstVotingRoundInRewardEpoch and firstVotingRoundInRewardEpoch + 1
      // Relay this on both contracts in Flare and Relay mode.
      // The new relay contracts are set to start with firstRewardEpochVotingRoundId + 2
      // Relay merkle roots also for firstVotingRoundInRewardEpoch + 2 and +3.

      const isFlare = new Map<RelayInstance, boolean>();
      isFlare.set(relayOldFlare, true);
      isFlare.set(relayOldRelay, false);
      isFlare.set(relayNewFlare, true);
      isFlare.set(relayNewRelay, false);
      const isNew = new Map<RelayInstance, boolean>();
      isNew.set(relayOldFlare, false);
      isNew.set(relayOldRelay, false);
      isNew.set(relayNewFlare, true);
      isNew.set(relayNewRelay, true);

      const allRelays = [
        relayOldFlare,
        relayOldRelay,
        relayNewFlare,
        relayNewRelay
      ];

      const votingRoundIdAndProtocolIdToMerkleRoot = new Map<string, string>();
      const votingRoundIdAndProtocolIdExampleLeaf = new Map<string, string>();
      const votingRoundIdAndProtocolIdExampleProof = new Map<string, string[]>();

      // set new signing policy on old flare contract
      await relayOldFlare.setSigningPolicy(newSigningPolicyData);

      const signaturesSP = await generateSignatures(
        accountPrivateKeys,
        newSigningPolicyHash,
        N / 2 + 1
      );

      const relayMessageSP = {
        signingPolicy: signingPolicyData,
        signatures: signaturesSP,
        newSigningPolicy: newSigningPolicyData
      };

      const fullDataSP = RelayMessage.encode(relayMessageSP);

      const receiptSP = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relayOldRelay.address,
        data: selector + fullDataSP.slice(2),
      })
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
            isSecureRandom: isRandomNumberProtocol
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
          votingRoundIdAndProtocolIdToMerkleRoot.set(`${votingRoundIdBase + votingRoundOffset}-${protocolId}`, newMessageData.merkleRoot);
          votingRoundIdAndProtocolIdExampleLeaf.set(`${votingRoundIdBase + votingRoundOffset}-${protocolId}`, leaf);
          votingRoundIdAndProtocolIdExampleProof.set(`${votingRoundIdBase + votingRoundOffset}-${protocolId}`, proof);
          const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData, chainId);
          const signatures = await generateSignatures(
            accountPrivateKeys,
            messageHash,
            N / 2 + 1
          );


          const relayMessage = {
            signingPolicy: newSigningPolicyData,
            signatures,
            protocolMessageMerkleRoot: newMessageData,
            ...relayData
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
            })
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
                expect(await relayContract.verify.call(
                  protocolId, votingRoundId,
                  votingRoundIdAndProtocolIdExampleLeaf.get(`${votingRoundId}-${protocolId}`)!,
                  votingRoundIdAndProtocolIdExampleProof.get(`${votingRoundId}-${protocolId}`)!,
                  { value })
                ).to.equal(true);
              } else {
                // old relay contract, old relaying - should match
                const merkleRootFromContract = await relayContract.merkleRoots(protocolId, votingRoundId);
                expect(merkleRootFromContract).to.equal(merkleRoot);
                const isFinalized = await relayContract.isFinalized(protocolId, votingRoundId);
                expect(isFinalized).to.equal(true);
                expect(await relayContract.verify.call(
                  protocolId, votingRoundId,
                  votingRoundIdAndProtocolIdExampleLeaf.get(`${votingRoundId}-${protocolId}`)!,
                  votingRoundIdAndProtocolIdExampleProof.get(`${votingRoundId}-${protocolId}`)!,
                  { value })
                ).to.equal(true);
              }
            } else {
              if (isNew.get(relayContract)!) {
                // new relay contract, new relaying - should match
                const merkleRootFromContract = await relayContract.merkleRoots(protocolId, votingRoundId);
                expect(merkleRootFromContract).to.equal(merkleRoot);
                const isFinalized = await relayContract.isFinalized(protocolId, votingRoundId);
                expect(isFinalized).to.equal(true);
                expect(await relayContract.verify.call(
                  protocolId, votingRoundId,
                  votingRoundIdAndProtocolIdExampleLeaf.get(`${votingRoundId}-${protocolId}`)!,
                  votingRoundIdAndProtocolIdExampleProof.get(`${votingRoundId}-${protocolId}`)!,
                  { value })
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

    })
  })

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
      const signatures = await generateSignatures(
        accountPrivateKeys,
        messageHash,
        N / 2 + 1
      );

      const relayMessage = {
        signingPolicy: signingPolicyData,
        signatures,
        protocolMessageMerkleRoot: messageData,
        ...relayData
      };

      const fullData = RelayMessage.encode(relayMessage);

      const receipt = await web3.eth.sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData.slice(2),
      });

      await expectEvent.inTransaction(
        receipt.transactionHash,
        relay,
        "ProtocolMessageRelayed",
        {
          protocolId: toBN(messageData.protocolId),
          votingRoundId: toBN(messageData.votingRoundId),
          isSecureRandom: messageData.isSecureRandom,
          merkleRoot: messageData.merkleRoot,
        }
      );

      expect(
        await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)
      ).to.equal(true);
    });

    it("Check for return data size", async () => {
      // const attackVotingRoundId = votingRoundId + 1;
      const attackVotingRoundId = testVotingRoundId + 1
      const attackMerkleRoot =
        "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef";

      const messageData: IProtocolMessageMerkleRoot = {
        protocolId: randomNumberProtocolId,
        votingRoundId: attackVotingRoundId,
        isSecureRandom: true,
        merkleRoot: attackMerkleRoot,
      };

      expect(
        await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)
      ).to.equal(false);

      const signingPolicyEncoded = SigningPolicy.encode(signingPolicyData).slice(2);
      const messageEncoded = ProtocolMessageMerkleRoot.encode(messageData).slice(2);

      const requiredSigners = N / 2 + 1;
      const forgedSigs = generateForgedSignatures(
        signingPolicyData.voters,
        requiredSigners
      );

      const signaturesEncoded = encodeForgedSignatures(forgedSigs);

      const fullCalldata =
        selector + signingPolicyEncoded + messageEncoded + signaturesEncoded;

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
      ).to.be.revertedWith("ecrecover returned bad data");

      expect(
        await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)
      ).to.equal(false);
    });

    it("Check for return data size, differnet protocol id", async () => {
      const attackProtocolId = randomNumberProtocolId + 1;
      // const attackVotingRoundId = votingRoundId + 2;
      const attackVotingRoundId = testVotingRoundId + 2;
      const attackMerkleRoot =
        "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

      const messageData: IProtocolMessageMerkleRoot = {
        protocolId: attackProtocolId,
        votingRoundId: attackVotingRoundId,
        isSecureRandom: false,
        merkleRoot: attackMerkleRoot,
      };

      expect(
        await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)
      ).to.equal(false);

      const signingPolicyEncoded = SigningPolicy.encode(signingPolicyData).slice(2);
      const messageEncoded = ProtocolMessageMerkleRoot.encode(messageData).slice(2);

      const requiredSigners = N / 2 + 1;
      const forgedSigs = generateForgedSignatures(
        signingPolicyData.voters,
        requiredSigners
      );
      const signaturesEncoded = encodeForgedSignatures(forgedSigs);

      const fullCalldata =
        selector + signingPolicyEncoded + messageEncoded + signaturesEncoded;

      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: fullCalldata,
        })
      ).to.be.revertedWith("ecrecover returned bad data");

      expect(
        await relay.isFinalized(messageData.protocolId, messageData.votingRoundId)
      ).to.equal(false);
    });

    it("Sanity check: v=0 forged sig is rejected by the canonical-signature check [RLY-16]", async () => {
      // const attackVotingRoundId = votingRoundId + 4;
      const attackVotingRoundId = testVotingRoundId + 4;
      const messageData: IProtocolMessageMerkleRoot = {
        protocolId: randomNumberProtocolId,
        votingRoundId: attackVotingRoundId,
        isSecureRandom: true,
        merkleRoot:
          "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
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
      const fullCalldata =
        selector + signingPolicyEncoded + messageEncoded + signaturesEncoded;

      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: fullCalldata,
        })
      ).to.be.revertedWith("Bad v");
    });

    it("High-s forged signature is rejected [RLY-16]", async () => {
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
      const fullCalldata =
        selector + signingPolicyEncoded + messageEncoded + signaturesEncoded;
      await expect(
        signers[0].sendTransaction({
          from: signers[0].address,
          to: relay.address,
          data: fullCalldata,
        })
      ).to.be.revertedWith("Bad s");
    });
  });
});
