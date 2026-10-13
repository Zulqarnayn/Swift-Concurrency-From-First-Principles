# P3.08 — Build `withTimeout` ⭐

<!-- nav:start -->
[← P3.07](./07-cancellation-propagation.md) · [Roadmap](../../ROADMAP.md) · [P3.09 →](./09-priority-yield.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.08` · Exercise `P3_08`

## 1. Concept (5 min)

Swift has no built-in `withTimeout`. Building one is a favorite interview exercise, because it pulls together everything in P3: task groups, first-result-wins, cancellation, and error propagation.

The idea: **race the operation against a sleeping child; the first to finish wins; cancel the loser.**

```swift
try await withThrowingTaskGroup(of: T.self) { group in
    group.addTask { try await operation() }
    group.addTask { try await Task.sleep(for: limit); throw TimeoutError() }
    defer { group.cancelAll() }
    return try await group.next()!   // first finisher: a value, the operation's error, or TimeoutError
}
```

Why each part matters:
- `next()` returns the **first** child to finish, success or error.
- `cancelAll()` stops the loser. If the operation won, the sleep is cancelled. If the timer won, the operation is cancelled.
- If the **caller** is cancelled, both children are cancelled and the sleep throws `CancellationError`, not `TimeoutError`. That distinction matters to callers ("the user left" vs "the server is slow").

**The structural limit.** A group **always waits for all its children** before it returns. If the operation **ignores cancellation**, your 100 ms timeout returns only when that operation decides to finish. The alternative, used by `LabKit.withLabTimeout`, is an unstructured race that returns immediately and abandons the stuck work: the function returns on time, but the work leaks. There's no free lunch. Make operations cooperative.

## 2. Predict (5 min)

1. A 20 ms operation with a 100 ms limit: returns when? ______
2. A cooperative 1 s operation with a 100 ms limit: what, and when? ______
3. A 600 ms operation that **ignores cancellation**, 100 ms limit: what, and when? ______

## 3. Run (5 min)

```bash
swift run lab p3.08
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
fast operation, 100ms limit → finished in 24ms
cooperative slow op, 100ms limit → TimedOut() after 103ms
NON-cooperative op, 100ms limit → TimedOut() after 603ms (!)
```
3. The *result* is correct (TimedOut), but it arrived at 603 ms: the group waited for the stuck child. In an interview, mentioning this limitation unprompted is a strong signal.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_08_Timeout.swift`. Implement `withTimeout`. The tests check: a value comes back; a timeout throws `TimeoutError` **and cancels** the operation; the operation's own errors pass through; caller cancellation throws `CancellationError`.

```bash
swift test --filter P3_08
```

## 6. Interview cards

- **Implement a timeout for an async operation.** A ThrowingTaskGroup with two children: the operation, and a sleep that throws TimeoutError. Return `try await group.next()!` and `cancelAll()` the loser in a `defer`.
- **What's the limitation of a TaskGroup-based timeout?** The group waits for all children, so an operation that ignores cancellation delays the return past the limit. An unstructured race returns on time but leaks the stuck work. Fix the operation to be cooperative.
- **Timeout vs caller cancellation?** Different errors for different situations: TimeoutError means the dependency was too slow; CancellationError means the caller no longer wants the result. Don't conflate them (e.g. no error UI for cancellation).

## Going deeper
- Compare with `LabKit/Timeout.swift` (`withLabTimeout`): the unstructured design and why the course's tests need it

---

<!-- nav:start -->
[← P3.07](./07-cancellation-propagation.md) · [Roadmap](../../ROADMAP.md) · [P3.09 →](./09-priority-yield.md)
<!-- nav:end -->
