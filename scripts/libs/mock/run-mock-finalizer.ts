import privateKeys from "../../../deployment/test-1020-accounts.json";
import { MockFinalizer } from "./MockFinalizer";
import { contractAddress } from "./mock-test-helpers";

const mf = new MockFinalizer(
  privateKeys[0].privateKey,
  web3, 
  contractAddress("Submission"),
  contractAddress("Relay"),
  contractAddress("FlareSystemsManager"),
);

mf.run()
  .then(() => {console.log("done")})
  .catch((e) => {console.error(e); process.exit(1)});