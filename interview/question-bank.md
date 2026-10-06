# Interview question bank

Questions grouped the way interviewers group them. Every section points to the lesson that answers it; model answers are in `flashcards.md`. Try each question cold first, out loud, then check.

Practice format: set a 2-minute timer per question and answer out loud. A good answer goes **definition → mechanism → example → trade-off**.

---

## GCD and OperationQueue (your home turf: make these flawless)

1. **Serial vs concurrent queue?** A serial queue runs one block at a time in FIFO order. A concurrent queue can start several blocks at once (still dequeued in FIFO order), up to the system's width.
2. **`sync` vs `async`?** `async` enqueues and returns immediately. `sync` enqueues and waits until the block has run. The *calling* thread blocks; the block may run on the caller's thread as an optimization.
3. **What happens with `DispatchQueue.main.sync {}` on main?** Deadlock. libdispatch crashes ("dispatch_sync called on queue already owned by current thread").
4. **How does a barrier work, and on which queues?** On a *custom concurrent* queue, a barrier block waits for all earlier blocks, runs alone, and then later blocks run. On global queues barriers are ignored (they behave like normal async). Use: readers–writer lock.
5. **`DispatchGroup` `wait` vs `notify`?** `wait` blocks the caller until the group empties (don't use it on main or in async code). `notify` schedules a block for when it empties, without blocking.
6. **What's QoS, and does it reorder a serial queue?** It's a priority class (userInteractive → background) that affects CPU scheduling, energy and I/O. It doesn't reorder a serial queue (FIFO always). A high-QoS item can *raise* the queue's effective QoS (override), which is how inversion is avoided.
7. **Target queues?** A queue can target another queue. Blocks ultimately run on the root of the hierarchy, which lets you serialize several queues through one, or set QoS for a subsystem.
8. **`DispatchSemaphore` use cases and dangers?** Limiting width (counting semaphore), turning async into sync. Dangers: blocking (main thread, pool threads), no priority inheritance (inversion), deadlock.
9. **`OperationQueue` vs GCD?** Operations add dependencies, `maxConcurrentOperationCount`, cancellation state, KVO-observable state, and reuse. GCD is lower-level and lighter.
10. **How do you cancel GCD work?** `DispatchWorkItem.cancel()` only prevents work that hasn't started. Running work has to check a flag. (Compare: Swift task cancellation is cooperative too.)
11. **`dispatch_once` / thread-safe lazy init in Swift?** Global and `static let` are lazily initialized exactly once, thread-safely (swift_once). An instance `lazy var` is **not** thread-safe.
12. **Thread explosion?** See flashcards P0.06.

## Threading fundamentals (language-agnostic) — answered in P0
Data race vs race condition · atomicity and CAS · memory ordering · mutex vs semaphore vs condition variable · deadlock conditions · livelock/starvation · priority inversion · Amdahl's law · blocking vs non-blocking I/O → see `flashcards.md` § P0.

Extra, practice cold:
- **Mutex vs binary semaphore?** A mutex has an *owner*: only the locker unlocks, and it supports priority inheritance and re-lock detection. A semaphore has no owner: any thread can signal, which makes it suitable for signaling events but not for ownership.
- **What's a condition variable?** Wait until a predicate becomes true, *releasing the mutex while waiting*. Always re-check the predicate in a `while` loop (spurious wakeups).
- **Spinlock vs mutex?** A spinlock busy-waits (good only for tiny critical sections on multicore, and bad with priority differences: iOS deprecated `OSSpinLock` for this reason). A mutex parks the thread.
- **Process vs thread?** Processes have separate address spaces; threads share their process's memory.

## async/await — answered in P1
See `flashcards.md` § P1. Practice these extra ones:
- "Rewrite this completion-handler function with async/await, and tell me what changed semantically." (Exactly-once, error propagation, where the result is delivered, cancellation.)
- "Can an async function be called from `viewDidLoad`? How?" (`Task {}`. Store and cancel it if its lifetime should match the VC's.)
- "What's the difference between `Task.sleep` and `Thread.sleep`?" (Suspend vs block; `Task.sleep` throws on cancellation.)

## Isolation & actors — answered in P2
See `flashcards.md` § P2. Practice these cold, then check:
- What's an actor? How is it different from a class with a serial queue? *(P2.03)*
- What's actor reentrancy? Show a bug it causes and two fixes. *(P2.04)*
- What does `@MainActor` guarantee? How does isolation inference work? *(P2.05)*
- What is `Sendable`? Why are actors and `@MainActor` classes Sendable? When is `@unchecked` legitimate? *(P2.06)*
- What does `sending` mean? What's region-based isolation? *(P2.07)*
- `nonisolated` vs `nonisolated(unsafe)` vs `nonisolated(nonsending)` vs `@concurrent`? *(P2.08, P2.11)*
- How do you make a singleton concurrency-safe in Swift 6? *(P2.11)*
- A `@MainActor` class must conform to a protocol with nonisolated requirements. Options? *(P2.12)*
- Can actors deadlock? *(P2.03: not lock-style; logical hangs are possible)*
- "Here's a Swift 6 error. Fix it." → domain, boundary, right fix, and the wrong (escape-hatch) fix. *(P2.16)*

## Structured concurrency — answered in P3
See `flashcards.md` § P3. Practice cold:
- `async let` vs `TaskGroup` vs `Task {}`: when do you use each? *(P3.01–P3.03, P3.11)*
- What happens to an `async let` you never await? *(P3.02)*
- How does cancellation work? Is it preemptive? *(P3.06)*
- Implement `withTimeout`. Why can't a TaskGroup alone time out a non-cooperative task? *(P3.08)*
- Download 100 images, at most 4 at a time, results in original order. *(P3.04)*
- What are task-local values used for? *(P3.10)*

## Classic problems — answered in P4
See `flashcards.md` § P4. Practice cold:
- Ten simultaneous 401s: make sure the token is refreshed exactly once. *(P4.07)*
- Implement a debounced search with cancellation of stale requests. *(P4.06)*
- An image cache gets duplicate downloads under load. Why, and how do you fix it? *(P4.10)*
- Producer–consumer with backpressure; readers–writers; dining philosophers; LeetCode 1114/1115/1117. *(P4.01–P4.03, P4.09)*
- Design an async semaphore / rate limiter / retry policy. *(P4.04, P4.05, P4.11)*

## Debugging — answered in P5
See `flashcards.md` § P5. Practice cold, out loud, as "tell me about a hard bug you fixed":
- Users report "the app hangs sometimes" after an async migration. How do you investigate? *(P5.05, P5.08)*
- A view model is never deallocated after moving to async/await. Likely causes? *(P5.06)*
- How do you write deterministic tests for async code? *(P5.11)*
- Tests pass, production crashes 0.01% of the time. *(P5.02, P5.10)*
- Walk me through this crash report. *(P5.10)*

## Internals — answered in P6
See `flashcards.md` § P6. Practice cold:
- What's an executor? How would you run an actor on a specific DispatchQueue? *(P6.01)*
- What does `#isolation` do? What's an `isolated` parameter for? `@isolated(any)`? *(P2.10, P6.06)*
- What does a context switch cost compared to an actor hop? Why do tasks scale where threads don't? *(P6.03, P6.04)*
- What is happens-before? Relaxed vs acquire/release? *(P6.05)*

## Interview rounds — P7
- GCD & OperationQueue round *(P7.01)* · "explain the output" marathon *(P7.02)*
- Timed katas *(P7.03–P7.05, and `katas.md`)*
- Design a networking layer with auth, retries, dedupe, cancellation, offline *(P7.06)*
- Design an offline-first sync engine *(P7.07)*
- Full mock interview *(P7.08)*
