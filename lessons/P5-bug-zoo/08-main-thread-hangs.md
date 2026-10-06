# P5.08 — Bug: "tapping Export freezes the app" ⭐

<!-- nav:start -->
[← P5.07](./07-cancellation-bugs.md) · [Roadmap](../../README.md) · [P5.09 →](./09-ordering-streams.md)
<!-- nav:end -->

⏱ 30 min · Repro `p5.08` · iOS lab **P5.08 Main-thread hang** · Exercise `P5_08`

## 🐞 Bug report #1301

> **Title:** UI freezes on Export
> **Steps:** Notes list → Export. → The UI stops responding for a moment (spinner frozen, scrolling stuck). Xcode Organizer shows a top **Hang** report in `ExportModel.export`.
> **Dev's comment:** "Can't be: export is `async`, and we even moved compression into an `async` function."
> **Code:** `Sources/Exercises/P5_08_Export.swift`

## 1. Reproduce and measure (5 min)

```bash
swift run lab p5.08
swift test --filter P5_08
```

**Then profile it (the real-world skill, in the iOS lab):**
1. Open the app in Xcode, then **Product → Profile** (⌘I), and choose **Time Profiler**.
2. Record, open "P5.08 · Main-thread hang", and tap **Export (buggy)** a few times.
3. Look at the **Hangs** track: red intervals. Select one.
4. In the call tree, choose *Invert Call Tree* and *Hide System Libraries*, and filter to the **main thread**. The heaviest frames are `LabExporter.encode` / `compress`, on main.
5. Repeat with **Export (fixed)**: no hang, and the work shows up on a cooperative-pool thread.

The **Swift Concurrency** template shows the same thing from the task side: the export task *running* on the main thread for 500 ms.

## 2. Hypothesis (5 min)

For each of the two calls inside `export`, decide **which executor it runs on** and why. Use P2.08's rules.

<details><summary>Hint</summary>
A synchronous call from a `@MainActor` function runs on main. A plain `async` function under Swift 6.2 rules runs on… whose actor?
</details>

## 3. Fix + prove (10 min)

```bash
swift test --filter P5_08
```

## 4. Root cause

<details><summary>Spoiler: after your fix passes</summary>

```
p5.08 (original): the main thread's longest freeze was 201ms (a 60Hz frame is 16ms)
iOS lab: ■ buggy export: worst main-thread stall 500ms · ■ fixed export: worst main-thread stall 1ms
```
- `Exporter.encode`: a synchronous call from a `@MainActor` method, so it runs on main.
- `Exporter.compress`: a plain `async` function is `nonisolated(nonsending)` under approachable concurrency, so it **runs on the caller's actor: main**. Being `async` didn't move it anywhere (P2.01, P2.08).

Fix: a `@concurrent` helper that does both. Because `compress` is nonsending, it now inherits the helper's background executor. Only the `status` updates stay on main.

(One honest note from building this lesson: the first version of the repro harness read the stall meter *right after* `export()` returned, before the heartbeat task had a chance to record the gap, and reported 3 ms. A measurement can share the main actor with the thing it measures. Let it run before reading.)
</details>

## 5. Interview cards

- **"It's async, so it can't block the UI". True?** No. An async function's synchronous parts run on whatever executor it's isolated to. On `@MainActor` (or nonsending from main), CPU work blocks the main thread. Move CPU-heavy work into `@concurrent` functions.
- **How do you find what's hanging the main thread?** Time Profiler with the Hangs track: select the hang, invert the call tree, look at the main thread's heaviest stacks. In production: Xcode Organizer hang reports and MetricKit `MXHangDiagnostic`. In development: `MainActor.assertIsolated` / `dispatchPrecondition` and stall meters.

---

<!-- nav:start -->
[← P5.07](./07-cancellation-bugs.md) · [Roadmap](../../README.md) · [P5.09 →](./09-ordering-streams.md)
<!-- nav:end -->
