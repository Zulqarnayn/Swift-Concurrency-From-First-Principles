# Flashcards

Cover the answer. Say yours **out loud**, in full sentences, as if to an interviewer. Mark ✗ on any you fumble and repeat those tomorrow.
Each new lesson adds its cards here.

---

## P0 — Foundations

**P0.01 · Concurrency vs parallelism?**
Concurrency means multiple tasks in progress over the same period (structure; possible on one core by interleaving). Parallelism means multiple tasks executing at the same instant on multiple cores. Concurrency is how you structure the program; parallelism is one way to run it.

**P0.01 · Why not one thread per task?**
Threads cost memory (stacks), creation time and context switches. More runnable threads than cores adds overhead, not throughput. That's why thread pools exist, and why Swift caps its cooperative pool at the core count.

**P0.01 · Amdahl's law?**
Max speedup = `1 / ((1−p) + p/n)`. The serial fraction caps it: 95% parallel tops out at 20× no matter how many cores.

**P0.02 · Define a data race.** ⭐
Two or more threads access the same memory concurrently, at least one access is a write, and there's no synchronization (no happens-before). In Swift it's undefined behavior: corrupted heaps and crashes, not just a wrong number.

**P0.02 · Data race vs race condition?** ⭐
A data race is a memory-level conflict; a race condition is a logic bug that depends on timing. Each can exist without the other. Swift 6 rules out data races at compile time, not race conditions.

**P0.02 · How do you find races?**
Thread Sanitizer at runtime (catches races even on runs that "worked"), and Swift 6 strict concurrency checking at compile time.

**P0.03 · What's CAS and how do you use it?**
Compare-and-swap: "set to `desired` only if the value is still `expected`; tell me if it worked." Use it in a loop: read, compute, CAS, and on failure retry with the fresh value. It's the basis of lock-free algorithms.

**P0.03 · Are two atomic operations in a row atomic?**
No. Another thread can run between them. Check-then-act needs one CAS or one lock scope.

**P0.03 · Why do memory ordering and visibility matter?**
CPUs (especially ARM) and compilers reorder memory operations. Without acquire/release or a lock, another thread can see your writes out of order, e.g. the flag before the data. Locks, queues and actors give you happens-before automatically.

**P0.04 · Is code with no data races thread-safe?** ⭐
Not necessarily. Check-then-act across separate critical sections gives you overdrafts and lost updates, and Swift 6 still compiles it. The critical section must cover the whole invariant-preserving operation.

**P0.04 · Which lock in modern Swift?**
`Mutex` (iOS 18+) or `OSAllocatedUnfairLock` (iOS 16+). Both own the state they protect. Never put a raw `os_unfair_lock` in a Swift `var`. Never hold a lock across slow work or callbacks.

**P0.05 · The four deadlock conditions?** ⭐
Mutual exclusion, hold-and-wait, no preemption, circular wait. Break any one. A global lock order, which breaks circular wait, is the usual fix.

**P0.05 · `DispatchQueue.main.sync {}` from the main thread?**
Deadlock: the block waits for main, and main waits for the block. libdispatch detects it and crashes. Same for any serial queue syncing onto itself.

**P0.05 · Deadlock vs livelock vs starvation?**
Deadlock: everyone waits forever. Livelock: everyone stays busy (retry/back off) and no one progresses. Starvation: the system progresses but one party never gets the resource.

**P0.06 · Priority inversion, and how Apple platforms handle it?** ⭐
High priority waits on low priority while medium work starves the low one. Primitives with a known owner (unfair lock, mutex, serial queues, actors) donate priority to the owner. Semaphores and groups have no owner, so they can't, and they invert.

**P0.06 · GCD thread explosion?** ⭐
A blocked block makes GCD spawn another thread, up to ~64. Result: memory and context-switch overhead, and possible deadlock at the cap. Avoid blocking, limit width, or use Swift concurrency's fixed-size pool.

**P0.07 · Blocking vs suspending?**
Blocking parks the thread until the event arrives, so the thread is wasted. Suspending saves the rest of the work as a continuation and frees the thread. Waiting on I/O never needs a thread.

**P0.07 · What's wrong with completion handlers?**
Nothing guarantees "called exactly once" or "on the right queue". Errors and cancellation are convention only, nesting gets deep, and `self` capture causes cycles. `async/await` makes these structural and compiler-checked.

