# P4.12 — Review: pick the right tool ⭐

<!-- nav:start -->
[← P4.11](./11-retry-backoff.md) · [Roadmap](../../README.md) · [P5.01 →](../P5-bug-zoo/01-debugging-method.md)
<!-- nav:end -->

⏱ 30 min · Exercise `P4_12` (graded)

Most "concurrency design" interview questions are really one question: **which primitive fits this problem, and why?**

## 1. The toolbox (5 min)

| Need | Tool | Lesson |
|---|---|---|
| Protect UI state | `@MainActor` | P2.05 |
| Protect shared state, async callers OK | `actor` | P2.03 |
| Protect shared state, **sync** API, tiny critical sections | `Mutex` | P0.04 |
| N items, at most K at once, from **one** place | TaskGroup sliding window | P3.04 |
| A limit shared by **unrelated** call sites | Async semaphore | P4.04 |
| Producer faster than consumer, bounded memory | Bounded channel | P4.01 |
| Process events **in order** | One consumer task + AsyncStream | P1.08 |
| Many callers, one expensive operation | Single-flight (shared in-flight Task) | P4.07 |
| Act after events stop | Debounce | P4.06 |
| Act at most once per interval | Throttle | P4.06 |
| N per second, with bursts | Token bucket | P4.05 |
| Wait for N independent things | Countdown latch | P4.08 |
| Transient failures | Retry with backoff + jitter | P4.11 |
| Deadline | `withTimeout` | P3.08 |

## 2. Graded quiz (10 min)

Open `Sources/Exercises/P4_12_Toolbox.swift`. Pick one tool per scenario, then:
```bash
swift test --filter P4_12
```

<details><summary>Spoiler: reasons, after grading</summary>

| # | Answer | Why not the runner-up |
|---|---|---|
| 1 | `mainActor` | An actor would make the UI `await` its own state |
| 2 | `slidingWindow` | All 300 start from one screen's code: no shared semaphore needed |
| 3 | `asyncSemaphore` | Unrelated call sites share the limit, so a window inside one function can't see the others |
| 4 | `mutex` | Synchronous C callbacks can't `await` an actor; millions of calls want a cheap lock |
| 5 | `singleFlight` | A semaphore of 1 would refresh 20 times, one after another |
| 6 | `debounce` | Throttle would fire mid-typing |
| 7 | `throttle` | Debounce would never fire while the user keeps pulling |
| 8 | `boundedChannel` | AsyncStream would buffer frames without limit or drop them; the requirement says "slow the camera down" |
| 9 | `serialStream` | One Task per message reorders them (P1.08) |
| 10 | `tokenBucket` | A semaphore limits concurrency, not rate |
| 11 | `latch` | The loaders are independent subsystems, not children you started (otherwise: `async let`) |
| 12 | `retryBackoff` | — |
</details>

## 3. Design drill (10 min)

Out loud, 3 minutes each:
1. "Design the networking layer for an app with auth, retries and offline mode." (auth actor + single-flight refresh; retry policy; rate limiting; a request queue persisted while offline; cancellation tied to screens)
2. "Design an image loading library." (P4.10, plus disk cache, downsampling, prefetch priority)

## 4. Flashcards (5 min)

`interview/flashcards.md` → **P4**.

## Phase 4 checkpoint ✅

You can build, from first principles: bounded channels, readers–writer caches, deadlock-free resource acquisition, async semaphores, token buckets, debounce and throttle, single-flight, latches and barriers, the LeetCode set, an image pipeline, and retry with backoff. And for each one, you know the classic thread version and why it doesn't carry over to async code as-is.

Next: **Phase 5: the Bug Zoo**, where you debug systems built from these parts.

---

<!-- nav:start -->
[← P4.11](./11-retry-backoff.md) · [Roadmap](../../README.md) · [P5.01 →](../P5-bug-zoo/01-debugging-method.md)
<!-- nav:end -->
