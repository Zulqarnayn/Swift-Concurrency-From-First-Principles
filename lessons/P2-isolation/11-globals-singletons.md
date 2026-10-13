# P2.11 — Globals, statics and singletons in Swift 6

<!-- nav:start -->
[← P2.10](./10-isolation-inheritance.md) · [Roadmap](../../ROADMAP.md) · [P2.12 →](./12-protocols-isolation.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.11` · Diagnostics `P2_11_globals.swift` · Exercise **Fixme** `P2_11_globals.swift`

## 1. Concept (5 min)

A global or static variable is state that **every domain can reach**. If it's mutable and unprotected, it's a data race waiting to happen. Swift 6 (SE-0412) therefore requires every global or static to be one of:

| Allowed | Example |
|---|---|
| `let` of a **Sendable** type | `let maxRetries = 3`, `static let shared = Analytics()` where `Analytics: Sendable` |
| **Isolated** to a global actor | `@MainActor var theme = "light"`, or everything in a MainActor-default module |
| Internally synchronized | `let counter = Atomic<Int>(0)`, `let cache = Mutex<[String: Data]>([:])` |
| The escape hatch | `nonisolated(unsafe) var legacy = false`: no checking, your responsibility |

**Singletons** are globals in disguise. `static let shared = Analytics()` is fine *only* if `Analytics` is Sendable. Pick:
- an **actor** (callers need `await`),
- `@MainActor` (UI singletons),
- a `final class: Sendable` with a `Mutex` inside (keeps a synchronous API),
- or rethink it: maybe it shouldn't be a singleton at all (Massicotte, [Singletons with Swift Concurrency](https://massicotte.org/singletons/)).

**Lazy initialization:** global and `static let` values are initialized **lazily, exactly once, thread-safely** (`swift_once`, the Swift equivalent of `dispatch_once`). **`lazy var` instance properties are not thread-safe.** Two threads can both run the initializer.

## 2. Predict (5 min)

1. `Diagnostics/P2_11_globals.swift`, globals 1–6: which are errors? ______
2. `p2.11`: 8 threads read a global `let` whose initializer has a side effect. How many times does it run? ______
3. 8 threads read a `lazy var` at the same time. How many times does its initializer run? ______

## 3. Run (5 min)

```bash
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_11_globals.swift
swift run lab p2.11
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
error: static property 'shared' is not concurrency-safe because non-'Sendable' type 'Analytics' may have shared mutable state   ← 4
error: var 'requestCount' is not concurrency-safe because it is nonisolated global shared mutable state                       ← 1
error: static property 'baseURL' is not concurrency-safe because it is nonisolated global shared mutable state                ← 3
```
2 (`let` of Sendable), 5 (`@MainActor`) and 6 (`nonisolated(unsafe)`, unchecked) compile.

```
8 threads read a global let: sum 336, initializer ran 1 time(s)
8 threads read a lazy var:   initializer ran 8 time(s)
```
A `lazy var` with an expensive or side-effecting initializer, shared across threads, gets initialized N times, and for reference types each thread may end up holding a *different* object. That's a classic bug in GCD-era singletons-within-objects. (The `lazy var` lives in the Swift 5 `UnsafeZone` module; Swift 6 wouldn't let you share that class across threads in the first place.)
</details>

## 5. Exercise (10 min) — Fixme

File: `ConcurrencyLab/Fixme/P2_11_globals.swift`. `trackRequest` is called from many threads and must stay **synchronous**. No escape hatches, no `@MainActor`.

```bash
scripts/fixme.sh ConcurrencyLab/Fixme/P2_11_globals.swift
```

## 6. Interview cards

- **Why does Swift 6 reject `var count = 0` at global scope?** Any domain can reach it, so unsynchronized mutation is a potential data race. Make it a `let` of a Sendable type, isolate it to a global actor, wrap it in `Atomic`/`Mutex`, or (last resort) `nonisolated(unsafe)`.
- **How do you make a singleton concurrency-safe?** `static let shared` of a Sendable type: an actor, a `@MainActor` class, or a final class protecting its state with a Mutex. Choose based on whether callers can be async and which domain owns it.
- **Is `static let` initialization thread-safe? `lazy var`?** Global/static lets are lazily initialized exactly once, thread-safely. `lazy var` isn't: concurrent first access can run the initializer several times.

## Going deeper
- [SE-0412 Strict concurrency for global variables](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md)
- Massicotte, [Singletons with Swift Concurrency](https://massicotte.org/singletons/)

---

<!-- nav:start -->
[← P2.10](./10-isolation-inheritance.md) · [Roadmap](../../ROADMAP.md) · [P2.12 →](./12-protocols-isolation.md)
<!-- nav:end -->
