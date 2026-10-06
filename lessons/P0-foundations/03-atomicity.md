# P0.03 — Atomicity, memory visibility, `Atomic`

<!-- nav:start -->
[← P0.02](./02-data-race.md) · [Roadmap](../../README.md) · [P0.04 →](./04-locks-race-conditions.md)
<!-- nav:end -->

⏱ 30 min · Demo `p0.03` · Exercise `P0_03`

## 1. Concept (5 min)

**Atomic** means indivisible: other threads see either all of the operation or none of it, never a half-done state.

Modern CPUs have instructions that do a read-modify-write as **one atomic step** (on ARM64: `LDADD`, `CAS`, or `LDXR`/`STXR` pairs). Swift exposes them through the `Synchronization` module (Swift 6, iOS 18 / macOS 15):

```swift
import Synchronization
let counter = Atomic<Int>(0)
counter.add(1, ordering: .relaxed)              // atomic load+add+store
let (exchanged, original) = counter.compareExchange(expected: 5, desired: 6, ordering: .relaxed)
```

**Compare-and-exchange (CAS)** is the building block of all lock-free code: *"if the value is still `expected`, replace it with `desired`, and tell me whether you did."* If another thread got there first, you retry with the value it wrote. That's the **CAS loop**.

**The second problem is visibility and ordering.** Compilers and CPUs reorder memory operations for speed. ARM (your iPhone and Mac) does it aggressively. So:

```swift
// Thread A                // Thread B
data = 42                  if ready { print(data) }   // may print 0!
ready = true
```

Thread B can see `ready == true` *before* it sees `data = 42`. Atomics with **acquire/release** ordering (`.releasing` on the store, `.acquiring` on the load) or locks set up a *happens-before* edge: everything A did before releasing is visible to B after it acquires. **Locks, serial queues and actors all give you this for free.** That's a big reason to prefer them.

**Atomic vs lock:**
- An atomic protects **one word** (an Int, a pointer). Fast, never blocks.
- A lock protects **an invariant across many values** (e.g. "balance ≥ 0 and the history matches the balance"). Two separate atomics can't keep two values consistent with each other.

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
2. Correct, and about 6× slower. All 4 threads fight over one lock (**contention**). Every handoff can involve the kernel.
3. Correct, and faster than the lock. It's one hardware instruction, but the threads still fight over the same cache line, so it's slower than the racy version. Correctness costs something; the question is how much.
4. **No.** Atomic steps don't make a sequence of steps atomic. `load` → check → `store` leaves a gap where another thread can do the same thing. Two threads both see 999, both store 1000, and both return `true`. Same bug as `count += 1`, one level up. **This is the most important idea in the lesson.** It comes back at the actor level as *actor reentrancy* (P2).
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
[← P0.02](./02-data-race.md) · [Roadmap](../../README.md) · [P0.04 →](./04-locks-race-conditions.md)
<!-- nav:end -->
