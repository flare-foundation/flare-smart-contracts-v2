import { readFileSync, globSync } from "fs";
import { execSync } from "child_process";

// get network from command line argument (mandatory)
const network = process.argv[2];
if (!network) {
  throw new Error("Usage: npx tsx deployment/scripts/verify-tee-contracts.ts <network>");
}
// check if network is valid (supports base networks and any "*-staging")
const allowedBaseNetworks = ["coston2", "coston", "flare", "songbird", "scdev"];
const isValidNetwork =
  allowedBaseNetworks.includes(network) ||
  (network.endsWith("-staging") && allowedBaseNetworks.includes(network.replace(/-staging$/, "")));
if (!isValidNetwork) {
  throw new Error(`Invalid network: ${network}`);
}
console.log(`Verifying TEE contracts on network: ${network}`);

const isMock = process.argv[3] === "mock";
// set paths and URLs based on network
const addressesFilePath = `deployment/deploys/${network}${isMock ? "_mock" : ""}.json`;
// for any "*-staging" network, use the base network for RPC and verifier
const baseNetwork = network.endsWith("-staging") ? network.replace(/-staging$/, "") : network;
const rpcUrl = `https://${baseNetwork}-api.flare.network/ext/C/rpc`;
const verifierUrl = `https://${baseNetwork}-explorer.flare.network/api/`;
const verifier = "blockscout";

const raw: unknown = JSON.parse(readFileSync(addressesFilePath, "utf8"));
if (!Array.isArray(raw)) {
  throw new Error("Invalid contract info format");
}

// TEE-related contract names to verify
const teeContractNames = new Set([
  // FDC2 implementations and proxies
  "Fdc2HubImplementation",
  "Fdc2Hub",
  "Fdc2RequestFeeConfigurationsImplementation",
  "Fdc2RequestFeeConfigurations",
  "Fdc2VerificationImplementation",
  "Fdc2Verification",
  // TeePayments
  "TeePaymentsImplementation",
  // TeeRewardOffersManager
  "TeeRewardOffersManager",
  // VrfVerifier
  "VrfVerifier",
  // FlareTeeManager diamond and facets
  "FlareTeeManager",
  "FlareTeeManagerInit",
  "DiamondGovernanceFacet",
  "DiamondLoupeFacet",
  "ExtensionManagerFacet",
  "InstructionsFacet",
  "MachineManagerFacet",
  "VerificationFacet",
  "OperationFeesFacet",
  "OwnerAllowlistFacet",
  "SystemStateVerifierFacet",
  "WalletManagerFacet",
  "WalletKeyManagerFacet",
  "WalletProjectManagerFacet",
  "WalletBackupManagerFacet",
  "VrfFacet",
  "ExternalAddressesFacet",
  "ReplicationFacet",
  "ExtensionGovernanceFacet",
  "UpgradeManagerFacet",
  "ReplicationInit",
]);

// Also match TeePayments_ prefixed entries (e.g. TeePayments_F_XRP)
function isTeeContract(name: string): boolean {
  return teeContractNames.has(name) || name.startsWith("TeePayments_");
}

const contracts = raw
  .map((item) => {
    if (
      typeof item === "object" &&
      item !== null &&
      typeof (item as { address?: unknown }).address === "string" &&
      typeof (item as { contractName?: unknown }).contractName === "string" &&
      typeof (item as { name?: unknown }).name === "string"
    ) {
      return {
        name: (item as { name: string }).name,
        contractName: (item as { contractName: string }).contractName,
        address: (item as { address: string }).address,
      };
    }
    throw new Error("Invalid contract info item");
  })
  .filter((c) => isTeeContract(c.name));

if (contracts.length === 0) {
  console.log("No TEE contracts found in deploys file.");
  process.exit(0);
}

console.log(`Found ${contracts.length} TEE contract(s) to verify.`);

contracts.forEach((contract) => {
  const address = contract.address;
  const contractFile = contract.contractName;
  // remove .sol from contractFile for the contract name
  const contractName = contractFile.replace(".sol", "");
  // find the full path of the contract file in TEE/FDC2/diamond directories
  const matches: string[] = globSync(`contracts/{tee,fdc2,diamond}/**/${contractFile}`);
  if (matches.length === 0) {
    throw new Error(`Contract file not found: ${contractFile}`);
  }
  if (matches.length > 1) {
    throw new Error(`Multiple contract files found for ${contractFile}: ${matches.join(", ")}`);
  }
  const contractPath = matches[0];
  const verifyCmd = `forge verify-contract \
    --rpc-url ${rpcUrl} \
    --verifier ${verifier} \
    --verifier-url ${verifierUrl} \
    ${address} \
    ${contractPath}:${contractName} \
    --skip-is-verified-check`;
  console.log(`Verifying: ${contract.name} @ ${address} (${contractPath}:${contractName})`);
  try {
    execSync(verifyCmd, { stdio: "inherit" });
  } catch (err) {
    if (err instanceof Error) {
      throw err;
    } else {
      throw new Error(String(err));
    }
  }
});

console.log("TEE contract verification complete.");
