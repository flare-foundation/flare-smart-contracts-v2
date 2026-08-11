#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, globSync, readFileSync } from "node:fs";
import { basename } from "node:path";
import Web3 from "web3";
import { AbiItem, AbiInput } from "web3-utils";
import { isFunctionFragment, loadAbi, toSelector } from "../utils/prep-cut";

// Standalone, cross-platform "check diamond cut plan" tool for the FlareTeeManager diamond.
// Pure Node/tsx: NO forge, NO vm.ffi, NO broadcast. It reads a cut config + the deployed-address
// registry, compares on-chain facet bytecode against the locally compiled artifact, and prints the
// cut plan (ADD/REPLACE/REUSE/REMOVE per facet + stale selectors). Run `forge build` first so the
// artifacts under artifacts-forge/ are up to date.

interface DeployedContract {
  name: string;
  contractName: string;
  address: string;
}

interface CutConfig {
  diamond: string;
  facets?: string[];
  deleteSelectorSigs?: string[];
  deleteAllOldMethods?: boolean;
}

interface BytecodeOutput {
  object: string;
}

interface LoupeFacet {
  facetAddress: string;
  functionSelectors: string[];
}

interface RepoSelectorInfo {
  contractName: string;
  signature: string;
}

type FacetAction = "ADD" | "REPLACE" | "REUSE" | "REMOVE";

interface FacetPlan {
  name: string;
  address?: string;
  action: FacetAction;
  reason: string;
  currentHash?: string;
  deployedHash?: string;
}

interface StaleSelector {
  selector: string;
  facetAddress: string;
  facetName?: string;
  deployedFacetAddress?: string;
  signature?: string;
  // Set when the selector still exists on another facet in the repo (moved, not removed).
  movedTo?: string;
}

const ZERO_CODE = "0x";
const DIAMOND_CONTRACT = "FlareTeeManager";
const SUPPORTED_BASE_NETWORKS = ["coston2", "coston", "flare", "songbird", "scdev"];
// DiamondLoupe.facets() output shape — a tuple[] of (facetAddress, functionSelectors).
const FACETS_ABI: AbiInput = {
  name: "facets",
  type: "tuple[]",
  components: [
    { name: "facetAddress", type: "address" },
    { name: "functionSelectors", type: "bytes4[]" },
  ],
};

async function main() {
  const args = process.argv.slice(2);
  const positional = args.filter((arg) => !arg.startsWith("--"));
  const network = positional[0];
  const cutFileName = positional[1];

  if (!network || args.includes("--help") || args.includes("-h")) {
    printUsageAndExit();
  }
  validateNetwork(network);

  const deployedContracts = loadDeployedContracts(network);
  const cutConfig = cutFileName ? loadCutConfig(network, cutFileName) : undefined;
  const diamond = cutConfig?.diamond ?? findDiamondAddress(deployedContracts);
  const rpcUrl = resolveRpcUrl(network);
  const web3 = new Web3(rpcUrl);

  const deployedFacets = deployedContracts.filter((contract) => contract.name.endsWith("Facet"));
  const deployedByName = new Map(deployedFacets.map((contract) => [contract.name, contract]));
  const cutFacetNames = cutConfig?.facets ?? [];

  console.log(`Diamond cut plan for ${network}`);
  console.log(
    cutFileName
      ? `Cut file: deployment/cuts/${network}/${normalizeCutFileName(cutFileName)}`
      : "Cut file: none (scope: all deployed facets; ADD detection needs a cut file)"
  );
  console.log(`Diamond: ${diamond}`);
  const rpcForDisplay = rpcUrl.includes("?") ? rpcUrl.split("?")[0] : rpcUrl;
  console.log(`RPC: ${rpcForDisplay}`);
  console.log("Bytecode source: artifacts-forge/ (run `forge build` first if stale)");
  console.log("");

  const facetPlans = await buildFacetPlans(web3, deployedFacets, deployedByName, cutFacetNames);
  printFacetPlan(facetPlans);

  const staleSelectors = await buildStaleSelectors(
    web3,
    network,
    deployedContracts,
    deployedFacets,
    cutFacetNames,
    diamond
  );
  const deleteSelectors = new Set(
    (cutConfig?.deleteSelectorSigs ?? []).map((selectorOrSignature) => toSelector(selectorOrSignature).toLowerCase())
  );
  printSelectorPlan(staleSelectors, deleteSelectors);

  printSummary(facetPlans, staleSelectors, deleteSelectors);

  if (cutConfig?.deleteAllOldMethods) {
    console.log("");
    console.log("Note: this cut sets deleteAllOldMethods=true — the execute path will remove ALL deployed selectors");
    console.log("not re-added by the listed facets, regardless of deleteSelectorSigs.");
  }
}

