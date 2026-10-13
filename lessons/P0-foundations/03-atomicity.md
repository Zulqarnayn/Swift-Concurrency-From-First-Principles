# P0.03 — Atomicity, memory visibility, `Atomic`

<!-- nav:start -->
[← P0.02](./02-data-race.md) · [Roadmap](../../ROADMAP.md) · [P0.04 →](./04-locks-race-conditions.md)
<!-- nav:end -->

<!-- dek: The hardware can do load, add and store as one indivisible step. That fixes a counter, and it fixes much less than you would hope. -->

⏱ 30 min · Demo `p0.03` · Exercise `P0_03`

## 1. Concept (5 min)

In P0.02 the counter lost updates because `count += 1` is three separate steps. Modern CPUs have instructions that do a read-modify-write as one step (on ARM64: `LDADD`, `CAS`, or `LDXR`/`STXR` pairs), and Swift exposes them through the `Synchronization` module (Swift 6, iOS 18 / macOS 15):

```swift
import Synchronization
let counter = Atomic<Int>(0)
counter.add(1, ordering: .relaxed)              // atomic load+add+store
let (exchanged, original) = counter.compareExchange(expected: 5, desired: 6, ordering: .relaxed)
```

An operation like this is **atomic**: indivisible. Other threads see all of it or none of it, never a half-done state.

The second line of the example is the important one. Compare-and-exchange (**CAS**) says: "if the value is still `expected`, replace it with `desired`, and tell me whether you did." If another thread got there first, you read the value it wrote and try again. That retry is the **CAS loop**, and every piece of lock-free code is built on it.

Atomicity is half the problem. The other half is visibility and ordering. Compilers and CPUs reorder memory operations for speed, and ARM, which runs your iPhone and your Mac, does it aggressively:

```swift
// Thread A                // Thread B
data = 42                  if ready { print(data) }   // may print 0!
ready = true
```

Thread B can see `ready == true` *before* it sees `data = 42`. To rule that out you need a *happens-before* edge: everything Thread A did before releasing becomes visible to Thread B after it acquires. Atomics with acquire/release ordering (`.releasing` on the store, `.acquiring` on the load) give you that edge, and so do locks. Locks, serial queues and actors all give it to you for free, which is a big reason to prefer them.

When do you want an atomic, and when a lock? An atomic protects **one word**, such as an Int or a pointer; it is fast and never blocks. A lock protects **an invariant across several values**, such as "the balance is never negative and the history matches the balance". Two separate atomics can't keep two values consistent with each other.

## 2. Predict (5 min)

The demo counts to 4,000,000 with 4 threads, three ways:

1. Racy `count += 1`: correct? ______
2. `NSLock` around `+= 1`: correct? Speed relative to racy? ______
3. `Atomic.add`: correct? Faster or slower than NSLock? ______
4. Read `BoundedCounter.tryIncrement()` in the exercise file. Every individual operation in it is atomic. Is the function correct? ______

## 3. Run (5 min)

```bash
swift run lab p0.03
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
racy:   3630150  in 143ms
NSLock: 4000000  in 835ms
Atomic: 4000000  in 300ms
```
1. Wrong, as in P0.02.
2. Correct, and about 6× slower than the racy version. All 4 threads fight over one lock, which is called *contention*, and every handoff can involve the kernel.
3. Correct, and faster than the lock, because it's one hardware instruction. It's still slower than the racy version: the threads fight over the same cache line. Correctness always costs something; the question is how much.
4. No. Atomic steps don't make a sequence of steps atomic. `load` → check → `store` leaves a gap in which another thread can do the same thing. Two threads both see 999, both store 1000, and both return `true`. It's the bug from `count += 1`, one level up.

   This is the most important idea in the lesson. It comes back at the actor level as *actor reentrancy* in P2.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P0_03_BoundedCounter.swift`. Rewrite `tryIncrement()` as a CAS loop. No locks.

```bash
swift test --filter P0_03
```

## 6. Interview cards

- **What does "atomic" mean?** The operation is indivisible: no thread ever observes it half done. Hardware provides atomic read-modify-write (fetch-add, compare-and-swap).
- **What is CAS and how do you use it?** "Set to `desired` only if it's still `expected`; report success." You use it in a loop: read, compute, CAS, and on failure retry with the fresh value. Every lock-free algorithm is built on it.
- **Are two atomic operations in a row atomic?** No. Another thread can run between them. Check-then-act needs a single CAS or a lock.
- **Why do memory ordering and visibility matter?** CPUs and compilers reorder memory accesses. Without acquire/release (or a lock), another thread can see your writes in a different order, e.g. the "ready" flag before the data. Locks, queues and actors handle this for you.

## Going deeper
- [SE-0410 Low-Level Atomic Operations](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0410-atomics.md) (read Motivation and the memory-ordering section)
- Apple: [Synchronization module](https://developer.apple.com/documentation/synchronization)

---

<!-- nav:start -->
[← P0.02](./02-data-race.md) · [Roadmap](../../ROADMAP.md) · [P0.04 →](./04-locks-race-conditions.md)
<!-- nav:end -->
