# P5.04 — Bug: "the location spinner sometimes spins forever"

<!-- nav:start -->
[← P5.03](./03-pagination.md) · [Roadmap](../../ROADMAP.md) · [P5.05 →](./05-pool-starvation.md)
<!-- nav:end -->

⏱ 30 min · Repro `p5.04` · Exercise `P5_04`

## 🐞 Bug report #1240

> **Title:** "Finding your location…" never finishes
> **Steps:** Open the store finder. → Spinner forever. Also: deny location permission → spinner forever. Also: leave the screen while it's searching, then come back: battery usage stays high.
> **Console (debug builds):** `SWIFT TASK CONTINUATION MISUSE: currentLocation(from:) leaked its continuation without resuming it. This may cause tasks waiting on it to remain suspended forever.`
> **Code:** `Sources/Exercises/P5_04_Location.swift` (the legacy API is in `Sources/UnsafeZone/Racy.swift`, at the bottom)

## 1. Reproduce (3 min)

```bash
swift run lab p5.04
swift test --filter P5_04
```

## 2. The checklist for a continuation that never resumes (5 min)

When a task waits forever on a continuation, go through **every path by which it could be resumed** and ask what happens on each:

1. **Success path:** does the callback even reach the code that resumes? (Is the receiving object still alive?)
2. **Every failure path:** is each error callback / delegate method implemented?
3. **Cancellation:** when the task is cancelled, does anything resume the continuation and stop the underlying work?
4. **"Never calls back" cases:** stopped, invalidated, timed out?
5. And the reverse: can two paths fire, so it gets resumed **twice** (a crash)? (P1.05)

Apply it to `P5_04.currentLocation` and `LocationCallbackAdapter`. There are **three** separate bugs.

<details><summary>Hint 1</summary>
Look at how the provider declares `delegate`. Who holds the adapter after the continuation closure returns?
</details>
<details><summary>Hint 2</summary>
`didFailWith` has a body. Read it.
</details>
<details><summary>Hint 3</summary>
Nothing in the code reacts to task cancellation (P3.06).
</details>

## 3. Fix + prove (15 min)

All three paths have to resume **exactly once**: success, denial, cancellation. Cancellation must also call `provider.stop()`.

```bash
swift test --filter P5_04
```

## 4. Root cause

<details><summary>Spoiler: after your fix passes</summary>

Original code: all three scenarios timed out, each printing `SWIFT TASK CONTINUATION MISUSE: … leaked its continuation`, and `provider stopped 0 time(s)`.

1. **Weak delegate → adapter deallocated.** `CLLocationManager`, `URLSession` and many Apple delegates are `weak`. The adapter was only referenced by a local inside the closure, so it was freed the moment the closure returned. No delegate, no callback; and because the continuation was destroyed with it, the runtime printed the "leaked" warning. Written as `provider.delegate = Adapter(…)` the compiler warns *"instance will be immediately deallocated because property 'delegate' is 'weak'"*. With a local `let` in between it stays silent.
2. **Unhandled failure callback:** `didFailWith` was empty.
3. **No cancellation forwarding:** a cancelled request kept the provider running and the continuation waiting.

The robust shape: keep the adapter alive for the whole wait (a local outside the closure), use a **take-once** continuation under a lock so any path can finish it safely, and use `withTaskCancellationHandler` to stop the provider and resume with `CancellationError`.

**Double-resume** is the opposite failure and crashes instead of hanging: `Fatal error: SWIFT TASK CONTINUATION MISUSE: … tried to resume its continuation more than once`. The take-once pattern prevents both.
</details>

## 5. Interview cards

- **A user reports a spinner that never stops, and the console says "leaked its continuation". What do you check?** Every resume path: is the callback receiver alive (weak delegates)? Are all error callbacks handled? Is cancellation forwarded? Can the API silently never call back? Fix with a take-once wrapper plus `withTaskCancellationHandler`.
- **How do you wrap a delegate-based API safely?** A strongly held adapter object for the duration of the await, a lock-protected optional continuation that's taken once by whichever path fires first (update, fail, cancel), and cancellation that also stops the underlying work.

---

<!-- nav:start -->
[← P5.03](./03-pagination.md) · [Roadmap](../../ROADMAP.md) · [P5.05 →](./05-pool-starvation.md)
<!-- nav:end -->
