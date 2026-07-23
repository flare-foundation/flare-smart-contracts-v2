// update-facet-address.ts
import fs from "fs";
import path from "path";
import { Contract, Contracts } from "../scripts/Contracts";

const [filePath, facetName, facetAddress] = process.argv.slice(2);

if (!filePath || !facetName || !facetAddress) {
  console.error("Usage: update-facet-address.ts <filePath> <facetName> <facetAddress>");
  process.exit(1);
}

// The history file lives alongside the current deploys file under an `all/` subfolder
// (e.g. deployment/deploys/coston.json -> deployment/deploys/all/coston.json).
const allFilePath = path.join(path.dirname(filePath), "all", path.basename(filePath));
fs.mkdirSync(path.dirname(allFilePath), { recursive: true });

// Reuse the shared Contracts abstraction from the deploy path: it updates the single `address`
// in the current file and appends (deduped) to the `addresses` history in the all/ file.
const contracts = new Contracts();
contracts.deserializeFile(filePath);
contracts.deserializeFile(allFilePath, true);

contracts.add(new Contract(facetName, `${facetName}.sol`, facetAddress));
contracts.serialize();

console.log(`Updated ${facetName} to ${facetAddress} in ${filePath} (history: ${allFilePath})`);
