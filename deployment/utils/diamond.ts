import { AbiItem } from "web3";
import { toSelector } from "./prep-cut";

export enum FacetCutAction {
  Add = 0,
  Replace = 1,
  Remove = 2,
}

export type DiamondCut = {
  action: FacetCutAction;
  facetAddress: string;
  functionSelectors: string[];
};

export type DiamondFacet = {
  facetAddress: string;
  functionSelectors: string[];
};

export type SelectorFilter = (selector: string, facet: string) => boolean;

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export class DiamondSelectors {
  constructor(
    public selectorMap: Map<string, string> = new Map() // selector => facet address
  ) {}

  get selectors() {
    return Array.from(this.selectorMap.keys());
  }

  static fromABI(contract: { address: string; abi: AbiItem[] }, methodFilter?: (abi: AbiItem) => boolean) {
    const functions = contract.abi.filter((abi) => abi.type === "function" && (!methodFilter || methodFilter(abi)));
    const selectorMap = new Map(functions.map((fn) => [toSelector(fn), contract.address]));
    return new DiamondSelectors(selectorMap);
  }

  static async fromLoupe(loupe: { facets: () => Promise<DiamondFacet[]> }) {
    const selectorMap: Map<string, string> = new Map();
    const facets = await loupe.facets();
    for (const facet of facets) {
      for (const selector of facet.functionSelectors) {
        selectorMap.set(selector, facet.facetAddress);
      }
    }
    return new DiamondSelectors(selectorMap);
  }

  has(selector: string) {
    return this.selectorMap.has(selector);
  }

  facets() {
    const facets = new Map<string, string[]>();
    for (const [selector, facet] of this.selectorMap) {
      if (!facets.has(facet)) facets.set(facet, []);
      facets.get(facet)!.push(selector);
    }
    return facets;
  }

  filter(predicate: SelectorFilter) {
    const selectorMap: Map<string, string> = new Map();
    for (const [selector, facet] of this.selectorMap) {
      if (predicate(selector, facet)) {
        selectorMap.set(selector, facet);
      }
    }
    return new DiamondSelectors(selectorMap);
  }

  merge(other: DiamondSelectors) {
    const selectorMap = new Map(this.selectorMap);
    for (const [selector, facet] of other.selectorMap) {
      if (selectorMap.has(selector) && selectorMap.get(selector) !== facet) {
        throw new Error(`Conflict in merge for selector ${selector}, facets ${selectorMap.get(selector)} and ${facet}`);
      }
      selectorMap.set(selector, facet);
    }
    return new DiamondSelectors(selectorMap);
  }

  restrict(functions: DiamondSelectors | Iterable<string | AbiItem>) {
    const keepSelectors = functions instanceof DiamondSelectors ? functions.selectorMap : toSelectorSet(functions);
    return this.filter((sel) => keepSelectors.has(sel));
  }

  remove(functions: DiamondSelectors | Iterable<string | AbiItem>) {
    const removeSelectors = functions instanceof DiamondSelectors ? functions.selectorMap : toSelectorSet(functions);
    return this.filter((sel) => !removeSelectors.has(sel));
  }

  removeExisting(existing: DiamondSelectors) {
    return this.filter((sel) => this.selectorMap.get(sel) !== existing.selectorMap.get(sel));
  }

  // the delete selectors require facet address to be zero
  toDeleteSelectors() {
    const selectorMap = new Map<string, string>();
    for (const sig of this.selectorMap.keys()) {
      selectorMap.set(sig, ZERO_ADDRESS);
    }
    return new DiamondSelectors(selectorMap);
  }

  createCuts(addedOrUpdated: DiamondSelectors, deleted?: DiamondSelectors) {
    const addSelectors = addedOrUpdated.remove(this);
    const replaceSelectors = addedOrUpdated.restrict(this);
    const removeSelectors = deleted ? deleted.remove(addedOrUpdated) : new DiamondSelectors();
    const result: DiamondCut[] = [];
    for (const [facetAddress, facetSelectors] of addSelectors.facets()) {
      result.push({ action: FacetCutAction.Add, facetAddress: facetAddress, functionSelectors: facetSelectors });
    }
    for (const [facetAddress, facetSelectors] of replaceSelectors.facets()) {
      result.push({ action: FacetCutAction.Replace, facetAddress: facetAddress, functionSelectors: facetSelectors });
    }
    for (const [facetAddress, facetSelectors] of removeSelectors.facets()) {
      result.push({ action: FacetCutAction.Remove, facetAddress: facetAddress, functionSelectors: facetSelectors });
    }
    return result;
  }
}

export function toSelectorSet(items: Iterable<string | AbiItem>) {
  const result = new Set<string>();
  for (const item of items) {
    result.add(toSelector(item));
  }
  return result;
}
