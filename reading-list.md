# Reading list

Ordered by phase. ★ = read it when the lesson tells you to; the rest is optional depth.

## Matt Massicotte (massicotte.org): the spine of P2
- ★ [Concurrency Step-by-Step: A Network Request](https://www.massicotte.org/step-by-step-network-request/): P0.07 (GCD part), P2.01 (all)
- ★ [Step-by-Step: Reading from Storage](https://massicotte.org/step-by-step-reading-from-storage/): P2.14
- ★ [Step-by-Step: Stateful Systems](https://massicotte.org/step-by-step-stateful-systems/): P1.08, P2.14
- [Step-by-Step: Conforming to Protocols](https://massicotte.org/step-by-step-conforming-to-protocols/): P2.12
- [Step-by-Step: Designing Protocols](https://massicotte.org/step-by-step-designing-protocols/): P2.12
- ★ [A Swift Concurrency Glossary](https://massicotte.org/concurrency-glossary/): keep it open throughout P1–P2
- [An Introduction to Isolation](https://massicotte.org/intro-to-isolation) · [Isolation Intuition](https://massicotte.org/isolation-intuition) · [Is Dynamic Isolation Bad?](https://massicotte.org/dynamic-isolation): P2.02
- ★ [Problematic Swift Concurrency Patterns](https://massicotte.org/problematic-patterns/): P1.03, P2, P5 (re-read each phase)
- [Synchronous Work](https://massicotte.org/synchronous-work/): P2.08
- [When should you use an actor?](https://massicotte.org/actors/) · [Stateless Actors](https://massicotte.org/stateless-actors/): P2.03
- [Default isolation with Swift 6.2](https://massicotte.org/default-isolation-swift-6_2/) · [MainActor by Default](https://massicotte.org/blog/mainactor-by-default/): P2.09
- [Singletons with Swift Concurrency](https://massicotte.org/singletons/): P2.11
- [Non-Sendable First Design](https://massicotte.org/blog/non-sendable-first-design/): P2.15
- [Migrating from the Outside in](https://massicotte.org/outside-in-migration/): P1.09, P2.13
- [An Even Closer Look at Protocols and Global Actors](https://massicotte.org/blog/protocols-and-global-actors/): P2.12
- [Testing with Event Streams](https://massicotte.org/blog/testing-event-stream/): P5.11
- [ModelActor is Just Weird](https://massicotte.org/model-actor/): P5.10

## Apple
- ★ The Swift Programming Language → [Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- ★ [Swift 6 Concurrency Migration Guide](https://www.swift.org/migration/documentation/migrationguide/), especially "Data Race Safety" and "Common Compiler Errors"
- [Diagnosing memory, thread, and crash issues early](https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early) (TSan, Main Thread Checker): P0.02, P5.02
- [Understanding hangs in your app](https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app): P0.05, P5.08

### WWDC sessions, in watching order
| Phase | Session |
|---|---|
| P0 | WWDC17 [Modernizing Grand Central Dispatch Usage](https://developer.apple.com/videos/play/wwdc2017/706/) |
| P1 | ★ WWDC21 [Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/) |
| P1 | ★ WWDC21 [Swift concurrency: Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/), the single best runtime talk |
| P2 | ★ WWDC21 [Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/) |
| P2 | WWDC22 [Eliminate data races using Swift Concurrency](https://developer.apple.com/videos/play/wwdc2022/110351/) |
| P2 | WWDC24 [Migrate your app to Swift 6](https://developer.apple.com/videos/play/wwdc2024/10169/) |
| P2 | ★ WWDC25 [Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/) (approachable concurrency, `@concurrent`) |
| P2 | WWDC25 [Explore concurrency in SwiftUI](https://developer.apple.com/videos/play/wwdc2025/266/) · [Code-along: Elevate an app with Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/270/) |
| P3 | ★ WWDC21 [Explore structured concurrency in Swift](https://developer.apple.com/videos/play/wwdc2021/10134/) |
| P3 | WWDC23 [Beyond the basics of structured concurrency](https://developer.apple.com/videos/play/wwdc2023/10170/) |
| P5 | WWDC22 [Visualize and optimize Swift concurrency](https://developer.apple.com/videos/play/wwdc2022/110350/) (Instruments) |

## Swift Evolution: read the *Motivation* sections, they're first-principles writing
| Phase | Proposals |
|---|---|
| P0 | [SE-0410 Atomics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0410-atomics.md) · [SE-0433 Mutex](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0433-mutex.md) |
| P1 | [SE-0296 async/await](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0296-async-await.md) · [SE-0300 Continuations](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0300-continuation.md) · [SE-0298 AsyncSequence](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0298-asyncsequence.md) · [SE-0314 AsyncStream](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0314-async-stream.md) · [SE-0413 Typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) · [SE-0472 Task.immediate](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0472-task-start-synchronously-on-caller-context.md) |
| P2 | [SE-0306 Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md) · [SE-0302 Sendable](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md) · [SE-0316 Global actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md) · [SE-0313 isolated params](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0313-actor-isolation-control.md) · [SE-0414 Region-based isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md) · [SE-0430 `sending`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md) · [SE-0412 Globals](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md) · [SE-0461 nonsending/@concurrent](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md) · [SE-0466 Default isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md) · [SE-0470 Isolated conformances](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md) · [SE-0371 Isolated deinit](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0371-isolated-synchronous-deinit.md) |
| P3 | [SE-0304 Structured concurrency](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md) · [SE-0317 async let](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0317-async-let.md) · [SE-0311 Task-local values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0311-task-locals.md) · [SE-0381 DiscardingTaskGroups](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0381-task-group-discard-results.md) |
| P6 | [SE-0338 Executors of nonisolated async](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md) · [SE-0392 Custom actor executors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md) · [SE-0417 Task executor preference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0417-task-executor-preference.md) · [SE-0420 #isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md) · [SE-0431 @isolated(any)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0431-isolated-any-functions.md) |

## Books and classics (general threading, language-agnostic)
- ★ Allen Downey, [*The Little Book of Semaphores*](https://greenteapress.com/wp/semaphores/) (free): the source of the classic problems in P4
- Arpaci-Dusseau, [*Operating Systems: Three Easy Pieces*](https://pages.cs.wisc.edu/~remzi/OSTEP/) (free), "Concurrency" part: P0 depth
- Herlihy & Shavit, *The Art of Multiprocessor Programming*: atomics, CAS, memory models (P0.03, P6.05)
- Nathaniel J. Smith, [*Notes on structured concurrency, or: Go statement considered harmful*](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/): ★ before P3.01
- Kodeco, *Modern Concurrency in Swift*: a second explanation of everything in P1–P3

## P4 extras
- AWS Architecture Blog, [Exponential Backoff And Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/) (P4.11)
- [groue/Semaphore](https://github.com/groue/Semaphore): a production async semaphore (P4.04)
- [swift-async-algorithms Channel guide](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md) (P4.01)

## P5 extras
- Apple: [Diagnosing performance issues early](https://developer.apple.com/documentation/xcode/diagnosing-performance-issues-early) · [Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)
- Apple: [Gathering information about memory use](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use) (Memory Graph)
- [pointfreeco/swift-clocks](https://github.com/pointfreeco/swift-clocks): `TestClock`, `ImmediateClock` (P5.11)

## Libraries worth reading the source of
- [apple/swift-async-algorithms](https://github.com/apple/swift-async-algorithms): `debounce`, `throttle`, `AsyncChannel` (P4)
- [pointfreeco/swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras): `withMainSerialExecutor` for deterministic tests (P5.11)
- [swiftlang/swift → stdlib/public/Concurrency](https://github.com/swiftlang/swift/tree/main/stdlib/public/Concurrency): `AsyncStream.swift`, `CheckedContinuation.swift` (P6)
