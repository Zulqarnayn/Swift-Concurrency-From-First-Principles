# P2.10 — Isolation inheritance: tasks, closures, isolated parameters

<!-- nav:start -->
[← P2.09](./09-default-mainactor.md) · [Roadmap](../../ROADMAP.md) · [P2.11 →](./11-globals-singletons.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.10` · Exercise `P2_10`

## 1. Concept (5 min)

When new code starts (a task, a closure, a call), which domain does it run in? The rules:

| Construct | Isolation |
|---|---|
| `Task { }` in a **global-actor** context (`@MainActor`) | Inherits it |
| `Task { }` in an **actor instance** method | Inherits the actor **only if the closure captures `self`** |
| `Task.detached { }` | Nonisolated, always |
| TaskGroup `addTask { }` / `async let` | Child tasks run nonisolated (concurrently) unless the closure says otherwise |
| Non-escaping, non-`@Sendable` closure (`forEach`, `map`) | Runs inline, in the caller's domain |
| `@Sendable` closure | Nonisolated |
| **Autoclosure** (`@autoclosure` param) | Nonisolated, so it *can't* see an actor instance's isolation |
| Plain async func (Swift 6.2) | Caller's domain (P2.08) |

**`isolated` parameters (SE-0313)** let a *function* borrow an actor's isolation:

```swift
func reserveAll(_ items: [String], in inventory: isolated Inventory) -> Bool {
    // runs ON `inventory`: synchronous access to its state, no awaits, no interleaving
}
await reserveAll(["A", "B"], in: inventory)   // callers outside hop once, at the call
```
It's the same as adding a method to the actor, but you can write it outside the actor: an extension in another module, a helper that works with several actor types, a generic function.

**`#isolation` (SE-0420)** as a default argument, `isolation: isolated (any Actor)? = #isolation`, makes a function run on **whatever actor called it**. Many stdlib APIs use it (`withTaskGroup`, `withCheckedContinuation`, `AsyncSequence.next`) so they can work with non-Sendable values without crossing boundaries. Swift 6.2's `nonisolated(nonsending)` gives async functions the same effect by default.

## 2. Predict (5 min)

`p2.10`, inside `actor Recorder`:
1. `Task { self.log.append(…); isolationLabel() }`? ______
2. `Task { isolationLabel() }` (no `self`)? ______
3. `Task.detached`? A TaskGroup child? ______
4. `appendBatch(_:to: isolated Recorder)` reports? ______

Bonus (a bug I hit writing this course): `trace("I am \(isolationLabel())")` inside `appendBatch` printed `nonisolated`. Why?

## 3. Run (5 min)

```bash
swift run lab p2.10
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
Task {} that uses self, inside actor → Recorder
Task {} that ignores self            → nonisolated
Task.detached inside actor           → nonisolated
TaskGroup child task                 → nonisolated
log = ["task", "closure 1", "closure 2"]
appendBatch runs as → Recorder
```
2. A closure is isolated to an *instance* only if it captures that instance (its isolation lives in `self`). Practical consequence: a `Task {}` inside an actor method that doesn't mention `self` runs **concurrently** with the actor.
- **Bonus:** `trace`'s message parameter is an `@autoclosure`, a closure that doesn't capture `recorder`, so `#isolation` inside it is `nil`. Evaluate `isolationLabel()` into a `let` first. The same rule as (2), in disguise.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P2_10_Inventory.swift`. `reserveAll` makes four separate trips to the actor, and other callers interleave between them, so stock goes negative. Make the whole check-and-take one uninterrupted job, **without editing `Inventory`**. The call site `await P2_10.reserveAll(items, in: inventory)` must keep compiling.

```bash
swift test --filter P2_10
```

## 6. Interview cards

- **Does `Task {}` inherit actor isolation?** From a global actor, yes. Inside an actor instance, only if the closure captures `self`. `Task.detached` never does.
- **What's an `isolated` parameter?** It makes a function run on the actor passed in, with synchronous access to its state. Callers outside hop once. Use it to make multi-step operations atomic without adding methods to the actor.
- **What does `#isolation` do?** Expands to the caller's current actor (or nil). As a default for an `isolated (any Actor)?` parameter, it makes a function run on whatever actor called it. Stdlib APIs use it to accept non-Sendable closures safely.
- **Why can many awaits on one actor still race?** Each `await actor.x()` is a separate job, and other tasks' jobs run in between. Group dependent steps into one synchronous actor job: an actor method, or a function with an `isolated` parameter.

## Going deeper
- [SE-0313 Improved control over actor isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0313-actor-isolation-control.md) · [SE-0420 Inheritance of actor isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md)
- Massicotte, [Is Dynamic Isolation Bad?](https://massicotte.org/dynamic-isolation)

---

<!-- nav:start -->
[← P2.09](./09-default-mainactor.md) · [Roadmap](../../ROADMAP.md) · [P2.11 →](./11-globals-singletons.md)
<!-- nav:end -->
