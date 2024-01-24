import { sleep } from "../../../deployment/tasks/run-simulation";
import { IProtocolMessageMerkleRoot } from "../protocol/ProtocolMessageMerkleRoot";
import { SignDepositMessage, SignerEmulator } from "./SignerEmulator";
import { extractEpochSettings } from "./mock-test-helpers";

export interface SignerEmulationConfig {
  varianceMs: number;
  numberOfSubProtocols: number;
  shareOfSignedSubprotocols: number;
}

export class SignerEmulatorManager {
  constructor(
    public privateKeys: string[],
    public web3: Web3,
    public submissionContractAddress: string,
    public flareSystemManagerAddress: string,
    public signerEmulationConfig: SignerEmulationConfig,
    public loggingEnabled = true
  ) { }

  public randomMessages(merkleRoots: string[], votingRoundId: number, share: number) {
    const maxNumberOfProtocols = merkleRoots.length;
    const range = Array.from({ length: maxNumberOfProtocols }, (value, index) => index);
    const size = Math.round(share * maxNumberOfProtocols);
    const subsample = range.map(a => [a, Math.random()])
      .sort((a, b) => { return a[1] < b[1] ? -1 : 1; })
      .slice(0, size)
      .map(a => a[0])
      .sort();
    return subsample.map(subprotocolId => {
      return {
        messageToSign: {
          protocolId: subprotocolId + 1,
          votingRoundId,
          isSecureRandom: false,
          merkleRoot: merkleRoots[subprotocolId]
        } as IProtocolMessageMerkleRoot,
        unsignedMessage: this.web3.utils.randomHex(32)
      } as SignDepositMessage;
    })
  }

  public async run() {
    const signerEmulators = this.privateKeys.map(privateKey => new SignerEmulator(privateKey, this.web3, this.submissionContractAddress, this.loggingEnabled));
    const epochSettings = await extractEpochSettings(this.flareSystemManagerAddress);
    while (true) {
      const signingVotingRoundId = epochSettings.votingEpochForTime(Date.now()) - 1;
      const startTime = Date.now();
      const merkleRoots = Array.from({ length: this.signerEmulationConfig.numberOfSubProtocols }, () => this.web3.utils.randomHex(32));
      await Promise.all(signerEmulators.map(async (signerEmulator, index) => {
        // variance at sending
        const messages = this.randomMessages(merkleRoots, signingVotingRoundId, this.signerEmulationConfig.shareOfSignedSubprotocols);
        await sleep(Math.floor(Math.random() * this.signerEmulationConfig.varianceMs));
        await signerEmulator.sendMessages(messages);
      }));
      // Periodical repeat  
      const delay = (startTime + epochSettings.votingEpochDurationSec * 1000) - Date.now()
      console.log(`Sleep delay: ${delay}`)    
      await sleep(delay > 0 ? delay : 0);
    }
  }
}