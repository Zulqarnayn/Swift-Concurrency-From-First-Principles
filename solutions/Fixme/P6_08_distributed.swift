// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency
//
// P6.08 — SOLUTION

import Distributed

/// Everything that crosses a distributed call is SERIALIZED (it may travel over a network), so it must
/// conform to the actor system's SerializationRequirement — `Codable` for LocalTestingDistributedActorSystem.
struct Message: Codable {
    let author: String
    let text: String
}

distributed actor ChatRoom {
    typealias ActorSystem = LocalTestingDistributedActorSystem

    var history: [Message] = []

    distributed func post(_ message: Message) {
        history.append(message)
    }

    /// From outside, a distributed actor may be REMOTE: only `distributed` members are reachable,
    /// and every call is `try await` (the network can fail).
    distributed func count() -> Int {
        history.count
    }

    distributed func last() -> String? {
        history.last?.text
    }
}

func client(_ room: ChatRoom) async throws {
    try await room.post(Message(author: "ada", text: "hi"))
    let count = try await room.count()
    // Stored properties are never accessible from outside — there may be no local storage at all.
    // The history size IS the count; ask the actor (a distributed method), don't reach into it.
    let size = count
    print(count, size, try await room.last() ?? "-")
}
