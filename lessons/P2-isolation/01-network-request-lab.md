# P2.01 — Lab: a network request, step by step (iOS app) ⭐

<!-- nav:start -->
[← P1.10](../P1-async-await/10-review.md) · [Roadmap](../../ROADMAP.md) · [P2.02 →](./02-isolation-first-principles.md)
<!-- nav:end -->

⏱ 30 min (could be split over 2 days) · App `ConcurrencyLabApp` · Diagnostics `P2_01_default_isolation.swift`
Based on Matt Massicotte, [Concurrency Step-by-Step: A Network Request](https://www.massicotte.org/step-by-step-network-request/). **Read that article first (10 min).** This lab lets you *watch* each of its steps run.

## 0. Setup (once)

```bash
cd ConcurrencyLabApp
xcodegen generate
open ConcurrencyLabApp.xcodeproj      # run on an iPhone simulator
```
The app target uses **the same build settings as a brand-new Xcode 26 app**:

| Setting | Value | Meaning |
|---|---|---|
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | **Everything** you write (types, functions, globals) is `@MainActor` unless you say otherwise |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | A plain `nonisolated async` func runs on the *caller's* actor. To leave it you write `@concurrent`. |

Every screen does the same job (download a robot PNG, decode it, show it) with a different design. Each screen shows:
- a **trace console**: which thread ran each line (`MAIN` in black, background threads in orange)
- a **stall meter**: the longest the main thread went without responding
- a **jank square**, rotated by the main thread every frame. If it stutters, your user saw a freeze.

`decodeImage` burns 300 ms of CPU on purpose (think: resizing, filters, ML) so you can **see** where it runs.

## 1. Concept (5 min)

Massicotte's central sentence:

> **"Isolation applies to an entire function. Not some parts — the whole thing."**

So *where code runs* is decided by the **declaration** of the function you're in, not by the line of code, and not by the caller's wishes:

- `@MainActor` function (the default in this app) → every line runs on main, including your CPU-heavy decode.
- `await` inside it suspends and frees main while waiting, but when the function resumes, it resumes **on main**.
- To run CPU work off main, put it in a function **declared** to run elsewhere: `@concurrent` (Swift 6.2+), and **return the result** rather than mutating main-actor state from there.

## 2. Predict (10 min)

For each step, predict (a) which thread runs `decodeImage`, (b) roughly the worst stall, (c) for Alt A, whether the function returns before or after the image is assigned.

| Step | Code (`Sources/P2_01_NetworkRequest/RobotLab.swift`) | decode thread | worst stall |
|---|---|---|---|
| 1 GCD | `dataTask { … decode … main.async { assign } }` | | |
| 2 async on main | `.task { let data = await fetch(); cgImage = decodeImage(data) }` | | |
| 3 `@concurrent` | `cgImage = await Self.fetchAndDecode(name)` | | |
| Alt A | `Task.detached { decode; Task { @MainActor in assign } }` | | |
| Alt B | `@concurrent func … { decode; await MainActor.run { assign } }` | | |

Then open `ConcurrencyLab/Diagnostics/P2_01_default_isolation.swift`: a model class compiled with the same settings. Predict: error, warning, or OK for (i) mutating `cgImage` inside a `dataTask` closure, (ii) mutating it inside a `@concurrent` function, (iii) calling the free function `decode(_:)` from each.

## 3. Run (5 min)

Run every step in the simulator (tap "Load a new robot" a few times). Or from the terminal:
```bash
xcrun simctl launch --console-pty booted dev.learning.concurrency.lab -autorun asyncOnMain
# steps: gcd | asyncOnMain | concurrent | detached | mainActorRun
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_01_default_isolation.swift     # from repo root
```

## 4. Explain (10 min)

<details><summary>Spoiler: open after running</summary>

Real traces (the robohash server was down during this run with HTTP 525; the app's fallback generated an image instead. URLSession does **not** throw for HTTP errors, which is why `validated(...)` checks the status code):

**Step 1 — GCD.** Decode on a background thread, assign on main. Stall 14 ms. ✅ Correct, the old way.
```
MAIN | GCD: dataTask.resume()
MAIN | GCD: loadWithGCD() returned
T1   | GCD: completion handler
T1   |     decodeImage: start (CPU-bound, ~300ms)
MAIN | GCD: main.async → assign cgImage
■ worst main-thread stall: 14ms
```

**Step 2 — async/await on the main actor.** ❌ **Stall 303 ms.** The jank square froze.
```
MAIN | step 2: start
MAIN |     network problem (…) → generated image      ← even fetchRobotData's code ran on MAIN
MAIN | step 2: data arrived
MAIN |     decodeImage: start (CPU-bound, ~300ms)      ← the whole function is @MainActor
MAIN | step 2: assigned cgImage
■ worst main-thread stall: 303ms
```
The `await` on the network did **not** block main (stall stayed low while waiting). But after resuming we were on main again, and `decodeImage`, a sync call, ran right there. "I used async/await, so it's in the background" is the most common misconception in Swift concurrency. Also notice that `fetchRobotData` is a plain `nonisolated async` func, so under approachable concurrency it **ran on the caller's actor**, main.

**Step 3 — `@concurrent` helper that returns a value.** ✅ Stall 4 ms.
```
MAIN | step 3: start
T1   |   @concurrent fetchAndDecode: start
T1   |     decodeImage: start (CPU-bound, ~300ms)
MAIN | step 3: back on the caller's actor → assign
■ worst main-thread stall: 4ms
```
This is Massicotte's recommended shape. The background function **returns** data; the caller, still `@MainActor` by declaration, assigns it. No hops written by hand, no `DispatchQueue.main`, and the compiler guarantees `cgImage` is only touched on main.

**Alt A — `Task.detached` + nested `Task { @MainActor }`.** Works, but:
```
MAIN | alt A: creating Task.detached
MAIN | alt A: function returned — the work is NOT done     ← caller can't await completion
T2   |   detached: done (UI not updated yet!)
MAIN |   nested Task @MainActor: assign
```
Unstructured twice over. The function returns immediately, nothing can await "loaded", cancellation of the view's `.task` doesn't reach the detached task, and priority and task-locals are dropped. (On another run "done" and "assign" came out in the opposite order. Two independent tasks have no ordering guarantee.)

**Alt B — `@concurrent` + `await MainActor.run { }`.** Works, stall 2 ms. Massicotte's objection is about **design**: the function says "I'm not on the main actor" and then reaches back into it. Better: make the *caller* `@MainActor` and have the helper return the value (Step 3), so isolation lives in declarations the compiler can check.

**Diagnostics** (with MainActor-by-default):
```
warning: main actor-isolated property 'cgImage' can not be mutated from a Sendable closure
warning: call to main actor-isolated global function 'decode' in a synchronous nonisolated context
error:   main actor-isolated property 'cgImage' can not be mutated from a nonisolated context
error:   main actor-isolated global function 'decode' cannot be called from outside of the actor
```
- GCD/URLSession closures give **warnings** (Objective-C APIs, `@preconcurrency`, as in P0.02). `@concurrent` gives **errors**.
- The trap specific to this mode: **a free helper function is `@MainActor` too.** Your "background" helper would run on main, or refuse to compile from background code. That's why `RobotImaging.swift` marks helpers `nonisolated`. Delete one `nonisolated` keyword in the app and read the errors.
</details>

## 5. Exercise (optional, 10 min)

In the app, change `fetchAndDecode` (Step 3):
1. Remove `@concurrent`. Predict, then check the trace and stall. (It's now a `static` method of a `@MainActor` View, so it's MainActor.)
2. Make it `nonisolated` (but not `@concurrent`). Predict: where does it run now? Why? (Hint: approachable concurrency, the caller's actor.)
3. Restore `@concurrent`.

<details><summary>Answers</summary>

1. Decode on MAIN, ~300 ms stall.
2. **Still on MAIN.** `nonisolated async` = `nonisolated(nonsending)` under approachable concurrency, so it runs on the caller's actor, and the caller is the main actor. Only `@concurrent` *leaves* the caller's actor. (Before Swift 6.2, `nonisolated async` always ran on the global pool. Interviewers may ask about the change: SE-0461.)
3. Back to T-threads, ~4 ms.
</details>

## 6. Interview cards

- **"I made the function async, why does the UI still freeze?"** `async` doesn't mean background. A `@MainActor` async function runs every synchronous line on main; only the waiting at `await` frees the thread. Move CPU-bound work into a `@concurrent` (or otherwise non-main-isolated) function that returns the result.
- **Where does a `nonisolated async` function run in Swift 6.2+ with approachable concurrency?** On the caller's actor (`nonisolated(nonsending)`, SE-0461). `@concurrent` explicitly runs it on the global concurrent executor.
- **What does MainActor-by-default change? (SE-0466)** Every declaration in the module is implicitly `@MainActor`, including free functions and globals. Pure helpers must be marked `nonisolated` to be callable from background code without hopping.
- **Why are `Task.detached` and `MainActor.run` discouraged for this?** Detached is unstructured: no awaitable completion, no cancellation, priority or task-local inheritance. `MainActor.run` reaches back into the main actor from code declared elsewhere; prefer `@MainActor` callers and helpers that return values, so isolation is visible in declarations and checked at compile time.

## Going deeper
- Massicotte: [Reading from Storage](https://massicotte.org/step-by-step-reading-from-storage/) (next in the series) · [Default isolation with Swift 6.2](https://massicotte.org/default-isolation-swift-6_2/) · [MainActor by Default](https://massicotte.org/blog/mainactor-by-default/)
- [SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md) (nonsending by default, `@concurrent`) · [SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md) (default isolation)

---

<!-- nav:start -->
[← P1.10](../P1-async-await/10-review.md) · [Roadmap](../../ROADMAP.md) · [P2.02 →](./02-isolation-first-principles.md)
<!-- nav:end -->