// --- Section 1: which facet contracts need (re)deploying ---

async function buildFacetPlans(
  web3: Web3,
  deployedFacets: DeployedContract[],
  deployedByName: Map<string, DeployedContract>,
  cutFacetNames: string[]
): Promise<FacetPlan[]> {
  const repoFacetSources = buildRepoFacetSourceSet();
  const plans: FacetPlan[] = [];

  for (const facet of deployedFacets) {
    const artifactPath = artifactPathFor(facet.name);
    // Source presence — not artifact presence — is the source of truth for "still exists".
    // A stale artifact (forge does not prune artifacts of deleted sources) must not mask a removal.
    if (!repoFacetSources.has(facet.name)) {
      plans.push({
        name: facet.name,
        address: facet.address,
        action: "REMOVE",
        reason: existsSync(artifactPath)
          ? "removed from source (stale artifact present — run `forge clean`); its live selectors are listed below"
          : "removed from source; its live selectors are listed below",
      });
      continue;
    }

    if (!existsSync(artifactPath)) {
      plans.push({
        name: facet.name,
        address: facet.address,
        action: "REPLACE",
        reason: "source present but artifact missing — run `forge build` (cannot compare; treating as redeploy)",
      });
      continue;
    }

    const deployedCodeHex = await web3.eth.getCode(facet.address);
    if (deployedCodeHex === ZERO_CODE) {
      plans.push({
        name: facet.name,
        address: facet.address,
        action: "ADD",
        reason: "recorded address has no on-chain code; would deploy fresh",
      });
      continue;
    }

    const deployedCode = hexToBytes(deployedCodeHex);
    const currentCode = loadDeployedCode(facet.name);
    plans.push(compareFacet(facet.name, facet.address, deployedCode, currentCode));
  }

  for (const name of cutFacetNames) {
    if (deployedByName.has(name)) {
      continue;
    }
    plans.push({
      name,
      action: "ADD",
      reason: existsSync(artifactPathFor(name))
        ? "in cut, not in deploys; would deploy as new"
        : `in cut, not in deploys, and missing artifact ${artifactPathFor(name)}`,
    });
  }

  return plans;
}

// Mirrors ExecuteTeeManagerDiamondCut._deployedCodeMatches: the execute path reuses a facet when the
// logic bytecode matches, i.e. both sides compared with the trailing CBOR metadata block stripped.
// The metadata ipfs hash shifts with the build environment, so historical deploys are not always
// byte-reproducible; metadata-only drift must not force redeploys.
function compareFacet(facetName: string, address: string, deployedCode: Buffer, currentCode: Buffer): FacetPlan {
  const deployedHash = shortHash(deployedCode);
  const currentHash = shortHash(currentCode);

  if (deployedCode.equals(currentCode)) {
    return {
      name: facetName,
      address,
      action: "REUSE",
      reason: "full deployed bytecode matches",
      currentHash,
      deployedHash,
    };
  }

  const onlyMetadataDiffers = stripMetadata(deployedCode).equals(stripMetadata(currentCode));
  if (onlyMetadataDiffers) {
    return {
      name: facetName,
      address,
      action: "REUSE",
      reason: "logic bytecode matches; only the trailing Solidity metadata differs",
      currentHash,
      deployedHash,
    };
  }

  return {
    name: facetName,
    address,
    action: "REPLACE",
    reason: "functional runtime bytecode differs; would redeploy",
    currentHash,
    deployedHash,
  };
}

