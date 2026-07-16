/**
 * Reverse dependency lookup for the AddressUpdater dependency graph.
 *
 * Contracts declare the other contracts they depend on inside their
 * `_updateContractAddresses(...)` override, via calls of the form:
 *
 *     _getContractAddress(_contractNameHashes, _contractAddresses, "VoterRegistry")
 *
 * This script scans the Solidity source tree and, for a given contract name,
 * reports every contract that resolves it through this mechanism (i.e. every
 * contract that "uses" it via the AddressUpdater).
 *
 * Inheritance is resolved: a dependency declared in an abstract base
 * (e.g. `_getContractAddress(..., "X")` inside `TeePaymentsBase`) is attributed
 * to the concrete contract(s) that inherit it (e.g. `TeePayments`), since those
 * are the instantiable/deployable contracts that actually carry the dependency.
 * The declaration site is shown as provenance ("via <Base>:<line>").
 * Use --decl-sites to instead list the raw declaration sites (no inheritance).
 *
 * This assumes the repo's convention that a concrete override of
 * `_updateContractAddresses` chains `super._updateContractAddresses(...)`, so a
 * base's dependencies really are the child's; a child that overrode without
 * calling super would be over-attributed. Cross-repo name collisions resolve
 * within the same source (v1 base for a v1 contract, v2 for v2).
 *
 * By default it scans BOTH repos, since deployments mix contracts from both:
 *   - v2: this repo's `contracts/`
 *   - v1: flare-smart-contracts, available as the `flare-smart-contracts`
 *         dependency at `node_modules/flare-smart-contracts/contracts`
 *         (https://github.com/flare-foundation/flare-smart-contracts-v1)
 *
 * It is the companion of `check-address-updater.ts`: that one checks the
 * on-chain AddressUpdater registry, this one inspects the source graph
 * statically (no Hardhat / network needed).
 *
 * Only string-literal dependency names are resolvable; calls that pass a
 * variable (e.g. `getContractName()`) cannot be matched by name and are
 * skipped.
 *
 * One or more contract names may be given; with several, the result is the
 * UNION (contracts that use at least one of them), annotated with which of
 * the requested names each using-contract resolves.
 *
 * Usage:
 *   pnpm ts-node scripts/check-contract-usage.ts <ContractName...> [options]
 *
 * Mock contracts (any `mock/` directory) are excluded by default.
 *
 * Options:
 *   --deployed <net>  Restrict results to contracts deployed on <net> (flare,
 *                     songbird, coston, coston2), per deployment/deploys/<net>.json.
 *                     That registry tracks v2 only, so v2 users are classified
 *                     deployed / not-deployed and v1 users are reported
 *                     separately as deployment-status-unknown.
 *   --decl-sites      Report raw declaration sites (contract + line of each
 *                     _getContractAddress call) instead of resolving inheritance.
 *   --mocks           Include mock contracts (excluded by default).
 *   --no-v1           Scan only this repo (v2), skip the v1 dependency.
 *   --v1-path <path>  Override the v1 source root
 *                     (default: node_modules/flare-smart-contracts/contracts).
 *   --dir <path>      Scan exactly the given root(s) instead of the defaults.
 *                     Repeatable. Disables the v1/v2 defaults.
 *
 * Examples:
 *   pnpm ts-node scripts/check-contract-usage.ts VoterRegistry
 *   pnpm ts-node scripts/check-contract-usage.ts VoterRegistry FlareSystemsCalculator WNatDelegationFee
 *   pnpm ts-node scripts/check-contract-usage.ts TeePaymentsConfigVerifier   # -> TeePayments via TeePaymentsBase
 *   pnpm ts-node scripts/check-contract-usage.ts VoterRegistry --deployed flare
 *   pnpm ts-node scripts/check-contract-usage.ts FtsoManager        # found in v1
 *   pnpm ts-node scripts/check-contract-usage.ts WNat --no-v1
 *   pnpm ts-node scripts/check-contract-usage.ts Relay --dir contracts/protocol
 */
