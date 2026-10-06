import LabKit

// P1.04 — SOLUTION. Task: the unit of async work
// Lesson: lessons/P1-async-await/04-task.md
// Test:   swift test --filter P1_04

/// A slow, thread-safe "disk" (don't edit).
public final class FakeDisk: Sendable {
    private let notes = Locked<[String]>([])
    public init() {}

    public func write(_ note: String) async {
        await suspend(ms: 30)
        notes.withLock { $0.append(note) }
    }

    public var all: [String] { notes.value }
}

public final class NotesStore: Sendable {
    public let disk: FakeDisk

    public init(disk: FakeDisk) {
        self.disk = disk
    }

    /// Saves a note. When `await save(...)` returns, the note MUST be on disk.
    ///
    /// BUG: "fire and forget". The Task is started and `save` returns immediately.
    /// The caller thinks the note is saved; it isn't (yet). Errors would be lost too.
    /// TODO: fix it.
    public func save(_ note: String) async {
        // We're already async: just await. No Task needed.
        // Creating a Task inside an async function is almost always a smell —
        // it breaks the "when I return, the work is done" contract (and loses errors + cancellation).
        await disk.write(note)
    }

    /// Kicks off saving `note` WITHOUT waiting for it, and returns a handle to that work.
    /// The handle's value is the number of notes on disk once this note has been written.
    /// The caller decides when (or whether) to await it.
    ///
    /// TODO: return a Task that writes the note and then produces `disk.all.count`.
    public func startSaving(_ note: String) -> Task<Int, Never> {
        // A sync function that wants async work done "in the background" creates a Task.
        // Returning the handle keeps the caller in control: await `.value`, or `cancel()`.
        Task {
            await disk.write(note)
            return disk.all.count
        }
    }
}
