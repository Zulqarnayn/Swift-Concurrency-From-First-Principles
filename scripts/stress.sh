#!/usr/bin/env bash
# Run a test filter many times. Concurrency bugs are probabilistic: one green run proves little.
#
#   scripts/stress.sh P0_04            20 runs
#   scripts/stress.sh P0_04 100        100 runs
#   scripts/stress.sh P0_02 20 --tsan  20 runs under Thread Sanitizer (slower, catches races that "passed")
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILTER="${1:?usage: scripts/stress.sh <test filter> [runs] [--tsan]}"
RUNS="${2:-20}"
SAN=()
[[ "${3:-}" == "--tsan" ]] && SAN=(--sanitize=thread)

cd "$ROOT/ConcurrencyLab"
swift build --build-tests -q ${SAN[@]+"${SAN[@]}"} || exit 1

fails=0
for ((i = 1; i <= RUNS; i++)); do
  if out="$(swift test --skip-build ${SAN[@]+"${SAN[@]}"} --filter "$FILTER" 2>&1)" && ! grep -q "ThreadSanitizer" <<<"$out"; then
    printf '.'
  else
    printf 'F'
    fails=$((fails + 1))
    last="$out"
  fi
done
echo
echo "$FILTER: $fails / $RUNS runs failed"
if [[ $fails -gt 0 ]]; then
  echo "── last failing run (tail) ──"
  tail -25 <<<"$last"
  exit 1
fi
