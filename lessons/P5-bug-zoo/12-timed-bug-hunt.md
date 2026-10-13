# P5.12 — Timed bug hunt ⭐

<!-- nav:start -->
[← P5.11](./11-deterministic-testing.md) · [Roadmap](../../ROADMAP.md) · [P6.01 →](../P6-internals/01-executors.md)
<!-- nav:end -->

⏱ **25 min, timed.** Exercise `P5_12`

Interview-style debugging round. A small store module, four failing scenarios, no hints in the code, no bug report beyond the test names. Set a timer.

## Rules

1. Start the timer. Run:
   ```bash
   swift test --filter P5_12
   ```
2. For each failing scenario, **before touching code**, write one line in this file under *My notes*: the symptom, your hypothesis, and which P0–P5 pattern it is.
3. Fix it. Re-run. Move on.
4. At 25 minutes, stop, even if you aren't done. Then read the spoiler.
5. Finally `scripts/stress.sh P5_12 30`: a fix that passes once but fails under stress isn't done.

File: `Sources/Exercises/P5_12_BugHunt.swift`

## My notes

| Scenario | Symptom | Hypothesis | Pattern |
|---|---|---|---|
| A | | | |
| B | | | |
| C | | | |
| D | | | |

## Debrief

<details><summary>Spoiler: after the timer</summary>

| Scenario | Bug | Pattern | Fix |
|---|---|---|---|
| A | 10 concurrent requests for the same product → 10 fetches | Actor reentrancy at the cache (P2.04) | In-flight `Task` dictionary (single-flight) |
| B | Stock 1, 10 buyers → several succeed, stock negative | Check-then-act across awaits (P0.04, P2.04). The backend's check and reserve are separate calls, so the actor alone can't make them atomic | Serialize purchases (chain each buy after the previous one), or better, an atomic `reserveIfAvailable` on the backend |
| C | Orders charged out of order | One `Task` per event (P1.08) | One consumer task draining an AsyncStream |
| D | Cancelled poller keeps hammering, about 1,000 polls with no delay | `try?` swallowing cancellation (P4.11, P5.07) | `try await Task.sleep`; break when it throws; check `isCancelled` |

Scoring yourself, interview style:
- **Found all four in 25 minutes**, with a correct one-line diagnosis each: strong senior signal.
- **Fixed by adding sleeps or retries** without being able to name the pattern: that's what the round is designed to catch.
- **Named the pattern before reading the code** (from the symptom alone): that's what Phase 5 trains.
</details>

## Phase 5 checkpoint ✅

You can now: reproduce under pressure, make interleavings deterministic, draw timelines, and fix causes rather than symptoms; use TSan, Main Thread Checker, Instruments (Time Profiler with Hangs, Swift Concurrency), the Memory Graph and LLDB task commands; recognize the main families of async bugs: lost updates, duplicate and stale results, leaked and double-resumed continuations, pool starvation, Task retain cycles, swallowed cancellation, main-thread hangs from "async" code, and AsyncStream misuse; and read a crash report and name the cause.

Next: **Phase 6: internals** (executors, the runtime, the memory model), then **Phase 7: interview mastery.**

---

<!-- nav:start -->
[← P5.11](./11-deterministic-testing.md) · [Roadmap](../../ROADMAP.md) · [P6.01 →](../P6-internals/01-executors.md)
<!-- nav:end -->
