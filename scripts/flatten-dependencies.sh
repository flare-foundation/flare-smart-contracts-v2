#!/bin/bash

set -e

if [ -z "$3" ]; then
    echo "$0 <subproject_dir> <listfile> <outfile> [<extra-imports>]"
    echo "    where <listfile> is a file containing list of input files"
    exit 1
fi

SUBPROJECT_DIR=$1
LISTFILE=$2
OUTFILE=$3
EXTRA_IMPORTS=$4

mapfile -t FILE_ARRAY < "$LISTFILE"
FIRSTFILE=$(head -n 1 "$LISTFILE")

TMPFILE="/tmp/$(basename "$OUTFILE")"

cd "$SUBPROJECT_DIR"
# TODO: Unsafe overrides used for compatibility with previous Yarn setup
pnpm_config_block_exotic_subdeps=false pnpm_config_strict_dep_builds=false pnpm install --ignore-workspace
cd - > /dev/null

HHCONFIG=()
if [[ "$SUBPROJECT_DIR" =~ flare-smart-contracts ]]; then
    HHCONFIG=(--config hardhatSetup.config.ts)
fi

if [ -n "$EXTRA_IMPORTS" ]; then
    cp "$EXTRA_IMPORTS" "$SUBPROJECT_DIR/contracts/extra-imports.sol"
    FILES=("contracts/extra-imports.sol" "${FILE_ARRAY[@]}")
else
    FILES=("${FILE_ARRAY[@]}")
fi

echo "Flattening to $OUTFILE..."
cd "$SUBPROJECT_DIR"
PRAGMA_SOLIDITY=$(grep '^pragma solidity' "$FIRSTFILE")
pnpm hardhat "${HHCONFIG[@]}" flatten "${FILES[@]}" > "$TMPFILE"
cd - > /dev/null

rm -f "$SUBPROJECT_DIR/contracts/extra-imports.sol"

mkdir -p "$(dirname "$OUTFILE")"
echo "// SPDX-License-Identifier: MIT" > "$OUTFILE"
echo "$PRAGMA_SOLIDITY" >> "$OUTFILE"
if grep '^pragma abicoder v2' "$TMPFILE" > /dev/null; then
    echo 'pragma abicoder v2;' >> "$OUTFILE"
fi
echo "" >> "$OUTFILE"
cat "$TMPFILE" | grep -v '^\$' | grep -v '^// SPDX-License-Identifier: MIT' | grep -v '^// SPDX-License-Identifier: Unlicense' | grep -v '^pragma solidity' | grep -v '^pragma abicoder v2' >> "$OUTFILE"
rm "$TMPFILE"
