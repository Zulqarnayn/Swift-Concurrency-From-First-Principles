# P6.03 — The runtime: what tasks and hops cost

<!-- nav:start -->
[← P6.02](./02-task-executors.md) · [Roadmap](../../README.md) · [P6.04 →](./04-hop-costs.md)
<!-- nav:end -->

⏱ 30 min · Demo `p6.03` · Exercise `P6_03` (graded **against measurements of your machine**)

## 1. Concept (8 min)

Why can you create 100,000 tasks but not 100,000 threads?

**A thread** is an OS object. It has a kernel structure, a scheduler entry, and a **stack reserved up front** (512 KB for secondary threads on Apple platforms, mostly virtual until touched). Blocking one parks all of that. Switching between threads is a kernel context switch.

**A task** is a heap object owned by the Swift runtime:
- a small task record (status, priority, task-locals, parent/child links),
- **async frames** (P1.02): the variables that live across suspension points, allocated from a per-task bump allocator; a suspended task holds only those,
- jobs it enqueues onto executors.

A suspended task holds **no thread and no stack**, only its frames. Resuming it means enqueuing a job, and a pool thread picks it up. When the target executor is idle and compatible, the runtime can **switch** to it on the current thread without a context switch. (That's why calling an idle actor from the pool is cheap, P6.04.)

Practical consequences:
- 100k concurrent network requests in flight: fine with tasks, impossible with blocked threads.
- Creating a task is cheap but not free: microseconds, not nanoseconds. Don't create one per element in a tight loop for trivial work.
- Hopping to the **main actor** is a real thread switch, about 50× an idle-actor call. Batch your UI updates (P6.04).

## 2. Predict (5 min): this is the exercise

Fill in your estimates **before running anything** in `Sources/Exercises/P6_03_Costs.swift`:
- resident memory per **suspended** task
- virtual stack reserved per secondary **thread**
- `Task { }` create + await
- one MainActor round trip from a background task
- that round trip vs a call to an idle custom actor

## 3. Run → grade (10 min)

```bash
swift test --filter P6_03      # measures this machine, then compares with your buckets
swift run lab p6.03            # the numbers, plus a thread comparison
```

## 4. Explain (5 min)

<details><summary>Spoiler: measured on this course's machine (M-series, macOS 26)</summary>

| Measurement | Value | Bucket |
|---|---|---|
| Suspended task (debug build, 50k tasks) | ≈ 1.5–2.5 KB resident each | 256 B – 4 KB |
| Blocked thread | ≈ 16 KB resident each, **plus 512 KB reserved stack** | > 64 KB (reservation) |
| `Task { }` create + await | ≈ 1–1.7 µs (release ≈ 1 µs; `async let` ≈ 0.66 µs) | 100 ns – 100 µs |
| MainActor round trip | ≈ 7–8 µs | 100 ns – 100 µs |
| MainActor hop vs idle-actor call | ≈ 50× | > 30× |

So: a suspended task is roughly **10× lighter** than a blocked thread's resident memory and **200× lighter** than its reservation, and it doesn't occupy a scheduler slot. That's what makes "one task per request" viable.

Measure on your own device when it matters. These numbers vary with hardware, OS and build configuration. The orders of magnitude don't.
</details>

## 5. Interview cards

- **Why are tasks cheaper than threads?** A suspended task is a small heap object plus its async frames: no stack, no kernel thread, no scheduler slot. Threads reserve a stack (512 KB secondary), are kernel objects, and context-switch through the kernel. Measured: about 1.5–2.5 KB per suspended task vs about 16 KB resident plus 512 KB reserved per blocked thread.
- **How expensive is an actor hop?** An idle default actor called from the pool is often a same-thread switch: tens to hundreds of nanoseconds. A MainActor round trip from the background is a real thread switch: microseconds (about 7 µs measured). Batch main-actor updates.
- **What's in an async frame?** The local variables and temporaries that must survive across a suspension point, allocated from the task's allocator rather than a thread stack. That's why the task can resume on any thread.

## Going deeper
- WWDC21 [Swift concurrency: Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/): the definitive talk on tasks, continuations, the pool and actor switching

---

<!-- nav:start -->
[← P6.02](./02-task-executors.md) · [Roadmap](../../README.md) · [P6.04 →](./04-hop-costs.md)
<!-- nav:end -->
