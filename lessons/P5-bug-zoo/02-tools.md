# P5.02 — Tools (bug: "rare EXC_BAD_ACCESS in SessionStore", tests pass)

<!-- nav:start -->
[← P5.01](./01-debugging-method.md) · [Roadmap](../../ROADMAP.md) · [P5.03 →](./03-pagination.md)
<!-- nav:end -->

⏱ 30 min · Exercise `P5_02` (TSan-graded)

## The toolbox (read once, keep as reference)

| Symptom | Tool | How |
|---|---|---|
| Wrong values, rare crashes, "impossible" states | **Thread Sanitizer** | Xcode: Scheme → Run/Test → Diagnostics → Thread Sanitizer. SwiftPM: `swift test --sanitize=thread`; here, `scripts/stress.sh <filter> N --tsan`. Reports **races that didn't corrupt anything on this run.** |
| UI updated off main | **Main Thread Checker** | On by default in Xcode debug runs. Purple runtime warnings. |
| Hangs, stutter | **Instruments → Time Profiler** (it includes the Hangs track) or **Animation Hitches** | Select the hang interval and read the heaviest stack on the main thread |
| Tasks stuck, too many tasks, actor contention | **Instruments → Swift Concurrency** template | The *Swift Tasks* track (running / suspended / ended, task count) and the *Swift Actors* track (queue length per actor) |
| A task is hung: where? | **LLDB** | Pause, then `language swift task backtrace` (async backtraces), `language swift task info`, `language swift task select <addr>` |
| Leaks (objects never freed) | **Memory Graph debugger** (Xcode debug bar), **Instruments → Leaks / Allocations** | Look for cycles that run through `Task` closures |
| Blocking in async code | `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` (`scripts/strict-pool.sh`) | Pool width 1, so blocking deadlocks deterministically |
| "Is this really on main / on this actor?" | `MainActor.assertIsolated()`, `preconditionIsolated()`, `dispatchPrecondition(condition: .onQueue(.main))` | Turns silent isolation violations into loud ones |
| Timelines across threads | `os_signpost` / `OSSignposter` | Custom intervals in Instruments |

(Verified on this machine: LLDB lists `language swift task backtrace | info | select`; Instruments lists the Swift Concurrency, Time Profiler, Animation Hitches, Leaks and Allocations templates.)

---

## 🐞 Bug report #1203

> **Title:** Crash: EXC_BAD_ACCESS in `SessionStore`
> **Frequency:** ~0.01% of sessions, only in production, no repro steps.
> **Notes:** `SessionStore` is "thread-safe" (it has a lock). All unit tests pass.
> **Code:** `Sources/Exercises/P5_02_SessionStore.swift`

## 1. Reproduce (5 min)

```bash
swift test --filter P5_02                  # passes. Of course it does.
scripts/stress.sh P5_02 5                  # passes 5/5.
scripts/stress.sh P5_02 5 --tsan           # (slow first build) — now read the report
```

## 2. Read the report (5 min)

For each warning, find three things: the **two accesses** (read/write, file:line), the **two threads**, and the **mutexes held** by each side. That last field is the giveaway.

<details><summary>Hint</summary>
One side of each race holds a mutex (`mutexes: write M0`). The other side holds none.
</details>

## 3. Fix + prove (15 min)

```bash
scripts/stress.sh P5_02 10 --tsan     # must report 0 / 10 failed
```

## 4. Root cause

<details><summary>Spoiler: after TSan is clean</summary>

```
WARNING: ThreadSanitizer: data race
  Read of size 8 … by thread T13:
    #0 SessionStore.activeCount.getter P5_02_SessionStore.swift:32
  Previous write of size 8 … by thread T10 (mutexes: write M0):
    #0 closure #1 in SessionStore.login(_:) P5_02_SessionStore.swift:19
```
(Stub: TSan failed **3/3** stress runs, while the plain tests passed. Solution: **0/3**.)

Two bugs, one myth: "only writes need the lock".
1. `activeCount` and `secondsSinceLastActivity` **read** without the lock while writers hold it.
2. `lastActivity = Date()` is **written** outside the lock.

Why does it crash only rarely? An unsynchronized read of an `Int` usually just returns a stale number. A `Date` is 16 bytes and can be read **torn** (half old, half new). A dictionary or string read mid-mutation can follow a freed pointer: that's the EXC_BAD_ACCESS. Undefined behavior means "usually fine", until it isn't.

Also note the type is `@unchecked Sendable`. Swift 6 stopped checking because the author promised (P2.06). TSan is how you audit that promise.
</details>

## 5. Interview cards

- **Tests pass but production crashes. How do you find a data race?** Run the tests under Thread Sanitizer, many times, with concurrency pressure. TSan flags unsynchronized conflicting accesses even when they didn't corrupt anything on that run. Read the two stacks and the mutexes held.
- **Do reads need the lock?** Yes. A read concurrent with a write is a data race: stale or torn values, or a crash for multi-word or reference-counted types.
- **Which tools for which concurrency symptom?** Races: TSan. UI off main: Main Thread Checker. Hangs: Time Profiler with Hangs, Animation Hitches. Stuck or leaked tasks: the Instruments Swift Concurrency template and `language swift task backtrace` in LLDB. Leaks: the Memory Graph. Blocking in async code: the strict cooperative pool env var.

---

<!-- nav:start -->
[← P5.01](./01-debugging-method.md) · [Roadmap](../../ROADMAP.md) · [P5.03 →](./03-pagination.md)
<!-- nav:end -->
