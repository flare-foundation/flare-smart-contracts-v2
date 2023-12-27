import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { artifacts, config, contract, ethers } from "hardhat";
import { defaultTestSigningPolicy, generateSignatures } from "../coding/coding-helpers";
import { getTestFile } from "../../../utils/constants";
import { RelayInstance } from "../../../../typechain-truffle";
import {
  ProtocolMessageMerkleRoot,
  SigningPolicy,
  encodeProtocolMessageMerkleRoot,
  encodeSigningPolicy,
  signingPolicyHash,
} from "../../../../scripts/libs/protocol/protocol-coder";
import { HardhatNetworkAccountConfig } from "hardhat/types";
import { expectEvent, expectRevert } from "@openzeppelin/test-helpers";
import { toBN } from "../../../utils/test-helpers";

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
  const votingRoundId = 4111;
  const rewardEpochId = Math.floor((votingRoundId - firstRewardEpochVotingRoundId) / rewardEpochDurationInVotingEpochs);
  let signingPolicyData: SigningPolicy;
  const randomNumberProtocolId = 15;
  const THRESHOLD_INCREASE = 12000;

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
    const signingPolicy = encodeSigningPolicy(signingPolicyData);
    const localHash = signingPolicyHash(signingPolicy);
    relay = await Relay.new(
      signers[0].address,
      signingPolicyData.rewardEpochId,
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
  let messageData: ProtocolMessageMerkleRoot;

  beforeEach(async () => {
    merkleRoot = ethers.hexlify(ethers.randomBytes(32));
    messageData = {
      protocolId: randomNumberProtocolId,
      votingRoundId,
      randomQualityScore: true,
      merkleRoot,
    } as ProtocolMessageMerkleRoot;
  });

  it("Should initial signing policy be initialized", async () => {
    const signingPolicy = encodeSigningPolicy(signingPolicyData);
    const lastInitializedRewardEpoch = (await relay.lastInitializedRewardEpoch()).toString();
    expect(lastInitializedRewardEpoch).to.equal(signingPolicyData.rewardEpochId.toString());
    const obtainedSigningPolicyHash = await relay.toSigningPolicyHash(signingPolicyData.rewardEpochId);
    const localHash = signingPolicyHash(signingPolicy);
    expect(obtainedSigningPolicyHash).to.equal(localHash);
  });

  it("Should relay", async () => {

    const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);
    const messageHash = ethers.keccak256("0x" + fullMessage);
    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      N / 2 + 1
    );

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + fullMessage + signatures;

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData,
    })
    await expectEvent.inTransaction(receipt!.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(messageData.protocolId),
      votingRoundId: toBN(messageData.votingRoundId),
      randomQualityScore: messageData.randomQualityScore,
      merkleRoot: merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    const confirmedMerkleRoot = await relay.merkleRoots(messageData.protocolId, messageData.votingRoundId);
    expect(confirmedMerkleRoot).to.equal(merkleRoot);

    let stateData = await relay.stateData();
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(messageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(messageData.votingRoundId.toString());
    expect(stateData.randomNumberQualityScore.toString()).to.be.equal(messageData.randomQualityScore.toString());

  });

  it("Should fail to relay due to low weight", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;
    const fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);
    const messageHash = ethers.keccak256("0x" + fullMessage);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      N / 2
    );

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + fullMessage + signatures;

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Not enough weight");
  });

  it("Should fail to relay due non increasing signature indices", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;
    const fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);
    const messageHash = ethers.keccak256("0x" + fullMessage);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      0,
      [0, 1, 2, 2, 1]
    );

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + fullMessage + signatures;

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Index out of order");
  });

  it("Should fail to relay due signature indices out of range", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId++;
    const fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);
    const messageHash = ethers.keccak256("0x" + fullMessage);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      0,
      [0, 1, 2, 101]
    );

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + fullMessage + signatures;

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Index out of range");
  });

  it("Should fail to due too short data for metadata", async () => {
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + "0000",
      })
    ).to.be.revertedWith("Invalid sign policy metadata");
  });

  it("Should fail on mismatch of signing policy length", async () => {
    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy.slice(0, -2),
      })
    ).to.be.revertedWith("Invalid sign policy length");
  });

  it("Should fail due to signing policy hash mismatch", async () => {
    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const tweakedSigningPolicy = signingPolicy.slice(0, -2) + ((parseInt(signingPolicy.slice(-2), 16) + 1) % 256).toString(16).padStart(2, "0");

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + tweakedSigningPolicy + "00",
      })
    ).to.be.revertedWith("Signing policy hash mismatch");
  });

  it("Should fail due to too short protocol message merkle root", async () => {
    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);
    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage.slice(0, -2),
      })
    ).to.be.revertedWith("Too short message");
  });

  it("Should fail due to delayed signing policy", async () => {
    // "Delayed sign policy"


    const newSigningPolicyData = { ...signingPolicyData };
    newSigningPolicyData.startVotingRoundId = votingRoundId + 1;
    const signingPolicy = encodeSigningPolicy(newSigningPolicyData);

    const relay2 = await Relay.new(
      signers[0].address,
      newSigningPolicyData.rewardEpochId,
      signingPolicyHash(signingPolicy),
      randomNumberProtocolId,
      firstVotingRoundStartSec,
      votingRoundDurationSec,
      firstRewardEpochVotingRoundId,
      rewardEpochDurationInVotingEpochs,
      THRESHOLD_INCREASE);

    const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay2.address,
        data: selector + signingPolicy.slice(2) + fullMessage
      })
    ).to.be.revertedWith("Delayed sign policy");

  });

  it("Should fail due to wrong signing policy reward epoch id", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = votingRoundId - rewardEpochDurationInVotingEpochs; // shift to previous reward epoch
    let fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage
      })
    ).to.be.revertedWith("Wrong sign policy reward epoch");

    newMessageData.votingRoundId = votingRoundId + 2 * rewardEpochDurationInVotingEpochs; // shift to one epoch after next reward epoch
    fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage
      })
    ).to.be.revertedWith("Wrong sign policy reward epoch");

    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs; // shift to next reward epoch
    fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);

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

  it("Should relay with old signing policy and 20% signatures more", async () => {

    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs; // shift to next reward epoch
    let fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);

    const messageHash = ethers.keccak256("0x" + fullMessage);
    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      Math.round(N * 0.6) + 1
    );

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + fullMessage + signatures;

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData,
    })
    await expectEvent.inTransaction(receipt!.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(newMessageData.protocolId),
      votingRoundId: toBN(newMessageData.votingRoundId),
      randomQualityScore: newMessageData.randomQualityScore,
      merkleRoot: merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    const confirmedMerkleRoot = await relay.merkleRoots(newMessageData.protocolId, newMessageData.votingRoundId);
    expect(confirmedMerkleRoot).to.equal(merkleRoot);

    let stateData = await relay.stateData();
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(newMessageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(newMessageData.votingRoundId.toString());
    expect(stateData.randomNumberQualityScore.toString()).to.be.equal(newMessageData.randomQualityScore.toString());

  });

  it("Should fail to relay with old signing policy and 20% signatures more due to slightly less weight", async () => {

    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs + 1; // shift to next reward epoch
    let fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);

    const messageHash = ethers.keccak256("0x" + fullMessage);
    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      Math.round(N * 0.6)
    );

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + fullMessage + signatures;

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Not enough weight");
  });

  it("Should relay new signing policy", async () => {
    const newSigningPolicyData = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.threshold = Math.round(newSigningPolicyData.threshold / 2);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = signingPolicyHash(encodeSigningPolicy(newSigningPolicyData));
    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 2 + 1
    );
    const newSigningPolicy = encodeSigningPolicy(newSigningPolicyData).slice(2);
    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + "00" + newSigningPolicy + signatures;

    const hashBefore = await relay.toSigningPolicyHash(newRewardEpoch);
    expect(hashBefore).to.equal(ZERO_BYTES32);

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData,
    })
    await expectEvent.inTransaction(receipt!.transactionHash, relay, "SigningPolicyRelayed", {
      rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
    });
    const hashAfter = await relay.toSigningPolicyHash(newRewardEpoch);
    expect(hashAfter).to.equal(localHash);
    const lastInitializedRewardEpoch = await relay.lastInitializedRewardEpoch();
    expect(lastInitializedRewardEpoch.toString()).to.equal(newRewardEpoch.toString());
    console.log("Gas used:", receipt?.gasUsed?.toString());
  });

  it("Should fail to relay again the message with new signing policy", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs; // shift to next reward epoch
    let fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);
    const messageHash = ethers.keccak256("0x" + fullMessage);

    const newSigningPolicyData = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.threshold = Math.round(newSigningPolicyData.threshold / 2);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const newSigningPolicy = encodeSigningPolicy(newSigningPolicyData).slice(2);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      26
    );

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = newSigningPolicy + fullMessage + signatures;

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Already relayed");
  });

  it("Should relay with new signing policy", async () => {
    const newMessageData = { ...messageData };
    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInVotingEpochs + 1; // shift to next reward epoch
    let fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);
    const messageHash = ethers.keccak256("0x" + fullMessage);

    const newSigningPolicyData = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    newSigningPolicyData.threshold = Math.round(newSigningPolicyData.threshold / 2);
    const newSigningPolicy = encodeSigningPolicy(newSigningPolicyData).slice(2);

    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      26
    );

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = newSigningPolicy + fullMessage + signatures;

    const receipt = await web3.eth.sendTransaction({
      from: signers[0].address,
      to: relay.address,
      data: selector + fullData,
    })
    await expectEvent.inTransaction(receipt!.transactionHash, relay, "ProtocolMessageRelayed", {
      protocolId: toBN(newMessageData.protocolId),
      votingRoundId: toBN(newMessageData.votingRoundId),
      randomQualityScore: newMessageData.randomQualityScore,
      merkleRoot: merkleRoot,
    });
    console.log("Gas used:", receipt?.gasUsed?.toString());
    const confirmedMerkleRoot = await relay.merkleRoots(newMessageData.protocolId, newMessageData.votingRoundId);
    expect(confirmedMerkleRoot).to.equal(merkleRoot);

    let stateData = await relay.stateData();
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(newMessageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(newMessageData.votingRoundId.toString());
    expect(stateData.randomNumberQualityScore.toString()).to.be.equal(newMessageData.randomQualityScore.toString());

  });


  it("Should fail due to not provided new sign policy size", async () => {
    // "No new sign policy size"

    const newSigningPolicyData = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = signingPolicyHash(encodeSigningPolicy(newSigningPolicyData));
    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 2 + 1
    );
    const newSigningPolicy = encodeSigningPolicy(newSigningPolicyData).slice(2);
    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + "00";

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("No new sign policy size");
  });

  it("Should fail due to wrong size of new signing policy", async () => {
    // "Wrong size for new sign policy"
    const newSigningPolicyData = { ...signingPolicyData };
    const newRewardEpoch = newSigningPolicyData.rewardEpochId + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = signingPolicyHash(encodeSigningPolicy(newSigningPolicyData));
    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 2 + 1
    );
    let newSigningPolicy = encodeSigningPolicy(newSigningPolicyData).slice(2);
    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
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

  it("Should fail due to providing new signing policy for a wrong reward epoch", async () => {
    // "Not next reward epoch"
    const newSigningPolicyData = { ...signingPolicyData };
    const lastInitializedRewardEpoch = parseInt((await relay.lastInitializedRewardEpoch()).toString());
    const newRewardEpoch = lastInitializedRewardEpoch + 2;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = signingPolicyHash(encodeSigningPolicy(newSigningPolicyData));
    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 2 + 1
    );
    const newSigningPolicy = encodeSigningPolicy(newSigningPolicyData).slice(2);
    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + "00" + newSigningPolicy + signatures;

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Not next reward epoch");
  });

  it("Should fail due to wrong length of signature data", async () => {
    // "Not enough signatures"
    const newSigningPolicyData = { ...signingPolicyData };
    const lastInitializedRewardEpoch = parseInt((await relay.lastInitializedRewardEpoch()).toString());
    const newRewardEpoch = lastInitializedRewardEpoch + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = signingPolicyHash(encodeSigningPolicy(newSigningPolicyData));
    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 2 + 1
    );
    const newSigningPolicy = encodeSigningPolicy(newSigningPolicyData).slice(2);
    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + "00" + newSigningPolicy + signatures.slice(0, -2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Not enough signatures");


  });

  it("Should fail due to a wrong signature", async () => {
    // "Wrong signature"
    const newSigningPolicyData = { ...signingPolicyData };
    const lastInitializedRewardEpoch = parseInt((await relay.lastInitializedRewardEpoch()).toString());
    const newRewardEpoch = lastInitializedRewardEpoch + 1;
    newSigningPolicyData.rewardEpochId = newRewardEpoch;
    newSigningPolicyData.voters = newSigningPolicyData.voters.slice(0, 50);
    newSigningPolicyData.weights = newSigningPolicyData.weights.slice(0, 50);
    newSigningPolicyData.startVotingRoundId = firstVotingRoundInRewardEpoch(newRewardEpoch);
    const localHash = signingPolicyHash(encodeSigningPolicy(newSigningPolicyData));
    const signatures = await generateSignatures(
      accountPrivateKeys,
      localHash,
      N / 2 + 1
    );
    const newSigningPolicy = encodeSigningPolicy(newSigningPolicyData).slice(2);
    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
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
  it("Should fail due message already relayed", async () => {
    // "Already relayed"

    const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);
    const messageHash = ethers.keccak256("0x" + fullMessage);
    const signatures = await generateSignatures(
      accountPrivateKeys,
      messageHash,
      N / 2 + 1
    );

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);
    const fullData = signingPolicy + fullMessage + signatures;

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).to.be.revertedWith("Already relayed");

  });

  describe("Direct signing policy setup", async () => {
    it("Should directly set the signing policy", async () => {
      const relay2 = await Relay.new(
        signers[0].address,
        0,
        signingPolicyHash(encodeSigningPolicy(signingPolicyData)),
        randomNumberProtocolId,
        firstVotingRoundStartSec,
        votingRoundDurationSec,
        firstRewardEpochVotingRoundId,
        rewardEpochDurationInVotingEpochs,
        THRESHOLD_INCREASE
      );

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;

      expectEvent(await relay2.setSigningPolicy(newSigningPolicyData), "SigningPolicyInitialized",
        {
          rewardEpochId: toBN(newSigningPolicyData.rewardEpochId),
          startVotingRoundId: toBN(newSigningPolicyData.startVotingRoundId),
          voters: newSigningPolicyData.voters,
          seed: toBN(newSigningPolicyData.seed),
          threshold: toBN(newSigningPolicyData.threshold),
          weights: newSigningPolicyData.weights.map(x => toBN(x)),
          signingPolicyBytes: encodeSigningPolicy(newSigningPolicyData)
        });


      // console.dir(receipt);
      let lastInitializedRewardEpoch = (await relay2.lastInitializedRewardEpoch()).toString();
      expect(lastInitializedRewardEpoch).to.equal(newSigningPolicyData.rewardEpochId.toString());
      const obtainedSigningPolicyHash = await relay2.toSigningPolicyHash(newSigningPolicyData.rewardEpochId);
      const localHash = signingPolicyHash(encodeSigningPolicy(newSigningPolicyData));
      expect(obtainedSigningPolicyHash).to.equal(localHash);

    });

    it("Should fail to directly set the signing policy due to wrong reward epoch", async () => {
      // "not next reward epoch"
      const relay2 = await Relay.new(
        signers[0].address,
        0,
        signingPolicyHash(encodeSigningPolicy(signingPolicyData)),
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
        0,
        signingPolicyHash(encodeSigningPolicy(signingPolicyData)),
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
        0,
        signingPolicyHash(encodeSigningPolicy(signingPolicyData)),
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
        0,
        signingPolicyHash(encodeSigningPolicy(signingPolicyData)),
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



  });
});
