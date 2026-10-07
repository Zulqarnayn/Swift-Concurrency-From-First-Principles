---
title: Home
hide:
  - navigation
  - toc
---

<div class="hero" markdown>

# Swift Concurrency,<br>from first principles

<p class="tagline">86 half-hour sessions. Predict what the code does, run it, learn from the gap, then fix a failing test. From threads and data races to actors, structured concurrency, the hardest async bugs, and senior iOS interviews.</p>

[Start at P0.01 →](lessons/P0-foundations/01-threads-cores.md){ .md-button .md-button--primary }
[⭐ Interview fast track](roadmap.md#interview-fast-track){ .md-button }
[Full roadmap](roadmap.md){ .md-button }

</div>

<div class="stats" markdown>
<div><strong>86</strong>sessions</div>
<div><strong>8</strong>phases</div>
<div><strong>≈ 43 h</strong>at 30 min a day</div>
<div><strong>219</strong>graded tests</div>
</div>

## Eight phases, one idea at a time

<div class="grid cards" markdown>

-   **🧱 P0 · Foundations** · 8 sessions

    ---

    Threads, cores, data races, atomics, locks, deadlock, priority inversion and thread explosion, with GCD as your starting point.

    [Start here →](lessons/P0-foundations/01-threads-cores.md)

-   **⏳ P1 · async/await** · 10 sessions

    ---

    What `await` really means, the cooperative pool, tasks, continuations, AsyncStream, and converting a real GCD codebase.

    [Start →](lessons/P1-async-await/01-async-await.md)

-   **🔐 P2 · Isolation** · 16 sessions

    ---

    Actors, reentrancy, `@MainActor`, `Sendable`, `sending`, `@concurrent`, and the Swift 6 compiler errors you will actually meet.

    [Start →](lessons/P2-isolation/01-network-request-lab.md)

-   **🌳 P3 · Structured concurrency** · 12 sessions

    ---

    `async let`, task groups, bounded concurrency, cancellation, timeouts, priorities and task-locals.

    [Start →](lessons/P3-structured/01-structured-concurrency.md)

-   **🍽️ P4 · Classic problems** · 12 sessions

    ---

    Producer–consumer, readers–writers, dining philosophers, async semaphore, rate limiter, debounce, token-refresh race, image pipeline.

    [Start →](lessons/P4-classics/01-producer-consumer.md)

-   **🐞 P5 · Bug Zoo** · 12 sessions

    ---

    Real bug reports, broken systems, no hints. Reproduce, make it deterministic, find the cause, prove the fix.

    [Start →](lessons/P5-bug-zoo/01-debugging-method.md)

-   **⚙️ P6 · Internals** · 8 sessions

    ---

    Executors, what tasks and hops cost (measured), the memory model, `@isolated(any)`, Swift Evolution.

    [Start →](lessons/P6-internals/01-executors.md)

-   **🎯 P7 · Interview mastery** · 8 sessions

    ---

    Output marathons, timed katas, system design rounds and a full mock interview.

    [Start →](lessons/P7-interview/01-gcd-operationqueue.md)

</div>

## How every session works

<div class="session-strip">
<span>1 · Concept</span><span>2 · Predict</span><span>3 · Run</span><span>4 · Explain</span><span>5 · Exercise</span><span>6 · Cards</span>
</div>

Your wrong predictions are the curriculum. Write them down *before* you run anything, and open the 🔒 spoilers only after.

## Run the labs on your machine

```bash
git clone https://github.com/Zulqarnayn/Swift-Concurrency-From-First-Principles.git
cd Swift-Concurrency-From-First-Principles/ConcurrencyLab
swift run lab list          # every runnable demo
swift test --filter P0_01   # check a lesson's exercise
```

Needs Xcode 26+ (Swift 6.2+). The iOS labs live in `ConcurrencyLabApp/` (`xcodegen generate`).
