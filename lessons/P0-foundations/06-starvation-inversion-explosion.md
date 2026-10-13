# P0.06 — Starvation, priority inversion, thread explosion ⭐

<!-- nav:start -->
[← P0.05](./05-deadlock.md) · [Roadmap](../../ROADMAP.md) · [P0.07 →](./07-blocking-vs-suspending.md)
<!-- nav:end -->

<!-- dek: Nothing is deadlocked, yet the UI waits behind background work and GCD keeps starting threads it doesn't need. Three ways a working system goes wrong. -->

⏱ 30 min · Demo `p0.06` · Exercise `P0_06`

## 1. Concept (5 min)

A database has readers and a writer. Readers keep arriving, each one overlapping the last, so the lock is never free long enough for the writer to get in. The app keeps working, and the writer waits forever. That is **starvation**: the system makes progress, but one thread or task never gets the resource. Low-priority work that never runs because high-priority work never stops is the same thing.

A worse variant puts priorities the wrong way round:

```
Low  (background): takes lock L ... gets preempted ...
High (UI):         wants L → waits for Low
Medium (utility):  runs and runs and runs (Low never gets CPU to release L)
→ your UI (High) is stuck behind Medium work. Inverted.
```
(The Mars Pathfinder rover kept rebooting because of this in 1997.)

This is **priority inversion**: a high-priority thread waits on a low-priority one. The fix is *priority inheritance*, also called donation: while High waits on Low, Low temporarily runs at High's priority. On Apple platforms that only works when the system knows who owns the thing High is waiting for:

| Primitive | Owner known? | Inversion avoided? |
|---|---|---|
| `os_unfair_lock`, `Mutex`, `pthread_mutex`, `NSLock` | Yes | Yes |
| Serial queue `sync` / `async` (QoS override) | Yes | Yes |
| `DispatchSemaphore`, `DispatchGroup`, `NSCondition` | No: anyone can signal | No, these invert |
| Swift `actor`, `await` | Yes, the runtime tracks it | Yes (priority escalation, P3) |

That is why Apple keeps telling you not to use semaphores to wait for async work. Xcode even reports it: "Thread Performance Checker: … waiting on a lower QoS thread".

The third problem is specific to GCD. When a block on a global or concurrent queue *blocks*, on synchronous I/O, `semaphore.wait()` or a lock, GCD reasons that the core is now idle and starts another thread. 100 blocking blocks give you about 64 threads, which is GCD's cap. This is **thread explosion**. It costs memory for every stack and constant context switches, and once the cap is reached it can deadlock: the block that would unblock everyone can't get a thread to run on.

With CPU work, GCD doesn't overcommit. It keeps the thread count around the core count.

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
1. 64 threads, about 300 ms. GCD saw each thread park and started a new one for the next block. It "worked", and 300 ms is fast, but it cost 64 stacks and a pile of kernel threads. Make that 1000 network calls and you hit the thread limit: the app stalls or deadlocks.
2. 8 threads, the number of cores, in about 160 ms ≈ 64×20/8. GCD adds threads only when it sees blocking.
3. Blocking is worse. The thread count tracks how much you block, not how much useful work there is.

This is the design decision behind Swift concurrency. Its cooperative pool has about one thread per core and never adds more, so an explosion is impossible. The price is a hard rule, which P1.03 covers: never block a thread in that pool. If you do, you get starvation or deadlock instead of extra threads.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P0_06_BoundedWork.swift`. Limit `runAll` to at most `limit` concurrent jobs with a `DispatchSemaphore`. This is the classic GCD answer to "download 100 images, max 4 at a time".

Answer two questions before you write code: who calls `wait()`, and where does `signal()` go so that it **always** runs?

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
[← P0.05](./05-deadlock.md) · [Roadmap](../../ROADMAP.md) · [P0.07 →](./07-blocking-vs-suspending.md)
<!-- nav:end -->
