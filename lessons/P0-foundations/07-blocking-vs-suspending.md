# P0.07 — Blocking vs suspending; why completion handlers hurt

<!-- nav:start -->
[← P0.06](./06-starvation-inversion-explosion.md) · [Roadmap](../../README.md) · [P0.08 →](./08-review.md)
<!-- nav:end -->

⏱ 30 min · Demo `p0.07` · Exercise `P0_07`

## 1. Concept (5 min)

Two kinds of slow:

- **CPU-bound** means *working*: decoding an image, parsing JSON, sorting. It needs a core, and more cores help (up to Amdahl's limit).
- **I/O-bound** means *waiting*: network, disk, a timer, user input. **No thread needs to be involved while you wait.** The network card and the kernel do the work and raise an event when they're done.

While you wait for I/O, you have two options:

| | Blocking | Suspending |
|---|---|---|
| What happens | The thread sleeps in the kernel until data arrives | You hand off "the rest of the work" and return. The thread goes off to run other things. |
| Thread cost while waiting | 1 thread, doing nothing | 0 threads |
| Example | `Data(contentsOf: url)`, `semaphore.wait()` | `URLSession.dataTask(completion:)`, `await` |

A **completion handler** is suspension done by hand. You cut your function in two at the wait point, and pass the second half ("the rest of the function", a **continuation**) as a closure:

```swift
func loadProfile(id: String, completion: @escaping (Result<Profile, Error>) -> Void) {
    // part 1
    network.get(id) { result in
        // part 2: the continuation. Runs later, on some other thread.
    }
}
```

That works, but the compiler can't check the contract you rely on:

1. **Called exactly once.** Forget it on one path and the caller waits forever, silently. Call it twice and the caller's logic runs twice: duplicate UI updates, crashes on `group.leave()`.
2. **Called on the right thread/queue.** The callback arrives wherever the library felt like delivering it, and UIKit work there crashes or corrupts state.
3. Errors, cancellation, `[weak self]`, and nested callbacks ("pyramid of doom") are all handled by convention only.

`async/await` turns every one of these into **compiler-checked** structure: a function returns or throws **exactly once** on every path, and isolation decides where code runs. That's the motivation for all of Phase 1.

## 2. Predict (5 min)

Demo: `LegacyLoader.load(id, completion)` (see `Sources/Demos/P0_Foundations.swift`, the `P0.07` section). Read it, then predict for each `id`:

| id | Callback count | Queue it runs on |
|---|---|---|
| `"42"` | | |
| `"dup"` | | |
| `""` | | |

## 3. Run (5 min)

```bash
swift run lab p0.07
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
  id="42" callback #1: fresh 42  queue='com.apple.root.default-qos'
id="42" → callback called 1 time(s)
  id="dup" callback #1: cached dup  queue='com.apple.root.default-qos'
  id="dup" callback #2: fresh dup  queue='com.apple.root.default-qos'
id="dup" → callback called 2 time(s)
id="" → callback called 0 time(s)
```
- `"42"`: once, but on a **global background queue**, not main as the docs promised.
- `"dup"`: **twice**, because of a missing `return`. Real APIs do this *on purpose*, too: `PHImageManager.requestImage` calls your handler once with a low-quality image and again with the full one. You'll wrap one of those in P1.05.
- `""`: **never.** The caller hangs with no error, no log, no crash. The worst kind of bug.

All three compile cleanly. The type system has no notion of "exactly once".
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P0_07_Completion.swift`. `loadProfile` breaks its contract three ways. Fix all of them.

Pattern worth remembering: send **every** exit path through one local `finish(_:)` closure.

```bash
swift test --filter P0_07
```

## 6. Interview cards

- **Blocking vs suspending?** Blocking parks the thread until the event arrives, so the thread is wasted. Suspending saves the rest of the work as a continuation and frees the thread. I/O waits never need a thread.
- **I/O-bound vs CPU-bound?** I/O-bound waits on something external; you fix it with suspension and overlapping requests. CPU-bound computes; you fix it with parallelism across cores, kept off the main thread.
- **What's wrong with completion handlers?** The compiler can't check that they're called exactly once or on which queue. Errors and cancellation are handled by convention, nesting gets deep, and `self` capture causes retain cycles. `async/await` makes those structural guarantees.

## Going deeper
- WWDC21 [Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/): the first 10 minutes walk through this exact completion-handler mess
- Massicotte, [Concurrency Step-by-Step: A Network Request](https://www.massicotte.org/step-by-step-network-request/): read the "GCD" section now; you'll rebuild the whole thing in P2.01

---

<!-- nav:start -->
[← P0.06](./06-starvation-inversion-explosion.md) · [Roadmap](../../README.md) · [P0.08 →](./08-review.md)
<!-- nav:end -->
