# P6.07 — Swift Evolution reading sprint

<!-- nav:start -->
[← P6.06](./06-isolated-any.md) · [Roadmap](../../README.md) · [P6.08 →](./08-distributed-actors.md)
<!-- nav:end -->

⏱ 30 min · Exercise `P6_07` (graded)

Senior interviews sometimes go "how does X work under the hood, and why was it designed that way?" The best answers come from the proposals themselves. Their **Motivation** sections are first-principles writing by the people who designed the feature.

## 1. How to read a proposal in 5 minutes

1. **Motivation**: what was broken or impossible before? This is what interviewers want to hear.
2. **Proposed solution**: the one-paragraph idea and the main example.
3. **Detailed design**: skim. Read only the parts that answer a question you have.
4. **Alternatives considered**: why they *didn't* do the obvious thing. That makes for great interview material.

## 2. The map (read 2–3 Motivation sections today; the rest over the coming weeks)

| Era | Proposals |
|---|---|
| **Foundations (Swift 5.5)** | SE-0296 async/await · SE-0300 continuations · SE-0302 Sendable · SE-0304 structured concurrency · SE-0306 actors · SE-0311 task-locals · SE-0316 global actors · SE-0317 async let |
| **Swift 5.9–5.10** | SE-0392 custom actor executors · SE-0381 discarding task groups · SE-0371 isolated deinit (accepted later, shipped in 6.2) |
| **Swift 6.0: data-race safety** | SE-0414 region-based isolation · SE-0430 `sending` · SE-0431 `@isolated(any)` · SE-0420 `#isolation` · SE-0417 task executor preference · SE-0433 `Mutex` · SE-0410 atomics · SE-0413 typed throws · SE-0412 strict global variables |
| **Swift 6.2: approachable concurrency** | SE-0461 `nonisolated(nonsending)` by default and `@concurrent` · SE-0466 default actor isolation · SE-0470 isolated conformances · SE-0472 `Task.immediate` · SE-0469 task naming |

Suggested reading order: SE-0306 (actors: the reentrancy discussion) → SE-0304 (structured concurrency: the task tree) → SE-0414 (regions: why "send and forget" is safe) → SE-0461 (why the 6.2 defaults changed).

## 3. Quiz (graded)

Fill in `Sources/Exercises/P6_07_Evolution.swift` with the SE number for each feature, **from memory first**, then look up the ones you missed in [swift-evolution/proposals](https://github.com/swiftlang/swift-evolution/tree/main/proposals).

```bash
swift test --filter P6_07
```

(Numbers aren't the point. Being able to say *"region-based isolation, SE-0414, is why sending a freshly created non-Sendable object to an actor compiles"* is.)

## 4. Interview cards

- **Why are Swift actors reentrant? (SE-0306)** Non-reentrant actors deadlock when actors await each other, and reduce throughput. The proposal chose reentrancy and asks developers to re-check state after suspension points.
- **What problem did region-based isolation solve? (SE-0414)** Strict Sendable checking rejected many safe programs, e.g. creating a non-Sendable object and handing it off. Regions let the compiler prove that a value is no longer accessible from the sender, so the transfer is safe.
- **Why did Swift 6.2 change nonisolated async semantics? (SE-0461)** Hopping off the caller's actor on every call made non-Sendable arguments and `self` cross boundaries constantly, which produced false-positive errors and surprising behavior. Running on the caller's actor matches sync functions; `@concurrent` makes leaving explicit.

---

<!-- nav:start -->
[← P6.06](./06-isolated-any.md) · [Roadmap](../../README.md) · [P6.08 →](./08-distributed-actors.md)
<!-- nav:end -->