import * as fs from "fs";
import * as path from "path";

interface Source {
  label: string; // short repo tag shown in output, e.g. "v2" / "v1"
  root: string; // directory to scan
}

/** A contract/interface/library declaration and the dependencies it declares. */
interface ContractDef {
  name: string;
  file: string; // repo-relative path
  label: string; // source label (v1 / v2)
  isAbstract: boolean;
  instantiable: boolean; // a non-abstract `contract` (interfaces/libraries/abstract are not)
  bases: string[]; // names in the `is ...` clause
  refs: Map<string, number[]>; // dependency name -> lines of the _getContractAddress calls
}

interface DeployEntry {
  name: string; // AddressUpdater name
  contractName: string; // .sol file name, e.g. "VoterRegistry.sol"
  address: string;
}

const DEFAULT_V1_PATH = "node_modules/flare-smart-contracts/contracts";
const DEFAULT_V2_PATH = "contracts";

const GET_CONTRACT_ADDRESS = /_getContractAddress\s*\([^)]*?"([^"]+)"/g;
const HEADER = /\b(abstract\s+contract|contract|interface|library)\s+([A-Za-z_]\w*)([^{}]*)\{/g;

/** A file is a mock if any of its directory segments contains "mock". */
function isMockPath(rel: string): boolean {
  return path
    .dirname(rel)
    .split(path.sep)
    .some((seg) => /mock/i.test(seg));
}

/**
 * Replace the contents of `//` and block comments with spaces, preserving
 * offsets and newlines so that later match positions still map to real lines.
 * String literals are left intact so dependency names inside them are kept.
 */
function blankComments(source: string): string {
  const out = source.split("");
  let state: "code" | "line" | "block" | "string" = "code";
  let quote = "";
  for (let i = 0; i < source.length; i++) {
    const c = source[i];
    const next = source[i + 1];
    switch (state) {
      case "code":
        if (c === "/" && next === "/") {
          state = "line";
          out[i] = out[i + 1] = " ";
          i++;
        } else if (c === "/" && next === "*") {
          state = "block";
          out[i] = out[i + 1] = " ";
          i++;
        } else if (c === '"' || c === "'") {
          state = "string";
          quote = c;
        }
        break;
      case "line":
        if (c === "\n") state = "code";
        else out[i] = " ";
        break;
      case "block":
        if (c === "*" && next === "/") {
          out[i] = out[i + 1] = " ";
          i++;
          state = "code";
        } else if (c !== "\n") {
          out[i] = " ";
        }
        break;
      case "string":
        // keep string contents; handle escapes so an escaped quote doesn't end it
        if (c === "\\") i++;
        else if (c === quote) state = "code";
        break;
    }
  }
  return out.join("");
}

/**
 * Blank string interiors (keeping the quote characters) of already
 * comment-blanked source. Used for structural scanning (contract headers) so a
 * `contract` keyword inside a string literal is not mistaken for a declaration.
 * Offsets/length are preserved, so positions map back to the original.
 */
function blankStrings(source: string): string {
  const out = source.split("");
  let inStr = false;
  let quote = "";
  for (let i = 0; i < source.length; i++) {
    const c = source[i];
    if (inStr) {
      if (c === "\\") {
        out[i] = " ";
        if (i + 1 < source.length) out[i + 1] = " ";
        i++;
      } else if (c === quote) {
        inStr = false;
      } else {
        out[i] = " ";
      }
    } else if (c === '"' || c === "'") {
      inStr = true;
      quote = c;
    }
  }
  return out.join("");
}

function walkFiles(dir: string, ext: string): string[] {
  const result: string[] = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      result.push(...walkFiles(full, ext));
    } else if (entry.isFile() && entry.name.endsWith(ext)) {
      result.push(full);
    }
  }
  return result;
}

function walkSolFiles(dir: string): string[] {
  return walkFiles(dir, ".sol");
}

function lineOf(source: string, index: number): number {
  let line = 1;
  for (let i = 0; i < index; i++) {
    if (source[i] === "\n") line++;
  }
  return line;
}