function loadDeployedCode(contractName: string): Buffer {
  const artifact = loadArtifact(contractName);
  if (isBytecodeOutput(artifact.deployedBytecode)) {
    return hexToBytes(artifact.deployedBytecode.object);
  }
  throw new Error(`Missing deployed bytecode object for ${contractName}`);
}

function isBytecodeOutput(value: unknown): value is BytecodeOutput {
  return (
    typeof value === "object" &&
    value !== null &&
    "object" in value &&
    typeof (value as { object?: unknown }).object === "string"
  );
}

function loadArtifact(contractName: string): { bytecode?: unknown; deployedBytecode?: unknown } {
  return JSON.parse(readFileSync(artifactPathFor(contractName), "utf8")) as {
    bytecode?: unknown;
    deployedBytecode?: unknown;
  };
}

function stripMetadata(code: Buffer): Buffer {
  const suffixLength = metadataSuffixLength(code);
  return code.subarray(0, code.length - suffixLength);
}

function metadataSuffixLength(code: Buffer): number {
  if (code.length < 2) {
    return 0;
  }
  const metadataLength = ((code[code.length - 2] ?? 0) << 8) | (code[code.length - 1] ?? 0);
  if (metadataLength === 0 || metadataLength + 2 > code.length) {
    return 0;
  }
  const metadataStart = code.length - metadataLength - 2;
  if ((code[metadataStart] ?? 0) >> 5 !== 5) {
    return 0;
  }
  return metadataLength + 2;
}

function hexToBytes(hex: string): Buffer {
  const normalized = hex.startsWith("0x") ? hex.slice(2) : hex;
  return Buffer.from(normalized, "hex");
}

function shortHash(data: Buffer): string {
  return createHash("sha256").update(data).digest("hex").slice(0, 16);
}

// --- Section 2: which live selectors are orphaned (deletion candidates) ---

async function buildStaleSelectors(
  web3: Web3,
  network: string,
  deployedContracts: DeployedContract[],
  deployedFacets: DeployedContract[],
  cutFacetNames: string[],
  diamond: string
): Promise<StaleSelector[]> {
  // Selectors kept after the cut come from every facet that will remain on the diamond:
  // the deployed facets that still exist in source, plus any new facets listed in the cut.
  // Requiring source presence (not just an artifact) stops a removed facet's stale-artifact
  // selectors from being treated as kept; including the cut's new facets stops moved selectors
  // from being flagged as stale.
  const repoFacetSources = buildRepoFacetSourceSet();
  const keptFacetNames = uniqueStrings([...deployedFacets.map((contract) => contract.name), ...cutFacetNames]).filter(
    (name) => repoFacetSources.has(name) && existsSync(artifactPathFor(name))
  );

  const repoSelectors = buildRepoSelectorMap(keptFacetNames);
  const facetNamesByAddress = buildFacetNamesByAddress(network, deployedContracts);
  const deployedFacetAddressesByName = buildDeployedFacetAddressesByName(deployedContracts);
  const loupeFacets = await fetchLoupeFacets(web3, diamond);

  const stale = enrichStaleSelectors(
    findStaleSelectors(loupeFacets, repoSelectors),
    facetNamesByAddress,
    deployedFacetAddressesByName
  );

  // Classify each stale selector: MOVED (still exists on some facet in the repo, just not in
  // this cut's scope) vs genuinely REMOVED (gone from all source). A moved selector must NOT be
  // added to deleteSelectorSigs — deleting it would drop a live function; its facet belongs in the cut.
  const allRepoSelectors = buildAllRepoFacetSelectorMap();
  for (const selector of stale) {
    const moved = allRepoSelectors.get(selector.selector.toLowerCase());
    if (moved) {
      selector.movedTo = moved.contractName;
      if (!selector.signature) {
        selector.signature = moved.signature;
      }
    }
  }
  return stale;
}

function buildRepoSelectorMap(facetNames: string[]): Map<string, RepoSelectorInfo> {
  const selectors = new Map<string, RepoSelectorInfo>();
  for (const facetName of facetNames) {
    const functions = loadAbi(facetName).filter(isFunctionFragment);
    for (const fn of functions) {
      selectors.set(toSelector(fn).toLowerCase(), {
        contractName: facetName,
        signature: functionSignature(fn),
      });
    }
  }
  return selectors;
}

