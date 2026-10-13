# P1.04 — `Task`: the unit of async work

<!-- nav:start -->
[← P1.03](./03-cooperative-pool.md) · [Roadmap](../../ROADMAP.md) · [P1.05 →](./05-continuations.md)
<!-- nav:end -->

<!-- dek: A button tap is synchronous and the work it starts is not. `Task` is the bridge, and it keeps running after you let go of it. -->

⏱ 30 min · Demo `p1.04` · Exercise `P1_04`

## 1. Concept (5 min)

A button's action is a synchronous function, and the network call it should start is async. You can't `await` from the action, so you write `Task { await viewModel.load() }`. That creates a **task**: a unit of asynchronous work with its own lifetime, priority, cancellation flag and task-local values. It runs as jobs on executors (P1.02). It is not a thread.

Every async function runs inside some task. There are two ways to create one:

| | Structured (P3) | Unstructured |
|---|---|---|
| How | `async let`, `withTaskGroup` | `Task { }`, `Task.detached { }`, `Task.immediate { }` |
| Lifetime | Bounded by a scope: the parent waits for children | Independent. Lives until its body returns, even if nobody holds the handle |
| Cancellation | Propagates automatically from the parent | Only if *you* keep the handle and call `cancel()` |
| Use when | Concurrency inside one async function | Bridging sync → async (button tap, `viewDidLoad`, delegate callback) |

A `Task { }` starts soon, not now. It is *enqueued* on an executor, and the code after `Task { }` keeps running first. It inherits the creator's actor isolation (a task created on `@MainActor` runs on `@MainActor`), its priority and its task-local values; `Task.detached` inherits none of these. It gives you a handle of type `Task<Success, Failure>`: `await task.value` returns the result or rethrows the error, and `task.cancel()` requests cancellation. Dropping the handle doesn't cancel the task. It keeps running, which is what "fire and forget" means.

`Task.immediate { }` (Swift 6.2) runs the body synchronously, right now, on the caller's actor, up to its first real suspension. Use it when ordering matters, for example to start UI work before the current event handler returns.

The most common mistake with tasks is `Task { }` *inside an async function*. You were already async and could simply have used `await`. Wrapping the work in a task drops the guarantee that the work is done when you return, and loses its errors and cancellation along with it.

## 2. Predict (5 min)

All on `@MainActor`:
1. `trace("A"); let t = Task { trace("B") }; trace("C"); await t.value`. Order? ______
2. `trace("A"); Task.immediate { trace("B"); await …; trace("D") }; trace("C")`. Order? ______
3. From `@MainActor`, does `Task {}` run on MAIN? Does `Task.detached {}`? ______
4. A function creates a Task that prints after 100 ms, drops the handle, and returns. Does the print happen? ______

## 3. Run (5 min)

```bash
swift run lab p1.04
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
MAIN | A
MAIN | C
MAIN | B (inside Task)
MAIN | A
MAIN | B (inside Task.immediate)
MAIN | C
MAIN | D (Task.immediate after its first await)
MAIN | Task {}          runs here
T1   | Task.detached {} runs here
MAIN | startBackgroundWork() returned. The handle was dropped.
MAIN | ...still alive and finished its work 100ms later
```
1. A C B. The task is enqueued on the main actor, which is busy running *this* function until its next suspension (`await t.value`). It's the same shape as `DispatchQueue.main.async` called from main (P0.08 puzzle 1).
2. A B C D. `immediate` runs B synchronously; at its first `await`, control returns to the caller, which prints C; D comes later.
3. `Task {}` inherits `@MainActor`, so it runs on MAIN. `Task.detached {}` drops isolation, so it runs on the pool. Massicotte calls `Task.detached` "an advanced tool you rarely need": it drops priority and task-locals as well.
4. Yes. Unstructured tasks live until they finish, which makes it easy to leak work, for example a task that keeps a view model alive (P5).
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_04_Tasks.swift`.
1. `save` is fire-and-forget. Make `await save(...)` really mean "saved".
2. `startSaving` must start the work **without waiting** and return a handle whose `.value` is the note count.

```bash
swift test --filter P1_04
```

## 6. Interview cards

- **Task vs thread?** A Task is a unit of async work (priority, cancellation, task-locals, result) scheduled as jobs on executors. Thousands of tasks can share a handful of threads.
- **What does `Task {}` inherit? `Task.detached`?** `Task {}` inherits actor isolation, priority, and task-local values. `Task.detached` inherits none of them.
- **Does dropping a Task handle cancel it?** No. Unstructured tasks run to completion unless you call `cancel()` on the handle (and the work checks for cancellation).
- **When is `Task {}` appropriate?** At the sync → async boundary: UI events, lifecycle methods, delegate callbacks. Inside an async function, prefer `await` (or structured concurrency).
- **`Task {}` vs `Task.immediate {}`?** `Task {}` enqueues and starts later. `immediate` runs synchronously on the caller's actor until its first suspension.

## Going deeper
- [SE-0304 Structured concurrency](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md): the "Unstructured tasks" section
- [SE-0472 Task.immediate](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0472-task-start-synchronously-on-caller-context.md)
- Massicotte, [Problematic patterns](https://massicotte.org/problematic-patterns/) → "Task.detached", "Unstructured when structured works"

---

<!-- nav:start -->
[← P1.03](./03-cooperative-pool.md) · [Roadmap](../../ROADMAP.md) · [P1.05 →](./05-continuations.md)
<!-- nav:end -->
