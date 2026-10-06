# P5.09 — Bug: "the second screen misses half the live updates, and never closes"

<!-- nav:start -->
[← P5.08](./08-main-thread-hangs.md) · [Roadmap](../../README.md) · [P5.10 →](./10-crash-forensics.md)
<!-- nav:end -->

⏱ 30 min · Repro `p5.09` · Exercise `P5_09`

## 🐞 Bug report #1317

> **Title:** Live scores: second screen out of sync; logout hangs
> **Steps:** Open the scoreboard on two screens (iPad split view). → Each screen shows only *some* goals, and never the same ones. Log out → the scoreboard screens never finish closing; their tasks are still running (Swift Concurrency instrument: tasks suspended forever in `for await`).
> **Code:** `Sources/Exercises/P5_09_EventHub.swift`

## 1. Reproduce (3 min)

```bash
swift run lab p5.09
swift test --filter P5_09
```

## 2. Recall, then hunt (7 min)

Without looking anything up, write down what you remember from P1.06 about AsyncStream: how many consumers, what ends a `for await` loop, and when `onTermination` fires. Then read `EventHub`.

<details><summary>Hint 1</summary>
How many `AsyncStream`s exist, and how many screens iterate it?
</details>
<details><summary>Hint 2</summary>
What makes a consumer's `for await` loop end? Does `shutdown()` do that?
</details>
<details><summary>Hint 3</summary>
When a screen stops listening, does the hub ever find out?
</details>

## 3. Fix + prove (15 min)

Requirements: every subscriber gets every event published after it subscribed, in order; `shutdown()` ends every subscriber's loop; subscribers that stop listening are removed; subscribing after shutdown returns an already-finished stream.

```bash
swift test --filter P5_09
```

## 4. Root cause

<details><summary>Spoiler: after your fix passes</summary>

Original code: both screens' tasks were still waiting 1 s after `shutdown()`. And in the unit test, the screens split the events between them.
1. **One AsyncStream shared by all screens:** AsyncStream is **unicast** (P1.06). Each element goes to one consumer, so two screens split the events. Fix: one stream per subscriber (a dictionary of continuations); `publish` yields into each.
2. **`shutdown()` did nothing:** a `for await` loop ends only when its stream finishes (or its task is cancelled). Fix: `finish()` every continuation.
3. **No unsubscription:** use `onTermination` to remove a subscriber when its consumer goes away.

A confession that teaches: the first version of this lesson's *test* kept `let stream = hub.subscribe()` in a local variable, broke out of the loop, and waited for `onTermination`. It never fired, because the stream was still referenced (P1.06, puzzle 6). The test now creates the stream inside the consuming task.
</details>

## 5. Interview cards

- **Two consumers iterate the same AsyncStream. What happens?** Values are split between them (unicast). For broadcast, give each subscriber its own stream and fan out on publish, or use a dedicated broadcast type.
- **A `for await` loop never ends. Why?** Its stream never finished (no `finish()`), and the consuming task wasn't cancelled. Every producer needs an explicit end-of-life: finish on shutdown or error.
- **How do you clean up after a subscriber that stops listening?** `continuation.onTermination`: it fires when the consumer is cancelled or drops the stream. Remove the continuation there.

---

<!-- nav:start -->
[← P5.08](./08-main-thread-hangs.md) · [Roadmap](../../README.md) · [P5.10 →](./10-crash-forensics.md)
<!-- nav:end -->
