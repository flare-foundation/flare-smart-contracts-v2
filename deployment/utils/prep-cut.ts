import fs from "fs";
import Web3, { AbiFunctionFragment, AbiItem } from "web3";
import { DiamondSelectors, type DiamondCut } from "./diamond";

const web3 = new Web3();

export interface FacetInput {
  address: string;
  selectors: string[];
}

export interface InitInput {
  address: string;
  calldata: string;
}

export interface CutConfigInput {
  diamond: string;
  facets: FacetInput[];
  deleteAllOldMethods?: boolean;
  deleteMethods?: string[];
  init?: InitInput;
}

export interface PreparedDiamondCutResult {
  cuts: DiamondCut[];
  initAddress: string;
  initCalldata: string;
  addedSelectors?: string[];
  replacedSelectors?: string[];
  removedSelectors?: string[];
}

export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export function prepareDiamondCut(
  config: CutConfigInput,
  deployedSelectors: DiamondSelectors
): PreparedDiamondCutResult {
  // Build a DiamondSelectors object from the facets in the config
  const newSelectorsPossiblyExisting = createNewSelectors(config.facets);
  // Remove any selectors that already exist in the deployed diamond with the same facet address
  const newSelectors = newSelectorsPossiblyExisting.removeExisting(deployedSelectors);
  const deletedSelectors = config.deleteAllOldMethods
    ? deployedSelectors.remove(newSelectorsPossiblyExisting).toDeleteSelectors()
    : createDeletedSelectors(deployedSelectors, config.deleteMethods ?? []);
  const cuts = deployedSelectors.createCuts(newSelectors, deletedSelectors);
  const initAddress = config.init?.address ?? ZERO_ADDRESS;
  const initCalldata = config.init?.calldata ?? "0x";
  return { cuts, initAddress, initCalldata };
}

function createNewSelectors(facets: FacetInput[]): DiamondSelectors {
  let selectors = new DiamondSelectors();
  for (const facet of facets) {
    const selectorMap = new Map<string, string>();
    for (const s of facet.selectors) {
      selectorMap.set(s, facet.address);
    }
    selectors = selectors.merge(new DiamondSelectors(selectorMap));
  }
  return selectors;
}

function createDeletedSelectors(deployedSelectors: DiamondSelectors, deleteMethods: string[]): DiamondSelectors {
  const selectorMap: Map<string, string> = new Map();
  for (const methodSigOrSelector of deleteMethods) {
    const selector = toSelector(methodSigOrSelector);
    const facet = deployedSelectors.selectorMap.get(selector);
    if (facet == null) throw new Error(`Unknown method to delete '${methodSigOrSelector}'`);
    selectorMap.set(selector, ZERO_ADDRESS); // diamondCut operation requires 0 facet address for deleted methods
  }
  return new DiamondSelectors(selectorMap);
}

export function selectorsFromLoupeData(
  facets: Array<{ facetAddress: string; functionSelectors: string[] }>
): DiamondSelectors {
  const m = new Map<string, string>();
  for (const f of facets) {
    for (const sel of f.functionSelectors) {
      m.set(sel, f.facetAddress);
    }
  }
  return new DiamondSelectors(m);
}

// narrow to function fragments before encoding; avoids passing constructors/events
export function isFunctionFragment(item: unknown): item is AbiFunctionFragment {
  return (
    typeof item === "object" &&
    item !== null &&
    "type" in item &&
    (item as { type?: string }).type === "function" &&
    "name" in item &&
    typeof (item as { name?: unknown }).name === "string"
  );
}

export function toSelector(item: string | AbiItem) {
  if (typeof item === "string" && /^0x[0-9a-f]{8}$/i.test(item)) return item;
  if (isFunctionFragment(item)) {
    return web3.eth.abi.encodeFunctionSignature(item);
  }
  throw new Error("toSelector: expected a selector string or a function ABI fragment");
}

export function loadAbi(contractName: string): AbiItem[] {
  const raw = fs.readFileSync(`artifacts-forge/${contractName}.sol/${contractName}.json`, "utf8");
  const parsed = JSON.parse(raw) as { abi: AbiItem[] };
  return parsed.abi;
}

export function parseArgs(argv: string[]) {
  const args: Record<string, string> = {};
  for (let i = 2; i < argv.length; i += 2) {
    args[argv[i].replace(/^--/, "")] = argv[i + 1];
  }
  return args;
}

export function readFacetsFile(p: string) {
  // line format: address|contractName
  const lines = fs.readFileSync(p, "utf8").split(/\r?\n/).filter(Boolean);
  return lines.map((l) => {
    const parts = l.split("|");
    if (parts.length !== 2) {
      throw new Error(`Invalid facets line (expected address|contractName): ${l}`);
    }
    const [address, contractName] = parts;
    return { address, contractName };
  });
}

export function readLoupeFile(p: string) {
  // line format: facetAddress|sel1,sel2,sel3
  const lines = fs.readFileSync(p, "utf8").split(/\r?\n/).filter(Boolean);
  return lines.map((l) => {
    const [facetAddress, selectors] = l.split("|");
    const functionSelectors = (selectors ? selectors.split(",") : []).filter(Boolean);
    return { facetAddress, functionSelectors };
  });
}
