# P3.07 — Cancellation propagation, `.task(id:)`, owning unstructured tasks

<!-- nav:start -->
[← P3.06](./06-cancellation.md) · [Roadmap](../../README.md) · [P3.08 →](./08-timeouts.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.07` · iOS lab **P3.07 Task lifecycle** · Exercise `P3_07`

## 1. Concept (5 min)

**Cancellation flows down the task tree**: cancel a parent, and every `async let` and TaskGroup child (and their children) is cancelled. It does **not** flow into `Task {}` created inside, because those are new roots. Their only owner is whoever holds the handle.

So whenever you write `Task {}`, ask: **who will cancel this, and when?**

| Where you start work | Who cancels it |
|---|---|
| SwiftUI `.task { }` | SwiftUI, when the view disappears |
| SwiftUI `.task(id: x) { }` | SwiftUI, when `x` changes (cancels the old task, starts a new one) or the view disappears |
| `onAppear { Task { } }` | **Nobody.** It outlives the view (a leak, stale UI updates). |
| UIKit `Task {}` in `viewDidLoad` | You: store it, cancel in `viewDidDisappear` / `deinit` |
| "Latest wins" (search, refresh) | You: store `currentTask`, cancel it before starting the next |

**"Latest wins" has a second trap.** Cancellation is cooperative, so a superseded search might *finish* just as it's cancelled. Re-check (`try Task.checkCancellation()`) right before applying results, or a stale response can still overwrite a fresh one. The iOS lab shows a related subtlety: with `.task(id:)`, the **new task starts before the old one has finished reacting to cancellation**, so for a moment both are alive.

## 2. Predict (5 min)

1. `p3.07`: a parent task has an `async let` child, a TaskGroup child, and a `Task {}` created inside. Cancel the parent at 20 ms. Which children are cancelled? ______
2. iOS lab: two child views poll every 300 ms, one via `.task`, one via `onAppear { Task {} }`. Hide both. What keeps ticking? ______
3. iOS lab: change a `.task(id:)` value from 1 to 2. Which prints first, "id 2 started" or "id 1 cancelled"? ______

## 3. Run (5 min)

```bash
swift run lab p3.07
# iOS: run the app → "P3.07 — Task lifecycle"; toggle the children off; tap "Change id".
# or: xcrun simctl launch --console-pty booted dev.learning.concurrency.lab -autorun lifecycle
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
group child cancelled
async-let child cancelled
Task {} inside finished        ← a new root: the parent's cancellation never reached it
```
iOS lab (simulator run):
```
── hiding both child views ──
✅ .task cancelled after 4 ticks (view disappeared)
⚠️ onAppear Task tick 5
⚠️ onAppear Task tick 6  …keeps going after its view is gone
── changing the .task id ──
🔁 .task(id: 2) started
🔁 .task(id: 1) cancelled       ← the old task finished reacting AFTER the new one started
```
3. **The new task started first.** If both write the same state, the old one can still write after the new one began. Re-check cancellation before writing.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_07_CancelPrevious.swift`. `SearchModel.queryChanged` is called on every keystroke. Make only the latest query's results appear, and **cancel** superseded searches.

```bash
swift test --filter P3_07
```

## 6. Interview cards

- **Does cancelling a task cancel `Task {}`s created inside it?** No. Cancellation propagates only to structured children (`async let`, task groups). A `Task {}` is a new root; only its handle's owner can cancel it.
- **`.task` vs `onAppear { Task {} }`?** `.task` is tied to the view's lifetime: cancelled on disappear, restarted when `id` changes. `onAppear + Task` runs past the view's lifetime unless you store and cancel the handle.
- **How do you implement "latest search wins"?** Keep the current task; on a new query cancel it and start a new one; check cancellation again before applying results so a just-finished stale response can't win. (Add debounce in P4.06.)

## Going deeper
- Apple: [`task(id:priority:_:)`](https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:))
- WWDC25 [Explore concurrency in SwiftUI](https://developer.apple.com/videos/play/wwdc2025/266/)

---

<!-- nav:start -->
[← P3.06](./06-cancellation.md) · [Roadmap](../../README.md) · [P3.08 →](./08-timeouts.md)
<!-- nav:end -->
