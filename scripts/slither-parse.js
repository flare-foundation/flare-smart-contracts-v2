const fs = require("fs");
const { sortBy } = require("lodash");
const axios = require("axios")

const priorities = { High: 1, Medium: 2, Low: 3, Informational: 4, Optimization: 5 };

const colors = { High: '31;1', Medium: '33;1', Low: '32;1', Informational: '34;1', Optimization: '36;1' };

resultInfo = {
    "abiencoderv2-array": ["Storage abiencoderv2 array", "https://github.com/crytic/slither/wiki/Detector-Documentation#storage-abiencoderv2-array"],
    "array-by-reference": ["Modifying storage array by value", "https://github.com/crytic/slither/wiki/Detector-Documentation#modifying-storage-array-by-value"],
    "incorrect-shift": ["The order of parameters in a shift instruction is incorrect.", "https://github.com/crytic/slither/wiki/Detector-Documentation#shift-parameter-mixup"],
    "multiple-constructors": ["Multiple constructor schemes", "https://github.com/crytic/slither/wiki/Detector-Documentation#multiple-constructor-schemes"],
    "name-reused": ["Contract's name reused", "https://github.com/crytic/slither/wiki/Detector-Documentation#name-reused"],
    "public-mappings-nested": ["Public mappings with nested variables", "https://github.com/crytic/slither/wiki/Detector-Documentation#public-mappings-with-nested-variables"],
    "rtlo": ["Right-To-Left-Override control character is used", "https://github.com/crytic/slither/wiki/Detector-Documentation#right-to-left-override-character"],
    "shadowing-state": ["State variables shadowing", "https://github.com/crytic/slither/wiki/Detector-Documentation#state-variable-shadowing"],
    "suicidal": ["Functions allowing anyone to destruct the contract", "https://github.com/crytic/slither/wiki/Detector-Documentation#suicidal"],
    "uninitialized-state": ["Uninitialized state variables", "https://github.com/crytic/slither/wiki/Detector-Documentation#uninitialized-state-variables"],
    "uninitialized-storage": ["Uninitialized storage variables", "https://github.com/crytic/slither/wiki/Detector-Documentation#uninitialized-storage-variables"],
    "unprotected-upgrade": ["Unprotected upgradeable contract", "https://github.com/crytic/slither/wiki/Detector-Documentation#unprotected-upgradeable-contract"],
    "arbitrary-send-eth": ["Functions that send Ether to arbitrary destinations", "https://github.com/crytic/slither/wiki/Detector-Documentation#functions-that-send-ether-to-arbitrary-destinations"],
    "controlled-array-length": ["Tainted array length assignment", "https://github.com/crytic/slither/wiki/Detector-Documentation#array-length-assignment"],
    "controlled-delegatecall": ["Controlled delegatecall destination", "https://github.com/crytic/slither/wiki/Detector-Documentation#controlled-delegatecall"],
    "reentrancy-eth": ["Reentrancy vulnerabilities (theft of ethers)", "https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities"],
    "storage-array": ["Signed storage integer array compiler bug", "https://github.com/crytic/slither/wiki/Detector-Documentation#storage-signed-integer-array"],
    "unchecked-transfer": ["Unchecked tokens transfer", "https://github.com/crytic/slither/wiki/Detector-Documentation#unchecked-transfer"],
    "weak-prng": ["Weak PRNG", "https://github.com/crytic/slither/wiki/Detector-Documentation#weak-PRNG"],
    "enum-conversion": ["Detect dangerous enum conversion", "https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-enum-conversion"],
    "erc20-interface": ["Incorrect ERC20 interfaces", "https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-erc20-interface"],
    "erc721-interface": ["Incorrect ERC721 interfaces", "https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-erc721-interface"],
    "incorrect-equality": ["Dangerous strict equalities", "https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities"],
    "locked-ether": ["Contracts that lock ether", "https://github.com/crytic/slither/wiki/Detector-Documentation#contracts-that-lock-ether"],
    "mapping-deletion": ["Deletion on mapping containing a structure", "https://github.com/crytic/slither/wiki/Detector-Documentation#deletion-on-mapping-containing-a-structure"],
    "shadowing-abstract": ["State variables shadowing from abstract contracts", "https://github.com/crytic/slither/wiki/Detector-Documentation#state-variable-shadowing-from-abstract-contracts"],
    "tautology": ["Tautology or contradiction", "https://github.com/crytic/slither/wiki/Detector-Documentation#tautology-or-contradiction"],
    "write-after-write": ["Unused write", "https://github.com/crytic/slither/wiki/Detector-Documentation#write-after-write"],
    "boolean-cst": ["Misuse of Boolean constant", "https://github.com/crytic/slither/wiki/Detector-Documentation#misuse-of-a-boolean-constant"],
    "constant-function-asm": ["Constant functions using assembly code", "https://github.com/crytic/slither/wiki/Detector-Documentation#constant-functions-using-assembly-code"],
    "constant-function-state": ["Constant functions changing the state", "https://github.com/crytic/slither/wiki/Detector-Documentation#constant-functions-changing-the-state"],
    "divide-before-multiply": ["Imprecise arithmetic operations order", "https://github.com/crytic/slither/wiki/Detector-Documentation#divide-before-multiply"],
    "reentrancy-no-eth": ["Reentrancy vulnerabilities (no theft of ethers)", "https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-1"],
    "reused-constructor": ["Reused base constructor", "https://github.com/crytic/slither/wiki/Detector-Documentation#reused-base-constructors"],
    "tx-origin": ["Dangerous usage of `tx.origin`", "https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-usage-of-txorigin"],
    "unchecked-lowlevel": ["Unchecked low-level calls", "https://github.com/crytic/slither/wiki/Detector-Documentation#unchecked-low-level-calls"],
    "unchecked-send": ["Unchecked send", "https://github.com/crytic/slither/wiki/Detector-Documentation#unchecked-send"],
    "uninitialized-local": ["Uninitialized local variables", "https://github.com/crytic/slither/wiki/Detector-Documentation#uninitialized-local-variables"],
    "unused-return": ["Unused return values", "https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return"],
    "incorrect-modifier": ["Modifiers that can return the default value", "https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-modifier"],
    "shadowing-builtin": ["Built-in symbol shadowing", "https://github.com/crytic/slither/wiki/Detector-Documentation#builtin-symbol-shadowing"],
    "shadowing-local": ["Local variables shadowing", "https://github.com/crytic/slither/wiki/Detector-Documentation#local-variable-shadowing"],
    "uninitialized-fptr-cst": ["Uninitialized function pointer calls in constructors", "https://github.com/crytic/slither/wiki/Detector-Documentation#uninitialized-function-pointers-in-constructors"],
    "variable-scope": ["Local variables used prior their declaration", "https://github.com/crytic/slither/wiki/Detector-Documentation#pre-declaration-usage-of-local-variables"],
    "void-cst": ["Constructor called not implemented", "https://github.com/crytic/slither/wiki/Detector-Documentation#void-constructor"],
    "calls-loop": ["Multiple calls in a loop", "https://github.com/crytic/slither/wiki/Detector-Documentation/#calls-inside-a-loop"],
    "events-access": ["Missing Events Access Control", "https://github.com/crytic/slither/wiki/Detector-Documentation#missing-events-access-control"],
    "events-maths": ["Missing Events Arithmetic", "https://github.com/crytic/slither/wiki/Detector-Documentation#missing-events-arithmetic"],
    "incorrect-unary": ["Dangerous unary expressions", "https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-unary-expressions"],
    "missing-zero-check": ["Missing Zero Address Validation", "https://github.com/crytic/slither/wiki/Detector-Documentation#missing-zero-address-validation"],
    "reentrancy-benign": ["Benign reentrancy vulnerabilities", "https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-2"],
    "reentrancy-events": ["Reentrancy vulnerabilities leading to out-of-order Events", "https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3"],
    "timestamp": ["Dangerous usage of `block.timestamp`", "https://github.com/crytic/slither/wiki/Detector-Documentation#block-timestamp"],
    "assembly": ["Assembly usage", "https://github.com/crytic/slither/wiki/Detector-Documentation#assembly-usage"],
    "assert-state-change": ["Assert state change", "https://github.com/crytic/slither/wiki/Detector-Documentation#assert-state-change"],
    "boolean-equal": ["Comparison to boolean constant", "https://github.com/crytic/slither/wiki/Detector-Documentation#boolean-equality"],
    "deprecated-standards": ["Deprecated Solidity Standards", "https://github.com/crytic/slither/wiki/Detector-Documentation#deprecated-standards"],
    "erc20-indexed": ["Un-indexed ERC20 event parameters", "https://github.com/crytic/slither/wiki/Detector-Documentation#unindexed-erc20-event-parameters"],
    "function-init-state": ["Function initializing state variables", "https://github.com/crytic/slither/wiki/Detector-Documentation#function-initializing-state-variables"],
    "low-level-calls": ["Low level calls", "https://github.com/crytic/slither/wiki/Detector-Documentation#low-level-calls"],
    "missing-inheritance": ["Missing inheritance", "https://github.com/crytic/slither/wiki/Detector-Documentation#missing-inheritance"],
    "naming-convention": ["Conformity to Solidity naming conventions", "https://github.com/crytic/slither/wiki/Detector-Documentation#conformance-to-solidity-naming-conventions"],
    "pragma": ["If different pragma directives are used", "https://github.com/crytic/slither/wiki/Detector-Documentation#different-pragma-directives-are-used"],
    "redundant-statements": ["Redundant statements", "https://github.com/crytic/slither/wiki/Detector-Documentation#redundant-statements"],
    "solc-version": ["Incorrect Solidity version", "https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-versions-of-solidity"],
    "unimplemented-functions": ["Unimplemented functions", "https://github.com/crytic/slither/wiki/Detector-Documentation#unimplemented-functions"],
    "unused-state": ["Unused state variables", "https://github.com/crytic/slither/wiki/Detector-Documentation#unused-state-variables"],
    "costly-loop": ["Costly operations in a loop", "https://github.com/crytic/slither/wiki/Detector-Documentation#costly-operations-inside-a-loop"],
    "dead-code": ["Functions that are not used", "https://github.com/crytic/slither/wiki/Detector-Documentation#dead-code"],
    "reentrancy-unlimited-gas": ["Reentrancy vulnerabilities through send and transfer", "https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-4"],
    "similar-names": ["Variable names are too similar", "https://github.com/crytic/slither/wiki/Detector-Documentation#variable-names-are-too-similar"],
    "too-many-digits": ["Conformance to numeric notation best practices", "https://github.com/crytic/slither/wiki/Detector-Documentation#too-many-digits"],
    "constable-states": ["State variables that could be declared constant", "https://github.com/crytic/slither/wiki/Detector-Documentation#state-variables-that-could-be-declared-constant"],
    "external-function": ["Public function that could be declared external", "https://github.com/crytic/slither/wiki/Detector-Documentation#public-function-that-could-be-declared-external"],
};

