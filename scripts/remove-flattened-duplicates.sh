#!/bin/bash

set -e

rm -rf artifacts/flare-sc
mkdir -p artifacts/flare-sc
cp artifacts/flattened/**/*.json artifacts/flare-sc

# duplicated files in flare-smart-contracts
if [[ "$OSTYPE" == "darwin"* ]]; then
   duplicates=$(find artifacts/ -name '*.json' -not -path 'artifacts/flattened/*/*' -not -path 'artifacts/flare-sc/*')
else
   duplicates=$(find artifacts/ -name '*.json' -not -path 'artifacts/flattened/*/*' -not -path 'artifacts/flare-sc/*' -printf '%f ')        # Unknown.
fi



# remove duplicates
cd artifacts/flare-sc
rm -f $duplicates
cd - > /dev/null
