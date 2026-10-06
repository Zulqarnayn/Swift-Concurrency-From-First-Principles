# P2.14 — Massicotte labs: reading from storage + stateful systems

<!-- nav:start -->
[← P2.13](./13-preconcurrency-migration.md) · [Roadmap](../../README.md) · [P2.15 →](./15-nonsendable-first.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.14` · Exercise `P2_14`

## 0. Read first (12 min)

- [Concurrency Step-by-Step: Reading from Storage](https://massicotte.org/step-by-step-reading-from-storage/)
- [Concurrency Step-by-Step: Stateful Systems](https://massicotte.org/step-by-step-stateful-systems/)

You now know every concept they use. Read them as a review of P2.02–P2.13.

## 1. Concept (3 min)

**Reading from Storage** works through six designs for "load a model from disk without blocking main" and recommends the simplest:

> **Value types + a `@MainActor` store + a few nonisolated (`@concurrent`) helper functions.**

```swift
@MainActor final class NoteStore {
    private(set) var loaded: [NoteFile] = []                 // UI state: main actor
    func load(from url: URL) async throws {
        let data  = try await Self.readFile(url)              // @concurrent: I/O off main
        let notes = try await Self.decode(data)               // @concurrent: CPU off main
        loaded = notes                                        // state changes only here, on main
    }
}
```
Use `sending`, custom actors, or Swift 5 companion modules only when this design doesn't fit.

**Stateful Systems** is reentrancy (P2.04) in a real UI: a toggle backed by a slow remote. The rule:

> "We have to do any state accesses synchronously, before the task has any opportunity to suspend."

## 2. Predict (3 min)

`p2.14`, part 2: 4 rapid taps. Each tap does `await remote.toggle(); isOn = await remote.state`. How many times does the remote toggle? What's the final state? ______

## 3. Run (2 min)

```bash
swift run lab p2.14
```

## 4. Explain (3 min)

<details><summary>Spoiler: open after running</summary>

```
MAIN | NoteStore.load: start
T1   |   readFile (I/O)
T1   |   decode (CPU)
MAIN | NoteStore.load: assigned 2 notes
remote toggled 4 times; final remote false, UI false
```
The user tapped "on" (several times, impatiently) and the switch ended **off**. UI and remote agree, so nothing looks broken in the code. The user's intent was still lost. Four overlapping toggles, no data race, no crash: a logic race.
</details>

## 5. Exercise (7 min)

File: `Sources/Exercises/P2_14_Toggle.swift`. Ignore taps while a toggle is in flight. When the toggle finishes, `isOn` must match the remote.

```bash
swift test --filter P2_14
```

Where must the `inFlight` check happen relative to the first `await`? Why does a `defer` help?

## 6. Interview cards

- **How do you load and decode data without blocking the UI, in Swift 6.2?** Keep state in a `@MainActor` model. Do I/O and decoding in `@concurrent` (or nonisolated) static helpers that return Sendable value types. Assign the result back on main. No custom actor needed.
- **Users double-tap "Pay" and get charged twice. Fix?** Guard on the main actor with an in-flight flag, checked and set synchronously before the first `await`, and reset in `defer`. Also make the server request idempotent (an idempotency key), because the client can't be the only guard.

## Going deeper
- Massicotte, [ModelActor is Just Weird](https://massicotte.org/model-actor/) (SwiftData), [Testing with Event Streams](https://massicotte.org/blog/testing-event-stream/)

---

<!-- nav:start -->
[← P2.13](./13-preconcurrency-migration.md) · [Roadmap](../../README.md) · [P2.15 →](./15-nonsendable-first.md)
<!-- nav:end -->
