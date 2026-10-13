# P3.04 — Bounded concurrency: at most N in flight ⭐

<!-- nav:start -->
[← P3.03](./03-task-groups.md) · [Roadmap](../../ROADMAP.md) · [P3.05 →](./05-discarding-task-group.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.04` · Exercise `P3_04`

## 1. Concept (5 min)

"Download 500 images, at most 4 at a time, results in the original order" is one of the most common iOS concurrency interview tasks.

Why limit at all? A task group with 500 `addTask` calls starts **500 downloads at once**. The cooperative pool doesn't explode the way GCD does (P1.03), because suspended tasks don't hold threads, but the *resources* do: 500 open sockets, 500 response buffers in memory, a server rate limit, battery and radio.

GCD's answer was a semaphore (P0.06). Blocking is banned in async code (P1.03). Structured concurrency's answer is the **sliding window**:

```swift
await withTaskGroup(of: (Int, Result).self) { group in
    var next = 0
    func startNext() { /* if next < count: group.addTask { (next, await work(items[next])) }; next += 1 */ }

    for _ in 0..<min(limit, items.count) { startNext() }   // 1. fill the window
    while let (index, value) = await group.next() {        // 2. one finished...
        results[index] = value
        startNext()                                         //    ...start exactly one more
    }
}
```

The window never holds more than `limit` children. Carrying the **index** gives you input order back from completion order.

(Alternatives: an async semaphore in an actor, which you'll build in P4.04; or `chunked(by:)` batches, which are simpler but slower: each batch waits for its slowest member.)

## 2. Predict (5 min)

40 jobs × 20 ms.
1. Unbounded group: peak in flight? Time? ______
2. Sliding window of 4: peak? Time? ______

## 3. Run (5 min)

```bash
swift run lab p3.04
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
unbounded: peak 40 at once, 25ms
sliding window of 4: peak 4 at once, 237ms
```
Unbounded is faster *for this fake*, because nothing here is scarce. Real limits come from the outside world: a server returning 429s, memory, the user's cellular connection. The window turns "unbounded parallelism" into a dial you control. Time ≈ (40 / 4) × 20 ms = 200 ms, plus scheduling overhead.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_04_Bounded.swift`. Implement `downloadAll(_:maxConcurrent:using:)`: never more than N in flight, results in **input** order.

```bash
swift test --filter P3_04
```

Edge cases the tests check: fewer items than the limit; an empty array.

## 6. Interview cards

- **Download N items with at most K concurrent, results in order?** A TaskGroup sliding window: start K children, and each time `next()` returns one, start the next item. Each child returns `(index, value)`, and you write into a pre-sized array.
- **Why not just add all N to a group?** Concurrency is unbounded: N sockets, N buffers, server rate limits. The pool won't spawn N threads, but other resources aren't free.
- **Why not a DispatchSemaphore?** `wait()` blocks a cooperative-pool thread, which risks starvation and deadlock, and semaphores don't donate priority. Use a sliding window or an async (suspending) semaphore.

## Going deeper
- [swift-async-algorithms](https://github.com/apple/swift-async-algorithms) (no built-in "map with max concurrency": interviewers like that you can build it)

---

<!-- nav:start -->
[← P3.03](./03-task-groups.md) · [Roadmap](../../ROADMAP.md) · [P3.05 →](./05-discarding-task-group.md)
<!-- nav:end -->
