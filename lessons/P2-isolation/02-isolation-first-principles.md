# P2.02 — Isolation from first principles

<!-- nav:start -->
[← P2.01](./01-network-request-lab.md) · [Roadmap](../../README.md) · [P2.03 →](./03-actors-vs-queues.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.02` · Diagnostics `P2_02_crossing.swift` · Exercise `P2_02` (graded predictions)

## 1. Concept (5 min)

In Phase 0 you protected mutable state at **runtime**: locks, serial queues, atomics. Nothing stopped you from forgetting the lock. Swift concurrency moves the protection to **compile time**.

**Isolation** is the compiler's answer to the question *"which code is allowed to touch this mutable state right now?"*

Every piece of Swift code lives in exactly one **isolation domain**:

| Domain | Written as | Who can touch its state synchronously |
|---|---|---|
| **Nonisolated** | default for plain code (in a normal module) | Code in this domain owns no shared mutable state. It can't touch any actor's state. |
| **Actor instance** | `actor Vault { … }` | Only code running *on that particular instance*. Each instance is its own domain. |
| **Global actor** | `@MainActor`, or your own `@globalActor` | Only code isolated to that global actor. There's one domain, shared by everything marked with it. |

The rules that come out of that table:

1. **Inside a domain, everything is synchronous.** An actor's methods touch its properties directly, with no locks and no `await`.
2. **Crossing into another domain requires `await`.** The call may have to wait its turn (the actor might be busy), so it's a potential suspension point.
3. **Only `Sendable` values can cross** (P2.06), because a value that crosses is now reachable from two domains.

A good mental model (Massicotte): isolation is a property of **declarations**, not threads. `@MainActor` *happens* to mean "main thread", but an actor instance runs on whatever pool thread is free, and a different one each time. Ask "which domain?", not "which thread?".

`#isolation` is a macro that evaluates to the **current domain's actor**, or `nil` when nonisolated. LabKit's `isolationLabel()` uses it to show you where you are:

```swift
public func isolationLabel(_ isolation: isolated (any Actor)? = #isolation) -> String
```

## 2. Predict (8 min)

Read `Sources/Puzzles/IsolationMap.swift`. For each call site `a`…`i`, what does `isolationLabel()` report: `"MainActor"`, `"nonisolated"`, or `"Ledger"`? Write your answers in `Sources/Exercises/P2_02_Predictions.swift`.

Then open `Diagnostics/P2_02_crossing.swift`: which of lines 1–6 are errors?

## 3. Run (4 min)

```bash
swift test --filter P2_02          # grades your map
swift run lab p2.02
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_02_crossing.swift      # from repo root
```

## 4. Explain (8 min)

<details><summary>Spoiler: open after running</summary>

```
a  inside a @MainActor function              → MainActor
b  plain SYNC func, called from main         → nonisolated
c  plain ASYNC func, called from main        → MainActor
d  @concurrent func, called from main        → nonisolated
e  actor method                              → Ledger
f  Task {} created on main                   → MainActor
g  Task.detached {}                          → nonisolated
h  Task {} inside an actor, not using self   → nonisolated
i  Task {} inside an actor, using self       → Ledger
```
- **b vs c is the subtle one.** Both are plain functions called from main, and both *run on the main thread*. But a **sync** nonisolated function has no isolation of its own; it just runs on whatever thread called it. A plain **async** function under Swift 6.2 rules is `nonisolated(nonsending)`: it takes on the caller's isolation, so `#isolation` reports MainActor. (P2.08 goes deep.)
- **d:** `@concurrent` always leaves the caller's domain.
- **f/g:** `Task {}` inherits the creator's isolation; `Task.detached` inherits nothing.
- **h/i:** inside an actor, `Task {}` inherits the actor **only if the closure captures `self`**. Instance isolation lives in `self`; a closure that doesn't capture it can't be isolated to it. Global actors (f) don't have this catch. (P2.10.)

Diagnostics:
```
error: call to actor-isolated instance method 'add' in a synchronous nonisolated context       ← 1
error: main actor-isolated property 'title' can not be referenced from a nonisolated context   ← 2
error: actor-isolated property 'secrets' can not be mutated from a nonisolated context         ← 3
```
- 1, 2: sync code can't wait its turn, so it can't cross a boundary.
- 3: even with `await`, **you can't mutate an actor's property from outside**. Mutation must happen inside the actor, through a method. This is deliberate: the actor stays in control of its invariants.
- 4, 5, 6 compile: crossing with `await`. Reads are allowed because the value comes back as a copy.
</details>

## 5. Exercise

The predictions you just graded are this lesson's exercise. Re-do any you got wrong in writing: one sentence each, *why*.

## 6. Interview cards

- **What is isolation?** A compile-time guarantee about which code may access a piece of mutable state. Every declaration is nonisolated, isolated to an actor instance, or isolated to a global actor. Same domain means synchronous access; crossing means `await`, and only Sendable values may cross.
- **Is an actor a thread?** No. An actor is an isolation domain with a serial executor. Its methods run one at a time, on whatever pool thread is available. `@MainActor` is the special case backed by the main thread.
- **Why can't you set an actor's property from outside, even with `await`?** Mutation has to go through the actor's own methods so the actor can keep its invariants. Reads from outside are allowed with `await`.

## Going deeper
- Massicotte, [An Introduction to Isolation](https://massicotte.org/intro-to-isolation) · [Isolation Intuition](https://massicotte.org/isolation-intuition)
- WWDC21 [Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/)

---

<!-- nav:start -->
[← P2.01](./01-network-request-lab.md) · [Roadmap](../../README.md) · [P2.03 →](./03-actors-vs-queues.md)
<!-- nav:end -->
