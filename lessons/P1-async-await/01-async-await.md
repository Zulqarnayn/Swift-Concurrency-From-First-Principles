# P1.01 — What `async` and `await` actually mean ⭐

<!-- nav:start -->
[← P0.08](../P0-foundations/08-review.md) · [Roadmap](../../README.md) · [P1.02 →](./02-under-the-hood.md)
<!-- nav:end -->

⏱ 30 min · Demo `p1.01`, `p1.01b` · Diagnostics `P1_01_async_from_sync.swift` · Exercise `P1_01`

## 1. Concept (5 min)

In P0.07 you split functions by hand at every wait point, using completion handlers. `async/await` has the **compiler** do that split for you.

- **`async`** on a function means *"this function is allowed to **suspend**"*: pause partway through, give up its thread, and resume later.
- **`await`** marks a **potential suspension point**: *"at this line my function may pause; the world may change before the next line runs."*

```swift
func loadProfile(id: String) async throws -> Profile {
    let data = try await network.get("/users/\(id)")   // may suspend here
    return try decode(data)                            // runs after resuming
}
```

Four rules to memorize:

1. **Suspending ≠ blocking.** While suspended, the function holds **no thread**. The thread goes off and runs other work. (Blocking parks the thread: P0.07.)
2. **`async` doesn't make code run in the background.** It only *allows* suspension. A CPU loop inside an `async` function hogs its thread just like sync code does.
3. **Between two `await`s, your code runs straight through,** like any sync code. Only at an `await` can other work interleave *in your isolation domain*. (This is the root of actor reentrancy, P2.)
4. **After an `await`, you may be on a different thread** unless something (like `@MainActor`) pins you. Never rely on thread identity: no `Thread.current`, no thread-local storage.

**Where does async code run?** (The full answer is "isolation", P2. For now, the working rules for this package, which match a new Xcode 26 project:)

| Declaration | Runs on |
|---|---|
| `@MainActor func f() async` | The main thread, always, before and after every `await` |
| `@concurrent func f() async` | The shared background pool (the "cooperative pool") |
| plain `func f() async` | **Wherever the caller is running** (Swift 6.2 `nonisolated(nonsending)` behavior) |

## 2. Predict (5 min)

`p1.01`: three `@concurrent` functions A, B, C run concurrently. Each traces, `await`s 20 ms, traces, `await`s 20 ms, traces. Then one `@MainActor` function does the same.

1. Will A print its three lines from the same thread each time? ______
2. Will the `@MainActor` function's lines all say `MAIN`? ______
3. `p1.01b`: 32 tasks (8 cores × 4). First each task **blocks** 100 ms, then each **suspends** 100 ms. Total time for each? ______
4. `Diagnostics/P1_01_async_from_sync.swift` has 4 functions. Which ones fail to compile? ______

## 3. Run (5 min)

```bash
swift run lab p1.01
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P1_01_async_from_sync.swift    # from repo root
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
T1   | A: before await #1
T1   | C: before await #1
T2   | B: before await #1
T4   | A: after  await #1      ← A hopped T1 → T4
T1   | A: after  await #2      ← ...and back to T1
MAIN | M: before await #1
MAIN | M: after  await #1
MAIN | M: after  await #2

32 async tasks that BLOCK 100ms each:   419ms
32 async tasks that SUSPEND 100ms each: 106ms
```
1. **No.** A resumed on whichever pool thread was free. The async frame (A's local variables) lives on the heap, not on a thread's stack, so any thread can pick it up (P1.02 explains how).
2. **Yes.** `@MainActor` code always resumes on the main thread.
3. **Blocking ≈ 400 ms** (32 tasks / 8 pool threads = 4 rounds). **Suspending ≈ 100 ms**, because nobody holds a thread while waiting. Same code shape, 4× difference, and both functions are marked `async`.
4. Diagnostics:
   ```
   error: 'async' call in a function that does not support concurrency      ← #1
   error: expression is 'async' but is not marked with 'await'              ← #2
   ```
   - #1: a sync function can't wait for async work. It has no way to suspend. Either make it `async` too ("async is contagious"), or *start* the work with `Task {}` without waiting (#4).
   - #2: `await` is mandatory. It's there for the **reader**: every place your function might pause and let other code run is marked.
   - #3 compiles: async code calls sync code freely, with no `await`.
   - #4 compiles: `Task {}` is the bridge from sync to async (P1.04).
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_01_Suspend.swift`. `slowSquare` is `async` but **blocks**. Make it suspend. Also: should you use `try` or `try?` on `Task.sleep`? One of the tests decides.

```bash
swift test --filter P1_01
```

## 6. Interview cards

- **What does `await` mean?** It marks a potential suspension point. The function may pause there, releasing its thread, and resume later, possibly on a different thread. Other code can run in between.
- **Does `async` make a function run in the background?** No. It only lets the function suspend. Where it runs depends on isolation (`@MainActor`, `@concurrent`, or the caller's context). CPU work inside an async function still occupies its thread.
- **Blocking vs suspending in async code?** Blocking (`sleep`, `semaphore.wait`, sync I/O) holds a cooperative-pool thread hostage and starves other tasks. Suspending (`await`) frees the thread.
- **Can you call async from sync?** Not directly. Make the caller async, or start a `Task {}` (fire-and-forget, you can't wait for its result synchronously).

## Going deeper
- [SE-0296 async/await](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0296-async-await.md): read "Motivation" and "Suspension points"
- WWDC21 [Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/)
- Massicotte, [A Swift Concurrency Glossary](https://massicotte.org/concurrency-glossary/)

---

<!-- nav:start -->
[← P0.08](../P0-foundations/08-review.md) · [Roadmap](../../README.md) · [P1.02 →](./02-under-the-hood.md)
<!-- nav:end -->
