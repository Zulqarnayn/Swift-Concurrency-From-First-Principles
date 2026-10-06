import LabKit

// P4.01 — Producer–consumer: a bounded buffer
// Lesson: lessons/P4-classics/01-producer-consumer.md
// Test:   swift test --filter P4_01

/// A FIFO channel between async producers and consumers, holding at most `capacity` buffered elements.
///  - `send` SUSPENDS while the buffer is full (backpressure — the thing AsyncStream doesn't have)
///  - `receive` SUSPENDS while the buffer is empty; returns nil once `finish()` was called AND it's drained
///
/// BUG: the buffer is unbounded (producers never wait), and receivers poll every millisecond.
/// TODO: real backpressure. Park waiting senders/receivers as continuations; wake them, don't poll.
public actor BoundedChannel<Element: Sendable> {
    public let capacity: Int
    private var buffer: [Element] = []
    private var finished = false

    /// The largest number of elements ever sitting in the buffer. Must never exceed `capacity`.
    public private(set) var maxBuffered = 0

    public init(capacity: Int) {
        self.capacity = capacity
    }

    public func send(_ element: Element) async {
        buffer.append(element)
        maxBuffered = max(maxBuffered, buffer.count)
    }

    public func receive() async -> Element? {
        while buffer.isEmpty {
            if finished { return nil }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return buffer.removeFirst()
    }

    /// No more sends. Receivers drain what's left, then get nil.
    public func finish() {
        finished = true
    }
}
