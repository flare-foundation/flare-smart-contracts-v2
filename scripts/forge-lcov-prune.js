const fs = require("node:fs");
let forgeLcovFile = fs.readFileSync("lcov.info", "utf8");
let prunedForgeLcovPath = "lcov.info.pruned";
if (fs.existsSync(prunedForgeLcovPath)) {
  fs.unlinkSync(prunedForgeLcovPath);
}

let del = false;
for (let line of forgeLcovFile.split("\n")) {
  if (
    line.includes("flattened/FlareSmartContracts.sol") ||
    // The whole test tree, not just its mocks: tests are not the code under measurement, and
    // forge reports them like any other source. They currently sit below the contract average,
    // so leaving them in understated the figure rather than inflating it.
    line.includes("test-forge/") ||
    // Any mock tree, not just contracts/mock: seven more sit under contracts/<module>/mock/.
    line.includes("/mock/") ||
    line.includes("contracts/mock") ||
    // Soldeer dependencies: `forge coverage` can emit records for them, but genhtml reads every
    // source file it reports on, and the reports job gets only lcov.info - `dependencies/` is
    // gitignored and installed in the coverage job, not this one. Third-party code should not
    // count toward this repo's coverage anyway.
    line.includes("dependencies/") ||
    line.includes("node_modules/")
  ) {
    del = true;
  } else if (line.includes("end_of_record") && del) {
    del = false;
  } else if (!del) {
    fs.appendFileSync(prunedForgeLcovPath, line + "\n");
  }
}