---

## P1 — async/await

**P1.01 · What does `await` mean?** ⭐
It marks a potential suspension point. The function may pause there, release its thread, and resume later, possibly on another thread. Other code may run in between.

**P1.01 · Does `async` run code in the background?** ⭐
No. It only allows suspension. Where code runs depends on isolation: `@MainActor`, `@concurrent`, or the caller's context. CPU work in an async function still occupies its thread.

**P1.02 · How can an async function resume on a different thread?**
The compiler splits it at each `await` into partial functions. Values that live across suspensions sit in a heap-allocated async frame owned by the task, not on a thread stack, so any thread can run the next partial.

**P1.02 · Why doesn't `await` on the main actor freeze the UI?**
Suspending ends the current job and frees the main thread. The continuation is enqueued later as a new job, and events and layout run in between.

**P1.03 · What's the cooperative pool, and why is it fixed-size?** ⭐
The global concurrent executor uses about one thread per core and never overcommits: no thread explosion, little context switching. The contract is that tasks never block; they run or they suspend.

**P1.03 · Why not use a semaphore to wait for async work?** ⭐
It parks a pool thread. If the awaited work needs a pool thread and all of them are parked, you have a deadlock, and the pool won't add threads. Semaphores also don't donate priority.

**P1.03 · How do you find blocking in async code?**
`LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` (pool width 1: blocking deadlocks every time), the Instruments Swift Concurrency template, hang detection, and reviewing for sync wrappers around async APIs.

**P1.04 · What does `Task {}` inherit? `Task.detached`?**
`Task {}` inherits actor isolation, priority and task-locals. `Task.detached` inherits none of them.

**P1.04 · Does dropping a Task handle cancel it?**
No. Unstructured tasks run until they finish unless someone calls `cancel()` and the code checks for cancellation.

**P1.04 · When is `Task {}` appropriate?**
At the sync → async boundary: UI events, lifecycle, delegates. Inside async code, use `await` or structured concurrency instead.

**P1.05 · Wrap a completion-handler API in async.** ⭐
`try await withCheckedThrowingContinuation { c in api { result in c.resume(with: result) } }`. The task suspends, and the callback resumes it on the task's own executor.

**P1.05 · Continuation resumed zero times? Twice?** ⭐
Zero: the task hangs forever (checked continuations log "leaked its continuation"). Twice: a fatal error crash. Every path must resume exactly once.

**P1.06 · Does AsyncStream have backpressure?**
No. `yield` never waits. Choose a buffering policy; an unbounded buffer with a slow consumer grows forever.

**P1.06 · Two consumers on one AsyncStream?**
Values get split between them (unicast), so each sees only part. Make one stream per subscriber.

**P1.06 · When does `onTermination` fire?**
On `finish()`, when the consuming task is cancelled, or when the stream is deallocated. Not on a `break` while the stream is still referenced.

**P1.07 · An error thrown inside `Task {}`?**
It's stored in the task's result. If nobody awaits `value`, it's silently lost.

**P1.07 · Why is a catch-all `catch` risky in async code?**
It also catches `CancellationError` and reports a deliberate cancel as a failure. `try?` around `Task.sleep` in a loop makes the loop uncancellable.

**P1.08 · `.task {}` vs `onAppear { Task {} }`?** ⭐
`.task` is cancelled when the view disappears and restarts when `id` changes. `onAppear + Task` outlives the view unless you store and cancel the handle.

**P1.08 · Process sync events in order with async handlers?** ⭐
One long-lived consumer task reading an AsyncStream (an async serial queue). One Task per event runs them concurrently and loses order.

**P1.10 · Does `await` always suspend?** ⭐
No. It marks a *possible* suspension. Calling an async function on the actor you're already on doesn't hop and may not suspend at all.

---

## P2 — Isolation

**P2.01 · "I made it async but the UI still freezes. Why?"** ⭐
A `@MainActor` async function runs all its synchronous lines on main; only the waiting at `await` frees the thread. Move CPU work into a `@concurrent` function that returns the result.

**P2.01 · Where does a `nonisolated async` func run in Swift 6.2 with approachable concurrency?** ⭐
On the caller's actor (`nonisolated(nonsending)`, SE-0461). `@concurrent` runs it on the global concurrent executor. Before 6.2, `nonisolated async` always ran on the global executor.

