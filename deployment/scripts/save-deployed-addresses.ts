import * as fs from "fs";
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from "./deploy-utils";

// Read Forge output from a output file
const outputPath = "forge-deploy-output.txt";
const output = fs.readFileSync(outputPath, "utf8");

const lines = output.split("\n");
type DeployedInfo = {
  name: string;
  contractName: string;
  address: string;
};

const deployed: DeployedInfo[] = [];
let network: string = "unknown";

lines.forEach((line: string) => {
  const match = line.match(/^\s*DEPLOYED:\s*([^,]+),\s*([^:]+):\s*(0x[a-fA-F0-9]{40})$/);
  const matchNetwork = line.match(/^\s*NETWORK:\s*([a-zA-Z0-9_-]+)/);
  if (match) {
    deployed.push({
      name: match[1].trim(),
      contractName: match[2].trim(),
      address: match[3].trim(),
    });
  } else if (matchNetwork) {
    network = matchNetwork[1].trim();
  }
});

if (network === "unknown") {
  throw new Error("Network name not found in output");
}

const allowedBaseNetworks = ["coston2", "coston", "flare", "songbird", "scdev"];
const isValidNetwork =
  allowedBaseNetworks.includes(network) ||
  (network.endsWith("-staging") && allowedBaseNetworks.includes(network.replace(/-staging$/, "")));
if (!isValidNetwork) {
  throw new Error(`Invalid network: ${network}`);
}

const isMock = process.argv[2] === "mock";
const networkFile = `${network}${isMock ? "_mock" : ""}.json`;

fs.mkdirSync("deployment/deploys", { recursive: true });
fs.mkdirSync("deployment/deploys/all", { recursive: true });

const contracts = new Contracts();
contracts.deserializeFile(`deployment/deploys/${networkFile}`);
contracts.deserializeFile(`deployment/deploys/all/${networkFile}`, true);

for (const entry of deployed) {
  spewNewContractInfo(contracts, null, entry.name, entry.contractName, entry.address, false, false);
}

contracts.serialize();
fs.unlinkSync(outputPath);
console.log(`Saved deployed addresses to deployment/deploys/${networkFile}`);
