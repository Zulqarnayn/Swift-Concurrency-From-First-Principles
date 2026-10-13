# P4.04 — An async semaphore ⭐

<!-- nav:start -->
[← P4.03](./03-dining-philosophers.md) · [Roadmap](../../ROADMAP.md) · [P4.05 →](./05-rate-limiter.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.04` (+ opt-in `p4.04c`) · Exercise `P4_04`

## 1. Concept (5 min)

A counting semaphore holds N **permits**. `wait()` takes one, or waits if none are left; `signal()` returns one. GCD's `DispatchSemaphore` **blocks the thread** while waiting. In async code that starves the cooperative pool, and can **deadlock** it (p4.04c, and P1.03).

When do you need a semaphore rather than a sliding window (P3.04)?
- **Sliding window:** all the work starts from **one place** (one TaskGroup).
- **Semaphore:** the limit is shared across **unrelated call sites**: uploads started from 5 different screens must share a global limit of 3.

An **async semaphore** suspends instead of blocking. Its design is the core interview question:

```
state:  value (free permits), waiters (FIFO queue of continuations)
wait:   if value > 0 → value -= 1, return
        else → park my continuation in waiters
signal: if waiters non-empty → resume the OLDEST waiter (hand the permit over DIRECTLY)
        else → value += 1
```

Three details separate a correct answer from a nearly correct one:
1. **Hand the permit directly to the waiter.** "Increment, then wake someone" lets a newcomer slip in between and steal the permit, which breaks FIFO.
2. **Cancellation.** A cancelled waiter must leave the queue and throw, and must **not** consume a permit. You need `withTaskCancellationHandler`, and `onCancel` runs on any thread, so it has to hop onto the actor (P3.06).
3. **Already cancelled before waiting.** Check before parking.

## 2. Predict (5 min)

1. 24 jobs (every 4th is slow: 90 ms, the others 10 ms), max 4 at once. **Fixed batches of 4** vs a **sliding window** of 4: times? ______
2. `p4.04c`: 32 tasks use `DispatchSemaphore(4)` as a limiter and hold the permit across an `await`. What happens? ______

## 3. Run (5 min)

```bash
swift run lab p4.04
swift run lab p4.04c     # opt-in, a watchdog ends it
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
batches of 4 (each batch waits for its slowest job): 556ms
sliding window of 4 (a slot refills the moment it frees): 231ms
WATCHDOG: nothing finished in 3s. Waiters block every pool thread; permit holders can't resume. Deadlock.
```
2. **Deadlock.** 28 tasks block pool threads in `wait()`. The 4 permit holders are suspended in `await` and need a pool thread to resume. None are free. This exact bug ships in real apps that "limit concurrent downloads" with a `DispatchSemaphore` inside `Task`s.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_04_AsyncSemaphore.swift`. Implement FIFO wake-up, cancellation that doesn't consume a permit, and no polling.

```bash
swift test --filter P4_04
```

## 6. Interview cards

- **Why not use DispatchSemaphore to limit concurrent async work?** `wait()` blocks a cooperative-pool thread. Enough waiters block every thread, and permit holders can't resume after their awaits, which is a deadlock. It also doesn't donate priority.
- **Design an async semaphore.** An actor with a permit count and a FIFO queue of continuations. `wait` takes a permit or parks; `signal` resumes the oldest waiter directly (handing over the permit), or increments if nobody waits. Support cancellation with `withTaskCancellationHandler`: remove the waiter on the actor and throw, without consuming a permit.
- **Sliding window vs semaphore?** A window limits work started from one TaskGroup. A semaphore limits across unrelated call sites that share a resource.

## Going deeper
- [groue/Semaphore](https://github.com/groue/Semaphore): a production async semaphore. Read its cancellation handling.

---

<!-- nav:start -->
[← P4.03](./03-dining-philosophers.md) · [Roadmap](../../ROADMAP.md) · [P4.05 →](./05-rate-limiter.md)
<!-- nav:end -->
