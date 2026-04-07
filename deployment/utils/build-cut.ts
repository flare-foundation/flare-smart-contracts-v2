#!/usr/bin/env node
import Web3, { AbiFunctionFragment } from "web3";
import fs from "fs";
import {
  selectorsFromLoupeData,
  prepareDiamondCut,
  toSelector,
  parseArgs,
  loadAbi,
  readFacetsFile,
  readLoupeFile,
} from "./prep-cut";

const web3 = new Web3();

interface CutConfig {
  diamond: string;
  facets: string[];
  deleteAllOldMethods?: boolean;
  deleteSelectorSigs?: string[];
  init?: {
    contract: string;
    method: string;
    args: unknown[];
    calldata?: string;
  };
  execute?: boolean;
}

function main() {
  const a = parseArgs(process.argv);
  const diamond = a["diamond"];
  const facetsFile = a["facets-file"];
  const loupeFile = a["loupe-file"];
  const configPath = a["config"];

  if (!diamond || !facetsFile || !loupeFile || !configPath) {
    console.error("Usage: build-cut --diamond <addr> --facets-file <path> --loupe-file <path> --config <path>");
    process.exit(1);
  }

  const loupeFacets = readLoupeFile(loupeFile);
  const deployed = selectorsFromLoupeData(loupeFacets);

  const planFacets = readFacetsFile(facetsFile);
  const facets = planFacets.map((f) => {
    const abi = loadAbi(f.contractName);
    const functions = abi.filter((abi) => abi.type === "function") as Array<AbiFunctionFragment>;
    const selectors: string[] = [];
    for (const fn of functions) {
      selectors.push(toSelector(fn));
    }
    return { address: f.address, selectors };
  });

  const rawCfg = fs.readFileSync(configPath, "utf8");
  const cfg: CutConfig = JSON.parse(rawCfg) as CutConfig;
  const deleteAllOldMethods: boolean = !!cfg.deleteAllOldMethods;
  const deleteSelectorSigs: string[] = Array.isArray(cfg.deleteSelectorSigs) ? cfg.deleteSelectorSigs.map(String) : [];
  // init: read raw calldata if provided; otherwise build from contract+method+args
  let initAddress = "0x0000000000000000000000000000000000000000";
  let initCalldata = "0x";
  if (cfg.init) {
    initAddress = a["init-address"];
    const init = cfg.init;
    if (typeof init.calldata === "string" && init.calldata.length > 0 && init.calldata !== "0x") {
      initCalldata = init.calldata;
    } else if (init.contract && init.method) {
      const initContractName: string = String(init.contract);
      const method: string = String(init.method);
      const argsArr: unknown[] = Array.isArray(init.args) ? init.args : [];
      // build calldata using ABI from artifacts
      const abi = loadAbi(initContractName);
      const fn = abi
        .filter(
          (i): i is AbiFunctionFragment => i.type === "function" && typeof (i as AbiFunctionFragment).name === "string"
        )
        .find((i) => i.name === method);
      if (!fn) {
        throw new Error(`Init method ${method} not found in ${initContractName} ABI`);
      }
      const inputsForEncoding: AbiFunctionFragment["inputs"] = (fn.inputs || []).map((inp, idx) => ({
        name: inp.name || `arg${idx}`,
        type: inp.type,
      }));
      initCalldata = web3.eth.abi.encodeFunctionCall(
        { name: method, type: "function", inputs: inputsForEncoding },
        argsArr
      );
    }
  }

  const result = prepareDiamondCut(
    { diamond, facets, deleteAllOldMethods, deleteMethods: deleteSelectorSigs },
    deployed
  );

  // encode with web3 to avoid cast signature parsing issues
  const facetCutType = {
    type: "tuple[]",
    components: [
      { name: "facetAddress", type: "address" },
      { name: "action", type: "uint8" },
      { name: "functionSelectors", type: "bytes4[]" },
    ],
  } as const;

  const encoded = web3.eth.abi.encodeParameters(
    [facetCutType, "address", "bytes"],
    [
      result.cuts.map((c) => ({
        facetAddress: c.facetAddress,
        action: c.action,
        functionSelectors: c.functionSelectors,
      })),
      initAddress,
      initCalldata,
    ]
  );

  process.stdout.write(encoded);
}

main();
