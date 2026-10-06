# Swift Concurrency, From First Principles

A self-paced course in **30-minute sessions**. The goal: understand threads, isolation and structured concurrency well enough to debug the hardest async bugs and handle senior iOS concurrency interviews.

Every session follows the same loop. **Predict → Run → Explain the gap → Fix a failing test.**
Your wrong predictions are the curriculum. Write them down.

---

## Setup (5 min, once)

Requirements: Xcode 26+ (Swift 6.2+). Built and verified with Swift 6.3.3 / Xcode 26.6 / macOS 26.5.

```bash
cd ConcurrencyLab
swift build                  # builds demos, exercises, tests
swift run lab list           # every runnable demo
swift run lab p0.01          # run one lesson's demo
swift test --filter P0_01    # check one lesson's exercise (fails until you solve it)
```

iOS app (first used in P2.01):
```bash
cd ConcurrencyLabApp && xcodegen generate && open ConcurrencyLabApp.xcodeproj
```

## How a session works (30 min)

| Min | Step | What you do |
|---|---|---|
| 5 | **Concept** | Read section 1 of the lesson. First principles plus the GCD analogy. |
| 5 | **Predict** | Answer the questions *in writing* before running anything. |
| 5 | **Run** | `swift run lab <id>` / `scripts/typecheck.sh …` / the app. |
| 5 | **Explain** | Open the spoiler. For every wrong prediction, write one sentence on *why*. |
| 10 | **Exercise** | Make `swift test --filter <ID>` pass, or for *Fixme* lessons make `scripts/fixme.sh <file>` pass. Solutions are in `solutions/` (only after you've tried). |
| + | **Cards** | Say the interview cards out loud. Review sessions (every ~8) repeat them. |

Run **one lesson's tests at a time** (`--filter`). Unsolved stubs from *other* lessons deliberately block threads or deadlock, and they can slow the whole run down.

## Repo map

```
lessons/P0…P7/          the lessons (start at P0-foundations/01-threads-cores.md)
ConcurrencyLab/         SwiftPM package
  Sources/LabKit/       trace(), burnCPU/blockThread/suspend, meters, timeouts
  Sources/Demos/        one demo per lesson → swift run lab <id>
  Sources/UnsafeZone/   Swift 5 mode: the only place real data races compile (for TSan demos)
  Sources/Puzzles/      "what does this print?" puzzles
  Sources/Exercises/    YOUR work: stubs that compile but are wrong
  Tests/ExercisesTests/ grade your exercises and predictions
  Diagnostics/          deliberately broken files: compile errors ARE the lesson
  Fixme/                "make it compile, CORRECTLY" exercises (graded by scripts/fixme.sh)
  Sources/LegacySemantics/   Swift 6.0/6.1 async rules, for comparison (P2.08, P2.15)
  Sources/MainActorDefault/  a MainActor-by-default module, like an Xcode 26 app target (P2.09)
ConcurrencyLabApp/      SwiftUI app (Xcode 26 defaults: MainActor-by-default + approachable concurrency)
solutions/              reference solutions (same filenames as Exercises/)
interview/              flashcards, question bank, output puzzles, katas
reading-list.md         Massicotte, Apple docs, WWDC, Swift Evolution, books, per phase
scripts/                typecheck · stress · strict-pool · verify-solutions
```

## Tools cheat sheet

| Command (from repo root unless noted) | Use |
|---|---|
| `swift run lab list` *(in ConcurrencyLab/)* | List demos (★ = opt-in crash/deadlock demos, run by exact id) |
| `swift run --sanitize=thread lab p0.02` *(in ConcurrencyLab/)* | Thread Sanitizer. Afterwards run `swift build` to get a normal build back. |
| `scripts/typecheck.sh ConcurrencyLab/Diagnostics/<file>` | What the compiler says about a broken file (`--full` for everything) |
| `scripts/fixme.sh ConcurrencyLab/Fixme/<file>` | Grade a compile-fix exercise: zero errors/warnings AND no forbidden escape hatches |
| `scripts/stress.sh P0_04 100 [--tsan]` | Run a test 100×. One green run proves little for concurrent code. |
| `scripts/strict-pool.sh p1.03` | Cooperative pool shrunk to 1 thread, so blocking bugs deadlock every time |
| `scripts/verify-solutions.sh [filter]` | Swap in `solutions/` (in a temp copy) and run the tests (no filter: also Fixme + Diagnostics) |

---

## Roadmap: 86 sessions ≈ 17 weeks at 5/week

✅ = built and ready · ⭐ = interview fast track. All 86 sessions are built. Each lesson has ← previous / next → links at the top and bottom.

### P0 — Foundations: OS-level first principles ✅
- [ ] [P0.01 Threads, cores, concurrency vs parallelism](lessons/P0-foundations/01-threads-cores.md)
- [ ] [P0.02 Data races](lessons/P0-foundations/02-data-race.md) ⭐
- [ ] [P0.03 Atomicity, memory visibility, `Atomic`](lessons/P0-foundations/03-atomicity.md)
- [ ] [P0.04 Locks and race conditions (check-then-act)](lessons/P0-foundations/04-locks-race-conditions.md) ⭐
- [ ] [P0.05 Deadlock](lessons/P0-foundations/05-deadlock.md) ⭐
- [ ] [P0.06 Starvation, priority inversion, thread explosion](lessons/P0-foundations/06-starvation-inversion-explosion.md) ⭐
- [ ] [P0.07 Blocking vs suspending; why completion handlers hurt](lessons/P0-foundations/07-blocking-vs-suspending.md)
- [ ] [P0.08 Review: GCD output puzzles](lessons/P0-foundations/08-review.md) ⭐

### P1 — async/await mechanics ✅
- [ ] [P1.01 What `async` and `await` actually mean](lessons/P1-async-await/01-async-await.md) ⭐
- [ ] [P1.02 Under the hood: async frames, jobs, continuations](lessons/P1-async-await/02-under-the-hood.md)
- [ ] [P1.03 The cooperative pool: never block it](lessons/P1-async-await/03-cooperative-pool.md) ⭐
- [ ] [P1.04 `Task`: the unit of async work](lessons/P1-async-await/04-task.md)
- [ ] [P1.05 Continuations: bridging callbacks](lessons/P1-async-await/05-continuations.md) ⭐
- [ ] [P1.06 AsyncSequence and AsyncStream](lessons/P1-async-await/06-async-sequences.md)
- [ ] [P1.07 Errors in async code, typed throws](lessons/P1-async-await/07-errors.md)
- [ ] [P1.08 Where async begins; keeping order](lessons/P1-async-await/08-async-entry-points.md) ⭐
- [ ] [P1.09 Lab: convert a GCD service](lessons/P1-async-await/09-lab-convert-gcd.md)
- [ ] [P1.10 Review: async output puzzles](lessons/P1-async-await/10-review.md) ⭐

### P2 — Isolation: actors, MainActor, Sendable (the core) ✅
- [ ] [P2.01 Lab: a network request, step by step (iOS app, Massicotte)](lessons/P2-isolation/01-network-request-lab.md) ⭐
- [ ] [P2.02 Isolation from first principles](lessons/P2-isolation/02-isolation-first-principles.md)
- [ ] [P2.03 Actors vs serial queues](lessons/P2-isolation/03-actors-vs-queues.md) ⭐
- [ ] [P2.04 **Actor reentrancy**](lessons/P2-isolation/04-actor-reentrancy.md) ⭐
- [ ] [P2.05 MainActor, global actors, inference](lessons/P2-isolation/05-global-actors.md) ⭐
- [ ] [P2.06 `Sendable` from first principles](lessons/P2-isolation/06-sendable.md) ⭐ *(Fixme)*
- [ ] [P2.07 `sending` and region-based isolation](lessons/P2-isolation/07-sending-regions.md) *(Fixme)*
- [ ] [P2.08 `nonisolated(nonsending)` vs `@concurrent`](lessons/P2-isolation/08-nonsending-vs-concurrent.md) ⭐
- [ ] [P2.09 MainActor by default](lessons/P2-isolation/09-default-mainactor.md) *(Fixme)*
- [ ] [P2.10 Isolation inheritance; isolated parameters](lessons/P2-isolation/10-isolation-inheritance.md)
- [ ] [P2.11 Globals, statics, singletons](lessons/P2-isolation/11-globals-singletons.md) *(Fixme)*
- [ ] [P2.12 Protocols and isolated conformances](lessons/P2-isolation/12-protocols-isolation.md) *(Fixme)*
- [ ] [P2.13 `@preconcurrency`, legacy bridges, migration](lessons/P2-isolation/13-preconcurrency-migration.md) ⭐
- [ ] [P2.14 Massicotte labs: storage + stateful systems](lessons/P2-isolation/14-massicotte-storage-stateful.md)
- [ ] [P2.15 Non-Sendable first design](lessons/P2-isolation/15-nonsendable-first.md) *(Fixme)*
- [ ] [P2.16 Review: isolation puzzles + diagnostics gauntlet](lessons/P2-isolation/16-review-gauntlet.md) ⭐

### P3 — Structured concurrency ✅
- [ ] [P3.01 What "structured" means: task trees and scoped lifetimes](lessons/P3-structured/01-structured-concurrency.md)
- [ ] [P3.02 `async let` (and its implicit cancel + await)](lessons/P3-structured/02-async-let.md) ⭐
- [ ] [P3.03 TaskGroup / ThrowingTaskGroup](lessons/P3-structured/03-task-groups.md) ⭐
- [ ] [P3.04 Bounded concurrency: max N in flight](lessons/P3-structured/04-bounded-concurrency.md) ⭐
- [ ] [P3.05 DiscardingTaskGroup and long-running work](lessons/P3-structured/05-discarding-task-group.md)
- [ ] [P3.06 Cancellation from first principles](lessons/P3-structured/06-cancellation.md) ⭐
- [ ] [P3.07 Cancellation propagation; `.task(id:)`; owning unstructured tasks (iOS lab)](lessons/P3-structured/07-cancellation-propagation.md) ⭐
- [ ] [P3.08 Build `withTimeout`](lessons/P3-structured/08-timeouts.md) ⭐
- [ ] [P3.09 Priority, escalation, `Task.yield`](lessons/P3-structured/09-priority-yield.md)
- [ ] [P3.10 `@TaskLocal`](lessons/P3-structured/10-task-locals.md)
- [ ] [P3.11 Unstructured tasks: ordering, `Task.immediate`](lessons/P3-structured/11-unstructured-tasks.md)
- [ ] [P3.12 Review: structured concurrency puzzles](lessons/P3-structured/12-review.md) ⭐

### P4 — Classic problems, each solved the thread way and the async way ✅
- [ ] [P4.01 Producer–consumer / bounded buffer](lessons/P4-classics/01-producer-consumer.md)
- [ ] [P4.02 Readers–writers](lessons/P4-classics/02-readers-writers.md)
- [ ] [P4.03 Dining philosophers (can actors deadlock?)](lessons/P4-classics/03-dining-philosophers.md) ⭐
- [ ] [P4.04 Async semaphore](lessons/P4-classics/04-async-semaphore.md) ⭐
- [ ] [P4.05 Rate limiter / token bucket](lessons/P4-classics/05-rate-limiter.md)
- [ ] [P4.06 Debounce and throttle (iOS search lab)](lessons/P4-classics/06-debounce-throttle.md) ⭐
- [ ] [P4.07 Single-flight and the token-refresh race](lessons/P4-classics/07-token-refresh.md) ⭐
- [ ] [P4.08 Latches and barriers](lessons/P4-classics/08-latch-barrier.md)
- [ ] [P4.09 The LeetCode concurrency set, in async Swift](lessons/P4-classics/09-leetcode-set.md)
- [ ] [P4.10 Image pipeline: dedupe + limit + LRU (iOS lab)](lessons/P4-classics/10-image-pipeline.md) ⭐
- [ ] [P4.11 Retry with backoff + cancellation](lessons/P4-classics/11-retry-backoff.md)
- [ ] [P4.12 Review: pick the right tool](lessons/P4-classics/12-review.md) ⭐

### P5 — Bug Zoo: debugging the hardest async bugs ✅
Each session is a **bug report** + a broken system. No hints in the code. `swift run lab p5.xx` runs *your* current code as a repro.
- [ ] [P5.01 The method: reproduce → deterministic → timeline → fix → prove](lessons/P5-bug-zoo/01-debugging-method.md) ⭐
- [ ] [P5.02 Tools; a race only TSan can see](lessons/P5-bug-zoo/02-tools.md)
- [ ] [P5.03 Pagination: duplicates + stale pages (iOS lab)](lessons/P5-bug-zoo/03-pagination.md) ⭐
- [ ] [P5.04 Continuations that never resume](lessons/P5-bug-zoo/04-continuations.md)
- [ ] [P5.05 Pool starvation hidden in helpers](lessons/P5-bug-zoo/05-pool-starvation.md) ⭐
- [ ] [P5.06 Task retain cycles and leaks](lessons/P5-bug-zoo/06-task-leaks.md)
- [ ] [P5.07 Cancellation swallowed or ignored](lessons/P5-bug-zoo/07-cancellation-bugs.md)
- [ ] [P5.08 Main-thread hangs from "async" code (iOS lab + Instruments)](lessons/P5-bug-zoo/08-main-thread-hangs.md) ⭐
- [ ] [P5.09 AsyncStream misuse: unicast, never-ending loops](lessons/P5-bug-zoo/09-ordering-streams.md)
- [ ] [P5.10 Crash forensics: read the crash, name the cause](lessons/P5-bug-zoo/10-crash-forensics.md)
- [ ] [P5.11 Deterministic async testing](lessons/P5-bug-zoo/11-deterministic-testing.md)
- [ ] [P5.12 Timed bug hunt (25 min)](lessons/P5-bug-zoo/12-timed-bug-hunt.md) ⭐

### P6 — Internals ✅
- [ ] [P6.01 Executors; custom actor executors](lessons/P6-internals/01-executors.md)
- [ ] [P6.02 Task executor preference (SE-0417)](lessons/P6-internals/02-task-executors.md)
- [ ] [P6.03 What tasks and hops cost (graded by measuring your machine)](lessons/P6-internals/03-runtime-costs.md) ⭐
- [ ] [P6.04 Hop costs and isolated parameters](lessons/P6-internals/04-hop-costs.md)
- [ ] [P6.05 Memory model and happens-before](lessons/P6-internals/05-memory-model.md) ⭐
- [ ] [P6.06 `@isolated(any)` and `#isolation`](lessons/P6-internals/06-isolated-any.md)
- [ ] [P6.07 Swift Evolution reading sprint](lessons/P6-internals/07-swift-evolution.md)
- [ ] [P6.08 Distributed actors overview](lessons/P6-internals/08-distributed-actors.md) *(Fixme)*

### P7 — Interview mastery ✅
- [ ] [P7.01 The GCD & OperationQueue round](lessons/P7-interview/01-gcd-operationqueue.md)
- [ ] [P7.02 "Explain the output" marathon (timed)](lessons/P7-interview/02-output-marathon.md) ⭐
- [ ] [P7.03 Kata: parallel fetch with a limit and a deadline (25 min)](lessons/P7-interview/03-kata-fetch-all.md) ⭐
- [ ] [P7.04 Kata: concurrent processing, in-order delivery (25 min)](lessons/P7-interview/04-kata-ordered-pipeline.md)
- [ ] [P7.05 Kata: an observable async value (25 min)](lessons/P7-interview/05-kata-async-value.md)
- [ ] [P7.06 iOS system design: networking layer](lessons/P7-interview/06-design-networking.md) ⭐
- [ ] [P7.07 iOS system design: offline-first sync engine](lessons/P7-interview/07-design-offline-sync.md)
- [ ] [P7.08 Mock interview (Claude plays interviewer)](lessons/P7-interview/08-mock-interview.md) ⭐

### ⭐ Interview fast track
Interview in under 3 weeks? Do only the ⭐ sessions, in order, then `interview/question-bank.md` and `interview/output-puzzles.md`.
