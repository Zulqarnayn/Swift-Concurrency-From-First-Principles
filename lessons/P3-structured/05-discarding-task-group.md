# P3.05 — DiscardingTaskGroup and long-running work

<!-- nav:start -->
[← P3.04](./04-bounded-concurrency.md) · [Roadmap](../../README.md) · [P3.06 →](./06-cancellation.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.05` · Exercise `P3_05`

## 1. Concept (5 min)

A TaskGroup **keeps every child's result** until you take it with `next()`. That's fine for 10 thumbnails. It's a problem for a **long-running** group: a server accept loop, a websocket connection handling messages, a sync engine processing an endless stream of events. If you never read the results, they pile up in memory forever.

**`withDiscardingTaskGroup` / `withThrowingDiscardingTaskGroup`** (Swift 5.9):
- Children must return `Void`. Results are discarded as soon as a child finishes, so memory stays flat.
- There's no `next()` and no iteration. You just add children.
- It still waits for all children before returning (it's still structured).
- **Throwing variant:** the first child error **cancels the whole group** and is rethrown. That's right for "if any connection handler fails, tear down the server".

The typical shape is an accept loop:

```swift
await withDiscardingTaskGroup { group in
    for await connection in listener.connections {   // runs until the stream ends
        group.addTask { await handle(connection) }   // one child per connection
    }
}                                                    // returns after the stream ends AND all handlers finish
```

Compare with P1.08: one consumer task processing events **in order, one at a time**. Here, events are processed **concurrently**. Choose based on whether ordering matters.

## 2. Predict (5 min)

`p3.05`: 6 requests arrive 5 ms apart; each handler takes 30 ms. How many run at once? When does the group return? ______

## 3. Run (5 min)

```bash
swift run lab p3.05
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
server handled 6 requests, up to 5 at once, then the stream ended and the group returned
```
Requests overlap (30 ms handlers, arriving every 5 ms). The group returned only after the request stream finished **and** the last handler completed.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_05_Discarding.swift`. Make `serve` handle requests concurrently and return only once everything is handled.

```bash
swift test --filter P3_05
```

Then think: what changes if the handler can throw, and one failure should stop the whole server?

## 6. Interview cards

- **TaskGroup vs DiscardingTaskGroup?** TaskGroup keeps results until consumed with `next()`, so a long-running group you never read grows forever. DiscardingTaskGroup takes `Void` children and drops results immediately, which suits servers and event loops. Both wait for all children.
- **What happens when a child throws in a ThrowingDiscardingTaskGroup?** The group cancels all other children and rethrows the first error. Fail-fast for the whole group.
- **Process an event stream concurrently vs in order?** In order: one consumer loop (P1.08). Concurrently: a discarding task group with one child per event (bound it if needed, P3.04).

## Going deeper
- [SE-0381 DiscardingTaskGroups](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0381-task-group-discard-results.md)
- WWDC23 [Beyond the basics of structured concurrency](https://developer.apple.com/videos/play/wwdc2023/10170/) (the server example)

---

<!-- nav:start -->
[← P3.04](./04-bounded-concurrency.md) · [Roadmap](../../README.md) · [P3.06 →](./06-cancellation.md)
<!-- nav:end -->
