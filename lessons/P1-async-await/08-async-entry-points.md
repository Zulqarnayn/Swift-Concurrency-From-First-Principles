# P1.08 — Where async begins; keeping order across the boundary ⭐

<!-- nav:start -->
[← P1.07](./07-errors.md) · [Roadmap](../../README.md) · [P1.09 →](./09-lab-convert-gcd.md)
<!-- nav:end -->

⏱ 30 min · Demo `p1.08` · Exercise `P1_08`

## 1. Concept (5 min)

Async code can only be called from async code. So where does the **first** async context come from?

| Entry point | Notes |
|---|---|
| `@main struct App { static func main() async }` / top-level `main.swift` | The program starts async. Top-level code runs on the main actor. |
| **SwiftUI `.task { }` / `.task(id:) { }`** | Tied to the view's lifetime: **cancelled automatically** when the view disappears (or when `id` changes). Prefer it to `onAppear { Task { } }`. |
| `Task { }` from UIKit (`viewDidLoad`, `@IBAction`), delegates, notifications | You own the lifetime: store the handle and `cancel()` in `deinit`/`viewDidDisappear` if needed. |
| `@Test func x() async` / `XCTestCase` async methods | The test framework provides it. |
| `.refreshable { }`, `.onChange { Task {} }`, `AppIntent.perform()` | The framework calls you async. |

**The ordering trap.** Legacy code calls you synchronously and in order (delegates, sockets, CoreBluetooth, a NotificationCenter observer). The obvious bridge:

```swift
func didReceive(_ message: Message) {
    Task { await upload(message) }        // one Task per message
}
```

Every message becomes an independent task. They start roughly in order, but **they all run concurrently**, so a slow upload of message 1 finishes after a fast upload of message 2. If order matters (chat, edits, sync, analytics sessions), the data is now corrupt.

**Fix: an async serial queue.** *One* long-lived Task consumes an `AsyncStream`:

```swift
let (stream, continuation) = AsyncStream.makeStream(of: Message.self)
Task { for await m in stream { await upload(m) } }   // one at a time, FIFO
func didReceive(_ m: Message) { continuation.yield(m) }  // sync, never blocks
```

This pattern shows up all over production Swift: an ordered event pipeline from a sync world into async.

## 2. Predict (5 min)

8 messages arrive in order 1…8. Each upload takes `(message × 37) % 23` ms.
1. With one Task per message, in what order does the server receive them? (Compute the delays!) ______
2. With one consumer Task + AsyncStream? ______

## 3. Run (5 min)

```bash
swift run lab p1.08
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
— one Task per incoming message —
server received: 5 2 7 4 1 6 3 8
— one long-lived consumer Task + AsyncStream —
server received: 1 2 3 4 5 6 7 8
```
1. Delays: 1→14, 2→5, 3→19, 4→10, 5→1, 6→15, 7→6, 8→20 ms, so arrival order is sorted by delay: **5 2 7 4 1 6 3 8**. Every task started in order; their finish times decided everything.
2. **In order.** It's also slower: total = sum of all delays instead of the max. Ordering costs throughput. If you need both, upload concurrently but *apply* the results in order (sequence numbers).
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_08_Ordering.swift`. Make `MessageSyncer` preserve order without blocking `didReceive`. Think about:
- Where does the consumer `Task` get created? What does it capture? (Capturing `self` strongly creates a cycle: the task keeps `self` alive forever.)
- How does the consumer loop *end*? (Hint: `deinit` + `finish()`.)

```bash
swift test --filter P1_08
```

## 6. Interview cards

- **Where does async code start in an iOS app?** SwiftUI `.task` (auto-cancelled with the view), `Task {}` in UIKit lifecycle/actions/delegates (you manage cancellation), `@main` async, test methods.
- **`.task {}` vs `onAppear { Task {} }`?** `.task` is cancelled automatically when the view disappears and restarts when `id` changes. `onAppear + Task` leaks the work past the view's lifetime unless you store and cancel the handle.
- **How do you process sync events in order with async handlers?** One long-lived consumer task reading an AsyncStream (an async serial queue). One `Task` per event runs them concurrently and loses ordering.

## Going deeper
- Apple: [`task(priority:_:)`](https://developer.apple.com/documentation/swiftui/view/task(priority:_:)) and [`task(id:priority:_:)`](https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:))
- Massicotte, [Concurrency Step-by-Step: Stateful Systems](https://massicotte.org/step-by-step-stateful-systems/)

---

<!-- nav:start -->
[← P1.07](./07-errors.md) · [Roadmap](../../README.md) · [P1.09 →](./09-lab-convert-gcd.md)
<!-- nav:end -->
