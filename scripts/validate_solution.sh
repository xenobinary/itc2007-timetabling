#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/validate_solution.sh data/itc2007/comp01.ctt results/comp01.sol

INSTANCE="${1:-}"
SOLUTION="${2:-}"

if [[ -z "$INSTANCE" || -z "$SOLUTION" ]]; then
  echo "Usage: $0 <instance.ctt> <solution.sol>" >&2
  exit 1
fi

swipl -q -g "[src/validate], main(['--instance','$INSTANCE','--solution','$SOLUTION'])" -t halt
