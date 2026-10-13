# P0.08 — Review: GCD output puzzles + spaced repetition

<!-- nav:start -->
[← P0.07](./07-blocking-vs-suspending.md) · [Roadmap](../../ROADMAP.md) · [P1.01 →](../P1-async-await/01-async-await.md)
<!-- nav:end -->

⏱ 30 min · Puzzles `Sources/Puzzles/GCDPuzzles.swift` · Exercise `P0_08`

"What does this print?" is the most common concurrency interview format. Today you predict five GCD programs, and **the test suite grades you**.

## 1. Flashcard review (10 min)

Open `interview/flashcards.md`, section **P0**. Cover each answer and say yours **out loud** (it's an interview; you need the words, not just the idea). Mark any you missed and redo them tomorrow.

## 2. Predict (10 min)

Read `Sources/Puzzles/GCDPuzzles.swift`. **Don't run anything.** For each puzzle, write the exact log sequence into `Sources/Exercises/P0_08_Predictions.swift`.

Hints, if you need them:
- Serial queues are FIFO: one block at a time, in submission order.
- `async` returns immediately. `sync` returns after the block has run.
- A barrier waits for everything submitted before it and blocks everything submitted after it.
- `notify` doesn't block; it schedules a block for "when the group empties".

## 3. Run → grade (5 min)

```bash
swift test --filter P0_08     # grades your predictions
swift run lab p0.08           # shows the real sequences
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after grading</summary>

| Puzzle | Answer | Why |
|---|---|---|
| 1 | `1, 3, 2` | `ui.async` from inside a `ui` block can't run until the current block finishes. Serial means one at a time. This is the same as `DispatchQueue.main.async` called from the main thread: it runs on a *later* turn of the run loop. |
| 2 | `A, B, C, D` | B is submitted first, so C (`sync`) queues **behind** B and waits for it even though B sleeps 20 ms. `sync` doesn't jump the queue. D waits for `sync` to return. |
| 3 | `slow read, write, read after write` | The barrier waits for the in-flight slow read; the read submitted after the barrier waits for the barrier. This is a **readers-writer lock** made from a concurrent queue (P4). |
| 4 | `after notify(), B, A, notify` | `notify` returns immediately. B (10 ms) beats A (60 ms). The notify block runs once both have called `leave()`. |
| 5 | `background, userInteractive` | **QoS doesn't reorder a serial queue.** FIFO wins. QoS only changes the priority of the thread that drains the queue (and can *raise* it: the high-QoS block boosts the background block ahead of it, which is priority-inversion avoidance). |

**Bonus (not testable, because it crashes):** what does this print, called on the main thread?
```swift
print("1"); DispatchQueue.main.sync { print("2") }; print("3")
```
→ `1`, then a deadlock. libdispatch detects it and crashes (P0.05).
</details>

## Phase 0 checkpoint ✅

You can now explain, from first principles: cores and threads; data races vs race conditions; atomics and CAS; locks and check-then-act; the four deadlock conditions; priority inversion and thread explosion; blocking vs suspending; why completion handlers are fragile.

Every one of these comes back in Swift-concurrency form:

| Phase 0 idea | Shows up again as |
|---|---|
| Data race | `Sendable`, isolation, Swift 6 errors (P2) |
| Check-then-act | **Actor reentrancy** (P2.04), the #1 actor bug |
| Deadlock | Blocking the cooperative pool (P1.03), continuations never resumed (P1.05) |
| Thread explosion | Why the cooperative pool has fixed width (P1.03) |
| Completion handlers | Continuations: `withCheckedContinuation` (P1.05) |
| Semaphore width limit | TaskGroup sliding window, async semaphore (P3, P4) |

Next: **P1.01 — what `async` and `await` actually mean.**

---

<!-- nav:start -->
[← P0.07](./07-blocking-vs-suspending.md) · [Roadmap](../../ROADMAP.md) · [P1.01 →](../P1-async-await/01-async-await.md)
<!-- nav:end -->
