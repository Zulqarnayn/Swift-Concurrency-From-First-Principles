import Foundation
import LabKit

// P5.08 — SOLUTION. Bug hunt: "tapping Export freezes the app for a moment"
// Lesson: lessons/P5-bug-zoo/08-main-thread-hangs.md
// Repro:  swift run lab p5.08  (+ iOS lab P5.08)      Test: swift test --filter P5_08

public struct Note: Codable, Sendable, Equatable {
    public let title: String
    public let body: String
    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// Export helpers (don't edit the work they do — 100ms of CPU each — only WHERE it runs).
public enum Exporter {
    public static func encode(_ notes: [Note]) -> Data {
        burnCPU(ms: 100)
        return (try? JSONEncoder().encode(notes)) ?? Data()
    }

    public static func compress(_ data: Data) async -> Data {
        burnCPU(ms: 100)
        return data
    }
}

@MainActor
public final class ExportModel {
    public private(set) var status = "Idle"

    public init() {}

    /// Called from the Export button. The UI must stay responsive while it runs.
    public func export(_ notes: [Note]) async -> Data {
        status = "Exporting…"
        let compressed = await Self.encodeAndCompress(notes)
        status = "Exported \(notes.count) notes"
        return compressed
    }

    // ROOT CAUSE: both steps ran ON THE MAIN ACTOR.
    //  - `encode` is a synchronous call from a @MainActor function → runs right there, on main.
    //  - `compress` is a plain `async` func → nonisolated(nonsending) → runs on the CALLER's actor: main.
    //    "It's async, so it's in the background" is the misconception (P2.01, P2.08).
    // FIX: one @concurrent function that leaves the main actor and does both; `compress`, being nonsending,
    // now inherits THIS function's (background) executor. Only the status updates stay on main.
    @concurrent
    private static func encodeAndCompress(_ notes: [Note]) async -> Data {
        let encoded = Exporter.encode(notes)
        return await Exporter.compress(encoded)
    }
}
