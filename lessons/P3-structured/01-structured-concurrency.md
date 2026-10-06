# P3.01 — What "structured" means

<!-- nav:start -->
[← P2.16](../P2-isolation/16-review-gauntlet.md) · [Roadmap](../../README.md) · [P3.02 →](./02-async-let.md)
<!-- nav:end -->

⏱ 30 min · Demo `p3.01` · Exercise `P3_01`
★ Read first (10 min): Nathaniel J. Smith, [Notes on structured concurrency, or: Go statement considered harmful](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/), up to "goto: the destroyer of abstraction" and its section on `nursery`.

## 1. Concept (5 min)

In the 1960s, programmers used `goto`: jump anywhere, never come back. Dijkstra's *structured programming* replaced it with blocks, loops and functions, where **control enters at the top and leaves at the bottom**. That's what made code readable: when a function returns, it's *done*.

`DispatchQueue.async`, completion handlers and `Task {}` are the `goto` of concurrency. They start work that **escapes** the function that started it:

```swift
func load() async {
    Task { await fetchProfile() }   // still running after load() returns
}                                   // who waits for it? who cancels it? where do its errors go?
```

**Structured concurrency** applies the same rule to concurrent work: **child tasks can't outlive the scope that created them.**

```swift
func load() async {
    async let profile = fetchProfile()     // child task, starts now
    async let feed = fetchFeed()           // child task, starts now
    _ = await (profile, feed)              // scope can't end until both are done
}
```

Every task forms a **tree**. The rules of the tree:

| Rule | Consequence |
|---|---|
| A parent can't finish before its children | When a function returns, all its concurrent work is done. Reasoning is local again. |
| **Cancellation flows down** | Cancel the parent, and every descendant sees `isCancelled`. |
| **Errors flow up** | A child's error is rethrown at the parent's `await`, and the siblings are cancelled. |
| Priority and task-locals are inherited | The tree shares context (P3.09, P3.10). |

Two ways to create structured children: **`async let`** (a fixed number, P3.02) and **TaskGroup** (a dynamic number, P3.03).
Unstructured: `Task {}` and `Task.detached {}`, which are only for the sync → async boundary (P3.11).

## 2. Predict (5 min)

`p3.01` runs the same two fetches (A: 50 ms, B: 80 ms) two ways:
1. Unstructured (`Task {}` children): when does `loadUnstructured` return? What has finished by then? ______
2. Structured (`async let`): when does `loadStructured` return? ______
3. Cancel each *parent* 20 ms in. What happens to the children? ______

## 3. Run (5 min)

```bash
swift run lab p3.01
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
loadUnstructured returned after 0ms; children finished so far: []
  A finished
  B finished                                     ← after the function was long gone
loadStructured returned after 84ms; children finished so far: ["A finished", "B finished"]
unstructured children after parent cancel: ["A finished", "B finished"]
structured children after parent cancel:   ["A cancelled", "B cancelled"]
```
1. Unstructured returned in **0 ms**, with nothing done. Callers can't know when the work ends.
2. Structured returned after **84 ms ≈ max(50, 80)**: concurrent, *and* complete on return.
3. Cancelling the unstructured parent didn't reach its children; they ran to completion. The structured children were cancelled immediately.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P3_01_Structure.swift`. Make `load()` structured: its children finish before it returns, and they're cancelled when the caller is.

```bash
swift test --filter P3_01
```

## 6. Interview cards

- **What is structured concurrency?** Concurrent child tasks are scoped to the code that created them: they can't outlive it. Tasks form a tree where parents wait for children, cancellation flows down, errors flow up, and priority and task-locals are inherited.
- **Why is `Task {}` "unstructured"?** It creates an independent top-level task. It outlives its creator, isn't cancelled when the creator is, and its errors go nowhere unless someone awaits its handle.
- **Structured tools in Swift?** `async let` for a fixed number of children, and TaskGroup / ThrowingTaskGroup / DiscardingTaskGroup for a dynamic number.

## Going deeper
- [SE-0304 Structured concurrency](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)
- WWDC21 [Explore structured concurrency in Swift](https://developer.apple.com/videos/play/wwdc2021/10134/)

---

<!-- nav:start -->
[← P2.16](../P2-isolation/16-review-gauntlet.md) · [Roadmap](../../README.md) · [P3.02 →](./02-async-let.md)
<!-- nav:end -->
