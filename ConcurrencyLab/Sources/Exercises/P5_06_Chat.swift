import LabKit

// P5.06 — Bug hunt: "memory grows every time the user opens a chat"
// Lesson: lessons/P5-bug-zoo/06-task-leaks.md
// Repro:  swift run lab p5.06        Test: swift test --filter P5_06

/// A live message feed (don't edit). Each subscription is an endless stream; `activeSubscriptions`
/// counts streams that haven't been terminated. `polls` counts badge refreshes.
public final class ChatBackend: Sendable {
    private let subscriptions = Locked(0)
    public let polls = CallCounter()

    public init() {}

    public var activeSubscriptions: Int { subscriptions.value }

    public func messages() -> AsyncStream<String> {
        subscriptions.withLock { $0 += 1 }
        return AsyncStream { continuation in
            let ticker = Task {
                var n = 0
                while !Task.isCancelled {
                    n += 1
                    continuation.yield("message \(n)")
                    try? await Task.sleep(for: .milliseconds(5))
                }
            }
            continuation.onTermination = { _ in
                ticker.cancel()
                self.subscriptions.withLock { $0 -= 1 }
            }
        }
    }

    public func unreadCount() async -> Int {
        polls.increment()
        await suspend(ms: 1)
        return polls.count
    }
}

@MainActor
public final class ChatViewModel {
    public private(set) var messages: [String] = []
    public private(set) var unread = 0
    private let backend: ChatBackend
    private var listener: Task<Void, Never>?
    private var poller: Task<Void, Never>?

    public init(backend: ChatBackend) {
        self.backend = backend
    }

    /// Called when the chat screen appears.
    public func start() {
        listener = Task {
            for await message in backend.messages() {
                messages.append(message)
            }
        }
        poller = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                unread = await backend.unreadCount()
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }
}
