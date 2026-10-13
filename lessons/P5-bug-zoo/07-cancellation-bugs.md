# P5.07 — Bug: "uploads keep running after leaving the screen; an error alert pops up on the next screen"

<!-- nav:start -->
[← P5.06](./06-task-leaks.md) · [Roadmap](../../ROADMAP.md) · [P5.08 →](./08-main-thread-hangs.md)
<!-- nav:end -->

⏱ 30 min · Repro `p5.07` · Exercise `P5_07`

## 🐞 Bug report #1288

> **Title:** Ghost uploads and a phantom error alert
> **Steps:** Start uploading a video, then go back before it finishes. → The upload still completes (visible on the web). Sometimes a "Upload failed" alert appears on the *next* screen.
> **Code:** `Sources/Exercises/P5_07_Upload.swift`. `upload(_:)` runs inside the screen's `.task {}`, so leaving the screen **does** cancel it.

## 1. Reproduce (3 min)

```bash
swift run lab p5.07
swift test --filter P5_07
```

## 2. Hunt (7 min)

Cancellation is a flag that code must **notice** (P3.06). Trace what happens to the cancellation flag through `upload` → `send` → the legacy uploader, in two cases:
- cancelled **during the 50 ms backoff** between attempts
- cancelled **while a request is in flight**

At each step, ask: does this code notice the cancellation, ignore it, or *swallow* it?

<details><summary>Hint 1</summary>
`try?` (P1.07, P4.11).
</details>
<details><summary>Hint 2</summary>
Who tells the legacy uploader that the task was cancelled?
</details>
<details><summary>Hint 3</summary>
What does the `catch` do with a `CancellationError` on the last attempt?
</details>

## 3. Fix + prove (15 min)

Requirements: leaving stops everything within milliseconds, the legacy request is cancelled, no alert for cancellation, and real retries and real failures still behave.

```bash
swift test --filter P5_07
```

## 4. Root cause

<details><summary>Spoiler: after your fix passes</summary>

Original code:
```
user leaves the screen during the retry backoff → cancel()
upload task ended 101ms later; attempts 2; uploaded ["vacation.mov"]; alerts []
```
The user left, and the app made a **second attempt** and **finished the upload** anyway.
1. **`try? await Task.sleep`** swallowed the cancellation: the backoff returned instantly and the next attempt started.
2. **No cancellation forwarding** to the legacy uploader (a continuation doesn't cancel anything by itself, P1.05).
3. **A catch-all that reports every error**, so a cancellation on the last attempt became an "Upload failed" alert, on whatever screen the user is looking at now.

Fix: `catch is CancellationError { return }` before the general catch; `try await Task.sleep` and exit if it throws; `withTaskCancellationHandler { … } onCancel: { uploader.cancel() }`; `try Task.checkCancellation()` before starting each attempt.
</details>

## 5. Interview cards

- **After leaving a screen, work continues and an error alert shows elsewhere. Causes?** Swallowed cancellation (`try?` on sleeps, catch-alls), legacy work not cancelled (no `withTaskCancellationHandler`), and cancellation treated as a failure (alerts and retries). Handle `CancellationError` separately: stop quietly.
- **What's the right way to write a retry loop's backoff?** `try await Task.sleep`, and exit when it throws. Never retry `CancellationError`. Check for cancellation before each attempt.

---

<!-- nav:start -->
[← P5.06](./06-task-leaks.md) · [Roadmap](../../ROADMAP.md) · [P5.08 →](./08-main-thread-hangs.md)
<!-- nav:end -->
