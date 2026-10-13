# P2.05 — MainActor, global actors, and isolation inference ⭐

<!-- nav:start -->
[← P2.04](./04-actor-reentrancy.md) · [Roadmap](../../ROADMAP.md) · [P2.06 →](./06-sendable.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.05` (+ opt-in `p2.05c`) · Diagnostics `P2_05_inference.swift` · Exercise `P2_05`

## 1. Concept (5 min)

An actor *instance* protects its own state. A **global actor** is one shared isolation domain you can attach to anything: types, functions, properties, closures, even globals.

```swift
@globalActor actor DatabaseActor { static let shared = DatabaseActor() }

@DatabaseActor final class Database { … }      // the whole type lives in that domain
@MainActor func updateUI() { … }                // MainActor is just the most famous global actor
```

`@MainActor` is a global actor whose executor is the main thread. That's what lets UIKit and SwiftUI code be checked at compile time.

**Isolation inference.** Isolation also comes from places you didn't write:

| Source | Example |
|---|---|
| Annotating a type | `@MainActor final class Model`: all members, unless marked `nonisolated` |
| **Subclassing** | A subclass of a `@MainActor` class is `@MainActor` |
| **Protocol conformance** declared on the type | SwiftUI's `View` is `@MainActor`, so your view structs are too |
| **Non-`@Sendable` closures** | Formed in a `@MainActor` function, they're `@MainActor` |
| `Task {}` | Inherits the creator's actor |
| Module default (P2.09) | `-default-isolation MainActor`: everything |

It does **not** come from:
- **`@Sendable` closures** (they may run anywhere, so they're nonisolated), and `Task.detached`.
- **Property wrappers** (Swift 6 removed this inference, SE-0401).
- **Call sites.** Calling from main doesn't make a function `@MainActor`. Isolation comes from declarations.

**Avoid split isolation** (Massicotte): `@MainActor` on *some* methods of an otherwise non-isolated class makes the type awkward to use from anywhere. Isolate the whole type, or none of it.

**Bridging tools:**
- `MainActor.assumeIsolated { }`: "I *know* I'm on main (old API, documented main-queue callback); let me touch main-actor state synchronously." It's checked at runtime and **traps** if you're wrong. It's not even available in async code (`await` the `@MainActor` function there instead).
- `MainActor.assertIsolated()` / `preconditionIsolated()`: runtime assertions, like `dispatchPrecondition(condition: .onQueue(.main))`.

## 2. Predict (5 min)

1. `Diagnostics/P2_05_inference.swift` cases A–F: which are errors? ______
2. `p2.05`: what isolation does `LabDatabase.insert` report? A subclass of a `@MainActor` class? ______
3. `p2.05c`: `MainActor.assumeIsolated` called (via a sync helper) from a background thread. Then what? ______

## 3. Run (5 min)

```bash
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_05_inference.swift
swift run lab p2.05
swift run lab p2.05c          # opt-in crash
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
error: call to main actor-isolated instance method 'rename()' in a synchronous nonisolated context   ← B
error: main actor-isolated property 'title' can not be mutated from a Sendable closure              ← D
error: main actor-isolated property 'title' can not be mutated from a nonisolated context           ← F
```
- **A** compiles, and the subclass *is* `@MainActor` (that's why B fails).
- **C** is fine: a plain closure formed on main is main-isolated. **D** fails: `@Sendable` gives up isolation.
- **E** is fine: `Task {}` inherits main. **F** fails: detached inherits nothing.

```
LabDatabase.insert(row 1) → isolation: LabDatabaseActor
ScreenModel.render → MainActor
DetailModel.render (subclass) → MainActor
model.title = updated from a legacy main-queue callback
```
`p2.05c`: the process traps (SIGTRAP). Correct behavior: an assumption that turns out false must fail loudly.

Also try uncommenting `MainActor.assumeIsolated { }` directly inside `p2_05c`. It won't compile: *"unavailable from asynchronous contexts; await the call to the @MainActor closure directly"*.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P2_05_GlobalActor.swift`. Declare a `@globalActor` called `DatabaseActor` and isolate the **whole** `Database` class to it. Remove `@unchecked Sendable`. Keep `init()` callable from anywhere. (What keyword lets an init opt out of the type's isolation?)

```bash
swift test --filter P2_05
```

## 6. Interview cards

- **What is a global actor? Why is `@MainActor` one?** A single, app-wide isolation domain you can attach to types, functions and closures. `@MainActor`'s executor is the main thread, which lets the compiler check UI-thread rules.
- **How is isolation inferred?** From type annotations, superclasses, protocols that require it (e.g. SwiftUI `View`), the enclosing context for non-`@Sendable` closures and `Task {}`, and module default isolation. Not from `@Sendable` closures, `Task.detached`, property wrappers (Swift 6), or call sites.
- **When do you use `MainActor.assumeIsolated`?** In synchronous callbacks you know run on main but the compiler can't (legacy delegate APIs, main-queue callbacks). It traps if wrong. In async code, `await` a `@MainActor` function instead.
- **What's split isolation and why avoid it?** Isolating only some members of a type. Instances become awkward to use from any single domain. Isolate the whole type.

## Going deeper
- [SE-0316 Global actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md) · [SE-0401 Remove property-wrapper isolation inference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0401-remove-property-wrapper-isolation.md)
- Massicotte, [Problematic patterns](https://massicotte.org/problematic-patterns/) → "Split Isolation", "MainActor.run"

---

<!-- nav:start -->
[← P2.04](./04-actor-reentrancy.md) · [Roadmap](../../ROADMAP.md) · [P2.06 →](./06-sendable.md)
<!-- nav:end -->
