# P1.10 — Review: async output puzzles + spaced repetition

<!-- nav:start -->
[← P1.09](./09-lab-convert-gcd.md) · [Roadmap](../../ROADMAP.md) · [P2.01 →](../P2-isolation/01-network-request-lab.md)
<!-- nav:end -->

⏱ 30 min · Puzzles `Sources/Puzzles/AsyncPuzzles.swift` · Exercise `P1_10`

## 1. Flashcard review (10 min)

`interview/flashcards.md`: re-do the P0 cards you missed, then all of P1, **out loud**.

## 2. Predict (10 min)

Read `Sources/Puzzles/AsyncPuzzles.swift`. **Don't run.** Write all 8 sequences in `Sources/Exercises/P1_10_Predictions.swift`.

Puzzle 4 is the deepest one. Think about what `await` *promises*.

## 3. Grade (5 min)

```bash
swift test --filter P1_10
swift run lab p1.10
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after grading</summary>

| # | Answer | Why |
|---|---|---|
| 1 | `A C B` | `Task {}` enqueues on the main actor, which is busy until this function suspends at `await task.value`. |
| 2 | `A B C D` | `Task.immediate` runs synchronously until its first suspension (`Task.yield()`), then the caller continues. |
| 3 | `1a 2a 2b 1b` | Both tasks are on the main actor and interleave **at awaits**: 1a runs then suspends (60 ms), 2a runs then suspends (10 ms), 2b wakes first, 1b last. This is what "reentrancy" will mean for actors: other work runs *on the same actor* while you're suspended. |
| 4 | `A X C B` | **`await` marks a *possible* suspension, not a guaranteed one.** `sameActorWork` is on the main actor, the caller is already there, so there's no hop and nothing suspends. X runs inline, then C. B only runs when the main actor is finally released (`await task.value`). |
| 5 | `3 4` | `bufferingNewest(2)` kept the last two of 1–4. |
| 6 | `1 2, after loop, yield 4: enqueued` | `break` doesn't terminate a stream still referenced by `stream`. The producer keeps buffering into nothing. No `onTermination` yet. |
| 7 | `1 2 onTermination, after loop, yield 4: terminated` | The stream was owned only by the loop's iterator. `break` destroyed it, so termination fires **synchronously at the break**, and later `yield`s are rejected. |
| 8 | `start, task throws, end` | The thrown error vanished silently. Nobody awaited `task.value`. |

**Puzzle 4 in one sentence for interviews:** "`await` is a *potential* suspension point; calling an async function on the actor you're already on doesn't hop and may not suspend at all."
</details>

## Phase 1 checkpoint ✅

You can now explain: suspension vs blocking; async frames and continuations; the cooperative pool's contract and how to break it; Task lifetimes and inheritance; continuations and exactly-once; AsyncStream buffering, unicast and termination; async error pitfalls; ordering at the sync/async boundary.

**What's still magic:** *why* `@MainActor` code always runs on main, what `@concurrent` and "plain async runs where the caller is" really mean, why the compiler rejects some captures and not others (`Sendable`), and what actors are. That's **Phase 2: Isolation**, the heart of Swift concurrency.

P2 opens in the iOS app (`ConcurrencyLabApp`) with the Massicotte network-request lab.

---

<!-- nav:start -->
[← P1.09](./09-lab-convert-gcd.md) · [Roadmap](../../ROADMAP.md) · [P2.01 →](../P2-isolation/01-network-request-lab.md)
<!-- nav:end -->
