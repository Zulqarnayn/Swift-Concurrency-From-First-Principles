import LabKit

// P1.08 — SOLUTION. Where async begins; keeping order across the sync → async boundary
// Lesson: lessons/P1-async-await/08-async-entry-points.md
// Test:   swift test --filter P1_08

/// Fake server (don't edit). Each upload takes a different time, like a real network.
public final class FakeServer: Sendable {
    private let log = Locked<[Int]>([])
    public init() {}

    public func upload(_ message: Int) async {
        await suspend(ms: (message * 37) % 23)
        log.withLock { $0.append(message) }
    }

    public var received: [Int] { log.value }
}

/// A legacy delegate calls `didReceive` synchronously, in order, for each incoming message.
/// Every message must reach the server IN THE SAME ORDER it was received.
public final class MessageSyncer: Sendable {
    private let inbox: AsyncStream<Int>.Continuation

    public init(server: FakeServer) {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
        inbox = continuation
        // ONE consumer task = one message at a time, in FIFO order. An async "serial queue".
        // It captures `server` and `stream`, NOT `self` → no retain cycle.
        Task {
            for await message in stream {
                await server.upload(message)
            }
        }
    }

    /// `yield` is synchronous and never blocks: the message is buffered for the consumer.
    public func didReceive(_ message: Int) {
        inbox.yield(message)
    }

    deinit {
        // Ends the consumer's `for await` loop, so the task finishes instead of waiting forever.
        inbox.finish()
    }
}
