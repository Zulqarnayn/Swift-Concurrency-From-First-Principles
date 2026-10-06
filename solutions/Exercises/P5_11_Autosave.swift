import LabKit

// P5.11 — SOLUTION. Deterministic async testing
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
    private var unsaved: String?

    public init(sleep: @escaping SleepFunction = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    /// Called on every edit. Saves 500ms after the user STOPS editing (a debounce).
    public func textChanged(_ text: String) {
        pending?.cancel()
        unsaved = text
        let sleep = self.sleep
        pending = Task {
            do {
                // ROOT CAUSE #1 (untestable): it called Task.sleep directly, ignoring the injected clock.
                try await sleep(.milliseconds(500))
                // ROOT CAUSE #2 (stale saves): `try?` swallowed the cancellation, so EVERY superseded edit
                // was saved the instant it was cancelled. Also re-check after waking (P3.07).
                try Task.checkCancellation()
            } catch {
                return
            }
            saveNow()
        }
    }

    /// Called when the screen closes: save immediately if an edit is pending.
    public func flush() {
        pending?.cancel()
        pending = nil
        saveNow() // ROOT CAUSE #3: flush cancelled the pending save and never saved
    }

    private func saveNow() {
        guard let text = unsaved else { return }
        unsaved = nil
        saves.append(text)
    }
}
