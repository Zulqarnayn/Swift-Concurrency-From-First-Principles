# P3.11 — Unstructured tasks: when, ordering, `Task.immediate`

<!-- nav:start -->
[← P3.10](./10-task-locals.md) · [Roadmap](../../ROADMAP.md) · [P3.12 →](./12-review.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.11` · Exercise `P3_11`

## 1. Concept (5 min)

Structured concurrency is the default. Unstructured tasks are for one job: **starting async work from a place that isn't async** (or whose lifetime the current scope can't contain).

| Tool | Isolation | Priority / task-locals | Starts | Use for |
|---|---|---|---|---|
| `Task { }` | Inherits | Inherits | Enqueued ("soon") | UI events, lifecycle, delegates, "latest wins" (store the handle) |
| `Task.immediate { }` (6.2) | Inherits | Inherits | **Synchronously now**, until the first suspension | When work must *begin* before the sync caller returns |
| `Task.detached { }` | None | None | Enqueued | Rarely. Prefer `@concurrent` functions (Massicotte). |

**Ordering guarantees** (people assume more than exists):
- Several `Task {}` created **on the same actor** (e.g. main) **start** in creation order: they're enqueued FIFO on that actor. But they **interleave at every `await`**, so they don't *finish* in order (P1.08).
- `Task {}` created from **nonisolated** code start on the global pool in **no guaranteed order**.
- If you need ordering, use one consumer task with an AsyncStream (P1.08), or do the work sequentially in one task.

**`Task.immediate`** solves "the work must visibly start right now". A UIKit button handler is synchronous: with `Task {}`, the first line of the async work (`isLoading = true`, an analytics event) runs **after** the handler returns, possibly a frame later. `Task.immediate` runs it before the handler returns.

## 2. Predict (5 min)

1. 6 × `Task {}` created on the main actor, each logging its number: start order? ______
2. The same from a nonisolated task, repeated 20 times: how many distinct orders? ______
3. `log("before"); Task.immediate { log("body") }; log("after")`? ______

## 3. Run (5 min)

```bash
swift run lab p3.11
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
6 × Task {} created on the main actor started in order: 1 2 3 4 5 6
6 × Task {} created on a NONISOLATED task, 20 runs → 6 distinct start orders, e.g. 1 2 3 5 4 6
Task.immediate: ["before", "immediate body", "after"]
```
2. Six different orders in 20 runs. Code that "always worked" because two tasks happened to start in order will break in production.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_11_Immediate.swift`. Make `tap()` start the like operation (event + optimistic UI) before it returns.

```bash
swift test --filter P3_11
```

## 6. Interview cards

- **When is an unstructured task appropriate?** At the sync → async boundary (UI events, lifecycle, delegates), or when the work must outlive the current scope and you own its handle. Inside async code, prefer `async let` / groups.
- **Do `Task {}`s start in creation order?** On the same actor, yes (FIFO enqueue), but they interleave at awaits. From nonisolated code there's no order guarantee. Never rely on task ordering for correctness.
- **What is `Task.immediate`?** It starts a task that runs synchronously on the caller's actor until its first suspension. Use it when the work must begin before a synchronous caller returns.
- **Why avoid `Task.detached`?** It drops isolation, priority and task-locals, and usually a `@concurrent` function expresses "run off the actor" better.

## Going deeper
- [SE-0472 Starting tasks synchronously from caller context](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0472-task-start-synchronously-on-caller-context.md)
- Massicotte, [Problematic patterns](https://massicotte.org/problematic-patterns/) → "Unstructured When Structured Works", "Task.detached"

---

<!-- nav:start -->
[← P3.10](./10-task-locals.md) · [Roadmap](../../ROADMAP.md) · [P3.12 →](./12-review.md)
<!-- nav:end -->
