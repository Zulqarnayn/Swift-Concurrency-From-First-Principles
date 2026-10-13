# P3.12 — Review: structured concurrency puzzles ⭐

<!-- nav:start -->
[← P3.11](./11-unstructured-tasks.md) · [Roadmap](../../ROADMAP.md) · [P4.01 →](../P4-classics/01-producer-consumer.md)
<!-- nav:end -->

⏱ 30 min · Puzzles `Sources/Puzzles/StructuredPuzzles.swift` · Exercise `P3_12`

## 1. Puzzles (15 min)

Read `Sources/Puzzles/StructuredPuzzles.swift`. **Don't run.** Write the six sequences in `Sources/Exercises/P3_12_Predictions.swift`.

```bash
swift test --filter P3_12
swift run lab p3.12
```

<details><summary>Spoiler: after grading</summary>

| # | Answer | Why |
|---|---|---|
| 1 | `body, child cancelled, after scope` | An un-awaited `async let` is cancelled **and awaited** at scope end, so its log line lands *before* "after scope". |
| 2 | `B, C, A` | Completion order (10, 35, 60 ms), not submission order. |
| 3 | `slow done, caught` | **`waitForAll()` doesn't cancel siblings.** It waited 300 ms for "slow", then rethrew. With `for try await` / `next()`, you'd get `slow cancelled, caught`. The most surprising answer in the set; this one catches experienced engineers. |
| 4 | `async let cancelled, Task{} done` | Cancellation reaches structured children only. The inner `Task {}` is a new root. |
| 5 | `onCancel, operation` | Already cancelled → the handler runs immediately, before the operation starts. |
| 6 | `ada, anonymous, ada, anonymous` | `Task {}` and `async let` inherit the task-local, detached doesn't, and after `withValue` it's unbound. |
</details>

## 2. Flashcards (10 min)

`interview/flashcards.md` → **P3**, out loud.

## 3. One whiteboard question (5 min)

Answer out loud, in 2 minutes, then compare with the cards:
> "Fetch a user's profile, their 20 most recent posts, and a thumbnail for each post. At most 4 thumbnail downloads at a time. The whole thing should give up after 5 seconds, and stop immediately if the user leaves the screen. Walk me through the code."

(`async let` for profile + posts → a sliding-window TaskGroup for thumbnails → wrapped in `withTimeout` → started from `.task` so the view's lifetime cancels it → every leaf cooperative with cancellation.)

## Phase 3 checkpoint ✅

You can now explain: task trees; `async let` and its implicit cancel+await; TaskGroup ordering, errors and the `waitForAll` trap; sliding windows; discarding groups; cooperative cancellation and handlers; propagation and `.task(id:)`; structured timeouts and their limit; priority inheritance and escalation; `Task.yield`; task-locals; unstructured tasks, ordering and `Task.immediate`.

| P3 idea | Shows up again in |
|---|---|
| Sliding window | P4.04 async semaphore, P4.10 image cache |
| Cancel-previous + re-check | P4.06 debounce, P5.03 stale results |
| withTimeout | K4 kata (partial results with a deadline) |
| Cancellation handler | P4.07 token refresh, P5.07 swallowed cancellation |

Next: **Phase 4: classic concurrency problems.**

---

<!-- nav:start -->
[← P3.11](./11-unstructured-tasks.md) · [Roadmap](../../ROADMAP.md) · [P4.01 →](../P4-classics/01-producer-consumer.md)
<!-- nav:end -->
