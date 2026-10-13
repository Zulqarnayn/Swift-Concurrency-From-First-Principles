# P4.06 — Debounce and throttle ⭐

<!-- nav:start -->
[← P4.05](./05-rate-limiter.md) · [Roadmap](../../ROADMAP.md) · [P4.07 →](./07-token-refresh.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.06` · iOS lab **P4.06 Debounced search** · Exercise `P4_06`

## 1. Concept (5 min)

Both turn a burst of events into fewer actions:

| | Debounce | Throttle |
|---|---|---|
| Rule | Act **after** a quiet period of T; every new event restarts the timer | Act **at most once per** T |
| A burst of 10 events in 200 ms (T = 300 ms) | **1** action, 300 ms after the last event | **1** action at the start (leading edge), plus maybe one at the end (trailing edge) |
| Typical uses | Search-as-you-type, autosave, validation | Scroll handlers, "refresh" buttons, analytics, location updates |

**Debounce in async Swift** is P3.07's "cancel previous", with a sleep in front:
```swift
pending?.cancel()
pending = Task {
    try await Task.sleep(for: .milliseconds(300))   // a newer keystroke cancels this sleep
    let results = try await search(query)           // ...or this request, if it's already running
    try Task.checkCancellation()                    // finished just as we were superseded? drop it
    show(results)
}
```
One cancellation covers both the pending timer and the in-flight request. Without the final check, a stale response can still win (P3.07).

**Throttle (leading edge):** keep `lastRun`; if `now − lastRun < T`, drop the event. Record `lastRun` **before** awaiting the action (reentrancy).

Alternatives: Combine's `.debounce` / `.throttle` (the pre-async way), and `swift-async-algorithms`' `debounce(for:)` / `_throttle(for:)` on AsyncSequences.

## 2. Predict (5 min)

1. No debounce: "swift" typed one key every 8 ms; shorter queries are slower to answer. How many requests? What does the screen end on? ______
2. Combine `.debounce(50ms)`; "s", "sw", "swi" sent 10 ms apart. Emitted values? ______

## 3. Run (5 min)

```bash
swift run lab p4.06
# iOS: app → "P4.06 · Debounced search". Type fast with the toggle off, then on.
#   or: xcrun simctl launch --console-pty booted dev.learning.concurrency.lab -autorun search
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
5 searches; results applied in order ["swift", "s", "swi", "sw", "swif"] → the screen shows 'swif' for 'swift'
sent s, sw, swi 10ms apart → debounce emitted ["swi"]
```
iOS lab (simulator run):
```
debounce OFF: 5 requests … 🖥 screen now shows results for 's'   ← typed "swift", sees results for "s"
debounce ON:  ✂️ 's' cancelled … ✂️ 'swif' cancelled → 🌐 request 'swift' → 🖥 'swift'   (1 request)
```
Without debounce you get wasted requests **and a wrong screen**, the stale-result race. It looks like a UI glitch, but it's a concurrency bug.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_06_Debounce.swift`.
1. `DebouncedSearch.queryChanged`: debounce, cancel in-flight requests, never show stale results.
2. `Throttler.submit`: leading-edge throttle.

```bash
swift test --filter P4_06
```

## 6. Interview cards

- **Debounce vs throttle?** Debounce acts once after events stop for T (search, autosave). Throttle acts at most once per T while events keep coming (scroll, buttons, analytics).
- **Implement debounced search in Swift concurrency.** Keep the pending Task; on each keystroke cancel it and start a new one that sleeps for the delay, searches, re-checks cancellation, then publishes on the main actor. One cancellation covers both the timer and the in-flight request.
- **What's the stale-result race?** Responses arrive out of order, and an older, slower request overwrites a newer result. Fix it by cancelling superseded work and checking for cancellation (or comparing a request id) before applying.

---

<!-- nav:start -->
[← P4.05](./05-rate-limiter.md) · [Roadmap](../../ROADMAP.md) · [P4.07 →](./07-token-refresh.md)
<!-- nav:end -->