**P2.01 · What does MainActor-by-default change?**
Every declaration in the module is implicitly `@MainActor`, including free functions and globals. Pure helpers need `nonisolated` to be callable from background code without hopping.

**P2.01 · Why avoid `Task.detached` and `MainActor.run` here?**
Detached is unstructured (no awaitable completion, no cancellation, priority or task-local inheritance). `MainActor.run` reaches back into the main actor from code declared elsewhere. Prefer `@MainActor` callers plus helpers that return values: isolation in declarations, checked at compile time.

**P2.02 · What is isolation?** ⭐
A compile-time guarantee about which code may touch which mutable state. Every declaration is nonisolated, isolated to an actor instance, or isolated to a global actor. Same domain means synchronous access; crossing means `await`, and only Sendable values (or `sending` values) cross.

**P2.02 · Is an actor a thread?**
No. It's an isolation domain with a serial executor. Its jobs run one at a time on whatever pool thread is free (p2.03 ran on 4 threads, never 2 at once). Only `@MainActor` is tied to a thread.

**P2.03 · Actor vs class + serial queue?** ⭐
Same mutual exclusion, but enforced by the compiler. Callers suspend instead of blocking, and self-calls and cross-calls can't deadlock. The costs: every external call is async, and the actor is reentrant at awaits.

**P2.03 · When NOT to use an actor?**
No mutable state (stateless actor), callers need sync access (use Mutex), or it's UI state (use `@MainActor`).

**P2.04 · What is actor reentrancy?** ⭐
While an actor method is suspended at `await`, the actor runs other calls, including the same method. State checked before the await may differ after it. Mutual exclusion holds only between suspension points.

**P2.04 · How do you fix reentrancy bugs?** ⭐
Check and mutate in one synchronous stretch, with no `await` between. Re-validate after every `await`. For once-only async work, store the in-flight `Task` before awaiting so others join it (caches, token refresh).

**P2.05 · How is isolation inferred?**
From type annotations, superclasses, protocols that require it (SwiftUI `View`), the enclosing context for non-`@Sendable` closures and `Task {}`, and module default isolation. Not from `@Sendable` closures, `Task.detached`, property wrappers (Swift 6), or call sites.

**P2.05 · `MainActor.assumeIsolated`?**
In sync code that you know runs on main but the compiler doesn't (legacy main-queue callbacks), it lets you touch main-actor state synchronously. It traps if wrong, and it's unavailable in async code.

**P2.06 · What makes a type Sendable?** ⭐
Copied (struct/enum of Sendable members), immutable (final class of Sendable lets), internally synchronized (actor), or isolated (global-actor class). `@unchecked` disables the check: in p2.06 a counter compiled cleanly and lost half its updates.

**P2.07 · Sendable vs `sending`?**
Sendable is a property of a *type*: always safe to share. `sending` is about a *value at one point*: it's handed over and never used again by the sender. Region-based isolation proves it.

**P2.07 · Why can't a `@MainActor` class send `self.current` to an actor?**
It stays reachable from the main actor, so two domains would touch one object. Send a fresh copy.

**P2.08 · Where does a nonisolated async func run in Swift 6.2?** ⭐
With NonisolatedNonsendingByDefault (the Xcode 26 default), on the caller's actor (SE-0461). Before, always on the global executor. `@concurrent` asks for that explicitly, and you use it for CPU-heavy work. The same source runs on different threads depending on a build setting.

**P2.09 · What does MainActor-by-default break?**
Background code using module types: free helpers and model conformances (Codable) are `@MainActor`. Fix: `nonisolated` on pure helpers and data types. Good for app targets; usually not for libraries.

**P2.10 · Does `Task {}` inherit isolation?**
From a global actor, yes. Inside an actor instance, only if the closure captures `self`. Detached never does. Autoclosures don't see instance isolation either.

**P2.10 · What's an `isolated` parameter for?**
It runs a function ON the actor passed in, with sync access and no interleaving. It makes multi-step operations atomic without editing the actor.

