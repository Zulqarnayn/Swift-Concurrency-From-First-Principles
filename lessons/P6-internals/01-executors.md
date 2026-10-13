# P6.01 — Executors: where jobs actually run

<!-- nav:start -->
[← P5.12](../P5-bug-zoo/12-timed-bug-hunt.md) · [Roadmap](../../ROADMAP.md) · [P6.02 →](./02-task-executors.md)
<!-- nav:end -->

⏱ 30 min · Demo `p6.01` · Exercise `P6_01`

## 1. Concept (8 min)

P1.02 introduced the vocabulary: a **task** is a chain of **jobs** (the partial functions between suspension points), and an **executor** runs jobs. This phase opens the box.

| Executor | Runs | Who uses it |
|---|---|---|
| **Global concurrent executor** | Jobs on the cooperative pool (≈ one thread per core) | nonisolated / `@concurrent` code, child tasks |
| **Main actor's executor** | Jobs on the main thread (via the main dispatch queue) | `@MainActor` code |
| **Default actor executor** | Each actor instance's jobs, **one at a time**, borrowing pool threads | every `actor` you write |
| **Custom serial executor** (SE-0392) | Whatever you decide: a DispatchQueue, a thread, a run loop | `nonisolated var unownedExecutor` on an actor |
| **Task executor** (SE-0417, next lesson) | Nonisolated work for a task tree | `withTaskExecutorPreference` |

An actor is, mechanically, **state + a serial executor**. Calling an actor method from outside means "enqueue a job on that actor's executor, and suspend until it has run".

**Why customize it?** You need an actor whose code runs on a specific queue or thread:
- **Legacy, thread-confined libraries**: SQLite connections, some C/C++ SDKs, Core Data-style confinement.
- **Interop**: existing GCD code is already on that queue and needs synchronous access to the actor's state.

```swift
actor Database {
    let queue = DispatchSerialQueue(label: "db")
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
}
```
`DispatchSerialQueue` conforms to `SerialExecutor` (iOS 17 / macOS 14+). Now every job of the actor runs on that queue, and code **already on the queue** can enter the actor **synchronously**:
```swift
db.queue.async { db.assumeIsolated { $0.handleLegacyCallback() } }   // no await, no hop
```
`assumeIsolated` checks at runtime that you really are on the actor's executor (P2.05, P5.10). Here that holds, because the actor's executor *is* the queue.

## 2. Predict (5 min)

1. An actor with `unownedExecutor` = a queue labeled "demo.legacy.queue". What does `currentQueueLabel()` report inside its method? ______
2. Can GCD code inside `queue.async { }` call `actor.assumeIsolated { }` without crashing? ______

## 3. Run (2 min)

```bash
swift run lab p6.01
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
actor method ran on queue: 'demo.legacy.queue'
legacy callback used assumeIsolated on the same queue → events: 2
```
Both work. Costs and cautions:
- A custom executor gives up the runtime's thread switching optimizations (calling an idle default actor can run the job right on the current pool thread, as P6.04 shows). Use it for a real reason.
- **Never `queue.sync` into the actor's queue from inside the actor**. That's P0.05's self-deadlock, reborn.
- Reentrancy is unchanged: at each `await`, the queue is free to run other jobs of the actor.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P6_01_CustomExecutor.swift`. Make every `QueueBoundDatabase` method run on the legacy queue with **one declaration**.

```bash
swift test --filter P6_01
```

## 6. Interview cards

- **What's an executor?** The component that runs a task's jobs. Default actors use the runtime's serial executors on the cooperative pool, the main actor uses the main thread, nonisolated code uses the global concurrent executor, and you can provide custom executors.
- **How do you make an actor run on a specific DispatchQueue, and why?** Implement `nonisolated var unownedExecutor` returning `queue.asUnownedSerialExecutor()` (`DispatchSerialQueue` is a `SerialExecutor`). Use it for thread-confined legacy libraries, and so GCD code already on that queue can use `actor.assumeIsolated` synchronously.
- **Does a custom executor change actor semantics?** No: still one job at a time, still reentrant at `await`. Only *where* jobs run changes, plus some lost optimizations.

## Going deeper
- [SE-0392 Custom Actor Executors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md)

---

<!-- nav:start -->
[← P5.12](../P5-bug-zoo/12-timed-bug-hunt.md) · [Roadmap](../../ROADMAP.md) · [P6.02 →](./02-task-executors.md)
<!-- nav:end -->
