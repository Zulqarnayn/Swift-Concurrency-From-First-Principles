#!/usr/bin/env bash
# Grade a "make it compile — correctly" exercise in ConcurrencyLab/Fixme/.
#
#   scripts/fixme.sh ConcurrencyLab/Fixme/P2_06_make_it_sendable.swift
#   scripts/fixme.sh --verify      (course maintenance: stubs must fail, solutions/Fixme must pass)
#
# A Fixme file passes when it compiles with ZERO errors and ZERO warnings, and contains none of the
# escape hatches listed on its `// FORBID:` line (checked outside comments). Shutting the compiler up
# with @unchecked Sendable or nonisolated(unsafe) is not a fix; it's a promise you can't check.
#
# Header lines:
#   // FLAGS:  -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
#   // FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

grade() { # file → prints report, returns 0 if passing
  local file="$1" out flags forbid status=0
  flags="$(grep -m1 '^// FLAGS:' "$file" | sed 's|^// FLAGS:||')"
  # shellcheck disable=SC2086
  out="$(xcrun swiftc $flags -parse-as-library -emit-sil -o /dev/null "$file" 2>&1)"
  local diags
  diags="$(grep -E '^[^ ].*:[0-9]+:[0-9]+: (error|warning):' <<<"$out" | sed -E 's|^.*/||; s/ \[#[A-Za-z]+\]$//')"
  if [[ -n "$diags" ]]; then
    echo "$diags"
    status=1
  fi
  forbid="$(grep -m1 '^// FORBID:' "$file" | sed 's|^// FORBID: *||')"
  if [[ -n "$forbid" ]]; then
    local code
    code="$(grep -v '^[[:space:]]*//' "$file" | sed 's|//.*$||')"
    IFS='|' read -ra tokens <<<"$forbid"
    for t in "${tokens[@]}"; do
      t="$(sed 's/^ *//; s/ *$//' <<<"$t")"
      [[ -z "$t" ]] && continue
      if grep -qF -- "$t" <<<"$code"; then
        echo "forbidden: '$t' (that silences the compiler instead of fixing the design)"
        status=1
      fi
    done
  fi
  return $status
}

if [[ "${1:-}" == "--verify" ]]; then
  bad=0
  for stub in "$ROOT"/ConcurrencyLab/Fixme/*.swift; do
    name="$(basename "$stub")"
    if grade "$stub" >/dev/null; then echo "✘ stub $name already passes"; bad=1; else echo "✔ stub $name fails as intended"; fi
    sol="$ROOT/solutions/Fixme/$name"
    if [[ ! -f "$sol" ]]; then echo "✘ no solution for $name"; bad=1; continue; fi
    if report="$(grade "$sol")"; then echo "✔ solution $name passes"; else echo "✘ solution $name: $report"; bad=1; fi
  done
  exit $bad
fi

file="${1:?usage: scripts/fixme.sh <Fixme/file.swift> | --verify}"
echo "── $(basename "$file")"
if grade "$file"; then
  echo "✅ PASS: compiles cleanly, no escape hatches."
else
  echo "❌ not yet."
  exit 1
fi
