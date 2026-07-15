#!/usr/bin/env node
"use strict";

// Produce a small deterministic record for the Hardhat Relay deployment artifact.
// The FV job consumes this instead of transferring Hardhat's large build-info tree.

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const manifestPath = path.join(repoRoot, "test-forge", "fv", "verification-manifest.json");

function fail(message) {
  console.error(`[relay-artifact] FAIL: ${message}`);
  process.exit(1);
}

function parseOutputPath() {
  const index = process.argv.indexOf("--output");
  if (index === -1 || !process.argv[index + 1]) {
    return path.join(repoRoot, "verification-reports", "relay-deployment.json");
  }
  return path.resolve(process.cwd(), process.argv[index + 1]);
}

function bytesFromHex(value, label) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]*$/.test(value) || value.length % 2 !== 0) {
    fail(`${label} is not canonical 0x-prefixed bytecode`);
  }
  return Buffer.from(value.slice(2), "hex");
}

function stripCborMetadata(value, label) {
  const bytes = bytesFromHex(value, label);
  if (bytes.length < 2) fail(`${label} is too short to contain a CBOR length suffix`);
  const metadataLength = bytes.readUInt16BE(bytes.length - 2);
  const suffixLength = metadataLength + 2;
  if (suffixLength >= bytes.length) fail(`${label} has an invalid CBOR metadata length ${metadataLength}`);
  const metadata = bytes.subarray(bytes.length - suffixLength, bytes.length - 2);
  if (metadata.length === 0 || (metadata[0] & 0xe0) !== 0xa0) {
    fail(`${label} suffix is not a CBOR map`);
  }
  return {
    full: bytes,
    semantic: bytes.subarray(0, bytes.length - suffixLength),
    metadataBytes: suffixLength,
  };
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  }
  return value;
}

function abiHash(abi) {
  const entries = abi.map(entry => JSON.stringify(canonical(entry))).sort();
  return sha256(Buffer.from(`[${entries.join(",")}]`));
}

function summarizeBytecode(value, label) {
  const parsed = stripCborMetadata(value, label);
  return {
    bytes: parsed.full.length,
    metadata_bytes: parsed.metadataBytes,
    full_sha256: sha256(parsed.full),
    semantic_bytes: parsed.semantic.length,
    semantic_sha256: sha256(parsed.semantic),
  };
}

function compilerSettings(buildInfo) {
  const settings = buildInfo.input.settings;
  return {
    version: buildInfo.solcLongVersion,
    evm_version: settings.evmVersion,
    optimizer_enabled: settings.optimizer && settings.optimizer.enabled === true,
    optimizer_runs: settings.optimizer && settings.optimizer.runs,
    via_ir: settings.viaIR === true,
  };
}

function assertExpected(actual, expected, label) {
  for (const key of Object.keys(expected)) {
    if (key === "short_version") continue;
    if (actual[key] !== expected[key]) {
      fail(`${label}.${key} is ${JSON.stringify(actual[key])}; expected ${JSON.stringify(expected[key])}`);
    }
  }
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const target = manifest.target;
const sourceName = target.source;
const contractName = target.contract;
const artifactPath = path.join(repoRoot, "artifacts", sourceName, `${contractName}.json`);
if (!fs.existsSync(artifactPath)) fail(`missing Hardhat artifact ${artifactPath}; run hardhat compile first`);

const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
if (artifact.sourceName !== sourceName || artifact.contractName !== contractName) {
  fail(`artifact identity is ${artifact.sourceName}:${artifact.contractName}, expected ${sourceName}:${contractName}`);
}

const buildInfoDir = path.join(repoRoot, "artifacts", "build-info");
if (!fs.existsSync(buildInfoDir)) fail(`missing Hardhat build-info directory ${buildInfoDir}`);

const matches = [];
for (const filename of fs.readdirSync(buildInfoDir).filter(name => name.endsWith(".json")).sort()) {
  const candidate = JSON.parse(fs.readFileSync(path.join(buildInfoDir, filename), "utf8"));
  const output = candidate.output?.contracts?.[sourceName]?.[contractName];
  if (output && `0x${output.evm.bytecode.object}` === artifact.bytecode) {
    matches.push({ filename, buildInfo: candidate });
  }
}
if (matches.length === 0) fail("no Hardhat build-info file matches the Relay artifact bytecode");

const configurations = new Map();
for (const match of matches) {
  const settings = compilerSettings(match.buildInfo);
  configurations.set(JSON.stringify(settings), settings);
}
if (configurations.size !== 1) fail("matching Hardhat build-info files disagree on compiler settings");
const deploymentCompiler = configurations.values().next().value;
assertExpected(deploymentCompiler, target.deployment_compiler, "deployment compiler");

const sourceBytes = fs.readFileSync(path.join(repoRoot, sourceName));
const outputPath = parseOutputPath();
const report = {
  schema_version: 1,
  gate: "relay-deployment-artifact",
  status: "pass",
  source: sourceName,
  contract: contractName,
  source_sha256: sha256(sourceBytes),
  compiler: deploymentCompiler,
  abi_sha256: abiHash(artifact.abi),
  creation: summarizeBytecode(artifact.bytecode, "creation bytecode"),
  runtime: summarizeBytecode(artifact.deployedBytecode, "runtime bytecode"),
  matching_build_info_files: matches.map(match => match.filename),
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(`[relay-artifact] PASS: ${sourceName}:${contractName}`);
console.log(`[relay-artifact] runtime semantic sha256 ${report.runtime.semantic_sha256}`);
console.log(`[relay-artifact] report: ${outputPath}`);
