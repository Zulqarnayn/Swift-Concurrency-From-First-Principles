# P4.02 — Readers–writers

<!-- nav:start -->
[← P4.01](./01-producer-consumer.md) · [Roadmap](../../ROADMAP.md) · [P4.03 →](./03-dining-philosophers.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.02` · Exercise `P4_02`

## 1. Concept (5 min)

Many readers can safely read shared data **at the same time**. A writer needs it **alone**. A plain mutex makes readers wait for each other for no reason.

A **readers–writer lock** allows many readers *or* one writer. Classic designs:
- **Readers-preference:** readers keep entering while others read, so a writer can **starve**.
- **Writers-preference:** once a writer is waiting, new readers queue behind it.
- `pthread_rwlock_t` exists on Apple platforms, but it's rarely used directly.

**The GCD way, the iOS interview classic:** a **concurrent queue + barrier writes**.
```swift
let queue = DispatchQueue(label: "cache", attributes: .concurrent)
func value(for key: K) -> V? { queue.sync { storage[key] } }                              // readers run in parallel
func set(_ v: V, for key: K) { queue.async(flags: .barrier) { self.storage[key] = v } }  // writer runs alone
```
A barrier block waits for all earlier blocks, runs alone, and holds back later ones. That's P0.08 puzzle 3. It behaves as writer-preferring: readers submitted after a barrier wait for it.

**In Swift concurrency** you rarely need this:
- An **actor** serializes reads too, but reads are usually tiny in-memory lookups, so it doesn't matter.
- If reads are **slow** (big computations over shared data), use **value semantics**: let readers take an immutable snapshot (Swift collections are copy-on-write). Readers then hold no lock at all, and the writer publishes a new snapshot.
- `Mutex` when you need a synchronous API and critical sections are short.

## 2. Predict (5 min)

8 threads × 100 reads, each read taking 0.2 ms while holding the protection:
| Protection | Time? |
|---|---|
| serial queue | |
| concurrent queue (+ barrier writes) | |
| Mutex held during the read | |

## 3. Run (5 min)

```bash
swift run lab p4.02
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
serial queue                         800 reads × 0.2ms: 210ms
concurrent queue (+ barrier writes)  800 reads × 0.2ms: 26ms
Mutex held during the read           800 reads × 0.2ms: 211ms
```
About 8× faster with parallel readers: 800 × 0.2 ms = 160 ms of reading, divided across 8 threads. That only matters when reads are *slow while holding the lock*. For a 50 ns dictionary lookup, a Mutex wins, because the GCD machinery itself costs more than the read.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_02_ReadersWriters.swift`. Turn `RWCache` into a readers–writer cache with GCD. The test runs 8 threads and checks that reads overlap and that **no reader ever overlaps a writer**.

```bash
swift test --filter P4_02
```

Question for yourself: your `set` probably returns before the write happens. Is read-your-own-writes still guaranteed? Why?

## 6. Interview cards

- **Build a thread-safe dictionary where reads run in parallel.** A concurrent DispatchQueue: reads with `sync`, writes with `async(flags: .barrier)`. The barrier waits for in-flight reads, runs alone, and delays later blocks. Reads queued after a write see it.
- **Why do barriers only work on custom concurrent queues?** On global queues, which are shared by the whole process, a barrier would block unrelated work, so GCD ignores the flag (it behaves as a normal `async`).
- **What's writer starvation?** With readers-preference, a continuous stream of readers keeps the count above zero, so a writer never gets in. Fix: writer-preferring policies, or barriers (later readers queue behind a pending writer).
- **Readers–writers in Swift concurrency?** Usually an actor (reads are short) or immutable snapshots via copy-on-write values. RW locks are rarely needed.

---

<!-- nav:start -->
[← P4.01](./01-producer-consumer.md) · [Roadmap](../../ROADMAP.md) · [P4.03 →](./03-dining-philosophers.md)
<!-- nav:end -->
