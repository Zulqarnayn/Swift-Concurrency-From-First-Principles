# P3.06 — Cancellation from first principles ⭐

<!-- nav:start -->
[← P3.05](./05-discarding-task-group.md) · [Roadmap](../../README.md) · [P3.07 →](./07-cancellation-propagation.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.06` · Exercise `P3_06`

## 1. Concept (5 min)

**Cancellation in Swift is a flag, not a kill switch.** `task.cancel()` does exactly two things:
1. sets the task's (and all its children's) **`isCancelled`** flag, and
2. runs any registered **cancellation handlers**.

Nothing is stopped by force. A task stops only when its code **notices and chooses to stop**. That's *cooperative* cancellation, and the reason is safety: killing a thread midway can leave locks held and invariants broken.

How code notices:

| API | Behavior |
|---|---|
| `Task.isCancelled` | Read the flag; decide yourself (return partial results, clean up) |
| `try Task.checkCancellation()` | Throws `CancellationError` if the flag is set |
| `try await Task.sleep(…)` | **Throws immediately** when cancelled, even mid-sleep |
| `URLSession.data(for:)` and most Apple async APIs | Cancel the underlying request, throw `URLError(.cancelled)` / `CancellationError` |
| `withTaskCancellationHandler { op } onCancel: { }` | Run code **the moment** cancellation happens, e.g. to cancel a legacy request |

What doesn't stop:
- **CPU loops** that never check the flag (demo).
- **Continuations** waiting on legacy callbacks (P1.05). Nothing tells the legacy API, unless you forward it with `withTaskCancellationHandler`.
- Code that swallows it: `try? await Task.sleep` in a loop (P1.07).

`withTaskCancellationHandler` fine print:
- `onCancel` runs **concurrently** with the operation, on whatever thread called `cancel()`. Keep it tiny and thread-safe (it's `@Sendable`).
- If the task is **already cancelled**, `onCancel` runs **immediately, before the operation starts**. So your legacy wrapper must handle "cancelled before I even started the request".

## 2. Predict (5 min)

1. A CPU loop (count primes) is cancelled 10 ms in. When does it stop? ______
2. The same loop with `try Task.checkCancellation()` every 500 iterations? ______
3. A task with `withTaskCancellationHandler` is cancelled *before* it runs. Which prints first, "operation" or "onCancel"? What's `isCancelled` inside the operation? ______

## 3. Run (5 min)

```bash
swift run lab p3.06
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
cancel() at 12ms; it ran to completion anyway at 875ms → 1438
cancel() at 887ms; stopped at 893ms → failure(Swift.CancellationError())
  onCancel: runs
  operation: starts (isCancelled = true)
```
1. **It ignored cancellation entirely** and ran 860 ms more. Cancelling doesn't make anything stop on its own.
2. Stopped within ~6 ms, by throwing `CancellationError`.
3. `onCancel` ran **first**, before the operation began, and the operation started already cancelled.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_06_Cancellation.swift`.
1. `countPrimes`: make it respond to cancellation within milliseconds, without checking on every iteration.
2. `download`: forward cancellation to `LegacyDownload.cancel()`, and throw `CancellationError`. One test cancels **before** the download starts.

```bash
swift test --filter P3_06
```

## 6. Interview cards

- **What does `task.cancel()` do?** It sets the cancellation flag on the task and its children and runs cancellation handlers. It doesn't stop anything; code must check `isCancelled` / `checkCancellation()`, or use APIs that throw on cancellation.
- **How do you make CPU-heavy work cancellable?** Call `try Task.checkCancellation()` (or check `isCancelled`) periodically, cheaply enough that it doesn't dominate the cost.
- **How do you make a legacy callback API cancellable from async code?** Wrap the continuation in `withTaskCancellationHandler` and call the legacy `cancel()` in `onCancel`. Handle cancel-before-start, keep the handler thread-safe, and resume the continuation exactly once.
- **Why is Swift cancellation cooperative?** Forcibly stopping code could leave locks held, invariants broken and resources leaked. Cooperative cancellation lets the code stop at safe points and clean up.

## Going deeper
- Apple: [Task cancellation](https://developer.apple.com/documentation/swift/task#Task-Cancellation) · [withTaskCancellationHandler](https://developer.apple.com/documentation/swift/withtaskcancellationhandler(operation:oncancel:isolation:))

---

<!-- nav:start -->
[← P3.05](./05-discarding-task-group.md) · [Roadmap](../../README.md) · [P3.07 →](./07-cancellation-propagation.md)
<!-- nav:end -->
