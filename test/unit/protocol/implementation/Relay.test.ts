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
import { expectRevert } from "@openzeppelin/test-helpers";

const Relay = artifacts.require("Relay");

contract(`Relay.sol; ${getTestFile(__filename)}`, async () => {
  // let accounts: Account[];
  let signers: SignerWithAddress[];
  const accountPrivateKeys = (config.networks.hardhat.accounts as HardhatNetworkAccountConfig[]).map(x => x.privateKey);
  let relay: RelayInstance;
  const selector = ethers.keccak256(ethers.toUtf8Bytes("relay()"))!.slice(0, 10);
  const N = 100;
  const singleWeight = 500;
  // The next two should match the contract settings
  const firstRewardEpochVotingRoundId = 1000;
  const rewardEpochDurationInEpochs = 3360; // 3.5 days
  const votingRoundId = 4111;
  const rewardEpochId = Math.floor((votingRoundId - firstRewardEpochVotingRoundId) / rewardEpochDurationInEpochs);
  let signingPolicyData: SigningPolicy;
  const randomNumberProtocolId = 15;

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
    relay = await Relay.new(signers[0].address, signingPolicyData.rewardEpochId, localHash, randomNumberProtocolId);
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

    const receipt = await (
      await signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + fullData,
      })
    ).wait();

    console.log("Gas used:", receipt?.gasUsed?.toString());
    const confirmedMerkleRoot = await relay.merkleRoots(messageData.protocolId, messageData.votingRoundId);
    expect(confirmedMerkleRoot).to.equal(merkleRoot);

    let stateData = await relay.stateData();
    expect(stateData.randomNumberProtocolId.toString()).to.be.equal(messageData.protocolId.toString());
    expect(stateData.randomVotingRoundId.toString()).to.be.equal(messageData.votingRoundId.toString());
    expect(stateData.randomNumberQualityScore.toString()).to.be.equal(messageData.randomQualityScore.toString());
    // console.log("randomNumberProtocolId", stateData.randomNumberProtocolId.toString());
    // console.log("randomTimestamp", stateData.randomTimestamp.toString());
    // console.log("randomVotingRoundId", stateData.randomVotingRoundId.toString());
    // console.log("randomNumberQualityScore", stateData.randomNumberQualityScore.toString());
    
  });

  it("Should fail to relay due to low weight", async () => {
    const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);
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
    const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);
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
    const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);
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

    const relay2 = await Relay.new(signers[0].address, newSigningPolicyData.rewardEpochId, signingPolicyHash(signingPolicy), randomNumberProtocolId);

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
    newMessageData.votingRoundId = votingRoundId - rewardEpochDurationInEpochs; // shift to previous reward epoch
    let fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);

    const signingPolicy = encodeSigningPolicy(signingPolicyData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage
      })
    ).to.be.revertedWith("Wrong sign policy reward epoch");

    newMessageData.votingRoundId = votingRoundId + 2 * rewardEpochDurationInEpochs; // shift to one epoch after next reward epoch
    fullMessage = encodeProtocolMessageMerkleRoot(newMessageData).slice(2);

    await expect(
      signers[0].sendTransaction({
        from: signers[0].address,
        to: relay.address,
        data: selector + signingPolicy + fullMessage
      })
    ).to.be.revertedWith("Wrong sign policy reward epoch");

    newMessageData.votingRoundId = votingRoundId + rewardEpochDurationInEpochs; // shift to next reward epoch
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

  });

  it("Should fail to relay with old signing policy with just 50% of signatures", async () => {

  });

  it("Should relay new signing policy", async () => {

  });

  it("Should fail due to not provided new sign policy size", async () => {
    // "No new sign policy size"

  });

  it("Should fail due to wrong size of new signing policy", async () => {
    // "Wrong size for new sign policy"

  });

  it("Should fail due to providing new signing policy for a wrong reward epoch", async () => {
    // "Not next reward epoch"

  });

  it("Should fail due to wrong length of signature data", async () => {
    // "Wrong signatures length"

  });

  it("Should fail due to a wrong signature", async () => {
    // "Wrong signature"

  });


  it("Should relay with new signing policy", async () => {

  });

  describe("Direct signing policy setup", async () => {
    it("Should directly set the signing policy", async () => {
      const relay2 = await Relay.new(signers[0].address, 0, signingPolicyHash(encodeSigningPolicy(signingPolicyData)), randomNumberProtocolId);

      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;

      const receipt = await relay2.setSigningPolicy(newSigningPolicyData);

      // console.dir(receipt);
      let lastInitializedRewardEpoch = (await relay2.lastInitializedRewardEpoch()).toString();
      expect(lastInitializedRewardEpoch).to.equal(newSigningPolicyData.rewardEpochId.toString());
      const obtainedSigningPolicyHash = await relay2.toSigningPolicyHash(newSigningPolicyData.rewardEpochId);
      const localHash = signingPolicyHash(encodeSigningPolicy(newSigningPolicyData));
      expect(obtainedSigningPolicyHash).to.equal(localHash);

    });

    it("Should fail to directly set the signing policy due to wrong reward epoch", async () => {
      // "not next reward epoch"
      const relay2 = await Relay.new(signers[0].address, 0, signingPolicyHash(encodeSigningPolicy(signingPolicyData)), randomNumberProtocolId);
      const newSigningPolicyData = { ...signingPolicyData };

      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "not next reward epoch");
      newSigningPolicyData.rewardEpochId += 2;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "not next reward epoch");

    });

    it("Should fail to directly set the signing policy due to policy being trivial", async () => {
      // "must be non-trivial"
      const relay2 = await Relay.new(signers[0].address, 0, signingPolicyHash(encodeSigningPolicy(signingPolicyData)), randomNumberProtocolId);
      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.voters = [];
      newSigningPolicyData.weights = [];
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "must be non-trivial");

    });

    it("Should fail due to voters and weights length mismatch", async () => {
      // "size mismatch"
      const relay2 = await Relay.new(signers[0].address, 0, signingPolicyHash(encodeSigningPolicy(signingPolicyData)), randomNumberProtocolId);
      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      newSigningPolicyData.weights = [];
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData), "size mismatch");

    });

    it("Should fail due to wrong setter", async () => {
      // "only sign policy setter"
      const relay2 = await Relay.new(signers[0].address, 0, signingPolicyHash(encodeSigningPolicy(signingPolicyData)), randomNumberProtocolId);
      const newSigningPolicyData = { ...signingPolicyData };
      newSigningPolicyData.rewardEpochId += 1;
      await expectRevert(relay2.setSigningPolicy(newSigningPolicyData, { from: signers[1].address }), "only sign policy setter");
    });



  });
});
