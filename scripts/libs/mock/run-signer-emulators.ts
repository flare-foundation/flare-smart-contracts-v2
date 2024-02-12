import { SignerEmulationConfig, SignerEmulatorManager } from "./SignerEmulatorManager";
import { FIXED_TEST_VOTERS, contractAddress, privateKeysForAddresses } from "./mock-test-helpers";

const voterPrivateKeys = privateKeysForAddresses(FIXED_TEST_VOTERS)

const signerEmulationConfig: SignerEmulationConfig = {
  varianceMs: 10000,
  numberOfSubProtocols: 5,
  shareOfSignedSubprotocols: 0.8,
}

const NUMBER_OF_SIGNERS = 4;
const LOGGING_ENABLED = true;

const sem = new SignerEmulatorManager(
  voterPrivateKeys,
  web3, 
  contractAddress("Submission"),
  contractAddress("FlareSystemsManager"),
  signerEmulationConfig,
  LOGGING_ENABLED
);

sem.run()
  .then(() => {console.log("done")})
  .catch((e) => {console.error(e); process.exit(1)});
