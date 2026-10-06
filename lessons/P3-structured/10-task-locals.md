# P3.10 — `@TaskLocal`: context that flows down the tree

<!-- nav:start -->
[← P3.09](./09-priority-yield.md) · [Roadmap](../../README.md) · [P3.11 →](./11-unstructured-tasks.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.10` · Exercise `P3_10`

## 1. Concept (5 min)

Some values describe the *current piece of work* rather than any object: a request id for logs, a trace span, the current user for auditing, a "dry run" flag in tests. Passing them as parameters through every function is noisy. A global is wrong, because concurrent requests would overwrite each other. Thread-locals are wrong in async code, because the thread changes at every `await` (P1.01).

**Task-local values** are attached to the **task**, not the thread:

```swift
enum RequestContext {
    @TaskLocal static var id: String?                     // declared static, with a default
}

await RequestContext.$id.withValue("req-42") {           // bind for the duration of this closure
    await handle()                                       // anything in here reads RequestContext.id == "req-42"
}                                                        // unbound again afterwards
```

| Inherited by | ? |
|---|---|
| `async let` children, TaskGroup children | ✅ |
| `Task {}` | ✅ (copied at creation) |
| **`Task.detached`** | ❌, so re-bind explicitly if needed |
| After `withValue` returns | ❌, so the binding can't leak |

Properties:
- **Read-only inside the scope.** You can only *rebind* for a nested scope (`withValue` again), which makes it safe across concurrent children.
- Lookups are cheap-ish but not free. Don't use it as a general dependency-injection container.
- Classic uses: logging/tracing context (swift-log metadata, swift-distributed-tracing), test overrides (Point-Free's `swift-dependencies` uses task-locals under the hood).

## 2. Predict (5 min)

Inside `withValue("req-42")`, what does each of these read: an `async let` child, a TaskGroup child, `Task {}`, `Task.detached`? And after `withValue` returns? ______

## 3. Run (5 min)

```bash
swift run lab p3.10
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
inside withValue:      req-42
async let child:       req-42
TaskGroup child:       req-42
Task {}:               req-42
Task.detached:         none
after withValue:       none
```
Detached drops it, which is the same pattern as isolation (P2.10) and priority (P3.09). "Detached" means "inherits nothing".
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_10_TaskLocal.swift`. Make every log line in `handle` carry the request id, including the concurrent children and the detached audit write (keep it detached; rebind instead).

```bash
swift test --filter P3_10
```

## 6. Interview cards

- **What are task-local values?** Values bound to a task for the duration of a scope with `$value.withValue(…)`, readable anywhere in that scope and inherited by child tasks and `Task {}`. Use them for request ids, tracing context and test overrides.
- **Why not thread-local storage in async code?** Tasks hop threads at suspension points, so a thread-local would be read by unrelated tasks, or lost after an `await`.
- **What doesn't inherit task-locals?** `Task.detached`. Capture the value and rebind inside it if needed.

## Going deeper
- [SE-0311 Task Local Values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0311-task-locals.md)
- [apple/swift-distributed-tracing](https://github.com/apple/swift-distributed-tracing): real-world task-local usage

---

<!-- nav:start -->
[← P3.09](./09-priority-yield.md) · [Roadmap](../../README.md) · [P3.11 →](./11-unstructured-tasks.md)
<!-- nav:end -->
