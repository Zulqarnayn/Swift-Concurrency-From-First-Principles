#!/usr/bin/env bash
# Run a demo with the Swift cooperative thread pool shrunk to ONE thread.
# Code that blocks a pool thread while waiting for other async work deadlocks immediately and every time,
# instead of "sometimes, under load, in production".
#
#   scripts/strict-pool.sh p1.03
#
# In Xcode: Scheme → Run → Arguments → Environment Variables → LIBDISPATCH_COOPERATIVE_POOL_STRICT = 1
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/ConcurrencyLab"
swift build -q
LIBDISPATCH_COOPERATIVE_POOL_STRICT=1 .build/debug/lab "$@"
