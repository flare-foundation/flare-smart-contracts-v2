#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/verify-tee-contracts.sh <network>
# Example: scripts/verify-tee-contracts.sh coston2

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <network> [mock]" >&2
  exit 2
fi

npx tsx deployment/scripts/verify-tee-contracts.ts "$@"
