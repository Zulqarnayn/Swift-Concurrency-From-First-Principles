# P2.03 — Actors vs serial queues ⭐

<!-- nav:start -->
[← P2.02](./02-isolation-first-principles.md) · [Roadmap](../../README.md) · [P2.04 →](./04-actor-reentrancy.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.03` · Exercise `P2_03`

## 1. Concept (5 min)

You already know the GCD pattern for protecting state:

```swift
final class Account: @unchecked Sendable {      // "trust me" to the compiler
    private let queue = DispatchQueue(label: "account")
    private var balance = 0
    func deposit(_ x: Int) { queue.sync { balance += x } }   // must remember the queue, EVERY time
}
```

An **actor** is that pattern built into the language:

```swift
actor Account {
    private var balance = 0
    func deposit(_ x: Int) { balance += x }   // no queue: the compiler routes every access for you
}
await account.deposit(5)                      // from outside: await
```

| | Class + serial queue | Actor |
|---|---|---|
| Who enforces "one at a time"? | You (forget one `queue.sync` and you have a race) | The compiler |
| Caller while waiting | **Blocks** a thread in `queue.sync` | **Suspends**; the thread is free |
| Calling your own method from inside | `queue.sync` inside `queue.sync` → **deadlock** (P0.05) | Plain sync call, no `await` |
| Two objects calling each other | Can deadlock (two queues `sync`ing each other) | No lock-style deadlock: `await` releases the actor |
| Priority inversion | Partly handled (QoS override) | Handled: priority escalation |
| Synchronous API possible? | Yes | No. Every call from outside is `async`. |
| Ordering | Strict FIFO | Not strictly FIFO (priority-ordered), and **reentrant** (P2.04) |

The last two rows are the real costs:
- **Everything becomes async for callers.** If you need a synchronous API (called from sync code, or a sync protocol requirement), an actor is the wrong tool; use a `Mutex` (P0.04).
- **Reentrancy:** an actor is only "one at a time" *between suspension points*. Next lesson.

**When to use an actor** (Massicotte, [When should you use an actor?](https://massicotte.org/actors/)): when you have **mutable state** that must be **shared across isolation domains**, *and* callers can live with async access. No mutable state means no actor ("stateless actors" are a smell). UI state belongs on `@MainActor`, not in a custom actor.

## 2. Predict (5 min)

Demo: 10,000 concurrent increments through a class + serial queue, then through an actor.
1. Do both end at exactly 10,000? ______
2. Which is faster? Why? ______
3. The actor records which threads its method ran on. 1 thread? Many? At most how many at the same time? ______
4. `incrementTwice()` calls `increment()` from inside the actor. Does it need `await`? Would the queue version deadlock? ______

## 3. Run (5 min)

```bash
swift run lab p2.03
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
class + serial queue: 10000 in 37ms (each caller BLOCKS in queue.sync)
actor:                10000 in 7ms (each caller SUSPENDS on await)
the actor ran on 4 different threads, max 1 at a time
incrementTwice() called increment() inside the actor without await → 10002
```
1. Both are correct.
2. Here the actor was ~5× faster. 10,000 tasks blocking pool threads in `queue.sync` starve the cooperative pool (P1.03); the actor version suspends instead. Don't treat this as a general benchmark. For tiny critical sections called from sync code, a `Mutex` beats both.
3. **Several threads, never two at once.** An actor guarantees mutual exclusion, not thread affinity. That's why you never use thread-local storage or `Thread.current` assumptions inside actors.
4. No `await`: same domain means synchronous. The GCD equivalent (`queue.sync` inside `queue.sync`) is the P0.05 crash.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P2_03_AccountActor.swift`.
1. Turn `AccountActor` from an unprotected class into a real `actor` (delete `@unchecked`).
2. Implement `transfer(_:to:)`. Where does the check-and-debit have to happen? While you `await other.deposit`, where is the money?

```bash
swift test --filter P2_03
```

Compare with P0.05. Can two actors transferring to each other deadlock? Why not?

## 6. Interview cards

- **Actor vs class with a serial queue?** Same idea, mutual exclusion over private state, but the compiler enforces it. Callers suspend instead of blocking, and calling yourself or each other can't deadlock. The costs: every external call is async, and actors are reentrant at suspension points.
- **Does an actor always run on the same thread?** No. Its executor runs jobs one at a time on whatever pool thread is free. Only `@MainActor` is tied to a thread.
- **Can two actors deadlock calling each other?** Not lock-style. Awaiting another actor releases the current one. You can still build a logical hang, e.g. two tasks each waiting on a continuation the other must resume.
- **When NOT to use an actor?** No mutable state (a "stateless actor"), callers that need synchronous access (use a Mutex), or UI state (use `@MainActor`).

## Going deeper
- [SE-0306 Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md)
- Massicotte, [When should you use an actor?](https://massicotte.org/actors/) · [Stateless Actors](https://massicotte.org/stateless-actors/)

---

<!-- nav:start -->
[← P2.02](./02-isolation-first-principles.md) · [Roadmap](../../README.md) · [P2.04 →](./04-actor-reentrancy.md)
<!-- nav:end -->
