# P0.02 — Data races ⭐

<!-- nav:start -->
[← P0.01](./01-threads-cores.md) · [Roadmap](../../ROADMAP.md) · [P0.03 →](./03-atomicity.md)
<!-- nav:end -->

⏱ 30 min · Demo `p0.02` (+ opt-in `p0.02b`) · Diagnostics `P0_02_racy_counter.swift` · Exercise `P0_02`

## 1. Concept (5 min)

A **data race** has a precise definition. Learn it word for word; interviewers check:

> Two or more threads access the **same memory location** at the same time, **at least one access is a write**, and there is **no synchronization** ordering them (no "happens-before" relationship).

Why is `count += 1` dangerous? It looks like one step. It's three:

```
load  r = count      // read memory into a register
add   r = r + 1      // change the register
store count = r      // write it back
```

Two threads, `count` starts at 5:

```
Thread A: load r=5                    add r=6   store count=6
Thread B:          load r=5  add r=6                      store count=6
                                                     → count is 6, not 7. One update LOST.
```

It gets worse than a wrong number. In Swift, a data race is **undefined behavior**. `Array`, `Dictionary` and `String` reallocate their buffers. Thread A can write into a buffer that Thread B just freed, and the result is heap corruption and a crash somewhere unrelated, minutes later. That's why races are among the hardest bugs to debug.

**Data race ≠ race condition.** A *race condition* is a logic bug where the result depends on timing. You can have one without a data race (P0.04), and the reverse too. Swift 6 can rule out data races at compile time. It can't rule out race conditions.

**Your tools:**
- **Thread Sanitizer (TSan)** instruments every memory access at runtime and reports races, even ones that didn't corrupt anything on this run. Xcode: Scheme → Diagnostics → Thread Sanitizer. SwiftPM: `--sanitize=thread`.
- **The Swift 6 compiler**, which proves the absence of data races in the code it can see.

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
1. **Wrong, and different every time.** That's the signature of a race: it's nondeterministic. On a lucky run it could even come out right, and that's exactly why races reach production.
2. **TSan:** `WARNING: ThreadSanitizer: Swift access race … Previous write … Racy.swift:20`. It names the line and both threads' stacks.
3. **Diagnostics:**
   ```
   18:13: warning: mutation of captured var 'count' in concurrently-executing code
   29:9:  error: sending value of non-Sendable type '() async -> ()' risks causing data races
   ```
   - **GCD: only a warning, even in Swift 6!** Dispatch is a C/Objective-C library. Its APIs are imported with relaxed (`@preconcurrency`) checking, so violations come out as warnings. Never ignore concurrency warnings in GCD code.
   - **Task: hard error.** `Task {}` is native Swift concurrency, fully annotated. The compiler sees the closure (with `count` inside it) being handed to several tasks that run concurrently. You'll learn the exact rules (`sending`, `Sendable`) in P2.
4. **`p0.02b` crashes**, and with a *different* error each run, e.g. `Fatal error: UnsafeMutablePointer.initialize overlapping range` on one run and a segfault (signal 11) on the next. That's undefined behavior. The crash points to `Array` internals, not to your bug.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P0_02_Counters.swift`. Make `QueueCounter` (serial queue) and `LockCounter` (`NSLock`) correct. Both are marked `@unchecked Sendable`, which means "compiler, trust me". Your job is to make that promise true.

```bash
swift test --filter P0_02
```

Think about: does `current` (a read) need protection too? Why?

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
