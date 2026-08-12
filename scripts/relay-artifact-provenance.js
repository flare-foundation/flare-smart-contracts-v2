#!/usr/bin/env node
"use strict";

// Produce a small deterministic record for the Hardhat Relay deployment artifact.
// The FV job consumes this instead of transferring Hardhat's large build-info tree.

const crypto = require("crypto");
const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const manifestPath = path.join(repoRoot, "test-forge", "fv", "verification-manifest.json");
const GENERATED_MODE = "generated-in-process";

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

function captureGitState() {
  const headResult = childProcess.spawnSync("git", ["rev-parse", "HEAD"], {
    cwd: repoRoot,
    encoding: null,
  });
  const statusResult = childProcess.spawnSync("git", ["status", "--porcelain=v1", "--untracked-files=all"], {
    cwd: repoRoot,
    encoding: null,
  });
  const headBytes = Buffer.isBuffer(headResult.stdout) ? headResult.stdout : Buffer.alloc(0);
  const statusBytes = Buffer.isBuffer(statusResult.stdout) ? statusResult.stdout : Buffer.alloc(0);
  const head = headBytes.toString("ascii").trim();
  const available =
    !headResult.error &&
    !statusResult.error &&
    headResult.status === 0 &&
    statusResult.status === 0 &&
    /^[0-9a-f]{40}$/.test(head);
  return {
    available,
    head: head || "unknown",
    clean: available && statusBytes.length === 0,
    status_sha256: sha256(statusBytes),
    status_entries: statusBytes.length === 0 ? 0 : statusBytes.toString("utf8").trimEnd().split("\n").length,
    head_exitcode: headResult.status,
    status_exitcode: statusResult.status,
  };
}

function generationProvenance(start, end) {
  const reasons = [];
  for (const [phase, state] of [
    ["start", start],
    ["end", end],
  ]) {
    if (state.available !== true) reasons.push(`git-state-unavailable-at-${phase}`);
    else if (state.clean !== true) reasons.push(`worktree-dirty-at-${phase}`);
  }
  if (start.available === true && end.available === true && start.head !== end.head) {
    reasons.push("head-changed-during-generation");
  }
  return {
    schema_version: 1,
    mode: GENERATED_MODE,
    start,
    end,
    release_eligible: reasons.length === 0,
    development_reasons: reasons,
  };
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
  // Runtime metadata is a suffix. Creation bytecode for contracts with immutable
  // values can carry compiler auxdata after that suffix, so scan backwards for
  // the last Solidity CBOR map and preserve any trailing semantic bytes.
  for (let end = bytes.length; end >= 2; end--) {
    const metadataLength = bytes.readUInt16BE(end - 2);
    const start = end - metadataLength - 2;
    if (start <= 0) continue;
    const metadata = bytes.subarray(start, end - 2);
    if (metadata.length === 0 || (metadata[0] & 0xe0) !== 0xa0) continue;
    if (end !== bytes.length && !metadata.includes(Buffer.from("solc"))) continue;
    return {
      full: bytes,
      semantic: Buffer.concat([bytes.subarray(0, start), bytes.subarray(end)]),
      metadataBytes: metadataLength + 2,
      metadataOffset: start,
      trailingBytes: bytes.length - end,
      suffix: bytes.subarray(start, end),
    };
  }
  fail(`${label} has no valid Solidity CBOR metadata segment`);
}

// The legacy codegen pipeline places the runtime object (and thus its CBOR metadata suffix) at
// the very end of the creation bytecode; via_ir emits constructor code after the embedded runtime,
// so the metadata sits mid-stream. Excise the runtime's exact suffix bytes wherever they occur.
function stripEmbeddedCborMetadata(value, runtimeSuffix, label) {
  const bytes = bytesFromHex(value, label);
  if (!Buffer.isBuffer(runtimeSuffix) || runtimeSuffix.length === 0) {
    fail(`${label} was given an empty runtime CBOR metadata suffix`);
  }
  const parts = [];
  let count = 0;
  let cursor = 0;
  let firstOffset = -1;
  let lastEnd = -1;
  for (let hit = bytes.indexOf(runtimeSuffix); hit !== -1; hit = bytes.indexOf(runtimeSuffix, cursor)) {
    if (firstOffset === -1) firstOffset = hit;
    parts.push(bytes.subarray(cursor, hit));
    cursor = hit + runtimeSuffix.length;
    lastEnd = cursor;
    count += 1;
  }
  if (count === 0) fail(`${label} does not embed the runtime CBOR metadata suffix`);
  parts.push(bytes.subarray(cursor));
  return {
    full: bytes,
    semantic: Buffer.concat(parts),
    metadataBytes: runtimeSuffix.length * count,
    metadataOffset: firstOffset,
    trailingBytes: bytes.length - lastEnd,
  };
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonical(value[key])])
    );
  }
  return value;
}

function abiHash(abi) {
  const entries = abi.map((entry) => JSON.stringify(canonical(entry))).sort();
  return sha256(Buffer.from(`[${entries.join(",")}]`));
}