/** Extract base contract names from an `is ...` clause (constructor args stripped). */
function parseBases(isClause: string): string[] {
  const kw = /\bis\b/.exec(isClause);
  if (!kw) return [];
  let s = isClause.slice(kw.index + 2);
  let prev = "";
  while (s !== prev) {
    prev = s;
    s = s.replace(/\([^()]*\)/g, ""); // strip (possibly nested) constructor argument lists
  }
  const bases: string[] = [];
  for (const part of s.split(",")) {
    const id = /[A-Za-z_]\w*/.exec(part);
    if (id) bases.push(id[0]);
  }
  return bases;
}

interface Index {
  allDefs: ContractDef[];
  nameToDefs: Map<string, ContractDef[]>;
}

function parseFile(rel: string, label: string, raw: string, index: Index): void {
  const commentBlanked = blankComments(raw);
  const structural = blankStrings(commentBlanked);

  // Contract/interface/library declarations, in source order.
  const headers: { pos: number; def: ContractDef }[] = [];
  HEADER.lastIndex = 0;
  let hm: RegExpExecArray | null;
  while ((hm = HEADER.exec(structural)) !== null) {
    const kindRaw = hm[1];
    const isAbstract = kindRaw.startsWith("abstract");
    const isContract = isAbstract || kindRaw === "contract";
    const def: ContractDef = {
      name: hm[2],
      file: rel,
      label,
      isAbstract,
      instantiable: isContract && !isAbstract,
      bases: parseBases(hm[3]),
      refs: new Map(),
    };
    index.allDefs.push(def);
    const list = index.nameToDefs.get(def.name);
    if (list) list.push(def);
    else index.nameToDefs.set(def.name, [def]);
    headers.push({ pos: hm.index, def });
  }

  // Attribute each _getContractAddress call to the contract whose body it is in
  // (the nearest preceding declaration; Solidity contracts do not nest).
  GET_CONTRACT_ADDRESS.lastIndex = 0;
  let cm: RegExpExecArray | null;
  while ((cm = GET_CONTRACT_ADDRESS.exec(commentBlanked)) !== null) {
    let owner: ContractDef | null = null;
    for (const h of headers) {
      if (h.pos <= cm.index) owner = h.def;
      else break;
    }
    if (!owner) continue;
    const line = lineOf(commentBlanked, cm.index);
    const lines = owner.refs.get(cm[1]);
    if (lines) lines.push(line);
    else owner.refs.set(cm[1], [line]);
  }
}

function buildIndex(sources: Source[], excludeMocks: boolean): Index {
  const index: Index = { allDefs: [], nameToDefs: new Map() };
  for (const source of sources) {
    for (const file of walkSolFiles(source.root)) {
      const rel = path.relative(process.cwd(), file);
      if (excludeMocks && isMockPath(rel)) continue;
      parseFile(rel, source.label, fs.readFileSync(file, "utf8"), index);
    }
  }
  return index;
}

/**
 * All transitive ancestor definitions of a contract (excluding itself).
 * When a base name is defined in more than one source (v1 and v2 both define
 * e.g. `Governor`), prefer the definition(s) from the same source as `def` —
 * inheritance is within-repo, so this avoids cross-repo collisions leaking a
 * v2 dependency onto a v1 contract (or vice versa).
 */
function ancestorsOf(def: ContractDef, nameToDefs: Map<string, ContractDef[]>): ContractDef[] {
  const result: ContractDef[] = [];
  const seen = new Set<string>();
  const stack = [...def.bases];
  while (stack.length > 0) {
    const base = stack.pop()!;
    if (seen.has(base)) continue;
    seen.add(base);
    const all = nameToDefs.get(base) ?? [];
    const sameLabel = all.filter((d) => d.label === def.label);
    for (const bd of sameLabel.length > 0 ? sameLabel : all) {
      result.push(bd);
      for (const bb of bd.bases) if (!seen.has(bb)) stack.push(bb);
    }
  }
  return result;
}

