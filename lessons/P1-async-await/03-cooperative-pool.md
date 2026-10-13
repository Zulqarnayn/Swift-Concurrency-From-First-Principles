# P1.03 — The cooperative thread pool: never block it ⭐

<!-- nav:start -->
[← P1.02](./02-under-the-hood.md) · [Roadmap](../../ROADMAP.md) · [P1.04 →](./04-task.md)
<!-- nav:end -->

⏱ 30 min · Demo `p1.03` (+ opt-in `p1.03c`) · Diagnostics `P1_03_blocking_in_async.swift` · Exercise `P1_03`

## 1. Concept (5 min)

Remember P0.06: GCD reacts to a blocking block by **creating another thread**, which leads to thread explosion. Swift concurrency makes the opposite trade:

> The **cooperative pool** (the global concurrent executor) has **about one thread per core** and **never adds more**.

No explosion, minimal context switching, small memory use. In exchange, **the runtime assumes every task makes forward progress: it either runs or suspends, and never blocks waiting for something else to happen.** That's the "cooperative" part, a contract between you and the runtime.

Break the contract and you get one of two failures:
1. **Starvation:** blocked threads reduce the pool's throughput. Blocking 1 of 8 threads = 12.5% of all async capacity gone.
2. **Deadlock:** a task blocks waiting for work that needs a pool thread to run. If every pool thread is in that state, nothing can ever wake them. GCD would have spawned a rescue thread; the cooperative pool won't.

**Things that break the contract:**
- `DispatchSemaphore.wait()`, `DispatchGroup.wait()`, `Thread.sleep`, `usleep`: waiting for *future* events
- Sync I/O: `Data(contentsOf:)` on a URL, sync file reads of large files, sync XPC
- Holding a lock **while waiting for async work** (short locks around memory are fine; they're held, not waited on)
- **The "sync wrapper" anti-pattern:** `semaphore.wait()` inside a sync helper that bridges to async. The compiler bans the direct call in async code but **can't see through a sync function**.

**Tooling:** set the environment variable `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` (Xcode: Scheme → Run → Arguments → Environment) to shrink the pool to **1 thread**. Any task that blocks waiting on another task deadlocks immediately and every time. That's how you find these bugs before your users do.

> **A real bug from building this course:** Swift Testing runs even *synchronous* `@Test` functions on the cooperative pool. The first version of this repo's P0 tests blocked with semaphores inside sync tests, starved the pool, and made unrelated async tests time out at random, ~1.1 s each. The fix is in `LabKit/Timeout.swift` → `onDedicatedThread`: run blocking code on its own OS thread and `await` the result.

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
1. **≤ 8 threads, ~200 ms.** Suspended tasks hold no thread, so a handful of threads juggle all 64.
2. **8 threads, ~1.6 s** (64 × 200 / 8). No explosion, but 8× slower than GCD here. The pool refuses to grow; blocking just queues everything behind it.
3. **Deadlock.** The first 8 tasks take all 8 pool threads and park in `wait()`. The signaller is a task too, so it needs a pool thread, and there are none left. The watchdog (a plain OS thread, outside the pool) reports it after 3 s. Under GCD this would have worked, because GCD would have spawned a 9th thread.
4. **~13 s.** One thread, 64 × 200 ms in sequence. Strict mode turns *"slow under load"* into *"obviously broken in the debugger"*.
5. Compile errors: **A** (`semaphore.wait`), **B** (`group.wait`), **C** (`Thread.sleep`), and **E** (`NSLock.lock()`/`unlock()`: *"Use async-safe scoped locking instead"*, i.e. `lock.withLock { }`, so the lock can't be held across an `await`).
   Not caught: **D** (`usleep`), **F** (sync network I/O), **G/H** (the sync-helper loophole). The compiler's checks are a seatbelt, not autopilot.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_03_NeverBlock.swift`. `total(for:)` uses a "sync wrapper" bridge. Under concurrent load it deadlocks (we added a 1 s escape hatch so your test run doesn't hang). Fix it.

```bash
swift test --filter P1_03
```

Then ask yourself: if old sync code *really* needs that price, what are its honest options? (Become async. Or kick off a `Task` and deliver the result later with a callback or state update. Never wait.)

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