// Names of every concrete facet implementation currently in the repo
// (contracts/**/facets/*Facet.sol, interfaces excluded). Source presence — not artifact presence —
// is the source of truth for whether a facet still exists; a stale artifact for a deleted facet
// (forge does not prune artifacts of removed sources) must not mask its removal.
function buildRepoFacetSourceSet(): Set<string> {
  const names = new Set<string>();
  for (const sourcePath of globSync("contracts/**/facets/*Facet.sol")) {
    if (/interface/i.test(sourcePath)) {
      continue;
    }
    names.add(basename(sourcePath).replace(/\.sol$/, ""));
  }
  return names;
}

// Selectors of every concrete facet implementation currently in the repo, regardless of deploy/cut
// scope. Used to tell a MOVED selector (still defined on some facet) apart from a genuinely REMOVED one.
function buildAllRepoFacetSelectorMap(): Map<string, RepoSelectorInfo> {
  const selectors = new Map<string, RepoSelectorInfo>();
  for (const facetName of buildRepoFacetSourceSet()) {
    if (!existsSync(artifactPathFor(facetName))) {
      continue;
    }
    for (const fn of loadAbi(facetName).filter(isFunctionFragment)) {
      const selector = toSelector(fn).toLowerCase();
      if (!selectors.has(selector)) {
        selectors.set(selector, { contractName: facetName, signature: functionSignature(fn) });
      }
    }
  }
  return selectors;
}

async function fetchLoupeFacets(web3: Web3, diamond: string): Promise<LoupeFacet[]> {
  const data = web3.eth.abi.encodeFunctionSignature("facets()");
  const encoded = await web3.eth.call({ to: diamond, data });
  const decoded = web3.eth.abi.decodeParameters([FACETS_ABI], encoded);
  const raw = (decoded as Record<string, unknown>)["0"] ?? (decoded as Record<string, unknown>)["facets"];
  if (!Array.isArray(raw)) {
    throw new Error("Could not decode DiamondLoupe facets()");
  }

  return raw.map((item) => {
    if (
      typeof item === "object" &&
      item !== null &&
      typeof (item as { facetAddress?: unknown }).facetAddress === "string" &&
      Array.isArray((item as { functionSelectors?: unknown }).functionSelectors)
    ) {
      const functionSelectors = (item as { functionSelectors: unknown[] }).functionSelectors.map((selector) =>
        String(selector).toLowerCase()
      );
      return {
        facetAddress: (item as { facetAddress: string }).facetAddress,
        functionSelectors,
      };
    }
    throw new Error("Invalid DiamondLoupe facet item");
  });
}

function findStaleSelectors(loupeFacets: LoupeFacet[], repoSelectors: Map<string, RepoSelectorInfo>) {
  const staleSelectors: Array<{ selector: string; facetAddress: string }> = [];
  for (const facet of loupeFacets) {
    for (const selector of facet.functionSelectors) {
      if (!repoSelectors.has(selector)) {
        staleSelectors.push({ selector, facetAddress: facet.facetAddress });
      }
    }
  }
  return staleSelectors.sort((a, b) => a.selector.localeCompare(b.selector));
}

function enrichStaleSelectors(
  staleSelectors: Array<{ selector: string; facetAddress: string }>,
  facetNamesByAddress: Map<string, string>,
  deployedFacetAddressesByName: Map<string, string>
): StaleSelector[] {
  const enriched = staleSelectors.map((stale): StaleSelector => {
    const result: StaleSelector = { ...stale };
    const facetName = facetNamesByAddress.get(stale.facetAddress.toLowerCase());
    if (facetName) {
      result.facetName = facetName;
      const deployedFacetAddress = deployedFacetAddressesByName.get(facetName);
      if (deployedFacetAddress) {
        result.deployedFacetAddress = deployedFacetAddress;
      }
    }
    return result;
  });
  const unresolved = enriched.filter((stale) => stale.signature === undefined);
  if (unresolved.length === 0) {
    return enriched;
  }

  const historicalHints = buildHistoricalSelectorHints(unresolved);
  return enriched.map((stale): StaleSelector => {
    if (stale.signature) {
      return stale;
    }
    const signature = historicalHints.get(stale.selector);
    return signature ? { ...stale, signature } : stale;
  });
}

