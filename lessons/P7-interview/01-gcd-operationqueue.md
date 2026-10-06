# P7.01 — The GCD & OperationQueue round

<!-- nav:start -->
[← P6.08](../P6-internals/08-distributed-actors.md) · [Roadmap](../../README.md) · [P7.02 →](./02-output-marathon.md)
<!-- nav:end -->

⏱ 30 min · Exercise `P7_01` · Bank: `interview/question-bank.md` → GCD section

Plenty of iOS interviews still open with GCD, and many production codebases still run on it. You came in strong here. This session makes the answers crisp and adds **OperationQueue**, which is often under-practiced.

## 1. Rapid fire (10 min, out loud, 1 minute each)

Answer from `interview/question-bank.md` → *GCD and OperationQueue* (questions 1–12) without looking. Then check. Aim for **definition → mechanism → pitfall** in under a minute.

## 2. OperationQueue in one table (5 min)

| Need | GCD | OperationQueue |
|---|---|---|
| Limit width | semaphore (P0.06) | `maxConcurrentOperationCount` |
| "B after A" | nest blocks or `DispatchGroup.notify` | `b.addDependency(a)`, even across queues |
| Cancel not-yet-started work | `DispatchWorkItem.cancel()` | `cancelAllOperations()` / `op.cancel()` |
| Cancel running work | check a flag | check `isCancelled` in `main()` (cooperative, like tasks) |
| Observe state | — | KVO on `isExecuting`/`isFinished`; `completionBlock` |
| Async work inside an operation | — | an *asynchronous* `Operation` subclass that manages `isExecuting`/`isFinished` itself (a classic interview drill) |

Traps:
- **Cancelling an operation does not cancel its dependents.** A cancelled op still "finishes", and its dependents become ready and run. Cancel the whole chain, or check dependencies' `isCancelled`.
- `waitUntilAllOperationsAreFinished()` **blocks**: never on main, never in async code.
- A dependency cycle means none of those operations ever becomes ready: a silent deadlock.

## 3. Exercise (12 min)

File: `Sources/Exercises/P7_01_Operations.swift`. Per file: download → parse → save, in order; at most 2 operations at a time; `cancelAll()` stops everything not yet started.

```bash
swift test --filter P7_01
```

## 4. Modern equivalent (3 min)

Say how you'd write the same pipeline in Swift concurrency. (A TaskGroup with a sliding window of 2 (P3.04), each child running `download → parse → save` sequentially as an `async` function. Cancellation comes from the parent task, and there's no dependency graph to manage, because order is just code order.) Then say why a team might *keep* OperationQueue: existing code, KVO-based progress UI, cross-queue dependencies, and the cost of migrating.

## 5. Interview cards

- **OperationQueue vs GCD?** OperationQueue adds dependencies (even across queues), a max-concurrency limit, cancellation state, KVO-observable state, and reusable operation objects. GCD is lower-level, lighter and block-based. Both run on GCD's thread pool.
- **How do you cancel an operation pipeline correctly?** `cancelAllOperations()` (or cancel every op in the chain). Cancelling one op doesn't stop its dependents, since a cancelled op still finishes. Running ops must check `isCancelled` themselves.
- **How do you implement an asynchronous Operation?** Subclass `Operation`, override `isAsynchronous`, `isExecuting` and `isFinished` with thread-safe storage and KVO notifications, start the async work in `start()`, and mark finished in its completion. Forgetting KVO means the queue never sees it finish.

---

<!-- nav:start -->
[← P6.08](../P6-internals/08-distributed-actors.md) · [Roadmap](../../README.md) · [P7.02 →](./02-output-marathon.md)
<!-- nav:end -->
