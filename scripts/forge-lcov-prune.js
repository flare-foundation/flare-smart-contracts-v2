const fs = require("node:fs");
let forgeLcovFile = fs.readFileSync('lcov.info','utf8');
let prunedForgeLcovPath = 'lcov.info.pruned';
if (fs.existsSync(prunedForgeLcovPath)) {
  fs.unlinkSync(prunedForgeLcovPath);
}

let del = false;
for (let line of forgeLcovFile.split('\n')) {
  if (line.includes('flattened/FlareSmartContracts.sol') || line.includes('test-forge/mock/') || line.includes('contracts/mock')) {
    del = true;
  } else if (line.includes('end_of_record') && del) {
    del = false;
  } else if (!del){
    fs.appendFileSync(prunedForgeLcovPath, line + '\n');
  }
}