function buildDeployedFacetAddressesByName(deployedContracts: DeployedContract[]): Map<string, string> {
  const addresses = new Map<string, string>();
  for (const contract of deployedContracts) {
    if (contract.name.endsWith("Facet")) {
      addresses.set(contract.name, contract.address);
    }
  }
  return addresses;
}

function buildFacetNamesByAddress(network: string, deployedContracts: DeployedContract[]): Map<string, string> {
  const names = new Map<string, string>();
  for (const contract of deployedContracts) {
    names.set(contract.address.toLowerCase(), contract.name);
  }

  const deployPath = `deployment/deploys/${network}.json`;
  for (const commit of gitLines(["log", "--all", "--format=%H", "--", deployPath])) {
    const deployed = readHistoricalDeployedContracts(commit, deployPath);
    for (const contract of deployed) {
      if (!names.has(contract.address.toLowerCase())) {
        names.set(contract.address.toLowerCase(), contract.name);
      }
    }
  }
  return names;
}

function readHistoricalDeployedContracts(commit: string, deployPath: string): DeployedContract[] {
  const raw = gitOutput(["show", `${commit}:${deployPath}`]);
  if (!raw) {
    return [];
  }
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed.filter(isDeployedContract);
  } catch {
    return [];
  }
}

function isDeployedContract(item: unknown): item is DeployedContract {
  return (
    typeof item === "object" &&
    item !== null &&
    typeof (item as { name?: unknown }).name === "string" &&
    typeof (item as { contractName?: unknown }).contractName === "string" &&
    typeof (item as { address?: unknown }).address === "string"
  );
}

function buildHistoricalSelectorHints(staleSelectors: StaleSelector[]): Map<string, string> {
  const selectorsByFacet = new Map<string, Set<string>>();
  for (const stale of staleSelectors) {
    if (!stale.facetName) {
      continue;
    }
    const selectors = selectorsByFacet.get(stale.facetName) ?? new Set<string>();
    selectors.add(stale.selector);
    selectorsByFacet.set(stale.facetName, selectors);
  }

  const hints = new Map<string, string>();
  for (const [facetName, targetSelectors] of selectorsByFacet) {
    for (const signature of historicalFunctionSignatures(facetName)) {
      const selector = encodeSignature(signature);
      if (selector && targetSelectors.has(selector) && !hints.has(selector)) {
        hints.set(selector, signature);
      }
    }
  }
  return hints;
}

function encodeSignature(signature: string): string | undefined {
  try {
    return new Web3().eth.abi.encodeFunctionSignature(signature).toLowerCase();
  } catch {
    return undefined;
  }
}

function historicalFunctionSignatures(contractName: string): Set<string> {
  const signatures = new Set<string>();
  const pathspec = `:(glob)contracts/**/${contractName}.sol`;
  const commits = gitLines(["log", "--all", "--format=%H", "--", pathspec]);

  for (const commit of commits) {
    for (const path of historicalContractPaths(commit, contractName)) {
      const source = gitOutput(["show", `${commit}:${path}`]);
      if (!source) {
        continue;
      }
      for (const signature of extractFunctionSignatures(source)) {
        signatures.add(signature);
      }
    }
  }
  return signatures;
}

function historicalContractPaths(commit: string, contractName: string): string[] {
  return gitLines(["ls-tree", "-r", "--name-only", commit, "--", "contracts"]).filter(
    (path) => basename(path) === `${contractName}.sol`
  );
}

function extractFunctionSignatures(source: string): string[] {
  const cleaned = stripSolidityComments(source);
  const signatures: string[] = [];
  const functionPattern = /\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
  let match: RegExpExecArray | null;
  while ((match = functionPattern.exec(cleaned)) !== null) {
    const functionName = match[1];
    const openParen = functionPattern.lastIndex - 1;
    const closeParen = findClosingParen(cleaned, openParen);
    if (!functionName || closeParen < 0) {
      continue;
    }
    const inputTypes = parseFunctionInputTypes(cleaned.slice(openParen + 1, closeParen));
    if (inputTypes) {
      signatures.push(`${functionName}(${inputTypes.join(",")})`);
    }
    functionPattern.lastIndex = closeParen + 1;
  }
  return signatures;
}