**P2.11 · Make a singleton concurrency-safe.**
`static let shared` of a Sendable type: an actor, a `@MainActor` class, or a final class with a Mutex (keeps the API sync). Global/static lets are initialized once, thread-safely. `lazy var` is not (initializer ran 8× in p2.11).

**P2.12 · A `@MainActor` class must conform to Equatable/Hashable.**
If the witnesses only use immutable Sendable data (an id), make them `nonisolated` and write `nonisolated Hashable` when conformances are inferred isolated. Otherwise use an isolated conformance (`@MainActor Equatable`), usable only on main. `@preconcurrency` conformance means runtime checks that trap.

**P2.13 · Receiving legacy callbacks on unknown threads?** ⭐
Make the callback explicitly `@Sendable`, touch only thread-safe values, and hop via AsyncStream (ordered). A closure inferred `@MainActor` and *stored* by Swift 5 code can run off-main with **no** runtime check (p2.13b). Passed as an argument, it traps (p2.13c).

**P2.13 · How would you migrate a big app to Swift 6?**
Outside-in: complete checking as warnings, leaves first, Sendable value types, `@MainActor` UI, `@preconcurrency import` for deps you don't own, Swift 6 mode per module. No `@unchecked` shortcuts.

**P2.14 · Load and decode from disk without blocking UI?**
A `@MainActor` model, `@concurrent` static helpers for I/O and decoding returning Sendable values, and the assignment on main. No custom actor needed (Massicotte, Reading from Storage).

**P2.15 · Non-Sendable-first design?**
Plain classes, no isolation, no Sendable, owned by one isolated owner. With nonsending, their async methods run in the owner's domain, so nothing crosses a boundary. Reach for actors only for state that's truly shared.

**P2.16 · Main actor calls a plain async func vs a `@concurrent` func, with a queued Task: who runs first?** ⭐
Plain (nonsending) stays on main, so main isn't released and the Task runs later (`1 plain 2 task`). `@concurrent` hops off and releases main, so the Task runs during it (`1 task 2`).

---

## P3 — Structured concurrency

**P3.01 · What is structured concurrency?** ⭐
Child tasks are scoped to the code that created them and can't outlive it. Tasks form a tree: parents wait for children, cancellation flows down, errors flow up, priority and task-locals are inherited. `Task {}` is unstructured: a new root that outlives its creator.

**P3.02 · What happens to an `async let` you never await?** ⭐
At scope exit it's cancelled AND awaited. It can't leak, but a child that ignores cancellation delays the exit (p3.02: cancelled, still waited 319ms).

**P3.02 · `try await (a, b, c)`: c fails first. When do you find out?**
Only when c is awaited, after a and b. Errors are observed in await order. Use a ThrowingTaskGroup to fail on the first error in completion order.

**P3.03 · TaskGroup result order? How do children share results?** ⭐
Completion order. Children return Sendable values and the parent collects them; the compiler rejects children mutating a captured var. Carry an index if you need input order.

**P3.03 · A child throws in a ThrowingTaskGroup. What happens?** ⭐
`next()` / `for try await` rethrow it. Leaving the body cancels the remaining children and awaits them. **`waitForAll()` does NOT cancel siblings**: it waits for all of them, then rethrows.

**P3.04 · N downloads, at most K at once, results in order?** ⭐
A sliding-window TaskGroup: start K; on each `next()`, start one more; children return `(index, value)` into a pre-sized array. Not a DispatchSemaphore (it blocks the pool).

**P3.05 · TaskGroup vs DiscardingTaskGroup?**
TaskGroup keeps results until you call `next()`, so it grows in long-running loops. Discarding drops Void results immediately: servers and event loops. A throwing discarding group cancels everything on the first error.

**P3.06 · What does `task.cancel()` do?** ⭐
Sets the cancellation flag on the task and its children and runs cancellation handlers. Nothing stops by force: code checks `isCancelled` / `checkCancellation()` or uses APIs that throw (Task.sleep, URLSession). A CPU loop that never checks runs to the end.

**P3.06 · Make a legacy callback API cancellable.**
`withTaskCancellationHandler { continuation… } onCancel: { legacy.cancel() }`. onCancel runs immediately, concurrently, and BEFORE the operation if the task is already cancelled, so handle cancel-before-start and resume exactly once.

