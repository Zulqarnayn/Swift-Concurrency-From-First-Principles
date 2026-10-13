# P4.01 — Producer–consumer: the bounded buffer

<!-- nav:start -->
[← P3.12](../P3-structured/12-review.md) · [Roadmap](../../ROADMAP.md) · [P4.02 →](./02-readers-writers.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.01` · Exercise `P4_01`
★ Background: Downey, [*The Little Book of Semaphores*](https://greenteapress.com/wp/semaphores/) §4.1. Every P4 problem is in this free book. Skim its version first.

## 1. Concept (5 min)

Some threads or tasks **produce** items (camera frames, downloaded chunks, log lines), and others **consume** them. A buffer in between lets the two run at different speeds. Two rules:
1. Consumers wait when the buffer is **empty**.
2. Producers wait when the buffer is **full**. This is **backpressure**: a slow consumer slows the producer down instead of letting memory grow without limit.

**The classic solution (Dijkstra)** uses three primitives:
```
empty = Semaphore(capacity)   // free slots
full  = Semaphore(0)          // filled slots
mutex = Lock()

producer: empty.wait(); mutex { buffer.append(x) }; full.signal()
consumer: full.wait();  mutex { x = buffer.removeFirst() }; empty.signal()
```

**In Swift concurrency:**
- `AsyncStream` handles rule 1 (`for await` suspends while empty) but **not rule 2**: `yield` never waits (P1.06). Its buffering policies either grow without limit or **drop** elements.
- `swift-async-algorithms`' `AsyncChannel` gives you a rendezvous with backpressure (capacity 0).
- Or build a **bounded channel**: an actor holding the buffer, plus queues of parked senders and receivers (continuations). That's today's exercise, and the same "park a continuation, resume it later" technique carries all of P4.

## 2. Predict (5 min)

1. Threads + two semaphores, capacity 3, fast producer, slow consumer: maximum number buffered? ______
2. `AsyncStream`: a producer yields 500 items instantly while the consumer takes 1 ms each. Maximum backlog? ______

## 3. Run (5 min)

```bash
swift run lab p4.01
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
threads + 2 semaphores: consumed 20 in order: true, max buffered 3 (capacity 3)
AsyncStream, fast producer + slow consumer: backlog reached 498 elements (no backpressure)
```
With real data (video frames at 8 MB each), 498 buffered elements is roughly 4 GB, and iOS kills the app. The semaphore version keeps memory bounded, but it **blocks threads**, which isn't allowed in async code. The exercise gets both properties: bounded and suspending.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_01_BoundedChannel.swift`. Implement `send` (suspends while full), `receive` (suspends while empty; `nil` after `finish()` + drained), and `finish`. Use no polling: park continuations.

Design questions:
- When a receiver takes an element and a sender is parked, what should happen *right away*?
- When `finish()` is called, what do parked receivers get?
- Why is it safe to check "is the buffer full?" and then park, inside an actor? (Hint: where are the suspension points?)

```bash
swift test --filter P4_01
```

## 6. Interview cards

- **What is the producer–consumer problem, and what does a solution need?** A shared bounded buffer between producers and consumers. Consumers wait when it's empty, producers wait when it's full (backpressure), and buffer access is mutually exclusive. Classic implementation: two counting semaphores (free and filled slots) plus a mutex.
- **Does AsyncStream provide backpressure?** No. `yield` never suspends, so you get unbounded growth or dropped elements. Use a bounded channel (an actor plus parked continuations) or `AsyncChannel` for real backpressure.
- **How do you build async primitives without blocking?** Keep state in an actor; when a caller must wait, store its continuation; when the condition changes, resume the right continuation. No threads blocked, no polling.

## Going deeper
- [swift-async-algorithms `AsyncChannel`](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md)

---

<!-- nav:start -->
[← P3.12](../P3-structured/12-review.md) · [Roadmap](../../ROADMAP.md) · [P4.02 →](./02-readers-writers.md)
<!-- nav:end -->
