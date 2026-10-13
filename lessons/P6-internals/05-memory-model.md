# P6.05 — The memory model and happens-before

<!-- nav:start -->
[← P6.04](./04-hop-costs.md) · [Roadmap](../../ROADMAP.md) · [P6.06 →](./06-isolated-any.md)
<!-- nav:end -->

⏱ 30 min · Demo `p6.05` · Exercise `P6_05` (graded)

## 1. Concept (12 min)

P0.03 introduced reordering. This lesson makes it precise, because it's the real foundation underneath every tool in this course.

**The problem.** CPUs (ARM aggressively; Apple silicon included) and compilers reorder memory operations, and cores have caches. "A wrote, then B read" doesn't mean B sees A's write. Without synchronization there is no defined order between threads at all.

**The model.** Correctness is defined by the **happens-before** relation:
- Within one thread, program order gives happens-before.
- Across threads, only **synchronization** creates it: a *release* operation by A that is *observed* by an *acquire* operation in B.
- It's transitive. If write W happens-before read R, R sees W (or something later).
- Two conflicting accesses **not** ordered by happens-before = a **data race** = undefined behavior. ("One second later" isn't synchronization. Time is not part of the model.)

**Every tool you've used is a happens-before machine:**

| Tool | Edge it creates |
|---|---|
| Mutex / NSLock | unlock (release) → the next lock (acquire) |
| Serial DispatchQueue | block N finishing → block N+1 starting |
| Atomics `.releasing` / `.acquiring` | store-release → a load-acquire that reads that value |
| Atomics `.relaxed` | **none**: atomic for that one variable, orders nothing else |
| Actor / serial executor | one job finishing → the next job on that executor starting |
| `Task { }` creation | everything before creation → the task's first line |
| `continuation.resume` | everything before resume → the resumed task's code |
| `await task.value` / child task completion | the child's last line → the parent after the await |

That's why actor code, queue code and lock code "just works" for plain variables: the edges come with the tool. Swift 6's Sendable checking exists so that every value crossing an isolation boundary does so through one of these edges.

**Relaxed atomics** are for things like counters and statistics, where nothing else depends on the order. Using a relaxed flag to *publish* other data is the classic bug.

## 2. Predict (8 min): the exercise

`Sources/Exercises/P6_05_MemoryModel.swift`: 8 scenarios. For each, is B **guaranteed** to see A's write? Answer by the model, not by what you think usually happens.

```bash
swift test --filter P6_05
```

## 3. Run (5 min)

```bash
swift run lab p6.05
```

## 4. Explain (5 min)

<details><summary>Spoiler: after grading</summary>

| # | Answer | Edge |
|---|---|---|
| 1 | guaranteed | mutex unlock → lock |
| 2 | **not** guaranteed | relaxed atomics create no ordering for *other* memory |
| 3 | guaranteed | release → acquire |
| 4 | guaranteed | the actor's serial executor orders its jobs |
| 5 | guaranteed | serial queue: earlier block finishes before the later one starts |
| 6 | guaranteed | resume → the resumed code |
| 7 | **not** guaranteed | no synchronization: a data race, whatever the timing |
| 8 | guaranteed | task creation → task start |

The demo:
```
message-passing litmus with RELAXED atomics: saw flag == 1 but data == 0 in 0 / 100000 runs
```
Zero observations doesn't make scenario 2 correct. The model **allows** the reordering. It might appear on another chip, another OS version, after an optimizer change, or under thermal pressure. **You program against guarantees, not observations.** (It's also why TSan matters: it reasons about happens-before, not about what happened to go wrong.)
</details>

## 5. Interview cards

- **What is happens-before?** The partial order that defines which writes a read is guaranteed to see. Program order within a thread, plus synchronization edges across threads (release → acquire, unlock → lock, queue/actor job ordering, task creation, continuation resume). Conflicting accesses not ordered by it are a data race.
- **Relaxed vs acquire/release atomics?** Relaxed is atomic for that variable only, and orders no other memory: fine for counters. Release/acquire publishes everything written before the release to whoever acquires the value: needed for flags that publish data.
- **Why does actor code not need memory barriers?** The actor's serial executor creates happens-before edges between consecutive jobs, and Sendable checking ensures values cross isolation boundaries only through synchronized handoffs.

## Going deeper
- [SE-0410 Atomics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0410-atomics.md): the memory-ordering section
- Herlihy & Shavit, *The Art of Multiprocessor Programming*, ch. 3

---

<!-- nav:start -->
[← P6.04](./04-hop-costs.md) · [Roadmap](../../ROADMAP.md) · [P6.06 →](./06-isolated-any.md)
<!-- nav:end -->
