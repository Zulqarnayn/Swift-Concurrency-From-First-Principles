# P0.02 — Data races ⭐

<!-- nav:start -->
[← P0.01](./01-threads-cores.md) · [Roadmap](../../ROADMAP.md) · [P0.03 →](./03-atomicity.md)
<!-- nav:end -->

<!-- dek: `count += 1` looks like one step. The CPU does it in three, and another thread can slip in between any two of them. -->

⏱ 30 min · Demo `p0.02` (+ opt-in `p0.02b`) · Diagnostics `P0_02_racy_counter.swift` · Exercise `P0_02`

## 1. Concept (5 min)

Why is `count += 1` dangerous? It looks like one step. It's three:

```
load  r = count      // read memory into a register
add   r = r + 1      // change the register
store count = r      // write it back
```

Now put two threads on it, with `count` starting at 5:

```
Thread A: load r=5                    add r=6   store count=6
Thread B:          load r=5  add r=6                      store count=6
                                                     → count is 6, not 7. One update LOST.
```

![Timeline of two threads incrementing count from 5: both load 5, both store 6, and count ends at 6 instead of 7](../../site/diagrams/lost-update.svg)

Both threads read 5, both write 6, and one of the two increments is gone. This is a **data race**, and it has a precise definition that interviewers expect you to know word for word:

> Two or more threads access the **same memory location** at the same time, **at least one access is a write**, and there is **no synchronization** ordering them (no "happens-before" relationship).

A wrong number is the mild outcome. In Swift a data race is *undefined behavior*: the language makes no promise at all about what happens next. `Array`, `Dictionary` and `String` reallocate their buffers as they grow, so Thread A can write into a buffer that Thread B has just freed. The heap is now corrupt, and the app crashes minutes later in code that has nothing to do with the race. That distance between cause and crash is what makes races among the hardest bugs to debug.

A data race is not the same thing as a race condition. A *race condition* is a logic bug where the result depends on timing. You can have one without a data race (P0.04), and the reverse too. Swift 6 can rule out data races at compile time. It can't rule out race conditions.

Two tools find data races. Thread Sanitizer (TSan) instruments every memory access at runtime and reports races, even ones that didn't corrupt anything on this run; turn it on in Xcode under Scheme → Diagnostics → Thread Sanitizer, or pass `--sanitize=thread` to SwiftPM. The Swift 6 compiler goes further and proves that the code it can see has no data races at all.

## 2. Predict (5 min)

`Sources/UnsafeZone/Racy.swift` → `Racy.counter(threads: 4, increments: 100_000)`: 4 threads, each doing `count += 1` 100k times.

1. Expected 400,000. Will you get exactly that? Same number on every run? ______
2. With TSan on, what happens? ______
3. Open `ConcurrencyLab/Diagnostics/P0_02_racy_counter.swift`. It holds the same racy counter written with GCD and with `Task`, compiled as **Swift 6**. For each version: error, warning, or clean? ______
4. (`p0.02b`) 8 threads append to one `Array`. What happens? ______

## 3. Run (5 min)

```bash
swift run lab p0.02
swift run --sanitize=thread lab p0.02        # then rebuild normally: swift build
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P0_02_racy_counter.swift   # from repo root
swift run lab p0.02b                          # run it 3 times
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
run 1: expected 400000, got 387496  (lost 12504 updates)
run 2: expected 400000, got 388648  (lost 11352 updates)
run 3: expected 400000, got 376351  (lost 23649 updates)
```
1. Wrong, and different every time. That is the signature of a race: it's nondeterministic. A lucky run could even come out right, which is exactly how races reach production.
2. TSan prints `WARNING: ThreadSanitizer: Swift access race … Previous write … Racy.swift:20`. It names the line and shows both threads' stacks.
3. The compiler says:
   ```
   18:13: warning: mutation of captured var 'count' in concurrently-executing code
   29:9:  error: sending value of non-Sendable type '() async -> ()' risks causing data races
   ```
   The GCD version gets only a warning, even in Swift 6. Dispatch is a C and Objective-C library, and its APIs are imported with relaxed (`@preconcurrency`) checking, so violations come out as warnings. Never ignore concurrency warnings in GCD code.

   The `Task {}` version is a hard error. Tasks are native Swift concurrency and fully annotated, so the compiler sees the closure, with `count` inside it, being handed to several tasks that run at the same time. You'll learn the exact rules (`sending`, `Sendable`) in P2.
4. `p0.02b` crashes, with a *different* error on each run: `Fatal error: UnsafeMutablePointer.initialize overlapping range` on one, a segfault (signal 11) on the next. That is undefined behavior in practice. The crash points into `Array` internals, not at your bug.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P0_02_Counters.swift`. Make `QueueCounter` (serial queue) and `LockCounter` (`NSLock`) correct. Both are marked `@unchecked Sendable`, which tells the compiler "trust me". Your job is to make that promise true.

```bash
swift test --filter P0_02
```

Think about this as you go: does `current`, which only reads, need protection too? Why?

## 6. Interview cards

- **Define a data race.** Two or more threads access the same memory concurrently, at least one access writes, and nothing synchronizes them (no happens-before). In Swift it's undefined behavior, not just a wrong value.
- **Data race vs race condition?** A data race is a memory-level conflict. A race condition is a logic bug that depends on timing. Each can exist without the other. Swift 6 eliminates data races at compile time; race conditions are still your job.
- **Why does `count += 1` race?** It's load, modify, store. Another thread can interleave between the steps, and an update gets lost.
- **How do you find races?** Thread Sanitizer (runtime, catches races even on runs that happened to give the right answer), and Swift 6 strict concurrency checking (compile time).

## Going deeper
- Apple: [Diagnosing memory, thread, and crash issues early](https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early)
- Swift.org: [Data race safety](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety)

---

<!-- nav:start -->
[← P0.01](./01-threads-cores.md) · [Roadmap](../../ROADMAP.md) · [P0.03 →](./03-atomicity.md)
<!-- nav:end -->
