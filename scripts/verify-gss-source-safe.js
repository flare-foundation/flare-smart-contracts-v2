#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");
const { AbiCoder, Interface, JsonRpcProvider, getAddress, id, keccak256 } = require("ethers");

const repoRoot = path.resolve(__dirname, "..");
const defaultManifest = path.join(repoRoot, "test-forge", "fv", "verification-manifest.json");
const guardSlot = "0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8";
const fallbackHandlerSlot = "0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5";
const sentinel = "0x0000000000000000000000000000000000000001";
const safeInterface = new Interface([
  "function VERSION() view returns (string)",
  "function getOwners() view returns (address[])",
  "function getThreshold() view returns (uint256)",
  "function nonce() view returns (uint256)",
  "function getModulesPaginated(address start,uint256 pageSize) view returns (address[] array,address next)",
]);

function option(name, fallback) {
  const index = process.argv.indexOf(name);
  return index === -1 ? fallback : process.argv[index + 1];
}

function canonicalAddress(value) {
  return getAddress(value).toLowerCase();
}

function addressFromWord(value) {
  return canonicalAddress(`0x${value.slice(-40)}`);
}

function canonicalJson(value) {
  if (Array.isArray(value)) return value.map(canonicalJson);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonicalJson(value[key])]));
  }
  return value;
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

