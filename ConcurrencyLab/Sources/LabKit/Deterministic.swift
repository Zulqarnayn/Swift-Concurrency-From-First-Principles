// Tools for making async tests deterministic (P5.01, P5.11).
// Real timing ("sleep 50ms and hope") makes tests flaky. These let a TEST decide when things happen.

/// A fake async dependency whose calls don't return until the test says so.
/// Lets you force any interleaving: "start A, start B, finish B first, then A".
///
///     let responder = ScriptedResponder<String, Int>()
///     // in the fake service:  return await responder.respond(to: sku)
///     // in the test:          await responder.waitForCalls(2); await responder.resolve("B", with: 200)
public actor ScriptedResponder<Key: Hashable & Sendable, Value: Sendable> {
    private var waiting: [Key: [CheckedContinuation<Value, Never>]] = [:]
    public private(set) var callLog: [Key] = []

    public init() {}

    /// Called by the fake: suspends until `resolve(key, with:)`.
    public func respond(to key: Key) async -> Value {
        callLog.append(key)
        return await withCheckedContinuation { waiting[key, default: []].append($0) }
    }

    /// Called by the test: completes the oldest pending call for `key`.
    public func resolve(_ key: Key, with value: Value) {
        guard var queue = waiting[key], !queue.isEmpty else { return }
        queue.removeFirst().resume(returning: value)
        waiting[key] = queue.isEmpty ? nil : queue
    }

    public var pendingCount: Int { waiting.values.reduce(0) { $0 + $1.count } }

    /// Wait (without sleeping) until at least `count` calls are pending.
    public func waitForPending(_ count: Int) async {
        while pendingCount < count && !Task.isCancelled { await settle() }
    }
}

/// A clock for tests: `sleep` suspends until the TEST advances time. No real waiting, no flakiness.
///
///     let clock = ManualSleeper()
///     let model = Autosave(sleep: clock.sleep)      // inject instead of Task.sleep
///     await clock.advance(by: .milliseconds(499))   // nothing fires
///     await clock.advance(by: .milliseconds(1))     // now it fires
public actor ManualSleeper {
    private struct Sleeper {
        let id: Int
        let deadline: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }
    private var now: Duration = .zero
    private var sleepers: [Sleeper] = []
    private var nextID = 0

    public init() {}

    /// Inject this wherever production code would call `Task.sleep(for:)`.
    public nonisolated var sleep: @Sendable (Duration) async throws -> Void {
        { duration in try await self.sleep(for: duration) }
    }

    public func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        nextID += 1
        let id = nextID
        let deadline = now + duration
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancel(id) } // like Task.sleep: cancellation wakes the sleeper with an error
        }
    }

    /// Move time forward; wakes (in deadline order) everyone whose deadline has passed, then lets them run.
    public func advance(by duration: Duration) async {
        await settle() // let pending cancellations remove their sleepers first
        now += duration
        let due = sleepers.filter { $0.deadline <= now }.sorted { $0.deadline < $1.deadline }
        sleepers.removeAll { $0.deadline <= now }
        for sleeper in due { sleeper.continuation.resume() }
        await settle()
    }

    public var pendingSleepers: Int { sleepers.count }

    /// Wait (without real sleeping) until at least `count` tasks are sleeping on this clock.
    public func waitForSleepers(_ count: Int) async {
        while sleepers.count < count && !Task.isCancelled { await settle() }
    }

    private func cancel(_ id: Int) {
        guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return }
        sleepers.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}

/// Yield many times so that work which was just resumed gets a chance to run before the test asserts.
/// (A pragmatic stand-in for a fully serial test executor — see P5.11.)
public func settle(_ rounds: Int = 25) async {
    for _ in 0..<rounds { await Task.yield() }
}
