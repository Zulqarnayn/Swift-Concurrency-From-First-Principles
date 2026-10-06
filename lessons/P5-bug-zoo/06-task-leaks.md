# P5.06 — Bug: "memory grows every time the user opens a chat"

<!-- nav:start -->
[← P5.05](./05-pool-starvation.md) · [Roadmap](../../README.md) · [P5.07 →](./07-cancellation-bugs.md)
<!-- nav:end -->

⏱ 30 min · Repro `p5.06` · Exercise `P5_06`

## 🐞 Bug report #1266

> **Title:** Memory leak in chat
> **Steps:** Open a chat, go back, repeat 10 times. → Memory grows ~2 MB each time. Battery drains in the background. Network logs show unread-count polling continuing for chats that were closed long ago.
> **Memory Graph:** 10 × `ChatViewModel` alive. `deinit` never runs.
> **Code:** `Sources/Exercises/P5_06_Chat.swift`

## 1. Reproduce (3 min)

```bash
swift run lab p5.06
swift test --filter P5_06
```
In an app you'd use Xcode's **Debug Memory Graph** (the button in the debug bar): select the leaked `ChatViewModel` and follow the strong references back to the cycle.

## 2. Draw the ownership graph (7 min)

For each of the two `Task`s in `start()`, draw arrows: who holds the Task? What does the Task's closure hold? When does the Task end, if ever?

<details><summary>Hint 1</summary>
A Task's closure is retained until the Task finishes. How long does `for await message in backend.messages()` run?
</details>
<details><summary>Hint 2</summary>
The poller *does* say `[weak self]`. Then it immediately says `guard let self`. How long does that strong `self` live?
</details>

## 3. Fix + prove (15 min)

Requirements: after the screen closes, the view model deallocates, the message stream is terminated, and polling stops.

```bash
swift test --filter P5_06
```

## 4. Root cause

<details><summary>Spoiler: after your fix passes</summary>

Original code:
```
opened and closed the chat 5 times: 5 view models still alive, 5 message streams running, 20 polls in the last 50ms
```
1. **Listener:** `Task { for await … { messages.append(…) } }` captures `self` strongly (implicitly; Swift doesn't make you write `self.` in a Task closure on the same actor). The view model holds the Task, the Task holds the view model, and the loop never ends because the stream is endless. A cycle that never breaks.
2. **Poller:** `[weak self]` followed by `guard let self` **at the top** makes `self` strong again for the entire loop. The weak capture achieved nothing. This mistake is very common in production code.

Fix:
- Capture weakly and re-acquire `self` **only for the moment you need it**, inside the loop body, never across a long `await`.
- Get the stream *outside* the Task (so the closure doesn't need `self` to start it).
- **`isolated deinit`** (Swift 6.2, SE-0371) to cancel the tasks explicitly. It only runs once there's no cycle, so it's belt and braces, not the fix.
- SwiftUI alternative: start the loops in `.task {}`, which cancels on disappear (P3.07). Then the cycle ends when the view goes away.
</details>

## 5. Interview cards

- **Why does `Task { for await x in stream { self.handle(x) } }` leak?** The Task retains its closure until it finishes, the closure strongly captures `self`, and an endless stream means the Task never finishes. If `self` also stores the Task, it's a permanent cycle. Use weak capture with short-lived unwrapping, cancel the task when the owner goes away, or tie it to `.task {}`.
- **Does `[weak self]` plus `guard let self` at the top of a Task fix it?** No. The strong reference lives for the whole closure body, including the loop. Unwrap inside each iteration, only for the moment you need it.
- **How do you find this kind of leak?** The Xcode Memory Graph debugger (look for a Task-closure context in the reference path), the Leaks and Allocations instruments, and a `deinit` log or test that checks a weak reference becomes nil.

---

<!-- nav:start -->
[← P5.05](./05-pool-starvation.md) · [Roadmap](../../README.md) · [P5.07 →](./07-cancellation-bugs.md)
<!-- nav:end -->
