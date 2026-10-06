#!/usr/bin/env bash
# Copies the package to a temp dir, swaps in solutions/, runs the tests.
# Proves every exercise is solvable and every test is correct. Your own work is never touched.
# With no filter it also checks the Fixme exercises and Diagnostics expectations.
#
#   scripts/verify-solutions.sh            all tests
#   scripts/verify-solutions.sh P1_05      only matching tests
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/concurrencylab-verify.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

rsync -a --exclude .build --exclude .swiftpm "$ROOT/ConcurrencyLab/" "$WORK/ConcurrencyLab/"
cp "$ROOT"/solutions/Exercises/*.swift "$WORK/ConcurrencyLab/Sources/Exercises/"

cd "$WORK/ConcurrencyLab"
if [[ $# -gt 0 ]]; then
  swift test --filter "$1"
else
  swift test
  echo "── Fixme exercises"
  "$ROOT/scripts/fixme.sh" --verify
  echo "── Diagnostics expectations"
  "$ROOT/scripts/typecheck.sh" --check
fi
