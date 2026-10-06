# P2.08 — `nonisolated(nonsending)` vs `@concurrent` ⭐

<!-- nav:start -->
[← P2.07](./07-sending-regions.md) · [Roadmap](../../README.md) · [P2.09 →](./09-default-mainactor.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.08` · Exercise `P2_08`

## 1. Concept (5 min)

The single biggest change in Swift 6.2, and a guaranteed interview question if the team uses Xcode 26.

**Question:** where does a plain `nonisolated` async function run?

```swift
func loadAvatar() async -> Data { … }    // no annotation
```

| Rules | Answer | Name |
|---|---|---|
| Swift 5.7 – 6.1 (SE-0338) | **Always on the global concurrent executor**: it leaves the caller's actor | (now spelled `@concurrent`) |
| **Swift 6.2 with `NonisolatedNonsendingByDefault`** (Xcode 26 "Approachable Concurrency", this package) | **On the caller's actor**: called from main, it runs on main | `nonisolated(nonsending)` |

Why change it? Under the old rule, *every* call to a plain async function crossed a boundary, so every non-Sendable argument and every non-Sendable `self` triggered "sending … risks causing data races". Simple code produced walls of errors. Under the new rule, plain async code stays where it's called from, the same way **sync** functions always have. Crossing a boundary becomes something you ask for explicitly:

```swift
@concurrent func decode(_ data: Data) async -> Model   // explicitly: leave the caller, use the pool
```

Practical rules (this is Massicotte's [Synchronous Work](https://massicotte.org/synchronous-work/) idea):
- **Sync functions** run wherever they're called. That was always true.
- **Plain async functions** now behave the same way: caller's actor.
- **`@concurrent`** exists for one reason: to get CPU-heavy work *off* the caller's actor.
- Waiting (network, disk, timers) doesn't need `@concurrent`. Suspension already frees the actor.
- You can write `nonisolated(nonsending)` explicitly to get the new behavior in a module that doesn't have the feature on.

## 2. Predict (5 min)

All called from the main actor. MAIN or background?

| Call | Prediction |
|---|---|
| plain async func, module with Swift 6.2 rules | |
| plain async func, module with 6.0/6.1 rules (`Sources/LegacySemantics`) | |
| explicit `nonisolated(nonsending)` func in the old-rules module | |
| `@concurrent` func | |
| plain **sync** func | |

## 3. Run (5 min)

```bash
swift run lab p2.08
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
plain async, Swift 6.2 rules (nonsending)     → MAIN
plain async, Swift 6.0/6.1 rules              → background
explicit nonisolated(nonsending), old module  → MAIN
@concurrent                                   → background
plain SYNC func (any module, any rules)       → MAIN
```
Same source code, different thread, depending on a **build setting**. That's why migrating to Xcode 26 settings can quietly move work onto the main thread: a "background" helper written for 6.0 rules now runs on main if it's called from main. When you adopt approachable concurrency, look for CPU-heavy plain async functions and mark them `@concurrent`.

(Seen in P2.01's optional exercise too: `nonisolated` without `@concurrent` stayed on main.)
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P2_08_Pipeline.swift`. The annotations are exactly backwards: cheap validation leaves the main actor and heavy filtering runs on it. Fix by changing **annotations only**.

```bash
swift test --filter P2_08
```

## 6. Interview cards

- **Where does a nonisolated async function run in Swift 6.2?** With `NonisolatedNonsendingByDefault` (the Xcode 26 default for new projects), on the caller's actor (`nonisolated(nonsending)`, SE-0461). Before, it always hopped to the global concurrent executor. `@concurrent` is the explicit way to get that old behavior.
- **Why was the default changed?** Hopping off the caller's actor on every call made every non-Sendable argument and receiver cross a boundary, which produced many false-positive errors. Staying on the caller matches sync functions and makes non-Sendable types practical.
- **When do you use `@concurrent`?** For CPU-heavy synchronous work you want off the caller's actor (decoding, image processing). Not for waiting: `await` on I/O already frees the actor.
- **What breaks when a project adopts the new setting?** Helpers that were implicitly background now run on the caller's actor, e.g. the main thread. Audit CPU-heavy plain async functions and mark them `@concurrent`.

## Going deeper
- [SE-0461 Run nonisolated async functions on the caller's actor by default](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
- WWDC25 [Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)
- Massicotte, [Synchronous Work](https://massicotte.org/synchronous-work/)

---

<!-- nav:start -->
[← P2.07](./07-sending-regions.md) · [Roadmap](../../README.md) · [P2.09 →](./09-default-mainactor.md)
<!-- nav:end -->
