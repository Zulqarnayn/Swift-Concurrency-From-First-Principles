import LabKit

// P5.11 — Deterministic async testing
// Lesson: lessons/P5-bug-zoo/11-deterministic-testing.md
// Test:   swift test --filter P5_11
//
// The tests drive time with a ManualSleeper (LabKit/Deterministic.swift): no real sleeping, no flakiness.
// They fail until this type is (a) testable and (b) correct.

public typealias SleepFunction = @Sendable (Duration) async throws -> Void

@MainActor
public final class AutosaveController {
    /// Texts that were saved, in order.
    public private(set) var saves: [String] = []
    private let sleep: SleepFunction
    private var pending: Task<Void, Never>?

    public init(sleep: @escaping SleepFunction = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    /// Called on every edit. Saves 500ms after the user STOPS editing (a debounce).
    public func textChanged(_ text: String) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(500))
            saves.append(text)
        }
    }

    /// Called when the screen closes: save immediately if an edit is pending.
    public func flush() {
        pending?.cancel()
        pending = nil
    }
}
