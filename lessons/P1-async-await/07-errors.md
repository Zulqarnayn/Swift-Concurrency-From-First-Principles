# P1.07 — Errors in async code, typed throws

<!-- nav:start -->
[← P1.06](./06-async-sequences.md) · [Roadmap](../../ROADMAP.md) · [P1.08 →](./08-async-entry-points.md)
<!-- nav:end -->

⏱ 30 min · Demo `p1.07` · Exercise `P1_07`

## 1. Concept (5 min)

Async errors work exactly like sync errors. That's one of async/await's biggest wins over completion handlers:

```swift
func level1() async throws { try await level2() }   // an error thrown in level3 propagates up
do { try await level1() } catch { … }               // the first `catch` above it gets it
```

No `Result` juggling, no "did every path call completion with the error?"

Three async-specific traps:

**1. Errors in unstructured Tasks vanish silently.**
```swift
Task { try await upload() }    // if this throws: no crash, no log, nothing
```
The error is stored in the `Task<Void, Error>` handle. If nobody ever runs `try await task.value`, it's simply gone. So **handle errors inside the Task** (`do/catch`, then show an alert or log), or keep the handle and await it.

**2. A catch-all `catch` also catches cancellation.**
`CancellationError` is an `Error`. When the user leaves the screen and you cancel the task, `try await Task.sleep` and URLSession throw `CancellationError` / `URLError(.cancelled)`. A generic `catch { showErrorAlert() }` then shows *"Network failed!"* for something the user did on purpose. Check `if error is CancellationError` (or `Task.isCancelled`) first.

**3. `try?` swallows cancellation, so loops keep going:**
```swift
while true { try? await Task.sleep(for: .seconds(1)); poll() }   // cancel() can never stop this
```

**Typed throws (Swift 6):** `func f() async throws(NetworkError)` tells the compiler, and callers, *exactly* which error can come out. Inside `catch`, `error` is already a `NetworkError`, so `switch` is exhaustive with no casts. Use it for domain errors at module boundaries; plain `throws` (i.e. `any Error`) is still the default for most code.

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
1. **Nothing at all.** In production that looks like "upload sometimes doesn't happen, no logs".
2. Cancellation **interrupted** `Task.sleep` right away (it doesn't wait 5 s; sleep checks cancellation), but the catch-all reported it as a network failure. Correct version:
   ```swift
   } catch is CancellationError {
       // user left: do nothing
   } catch {
       showAlert(error)
   }
   ```
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P1_07_Errors.swift`. Implement `loadProfile(id:) async throws(ProfileLoadError)`:
- map name errors to domain errors
- treat avatar failure as non-fatal (fallback image)

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