interface Contributor {
  def: ContractDef; // where the _getContractAddress call is declared
  lines: number[];
}
interface TargetUse {
  direct: boolean; // the target is declared in the concrete contract itself
  contributors: Contributor[];
}
interface UserRecord {
  def: ContractDef; // the concrete (instantiable) contract that uses the target(s)
  uses: Map<string, TargetUse>;
}
interface Unresolved {
  target: string;
  def: ContractDef; // abstract declaration site with no concrete implementor in scan
  lines: number[];
}

function collectUsers(
  targets: string[],
  index: Index
): { users: UserRecord[]; unresolved: Unresolved[]; missing: string[]; known: string[] } {
  const { allDefs, nameToDefs } = index;
  const targetSet = new Set(targets);

  const users: UserRecord[] = [];
  const contributed = new Set<ContractDef>(); // declaration sites covered by some concrete user
  for (const c of allDefs) {
    if (!c.instantiable) continue;
    const reachable = [c, ...ancestorsOf(c, nameToDefs)];
    const uses = new Map<string, TargetUse>();
    for (const target of targets) {
      const contributors = reachable
        .filter((d) => d.refs.has(target))
        .map((d) => ({ def: d, lines: d.refs.get(target)! }));
      if (contributors.length === 0) continue;
      uses.set(target, { direct: contributors.some((cc) => cc.def === c), contributors });
      for (const cc of contributors) contributed.add(cc.def);
    }
    if (uses.size > 0) users.push({ def: c, uses });
  }

  // Declaration sites in abstract contracts that no concrete contract inherits.
  const unresolved: Unresolved[] = [];
  for (const d of allDefs) {
    if (d.instantiable || contributed.has(d)) continue;
    for (const target of d.refs.keys()) {
      if (targetSet.has(target)) unresolved.push({ target, def: d, lines: d.refs.get(target)! });
    }
  }

  const usedTargets = new Set<string>();
  for (const u of users) for (const t of u.uses.keys()) usedTargets.add(t);
  for (const u of unresolved) usedTargets.add(u.target);
  const missing = targets.filter((t) => !usedTargets.has(t));

  const known = [...new Set(allDefs.flatMap((d) => [...d.refs.keys()]))].sort((a, b) => a.localeCompare(b));
  return { users, unresolved, missing, known };
}

function usage(msg?: string): never {
  if (msg) console.error(msg + "\n");
  console.error("Usage: pnpm ts-node scripts/check-contract-usage.ts <ContractName...> [options]");
  console.error("");
  console.error("Reports which concrete contracts resolve the given name(s) via the AddressUpdater");
  console.error('(_getContractAddress(..., "<ContractName>")), resolving inheritance, across the v2');
  console.error("(this repo) and v1 (flare-smart-contracts dependency) source trees.");
  console.error("With several names, reports the union (contracts using at least one).");
  console.error("");
  console.error("Options:");
  console.error("  --deployed <net>  Restrict results to contracts deployed on <net>.");
  console.error("  --decl-sites      List raw declaration sites instead of resolving inheritance.");
  console.error("  --mocks           Include mock contracts (excluded by default).");
  console.error("  --no-v1           Scan only this repo (v2).");
  console.error("  --v1-path <path>  Override the v1 source root.");
  console.error("  --dir <path>      Scan exactly the given root(s) instead of the defaults (repeatable).");
  process.exit(msg ? 1 : 0);
}

interface Options {
  targets: string[];
  sources: Source[];
  excludeMocks: boolean;
  deployedNetwork: string | null;
  declSites: boolean;
}

