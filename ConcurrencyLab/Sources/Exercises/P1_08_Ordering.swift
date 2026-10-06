import LabKit

// P1.08 — Where async begins; keeping order across the sync → async boundary
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
    private let server: FakeServer

    public init(server: FakeServer) {
        self.server = server
    }

    /// Called synchronously by legacy code. Must not block.
    ///
    /// BUG: one Task per message. The Tasks run concurrently, so uploads finish in any order.
    /// TODO: upload one at a time, in order, without blocking the caller.
    /// Hint: one long-lived Task reading from an AsyncStream behaves like an async serial queue.
    public func didReceive(_ message: Int) {
        Task {
            await server.upload(message)
        }
    }
}