function stripSolidityComments(source: string): string {
  return source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
}

function findClosingParen(source: string, openParen: number): number {
  let depth = 0;
  for (let i = openParen; i < source.length; i++) {
    const char = source[i];
    if (char === "(") {
      depth++;
    } else if (char === ")") {
      depth--;
      if (depth === 0) {
        return i;
      }
    }
  }
  return -1;
}

function parseFunctionInputTypes(params: string): string[] | undefined {
  const chunks = splitTopLevel(params);
  if (!chunks) {
    return undefined;
  }
  const types: string[] = [];
  for (const chunk of chunks) {
    const type = parseSolidityParameterType(chunk);
    if (!type) {
      return undefined;
    }
    types.push(type);
  }
  return types;
}

function parseSolidityParameterType(param: string): string | undefined {
  // Best-effort historical source parsing: struct/interface aliases would require
  // reconstructing old imports and expanding structs to tuple selector form.
  const cleaned = param
    .replace(/\b(?:calldata|memory|storage)\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!cleaned) {
    return undefined;
  }

  const tokens = cleaned.split(" ");
  let type = tokens[0];
  if (!type) {
    return undefined;
  }
  if (type === "address" && tokens[1]?.startsWith("payable")) {
    type = `address${tokens[1].slice("payable".length)}`;
  }

  return canonicalSourceType(type);
}

function canonicalSourceType(type: string): string | undefined {
  let suffix = "";
  let baseType = type;
  while (baseType.endsWith("]")) {
    const arrayMatch = /^(.*)(\[(?:[0-9]+)?\])$/.exec(baseType);
    if (!arrayMatch?.[1] || !arrayMatch[2]) {
      return undefined;
    }
    baseType = arrayMatch[1];
    suffix = `${arrayMatch[2]}${suffix}`;
  }

  if (baseType === "uint") {
    return `uint256${suffix}`;
  }
  if (baseType === "int") {
    return `int256${suffix}`;
  }
  if (isCanonicalSourceBaseType(baseType)) {
    return `${baseType}${suffix}`;
  }
  return undefined;
}

function isCanonicalSourceBaseType(type: string): boolean {
  if (["address", "bool", "string", "bytes", "function"].includes(type)) {
    return true;
  }
  if (/^bytes(?:[1-9]|[1-2][0-9]|3[0-2])$/.test(type)) {
    return true;
  }
  if (/^(?:u?int)(?:[1-9][0-9]*)$/.test(type)) {
    const size = Number(type.replace(/u?int/, ""));
    return size >= 8 && size <= 256 && size % 8 === 0;
  }
  return false;
}

function splitTopLevel(value: string): string[] | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return [];
  }

  const result: string[] = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < value.length; i++) {
    const char = value[i];
    if (char === "(") {
      depth++;
    } else if (char === ")") {
      if (depth === 0) {
        return undefined;
      }
      depth--;
    } else if (char === "," && depth === 0) {
      result.push(value.slice(start, i).trim());
      start = i + 1;
    }
  }

  if (depth !== 0) {
    return undefined;
  }
  result.push(value.slice(start).trim());
  return result.every((item) => item.length > 0) ? result : undefined;
}

