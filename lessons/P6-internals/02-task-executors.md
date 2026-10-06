# P6.02 — Task executor preference (SE-0417)

<!-- nav:start -->
[← P6.01](./01-executors.md) · [Roadmap](../../README.md) · [P6.03 →](./03-runtime-costs.md)
<!-- nav:end -->

⏱ 30 min · Demo `p6.02` · Exercise `P6_02`

## 1. Concept (8 min)

A custom *actor* executor (P6.01) controls where one actor's code runs. A **task executor** controls where **nonisolated** code runs for a whole task tree:

```swift
await withTaskExecutorPreference(myExecutor) {
    await parse(data)                                   // nonisolated async code → runs on myExecutor
    await withTaskGroup(of: X.self) { g in g.addTask { … } } // child tasks inherit the preference
}
let t = Task(executorPreference: myExecutor) { … }      // or per task
```

The rules (verified in the demo):
- **Nonisolated async functions, including `@concurrent` ones**, run on the preferred executor instead of the global pool.
- **Child tasks** (`async let`, TaskGroup) inherit the preference. Unstructured `Task {}` doesn't, unless you pass it.
- **Actor-isolated code ignores it.** An actor always runs on its own executor. Isolation beats preference.

Implementing one:
```swift
final class MyExecutor: TaskExecutor {
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        queue.async { job.runSynchronously(on: self.asUnownedTaskExecutor()) }
    }
}
```
`enqueue` receives a job, and you run it **somewhere you control**, exactly once.

**When is it useful?** Rarely, and that's the right answer in an interview. Examples: a thread-affine C library called from nonisolated async code; isolating heavy CPU work onto its own threads so it can't starve the cooperative pool; server workloads that pin work to event-loop threads (SwiftNIO). For most iOS code, `@concurrent` plus the default pool is right.

## 2. Predict (5 min)

Under `withTaskExecutorPreference(executor)`, where does each run: a `@concurrent` func, a plain async func, a TaskGroup child, and a method of an actor with its own custom executor? ______

## 3. Run (2 min)

```bash
swift run lab p6.02
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
without preference, @concurrent runs on: 'com.apple.root.default-qos.cooperative'
with preference: @concurrent → 'demo.task.executor', plain async → 'demo.task.executor', group child → 'demo.task.executor'
but an ACTOR keeps its own executor even under a preference → 'demo.legacy.queue'
```
The preference redirects everything that has no isolation of its own. Isolated code keeps its executor.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P6_02_TaskExecutor.swift`. Build `DedicatedThreadExecutor`: one OS thread that runs every enqueued job, FIFO. The test checks that all preferred work, including after `await`s and in child tasks, runs on that single thread.

```bash
swift test --filter P6_02
```

Think: why is it fine for *your* thread to block waiting for jobs, when blocking a cooperative-pool thread is forbidden?

## 6. Interview cards

- **What does `withTaskExecutorPreference` do?** It makes nonisolated async code (including `@concurrent` functions) and child tasks in that scope run on the given TaskExecutor instead of the global pool. Actor-isolated code still runs on its actor's executor.
- **Actor executor vs task executor?** A serial (actor) executor defines where an actor's isolated code runs. A task executor defines where nonisolated work runs for a task tree. Isolation takes precedence.
- **When would you use one?** Rarely: thread-affine native libraries, keeping heavy work from starving the shared pool, or event-loop architectures. The default pool is right for most app code.

## Going deeper
- [SE-0417 Task Executor Preference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0417-task-executor-preference.md)

---

<!-- nav:start -->
[← P6.01](./01-executors.md) · [Roadmap](../../README.md) · [P6.03 →](./03-runtime-costs.md)
<!-- nav:end -->
