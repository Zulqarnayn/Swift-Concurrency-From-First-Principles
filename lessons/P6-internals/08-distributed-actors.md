# P6.08 — Distributed actors (overview)

<!-- nav:start -->
[← P6.07](./07-swift-evolution.md) · [Roadmap](../../ROADMAP.md) · [P7.01 →](../P7-interview/01-gcd-operationqueue.md)
<!-- nav:end -->

⏱ 30 min · Demo `p6.08` · Exercise **Fixme** `P6_08_distributed.swift`

## 1. Concept (8 min)

An actor protects state from other *threads*. A **distributed actor** (SE-0336, SE-0344) extends the same model to other *processes or machines*: a reference may point to an actor that lives somewhere else, and calls go through an **actor system** that handles transport.

```swift
distributed actor ChatRoom {
    typealias ActorSystem = SomeActorSystem           // the transport: in-process test system, cluster, XPC…
    distributed func post(_ message: Message) { … }   // callable remotely
    func internalHelper() { … }                       // local-only: not callable on a remote reference
}
let room = try ChatRoom.resolve(id: someID, using: system)   // maybe local, maybe remote
try await room.post(message)                                 // always `try await`: it may cross a network
```

What changes compared to a local actor:

| Rule | Why |
|---|---|
| Only `distributed func`/`var` are callable from outside | The reference may have no local storage at all |
| Calls are always `try await` | Networks fail: timeouts, disconnects |
| Parameters and results must meet the system's **SerializationRequirement** (usually `Codable`) | They're serialized onto the wire |
| No stored-property access from outside | Same reason as rule 1 |
| `id` + `resolve(id:using:)` | Location transparency: you hold an identity, not a pointer |

Swift provides `LocalTestingDistributedActorSystem` for tests and learning. Real systems include Apple's open-source `swift-distributed-actors` cluster and custom ones (XPC, WebSockets).

**For iOS interviews:** know what they are and that the *programming model* matches actors. You'll rarely ship them in an app. They mostly appear in server-side Swift and tooling.

## 2. Run (4 min)

```bash
swift run lab p6.08
```

<details><summary>What you'll see</summary>

```
created LocalTestingActorID(id: "1")
direct: hello ada (#1) · resolved by id: hello linus (#2)
every distributed call is `try await`: on a real system it may cross a network and fail
```
Resolving by ID returned the same actor (local here), so the greeting counter continued.
</details>

## 3. Exercise (15 min): Fixme

`ConcurrencyLab/Fixme/P6_08_distributed.swift` is a chat room used from a different node. It has three errors. Fix them, keeping the client's intent.

```bash
scripts/fixme.sh ConcurrencyLab/Fixme/P6_08_distributed.swift
```

<details><summary>The errors you'll meet (verified)</summary>

```
error: parameter '_' of type 'Message' in distributed instance method does not conform to serialization requirement 'Codable'
error: only 'distributed' instance methods can be called on a potentially remote distributed actor
error: distributed actor-isolated property 'history' can not be accessed from a nonisolated context
```
</details>

## 4. Interview cards

- **What's a distributed actor?** An actor whose references may be remote (another process or machine). Calls go through an ActorSystem, only `distributed` members are reachable, calls are `try await`, and arguments must be serializable (usually Codable).
- **How does it differ from a regular actor?** It has the same isolation model and adds location transparency: identity-based `resolve`, serialization requirements, throwing calls for transport failure, and no direct property access from outside.
- **Where would you use one?** Clustered servers, IPC (XPC-like boundaries), multiplayer/peer systems. Rarely in a typical iOS app.

## Going deeper
- [SE-0336 Distributed actor isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0336-distributed-actor-isolation.md) · [SE-0344 Distributed actor runtime](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0344-distributed-actor-runtime.md)
- [apple/swift-distributed-actors](https://github.com/apple/swift-distributed-actors)

## Phase 6 checkpoint ✅

You can explain: executors (default, main, custom serial, task executors) and when to customize them; what tasks, frames and hops cost and why tasks scale where threads don't; happens-before and which tool creates which edge; `@isolated(any)` and the ordering guarantee of isolated task closures; how the concurrency features evolved; and the distributed actor model.

Next: **Phase 7: interview mastery.**

---

<!-- nav:start -->
[← P6.07](./07-swift-evolution.md) · [Roadmap](../../ROADMAP.md) · [P7.01 →](../P7-interview/01-gcd-operationqueue.md)
<!-- nav:end -->