function gitLines(args: string[]): string[] {
  return gitOutput(args)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function gitOutput(args: string[]): string {
  try {
    return execFileSync("git", args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
  } catch {
    return "";
  }
}

function functionSignature(fn: AbiItem): string {
  const inputTypes = (fn.inputs ?? []).map((input) => input.type).join(",");
  return `${fn.name ?? ""}(${inputTypes})`;
}

// --- shared input loading ---

function validateNetwork(network: string) {
  const baseNetwork = baseNetworkName(network);
  if (!SUPPORTED_BASE_NETWORKS.includes(baseNetwork)) {
    throw new Error(`Invalid network: ${network}`);
  }
}

function baseNetworkName(network: string): string {
  return network.endsWith("-staging") ? network.replace(/-staging$/, "") : network;
}

function loadDeployedContracts(network: string): DeployedContract[] {
  const path = `deployment/deploys/${network}.json`;
  const raw: unknown = JSON.parse(readFileSync(path, "utf8"));
  if (!Array.isArray(raw)) {
    throw new Error(`Invalid deployed contracts file: ${path}`);
  }
  return raw.map((item) => {
    if (isDeployedContract(item)) {
      return item;
    }
    throw new Error(`Invalid deployed contract item in ${path}`);
  });
}

function loadCutConfig(network: string, cutFileName: string): CutConfig {
  const path = `deployment/cuts/${network}/${normalizeCutFileName(cutFileName)}`;
  const raw: unknown = JSON.parse(readFileSync(path, "utf8"));
  if (typeof raw !== "object" || raw === null) {
    throw new Error(`Invalid cut config: ${path}`);
  }

  const config = raw as {
    diamond?: unknown;
    facets?: unknown;
    deleteSelectorSigs?: unknown;
    deleteAllOldMethods?: unknown;
  };
  if (typeof config.diamond !== "string") {
    throw new Error(`Invalid cut config ${path}: diamond must be a string`);
  }
  if (config.facets !== undefined && !isStringArray(config.facets)) {
    throw new Error(`Invalid cut config ${path}: facets must be an array of strings`);
  }
  if (config.deleteSelectorSigs !== undefined && !isStringArray(config.deleteSelectorSigs)) {
    throw new Error(`Invalid cut config ${path}: deleteSelectorSigs must be an array of strings`);
  }

  const cutConfig: CutConfig = { diamond: config.diamond };
  if (config.facets !== undefined) {
    cutConfig.facets = config.facets;
  }
  if (config.deleteSelectorSigs !== undefined) {
    cutConfig.deleteSelectorSigs = config.deleteSelectorSigs;
  }
  if (typeof config.deleteAllOldMethods === "boolean") {
    cutConfig.deleteAllOldMethods = config.deleteAllOldMethods;
  }
  return cutConfig;
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string");
}

function findDiamondAddress(deployedContracts: DeployedContract[]): string {
  const diamond = deployedContracts.find(
    (contract) => contract.name === DIAMOND_CONTRACT || contract.contractName === `${DIAMOND_CONTRACT}.sol`
  );
  if (!diamond) {
    throw new Error(`Could not find ${DIAMOND_CONTRACT} in deployment/deploys file`);
  }
  return diamond.address;
}

function normalizeCutFileName(cutFileName: string): string {
  return cutFileName.endsWith(".json") ? cutFileName : `${cutFileName}.json`;
}

function resolveRpcUrl(network: string): string {
  const env = { ...readDotEnv(), ...process.env };
  const baseNetwork = baseNetworkName(network);
  // Match the TEE deploy shell scripts: <NETWORK>_RPC (e.g. COSTON2_RPC).
  const rpcUrl = env[`${network.toUpperCase().replace(/-/g, "_")}_RPC`] ?? env[`${baseNetwork.toUpperCase()}_RPC`];
  if (rpcUrl) {
    return rpcUrl;
  }
  return `https://${baseNetwork}-api.flare.network/ext/C/rpc`;
}

function readDotEnv(): Record<string, string> {
  if (!existsSync(".env")) {
    return {};
  }
  const env: Record<string, string> = {};
  for (const line of readFileSync(".env", "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }
    const separator = trimmed.indexOf("=");
    if (separator < 0) {
      continue;
    }
    const key = trimmed.slice(0, separator).trim();
    const value = trimmed
      .slice(separator + 1)
      .trim()
      .replace(/^['"]|['"]$/g, "");
    env[key] = value;
  }
  return env;
}

function artifactPathFor(contractName: string): string {
  return `artifacts-forge/${contractName}.sol/${contractName}.json`;
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values));
}

// --- output ---

function printFacetPlan(plans: FacetPlan[]) {
  console.log("=== Facets (deploy) ===");
  if (plans.length === 0) {
    console.log("  (none)");
    console.log("");
    return;
  }
  for (const plan of plans) {
    const address = plan.address ? ` ${plan.address}` : "";
    console.log(`${plan.action.padEnd(8)} ${plan.name.padEnd(28)}${address}`);
    console.log(`         ${plan.reason}`);
    if (plan.deployedHash && plan.currentHash && plan.deployedHash !== plan.currentHash) {
      console.log(`         deployed=${plan.deployedHash} current=${plan.currentHash}`);
    }
  }
  console.log("");
}

function printSelectorPlan(staleSelectors: StaleSelector[], deleteSelectors: Set<string>) {
  const removed = staleSelectors.filter((stale) => !stale.movedTo);
  const moved = staleSelectors.filter((stale) => stale.movedTo);

  console.log("=== Selectors to remove ===");
  if (removed.length === 0) {
    console.log("  (none — every live selector still exists in current source)");
  }
  for (const stale of removed) {
    const listed = deleteSelectors.has(stale.selector);
    console.log(`DELETE   ${stale.selector} ${stale.signature ?? "unknown"}`);
    console.log(
      `         facet=${stale.facetName ?? "unknown"} liveAddress=${stale.facetAddress} deployedAddress=${stale.deployedFacetAddress ?? "unknown"}`
    );
    console.log(
      listed
        ? "         listed in deleteSelectorSigs — will be removed by the cut"
        : "         NOT in deleteSelectorSigs — add it to remove, else it stays live after the cut"
    );
  }
  console.log("");

  if (moved.length > 0) {
    console.log("=== Moved selectors (repoint — do NOT delete) ===");
    for (const stale of moved) {
      const wronglyListed = deleteSelectors.has(stale.selector);
      console.log(`MOVE     ${stale.selector} ${stale.signature ?? "unknown"}`);
      console.log(
        `         live on ${stale.facetName ?? "unknown"} (${stale.facetAddress}); now defined on ${stale.movedTo}`
      );
      console.log(
        wronglyListed
          ? `         WARNING IN deleteSelectorSigs — REMOVE it: this selector moved, deleting it drops a live function. Add ${stale.movedTo} to the cut's facets instead.`
          : `         add ${stale.movedTo} to the cut's facets so it repoints (Replace); do NOT add to deleteSelectorSigs`
      );
    }
    console.log("");
  }
}

function printSummary(plans: FacetPlan[], staleSelectors: StaleSelector[], deleteSelectors: Set<string>) {
  const count = (action: FacetAction) => plans.filter((plan) => plan.action === action).length;
  const removed = staleSelectors.filter((stale) => !stale.movedTo);
  const moved = staleSelectors.filter((stale) => stale.movedTo);
  const listed = removed.filter((stale) => deleteSelectors.has(stale.selector)).length;
  const needsListing = removed.length - listed;
  const wronglyListedMoved = moved.filter((stale) => deleteSelectors.has(stale.selector));

  console.log("Summary");
  console.log(
    `  Facets:  ${count("ADD")} add, ${count("REPLACE")} replace, ${count("REUSE")} reuse, ${count("REMOVE")} remove`
  );
  console.log(
    `  Selectors to remove: ${removed.length} (${listed} listed, ${needsListing} need adding to deleteSelectorSigs)`
  );
  if (moved.length > 0) {
    console.log(`  Moved selectors: ${moved.length} (repoint by adding their facet to the cut; do NOT delete)`);
  }

  if (needsListing > 0) {
    console.log("");
    console.log("Add only intentionally removed selectors to deleteSelectorSigs in the cut JSON");
    console.log("(entries accept a 4-byte hex selector or a canonical function signature):");
    for (const stale of removed) {
      if (!deleteSelectors.has(stale.selector)) {
        console.log(`  - ${stale.selector} ${stale.signature ?? "unknown"}`);
      }
    }
  }

  if (wronglyListedMoved.length > 0) {
    console.log("");
    console.log(
      "WARNING deleteSelectorSigs contains selectors that MOVED (not removed) — remove these and add their facet to the cut:"
    );
    for (const stale of wronglyListedMoved) {
      console.log(`  - ${stale.selector} ${stale.signature ?? "unknown"} -> now on ${stale.movedTo}`);
    }
  }
}

function printUsageAndExit(): never {
  console.error("Usage: pnpm check_cut <network> [cut-file-name]");
  console.error("Example: pnpm check_cut coston2 2026-07-23");
  process.exit(1);
}

main().catch((err: unknown) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
