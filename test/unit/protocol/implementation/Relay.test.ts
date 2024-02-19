import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { constants, expectEvent, expectRevert } from "@openzeppelin/test-helpers";
import { artifacts, config, contract, ethers } from "hardhat";
import { HardhatNetworkAccountConfig } from "hardhat/types";
import { IProtocolMessageMerkleRoot, ProtocolMessageMerkleRoot } from "../../../../scripts/libs/protocol/ProtocolMessageMerkleRoot";
import { RelayMessage } from "../../../../scripts/libs/protocol/RelayMessage";
import {
  ISigningPolicy,
  SigningPolicy
} from "../../../../scripts/libs/protocol/SigningPolicy";
import { RelayInstance } from "../../../../typechain-truffle";
import { getTestFile } from "../../../utils/constants";
import { toBN } from "../../../utils/test-helpers";
import { defaultTestSigningPolicy, generateSignatures, generateSignaturesEncoded } from "../coding/coding-helpers";

const Relay = artifacts.require("Relay");
const ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

contract(`Relay.sol; ${getTestFile(__filename)}`, async () => {
  // let accounts: Account[];
  let signers: SignerWithAddress[];
  const accountPrivateKeys = (config.networks.hardhat.accounts as HardhatNetworkAccountConfig[]).map(x => x.privateKey);
  let relay: RelayInstance;
  const selector = ethers.keccak256(ethers.toUtf8Bytes("relay()"))!.slice(0, 10);
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
  let newSigningPolicyDataRelayed: ISigningPolicy;
  

  const firstVotingRoundInRewardEpoch = (rewardEpochId: number) => firstRewardEpochVotingRoundId + rewardEpochDurationInVotingEpochs * rewardEpochId;

  before(async () => {
    // accounts = loadAccounts(web3);
    signers = (await ethers.getSigners()) as unknown as SignerWithAddress[];
    signingPolicyData = defaultTestSigningPolicy(
      signers.map(x => x.address),
      N,
      singleWeight
    );
    signingPolicyData.rewardEpochId = rewardEpochId;
    signingPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(rewardEpochId);
    const signingPolicy = SigningPolicy.encode(signingPolicyData);
    const localHash = SigningPolicy.hashEncoded(signingPolicy);
    relay = await Relay.new(
      constants.ZERO_ADDRESS,
      signingPolicyData.rewardEpochId,
      signingPolicyData.startVotingRoundId,
      localHash,
      randomNumberProtocolId,
      firstVotingRoundStartSec,
      votingRoundDurationSec,
      firstRewardEpochVotingRoundId,
      rewardEpochDurationInVotingEpochs,
      THRESHOLD_INCREASE
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
    const { _lastInitializedRewardEpoch, _startingVotingRoundIdForLastInitializedRewardEpoch } = await relay.lastInitializedRewardEpochData();
    expect(_lastInitializedRewardEpoch.toString()).to.equal(signingPolicyData.rewardEpochId.toString());
    expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(signingPolicyData.startVotingRoundId.toString());
    const obtainedSigningPolicyHash = await relay.toSigningPolicyHash(signingPolicyData.rewardEpochId);
    const localHash = SigningPolicy.hashEncoded(signingPolicy);
    expect(obtainedSigningPolicyHash).to.equal(localHash);
  });

  it("Should relay a message", async () => {
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData);
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
    await expectEvent.inTransaction(receipt!.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(messageData.protocolId),
      votingRoundId: toBN(messageData.votingRoundId),
      isSecureRandom: messageData.isSecureRandom,
      merkleRoot: merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    const confirmedMerkleRoot = await relay.getConfirmedMerkleRoot(messageData.protocolId, messageData.votingRoundId);
    expect(confirmedMerkleRoot).to.equal(merkleRoot);

    let stateData = await relay.stateData();
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(messageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(messageData.votingRoundId.toString());
    expect(stateData.isSecureRandom.toString()).to.be.equal(messageData.isSecureRandom.toString());

    expect(RelayMessage.decode(fullData)).not.to.throw;
    const decodedRelayMessage = RelayMessage.decode(fullData);

    expect(RelayMessage.equals(relayMessage, decodedRelayMessage)).to.be.true;


  });

  it("Should fail to relay a message due to low weight", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;

    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData);

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

  it("Should fail to relay a message due to non increasing signature indices", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData);

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

    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData);

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

    const relay2 = await Relay.new(
      constants.ZERO_ADDRESS,
      newSigningPolicyData.rewardEpochId,
      newSigningPolicyData.startVotingRoundId,
      SigningPolicy.hashEncoded(signingPolicy),
      randomNumberProtocolId,
      firstVotingRoundStartSec,
      votingRoundDurationSec,
      firstRewardEpochVotingRoundId,
      rewardEpochDurationInVotingEpochs,
      THRESHOLD_INCREASE);

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
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData);

    const signatureObjects = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      Math.round(N * 0.6) + 1
    );

    let relayMessage = {
      signingPolicy: signingPolicyData,
      signatures: signatureObjects,
      protocolMessageMerkleRoot: newMessageData,
    };
    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    })
    await expectEvent.inTransaction(receipt!.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(newMessageData.protocolId),
      votingRoundId: toBN(newMessageData.votingRoundId),
      isSecureRandom: newMessageData.isSecureRandom,
      merkleRoot: merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    const confirmedMerkleRoot = await relay.getConfirmedMerkleRoot(newMessageData.protocolId, newMessageData.votingRoundId);
    expect(confirmedMerkleRoot).to.equal(merkleRoot);

    let stateData = await relay.stateData();
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(newMessageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(newMessageData.votingRoundId.toString());
    expect(stateData.isSecureRandom.toString()).to.be.equal(newMessageData.isSecureRandom.toString());
  });

  it("Should fail to relay a message with old signing policy and less then 20%+ more weight", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = firstVotingRoundInRewardEpoch(signingPolicyData.rewardEpochId + 1) + 5;//votingRoundId + rewardEpochDurationInVotingEpochs + 1; // shift to next reward epoch
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData);

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

    const localHash = SigningPolicy.hash(newSigningPolicyDataRelayed);

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

    const hashBefore = await relay.toSigningPolicyHash(newRewardEpoch);
    expect(hashBefore).to.equal(ZERO_BYTES32);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    })
    await expectEvent.inTransaction(receipt!.transactionHash, relay, "SigningPolicyRelayed", {
      rewardEpochId: toBN(newSigningPolicyDataRelayed.rewardEpochId),
    });
    const hashAfter = await relay.toSigningPolicyHash(newRewardEpoch);
    expect(hashAfter).to.equal(localHash);
    const { _lastInitializedRewardEpoch, _startingVotingRoundIdForLastInitializedRewardEpoch } = await relay.lastInitializedRewardEpochData();
    expect(_lastInitializedRewardEpoch.toString()).to.equal(newRewardEpoch.toString());
    expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(newSigningPolicyDataRelayed.startVotingRoundId.toString());
    console.log("Gas used:", receipt?.gasUsed?.toString());
  });

  it("Should fail to relay an already relayed message by old signing policy with a new signing policy", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs; // shift to next reward epoch
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData);

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
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData);

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
    };

    const fullData = RelayMessage.encode(relayMessage);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    })
    await expectEvent.inTransaction(receipt!.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(newMessageData.protocolId),
      votingRoundId: toBN(newMessageData.votingRoundId),
      isSecureRandom: newMessageData.isSecureRandom,
      merkleRoot: merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    const confirmedMerkleRoot = await relay.getConfirmedMerkleRoot(newMessageData.protocolId, newMessageData.votingRoundId);
    expect(confirmedMerkleRoot).to.equal(merkleRoot);

    let stateData = await relay.stateData();
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(newMessageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(newMessageData.votingRoundId.toString());
    expect(stateData.isSecureRandom.toString()).to.be.equal(newMessageData.isSecureRandom.toString());

  });

  it("Should relay a message with old signing policy and less then 20%+ more weight after delayed reward epoch initialization", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = firstVotingRoundInRewardEpoch(signingPolicyData.rewardEpochId + 1) + 9; // new startingVotingRoundId is on +10
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData);

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

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData.slice(2),
    })
    await expectEvent.inTransaction(receipt!.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(newMessageData.protocolId),
      votingRoundId: toBN(newMessageData.votingRoundId),
      isSecureRandom: newMessageData.isSecureRandom,
      merkleRoot: merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    const confirmedMerkleRoot = await relay.getConfirmedMerkleRoot(newMessageData.protocolId, newMessageData.votingRoundId);
    expect(confirmedMerkleRoot).to.equal(merkleRoot);

    let stateData = await relay.stateData();
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(newMessageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(newMessageData.votingRoundId.toString());
    expect(stateData.isSecureRandom.toString()).to.be.equal(newMessageData.isSecureRandom.toString());
  });

  it("Should fail to relay a message with old signing policy when a new was initialized and votingRoundId is over startingVotingRoundId", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = firstVotingRoundInRewardEpoch(signingPolicyData.rewardEpochId + 1) + 10; // new startingVotingRoundId is on +10
    const messageHash = ProtocolMessageMerkleRoot.hash(newMessageData);

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
    const { _lastInitializedRewardEpoch, _startingVotingRoundIdForLastInitializedRewardEpoch } = await relay.lastInitializedRewardEpochData()
    const newRewardEpoch = parseInt(_lastInitializedRewardEpoch.toString()) + 2;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = SigningPolicy.hash(newSigningPolicyData);

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
    const { _lastInitializedRewardEpoch, _startingVotingRoundIdForLastInitializedRewardEpoch } = await relay.lastInitializedRewardEpochData()
    const newRewardEpoch = parseInt(_lastInitializedRewardEpoch.toString()) + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = SigningPolicy.hash(newSigningPolicyData);

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
    const { _lastInitializedRewardEpoch, _startingVotingRoundIdForLastInitializedRewardEpoch } = await relay.lastInitializedRewardEpochData();
    const newRewardEpoch = parseInt(_lastInitializedRewardEpoch.toString()) + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = SigningPolicy.hash(newSigningPolicyData);
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
    const { _lastInitializedRewardEpoch, _startingVotingRoundIdForLastInitializedRewardEpoch } = await relay.lastInitializedRewardEpochData();
    const newRewardEpoch = parseInt(_lastInitializedRewardEpoch.toString()) + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = SigningPolicy.hash(newSigningPolicyData);
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

    const messageHash = ProtocolMessageMerkleRoot.hash(messageData);

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

  describe("Direct signing policy setup", async () => {
    it("Should directly set the signing policy", async () => {
      const relay2 = await Relay.new(
        signers[0].address,
        signingPolicyData.rewardEpochId,
        signingPolicyData.startVotingRoundId,
        SigningPolicy.hash(signingPolicyData),
        randomNumberProtocolId,
        firstVotingRoundStartSec,
        votingRoundDurationSec,
        firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs,
        THRESHOLD_INCREASE
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
      const { _lastInitializedRewardEpoch, _startingVotingRoundIdForLastInitializedRewardEpoch } = await relay2.lastInitializedRewardEpochData();
      expect(_lastInitializedRewardEpoch.toString()).to.equal(newSigningPolicyData.rewardEpochId.toString());
      expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(newSigningPolicyData.startVotingRoundId.toString());
      const obtainedSigningPolicyHash = await relay2.toSigningPolicyHash(newSigningPolicyData.rewardEpochId);
      const localHash = SigningPolicy.hash(newSigningPolicyData);
      expect(obtainedSigningPolicyHash).to.equal(localHash);

    });

    it("Should fail to directly set the signing policy due to wrong reward epoch", async () => {
      // "not next reward epoch"
      const relay2 = await Relay.new(
        signers[0].address,
        signingPolicyData.rewardEpochId,
        signingPolicyData.startVotingRoundId,
        SigningPolicy.hash(signingPolicyData),
        randomNumberProtocolId,
        firstVotingRoundStartSec,
        votingRoundDurationSec,
        firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs,
        THRESHOLD_INCREASE
      );
      const newSigningPolicyData = { ...signingPolicyData };

      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "not next reward epoch");
      newSigningPolicyData.rewardEpochId += 2;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "not next reward epoch");

    });

    it("Should fail to directly set the signing policy due to policy being trivial", async () => {
      // "must be non-trivial"
      const relay2 = await Relay.new(
        signers[0].address,
        signingPolicyData.rewardEpochId,
        signingPolicyData.startVotingRoundId,
        SigningPolicy.hash(signingPolicyData),
        randomNumberProtocolId,
        firstVotingRoundStartSec,
        votingRoundDurationSec,
        firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs,
        THRESHOLD_INCREASE
      );
      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.voters = [];
      newSigningPolicyData.weights = [];
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "must be non-trivial");

    });

    it("Should fail due to voters and weights length mismatch", async () => {
      // "size mismatch"
      const relay2 = await Relay.new(
        signers[0].address,
        signingPolicyData.rewardEpochId,
        signingPolicyData.startVotingRoundId,
        SigningPolicy.hash(signingPolicyData),
        randomNumberProtocolId,
        firstVotingRoundStartSec,
        votingRoundDurationSec,
        firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs,
        THRESHOLD_INCREASE
      );
      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.weights = [];
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "size mismatch");

    });

    it("Should fail due to wrong setter", async () => {
      // "only sign policy setter"
      const relay2 = await Relay.new(
        signers[0].address,
        signingPolicyData.rewardEpochId,
        signingPolicyData.startVotingRoundId,
        SigningPolicy.hash(signingPolicyData),
        randomNumberProtocolId,
        firstVotingRoundStartSec,
        votingRoundDurationSec,
        firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs,
        THRESHOLD_INCREASE
      );
      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData, { from: signers[1].address }), "only sign policy setter");
    });

    it("Should fail to relay new signing policy due to policy setter being set", async () => {
      const signingPolicy = SigningPolicy.encode(signingPolicyData);
      const relay2 = await Relay.new(
        signers[0].address,
        signingPolicyData.rewardEpochId,
        signingPolicyData.startVotingRoundId,
        SigningPolicy.hashEncoded(signingPolicy),
        randomNumberProtocolId,
        firstVotingRoundStartSec,
        votingRoundDurationSec,
        firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs,
        THRESHOLD_INCREASE
      );

      const newSigningPolicyData = { ...signingPolicyData };
      const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
      newSigningPolicyData.rewardEpochId = newRewardEpoch;
      newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
      newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
      newSigningPolicyData.threshold = Math.round(newSigningPolicyData.threshold / 2);
      newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch) + 10;  // create a delay
      const localHash = SigningPolicy.hash(newSigningPolicyData);

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
  });
});
