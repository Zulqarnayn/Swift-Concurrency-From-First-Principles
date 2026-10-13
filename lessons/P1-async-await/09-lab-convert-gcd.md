# P1.09 — Lab: convert a GCD service to async/await

<!-- nav:start -->
[← P1.08](./08-async-entry-points.md) · [Roadmap](../../ROADMAP.md) · [P1.10 →](./10-review.md)
<!-- nav:end -->

<!-- dek: No new ideas today. You take a realistic piece of callback code, find where it can break, and rewrite it with everything from this phase. -->

⏱ 30 min · Exercise `P1_09`

There is no new concept in this session. You take a real-shaped piece of legacy code and modernize it, using everything from P1.01–P1.08.

## 1. Read the legacy code (5 min)

Open `Sources/Exercises/P1_09_FeedLab.swift` and read `LegacyFeedService.loadFeed`. It loads the current user, then their posts, then a thumbnail for each post in parallel with `DispatchGroup`, and finally calls back on a queue.

Before you write anything, list every place where a future edit could:
- forget to call `completion` ______
- call it twice ______
- call it on the wrong queue ______
- race on shared state ______

(One hint: the `Locked` box around `thumbnails` is there because the thumbnail callbacks run concurrently on different threads. Without it you would have P0.02's data race.)

## 2. Plan (5 min)

Answer these before coding:
1. Which callback APIs need wrappers, and which continuation kind does each one need (throwing or not)? ______
2. Typed throws: `withCheckedThrowingContinuation` produces `any Error`. How do you keep the `FeedError` type? (Hint: a non-throwing continuation that returns the `Result`, then `.get()`.) ______
3. Does your version need a lock for `thumbnails`? Why or why not? ______

## 3. Build (15 min)

Implement `ModernFeedService.loadFeed(token:) async throws(FeedError) -> Feed`.

```bash
swift test --filter P1_09
```

## 4. Compare (5 min)

<details><summary>Spoiler: after your tests pass</summary>

See `solutions/Exercises/P1_09_FeedLab.swift`.

1. Three wrappers. `currentUser` and `posts` can fail (`Result` → `.get()`); `thumbnail` can't, so it uses a plain `withCheckedContinuation`.
2. `let result = await withCheckedContinuation { c in api { c.resume(returning: $0) } }; return try result.get()`. `Result<_, FeedError>.get()` throws exactly `FeedError`.
3. No lock. Your version fetches thumbnails one after another in a single task, so nothing touches `thumbnails` concurrently, and a plain local `var` is safe.

   It is slower, though: 3 sequential thumbnail fetches instead of 3 parallel ones. Getting the parallelism back *without* reintroducing locks is what structured concurrency (`async let`, `TaskGroup`) is for, in P3.

Compare the sizes. The legacy version is about 35 lines with 5 levels of nesting, 1 group, 1 lock and 3 `callbackQueue.async` calls. The modern one is about 8 lines of logic, flat, and the compiler checks "exactly once" and error propagation for you.
</details>

## 5. Interview prompt (practice out loud)

> "Walk me through migrating a completion-handler networking layer to async/await. What breaks? What do you watch out for?"

A good answer covers these points:

- Wrap the leaf APIs with continuations, resuming exactly once.
- Bubble async upward "outside-in": start at the leaves, and keep sync façades with `Task {}` only at the UI edge.
- Map errors, using typed throws where the domain calls for it.
- Preserve *where* results are delivered, with main actor isolation instead of `DispatchQueue.main.async`.
- Don't add a Task per call, which loses ordering and errors.
- Restore parallelism with `async let` / TaskGroup.
- Forward cancellation with `withTaskCancellationHandler`.
- Test with async tests.

Read: Massicotte, [Migrating from the Outside in](https://massicotte.org/outside-in-migration/).

---

<!-- nav:start -->
[← P1.08](./08-async-entry-points.md) · [Roadmap](../../ROADMAP.md) · [P1.10 →](./10-review.md)
<!-- nav:end -->
