# P1.02 — Under the hood: async frames, jobs, continuations

<!-- nav:start -->
[← P1.01](./01-async-await.md) · [Roadmap](../../ROADMAP.md) · [P1.03 →](./03-cooperative-pool.md)
<!-- nav:end -->

⏱ 30 min · Demo `p1.02` · Exercise `P1_02`

## 1. Concept (5 min)

How can a function stop halfway, release its thread, and continue on a different thread? Here's what the compiler does.

**Normal (sync) function:** local variables live in a **stack frame** on the thread's stack. The function must finish before the thread can do anything else, because the frame sits in the middle of that thread's stack.

**Async function:** the compiler splits it at every `await` into **partial functions** ("funclets"):

```swift
func checkout(cartID: String) async throws -> Receipt {
    let cart = try await ShopAPI.fetchCart(cartID)   // ─── split ───
    let total = cart.prices.reduce(0, +)
    let payment = try await ShopAPI.charge(total)    // ─── split ───
    return Receipt(paymentID: payment.id, total: total)
}
```
- Partial 1: start the `fetchCart` call, then **return to the executor** (the thread is free).
- Partial 2 (runs when `fetchCart` finishes): compute `total`, start `charge`, return to the executor.
- Partial 3: build the receipt, return to the caller.

Variables that must survive a split (`total` lives across the second `await`) go into an **async frame** allocated on the heap (in a fast per-task allocator), **not on any thread's stack**. That's why the function can resume on any thread.

Vocabulary:
- A **Task** is a chain of these partials plus its async frames: one logical "thread of execution", not an OS thread.
- A **job** is one partial, ready to run.
- An **executor** runs jobs: the main actor's executor (the main thread), the global concurrent executor (the cooperative pool), or an actor's serial executor.
- A **continuation** is "the rest of the task from here". When you wrote completion handlers in P0.07, the closure was the continuation, written by hand.

So `await` doesn't block a thread waiting. It ends the current job. When the awaited thing finishes, the next partial is enqueued as a new job on the right executor.

**Consequence:** while a `@MainActor` function is suspended at an `await`, the main thread is **free** to process touches, layout and other main-actor tasks. While it **blocks**, nothing else runs on main, and the UI freezes.

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
1. **About 5.** The main thread was free while the function was suspended, so the heartbeat's jobs ran in between.
2. **Zero.** A 500 ms gap. On iOS that's a visible hang, and the system logs it.
3. **No catch-up.** One beat at +1077 (the delayed job finally runs), then the normal rhythm resumes. Missed time is just lost.

This is the most practical fact in the course: **`await` on the main actor = UI stays responsive. Blocking on the main actor = UI freezes.**
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_02_Desugar.swift`. Write `checkoutCPS`, the callback version of `checkout`, using only the callback APIs. You're doing the compiler's job: each `await` turns into "the rest of the function as a closure".

As you write it, notice:
- `total` gets **captured** by the inner closure. That's the async frame done by hand.
- `throw` turns into "call completion with `.failure` and stop".
- How much harder "exactly once" is to see than in the async version.

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
