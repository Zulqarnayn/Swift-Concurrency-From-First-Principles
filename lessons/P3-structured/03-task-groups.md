# P3.03 — TaskGroup and ThrowingTaskGroup ⭐

<!-- nav:start -->
[← P3.02](./02-async-let.md) · [Roadmap](../../ROADMAP.md) · [P3.04 →](./04-bounded-concurrency.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.03` · Diagnostics `P3_03a…`, `P3_03b…` · Exercise `P3_03`

## 1. Concept (5 min)

For a **dynamic** number of children (one per item), use a task group:

```swift
let thumbnails = await withTaskGroup(of: (Int, String).self) { group in
    for id in ids {
        group.addTask { (id, await api.fetch(id)) }   // child returns a value
    }
    var result: [Int: String] = [:]
    for await (id, url) in group {                    // results arrive in COMPLETION order
        result[id] = url                              // only the parent mutates
    }
    return result
}                                                     // group can't return until all children are done
```

Rules:
1. **Results come back in completion order**, not submission order. If order matters, carry an index (P3.04).
2. **Children return values; the parent collects them.** Children must not mutate shared local state. The compiler rejects it, and the child result type must be `Sendable` (see diagnostics).
3. The group **waits for all children** before `withTaskGroup` returns, even ones you never asked about.
4. **ThrowingTaskGroup:** iterate with `for try await` or `next()`. The first child error is rethrown. If that error **leaves the group's body**, the group **cancels all remaining children**, waits for them, and then rethrows.
5. ⚠️ **`waitForAll()` does NOT cancel siblings on error.** It waits for *every* child, then rethrows the first error (P3.12 puzzle 3). Use `for try await` or `next()` when you want fail-fast.
6. `group.cancelAll()` cancels every child explicitly. Children added after that start already cancelled.

`async let` vs TaskGroup: same structure and semantics. `async let` gives each child its own type and name; a group gives you a dynamic count with one result type.

## 2. Predict (5 min)

1. 5 children sleeping `[50, 10, 40, 20, 30]` ms, added in order 0…4. Result order? ______
2. A ThrowingTaskGroup of 4; child 2 throws at 20 ms, the others take 200 ms. What happens to 0, 1, 3? ______
3. `Diagnostics/P3_03a`: which of cases 1, 2, 4, 5 compile? `P3_03b`: can a child return a non-Sendable class? ______

## 3. Run (5 min)

```bash
swift run lab p3.03
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P3_03a_shared_mutation.swift
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P3_03b_child_results.swift
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
added in order [0,1,2,3,4], results arrived in order [1, 3, 4, 2, 0]
  child 0: cancelled after being started
  child 1: cancelled after being started
  child 3: cancelled after being started
group threw FetchFailed() — and every sibling was cancelled first
```
Diagnostics:
```
P3_03a: error: passing closure as a 'sending' parameter risks causing data races between code in the current task and concurrent execution of the closure   ← case 1
        error: sending 'total' risks causing data races                                                                                           ← case 5
P3_03b: error: type 'Thumbnail' does not conform to the 'Sendable' protocol   (×5)
```
- **Case 1** (children `append` to a shared array) is P0.02's data race, caught at compile time. Case 2 (children *return*, the parent collects) is the correct shape.
- **Case 4 compiles, case 5 doesn't.** An `async let` may mutate a captured `var` *if the parent doesn't touch it until after the await*: region analysis proves the child has exclusive access. Touch it in between (case 5) and it's rejected.
- Group child results cross from child to parent, so they must be `Sendable`.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_03_TaskGroup.swift`.
1. `thumbnails(for:)`: fetch concurrently and skip failures.
2. `requireAll`: all-or-nothing, failing fast. The test requires the error within 60 ms (the other fetches take 100 ms each) and **4 cancellations**. Pick your "wait" carefully (rule 5).

```bash
swift test --filter P3_03
```

## 6. Interview cards

- **In what order do TaskGroup results arrive?** Completion order. Carry an index or key if you need input order.
- **How do children share results safely?** They don't mutate shared state; each returns a Sendable value and the parent collects. The compiler rejects children mutating a captured var.
- **What happens when a child throws in a ThrowingTaskGroup?** The error is rethrown from `next()` / `for try await`. If it propagates out of the group body, the group cancels the remaining children, awaits them, and rethrows. `waitForAll()` is the exception: it waits for all children and doesn't cancel.
- **`async let` vs TaskGroup?** The same structured semantics. `async let` is for a fixed set of heterogeneous children, TaskGroup for a dynamic number of homogeneous children.

## Going deeper
- Apple: [TaskGroup](https://developer.apple.com/documentation/swift/taskgroup) · [ThrowingTaskGroup.waitForAll()](https://developer.apple.com/documentation/swift/throwingtaskgroup/waitforall(isolation:)) (read the note about cancellation)
- WWDC23 [Beyond the basics of structured concurrency](https://developer.apple.com/videos/play/wwdc2023/10170/)

---

<!-- nav:start -->
[← P3.02](./02-async-let.md) · [Roadmap](../../ROADMAP.md) · [P3.04 →](./04-bounded-concurrency.md)
<!-- nav:end -->
