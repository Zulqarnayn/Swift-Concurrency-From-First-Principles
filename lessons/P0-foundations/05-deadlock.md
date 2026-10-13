# P0.05 — Deadlock ⭐

<!-- nav:start -->
[← P0.04](./04-locks-race-conditions.md) · [Roadmap](../../ROADMAP.md) · [P0.06 →](./06-starvation-inversion-explosion.md)
<!-- nav:end -->

<!-- dek: Two threads, two locks, opposite order. Neither will ever move again, and the fix costs one line. -->

⏱ 30 min · Demo `p0.05` (+ opt-in `p0.05b`, `p0.05c`) · Exercise `P0_05`

## 1. Concept (5 min)

Thread 1 locks A and then wants B. Thread 2 locks B and then wants A. Each holds what the other needs, and neither will let go. That is a **deadlock**: a set of threads where each waits for something another holds, so none of them can ever move.

![Wait-for cycle: lock A is held by Thread 1, which waits for lock B, which is held by Thread 2, which waits for lock A](../../site/diagrams/deadlock.svg)

A deadlock needs all four *Coffman conditions* at once. Break any one of them and deadlock becomes impossible:

| # | Condition | How you break it |
|---|---|---|
| 1 | **Mutual exclusion**: a resource is held by one thread | Use lock-free or immutable data |
| 2 | **Hold and wait**: hold one, wait for another | Take all locks at once, or never hold one while waiting |
| 3 | **No preemption**: you can't take a lock away | `tryLock` with back-off (risk: livelock) |
| 4 | **Circular wait**: A waits for B, B waits for A | A global lock order. The cheapest fix by far. |

These are the deadlocks you will actually meet on iOS:

```swift
// 1. Lock-order inversion (this lesson's exercise)
T1: lock(A); lock(B)        T2: lock(B); lock(A)

// 2. sync onto the queue you're already on
DispatchQueue.main.sync { }            // called from the main thread
serialQueue.sync { serialQueue.sync { } }

// 3. Re-locking a non-recursive lock on the same thread
mutex.withLock { helper() }   // and helper() also takes the lock

// 4. A chain of sync calls between queues
queueA.sync { queueB.sync { queueA.sync { } } }

// 5. (Swift concurrency) blocking a pool thread to wait for async work. P1.03.
```

GCD sometimes detects the second case and crashes on purpose, with `EXC_BREAKPOINT` and "dispatch_sync called on queue already owned by current thread". The crash is the *good* outcome. A silent hang is worse.

To debug a hang, pause in the debugger (or take a spindump or sample) and read every thread's stack. Threads parked in `__psynch_mutexwait`, `_dispatch_sync_f_slow` or `semaphore_wait_trap` tell you who is waiting on what. Draw the wait-for graph from that and look for the cycle.

## 2. Predict (5 min)

1. `p0.05`: T1 takes lock A, sleeps 50ms, takes B. T2 takes B, sleeps 50ms, takes A. What happens? ______
2. `p0.05b`: `queue.sync { queue.sync { … } }` on a serial queue. Hang, crash, or works? ______
3. `p0.05c`: `mutex.withLock { mutex.withLock { … } }`. Hang, crash, or works? ______
4. Which Coffman condition does a **global lock order** break? ______

## 3. Run (5 min)

```bash
swift run lab p0.05
swift run lab p0.05b    # opt-in: crashes on purpose
swift run lab p0.05c    # opt-in: crashes on purpose
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
T1: holds A, wants B
T2: holds B, wants A
DEADLOCK. Nobody progressed for 2s. Both threads are parked forever.
```
1. Deadlock, every time: the 50 ms sleep guarantees that each thread grabs its first lock. Without the sleep it would deadlock only *sometimes*, which is worse, because then it shows up only in production.
2. A crash (SIGTRAP). libdispatch sees that the current thread already owns this serial queue and traps rather than hang. `DispatchQueue.main.sync` from the main thread is the most famous case.
3. A crash: the process is killed. `Mutex` isn't recursive, and the underlying `os_unfair_lock` detects re-locking by its owner and aborts. `NSLock` would just hang silently instead.
4. Circular wait. If everyone locks the lower id first, no cycle can form in the wait-for graph.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P0_05_Transfer.swift`. Make `transfer(from:to:amount:)` deadlock-free while it still holds **both** locks. Two threads run A→B and B→A 500 times each. The test fails if nothing progresses for 5 seconds.

```bash
swift test --filter P0_05
```

## 6. Interview cards

- **What are the four conditions for deadlock?** Mutual exclusion, hold-and-wait, no preemption, circular wait. Break any one. A global lock ordering, which breaks circular wait, is the usual fix.
- **What happens with `DispatchQueue.main.sync {}` on the main thread?** Deadlock. The block waits for the main queue to be free, and the main queue is busy waiting for the block. libdispatch detects it and crashes. The same applies to any serial queue syncing onto itself.
- **How do you debug a hang?** Pause or sample every thread. Find the threads blocked in mutex/semaphore/dispatch-sync waits. Build the wait-for graph and find the cycle. Turn on the Main Thread Checker and hang detection in Xcode/Instruments.
- **Deadlock vs livelock vs starvation?** Deadlock: everyone waits forever. Livelock: everyone keeps busy (retrying, backing off) but nobody progresses. Starvation: the system progresses but one thread never gets the resource (P0.06).

## Going deeper
- Apple: [Diagnosing hangs](https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app)
- Coffman et al., *System Deadlocks* (1971): the original four conditions

---

<!-- nav:start -->
[← P0.04](./04-locks-race-conditions.md) · [Roadmap](../../ROADMAP.md) · [P0.06 →](./06-starvation-inversion-explosion.md)
<!-- nav:end -->