function parseArgs(): Options {
  const argv = process.argv.slice(2);
  const dirs: string[] = [];
  let v1Path = DEFAULT_V1_PATH;
  let includeV1 = true;
  let excludeMocks = true;
  let declSites = false;
  let deployedNetwork: string | null = null;
  const positional: string[] = [];

  for (let i = 0; i < argv.length; i++) {
    switch (argv[i]) {
      case "--dir":
        dirs.push(argv[++i]);
        break;
      case "--v1-path":
        v1Path = argv[++i];
        break;
      case "--no-v1":
        includeV1 = false;
        break;
      case "--mocks":
        excludeMocks = false;
        break;
      case "--decl-sites":
        declSites = true;
        break;
      case "--deployed":
        deployedNetwork = argv[++i];
        if (!deployedNetwork) usage("--deployed requires a network name.");
        break;
      case "-h":
      case "--help":
        usage();
        break;
      default:
        positional.push(argv[i]);
    }
  }

  const targets = [...new Set(positional)];
  if (targets.length === 0) usage("Missing <ContractName> argument.");

  // Explicit --dir roots override the v1/v2 defaults.
  if (dirs.length > 0) {
    return { targets, sources: dirs.map((root) => ({ label: root, root })), excludeMocks, deployedNetwork, declSites };
  }

  const sources: Source[] = [];
  if (fs.existsSync(DEFAULT_V2_PATH)) sources.push({ label: "v2", root: DEFAULT_V2_PATH });
  if (includeV1) {
    if (fs.existsSync(v1Path)) {
      sources.push({ label: "v1", root: v1Path });
    } else {
      console.error(`Warning: v1 source not found at "${v1Path}" — scanning v2 only.`);
      console.error("(Run `pnpm install` to fetch the flare-smart-contracts dependency, or pass --v1-path.)\n");
    }
  }
  if (sources.length === 0) usage(`No source roots to scan (looked for "${DEFAULT_V2_PATH}").`);
  return { targets, sources, excludeMocks, deployedNetwork, declSites };
}

/**
 * Load the set of deployed `.sol` file names for a network from this repo's
 * `deployment/deploys/<network>.json`. This registry only tracks v2-era
 * deployments; v1 contracts are deployed from the flare-smart-contracts repo
 * and are not listed here.
 */
function loadDeployedContractNames(network: string): Set<string> {
  const file = path.join("deployment", "deploys", `${network}.json`);
  if (!fs.existsSync(file)) {
    usage(`Deploys registry not found: ${file} (valid networks: flare, songbird, coston, coston2).`);
  }
  const entries = JSON.parse(fs.readFileSync(file, "utf8")) as DeployEntry[];
  return new Set(entries.map((e) => e.contractName));
}

interface FacetMembership {
  diamond: string; // diamond that cuts this facet in, per the deploy script
  source: string; // deploy script the FACETS list was read from
}

/**
 * Map facet contract name -> the diamond that cuts it in, read from deploy
 * scripts. A diamond's facet set is decided at deploy time via `diamondCut`,
 * not by where a facet's .sol lives; the authoritative in-repo source is the
 * `FACETS = [...]` list in the deploy script that deploys the diamond (e.g.
 * deployment/scripts/deploy-flare-tee-manager.ts). We look for a `FACETS` array
 * in a deploy script that also names a known diamond root, and attribute those
 * facets to it. This reflects the deploy script, not live on-chain state.
 */
function loadFacetMembership(diamondRoots: Set<string>): Map<string, FacetMembership> {
  const membership = new Map<string, FacetMembership>();
  if (diamondRoots.size === 0 || !fs.existsSync("deployment")) return membership;
  for (const file of walkFiles("deployment", ".ts")) {
    const txt = fs.readFileSync(file, "utf8");
    const arr = /FACETS\s*=\s*\[([\s\S]*?)\]/.exec(txt);
    if (!arr) continue;
    const diamond = [...diamondRoots].find((n) => new RegExp(`\\b${n}\\b`).test(txt));
    if (!diamond) continue;
    const source = path.relative(process.cwd(), file);
    for (const q of arr[1].match(/"([^"]+)"|'([^']+)'/g) ?? []) {
      const name = q.slice(1, -1);
      if (!membership.has(name)) membership.set(name, { diamond, source });
    }
  }
  return membership;
}

/** Hedged note attributing a facet to its diamond, per the deploy FACETS list. */
function facetNote(def: ContractDef, membership: Map<string, FacetMembership>): string {
  const m = membership.get(def.name);
  return m ? `  (facet of ${m.diamond}? — per ${m.source})` : "";
}

