# P1.07 — Errors in async code, typed throws

<!-- nav:start -->
[← P1.06](./06-async-sequences.md) · [Roadmap](../../ROADMAP.md) · [P1.08 →](./08-async-entry-points.md)
<!-- nav:end -->

<!-- dek: Async errors propagate exactly like sync ones, which is a big win. Three traps are specific to async code, and one of them hides errors completely. -->

⏱ 30 min · Demo `p1.07` · Exercise `P1_07`

## 1. Concept (5 min)

An error thrown three calls deep in async code reaches the nearest `catch`, exactly as it would in sync code:

```swift
func level1() async throws { try await level2() }   // an error thrown in level3 propagates up
do { try await level1() } catch { … }               // the first `catch` above it gets it
```

There is no `Result` juggling, and no wondering whether every path called completion with the error. That is one of the biggest wins of async/await over completion handlers. Three traps remain, and they are specific to async code.

The first is that errors thrown inside an unstructured task vanish:

```swift
Task { try await upload() }    // if this throws: no crash, no log, nothing
```

The error is stored in the `Task<Void, Error>` handle. If nobody ever runs `try await task.value`, it is simply gone. Handle errors inside the task, with `do/catch` followed by an alert or a log line, or keep the handle and await it.

The second is that a catch-all `catch` also catches cancellation. `CancellationError` is an `Error`. When the user leaves the screen and you cancel the task, `try await Task.sleep` and URLSession throw `CancellationError` or `URLError(.cancelled)`. A generic `catch { showErrorAlert() }` then shows *"Network failed!"* for something the user did on purpose. Check `if error is CancellationError` (or `Task.isCancelled`) first.

The third is that `try?` swallows cancellation, so a loop built on it never stops:

```swift
while true { try? await Task.sleep(for: .seconds(1)); poll() }   // cancel() can never stop this
```

Swift 6 adds **typed throws**. `func f() async throws(NetworkError)` tells the compiler and every caller exactly which error can come out. Inside `catch`, `error` is already a `NetworkError`, so a `switch` over it is exhaustive with no casts. Use typed throws for domain errors at module boundaries; plain `throws`, meaning `any Error`, is still the right default for most code.

## 2. Predict (5 min)

1. (b) `Task { throw BoomError() }`, never awaited. After 20 ms: crash, console log, or nothing? ______
2. (c) A download task does `do { try await Task.sleep(5s) } catch { print("Network failed") }`. We cancel it after 20 ms. What prints, and when? ______

## 3. Run (5 min)

```bash
swift run lab p1.07
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
task: throwing
...nothing was printed, logged or crashed. The error sits in the Task.
only `try await task.value` reveals it: BoomError()
catch-all: 'Network failed, showing error alert!' — error was CancellationError
```
1. Nothing at all. In production that looks like "the upload sometimes doesn't happen, and there are no logs".
2. Cancellation interrupted `Task.sleep` right away: it doesn't wait 5 s, because sleep checks for cancellation. But the catch-all reported it as a network failure. The correct version:
   ```swift
   } catch is CancellationError {
       // user left: do nothing
   } catch {
       showAlert(error)
   }
   ```
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_07_Errors.swift`. Implement `loadProfile(id:) async throws(ProfileLoadError)`. Map name errors to domain errors, and treat an avatar failure as non-fatal by falling back to a placeholder image.

```bash
swift test --filter P1_07
```

## 6. Interview cards

- **What happens to an error thrown inside `Task {}`?** It's stored in the task's result. If nobody awaits `task.value`, it's silently lost. Handle errors inside the task, or keep and await the handle.
- **Why is `catch { }` dangerous in async code?** It catches `CancellationError` too, so a deliberate cancellation shows up as a failure. And `try?` around `Task.sleep` in a loop makes the loop impossible to cancel.
- **What are typed throws?** `throws(E)` declares the exact error type. Callers get `E` in `catch` without casting, and switches over it are exhaustive. Good for domain errors; `any Error` stays the default.

## Going deeper
- [SE-0413 Typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md)

---

<!-- nav:start -->
[← P1.06](./06-async-sequences.md) · [Roadmap](../../ROADMAP.md) · [P1.08 →](./08-async-entry-points.md)
<!-- nav:end -->
