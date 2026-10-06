import Foundation
import Synchronization

// MARK: - trace()
//
// Prints:  [  +103ms] T3   | message
//          [  +104ms] MAIN | message
//
// T1, T2, ... are small stable numbers given to OS threads in the order we first see them.
// Remember: a thread is NOT an isolation domain. This is only an intuition tool.

public enum Trace {
    /// Resets the clock and thread numbering. The `lab` runner calls this before each demo.
    public static func reset() {
        TraceState.shared.reset()
    }

    /// Install a closure that receives every trace line (the iOS app uses this to show traces on screen).
    public static func setSink(_ sink: (@Sendable (String) -> Void)?) {
        TraceState.shared.setSink(sink)
    }

    /// Milliseconds since the last `reset()`.
    public static func elapsedMs() -> Int {
        TraceState.shared.elapsedMs()
    }
}

/// Print a line tagged with elapsed time and the current thread.
/// Synchronous on purpose: `Thread.current` is unavailable directly inside async functions,
/// but an ordinary sync function called from async code can still ask which thread it is on.
@discardableResult
public func trace(_ message: @autoclosure () -> String) -> String {
    let time = "+\(Trace.elapsedMs())ms"
    let thread = currentThreadLabel()
    let line = "[\(leftPad(time, 8))] \(rightPad(thread, 4)) | \(message())"
    TraceState.shared.emit(line)
    return line
}

private func leftPad(_ s: String, _ width: Int) -> String {
    String(repeating: " ", count: max(0, width - s.count)) + s
}

private func rightPad(_ s: String, _ width: Int) -> String {
    s + String(repeating: " ", count: max(0, width - s.count))
}

/// "MAIN" on the main thread, otherwise "T<n>".
public func currentThreadLabel() -> String {
    if pthread_main_np() != 0 { return "MAIN" }
    return "T\(TraceState.shared.number(for: currentThreadID()))"
}

/// Raw OS thread id. Use for counting distinct threads.
public func currentThreadID() -> UInt64 {
    var tid: UInt64 = 0
    pthread_threadid_np(nil, &tid)
    return tid
}

public func isMainThread() -> Bool {
    pthread_main_np() != 0
}

final class TraceState: Sendable {
    static let shared = TraceState()

    private struct State {
        var start = ContinuousClock.now
        var names: [UInt64: Int] = [:]
        var sink: (@Sendable (String) -> Void)?
    }

    private let state = Mutex(State())

    func reset() {
        state.withLock {
            $0.start = .now
            $0.names = [:]
        }
    }

    func setSink(_ sink: (@Sendable (String) -> Void)?) {
        state.withLock { $0.sink = sink }
    }

    func elapsedMs() -> Int {
        let start = state.withLock { $0.start }
        let d = ContinuousClock.now - start
        return Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000)
    }

    func number(for tid: UInt64) -> Int {
        state.withLock { s in
            if let n = s.names[tid] { return n }
            let n = s.names.count + 1
            s.names[tid] = n
            return n
        }
    }

    func emit(_ line: String) {
        // Lock around print so concurrent lines never interleave mid-line.
        let sink = state.withLock { s in
            print(line)
            fflush(stdout)
            return s.sink
        }
        sink?(line)
    }
}