/** The set of diamond root contract names (instantiable contracts inheriting `Diamond`). */
function diamondRootNames(index: Index): Set<string> {
  const roots = new Set<string>();
  for (const d of index.allDefs) {
    if (d.instantiable && ancestorsOf(d, index.nameToDefs).some((a) => a.name === "Diamond")) roots.add(d.name);
  }
  return roots;
}

/** Render a concrete user's line, with provenance for inherited dependencies. */
function renderUser(
  user: UserRecord,
  targets: string[],
  pad: number,
  dup: Set<string>,
  membership: Map<string, FacetMembership>
): string {
  const c = user.def;
  const ownLines = new Set<number>();
  const parts: string[] = [];
  for (const target of targets) {
    const use = user.uses.get(target);
    if (!use) continue;
    if (use.direct) {
      const own = use.contributors.find((cc) => cc.def === c);
      if (own) own.lines.forEach((l) => ownLines.add(l));
      parts.push(target);
    } else {
      const via = use.contributors.map((cc) => `${cc.def.file}:${cc.lines.join(",")}`).join("; ");
      parts.push(`${target} via ${via}`);
    }
  }
  const name = dup.has(c.file) ? ` [${c.name}]` : "";
  const facet = facetNote(c, membership);
  const linesStr = [...ownLines].sort((a, b) => a - b).join(",");
  const fileCol = ownLines.size > 0 ? `${c.file}:${linesStr}` : c.file;

  // Single target: keep it compact (matches the historical output for direct users).
  if (targets.length === 1) {
    const use = user.uses.get(targets[0])!;
    if (use.direct) return `  [${c.label.padEnd(pad)}] ${fileCol}${name}${facet}`;
    const via = use.contributors.map((cc) => `${cc.def.file}:${cc.lines.join(",")}`).join("; ");
    return `  [${c.label.padEnd(pad)}] ${c.file}${name}  (via ${via})${facet}`;
  }
  return `  [${c.label.padEnd(pad)}] ${fileCol}${name}  (uses: ${parts.join(", ")})${facet}`;
}

