#!/usr/bin/env bash
set -uo pipefail

# Usage:
#   scripts/benchmark.sh data/itc2007 results/bench

INST_DIR="${1:-data/itc2007}"
OUT_DIR="${2:-results/bench}"

mkdir -p "$OUT_DIR"

SUMMARY="$OUT_DIR/summary.csv"
echo "instance,feasible,penalty,seconds" > "$SUMMARY"

for f in "$INST_DIR"/*.ctt; do
  [ -e "$f" ] || { echo "No .ctt files found in $INST_DIR"; exit 1; }
  base=$(basename "$f")
  out="$OUT_DIR/${base%.ctt}.sol"
  start=$(date +%s)

  set +e
  swipl -q -g "[src/main], main(['--instance','$f','--out','$out','--csv','$OUT_DIR/${base%.ctt}.csv'])" -t halt
  rc=$?
  set -e

  end=$(date +%s)
  seconds=$((end-start))

  # main/1 also writes a per-instance csv; parse minimal fields if present
  if [[ -f "$OUT_DIR/${base%.ctt}.csv" ]]; then
    # expected header: feasible,penalty
    line=$(tail -n 1 "$OUT_DIR/${base%.ctt}.csv")
    feasible=$(echo "$line" | cut -d, -f1 | tr -d '\r')
    penalty=$(echo "$line" | cut -d, -f2 | tr -d '\r')
  else
    if [[ $rc -eq 0 ]]; then
      feasible="true"
      penalty="0"
    else
      feasible="false"
      penalty="unknown"
    fi
  fi

  echo "$base,$feasible,$penalty,$seconds" >> "$SUMMARY"
done

echo "Wrote $SUMMARY"
