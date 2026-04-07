process.removeAllListeners("warning");
process.on("warning", (e) => {
  if (e.name !== "DeprecationWarning") return;
});

const { readFileSync } = require("fs");
let Web3 = require("web3");
// Support both CommonJS and ESM builds of web3
Web3 = Web3.default || Web3;
const web3 = new Web3();

function getInterfaceSelectors() {
  const artifactPath =
    "artifacts-forge/IIFlareTeeManager.sol/IIFlareTeeManager.json";
  const artifact = JSON.parse(readFileSync(artifactPath, "utf8"));
  const interfaceSelectors = getInterfaceSelectorMap(artifact.abi);
  return interfaceSelectors;
}

function getInterfaceSelectorMap(abiItems) {
  const interfaceSelectorPairs = abiItems
    .filter((it) => it.type === "function")
    .map((it) => [web3.eth.abi.encodeFunctionSignature(it), it]);
  return new Map(interfaceSelectorPairs);
}

function getContractSelectors(contractName) {
  const filterSelectors = getInterfaceSelectors();
  const contractArtifactPath = `artifacts-forge/${contractName}.sol/${contractName}.json`;
  const contractArtifact = JSON.parse(readFileSync(contractArtifactPath, "utf8"));
  const contractSelectors = contractArtifact.abi
    .filter((it) => it.type === "function")
    .map((it) => web3.eth.abi.encodeFunctionSignature(it));
  const exposedSelectors = contractSelectors.filter((sel) => filterSelectors.has(sel));
  return exposedSelectors;
}

if (require.main === module) {
  const contractName = process.argv[2];
  if (!contractName) {
    console.error("Usage: node flare-tee-manager-selectors.js <ContractName>");
    process.exit(1);
  }
  const selectors = getContractSelectors(contractName);
  // Output ABI-encoded bytes4[]
  process.stdout.write(web3.eth.abi.encodeParameter("bytes4[]", selectors));
}
