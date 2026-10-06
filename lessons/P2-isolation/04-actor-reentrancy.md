# P2.04 — Actor reentrancy ⭐⭐

<!-- nav:start -->
[← P2.03](./03-actors-vs-queues.md) · [Roadmap](../../README.md) · [P2.05 →](./05-global-actors.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.04` · Exercise `P2_04`

The #1 actor bug, and the #1 actor interview question.

## 1. Concept (5 min)

Remember P0.04 (check-then-act across two critical sections) and P0.03 (two atomic steps are not one atomic step). An actor gives you mutual exclusion **between suspension points only**:

```swift
actor Bank {
    var balance = 100
    func withdraw(_ amount: Int) async -> Bool {
        guard balance >= amount else { return false }   // ── critical section #1
        await fraudCheck()                               // ⚠️ SUSPENSION: actor is released
        balance -= amount                                // ── critical section #2
        return true
    }
}
```

While `withdraw` is suspended at `await`, the actor is **free** and runs the next queued call, which sees the *old* balance. That's **reentrancy**: the same actor method is entered again before the first call has finished.

Why did Swift choose this? A *non*-reentrant actor would hold itself locked across `await`, and that brings back deadlocks (A awaits B, B awaits A) and starves everyone waiting. Swift picked "no deadlocks" and asks you to handle interleaving.

**Rules:**
1. **Every `await` inside an actor is a point where any of its state may change.** After an `await`, re-validate any assumption you made before it.
2. **Do the check and the mutation in the same synchronous stretch.** Move awaits before the check or after the mutation, never between.
3. **For "do this expensive async thing once" (caches, token refresh), store the in-flight `Task`** before the first `await`, so later callers join it instead of starting their own.

```swift
if let running = inFlight[key] { return try await running.value }   // join
let task = Task { try await download(key) }
inFlight[key] = task                       // recorded BEFORE any await
let value = try await task.value
```

## 2. Predict (5 min)

1. Bank: balance 100, two concurrent `withdraw(80)` with a 20 ms fraud check between check and debit. How many are approved? Final balance? ______
2. Cache: `if cached return; await download; store`. 10 concurrent requests for the same URL. How many downloads? ______

## 3. Run (5 min)

```bash
swift run lab p2.04
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
A: check passed (balance 100) → awaiting fraud check...
B: check passed (balance 100) → awaiting fraud check...
A: debited 80 → balance 20
B: debited 80 → balance -60
approved: [true, true]  final balance: -60
downloads performed: 10
```
No data race anywhere, and Swift 6 compiles it all cleanly. Every access happened *inside* the actor. It's a pure logic race, exactly P0.04's shape.

Fixes for the bank, from best to worst:
1. **No await between check and act:** `guard balance >= amount; balance -= amount` (reserve), then `await fraudCheck()`; if it fails, refund.
2. Re-check after the await: `guard balance >= amount else { return false }` again after `fraudCheck()`.
3. An `inProgress` flag (P2.14).
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P2_04_ImageCache.swift`. Make `image(for:)`:
- share **one** download between concurrent requests for the same URL
- **not** cache failures (the next call retries)

```bash
swift test --filter P2_04
```

Extra challenge: what should happen if the first caller's task is **cancelled** while 9 others are joined to the same download? (Hint: unstructured `Task` isn't cancelled by its awaiters. Is that what you want? P3 revisits this.)

## 6. Interview cards

- **What is actor reentrancy?** While an actor method is suspended at an `await`, the actor can run other calls, including the same method. State you checked before the `await` may be different after it. Mutual exclusion holds only between suspension points.
- **Why are Swift actors reentrant?** Non-reentrant actors would hold their lock across awaits, which brings back deadlocks (actors awaiting each other) and long waits. Reentrancy trades that for interleaving that you have to handle.
- **How do you fix reentrancy bugs?** Keep check and mutation in one synchronous stretch (no `await` between them); re-validate state after every `await`; for once-only async work, store the in-flight `Task` before awaiting so concurrent callers join it.
- **Classic example?** An image cache that downloads the same URL N times, or token refresh called by N simultaneous 401s. Fix: a dictionary of in-flight tasks / single-flight.

## Going deeper
- Massicotte, [Concurrency Step-by-Step: Stateful Systems](https://massicotte.org/step-by-step-stateful-systems/): reentrancy in an app (P2.14 lab)
- WWDC21 [Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/) ("Actor reentrancy" chapter)

---

<!-- nav:start -->
[← P2.03](./03-actors-vs-queues.md) · [Roadmap](../../README.md) · [P2.05 →](./05-global-actors.md)
<!-- nav:end -->
