# P4.03 — Dining philosophers (can actors deadlock?)

<!-- nav:start -->
[← P4.02](./02-readers-writers.md) · [Roadmap](../../README.md) · [P4.04 →](./04-async-semaphore.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.03` · Exercise `P4_03`

## 1. Concept (5 min)

Five philosophers sit at a round table, with a fork between each pair. Eating takes **both** neighbouring forks. If everyone picks up their left fork first, everyone holds one fork and waits for the other, forever. It's the textbook illustration of the four Coffman conditions (P0.05).

Classic fixes:
| Fix | Breaks |
|---|---|
| **Resource ordering**: always pick up the lower-numbered fork first | circular wait |
| **Waiter/arbitrator**: at most 4 may try at once (a semaphore of 4) | circular wait (someone always gets two) |
| Try-lock + back off | hold-and-wait (risks livelock) |
| Chandy/Misra: forks are passed with clean/dirty state | for distributed settings |

**"Actors can't deadlock," right?** True in one narrow sense: an actor **never holds itself locked across an `await`** (reentrancy, P2.04), so two actors calling each other don't deadlock like two locks do.

But if you **build a mutex out of continuations** (an async lock, a semaphore, a fork that suspends until free), you have mutual exclusion and hold-and-wait again. All four Coffman conditions come back, so deadlock comes back too, in a quieter form:
- no thread is blocked; every task is **suspended**
- CPU at 0%, the app stays responsive, nothing crashes
- the feature simply **never completes**, and no tool flags it

Async deadlocks are harder to notice than thread deadlocks, not easier.

## 2. Predict (5 min)

1. 5 threads, 5 `NSLock`s, left then right (with a pause between): what happens? ______
2. 5 tasks, 5 fork **actors** with async `pickUp()`, same order: what happens? Can unrelated tasks still run? ______

## 3. Run (5 min)

```bash
swift run lab p4.03
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
DEADLOCK after 0 meals: 5 threads blocked forever in lock()
HANG after 0 meals: every task is SUSPENDED waiting for a fork
...yet the cooperative pool is fine: 8 unrelated tasks just ran in 11ms. No thread is blocked.
The app doesn't freeze. A feature silently never completes. That's how async deadlocks look in production.
```
How you'd catch it: a timeout around the operation (P3.08); debugger task inspection showing tasks suspended in `pickUp`; and the Instruments Swift Tasks track showing tasks that never finish.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_03_Philosophers.swift`. Make `dine` deadlock-free. Don't edit `Fork` or `DiningTable`. The test fails if the dinner doesn't finish within 5 s.

```bash
swift test --filter P4_03
```

Bonus: implement the *waiter* solution instead (hint: the `AsyncSemaphore` from P4.04 with 4 permits).

## 6. Interview cards

- **What's the dining philosophers problem and how do you solve it?** Five processes each need two shared resources, and the naive order deadlocks via circular wait. Fixes: a global resource order (lowest id first), an arbitrator that limits concurrent attempts to N−1, or try-and-back-off (watch for livelock).
- **Can actors deadlock?** Not lock-style: awaiting releases the actor. But async primitives built from continuations (async mutexes, semaphores) can deadlock logically. Every task is suspended forever, no thread is blocked, nothing crashes, and the work just never finishes.
- **How do you detect an async deadlock?** Timeouts on operations that must complete, the Instruments Swift Tasks view (tasks stuck suspended), debugger task backtraces, and design rules (lock ordering) that make it impossible.

---

<!-- nav:start -->
[← P4.02](./02-readers-writers.md) · [Roadmap](../../README.md) · [P4.04 →](./04-async-semaphore.md)
<!-- nav:end -->