function summarizeParsedBytecode(parsed) {
  return {
    bytes: parsed.full.length,
    metadata_bytes: parsed.metadataBytes,
    full_sha256: sha256(parsed.full),
    semantic_bytes: parsed.semantic.length,
    semantic_sha256: sha256(parsed.semantic),
    metadata_offset: parsed.metadataOffset,
    trailing_bytes: parsed.trailingBytes,
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

function runNodePreparation() {
  const packageJson = JSON.parse(fs.readFileSync(path.join(repoRoot, "package.json"), "utf8"));
  const expectedPnpm = packageJson.packageManager.split("@", 2)[1].split("+", 1)[0];
  const pnpm = process.env.PNPM || "pnpm";
  const version = childProcess.spawnSync(pnpm, ["--version"], {
    cwd: repoRoot,
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024,
  });
  if (version.error || version.status !== 0 || version.stdout.trim() !== expectedPnpm) {
    fail(
      `pnpm is ${JSON.stringify((version.stdout || version.stderr || "unavailable").trim())}; expected ${expectedPnpm}`
    );
  }
  const commands = [["install", "--frozen-lockfile", "--force"], ["hardhat", "clean"], ["compile"]];
  const records = [];
  for (const args of commands) {
    const completed = childProcess.spawnSync(pnpm, args, {
      cwd: repoRoot,
      encoding: "utf8",
      maxBuffer: 50 * 1024 * 1024,
    });
    if (completed.error || completed.status !== 0) {
      fail(
        `${pnpm} ${args.join(" ")} failed: ${(completed.stderr || completed.stdout || completed.error || "").toString().slice(-1000)}`
      );
    }
    records.push({
      command: [pnpm, ...args],
      exitcode: completed.status,
      stdout_sha256: sha256(Buffer.from(completed.stdout || "")),
      stderr_sha256: sha256(Buffer.from(completed.stderr || "")),
    });
  }
  return {
    mode: "clean-install-and-compile-in-process",
    pnpm_version: version.stdout.trim(),
    commands: records,
    release_eligible: true,
    problems: [],
  };
}

const generationStart = captureGitState();
const manifestBytes = fs.readFileSync(manifestPath);
const manifest = JSON.parse(manifestBytes);
if (!Number.isInteger(manifest.schema_version) || manifest.schema_version !== 1) {
  fail("verification manifest schema_version must be integer 1");
}
const target = manifest.target;
const nodePreparation = runNodePreparation();
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
for (const filename of fs
  .readdirSync(buildInfoDir)
  .filter((name) => name.endsWith(".json"))
  .sort()) {
  const candidate = JSON.parse(fs.readFileSync(path.join(buildInfoDir, filename), "utf8"));
  const output = candidate.output?.contracts?.[sourceName]?.[contractName];
  if (output && `0x${output.evm.bytecode.object}` === artifact.bytecode) {
    matches.push({ filename, buildInfo: candidate });
  }
}
if (matches.length === 0) fail("no Hardhat build-info file matches the Relay artifact bytecode");

const configurations = new Map();
const sourceBytes = fs.readFileSync(path.join(repoRoot, sourceName));
for (const match of matches) {
  const compiledSource = match.buildInfo.input?.sources?.[sourceName]?.content;
  if (typeof compiledSource !== "string" || !Buffer.from(compiledSource).equals(sourceBytes)) {
    fail(`${match.filename} was not compiled from the current ${sourceName}`);
  }
  const settings = compilerSettings(match.buildInfo);
  configurations.set(JSON.stringify(settings), settings);
}
if (configurations.size !== 1) fail("matching Hardhat build-info files disagree on compiler settings");
const deploymentCompiler = configurations.values().next().value;
assertExpected(deploymentCompiler, target.production_compiler, "production compiler");

const outputPath = parseOutputPath();
const generation = generationProvenance(generationStart, captureGitState());
const report = {
  schema_version: 1,
  gate: "relay-deployment-artifact",
  status: "pass",
  release_eligible: generation.release_eligible && nodePreparation.release_eligible,
  git_commit: generationStart.available ? generationStart.head : "unknown",
  manifest_sha256: sha256(manifestBytes),
  generation_provenance: generation,
  inputs: {
    node: nodePreparation,
    release_eligible: nodePreparation.release_eligible,
    problems: nodePreparation.problems,
  },
  source: sourceName,
  contract: contractName,
  source_sha256: sha256(sourceBytes),
  compiler: deploymentCompiler,
  abi_sha256: abiHash(artifact.abi),
  creation: summarizeParsedBytecode(
    stripEmbeddedCborMetadata(
      artifact.bytecode,
      stripCborMetadata(artifact.deployedBytecode, "runtime bytecode").suffix,
      "creation bytecode"
    )
  ),
  runtime: summarizeParsedBytecode(stripCborMetadata(artifact.deployedBytecode, "runtime bytecode")),
  matching_build_info_files: matches.map((match) => match.filename),
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(`[relay-artifact] PASS: ${sourceName}:${contractName}`);
console.log(`[relay-artifact] runtime semantic sha256 ${report.runtime.semantic_sha256}`);
console.log(`[relay-artifact] report: ${outputPath}`);
