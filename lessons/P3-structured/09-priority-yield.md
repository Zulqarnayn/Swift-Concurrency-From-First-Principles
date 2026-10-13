# P3.09 — Priority, escalation, `Task.yield`

<!-- nav:start -->
[← P3.08](./08-timeouts.md) · [Roadmap](../../ROADMAP.md) · [P3.10 →](./10-task-locals.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.09` · Exercise `P3_09`

## 1. Concept (5 min)

**Task priority** is a hint to the scheduler: `.userInitiated` (= `.high`), `.medium`, `.utility`, `.low`, `.background`. It maps onto QoS (P0.06).

Rules:
- **Inheritance:** child tasks (`async let`, groups) and `Task {}` inherit the creator's priority. **`Task.detached` doesn't**; it gets the default unless you pass one.
- **Escalation:** when a higher-priority task **awaits** a lower-priority one (`await lowTask.value`), the low task is **raised** to the waiter's priority. Actors escalate too: a high-priority job waiting on an actor raises the job currently running on it. This is priority inversion avoidance (P0.06), done automatically because the runtime knows who waits on whom. Semaphores can't do this.
- Massicotte's advice: **don't set explicit priorities** unless you can explain why the default is wrong. Hand-picked priorities create inversions and rarely help.

**`Task.yield()`** suspends the current task and puts it back at the end of its executor's queue, so other jobs waiting on the **same** executor can run. That matters on the **main actor**: a long synchronous loop there blocks every tap, animation and other main-actor task until it ends. Yielding every few iterations lets them interleave.

`Task.yield` is a **fairness** tool, not a performance tool:
- The work still runs on main and still costs main-thread time.
- If the work doesn't need main, move it off with `@concurrent` (P2.08). That's usually the right fix.
- Yield is for work that has to stay on its actor (it mutates that actor's state as it goes) but is long.

## 2. Predict (5 min)

1. `Task {}` inside a `.userInitiated` task: priority? `Task.detached` inside it (before anyone awaits it)? ______
2. A `.background` task awaited by a `.high` task reports what priority? ______
3. On the main actor: 100 ms of work in 2 ms chunks, while another main-actor task wants to run. How many times does it get to run without `Task.yield`? With? ______

## 3. Run (5 min)

```bash
swift run lab p3.09
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
child Task {} of a .userInitiated task: TaskPriority.high   (.userInitiated and .high are the same value)
Task.detached inside a .userInitiated task: TaskPriority.medium
a .background task, awaited by a .high task, reports: TaskPriority.high
100ms of main-actor work without Task.yield → other main-actor task ran 0 times
100ms of main-actor work WITH Task.yield → other main-actor task ran 51 times
```
- Detached did **not** inherit. While building this demo, the first version read the detached task's priority *after* awaiting it and saw `.high`, which was escalation hiding the non-inheritance. It's a nice example of how observing a system can change it.
- **0 vs 51:** without yields, the main actor was monopolized for 100 ms (6 dropped frames at 60 Hz).
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_09_Yield.swift`. `processAll` must stay on the main actor but let other main-actor work run.

```bash
swift test --filter P3_09
```

Then answer for yourself: when is `@concurrent` the better fix?

## 6. Interview cards

- **How is task priority inherited?** Child tasks and `Task {}` inherit the creator's priority. `Task.detached` doesn't. Priority is a scheduling hint mapped to QoS.
- **What is priority escalation?** When a higher-priority task awaits a lower-priority task, or waits on an actor running lower-priority work, the runtime raises the lower one's priority. It's automatic priority-inversion avoidance, possible because the runtime knows who waits on whom.
- **What does `Task.yield()` do and when do you use it?** It suspends and requeues the current task so other jobs on the same executor can run. Use it in long loops that must stay on an actor (often main) to keep things responsive. If the work doesn't need that actor, move it off instead.

## Going deeper
- Massicotte, [Problematic patterns](https://massicotte.org/problematic-patterns/) → "Explicit Priorities"
- WWDC21 [Swift concurrency: Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/) (priority escalation for actors)

---

<!-- nav:start -->
[← P3.08](./08-timeouts.md) · [Roadmap](../../ROADMAP.md) · [P3.10 →](./10-task-locals.md)
<!-- nav:end -->
