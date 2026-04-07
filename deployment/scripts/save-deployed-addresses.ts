import * as fs from "fs";

// Read Forge output from a output file
const outputPath = "forge-deploy-output.txt";
const output = fs.readFileSync(outputPath, "utf8");

const lines = output.split("\n");
type ContractInfo = {
  name: string;
  contractName: string;
  address: string;
};

const contracts: ContractInfo[] = [];
let network: string = "unknown";

lines.forEach((line: string) => {
  const match = line.match(/^\s*DEPLOYED:\s*([^,]+),\s*([^:]+):\s*(0x[a-fA-F0-9]{40})$/);
  const matchNetwork = line.match(/^\s*NETWORK:\s*([a-zA-Z0-9_-]+)/);
  if (match) {
    contracts.push({
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

fs.mkdirSync("deployment/deploys", { recursive: true });
const isMock = process.argv[2] === "mock";
const filePath = `deployment/deploys/${network}${isMock ? "_mock" : ""}.json`;

let existingContracts: ContractInfo[] = [];
if (fs.existsSync(filePath)) {
  const raw: unknown = JSON.parse(fs.readFileSync(filePath, "utf8"));
  if (!Array.isArray(raw)) {
    throw new Error(`Invalid contract info format in ${filePath}`);
  }
  existingContracts = raw.map((item) => {
    if (
      typeof item === "object" &&
      item !== null &&
      typeof (item as { name?: unknown }).name === "string" &&
      typeof (item as { contractName?: unknown }).contractName === "string" &&
      typeof (item as { address?: unknown }).address === "string"
    ) {
      return {
        name: (item as { name: string }).name,
        contractName: (item as { contractName: string }).contractName,
        address: (item as { address: string }).address,
      };
    }
    throw new Error(`Invalid contract info item in ${filePath}`);
  });
}

for (const deployed of contracts) {
  const index = existingContracts.findIndex((item) => item.name === deployed.name);
  if (index >= 0) {
    existingContracts[index] = deployed;
  } else {
    existingContracts.push(deployed);
  }
}

fs.writeFileSync(filePath, JSON.stringify(existingContracts, null, 2));
fs.unlinkSync(outputPath);
console.log(`Saved deployed addresses to ${filePath}`);
