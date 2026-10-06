#!/usr/bin/env bash
# Compile one Diagnostics/*.swift file standalone and show what the Swift compiler says about it.
# These files are deliberately broken, so they live OUTSIDE the package build.
#
#   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P0_02_racy_counter.swift          one-line diagnostics
#   scripts/typecheck.sh --full ConcurrencyLab/Diagnostics/P0_02_racy_counter.swift   compiler's full output
#   scripts/typecheck.sh --check                                                      verify all EXPECT lines
#
# Each file declares its compiler flags and expected diagnostics in header comments:
#   // FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
#   // EXPECT: error: 'async' call in a function that does not support concurrency
#
# Why -emit-sil and not -typecheck: some concurrency errors (region-based isolation, `sending`)
# are found in a later compiler phase (SIL). `-typecheck` stops too early and silently misses them.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIAG_DIR="$ROOT/ConcurrencyLab/Diagnostics"

compile() {
  local file="$1"
  local flags
  flags="$(grep -m1 '^// FLAGS:' "$file" | sed 's|^// FLAGS:||')"
  # shellcheck disable=SC2086
  xcrun swiftc $flags -parse-as-library -emit-sil -o /dev/null "$file" 2>&1
}

brief() {
  grep -E '^[^ ].*:[0-9]+:[0-9]+: (error|warning):' | sed -E 's|^.*/||; s/ \[#[A-Za-z]+\]$//'
}

if [[ "${1:-}" == "--check" ]]; then
  status=0
  for file in "$DIAG_DIR"/*.swift; do
    out="$(compile "$file")"
    while IFS= read -r expect; do
      [[ -z "$expect" ]] && continue
      if grep -qF -- "$expect" <<<"$out"; then
        echo "✔ $(basename "$file"): $expect"
      else
        echo "✘ $(basename "$file"): missing → $expect"
        status=1
      fi
    done < <(grep '^// EXPECT:' "$file" | sed 's|^// EXPECT: *||')
  done
  exit $status
fi

full=0
if [[ "${1:-}" == "--full" ]]; then full=1; shift; fi
file="${1:?usage: scripts/typecheck.sh [--full] <file.swift> | --check}"

echo "── swiftc $(grep -m1 '^// FLAGS:' "$file" | sed 's|^// FLAGS: *||') $(basename "$file")"
out="$(compile "$file")"
if [[ $full -eq 1 ]]; then
  echo "$out"
else
  lines="$(brief <<<"$out")"
  if [[ -z "$lines" ]]; then echo "(no diagnostics — it compiles)"; else echo "$lines"; fi
fi
