import Web3 from "web3";
import { IProtocolMessageMerkleRoot, ProtocolMessageMerkleRoot } from "../protocol/ProtocolMessageMerkleRoot";
import { ECDSASignature } from "../protocol/ECDSASignature";
import { ISignaturePayload, SignaturePayload } from "../protocol/SignaturePayload";
import { PayloadMessage } from "../protocol/PayloadMessage";
import { SUBMIT_SIGNATURES_SELECTOR } from "./mock-test-helpers";
import { getLogger } from "../../../deployment/utils/logger";
import { Logger } from "winston";

export interface SignDepositMessage {
  messageToSign: IProtocolMessageMerkleRoot;
  unsignedMessage: string;
}

export class SignerEmulator {
  logger?: Logger;
  address!: string;
  constructor(
    private privateKey: string,
    public web3: Web3,
    public submissionContractAddress: string,
    public loggingEnabled = true
  ) {
    this.address = this.web3.eth.accounts.privateKeyToAccount(this.privateKey).address;
    if (this.loggingEnabled) {
      this.logger = getLogger(`signer-emulator-${this.address}`)
    }
  }

  public async signAndEncode(messages: SignDepositMessage[]): Promise<string> {
    const signaturePayloadHexList: string[] = await Promise.all(messages.map(async (message) => {
      const messageHash = web3.utils.keccak256(ProtocolMessageMerkleRoot.encode(message.messageToSign))
      const signaturePayload = {
        type: "0x00",
        message: message.messageToSign,
        signature: await ECDSASignature.signMessageHash(messageHash, this.privateKey),
        unsignedMessage: message.unsignedMessage
      } as ISignaturePayload;
      return PayloadMessage.encode({
        protocolId: message.messageToSign.protocolId,
        votingRoundId: message.messageToSign.votingRoundId,
        payload: SignaturePayload.encode(signaturePayload)
      }) 
    }));
    return PayloadMessage.concatenateHexStrings(signaturePayloadHexList);
  }

  public async sendMessages(messages: SignDepositMessage[]): Promise<any> {
    await web3.eth.sendTransaction({
      from: this.address,
      to: this.submissionContractAddress,
      data: SUBMIT_SIGNATURES_SELECTOR + (await this.signAndEncode(messages)).slice(2),
    });
    if (this.loggingEnabled) {
      this.logger!.info(`Voter ${this.address} sent:`);
      for (const message of messages) {
        this.logger!.info(`   ${ProtocolMessageMerkleRoot.print(message.messageToSign)}, ${message.unsignedMessage}`)
      }
    }
  }
}