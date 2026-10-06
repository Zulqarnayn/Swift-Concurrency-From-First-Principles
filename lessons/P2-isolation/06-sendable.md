# P2.06 — `Sendable` from first principles ⭐

<!-- nav:start -->
[← P2.05](./05-global-actors.md) · [Roadmap](../../README.md) · [P2.07 →](./07-sending-regions.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.06` · Diagnostics `P2_06_sendable_rules.swift` · Exercise **Fixme** `P2_06_make_it_sendable.swift`

## 1. Concept (5 min)

Isolation keeps each domain's state private. But values have to *move* between domains: arguments to actor methods, results of `@concurrent` functions, captures in tasks. **`Sendable`** marks a type whose values are **safe to share across isolation domains**: two domains holding "the same" value can't cause a data race.

Why can a type be safe to share?

| Reason | Types | Rule |
|---|---|---|
| **Copied, not shared** | structs, enums, tuples | Sendable if all their stored members are Sendable. *Implicit* for non-public types. |
| **Immutable** | `final class` with only `let` properties of Sendable types | Must be `final` (a subclass could add a `var`) |
| **Internally synchronized** | actors | Always Sendable: the actor *is* the synchronization |
| **Isolated** | `@MainActor` (any global-actor) classes | Always Sendable: only one domain can touch their state anyway |
| **Locked by you** | `final class: @unchecked Sendable` with a Mutex inside | The compiler **stops checking**. Your promise. |

Closures: a `@Sendable` closure may run concurrently, so it can't capture mutable local variables and everything it captures must be Sendable.

Non-Sendable types aren't bad. A non-Sendable class is perfectly safe **inside one domain**. Sendable only matters at boundaries. (P2.15 builds a whole design on that.)

**`@unchecked Sendable` is a lie detector you've unplugged.** Legitimate uses: a type that really is protected by a lock or a serial queue (P0.02), or wrapping an old library type you know is thread-safe. If you use it to "make the error go away", you've traded a compile error for a data race.

## 2. Predict (5 min)

1. `Diagnostics/P2_06_sendable_rules.swift`, types 1–8: which conformances are rejected? ______
2. `p2.06`: `LyingCounter: @unchecked Sendable` with a plain `var`. 8 tasks × 100,000 increments. Compile error? Result? ______

## 3. Run (5 min)

```bash
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_06_sendable_rules.swift
swift run lab p2.06
swift run --sanitize=thread lab p2.06   # then `swift build` to restore the normal build
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
error: stored property 'counter' of 'Sendable'-conforming struct 'Box' has non-Sendable type 'Counter'   ← 2
error: stored property 'name' of 'Sendable'-conforming class 'MutableConfig' is mutable                  ← 4
error: non-final class 'OpenConfig' cannot conform to the 'Sendable' protocol                             ← 5
```
1, 3, 6, 7, 8 are accepted. 7 and 8 don't even need to say `: Sendable`.

```
@unchecked Sendable counter: expected 800000, got 435573
```
2. **No compile error, nearly half the updates lost.** Swift 6's guarantee of no data races holds only for code you didn't opt out of. TSan flags it immediately.

**Interview phrasing:** "`@unchecked Sendable` moves the proof from the compiler to me. I only use it when the type is internally synchronized, and I document how."
</details>

## 5. Exercise (10 min) — Fixme

File: `ConcurrencyLab/Fixme/P2_06_make_it_sendable.swift`. It doesn't compile. Fix the **types** (not the logic) so it does. Escape hatches are forbidden and the grader checks for them.

```bash
scripts/fixme.sh ConcurrencyLab/Fixme/P2_06_make_it_sendable.swift
```

Each type needs a *different* fix. Ask of each one: is it a value? Immutable? Shared and mutated?

## 6. Interview cards

- **What does Sendable mean?** Values of the type can be safely shared across isolation domains: copied (value types of Sendable members), immutable (final class of lets), internally synchronized (actors), or isolated (global-actor classes).
- **Why must a Sendable class be final?** A subclass could add mutable state and break the guarantee.
- **Are actors and `@MainActor` classes Sendable?** Yes, implicitly. Their state can only be touched from their own domain, so sharing the reference is safe.
- **When is `@unchecked Sendable` legitimate?** When the type really is protected internally (a lock, a serial queue) or wraps a known thread-safe legacy type. Never as a way to silence errors. It disables checking, as a counter losing half its updates shows.
- **Is a non-Sendable type unsafe?** No. It's safe within one isolation domain; it just can't cross boundaries (except via `sending`, next lesson).

## Going deeper
- [SE-0302 Sendable and @Sendable closures](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
- Swift migration guide: [Data race safety → Sendable types](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety)
- Massicotte, [Problematic patterns](https://massicotte.org/problematic-patterns/) → "Redundant Sendable Conformances"

---

<!-- nav:start -->
[← P2.05](./05-global-actors.md) · [Roadmap](../../README.md) · [P2.07 →](./07-sending-regions.md)
<!-- nav:end -->
