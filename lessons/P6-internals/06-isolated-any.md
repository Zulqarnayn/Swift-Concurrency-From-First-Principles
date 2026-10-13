# P6.06 — `@isolated(any)` and `#isolation`

<!-- nav:start -->
[← P6.05](./05-memory-model.md) · [Roadmap](../../ROADMAP.md) · [P6.07 →](./07-swift-evolution.md)
<!-- nav:end -->

⏱ 30 min · Demo `p6.06` · Exercise `P6_06`

## 1. Concept (8 min)

A function *value* can be isolated: `{ @MainActor in … }` is a closure that must run on the main actor. Before Swift 6, a function type couldn't express "isolated to *some* actor; tell me which". **`@isolated(any)`** (SE-0431) can:

```swift
let work: @isolated(any) () async -> Void = { @MainActor in … }
work.isolation        // → MainActor (an `(any Actor)?` you can inspect at runtime)
```

Its most important user is **`Task.init` itself**, which takes an `@isolated(any)` closure. That gives the runtime a superpower:

> When you create `Task { @MainActor in … }`, the runtime knows the target actor up front, so it **enqueues the task directly on that actor's executor, at creation time**. Tasks created in order are enqueued in order.

Compare the version that looks equivalent:
```swift
Task { await sink.record(event) }        // closure NOT isolated: starts on the global pool,
                                          // THEN hops to main: siblings race on the way
Task { @MainActor in sink.record(event) } // enqueued on main immediately: FIFO with its siblings
```

**`#isolation`** (SE-0420) is the *static* counterpart: in a function, it evaluates to the caller's actor (P2.02, P2.10). Libraries declare `isolation: isolated (any Actor)? = #isolation` so their closures run on the caller's actor (e.g. `withTaskGroup`, `withCheckedContinuation`, AsyncSequence `next`).

| Need | Tool |
|---|---|
| Run a closure on the caller's actor (static) | `isolated (any Actor)? = #isolation` parameter, or `nonisolated(nonsending)` |
| Store or pass closures with arbitrary isolation and know it at runtime | `@isolated(any)` |
| Start work on an actor **in order** from nonisolated code | `Task { @ThatActor in … }` |

## 2. Predict (5 min)

From nonisolated code, 10 tasks per round, 20 rounds. How often is creation order preserved with `Task { @MainActor in log.add(i) }`? With `Task { await log.add(i) }`? ______

## 3. Run (3 min)

```bash
swift run lab p6.06
```

## 4. Explain (4 min)

<details><summary>Spoiler: open after running</summary>

```
  Task { @MainActor in log.add(i) }   → 20/20 rounds
  Task { await log.add(i) }           → 12/20 rounds
an @isolated(any) function value carries its isolation: f.isolation = MainActor
```
Same intent, one keyword apart, and only one is ordered. This is a cheap fix for P1.08-style ordering bugs when the destination is an actor: often you don't even need the AsyncStream serial queue.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P6_06_IsolatedAny.swift`. `forward` must deliver events to the main actor **in order** and stay synchronous. One small change.

```bash
swift test --filter P6_06
```

## 6. Interview cards

- **What is `@isolated(any)`?** A function-type attribute meaning the function may be isolated to any actor (or none), and the value carries that isolation at runtime (`.isolation`). `Task.init` takes such closures.
- **Why does `Task { @MainActor in … }` preserve order when `Task { await mainActorFunc() }` doesn't?** The first closure is statically main-isolated, so the task is enqueued directly on the main actor's FIFO executor when it's created. The second starts nonisolated on the global pool and hops later, so sibling tasks race (measured: 20/20 vs 12/20 rounds in order).
- **`#isolation` vs `@isolated(any)`?** `#isolation` is a compile-time expression for the current actor, used as a default argument to inherit the caller's isolation. `@isolated(any)` is a runtime property of function values with arbitrary isolation.

## Going deeper
- [SE-0431 `@isolated(any)` function types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0431-isolated-any-functions.md) · [SE-0420 Inheritance of actor isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md)

---

<!-- nav:start -->
[← P6.05](./05-memory-model.md) · [Roadmap](../../ROADMAP.md) · [P6.07 →](./07-swift-evolution.md)
<!-- nav:end -->
