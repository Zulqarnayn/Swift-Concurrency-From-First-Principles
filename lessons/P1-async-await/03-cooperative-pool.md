# P1.03 — The cooperative thread pool: never block it ⭐

<!-- nav:start -->
[← P1.02](./02-under-the-hood.md) · [Roadmap](../../ROADMAP.md) · [P1.04 →](./04-task.md)
<!-- nav:end -->

<!-- dek: GCD answers a blocked thread by starting another one. Swift concurrency refuses, and asks you to keep a promise in return. -->

⏱ 30 min · Demo `p1.03` (+ opt-in `p1.03c`) · Diagnostics `P1_03_blocking_in_async.swift` · Exercise `P1_03`

## 1. Concept (5 min)

In P0.06, GCD reacted to every blocked block by creating another thread, and you got thread explosion. Swift concurrency makes the opposite trade:

> The **cooperative pool** (the global concurrent executor) has **about one thread per core** and **never adds more**.

That means no explosion, little context switching and a small memory footprint. In exchange, the runtime assumes every task makes forward progress: it either runs or suspends, and never blocks waiting for something else to happen. That assumption is the "cooperative" part, a contract between you and the runtime.

Break the contract and you get one of two failures. The first is starvation: blocked threads reduce the pool's throughput, and blocking 1 of 8 threads removes 12.5% of all async capacity. The second is deadlock: a task blocks waiting for work that needs a pool thread to run, and if every pool thread is in that state, nothing can ever wake them. GCD would have spawned a rescue thread. The cooperative pool won't.

These break the contract:

- `DispatchSemaphore.wait()`, `DispatchGroup.wait()`, `Thread.sleep`, `usleep`: anything that waits for a *future* event
- Synchronous I/O: `Data(contentsOf:)` on a URL, synchronous reads of large files, synchronous XPC
- Holding a lock while waiting for async work. Short locks around memory are fine, because they are held, not waited on.
- The "sync wrapper": `semaphore.wait()` inside a sync helper that bridges to async. The compiler bans the direct call in async code, but it can't see through a sync function.

To find these bugs, set the environment variable `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` (in Xcode: Scheme → Run → Arguments → Environment). It shrinks the pool to one thread, so any task that blocks waiting on another task deadlocks immediately, every time. You find the bug before your users do.

> A real bug from building this course: Swift Testing runs even *synchronous* `@Test` functions on the cooperative pool. The first version of this repo's P0 tests blocked with semaphores inside sync tests, starved the pool, and made unrelated async tests time out at random, ~1.1 s each. The fix is in `LabKit/Timeout.swift` → `onDedicatedThread`: run blocking code on its own OS thread and `await` the result.

## 2. Predict (5 min)

1. 64 tasks each **suspend** 200 ms. How many distinct threads run them? Total time? ______
2. 64 tasks each **block** 200 ms. How many threads? Total time? (Compare P0.06: GCD used 64 threads and 300 ms.) ______
3. `p1.03c`: 16 tasks each wait on a semaphore (via a sync helper). A 17th task will signal it 16 times. What happens? ______
4. Under `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`, how long does the 64×200 ms blocking test take? ______
5. `Diagnostics/P1_03_blocking_in_async.swift`, calls A–H: which are compile errors? ______

## 3. Run (5 min)

```bash
swift run lab p1.03
swift run lab p1.03c                       # opt-in deadlock, a watchdog ends it after 3s
scripts/strict-pool.sh p1.03               # from repo root; takes ~13s
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P1_03_blocking_in_async.swift
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
64 tasks SUSPENDING 200ms: 5 threads, 211ms   (cores: 8)
64 tasks BLOCKING 200ms:   8 threads, 1633ms
```
1. At most 8 threads (≤ 8) and about 200 ms. Suspended tasks hold no thread, so a handful of threads juggle all 64.
2. 8 threads and about 1.6 s (64 × 200 / 8). There is no explosion, but it is 8× slower than GCD here: the pool refuses to grow, and blocking just queues everything behind it.
3. Deadlock. The first 8 tasks take all 8 pool threads and park in `wait()`. The signaller is a task too, so it needs a pool thread, and none are left. The watchdog, a plain OS thread outside the pool, reports it after 3 s. Under GCD this would have worked, because GCD would have started a ninth thread.
4. About 13 s: one thread, 64 × 200 ms in sequence. Strict mode turns *"slow under load"* into *"obviously broken in the debugger"*.
5. The compile errors are **A** (`semaphore.wait`), **B** (`group.wait`), **C** (`Thread.sleep`) and **E** (`NSLock.lock()`/`unlock()`, with *"Use async-safe scoped locking instead"*, meaning `lock.withLock { }`, so that the lock can't be held across an `await`).

   Not caught: **D** (`usleep`), **F** (synchronous network I/O) and **G/H** (the sync-helper loophole). The compiler's checks are a seatbelt, not an autopilot.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_03_NeverBlock.swift`. `total(for:)` uses a "sync wrapper" bridge. Under concurrent load it deadlocks (a 1 s escape hatch keeps your test run from hanging). Fix it.

```bash
swift test --filter P1_03
```

Then ask yourself: if old synchronous code really needs that price, what are its honest options? It can become async, or it can start a `Task` and deliver the result later through a callback or a state update. It must never wait.

## 6. Interview cards

- **What is the cooperative thread pool and why is it fixed-size?** The global concurrent executor runs tasks on about one thread per core and never overcommits. That avoids thread explosion and context switching. The trade-off: tasks must never block.
- **Why can't you use a semaphore to wait for async work?** The waiting thread is a pool thread. If the work it waits for needs a pool thread and all of them are waiting, it deadlocks, and the pool won't add threads to break the cycle. Semaphores also don't donate priority (inversion).
- **How do you find blocking in async code?** `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` (pool width 1, so blocking deadlocks deterministically), the Instruments Swift Concurrency template (tasks stuck "running" while doing nothing), hang detection, and code review for sync wrappers around async APIs.
- **Is a lock OK in async code?** A short critical section around in-memory state, yes (`Mutex.withLock`, `NSLock.withLock`). Never hold a lock across an `await`, and never use a lock or semaphore to *wait for* other async work.

## Going deeper
- WWDC21 [Swift concurrency: Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/) ("Runtime contract" and "forward progress")
- Massicotte, [Problematic Swift Concurrency Patterns](https://massicotte.org/problematic-patterns/) → "Blocking for Async Work"

---

<!-- nav:start -->
[← P1.02](./02-under-the-hood.md) · [Roadmap](../../ROADMAP.md) · [P1.04 →](./04-task.md)
<!-- nav:end -->
