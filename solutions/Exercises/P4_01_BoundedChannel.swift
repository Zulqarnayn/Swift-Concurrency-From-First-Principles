import LabKit

// P4.01 — SOLUTION. Producer–consumer: a bounded buffer
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
    /// Senders parked because the buffer was full, each with the element it wants to deliver.
    private var waitingSenders: [(element: Element, continuation: CheckedContinuation<Void, Never>)] = []
    /// Receivers parked because the buffer was empty.
    private var waitingReceivers: [CheckedContinuation<Element?, Never>] = []

    /// The largest number of elements ever sitting in the buffer. Must never exceed `capacity`.
    public private(set) var maxBuffered = 0

    public init(capacity: Int) {
        self.capacity = capacity
    }

    public func send(_ element: Element) async {
        guard !finished else { return } // sending after finish() is a programmer error; drop it

        // 1. Someone is already waiting: hand the element over directly. No buffering needed.
        if !waitingReceivers.isEmpty {
            waitingReceivers.removeFirst().resume(returning: element)
            return
        }
        // 2. Room in the buffer.
        if buffer.count < capacity {
            buffer.append(element)
            maxBuffered = max(maxBuffered, buffer.count)
            return
        }
        // 3. Full: park. A receiver will move our element into the buffer and resume us.
        //    This is the backpressure: the producer can't get ahead of the consumer by more than `capacity`.
        await withCheckedContinuation { continuation in
            waitingSenders.append((element, continuation))
        }
    }

    public func receive() async -> Element? {
        if !buffer.isEmpty {
            let element = buffer.removeFirst()
            // A slot just opened: admit the oldest parked sender (FIFO order is preserved,
            // because its element goes to the BACK of the buffer).
            if !waitingSenders.isEmpty {
                let (pending, sender) = waitingSenders.removeFirst()
                buffer.append(pending)
                sender.resume()
            }
            return element
        }
        // capacity 0 (a "rendezvous" channel): take directly from a parked sender.
        if !waitingSenders.isEmpty {
            let (pending, sender) = waitingSenders.removeFirst()
            sender.resume()
            return pending
        }
        if finished { return nil }
        return await withCheckedContinuation { continuation in
            waitingReceivers.append(continuation)
        }
    }

    /// No more sends. Receivers drain what's left, then get nil.
    public func finish() {
        finished = true
        // Parked receivers only exist when the buffer is empty → they will never get an element.
        for receiver in waitingReceivers { receiver.resume(returning: nil) }
        waitingReceivers.removeAll()
    }
}
