# P7.05 — Timed kata: an observable async value

<!-- nav:start -->
[← P7.04](./04-kata-ordered-pipeline.md) · [Roadmap](../../ROADMAP.md) · [P7.06 →](./06-design-networking.md)
<!-- nav:end -->

⏱ **25 min coding** + 5 min debrief · Exercise `P7_05`

## The prompt

> "Our networking layer exposes connection state (`.offline`, `.connecting`, `.online`). Several screens and services need the current state *and* every change, using `for await`. Build `AsyncValue<Value>`: a thread-safe value with independent async subscribers. Slow subscribers shouldn't build a backlog; they should just see the latest state."

Spec and signature: `Sources/Exercises/P7_05_KataAsyncValue.swift`. (Think `CurrentValueSubject`, or Observation's `Observations`, for non-UI code.)

25-minute timer, narrate first, then `swift test --filter P7_05`.

## A strong answer mentions

- [ ] **One AsyncStream per subscriber** (AsyncStream is unicast: P1.06, P5.09)
- [ ] `bufferingNewest(1)`, because it's **state, not events**: conflate, never backlog (P1.06 buffering policies)
- [ ] The current value is delivered on subscribe, with no window where a `send` between "read current" and "register" is lost
- [ ] `onTermination` removes subscribers that stop listening (P5.09); `finish()` ends every loop
- [ ] Synchronization choice: a lock (`Mutex`) keeps `send` synchronous for callers (P0.04, P2.11); an actor would force `await` on every `send`
- [ ] Never call `yield` / `finish` while holding the lock (`onTermination` may re-enter it)

<details><summary>Debrief: reference solution notes</summary>

`solutions/Exercises/P7_05_KataAsyncValue.swift`. The subtle ordering in `values()`: **register the continuation under the lock, then yield the current value outside the lock.** If a `send` sneaks in between, the subscriber gets the newer value (the buffer of 1 keeps the latest), which is still correct for state semantics. Holding the lock while yielding risks deadlock, because yield can run `onTermination`, which takes the lock.
</details>

## Interview cards

- **Design a "current value + updates" async API.** One stream per subscriber (unicast), yield the current value on subscribe, `bufferingNewest(1)` for state semantics, a lock-protected subscriber map, `onTermination` cleanup, `finish()` to end all loops, and never yield while holding the lock.
- **Events vs state streams?** Events must all be delivered, in order (buffer, or apply backpressure: P4.01). State may be conflated: only the latest matters, so `bufferingNewest(1)`.

---

<!-- nav:start -->
[← P7.04](./04-kata-ordered-pipeline.md) · [Roadmap](../../ROADMAP.md) · [P7.06 →](./06-design-networking.md)
<!-- nav:end -->