if (!process.argv[2]) {
    console.error("Usage: node scripts/slither-parse.js <slither.json>");
}

const json = fs.readFileSync(process.argv[2], 'utf-8');
const data = JSON.parse(json);

let BadgeStorageURL = ""
if (process.env.BADGE_URL) {
  BadgeStorageURL = process.env.BADGE_URL
}


if (!data.success) {
    process.exit(0);
}

let detectors = (data.results && data.results.detectors) || [];
detectors = detectors.filter(det => det.impact in priorities);
detectors = sortBy(detectors, det => [priorities[det.impact], priorities[det.confidence]]);

const counts = {};

for (const det of detectors) {
    counts[det.impact] = (counts[det.impact] || 0) + 1;
    const [info, link] = resultInfo[det.check] || [det.check, null];
    console.log(`\u001b[${colors[det.impact]}m${info}  ('${det.check}', impact: ${det.impact}, confidence: ${det.confidence}):\u001b[0m`);
    const description = (det.description || '').trim()
        .replace(/([\w\/\.\@]+)\#(\d+)(-\d+)?/g, "\u001b[33;1m$1:$2$3\u001b[0m");
    console.log('   ', description);
    if (link) console.log(`\u001b[34m${link}`)
    console.log(`\u001b[0m`);
}

console.log("TOTALS by impact:");
for (const [type, count] of Object.entries(counts)) {
    console.log(`    ${type}: ${count}`);
}

process.exit(counts['High'] || 0);
