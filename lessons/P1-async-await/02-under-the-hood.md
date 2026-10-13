# P1.02 — Under the hood: async frames, jobs, continuations

<!-- nav:start -->
[← P1.01](./01-async-await.md) · [Roadmap](../../ROADMAP.md) · [P1.03 →](./03-cooperative-pool.md)
<!-- nav:end -->

<!-- dek: A function stops halfway, gives its thread away, and carries on later on another one. Here is what the compiler builds to make that possible. -->

⏱ 30 min · Demo `p1.02` · Exercise `P1_02`

## 1. Concept (5 min)

How can a function stop halfway, release its thread, and continue on a different thread? Start with a function that has two waits in it:

```swift
func checkout(cartID: String) async throws -> Receipt {
    let cart = try await ShopAPI.fetchCart(cartID)   // ─── split ───
    let total = cart.prices.reduce(0, +)
    let payment = try await ShopAPI.charge(total)    // ─── split ───
    return Receipt(paymentID: payment.id, total: total)
}
```

The compiler cuts it at every `await` into **partial functions**, sometimes called funclets:

- Partial 1 starts the `fetchCart` call, then returns to the executor, which frees the thread.
- Partial 2 runs when `fetchCart` finishes. It computes `total`, starts `charge`, and returns to the executor.
- Partial 3 builds the receipt and returns to the caller.

A normal, synchronous function keeps its local variables in a **stack frame** on the thread's stack. It must finish before the thread can do anything else, because that frame sits in the middle of the thread's stack. An async function can't work that way. Variables that must survive a split, such as `total`, which lives across the second `await`, go into an **async frame** allocated on the heap by a fast per-task allocator. The frame is on no thread's stack, which is why the function can resume on any thread.

Four words describe the machinery, and the rest of the course uses them:

- A **task** is a chain of these partials plus their async frames: one logical thread of execution, not an OS thread.
- A **job** is one partial, ready to run.
- An **executor** runs jobs. The main actor's executor runs them on the main thread, the global concurrent executor runs them on the cooperative pool, and each actor has a serial executor of its own.
- A **continuation** is "the rest of the task from here". The completion handlers you wrote in P0.07 were continuations written by hand.

So `await` doesn't make a thread wait. It ends the current job. When the awaited work finishes, the next partial is enqueued as a new job on the right executor.

This has a practical consequence. While a `@MainActor` function is suspended at an `await`, the main thread is free to process touches, layout and other main-actor work. While it blocks, nothing else runs on main, and the UI freezes.

## 2. Predict (5 min)

`p1.02`: a heartbeat task on the main actor prints `♥` every 100 ms. Then, on the main actor:
1. `await suspend(ms: 500)`: how many ♥ appear during it? ______
2. `blockThread(ms: 500)`: how many ♥ appear during it? ______
3. After the block ends, does the heartbeat "catch up" with 5 quick beats? ______

## 3. Run (5 min)

```bash
swift run lab p1.02
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
[   +55ms] MAIN | main actor: AWAITING 500ms...
[  +103ms] MAIN | ♥ 2
[  +209ms] MAIN | ♥ 3
[  +311ms] MAIN | ♥ 4
[  +411ms] MAIN | ♥ 5
[  +512ms] MAIN | ♥ 6
[  +577ms] MAIN | main actor: done awaiting
[  +577ms] MAIN | main actor: BLOCKING 500ms...
[ +1077ms] MAIN | main actor: done blocking
[ +1077ms] MAIN | ♥ 7
[ +1183ms] MAIN | ♥ 8
```
1. About 5. The main thread was free while the function was suspended, so the heartbeat's jobs ran in between.
2. Zero, which leaves a 500 ms gap. On iOS that is a visible hang, and the system logs it.
3. No catch-up. One beat arrives at +1077, when the delayed job finally runs, and then the normal rhythm resumes. Missed time is simply lost.

This is the most practical fact in the course. An `await` on the main actor keeps the UI responsive; blocking on the main actor freezes it.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_02_Desugar.swift`. Write `checkoutCPS`, the callback version of `checkout`, using only the callback APIs. You're doing the compiler's job: each `await` turns into "the rest of the function as a closure".

As you write it, notice three things. `total` gets captured by the inner closure, which is the async frame done by hand. `throw` turns into "call completion with `.failure` and stop". And "exactly once" is much harder to see than in the async version.

```bash
swift test --filter P1_02
```

## 6. Interview cards

- **How can an async function resume on a different thread?** The compiler splits it into partial functions at each `await`. Values that live across a suspension are kept in a heap-allocated async frame owned by the task, not on a thread stack, so any thread can run the next partial.
- **Task vs job vs executor?** A task is the unit of async work, a chain of partials. A job is one runnable partial. An executor runs jobs: main actor (main thread), global concurrent (cooperative pool), or an actor's serial executor.
- **Why doesn't `await` on the main actor freeze the UI?** Suspending ends the current job and frees the main thread. The continuation is enqueued later as a new job, and touch handling and layout run in between.

## Going deeper
- WWDC21 [Swift concurrency: Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/): async frames and continuations (~15:00 onward)
- [SE-0296](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0296-async-await.md): "Detailed design → Suspension points"

---

<!-- nav:start -->
[← P1.01](./01-async-await.md) · [Roadmap](../../ROADMAP.md) · [P1.03 →](./03-cooperative-pool.md)
<!-- nav:end -->
