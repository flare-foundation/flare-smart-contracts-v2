#!/usr/bin/env node
import fs from "fs";
import Web3 from "web3";
import { AbiItem } from "web3-utils";
import { isFunctionFragment, parseArgs } from "./prep-cut";

function resultToTuple(value: unknown): unknown {
  if (typeof value === "object" && value !== null) {
    if (typeof (value as { isBN?: () => boolean }).isBN === "function" && (value as { isBN: () => boolean }).isBN()) {
      return (value as { ltn: (n: number) => boolean; toString: () => string }).ltn(1e9)
        ? Number(value)
        : (value as { toString: () => string }).toString();
    }
    if (Array.isArray(value)) {
      return value.map(resultToTuple);
    }
    const tuple = [];
    for (let i = 0; i in value; i++) {
      tuple.push(resultToTuple((value as Record<number, unknown>)[i]));
    }
    return tuple;
  }
  if (typeof value === "bigint") return value.toString();
  return value;
}

const args = parseArgs(process.argv);
const encodedPath = args["encoded-path"];
const outputPath = args["output-path"];
if (!encodedPath || !outputPath) {
  console.error("Usage: format-cut --encoded-path <encoded-path> --output-path <output-path>");
  process.exit(1);
}

const encoded = "0x" + fs.readFileSync(encodedPath).toString("hex");
const web3 = new Web3();
const facetCutType = {
  type: "tuple[]",
  components: [
    { name: "facetAddress", type: "address" },
    { name: "action", type: "uint8" },
    { name: "functionSelectors", type: "bytes4[]" },
  ],
} as const;

const diamondCutArtifact = JSON.parse(
  fs.readFileSync("artifacts-forge/DiamondGovernanceFacet.sol/DiamondGovernanceFacet.json", "utf8")
) as { abi: AbiItem[] };
const diamondCutAbi = diamondCutArtifact.abi;

const diamondCutFn = diamondCutAbi.find(isFunctionFragment);

if (diamondCutFn) {
  const decoded = web3.eth.abi.decodeParameters([facetCutType, "address", "bytes"], encoded);
  const tupleOut = resultToTuple([decoded[0], decoded[1], decoded[2]]);
  fs.writeFileSync(outputPath, JSON.stringify(tupleOut, null, 2), "utf8");
}
