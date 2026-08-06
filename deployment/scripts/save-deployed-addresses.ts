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

// Networks are identified by name: the Flare-family bases (flare/songbird/coston/coston2/scdev,
// optionally "-staging"), or a relay mirror name from the source config's `mirrors` map (e.g.
// "arbitrum", "arbitrum-sepolia"). Restrict to a filename-safe lowercase token so the value is
// safe to use as `deploys/<network>.json` (no path separators or dots).
const isValidNetwork = /^[a-z0-9][a-z0-9-]*$/.test(network);
if (!isValidNetwork) {
  throw new Error(`Invalid network name: ${network}`);
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
