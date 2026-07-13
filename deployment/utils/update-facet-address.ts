// update-facet-address.ts
import fs from "fs";

const [filePath, facetName, facetAddress] = process.argv.slice(2);

if (!filePath || !facetName || !facetAddress) {
  console.error("Usage: update-facet-address.ts <filePath> <facetName> <facetAddress>");
  process.exit(1);
}

interface ContractEntry {
  name: string;
  contractName: string;
  address: string;
}

const data: ContractEntry[] = JSON.parse(fs.readFileSync(filePath, "utf8")) as ContractEntry[];

let found = false;
for (const entry of data) {
  if (entry.name === facetName) {
    entry.address = facetAddress;
    found = true;
    break;
  }
}
if (!found) {
  data.push({ name: facetName, contractName: `${facetName}.sol`, address: facetAddress });
}

fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
console.log(`Updated ${facetName} to ${facetAddress} in ${filePath}`);
