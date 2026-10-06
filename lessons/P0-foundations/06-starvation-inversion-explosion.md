# P0.06 — Starvation, priority inversion, thread explosion ⭐

<!-- nav:start -->
[← P0.05](./05-deadlock.md) · [Roadmap](../../README.md) · [P0.07 →](./07-blocking-vs-suspending.md)
<!-- nav:end -->

⏱ 30 min · Demo `p0.06` · Exercise `P0_06`

## 1. Concept (5 min)

**Starvation:** the system keeps making progress, but one thread or task never gets the resource. Examples: a writer that never gets in because readers keep arriving; low-priority work that never runs because high-priority work never stops.

**Priority inversion:** a high-priority thread waits on a low-priority one.

```
Low  (background): takes lock L ... gets preempted ...
High (UI):         wants L → waits for Low
Medium (utility):  runs and runs and runs (Low never gets CPU to release L)
→ your UI (High) is stuck behind Medium work. Inverted.
```
(The Mars Pathfinder rover kept rebooting because of this in 1997.)

The fix is **priority inheritance/donation**: while High waits on Low, Low temporarily runs at High's priority. On Apple platforms that only works if the system knows **who the owner is**:

| Primitive | Owner known? | Inversion avoided? |
|---|---|---|
| `os_unfair_lock`, `Mutex`, `pthread_mutex`, `NSLock` | ✅ | ✅ |
| Serial queue `sync` / `async` (QoS override) | ✅ | ✅ |
| **`DispatchSemaphore`, `DispatchGroup`, `NSCondition`** | ❌ anyone can signal | ❌ **inversion** |
| Swift `actor`, `await` | ✅ the runtime tracks it | ✅ (priority escalation, P3) |

That's why Apple keeps saying: **don't use semaphores to wait for async work.** Xcode even reports "Thread Performance Checker: … waiting on a lower QoS thread".

**Thread explosion (GCD):** when a block on a global/concurrent queue **blocks** (sync I/O, `semaphore.wait()`, a lock), GCD thinks "that core is idle, start another thread". 100 blocking blocks give you ~64 threads (GCD's cap). That costs memory (stacks), constant context switches, and once the cap is hit, **deadlock** if the block that would unblock everyone can't get a thread.

With **CPU work** GCD doesn't overcommit. It keeps the thread count around the core count.

## 2. Predict (5 min)

64 jobs submitted to `DispatchQueue.global()`:

1. Each job **blocks** for 300 ms. How many distinct threads run them? Total time? ______
2. Each job **computes** for 20 ms. How many threads? Total time? ______
3. Which is worse for the system, and why? ______

## 3. Run (5 min)

```bash
swift run lab p0.06
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
64 BLOCKING jobs on a global queue: 64 threads, 305ms   (cores: 8)
64 CPU jobs on a global queue:      8 threads, 169ms
```
1. **64 threads, ~300 ms.** GCD saw each thread park and started a new one for the next block. It "worked" (300 ms is fast), but it cost 64 stacks and a pile of kernel threads. Make that 1000 network calls and you hit the thread limit: the app stalls or deadlocks.
2. **8 threads ≈ cores**, ~160 ms ≈ 64×20/8. GCD only adds threads when it sees blocking.
3. Blocking. The thread count tracks *how much you block*, not how much useful work there is.

**This is the design decision behind Swift concurrency:** the cooperative pool has **exactly ~one thread per core and never adds more**. No explosion is possible. The price is a hard rule: **never block** (P1.03). When you block there, you get starvation or deadlock instead of extra threads.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P0_06_BoundedWork.swift`. Limit `runAll` to at most `limit` concurrent jobs with a `DispatchSemaphore`. This is the classic GCD answer to "download 100 images, max 4 at a time".

Two questions to answer before you code: who calls `wait()`, and where does `signal()` go so it **always** runs?

```bash
swift test --filter P0_06
```

## 6. Interview cards

- **What's priority inversion and how do Apple platforms handle it?** A high-priority thread waits on a resource held by a low-priority one while medium work starves the low one. Primitives with a known owner (unfair lock, mutex, serial queues, actors) donate priority to the owner. Semaphores and groups don't, so they invert.
- **What's thread explosion?** GCD spawns more threads whenever blocks block, up to ~64. It wastes memory, adds context switches, and can deadlock at the cap. Fix: don't block on concurrent queues, and limit width (semaphore, `OperationQueue.maxConcurrentOperationCount`). Or use Swift concurrency, which never overcommits.
- **How do you limit concurrent work in GCD?** A counting semaphore with `wait()` before submitting and `signal()` in a `defer`; or `OperationQueue` with `maxConcurrentOperationCount`. In Swift concurrency: a TaskGroup with a sliding window, or an async semaphore (P3/P4).

## Going deeper
- WWDC21 [Swift concurrency: Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/), first 15 min (thread explosion and the cooperative pool)
- WWDC17 [Modernizing Grand Central Dispatch Usage](https://developer.apple.com/videos/play/wwdc2017/706/)

---

<!-- nav:start -->
[← P0.05](./05-deadlock.md) · [Roadmap](../../README.md) · [P0.07 →](./07-blocking-vs-suspending.md)
<!-- nav:end -->
