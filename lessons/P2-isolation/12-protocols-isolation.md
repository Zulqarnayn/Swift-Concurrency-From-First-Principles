# P2.12 — Protocols and isolation; isolated conformances (SE-0470)

<!-- nav:start -->
[← P2.11](./11-globals-singletons.md) · [Roadmap](../../README.md) · [P2.13 →](./13-preconcurrency-migration.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.12` (+ opt-in `p2.12c`) · Diagnostics `P2_12a…`, `P2_12b…` · Exercise **Fixme** `P2_12_conformances.swift`

## 1. Concept (5 min)

A protocol requirement like `func describe() -> String` is **nonisolated**: anyone, anywhere, may call it synchronously. A `@MainActor` class implements it with a main-actor method. Those two facts conflict. Code on a background thread could call `describe()` through the protocol and read main-actor state.

Your options, in order of preference:

| Option | How | When |
|---|---|---|
| **1. Nonisolated witnesses** | `nonisolated func describe()` (or `nonisolated var cacheKey`) | The requirement only needs immutable (`let`, Sendable) data. Most `Equatable`/`Hashable`/`Identifiable` cases. |
| **2. Isolated conformance** (Swift 6.2, SE-0470) | `extension Model: @MainActor Describable`, or inferred automatically with `InferIsolatedConformances` | The witness really needs main-actor state. The conformance can then only be **used** on the main actor. |
| **3. Isolate the protocol** | `@MainActor protocol Describable` | Every conformer is UI-bound anyway. |
| **4. `@preconcurrency` conformance** | `extension Model: @preconcurrency Describable` | Migration only. Compiles, then **checked at runtime**: traps if called off main. |

**InferIsolatedConformances** is on in Xcode 26's approachable concurrency and in this package. With it, a `@MainActor` type's conformances are inferred `@MainActor` (option 2) automatically. The declaration compiles, and errors move to the places where the conformance is **used** off main. To get a conformance usable everywhere, write it as `nonisolated Hashable` **and** make every witness nonisolated.

## 2. Predict (5 min)

1. `P2_12a` (Swift 6.0/6.1 rules, no inference): `@MainActor final class ProfileModel: Describable`. Error? ______
2. `P2_12b` (with inference): uses 1, 2, 3, which fail? ______
3. `p2.12c`: an `@preconcurrency Describable` conformance called from `Task.detached`. Then what? ______

## 3. Run (5 min)

```bash
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_12a_conformance_without_inference.swift
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_12b_isolated_conformance_usage.swift
swift run lab p2.12
swift run lab p2.12c      # opt-in crash
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
P2_12a: error: conformance of 'ProfileModel' to protocol 'Describable' crosses into main actor-isolated code and can cause data races
P2_12b: error: main actor-isolated conformance of 'ProfileModel' to 'Describable' cannot be used in nonisolated context               ← 2
        error: main actor-isolated conformance of 'ProfileModel' to 'Describable' cannot satisfy conformance requirement for a 'Sendable' type parameter   ← 3
```
- Without inference, the *declaration* is rejected. With inference it's accepted as an isolated conformance, and the compiler checks every *use*: fine on main (1), rejected in `@concurrent` code (2) and wherever the value must be Sendable (3), since a Sendable value could carry the conformance off main.
- `p2.12c`: `on main: ["Grace"]`, then the process traps (SIGTRAP) when `describe()` runs on a background thread. `@preconcurrency` turns a compile-time error into a runtime check. Use it during migration, then replace it.
</details>

## 5. Exercise (10 min) — Fixme

File: `ConcurrencyLab/Fixme/P2_12_conformances.swift`. `Article` stays `@MainActor`, but background code needs its `Cacheable` and `Hashable` conformances. Don't touch `DiskCache`. Hint: which of Article's properties are safe to read from any thread?

```bash
scripts/fixme.sh ConcurrencyLab/Fixme/P2_12_conformances.swift
```

## 6. Interview cards

- **A `@MainActor` class must conform to `Equatable`. Problem? Fix?** `Equatable`'s `==` is nonisolated, but the class's members are main-actor. If equality only uses immutable Sendable data (an id), mark the witnesses `nonisolated` (and with inferred isolated conformances, write `nonisolated Equatable`). Otherwise use an isolated conformance, usable only on main.
- **What is an isolated conformance? (SE-0470)** A conformance that is itself isolated to a global actor (`extension M: @MainActor P`). The compiler only lets it be used from that actor, and never where the value must be Sendable. Swift 6.2 can infer it.
- **What does `@preconcurrency` on a conformance do?** It suppresses the static error and inserts a runtime isolation check that traps if a witness is called from the wrong domain. A migration tool, not a fix.

## Going deeper
- [SE-0470 Global-actor isolated conformances](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md)
- Massicotte, [Step-by-Step: Conforming to Protocols](https://massicotte.org/step-by-step-conforming-to-protocols/) · [Designing Protocols](https://massicotte.org/step-by-step-designing-protocols/) · [An Even Closer Look at Protocols and Global Actors](https://massicotte.org/blog/protocols-and-global-actors/)

---

<!-- nav:start -->
[← P2.11](./11-globals-singletons.md) · [Roadmap](../../README.md) · [P2.13 →](./13-preconcurrency-migration.md)
<!-- nav:end -->
