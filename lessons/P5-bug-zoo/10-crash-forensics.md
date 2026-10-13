# P5.10 — Crash forensics: read the crash, name the cause

<!-- nav:start -->
[← P5.09](./09-ordering-streams.md) · [Roadmap](../../ROADMAP.md) · [P5.11 →](./11-deterministic-testing.md)
<!-- nav:end -->

⏱ 30 min · Repro `p5.10` (lists the crash demos) · Exercise `P5_10` (graded)

In production you rarely get repro steps for a concurrency crash. You get a **crash report**: an exception type, a signal, a stack trace for the crashed thread, and sometimes a line of *Application Specific Information*. This lesson trains you to read those.

## 1. Where crash reports live (3 min)

- Device or production: Xcode → **Window → Organizer → Crashes**; MetricKit `MXCrashDiagnostic`.
- Your Mac (every crash demo in this course writes one): `~/Library/Logs/DiagnosticReports/lab-*.ips`. Open one in Console.app, or read the JSON.

Key fields: `exception.type` and `signal`, the **crashed thread's frames**, and **`asi`** (Application Specific Information), where system libraries write *"BUG IN CLIENT OF …"*.

## 2. Collect evidence (12 min)

Run each crash demo **without reading its source**. Write down how it dies; then open its `.ips` report and find the first frames *above* the system library frames.

```bash
swift run lab p5.10        # prints the list
swift run lab p0.02b       # …and so on, one at a time
ls -t ~/Library/Logs/DiagnosticReports/lab-*.ips | head -1     # newest report
```

## 3. Name the causes (10 min)

Fill in `Sources/Exercises/P5_10_Forensics.swift`, then:
```bash
swift test --filter P5_10
```

<details><summary>Hint: three demos have the same top frames</summary>
`_dispatch_assert_queue_fail ← dispatch_assert_queue ← _swift_task_checkIsolatedSwift ← swift_task_isCurrentExecutorWithFlagsImpl` means "a Swift runtime isolation check failed". To tell <i>which</i> check, read the NEXT frame down.
</details>

## 4. The evidence (spoiler)

<details><summary>Spoiler: after grading. Real crash reports from this machine.</summary>

| Demo | Exception | Telltale frames / ASI | Cause |
|---|---|---|---|
| p0.02b | `EXC_BAD_ACCESS SIGSEGV` (varies run to run: also `Fatal error: … overlapping range`) | `_swift_release_dealloc ← … ← Array.append ← closure in Racy.arrayAppend`; asi: **"BUG IN CLIENT OF LIBMALLOC: double free detected"** | heap corruption from a data race |
| p0.05b | `EXC_BREAKPOINT SIGTRAP` | `__DISPATCH_WAIT_FOR_QUEUE__ ← _dispatch_sync_f_slow`; asi: **"BUG IN CLIENT OF LIBDISPATCH: dispatch_sync called on queue already owned by current thread"** | sync onto own queue |
| p0.05c | `EXC_BREAKPOINT`, process `SIGKILL` | `_os_unfair_lock_recursive_abort`; asi: **"BUG IN CLIENT OF LIBPLATFORM: Trying to recursively lock an os_unfair_lock"** | recursive lock (a `Mutex` is built on `os_unfair_lock`) |
| p1.03c | no crash: the watchdog prints and exits | all pool threads parked in `semaphore_wait` (pause it in a debugger to see) | cooperative pool deadlock |
| p1.05c | `EXC_BREAKPOINT SIGTRAP` | `_assertionFailure ← CheckedContinuation.resume(returning:)`; console: **"SWIFT TASK CONTINUATION MISUSE: … tried to resume its continuation more than once"** | continuation resumed twice |
| p2.05c | `EXC_BREAKPOINT SIGTRAP` | isolation-check frames ← **`static MainActor.assumeIsolated`** ← `assumeMainFromSyncCode()` | `assumeIsolated` was wrong |
| p2.12c | `EXC_BREAKPOINT SIGTRAP` | isolation-check frames ← **`_checkExpectedExecutor` ← `protocol witness for Describable.describe() in conformance LegacyProfile`** | `@preconcurrency` conformance called off its actor |
| p2.13c | `EXC_BREAKPOINT SIGTRAP` | isolation-check frames ← **`closure #1 in p2_13c()`** directly | dynamic isolation check at the closure's entry (SE-0423) |
| p4.04c | no crash: watchdog | pool threads in `semaphore_wait`, permit holders suspended | cooperative pool deadlock |

Patterns worth memorizing:
- **`EXC_BREAKPOINT` / `SIGTRAP` is a deliberate trap.** Some code *checked* something and stopped (a Swift precondition, a libdispatch assertion, a runtime isolation check). The frames just above the trap say what was checked.
- **`EXC_BAD_ACCESS` / `SIGSEGV`**, especially inside `swift_release` or `malloc`, in code that "can't fail", is the classic signature of memory corruption, often caused by a **data race** far away from the crash site. Next step: TSan (P5.02).
- **"BUG IN CLIENT OF …"** in Application Specific Information: the system library is telling you exactly what you did wrong. Read it first.
</details>

## 5. Interview cards

- **You get a crash report: `EXC_BREAKPOINT` in `_dispatch_assert_queue_fail ← … ← _swift_task_checkIsolatedSwift`. What happened?** A Swift runtime isolation check failed: code isolated to an actor (usually main) ran on the wrong executor. The next frames say which check: `MainActor.assumeIsolated` (a wrong assumption), `_checkExpectedExecutor` in a protocol witness (a `@preconcurrency` conformance), or a closure entry (a dynamic isolation check for an isolated closure called by unchecked or Swift 5 code).
- **`EXC_BAD_ACCESS` in `swift_release` inside `Array.append`, rarely, in production. Hypothesis?** Heap corruption from a data race on that array (or something next to it). Reproduce under Thread Sanitizer with concurrency pressure; check for `@unchecked Sendable` types and unlocked reads.
- **Where do you look first in a crash report?** Exception type and signal, the "BUG IN CLIENT OF …" application-specific info, then the crashed thread's first frames in your own code just above the system frames.

---

<!-- nav:start -->
[← P5.09](./09-ordering-streams.md) · [Roadmap](../../ROADMAP.md) · [P5.11 →](./11-deterministic-testing.md)
<!-- nav:end -->
