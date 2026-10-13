# P2.13 — `@preconcurrency`, legacy code, and outside-in migration

<!-- nav:start -->
[← P2.12](./12-protocols-isolation.md) · [Roadmap](../../ROADMAP.md) · [P2.14 →](./14-massicotte-storage-stateful.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.13`, `p2.13b` (+ opt-in `p2.13c`) · Exercise `P2_13`

## 1. Concept (5 min)

Real apps mix Swift 6 code with code written before Sendable existed: Objective-C frameworks, Swift 5 modules, third-party SDKs. Swift has three tools for that boundary:

1. **`@preconcurrency import Module`.** "This module predates concurrency annotations." Sendable-related diagnostics about its types become warnings, or go away. The compiler itself suggests it: `warning: add '@preconcurrency' to treat 'Sendable'-related errors from module 'UnsafeZone' as warnings`.
2. **`@preconcurrency` on your own declarations** (protocols, conformances, functions), so *your* old clients aren't broken when you add annotations.
3. **Dynamic isolation checks (SE-0423).** Where Swift 6 code hands an isolated closure to code that can't be checked statically, the compiler inserts a runtime check that **traps** if the closure runs in the wrong domain.

Case 3 has a hole, verified in this lesson's demos:
- Pass a main-actor-inferred closure **as an argument** to a Swift 5 function that calls it off-main → **runtime trap** (loud, good).
- **Assign** the same closure **to a property** of a Swift 5 object, which later calls it off-main → **no check**. It silently runs on a background thread while mutating `@MainActor` state.

**Defense:** any callback you hand to legacy code that might call it on another thread should be **explicitly `@Sendable`**, touch only Sendable things (a continuation, an atomic), and hop to your actor through an `AsyncStream` (ordered) or `Task { @MainActor in }` (unordered).

**Outside-in migration** (Massicotte, [Migrating from the Outside in](https://massicotte.org/outside-in-migration/)):
1. Turn on complete checking as **warnings** first (Swift 5 mode + `-strict-concurrency=complete`), module by module.
2. Start at the **leaves** (models, networking, utilities): make value types Sendable, isolate UI types to `@MainActor`.
3. Work toward the UI. Use `@preconcurrency import` for dependencies you can't change, and track them.
4. Flip each module to Swift 6 mode once it's warning-free.
5. Don't sprinkle `@unchecked Sendable` / `nonisolated(unsafe)` to hit a deadline. Each one is a race you've agreed to keep.

## 2. Predict (5 min)

`LegacyThermometerClient` (Swift 5 module) calls `onReading` on a **background** queue.
1. `p2.13b`: on main, `client.onReading = { v in model.values.append(v) }`. Compiles? At runtime? ______
2. `p2.13c`: `LegacyScheduler.runInBackground { model.values.append(1) }` (closure as an **argument**). Runtime? ______
3. `p2.13`: an explicitly `@Sendable` callback yields into an AsyncStream consumed on main. Which threads? ______

## 3. Run (5 min)

```bash
swift run lab p2.13 && swift run lab p2.13b
swift run lab p2.13c     # opt-in crash
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
p2.13b: [+2ms] T1 | closure isolated to @MainActor just mutated main-actor state. On main? false
p2.13c: traps (SIGTRAP)
p2.13:  T1 legacy callback: 20 → MAIN main actor consumed 20 → …
```
1. It compiles (the closure is inferred `@MainActor`, so touching `model` is "fine"), then runs on T1. **A silent isolation violation**: a data race the compiler believed it had prevented. This is the hardest kind of migration bug to find, because nothing crashes.
2. Trap: the runtime check fired. Passing a closure as an argument to a Swift 5 function gets a check; storing it in a property didn't.
3. Callback on T1, consumption on MAIN, in order. The safe pattern.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P2_13_LegacyBridge.swift`. Bridge the legacy client into `@MainActor TemperatureModel` so readings arrive **in order, on the main actor**. The "obvious" one-liner is commented out. Don't use it.

```bash
swift test --filter P2_13
```

## 6. Interview cards

- **What does `@preconcurrency import` do?** It marks a dependency as predating concurrency annotations, so Sendable diagnostics involving its types become warnings or are suppressed. Use it for code you can't change, track it, and remove it when the dependency is annotated.
- **What are dynamic isolation checks?** Runtime checks (SE-0423) the compiler inserts where isolated code is handed to unchecked code, e.g. a `@MainActor` closure passed to a Swift 5 API. If it's called in the wrong domain, the app traps instead of racing.
- **How do you safely receive callbacks from legacy code on unknown threads?** Make the callback explicitly `@Sendable`, touch only thread-safe values in it, and hop to your actor via an AsyncStream (preserves order) or a Task. Don't let it be inferred `@MainActor`: a closure stored and called off-main may skip the runtime check entirely.
- **How would you migrate a large app to Swift 6?** Outside-in: complete checking as warnings, leaves first (models, networking), Sendable value types, `@MainActor` UI, `@preconcurrency` for third parties, Swift 6 mode per module once clean. Avoid `@unchecked` shortcuts.

## Going deeper
- [SE-0423 Dynamic actor isolation enforcement](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0423-dynamic-actor-isolation.md)
- Swift migration guide: [Migration strategy](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/migrationstrategy)
- Massicotte, [Migrating from the Outside in](https://massicotte.org/outside-in-migration/) · [The Problem With Combine Annotations](https://massicotte.org/combine-annotations/)

---

<!-- nav:start -->
[← P2.12](./12-protocols-isolation.md) · [Roadmap](../../ROADMAP.md) · [P2.14 →](./14-massicotte-storage-stateful.md)
<!-- nav:end -->
