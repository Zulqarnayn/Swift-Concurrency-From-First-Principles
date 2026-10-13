# P6.04 — Hop costs and isolated parameters

<!-- nav:start -->
[← P6.03](./03-runtime-costs.md) · [Roadmap](../../ROADMAP.md) · [P6.05 →](./05-memory-model.md)
<!-- nav:end -->

⏱ 30 min · Demo `p6.04` · Exercise `P6_04`

## 1. Concept (7 min)

Every `await` that crosses an isolation boundary is a **hop**: the task leaves one executor and enqueues a job on another. Hops differ a lot in cost:

| Hop | Mechanism | Measured (P6.03 / p6.04) |
|---|---|---|
| Pool → idle default actor | Often a **switch on the same thread**: the runtime runs the actor's job right here | ~0.1 µs |
| Pool → **MainActor** → back | Enqueue on the main queue, a real **thread switch**, then back to the pool | **~7–8 µs** |
| Contended actor | Your job waits in the actor's queue behind others | unbounded (it depends on the load) |

The MainActor is special in a second way: **it's the UI thread**. Every main-actor job competes with touch handling, layout and rendering. 5,000 tiny hops add up to 35+ ms of main-thread time, plus 5,000 scheduling round trips, for updates that the screen (60–120 Hz) can't even display.

Tools to cut hops:
1. **Batch:** do the work on one side and cross once with the result (P2.01, P5.08).
2. **Throttle UI updates:** report progress every N items or every ~100 ms, never per item.
3. **Isolated parameters / actor methods for multi-step work:** one hop for a whole transaction, which is also *atomic* (P2.10).
4. **Keep data where it's used:** a non-Sendable model owned by the main actor (P2.15) needs no hops at all.

But measure first. Hop cost matters in loops, not in a button handler that hops once.

## 2. Predict (5 min)

From a background task: 10,000 awaits of a `@MainActor` function vs 10,000 calls to an idle actor vs 1 call carrying all 10,000 updates. Rough times? ______

## 3. Run (3 min)

```bash
swift run lab p6.04
```

## 4. Explain (3 min)

<details><summary>Spoiler: open after running</summary>

```
10000 round trips pool → MainActor → back: 79ms (≈ 7.9µs each — a real thread switch)
10000 calls pool → idle actor: 1ms (the runtime can run the actor right on this thread)
1 call carrying all 10000 updates: 0ms
```
</details>

## 5. Exercise (12 min)

File: `Sources/Exercises/P6_04_HopCosts.swift`. The import updates the main-actor progress model once per record. Keep the UI informed (at least every 10%) with **at most 20** main-actor updates in total.

```bash
swift test --filter P6_04
```

## 6. Interview cards

- **Is `await`ing an actor expensive?** It depends. An idle default actor called from the pool is often a cheap same-thread switch (about 0.1 µs). A MainActor round trip is a real thread switch (about 7 µs) and competes with UI work. Contended actors add queueing delay. Cost matters in loops: batch.
- **A background import updates a progress bar per item and the UI stutters. Why, and what's the fix?** Thousands of main-actor hops: each one a thread switch plus a main-thread job, mostly for updates the screen can't show. Batch the updates (every N items or every ~100 ms) and hop once per batch.
- **How do isolated parameters reduce hops?** A function with an `isolated` actor parameter runs entirely on that actor: one hop in, synchronous access inside. That makes it both faster and atomic compared with many separate awaited calls.

---

<!-- nav:start -->
[← P6.03](./03-runtime-costs.md) · [Roadmap](../../ROADMAP.md) · [P6.05 →](./05-memory-model.md)
<!-- nav:end -->
