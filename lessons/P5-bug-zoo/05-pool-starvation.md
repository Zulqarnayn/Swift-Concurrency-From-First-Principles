# P5.05 — Bug: "photo sync freezes for seconds" ⭐

<!-- nav:start -->
[← P5.04](./04-continuations.md) · [Roadmap](../../README.md) · [P5.06 →](./06-task-leaks.md)
<!-- nav:end -->

⏱ 30 min · Repro `p5.05` · Exercise `P5_05`

## 🐞 Bug report #1251

> **Title:** App sluggish / photos skipped during sync
> **Steps:** Queue 30+ photos for upload. → Everything async in the app crawls for several seconds (images, search, refresh). Some photos are silently never uploaded.
> **History:** v3.2 had "app hangs forever during sync"; v3.3 "fixed" it by adding a timeout. Now it's "only" slow.
> **Code:** `Sources/Exercises/P5_05_PhotoSync.swift`

## 1. Reproduce (5 min)

```bash
swift run lab p5.05
scripts/strict-pool.sh p5.05        # from the repo root: pool width 1 makes it obvious
swift test --filter P5_05
```

## 2. Hunt (8 min)

The sync loop *looks* fully async. Read **every function it calls**, and every function *those* call, and list each call that can **block a thread**. The compiler catches some blocking calls in async code (P1.03), but not through a synchronous helper.

<details><summary>Hint 1</summary>
There are three. One of them waits for a Task.
</details>
<details><summary>Hint 2</summary>
A legacy synchronous disk read can't be made non-blocking. But it doesn't have to run on the cooperative pool. Where else can blocking work go?
</details>

## 3. Fix + prove (12 min)

```bash
swift test --filter P5_05
scripts/strict-pool.sh p5.05       # should now finish quickly even with ONE pool thread
```

## 4. Root cause

<details><summary>Spoiler: after your fix passes</summary>

Original code:
```
16 concurrent syncs of 2 photos: 0/32 uploaded in 4018ms
```
**Zero** uploads: the "fix" in v3.3 turned a deadlock into a slow, silent data-loss bug.
1. **`wifiAvailable()`**: a semaphore bridge from async to sync (P1.03's anti-pattern). 16 syncs take all 8 pool threads, each parked waiting for a Task that needs a pool thread to run. Deadlock. The 1 s timeout "resolves" it, and the timeout path returns `false`, so every photo is skipped.
2. **`LegacyPhotoLibrary.thumbnailData`**: synchronous blocking disk I/O on a pool thread. Fix: run it on a **GCD queue** and await it with a continuation. GCD threads may block; cooperative pool threads may not.
3. **`pace()`**: `usleep` blocks a pool thread. Fix: `try await Task.sleep`.

The war story worth telling in an interview: **a timeout added to "fix" a hang usually hides a deadlock and turns it into a performance bug or data loss.**
</details>

## 5. Interview cards

- **The whole app's async work slows down whenever feature X runs. What do you suspect?** Cooperative pool starvation: something in X blocks pool threads (semaphore or group waits, sync I/O, sleeps, sync bridges to async). Confirm with strict pool mode and the Instruments Swift Concurrency template. Fix by awaiting async APIs and moving unavoidable blocking I/O to a GCD queue behind a continuation.
- **Where should blocking legacy calls run in a Swift concurrency app?** Off the cooperative pool: a dedicated DispatchQueue (or OperationQueue), bridged with a continuation. The pool only runs code that makes forward progress.
- **Why is "add a timeout" a dangerous fix for a hang?** It masks the deadlock: the system still stalls for the timeout, and the timeout path often has wrong semantics (here: skipped uploads).

---

<!-- nav:start -->
[← P5.04](./04-continuations.md) · [Roadmap](../../README.md) · [P5.06 →](./06-task-leaks.md)
<!-- nav:end -->
