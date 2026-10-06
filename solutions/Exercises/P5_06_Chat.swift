import LabKit

// P5.06 — SOLUTION. Bug hunt: "memory grows every time the user opens a chat"
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
        let backend = self.backend
        let stream = backend.messages()

        // ROOT CAUSE #1: `Task { for await … { messages.append } }` captured self STRONGLY (implicitly)
        // for an ENDLESS loop. self owns the task, the task owns self: a cycle that never ends.
        // FIX: capture weakly, and re-acquire self only for the instant you need it.
        listener = Task { [weak self] in
            for await message in stream {
                guard let self else { return } // screen gone → leave the loop → stream terminates
                self.messages.append(message)
            }
        }

        // ROOT CAUSE #2: `[weak self]` + `guard let self` at the TOP made self strong again for the
        // whole (endless) loop. The weak capture achieved nothing. A very common mistake.
        // FIX: unwrap inside the loop, per iteration, and never hold self across the sleep.
        poller = Task { [weak self] in
            while !Task.isCancelled {
                let count = await backend.unreadCount()
                guard let self else { return }
                self.unread = count
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    // Belt and braces (Swift 6.2, SE-0371): when the model goes away, stop its work explicitly.
    // `isolated deinit` runs on the main actor, so it may touch these isolated properties.
    isolated deinit {
        listener?.cancel()
        poller?.cancel()
    }
}
