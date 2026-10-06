import LabKit

// P2.14 — SOLUTION. Massicotte step-by-step: stateful systems
// Lesson: lessons/P2-isolation/14-massicotte-storage-stateful.md
// Test:   swift test --filter P2_14

/// A remote device with a slow toggle (don't edit).
public actor RemoteSwitch {
    public private(set) var state = false
    public private(set) var toggleCount = 0

    public init() {}

    public func toggle() async {
        await suspend(ms: 20)
        state.toggle()
        toggleCount += 1
    }
}

@MainActor
public final class ToggleModel {
    public private(set) var isOn = false
    public let remote = RemoteSwitch()
    private var inFlight = false

    public init() {}

    /// Called on every tap.
    ///
    /// BUG: impatient users tap 5 times quickly. Five toggles overlap; the switch flips 5 times.
    /// TODO: while a toggle is in flight, ignore further taps. When it finishes, `isOn` must match the switch.
    public func tap() async {
        // Check and set the flag BEFORE the first await: on the main actor, sync code can't interleave,
        // so this is a critical section (Massicotte: "do any state accesses synchronously, before the
        // task has any opportunity to suspend").
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }

        await remote.toggle()
        isOn = await remote.state
    }
}
