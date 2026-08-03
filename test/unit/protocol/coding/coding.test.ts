import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { config, contract, ethers, web3 } from "hardhat";
import { HardhatNetworkAccountConfig } from "hardhat/types";
import { ECDSASignatureWithIndex } from "../../../../scripts/libs/protocol/ECDSASignatureWithIndex";
import {
  IProtocolMessageMerkleRoot,
  ProtocolMessageMerkleRoot,
} from "../../../../scripts/libs/protocol/ProtocolMessageMerkleRoot";
import { ISigningPolicy, SigningPolicy } from "../../../../scripts/libs/protocol/SigningPolicy";
import { IPayloadMessage, PayloadMessage } from "../../../../scripts/libs/protocol/PayloadMessage";
import { getTestFile } from "../../../utils/constants";
import { defaultTestSigningPolicy, generateSignatures } from "./coding-helpers";
import { RelayMessage } from "../../../../scripts/libs/protocol/RelayMessage";
import { FtsoConfigurations } from "../../../../scripts/libs/protocol/FtsoConfigurations";

contract(`Coding; ${getTestFile(__filename)}`, async () => {
  let signers: SignerWithAddress[];
  let accountAddresses: string[];
  const accountPrivateKeys = (config.networks.hardhat.accounts as HardhatNetworkAccountConfig[]).map(
    (x) => x.privateKey
  );
  const N = 100;
  const singleWeight = 500;
  const firstRewardEpochVotingRoundId = 1000;
  const rewardEpochDurationInEpochs = 3360; // 3.5 days
  const votingRoundId = 4111;
  const rewardEpochId = Math.floor((votingRoundId - firstRewardEpochVotingRoundId) / rewardEpochDurationInEpochs);
  let signingPolicyData: ISigningPolicy;
  let newSigningPolicyData: ISigningPolicy;
  // RLY-23: signed relay digests are chain-bound; set in before().
  let chainId: number;

  before(async () => {
    chainId = await web3.eth.getChainId();
    accountAddresses = (await ethers.getSigners()).map((x) => x.address);
    signingPolicyData = defaultTestSigningPolicy(accountAddresses, N, singleWeight);
    signingPolicyData.rewardEpochId = rewardEpochId;
    newSigningPolicyData = { ...signingPolicyData };
    newSigningPolicyData.rewardEpochId++;
  });

  it("Should encode and decode signing policy", async () => {
    const encoded = SigningPolicy.encode(signingPolicyData);
    const decoded = SigningPolicy.decode(encoded);
    expect(decoded).to.deep.equal(signingPolicyData);
    const decoded2 = SigningPolicy.decode(encoded + "123456", false);
    expect(decoded2).to.deep.equal({ ...decoded, encodedLength: encoded.length - 2 });
  });

  it("Should encode and decode ECDSA signature", async () => {
    const messageHash = "0x1122334455667788990011223344556677889900112233445566778899001122";
    const signature = await ECDSASignatureWithIndex.signMessageHash(messageHash, accountPrivateKeys[0], 0);
    const encoded = ECDSASignatureWithIndex.encode(signature);
    const decoded = ECDSASignatureWithIndex.decode(encoded);
    expect(decoded).to.deep.equal(signature);
  });

  it("Should encode and decode protocol message merkle root", async () => {
    const messageData = {
      protocolId: 15,
      votingRoundId: 1234,
      isSecureRandom: true,
      merkleRoot: "0x1122334455667788990011223344556677889900112233445566778899001122",
    } as IProtocolMessageMerkleRoot;
    const encoded = ProtocolMessageMerkleRoot.encode(messageData);
    const decoded = ProtocolMessageMerkleRoot.decode(encoded);
    expect(decoded).to.deep.equal(messageData);
    const decoded2 = ProtocolMessageMerkleRoot.decode(encoded + "123456", false);
    expect(decoded2).to.deep.equal({ ...decoded, encodedLength: encoded.length - 2 });
  });

  it("Should encode and decode signature payloads", async () => {
    const payloads: IPayloadMessage<string>[] = [];
    const N = 10;
    let encoded = "0x";
    for (let i = 0; i < N; i++) {
      const payload = {
        protocolId: i,
        votingRoundId: 10 * i,
        payload: web3.utils.randomHex(2 * (N - i)),
      } as IPayloadMessage<string>;
      payloads.push(payload);
      encoded += PayloadMessage.encode(payload).slice(2);
    }
    const decoded = PayloadMessage.decode(encoded);
    expect(decoded).to.deep.equal(payloads);
  });

  it("Should encode and decode Relay message", async () => {
    const merkleRoot = ethers.hexlify(ethers.randomBytes(32));
    const messageData = {
      protocolId: 15,
      votingRoundId,
      isSecureRandom: true,
      merkleRoot,
    } as IProtocolMessageMerkleRoot;

    const messageHash = ProtocolMessageMerkleRoot.hash(messageData, chainId);
    const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: messageData,
    };

    let fullData = RelayMessage.encode(relayMessage);
    expect(RelayMessage.decode(fullData)).not.to.throw;
    let decodedRelayMessage = RelayMessage.decode(fullData);
    expect(RelayMessage.equals(relayMessage, decodedRelayMessage)).to.be.true;

    const relayMessage2 = {
      signingPolicy: signingPolicyData,
      signatures,
      newSigningPolicy: newSigningPolicyData,
    };

    expect(RelayMessage.equals(relayMessage, relayMessage2)).to.be.false;
    fullData = RelayMessage.encode(relayMessage2);
    expect(RelayMessage.decode(fullData)).not.to.throw;
    decodedRelayMessage = RelayMessage.decode(fullData);
    expect(RelayMessage.equals(relayMessage2, decodedRelayMessage)).to.be.true;
  });

  it("Should encode and decode a random-number Relay message with the RLY-03 trailer", async () => {
    const merkleRoot = ethers.hexlify(ethers.randomBytes(32));
    const messageData = {
      protocolId: 2,
      votingRoundId,
      isSecureRandom: true,
      merkleRoot,
    } as IProtocolMessageMerkleRoot;
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData, chainId);
    const signatures = await generateSignatures(accountPrivateKeys, messageHash, N / 2 + 1);

    const randomNumber = ethers.hexlify(ethers.randomBytes(32));
    const merkleProof = [
      ethers.hexlify(ethers.randomBytes(32)),
      ethers.hexlify(ethers.randomBytes(32)),
      ethers.hexlify(ethers.randomBytes(32)),
    ];

    const relayMessage = {
      signingPolicy: signingPolicyData,
      signatures,
      protocolMessageMerkleRoot: messageData,
      isRandomNumberGeneratingProtocolMessage: true,
      randomNumber,
      merkleProof,
    };

    const fullData = RelayMessage.encode(relayMessage);
    const decoded = RelayMessage.decode(fullData);
    // the trailer is now parsed (previously decode() threw on the extra bytes)
    expect(decoded.isRandomNumberGeneratingProtocolMessage).to.be.true;
    expect(decoded.randomNumber!.toLowerCase()).to.equal(randomNumber.toLowerCase());
    expect(decoded.merkleProof!.map(x => x.toLowerCase())).to.deep.equal(merkleProof.map(x => x.toLowerCase()));
    // the core message still round-trips and re-encoding reproduces the exact bytes (incl. the trailer)
    expect(decoded.signatures.length).to.equal(signatures.length);
    expect(RelayMessage.equals(relayMessage, decoded)).to.be.true;
    expect(RelayMessage.encode(decoded)).to.equal(fullData);

    // edge case: single-leaf tree ⇒ empty Merkle proof ⇒ trailer is just the 32-byte random number
    const relayMessageEmptyProof = { ...relayMessage, merkleProof: [] as string[] };
    const encodedEmpty = RelayMessage.encode(relayMessageEmptyProof);
    const decodedEmpty = RelayMessage.decode(encodedEmpty);
    expect(decodedEmpty.isRandomNumberGeneratingProtocolMessage).to.be.true;
    expect(decodedEmpty.randomNumber!.toLowerCase()).to.equal(randomNumber.toLowerCase());
    expect(decodedEmpty.merkleProof).to.deep.equal([]);
    expect(RelayMessage.encode(decodedEmpty)).to.equal(encodedEmpty);

    // negative: a non-random message must NOT acquire a trailer on decode
    const plainMessage = { signingPolicy: signingPolicyData, signatures, protocolMessageMerkleRoot: messageData };
    const decodedPlain = RelayMessage.decode(RelayMessage.encode(plainMessage));
    expect(decodedPlain.isRandomNumberGeneratingProtocolMessage).to.be.undefined;
    expect(decodedPlain.randomNumber).to.be.undefined;
    expect(decodedPlain.merkleProof).to.be.undefined;
  });

  it("Should encode and decode ftso feeds", async () => {
    const feeds = [
      { category: 1, name: "BTC/USD" },
      { category: 126, name: "1TEST123" },
    ];
    const encoded = FtsoConfigurations.encodeFeedIds(feeds);
    const decoded = FtsoConfigurations.decodeFeedIds(encoded);
    expect(decoded).to.deep.equal(feeds);
  });
});
