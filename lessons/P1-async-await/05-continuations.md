# P1.05 — Continuations: bridging callbacks to async ⭐

<!-- nav:start -->
[← P1.04](./04-task.md) · [Roadmap](../../ROADMAP.md) · [P1.06 →](./06-async-sequences.md)
<!-- nav:end -->

<!-- dek: You will call callback APIs from async code for years. A continuation is the bridge, and it has exactly one rule. -->

⏱ 30 min · Demo `p1.05`, `p1.05b` (+ opt-in `p1.05c`) · Exercise `P1_05`

## 1. Concept (5 min)

Here is an old weather API that takes a completion handler, wrapped so async code can `await` it:

```swift
func temperature(in city: String) async throws -> Int {
    try await withCheckedThrowingContinuation { continuation in
        LegacyWeather.fetchTemperature(city: city) { result in
            continuation.resume(with: result)       // Result → return or throw
        }
    }
}
```

The `continuation` value represents "the rest of this suspended task". You hand it to the callback, and the callback **resumes** the task with it. Step by step:

1. `withChecked…Continuation` suspends the current task and runs your closure synchronously, right away.
2. Your closure starts the legacy work and returns. The task stays suspended and uses no thread.
3. Later, from any thread, the callback calls `resume(returning:)`, `resume(throwing:)` or `resume(with:)`.
4. The task is enqueued back onto its own executor. A `@MainActor` caller continues on main even if the callback fired on a background queue.

The one rule: **resume exactly once, on every path.**

| Resumed | Result |
|---|---|
| 0 times | The task is suspended forever: a silent hang plus leaked memory. A *checked* continuation prints `SWIFT TASK CONTINUATION MISUSE: … leaked its continuation` when it's destroyed. |
| 2+ times | A crash: `Fatal error: SWIFT TASK CONTINUATION MISUSE: … tried to resume its continuation more than once` |

`withCheckedContinuation` adds the runtime checks in that table. `withUnsafeContinuation` skips them for a tiny speedup. Use the checked version unless profiling proves otherwise.

Four situations need care:

- Some APIs call back more than once. `PHImageManager.requestImage` delivers a degraded image first, then the full one. Resume once, on the final call.
- Some APIs sometimes never call back, through error paths that return early (the P0.07 bug). The task hangs forever. Read the legacy code, or add a timeout.
- Delegate APIs have no closure to resume from. Store the continuation in a property, resume it from the delegate method, then set the property to `nil`.
- Cancellation isn't automatic. If the task is cancelled, the legacy work keeps going. Bridging cancellation needs `withTaskCancellationHandler` (P3).

Before you wrap anything, check whether the compiler has done it already. Many Apple callback APIs have generated async versions: Objective-C `completionHandler:` methods are imported as `async`.

## 2. Predict (5 min)

1. `p1.05`, called from `@MainActor`: which thread prints `got 15`, the background thread that fired the callback or MAIN? ______
2. In which order do these appear: "body returned (task now suspended)" vs "legacy callback fires"? ______
3. `p1.05b`: the legacy API returns without calling the completion for "Atlantis". What do you see? ______
4. `p1.05c`: an API calls back twice and both calls `resume`. What happens? ______

## 3. Run (5 min)

```bash
swift run lab p1.05
swift run lab p1.05c     # opt-in crash
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
MAIN |   inside withCheckedContinuation: starting legacy call
MAIN |   inside withCheckedContinuation: body returned (task now suspended)
T1   |   legacy callback fires for Paris
MAIN | got 15
```
1. MAIN. The callback ran on T1 and called `resume`, and the task continued on its own executor, the main actor. The hop back is handled for you, with no `DispatchQueue.main.async`.
2. The body returns first. The closure runs synchronously and returns immediately; the callback comes 30 ms later.
3. The console shows:
   ```
   legacy callback fires for Atlantis
   SWIFT TASK CONTINUATION MISUSE: temperature(city:) leaked its continuation without resuming it. This may cause tasks waiting on it to remain suspended forever.
   Timed out after 1.0s (hang / deadlock / never-resumed continuation?)
   ```
   The warning appears when the dropped closure, and the continuation with it, is destroyed. Without the demo's 1 s timeout the caller would wait forever. (The trace shows T1 instead of MAIN here only because the timeout helper runs the work in its own Task.)
4. The console shows:
   ```
   Fatal error: SWIFT TASK CONTINUATION MISUSE: p1_05c() tried to resume its continuation more than once, returning 15!
   ```
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_05_Continuations.swift`.
1. Wrap `LegacyWeather.fetchTemperature` (throws on unknown cities).
2. Wrap `LegacyImageManager.requestImage` (calls back **twice**) and return only the full image.

```bash
swift test --filter P1_05
```

A question to think about afterwards: what if `requestImage` hits an error and never sends a non-degraded image? What would you change?

## 6. Interview cards

- **How do you wrap a completion-handler API in async?** `withCheckedThrowingContinuation { c in api { result in c.resume(with: result) } }`. The task suspends; the callback resumes it on the task's own executor.
- **What happens if a continuation is resumed zero times? Twice?** Zero: the task hangs forever (checked continuations log "leaked its continuation"). Twice: a fatal error crash. Every path must resume exactly once.
- **Checked vs unsafe continuations?** Checked adds runtime misuse detection (leak warning, double-resume crash). Unsafe skips it for speed. Default to Checked.
- **Does cancelling the task cancel the wrapped legacy work?** No. Use `withTaskCancellationHandler` to forward cancellation to the legacy API's cancel method (P3).

## Going deeper
- [SE-0300 Continuations for interfacing async tasks with synchronous code](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0300-continuation.md)
- Apple: [CheckedContinuation](https://developer.apple.com/documentation/swift/checkedcontinuation)

---

<!-- nav:start -->
[← P1.04](./04-task.md) · [Roadmap](../../ROADMAP.md) · [P1.06 →](./06-async-sequences.md)
<!-- nav:end -->
