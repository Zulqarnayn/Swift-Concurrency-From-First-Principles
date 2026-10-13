# P5.11 — Deterministic async testing

<!-- nav:start -->
[← P5.10](./10-crash-forensics.md) · [Roadmap](../../ROADMAP.md) · [P5.12 →](./12-timed-bug-hunt.md)
<!-- nav:end -->

⏱ 30 min · Exercise `P5_11`

## 1. Concept (8 min)

Most flaky async tests share one cause: **they use real time to wait for concurrent work** (`sleep(100ms)` and hope it's done). They fail on a busy CI machine and pass on your laptop. Bugs hide in exactly the interleavings that real time rarely produces.

Principles:
1. **Inject time.** Production code shouldn't call `Task.sleep` / `Date()` / `ContinuousClock.now` directly. Take a sleep function or a `Clock` as a dependency. Tests pass a **manual clock** and *advance* it.
2. **Inject the slow dependency, and script it.** A fake whose calls finish when the *test* says (`ScriptedResponder`, P5.01) lets you force any interleaving.
3. **Wait for events, not durations.** Swift Testing's `confirmation { … }`, an `AsyncStream` of events the code emits (Massicotte: [Testing with Event Streams](https://massicotte.org/blog/testing-event-stream/)), or polling a condition with a deadline. Not `sleep`.
4. **Let resumed work run before asserting.** After you release something, the resumed task needs a turn. Tools: `await settle()` (many `Task.yield()`s) in this course; Point-Free's [`withMainSerialExecutor`](https://github.com/pointfreeco/swift-concurrency-extras) makes all tasks in a test run serially on the main executor; [`swift-clocks`](https://github.com/pointfreeco/swift-clocks) provides `TestClock` and `ImmediateClock`.
5. **Then stress the real thing.** Deterministic tests prove the logic; stress plus TSan runs catch what your fakes don't model.

This course's tools (`LabKit/Deterministic.swift`):
```swift
let clock = ManualSleeper()
let model = AutosaveController(sleep: clock.sleep)   // inject
model.textChanged("a")
await clock.waitForSleepers(1)                        // wait for an EVENT (it's sleeping now)
await clock.advance(by: .milliseconds(499))           // time moves only when the test says
#expect(model.saves.isEmpty)
```

## 2. The exercise (17 min)

`Sources/Exercises/P5_11_Autosave.swift` has an injection point (`sleep`)… which it ignores. Make it testable, and then make it correct: the deterministic tests expose bugs that real-time tests would only show sometimes.

```bash
swift test --filter P5_11
scripts/stress.sh P5_11 100          # deterministic tests must pass 100/100, and fast
```

<details><summary>Hint 1</summary>
Does `textChanged` use the injected `sleep`?
</details>
<details><summary>Hint 2</summary>
What does `try?` do when a superseded autosave's sleep is cancelled? (Third time this pattern bites.)
</details>
<details><summary>Hint 3</summary>
Read `flush()`'s doc comment, then its body.
</details>

## 3. Root cause (5 min)

<details><summary>Spoiler: after your tests pass</summary>

1. **Untestable:** `Task.sleep` was called directly, so the injected clock had no effect, and the test could only wait in real time.
2. **Stale saves:** `try? await Task.sleep(…)` swallowed the `CancellationError` of every superseded edit, so each keystroke's cancelled task **saved immediately**. Typing "hello" saved "h", "he", "hel"… A real-time test probably would have passed, because each stale save happens *before* the final one. The deterministic test checks the exact sequence of saves.
3. **`flush()` dropped the pending text** instead of saving it, so closing the screen during the pause lost the last edit.

All three are invisible to "sleep 600 ms then check that the last save is the latest text".
</details>

## 4. Interview cards

- **How do you make async tests deterministic?** Inject clocks and slow dependencies; drive time and responses from the test; wait for events or conditions, not durations; let resumed work run before asserting (yielding, or a serial test executor); then stress-test the real implementation separately.
- **Why are sleep-based async tests bad?** They're flaky under load and slow, and they only exercise the interleavings real timing happens to produce, which are the ones least likely to have bugs.
- **How do you test a debounce?** Inject a manual clock. Make an edit; advance just under the delay and assert nothing happened; make another edit; advance past the delay and assert exactly one action with the latest value; and check that cancelled waits don't trigger actions.

---

<!-- nav:start -->
[← P5.10](./10-crash-forensics.md) · [Roadmap](../../ROADMAP.md) · [P5.12 →](./12-timed-bug-hunt.md)
<!-- nav:end -->
