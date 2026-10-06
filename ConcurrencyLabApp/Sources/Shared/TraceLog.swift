import LabKit
import Observation

/// Collects every `trace(...)` line (from any thread) so the UI can show it.
///
/// Remember: everything in this app target is @MainActor by default — including this class.
@Observable
final class TraceLog {
    static let shared = TraceLog()

    private(set) var lines: [String] = []

    private init() {
        // trace() is called from many threads. We must get each line onto the main actor IN ORDER.
        // `Task { @MainActor in lines.append(line) }` per line would be the P1.08 bug (no ordering guarantee).
        // Instead: one AsyncStream + one consumer task = an async serial queue.
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        Trace.setSink { line in continuation.yield(line) }
        Task {
            for await line in stream {
                lines.append(line)
            }
        }
    }

    func clear() {
        lines.removeAll()
        Trace.reset()
    }
}
