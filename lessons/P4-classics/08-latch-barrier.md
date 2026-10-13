# P4.08 — Latches and barriers

<!-- nav:start -->
[← P4.07](./07-token-refresh.md) · [Roadmap](../../ROADMAP.md) · [P4.09 →](./09-leetcode-set.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.08` · Exercise `P4_08`

## 1. Concept (5 min)

Two synchronization shapes that turn up in launch sequences, test harnesses, parallel algorithms, and Java-flavoured interviews (`CountDownLatch`, `CyclicBarrier`):

| | Countdown latch | Cyclic barrier |
|---|---|---|
| Who waits | Any number of waiters | The N participants themselves |
| Opens when | `countDown()` has been called N times | All N participants have arrived |
| Reusable | No: once open, stays open | **Yes**: resets for the next round |
| Example | "Launch when config, auth and flags have all loaded" | Simulation steps: no worker starts step k+1 until all finished step k |
| GCD equivalent | `DispatchGroup` (enter/leave/notify) | `concurrentPerform` (returns when all iterations finish) |

In async Swift, if **you** start the N pieces of work, you already have a latch and a barrier: `async let` and TaskGroup (the scope's end is the barrier). You need explicit latches and barriers when the participants are **independent**: started elsewhere, by different subsystems.

The cyclic barrier's trap is the **reset**. When the last party arrives, release that round's waiters and start a **new** waiting list in the same synchronous step. Otherwise a fast task that arrives for round 2 can be released by round 1's wake-up.

## 2. Predict (5 min)

`p4.08`: three loaders take 30, 10 and 20 ms; `DispatchGroup.notify` fires when? Three phases of `concurrentPerform(4)`: can phase 1 start before phase 0 has finished? ______

## 3. Run (5 min)

```bash
swift run lab p4.08
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
  auth loaded
  flags loaded
  config loaded
all loaders done → launch
  phase 0 complete (4 threads) → only now can phase 1 start
```
The GCD tools work, but their waiting is **thread-based** (`group.wait()` blocks; `concurrentPerform` blocks the caller). In async code, park continuations instead. That's the exercise.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_08_LatchBarrier.swift`. Implement `CountdownLatch` and `CyclicBarrier` with parked continuations. The barrier test runs 3 rounds and checks that no task passes a round before everyone has arrived.

```bash
swift test --filter P4_08
```

## 6. Interview cards

- **Countdown latch vs cyclic barrier?** A latch is a one-shot gate that opens after N countdowns, and any number of tasks can wait on it. A barrier is a reusable rendezvous where N participants wait for each other, then everyone proceeds and it resets.
- **When do you need them in Swift concurrency?** Only when the participants are independent (not children you started). If you own the work, `async let` or a TaskGroup already gives you the barrier at the end of the scope.
- **What's the classic barrier bug?** Resetting after resuming waiters, or reusing the same waiter list, so early arrivals for the next round get released with the previous one. Swap in a fresh list in the same synchronous step as the release.

---

<!-- nav:start -->
[← P4.07](./07-token-refresh.md) · [Roadmap](../../ROADMAP.md) · [P4.09 →](./09-leetcode-set.md)
<!-- nav:end -->