function main(): void {
  const { targets, sources, excludeMocks, deployedNetwork, declSites } = parseArgs();
  const index = buildIndex(sources, excludeMocks);
  const membership = loadFacetMembership(diamondRootNames(index));
  const multi = targets.length > 1;
  const quoted = targets.map((t) => `"${t}"`).join(", ");
  const anyOf = multi ? "any of " : "";
  let scanned = sources.map((s) => `${s.label} (${s.root})`).join(", ");
  if (excludeMocks) scanned += "; mocks excluded";

  // ---- Raw declaration-site view (--decl-sites): no inheritance resolution ----
  if (declSites) {
    const targetSet = new Set(targets);
    const rows: { def: ContractDef; target: string; lines: number[] }[] = [];
    for (const d of index.allDefs) {
      for (const t of d.refs.keys()) {
        if (targetSet.has(t)) rows.push({ def: d, target: t, lines: d.refs.get(t)! });
      }
    }
    console.log(`Declaration sites of ${anyOf}${quoted} (via AddressUpdater):`);
    console.log(`Scanned: ${scanned}`);
    console.log("");
    if (rows.length === 0) console.log("  (none)");
    const pad = Math.max(1, ...rows.map((r) => r.def.label.length));
    rows.sort((a, b) => a.def.file.localeCompare(b.def.file) || a.lines[0] - b.lines[0]);
    for (const r of rows) {
      const kind = r.def.isAbstract ? " (abstract)" : "";
      const attr = multi ? `  (${r.target})` : "";
      const facet = facetNote(r.def, membership);
      console.log(`  [${r.def.label.padEnd(pad)}] ${r.def.file}:${r.lines.join(",")}${kind}${attr}${facet}`);
    }
    console.log("");
    console.log(`Found ${rows.length} declaration site(s).`);
    return;
  }

  const { users, unresolved, missing, known } = collectUsers(targets, index);

  const printMissing = (): void => {
    if (missing.length > 0) console.log(`No users found for: ${missing.map((t) => `"${t}"`).join(", ")}`);
  };
  const printUnresolved = (pad: number): void => {
    if (unresolved.length === 0) return;
    console.log("");
    console.log("Declared only in abstract contract(s) with no concrete implementor in scan:");
    for (const u of unresolved) {
      const attr = multi ? `  (${u.target})` : "";
      console.log(`  [${u.def.label.padEnd(pad)}] ${u.def.file}:${u.lines.join(",")}  (${u.def.name})${attr}`);
    }
  };

  if (users.length === 0 && unresolved.length === 0) {
    console.log(`No contract resolves ${anyOf}${quoted} via the AddressUpdater.`);
    console.log(`Scanned: ${scanned}`);
    if (known.length > 0) {
      console.log("");
      console.log("Known dependency names (check spelling):");
      for (const name of known) console.log(`  ${name}`);
    }
    process.exit(0);
  }

  users.sort((a, b) => a.def.file.localeCompare(b.def.file) || a.def.name.localeCompare(b.def.name));
  const fileCount = new Map<string, number>();
  for (const u of users) fileCount.set(u.def.file, (fileCount.get(u.def.file) ?? 0) + 1);
  const dup = new Set([...fileCount.entries()].filter(([, n]) => n > 1).map(([f]) => f));
  const pad = Math.max(1, ...users.map((u) => u.def.label.length), ...unresolved.map((u) => u.def.label.length));

  // ---- Full source-tree view (default) ----
  if (!deployedNetwork) {
    console.log(`Contracts that use ${anyOf}${quoted} (via AddressUpdater):`);
    console.log(`Scanned: ${scanned}`);
    console.log("");
    for (const u of users) console.log(renderUser(u, targets, pad, dup, membership));

    const perLabel = new Map<string, number>();
    for (const u of users) perLabel.set(u.def.label, (perLabel.get(u.def.label) ?? 0) + 1);
    const breakdown = [...perLabel.entries()].map(([l, n]) => `${n} in ${l}`).join(", ");
    console.log("");
    console.log(`Found ${multi ? "union: " : ""}${users.length} contract(s)${breakdown ? ` (${breakdown})` : ""}.`);
    printUnresolved(pad);
    printMissing();
    return;
  }

  // ---- Deployed-filtered view (--deployed <net>) ----
  const deployed = loadDeployedContractNames(deployedNetwork);
  const isV2File = (rel: string): boolean => rel.split(path.sep)[0] === DEFAULT_V2_PATH;
  const live: UserRecord[] = [];
  const notDeployed: UserRecord[] = [];
  const unknown: UserRecord[] = [];
  for (const u of users) {
    if (!isV2File(u.def.file)) unknown.push(u);
    else if (deployed.has(path.basename(u.def.file))) live.push(u);
    else notDeployed.push(u);
  }

  console.log(`Contracts that use ${anyOf}${quoted} (via AddressUpdater), deployed on ${deployedNetwork}:`);
  console.log(`Scanned: ${scanned}; deployment filter: deployment/deploys/${deployedNetwork}.json`);
  console.log("");
  if (live.length === 0) console.log("  (none)");
  for (const u of live) console.log(renderUser(u, targets, pad, dup, membership));
  console.log("");
  console.log(`Found ${multi ? "union: " : ""}${live.length} contract(s) deployed on ${deployedNetwork}.`);

  if (notDeployed.length > 0) {
    console.log("");
    console.log(`Referenced in v2 source but NOT deployed on ${deployedNetwork}:`);
    for (const u of notDeployed) console.log(renderUser(u, targets, pad, dup, membership));
  }
  if (unknown.length > 0) {
    console.log("");
    console.log("Deployment status unknown (v1 — not tracked in this repo's registry):");
    for (const u of unknown) console.log(renderUser(u, targets, pad, dup, membership));
  }
  printUnresolved(pad);
  printMissing();
}

main();
