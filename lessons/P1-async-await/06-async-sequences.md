# P1.06 — AsyncSequence and AsyncStream

<!-- nav:start -->
[← P1.05](./05-continuations.md) · [Roadmap](../../ROADMAP.md) · [P1.07 →](./07-errors.md)
<!-- nav:end -->

<!-- dek: Notifications, sensor readings and progress updates arrive many times. A `for await` loop consumes them, and AsyncStream has four habits that cause real bugs. -->

⏱ 30 min · Demo `p1.06` · Exercise `P1_06`

## 1. Concept (5 min)

A continuation (P1.05) turns one callback into one value. Notifications, sensor readings, download progress and websocket messages keep arriving, and for those you write a loop:

```swift
for await notification in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
    refresh()                       // the loop SUSPENDS between elements, holding no thread
}                                   // ends when the sequence ends (or throws, for throwing sequences)
```

`notifications(named:)` returns an `AsyncSequence`: a `Sequence` with `async next()`. `map`, `filter`, `prefix`, `first(where:)` and the rest all work on it.

To make your own from any push-based source, such as a delegate, a callback or NotificationCenter, use **AsyncStream**:

```swift
let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
continuation.yield(1)                   // push a value (sync, never blocks)
continuation.finish()                   // end the stream: the consumer's loop exits
continuation.onTermination = { reason in /* .finished or .cancelled: release resources */ }
```

Four facts about AsyncStream cause real bugs:

1. There is no backpressure. `yield` never waits for the consumer, so values pile up in a buffer. The default, `.unbounded`, grows forever if the consumer is slow; `.bufferingOldest(n)` drops new values when full, and `.bufferingNewest(n)` drops old ones.
2. A stream is unicast: one stream, one consumer. Two `for await` loops on the same stream *split* the values between them, and neither sees all of them. If you need broadcasting, give each consumer its own stream.
3. `onTermination` runs when the stream is terminated: `finish()` was called, the consuming task was cancelled, or the stream was destroyed. Breaking out of a loop doesn't terminate a stream you are still holding in a variable. The producer keeps yielding into a buffer nobody reads, and that is a leak.
4. `finish()` matters. If the producer never calls it, the consumer's `for await` never ends, and that task, with everything it captures, lives forever.

## 2. Predict (5 min)

1. (b) `bufferingNewest(2)`: yield 1, 2, 3, `finish()`, *then* consume. What does the consumer get? ______
2. (c) Two tasks loop over the **same** stream; values 1…10 are yielded. What does each get? ______
3. (d) `let (kept, keptC) = makeStream()`, set `onTermination`, yield 1, 2, 3, then `for await v in kept { if v == 2 { break } }`. Right after the break, does `onTermination` run? What does `keptC.yield(4)` return? ______

## 3. Run (5 min)

```bash
swift run lab p1.06
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
consumer got [2, 3]
consumer 1: [1, 3, 5, 7, 9]
consumer 2: [2, 4, 6, 8, 10]
got 1
got 2
after break. producer yields again → enqueued(remaining: 9223372036854775807)
('kept' is still a live variable here)
  onTermination(kept): cancelled          ← only when the function returned and `kept` was destroyed
```
1. [2, 3]. The newest two were kept and 1 was dropped. `bufferingOldest(2)` would give [1, 2].
2. The values were split: each went to exactly one consumer. The alternating pattern here is a coincidence of timing; the split isn't guaranteed to be even or alternating.
3. No. After `break` the stream is still referenced by `kept`, so it isn't terminated, and `yield(4)` returns `.enqueued`. A real producer here, a sensor or a timer, would keep running and buffering into memory. Termination happened only when the function returned.

   To fix it, don't keep the stream in a variable that outlives the loop. Consume it directly (`for await v in makeStream()`), cancel the consuming task, or call `finish()`. P1.10 puzzle 7 shows the inline version terminating right at the `break`.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_06_Streams.swift`.
1. `heartRates(from:)`: wrap `LegacyHeartRateMonitor` in an `AsyncStream`. Start it on creation and **stop it in `onTermination`**.
2. `average(of:)`: consume any finite `AsyncSequence<Int, Never>`.

```bash
swift test --filter P1_06
```

## 6. Interview cards

- **AsyncStream vs continuation?** A continuation bridges a single callback to a single value. AsyncStream bridges a callback that fires many times into an AsyncSequence consumed with `for await`.
- **Does AsyncStream have backpressure?** No. `yield` never suspends. Pick a buffering policy (`.unbounded`, `.bufferingOldest(n)`, `.bufferingNewest(n)`), and remember an unbounded buffer with a slow consumer grows forever.
- **Can two consumers iterate one AsyncStream?** It's unicast: values get split between consumers, and each sees only some of them. For broadcast, create one stream per subscriber.
- **When does `onTermination` fire?** On `finish()`, when the consuming task is cancelled, or when the stream is deallocated. Not merely on `break` while the stream is still referenced elsewhere.

## Going deeper
- [SE-0298 AsyncSequence](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0298-asyncsequence.md) · [SE-0314 AsyncStream](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0314-async-stream.md)
- [swift-async-algorithms](https://github.com/apple/swift-async-algorithms): `debounce`, `throttle`, `merge`, `combineLatest`, `AsyncChannel` (which *does* have backpressure)

---

<!-- nav:start -->
[← P1.05](./05-continuations.md) · [Roadmap](../../ROADMAP.md) · [P1.07 →](./07-errors.md)
<!-- nav:end -->
