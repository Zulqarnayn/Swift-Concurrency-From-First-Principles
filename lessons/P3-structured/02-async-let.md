# P3.02 — `async let` ⭐

<!-- nav:start -->
[← P3.01](./01-structured-concurrency.md) · [Roadmap](../../ROADMAP.md) · [P3.03 →](./03-task-groups.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.02` · Exercise `P3_02`

## 1. Concept (5 min)

```swift
async let user = api.user()        // starts a CHILD task right now; no await yet
async let news = api.news()        // starts another, concurrently
let dashboard = try await Dashboard(user: user, news: news)   // await = wait for the values
```

- **`async let x = f()`** starts `f()` immediately as a child task. Your code keeps going.
- **`await x`** suspends until that child has produced its value (or rethrows its error).
- It's the right tool for a **fixed, known number** of concurrent operations. For "one per item in an array", use a TaskGroup.

The rules that interviewers test:

1. **Implicit cancel + await at scope exit.** If a scope ends (normal return *or* a thrown error) while an `async let` hasn't been awaited, Swift **cancels** that child and then **waits for it to finish**. It can't leak; it can only be cancelled. A child that ignores cancellation therefore *delays* your scope exit.
2. **Errors are observed when awaited, in the order you await.** In `try await (a, b, c)`, if `c` fails at 1 ms but `a` takes 5 s, you find out after 5 s. When "fail on the first error, whichever it is" matters, use a ThrowingTaskGroup.
3. When an error escapes, the remaining children are cancelled (rule 1).
4. You can't pass an `async let` around or store it. It's bound to its scope. The compiler warns if you name one and never use it; `async let _ = …` says "on purpose".
5. The initializer runs in a **child task**, so what it captures must be safe to send (P3.03's diagnostics).

## 2. Predict (5 min)

1. Three 100 ms calls sequentially vs with `async let`. Times? ______
2. An `async let` whose child sleeps 300 ms, never awaited. How long until the scope exits? ______
3. Same, but the child **ignores** cancellation (it waits on a legacy callback). How long? ______
4. `try await (bad, slow)`: `bad` throws at 30 ms, `slow` takes 500 ms. When does the error surface? What happens to `slow`? ______

## 3. Run (5 min)

```bash
swift run lab p3.02
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
sequential: 320ms
async let: 107ms
scope ends without awaiting the async let
  forgotten: cancelled after being started
scope took 0ms to exit (child was cancelled — and honored it)
scope ends without awaiting a child that IGNORES cancellation
  stubborn child: finished anyway (isCancelled = true)
scope took 319ms to exit: the implicit await waited for it
  failing child: throwing
  slow: cancelled after being started
failure surfaced after 34ms
```
2. The child was cancelled at the scope's end, honored it, and the scope exited in 0 ms.
3. **319 ms.** It was cancelled (`isCancelled = true`), but the implicit await still waited for it to finish. Structured concurrency doesn't kill tasks; it waits for them.
4. 34 ms, because `bad` comes first in the tuple. Swap the order to `(slow, bad)` and the error surfaces only after `slow` would have finished (try it).
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_02_AsyncLet.swift`. Fetch `user`, `news` and `weather` concurrently. The tests also check that when `news` fails, the long `weather` call was **started and then cancelled**.

```bash
swift test --filter P3_02
```

## 6. Interview cards

- **What does `async let` do?** It starts a child task immediately and binds its future value. `await` retrieves it. Use it for a fixed number of concurrent operations.
- **What happens to an `async let` you never await?** At scope exit it's cancelled, then awaited. It can't leak, but a child that ignores cancellation delays the scope's exit.
- **`try await (a, b, c)`: if `c` fails first, when do you find out?** Only when `c` is awaited, after `a` and `b`. Errors are observed in await order. Use a ThrowingTaskGroup to react to the first error in completion order.
- **`async let` vs `Task {}`?** `async let` is a structured child (scoped, cancelled with its parent, errors propagate). `Task {}` is an independent top-level task.

## Going deeper
- [SE-0317 async let bindings](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0317-async-let.md)

---

<!-- nav:start -->
[← P3.01](./01-structured-concurrency.md) · [Roadmap](../../ROADMAP.md) · [P3.03 →](./03-task-groups.md)
<!-- nav:end -->
