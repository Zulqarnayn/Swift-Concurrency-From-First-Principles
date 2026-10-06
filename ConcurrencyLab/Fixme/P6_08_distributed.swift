// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency
//
// P6.08 — Distributed actors.
//   scripts/fixme.sh ConcurrencyLab/Fixme/P6_08_distributed.swift
// A chat room that may live in another process (or on a server). The client code below is how a
// caller on a DIFFERENT node would use it. Make it compile. Keep `client`'s intent: post a message,
// read the message count, print the history size and the last message.

import Distributed

struct Message {
    let author: String
    let text: String
}

distributed actor ChatRoom {
    typealias ActorSystem = LocalTestingDistributedActorSystem

    var history: [Message] = []

    distributed func post(_ message: Message) {
        history.append(message)
    }

    func count() -> Int {
        history.count
    }

    distributed func last() -> String? {
        history.last?.text
    }
}

func client(_ room: ChatRoom) async throws {
    try await room.post(Message(author: "ada", text: "hi"))
    let count = await room.count()
    let size = room.history.count
    print(count, size, try await room.last() ?? "-")
}