**P3.07 · Does cancelling a parent cancel a `Task {}` created inside it?** ⭐
No. Only structured children. A `Task {}` is a root; only its handle's owner cancels it. `.task` cancels on disappear; `onAppear { Task {} }` leaks past the view.

**P3.07 · "Latest search wins". How?**
Store `currentTask`; cancel it on each new query; re-check cancellation right before applying results (a superseded request may finish just as it's cancelled; with `.task(id:)` the new task starts before the old one reacts).

**P3.08 · Implement withTimeout. What's its limit?** ⭐
A ThrowingTaskGroup racing the operation against a sleep that throws TimeoutError; `next()` takes the first; `cancelAll()` in a defer. Limit: the group waits for all children, so a non-cooperative operation delays the return (p3.08: a 100ms timeout returned at 603ms).

**P3.09 · Priority inheritance and escalation?**
Children and `Task {}` inherit; detached doesn't. A higher-priority task awaiting a lower one (or an actor) escalates it, which avoids inversion automatically. Don't set explicit priorities without a reason.

**P3.09 · `Task.yield()`?**
Suspends and requeues, so other jobs on the same executor run. Use it for long loops that must stay on an actor (main: 0 → 51 interleavings in p3.09). If the work doesn't need the actor, move it off with `@concurrent`.

**P3.10 · Task-locals?**
Values bound with `$x.withValue(v) {…}`, readable in that scope and inherited by children and `Task {}`, not by detached. Use them for request ids and tracing. Thread-locals don't work: tasks hop threads.

**P3.11 · Do `Task {}`s start in order? `Task.immediate`?**
On the same actor they start FIFO but interleave at awaits; from nonisolated code there's no guarantee (6 distinct orders in 20 runs). `Task.immediate` runs synchronously on the caller's actor until its first suspension, for work that must begin before a sync handler returns.

---

## P4 — Classic problems

**P4.01 · Producer–consumer: what must a solution guarantee?**
A bounded buffer: consumers wait when it's empty, producers wait when it's full (backpressure), and access is exclusive. Threads: two counting semaphores (free and filled slots) plus a mutex. Async: an actor plus parked sender and receiver continuations. AsyncStream has NO backpressure (p4.01: a 498-element backlog).

**P4.02 · Thread-safe dictionary with parallel reads?**
A concurrent queue: `sync` reads, `async(flags: .barrier)` writes. The barrier waits for in-flight reads, runs alone, and later blocks queue behind it (read-your-writes holds). It's ignored on global queues. In Swift concurrency: usually an actor or copy-on-write snapshots.

**P4.03 · Can actors deadlock?** ⭐
Not lock-style: awaiting releases the actor. But async locks and semaphores built from continuations restore all four Coffman conditions. You get tasks suspended forever, no blocked threads, no crash, and a feature that never finishes. Fix with resource ordering; detect with timeouts.

**P4.04 · Design an async semaphore.** ⭐
An actor with a permit count and a FIFO continuation queue. `signal` hands the permit DIRECTLY to the oldest waiter, otherwise it increments. Cancellation: `withTaskCancellationHandler`, hop to the actor, remove the waiter, throw, consume no permit. Never `DispatchSemaphore` in tasks (p4.04c deadlocked the pool).

**P4.05 · Token bucket vs sliding window vs leaky bucket?**
Token bucket: bursts up to capacity, then a steady refill. Sliding window: at most N in any T. Leaky bucket: a constant drain, no bursts. Implementation: lazy refill from elapsed time; sleep until the next token; WHILE-loop re-check (reentrancy).

**P4.06 · Debounce vs throttle; debounced search in Swift?** ⭐
Debounce acts after events stop for T; throttle acts at most once per T. Search: cancel the pending Task, start one that sleeps → searches → re-checks cancellation → shows results. Without it you get a stale-result race (the iOS lab showed results for "s" while the user typed "swift").

**P4.07 · 20 requests get 401 at once. Refresh safely?** ⭐⭐
An auth actor. Remember the token each request used. If the token has changed since, just retry. If a refresh Task is in flight, await it. Otherwise create one, publish it before awaiting, clear it in `defer`. Retry once. Errors fan out to every waiter and aren't cached. Naive version: 10 refreshes, 2/10 succeeded (token rotation).

**P4.08 · Latch vs barrier?**
A latch is a one-shot gate after N countdowns (DispatchGroup). A barrier is a reusable rendezvous of N participants (concurrentPerform per phase). Only needed for independent participants. The barrier bug: reset in the same step as the release, or the next round's early arrivals get released.

**P4.09 · FooBar alternately: threads vs async?**
Threads: two semaphores (foo = 1, bar = 0), each waits on its own and signals the other. Async: an actor with a turn flag and a parked continuation. Works because the actor is reentrant while one side is parked.

**P4.10 · Design an image loader.** ⭐
An actor with in-flight Task dedupe, a download limiter (hits bypass it), and an LRU or NSCache memory cache. Decode and downsample off main. Don't cache failures. Discuss a disk cache, prefetch priority, and cancellation with ref-counting. Naive: 54 downloads for 20 images; pipeline: 20 downloads, peak 4.

**P4.11 · A good retry policy?**
Bounded attempts, exponential backoff plus jitter (thundering herd), retry only transient errors, NEVER CancellationError, cancellable waits (`try await Task.sleep`, not `try?`), idempotency, Retry-After. `try?` backoff turned cancelled retries into zero-delay hammering (p4.11).

---

## P5 — Bug Zoo

**P5.01 · How do you debug a concurrency bug?** ⭐
Reproduce under pressure → make it deterministic (scripted fakes, manual clocks) → draw the timeline with every `await` → fix the design, not the timing → prove it (the deterministic test plus stress and TSan). Sleeps, retries and timeouts change probability, not possibility.

**P5.02 · Tests pass, production crashes rarely. How do you find the race?** ⭐
Run under Thread Sanitizer, repeatedly, with pressure. Read both stacks and the "mutexes held" field. Reads need the lock too (torn values, crashes). `@unchecked Sendable` is where TSan earns its keep.

**P5.02 · Which tool for which symptom?**
Races: TSan. UI off main: Main Thread Checker. Hangs: Time Profiler (Hangs track) or Animation Hitches. Stuck or too many tasks: the Swift Concurrency template and LLDB `language swift task backtrace`. Leaks: Memory Graph, Leaks. Blocking in async code: `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`.

**P5.03 · Duplicate pages / stale posts after refresh?** ⭐
Duplicates: concurrent "load more" calls read the same `nextPage` before any finished, so single-flight the load. Stale: a pre-refresh response landed after the reset, so use a generation token captured at request time and checked on arrival, plus cancellation. Check every async result against the world at ARRIVAL.

**P5.04 · Spinner forever, "leaked its continuation"?**
Check every resume path: the receiver is alive (WEAK delegates!), every error callback is implemented, cancellation is forwarded, and there's no silent "never calls back" path. Fix: a strongly held adapter, a lock-protected take-once continuation, and `withTaskCancellationHandler` that also stops the work.

**P5.05 · The whole app's async work crawls during feature X?** ⭐
Pool starvation: something blocks pool threads (semaphore bridges, sync I/O, usleep), often hidden in sync helpers. Await async APIs; move unavoidable blocking I/O to a GCD queue behind a continuation. A timeout "fix" hid the deadlock and turned it into data loss (0/32 uploaded).

**P5.06 · View model never deinits after adopting async?**
`Task { for await … { self… } }` retains `self` for an endless loop → a cycle. `[weak self]` + `guard let self` at the TOP doesn't help: it's strong for the whole loop. Unwrap per iteration, get streams outside the task, cancel in `isolated deinit`, or use `.task {}`.

**P5.07 · Work continues after leaving + a phantom error alert?**
`try?` on sleeps (instant retries), no `withTaskCancellationHandler` for legacy work, and catch-alls that report CancellationError. Handle cancellation separately: stop quietly.

**P5.08 · "It's async, so it can't freeze the UI"?** ⭐
False. Sync calls from `@MainActor` and plain (nonsending) async funcs called from main run ON main. Move CPU work to `@concurrent`. Find it with Time Profiler's Hangs track (invert the call tree, main thread) and Organizer hang reports.

**P5.09 · Second screen misses events; loops never end?**
AsyncStream is unicast (split values): one stream per subscriber. `for await` ends only when the stream finishes or the task is cancelled: `finish()` on shutdown. Remove dead subscribers in `onTermination`.

**P5.10 · Read a concurrency crash report.**
`EXC_BREAKPOINT/SIGTRAP` is a deliberate trap: read the frames above it. `_swift_task_checkIsolatedSwift` means an isolation check failed: the next frame is `assumeIsolated`, `_checkExpectedExecutor` in a protocol witness (`@preconcurrency`), or a closure entry (SE-0423). `EXC_BAD_ACCESS` in `swift_release` or malloc ("double free") usually means memory corruption from a data race. Read "BUG IN CLIENT OF …" first.

**P5.11 · Make async tests deterministic.**
Inject clocks and slow dependencies; advance time from the test; wait for events or conditions, not durations; let resumed work run (yield or a serial executor); stress the real thing separately. Sleep-based tests are flaky AND miss the rare interleavings.

---

## P6 — Internals

**P6.01 · What's an executor? How do you pin an actor to a queue?**
The thing that runs a task's jobs: the global concurrent executor (pool), the main actor's executor (main thread), default actor executors, or custom ones. `nonisolated var unownedExecutor { queue.asUnownedSerialExecutor() }` with a DispatchSerialQueue. GCD code already on that queue can then use `actor.assumeIsolated` synchronously.

**P6.02 · Task executor preference?**
`withTaskExecutorPreference(e) { … }` runs nonisolated async code (including `@concurrent`) and child tasks on `e`. Actor-isolated code keeps its own executor: isolation beats preference. Rarely needed: thread-affine libraries, keeping heavy work off the shared pool.

**P6.03 · Why do tasks scale where threads don't?** ⭐
A suspended task is a heap record plus async frames (about 1.5–2.5 KB measured), with no stack and no kernel thread. A blocked thread costs about 16 KB resident plus a 512 KB stack reservation, a kernel object and context switches. Task create+await ≈ 1 µs.

**P6.04 · How expensive is an actor hop?**
An idle default actor from the pool: often a same-thread switch (~0.1 µs). A MainActor round trip: a real thread switch (~7 µs, ~50×) that also competes with UI work. Batch main-actor updates; use isolated params or actor methods for multi-step work.

**P6.05 · What is happens-before?** ⭐
Program order plus synchronization edges (unlock→lock, release→acquire, serial queue and actor job order, task creation, continuation resume, awaiting a child). Unordered conflicting accesses are a data race. Relaxed atomics order nothing else. Time is not synchronization. Program against guarantees, not observations.

**P6.06 · Why does `Task { @MainActor in }` keep order but `Task { await main() }` doesn't?**
Task.init takes `@isolated(any)` closures: an isolated closure's task is enqueued on that actor at creation, so FIFO. A nonisolated closure starts on the pool and hops later, so siblings race (20/20 vs 12/20 measured). `#isolation` is the static counterpart.

**P6.07 · Name the proposal: reentrant actors, regions, nonsending.**
SE-0306 (actors: reentrancy chosen to avoid deadlocks), SE-0414 (region-based isolation: safe transfer of non-Sendable values), SE-0461 (nonisolated async runs on the caller's actor; `@concurrent`).

**P6.08 · Distributed actors?**
References may be remote, through an ActorSystem. Only `distributed` members are callable, always `try await`, arguments must be serializable (Codable), no stored-property access from outside, `resolve(id:using:)`.

---

## P7 — Interview mastery

**P7.01 · OperationQueue vs GCD; cancelling pipelines?**
Dependencies (even across queues), `maxConcurrentOperationCount`, cancellation state, KVO. Cancelling one op doesn't cancel its dependents (it still "finishes"), so cancel the chain. `waitUntilAllOperationsAreFinished` blocks.

**P7.03 · Fetch N with max K and a deadline?** ⭐
A TaskGroup with a deadline child plus a sliding window of `(id, Result)` children. On deadline: `cancelAll`, mark unfinished as timed out. When all finish: cancel the timer. Requires cooperative fetches.

**P7.04 · Concurrent work, in-order delivery?**
Sliding window plus a reorder buffer; flush the contiguous prefix after each arrival. Memory bounded by the window; mention head-of-line blocking.

**P7.05 · Current value + updates API?**
One stream per subscriber, current value on subscribe, `bufferingNewest(1)` (state, not events), a lock-protected subscriber map, `onTermination` cleanup, `finish()`; never yield while holding the lock.
