# P7.02 — "Explain the output" marathon ⭐

<!-- nav:start -->
[← P7.01](./01-gcd-operationqueue.md) · [Roadmap](../../ROADMAP.md) · [P7.03 →](./03-kata-fetch-all.md)
<!-- nav:end -->

⏱ **20 minutes for 10 puzzles** (timed), plus 10 min of debrief · Puzzles `Sources/Puzzles/MarathonPuzzles.swift` · Exercise `P7_02`

Mixed GCD, async/await, actors and structured concurrency: the format interviewers use most. Two minutes per puzzle. **Explain out loud** as you go, as if someone were listening.

## Rules

1. Start a 20-minute timer. Read `MarathonPuzzles.swift` one puzzle at a time.
2. Write each answer in `Sources/Exercises/P7_02_Marathon.swift`, *and* say the one-sentence reason.
3. When time's up:
   ```bash
   swift test --filter P7_02
   swift run lab p7.02
   ```
4. For every miss, find the lesson it came from in the table below and re-read its spoiler.

## Debrief

<details><summary>Spoiler: after grading</summary>

| # | Answer | One-sentence reason | Lesson |
|---|---|---|---|
| 1 | `a c b d` | `async` onto the serial queue you're on runs after the current block; the later `sync` queues behind `b` | P0.08 |
| 2 | `A B C` | `@concurrent` leaves the main actor, so the queued Task runs during the await | P2.16 #6 |
| 3 | `start, b done, b, a done, a` | both children start immediately; `await b` (10 ms) returns before `a` (50 ms) finishes | P3.02 |
| 4 | `10 done, cancelled: 2` | the first finisher wins; `cancelAll()` makes the sleeping siblings throw | P3.03 |
| 5 | `1 2` | `bufferingOldest(2)` keeps the first two and drops newer values | P1.06 |
| 6 | `operation, after` | nobody cancelled the task, so `onCancel` never runs | P3.06 |
| 7 | `body, stubborn done, after` | an un-awaited `async let` is cancelled **and awaited**; a child that ignores cancellation delays the scope | P3.02 |
| 8 | `Vault, nonisolated` | a plain async func runs on the caller's actor (nonsending); `@concurrent` never does | P2.08 |
| 9 | `0 1 2 3 4` | `Task { @MainActor in }` is enqueued on main at creation, in order | P6.06 |
| 10 | `slow cancelled, caught` | `for try await` rethrows the error out of the group body, so siblings are cancelled (unlike `waitForAll`) | P3.03, P3.12 |

Scoring: **9–10** interview-ready · **7–8** solid, review the misses · **≤6** redo P1.10, P2.16, P3.12 first.
</details>

## Interview technique (re-read before every interview)

1. **State the model first**: "serial queue, so FIFO", "we're on the main actor, so…", "`@concurrent` leaves the actor".
2. **Mark every `await`**: could it suspend? Who can run meanwhile?
3. **Separate start order from finish order.**
4. **If it's nondeterministic, say so**, and list which orders are possible. Saying "it depends, here's on what" is usually the answer they're looking for.

---

<!-- nav:start -->
[← P7.01](./01-gcd-operationqueue.md) · [Roadmap](../../ROADMAP.md) · [P7.03 →](./03-kata-fetch-all.md)
<!-- nav:end -->