async function main() {
  const manifestPath = path.resolve(option("--manifest", defaultManifest));
  const manifestBytes = fs.readFileSync(manifestPath);
  const manifest = JSON.parse(manifestBytes);
  const expected = manifest.gss_source_safe;
  const rpcUrl = option("--rpc-url", process.env.FLARE_RPC_URL || expected.rpc_url);
  const outputPath = path.resolve(
    option("--output", path.join(repoRoot, "verification-reports", "gss-source-safe.json")),
  );
  const blockTag = `0x${BigInt(expected.block_number).toString(16)}`;
  const safeAddress = canonicalAddress(expected.safe);
  const provider = new JsonRpcProvider(rpcUrl, undefined, { staticNetwork: true });

  async function safeCall(functionName, values = []) {
    const data = safeInterface.encodeFunctionData(functionName, values);
    const result = await provider.send("eth_call", [{ to: safeAddress, data }, blockTag]);
    return safeInterface.decodeFunctionResult(functionName, result);
  }

  const [chainIdHex, block, versionResult, ownersResult, thresholdResult, nonceResult, modulesResult] =
    await Promise.all([
      provider.send("eth_chainId", []),
      provider.send("eth_getBlockByNumber", [blockTag, false]),
      safeCall("VERSION"),
      safeCall("getOwners"),
      safeCall("getThreshold"),
      safeCall("nonce"),
      safeCall("getModulesPaginated", [sentinel, 100]),
    ]);
  if (!block) throw new Error(`block ${blockTag} is unavailable from ${rpcUrl}`);

  const [singletonWord, guardWord, fallbackWord] = await Promise.all([
    provider.send("eth_getStorageAt", [safeAddress, "0x0", blockTag]),
    provider.send("eth_getStorageAt", [safeAddress, guardSlot, blockTag]),
    provider.send("eth_getStorageAt", [safeAddress, fallbackHandlerSlot, blockTag]),
  ]);
  const singleton = addressFromWord(singletonWord);
  const guard = addressFromWord(guardWord);
  const fallbackHandler = addressFromWord(fallbackWord);
  const [safeCode, singletonCode, fallbackHandlerCode] = await Promise.all([
    provider.send("eth_getCode", [safeAddress, blockTag]),
    provider.send("eth_getCode", [singleton, blockTag]),
    provider.send("eth_getCode", [fallbackHandler, blockTag]),
  ]);
  if (safeCode === "0x" || singletonCode === "0x" || fallbackHandlerCode === "0x") {
    throw new Error("Safe, singleton, or fallback handler has no code at the snapshot block");
  }

  const ownersSafeOrder = [...ownersResult[0]].map(canonicalAddress);
  const ownersCanonical = [...ownersSafeOrder].sort();
  const ownerCodes = await Promise.all(
    ownersCanonical.map(owner => provider.send("eth_getCode", [owner, blockTag])),
  );
  const contractOwners = ownersCanonical.filter((_, index) => ownerCodes[index] !== "0x");
  const threshold = thresholdResult[0];
  const safeNonce = nonceResult[0];
  const suggestedOwnerConfigNonce = safeNonce + 1n;
  const ownerConfigTypehash = id(
    "FlareRelayOwnerConfiguration(uint256 sourceChainId,address safe,uint256 safeNonce,uint256 threshold,address[] owners)",
  );
  const ownerConfigHash = keccak256(
    AbiCoder.defaultAbiCoder().encode(
      ["bytes32", "uint256", "address", "uint256", "uint256", "address[]"],
      [ownerConfigTypehash, BigInt(chainIdHex), safeAddress, suggestedOwnerConfigNonce, threshold, ownersCanonical],
    ),
  );

  const observed = {
    chain_id: Number(BigInt(chainIdHex)),
    block_number: Number(BigInt(block.number)),
    block_hash: block.hash.toLowerCase(),
    block_timestamp: Number(BigInt(block.timestamp)),
    block_gas_limit: BigInt(block.gasLimit).toString(),
    safe: safeAddress,
    version: versionResult[0],
    owner_count: ownersSafeOrder.length,
    owner_contract_count: contractOwners.length,
    contract_owners: contractOwners,
    owners_safe_order: ownersSafeOrder,
    owners_canonical: ownersCanonical,
    threshold: threshold.toString(),
    nonce: safeNonce.toString(),
    module_count: modulesResult[0].length,
    modules: [...modulesResult[0]].map(canonicalAddress),
    module_next: canonicalAddress(modulesResult[1]),
    singleton,
    guard,
    fallback_handler: fallbackHandler,
    safe_runtime_keccak256: keccak256(safeCode),
    singleton_runtime_keccak256: keccak256(singletonCode),
    fallback_handler_runtime_keccak256: keccak256(fallbackHandlerCode),
    suggested_owner_config_nonce: suggestedOwnerConfigNonce.toString(),
    suggested_owner_config_hash: ownerConfigHash,
  };

  const comparable = [
    "chain_id",
    "block_number",
    "block_hash",
    "block_timestamp",
    "block_gas_limit",
    "safe",
    "version",
    "owner_count",
    "owner_contract_count",
    "threshold",
    "nonce",
    "module_count",
    "module_next",
    "singleton",
    "guard",
    "fallback_handler",
    "owners_canonical",
    "safe_runtime_keccak256",
    "singleton_runtime_keccak256",
    "fallback_handler_runtime_keccak256",
  ];
  const checks = {};
  const violations = [];
  for (const key of comparable) {
    if (!(key in expected)) continue;
    const actualJson = JSON.stringify(canonicalJson(observed[key]));
    const expectedJson = JSON.stringify(canonicalJson(expected[key]));
    const matches = actualJson === expectedJson;
    checks[key] = matches;
    if (!matches) violations.push(`${key} is ${actualJson}; expected ${expectedJson}`);
  }

  const report = {
    schema_version: 1,
    gate: "gss-source-safe",
    status: violations.length === 0 ? "pass" : "fail",
    git_commit: childProcess.execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: repoRoot,
      encoding: "utf8",
    }).trim(),
    manifest_sha256: sha256(manifestBytes),
    rpc_url: rpcUrl,
    observed,
    checks,
    violations,
  };
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(
    `[gss-source-safe] ${report.status.toUpperCase()}: ${Object.keys(checks).length} fixed-block checks, ` +
      `${violations.length} violation(s).`,
  );
  console.log(`[gss-source-safe] report: ${outputPath}`);
  if (violations.length) {
    for (const violation of violations) console.error(`  - ${violation}`);
    process.exitCode = 1;
  }
}

main().catch(error => {
  console.error(`[gss-source-safe] FAIL: ${error.stack || error.message}`);
  process.exitCode = 1;
});
