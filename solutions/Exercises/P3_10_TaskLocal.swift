import LabKit

// P3.10 — SOLUTION. @TaskLocal
// Lesson: lessons/P3-structured/10-task-locals.md
// Test:   swift test --filter P3_10

public enum RequestLog {
    @TaskLocal public static var requestID: String?

    /// Every log line is tagged with the current request id.
    public static func log(_ message: String, into log: EventLog) {
        log.add("[\(requestID ?? "none")] \(message)")
    }
}

public enum P3_10 {
    /// Handle one request. EVERY log line written while handling it — including from concurrent
    /// subtasks and the background audit write — must carry `requestID`.
    ///
    /// BUG: the id is never bound, and the audit write uses Task.detached.
    /// TODO: bind the task-local for the whole request; fix the audit line (keep it off the caller's task).
    public static func handle(requestID: String, log: EventLog) async {
        // Bind for the duration of the closure. Child tasks (async let, groups) and Task {} inherit it;
        // it's automatically unbound when the closure returns — it can't leak out.
        await RequestLog.$requestID.withValue(requestID) {
            await handleBound(log: log)
        }
    }

    private static func handleBound(log: EventLog) async {
        RequestLog.log("start", into: log)

        async let user: Void = RequestLog.log("loaded user", into: log)
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                group.addTask { RequestLog.log("loaded item \(i)", into: log) }
            }
        }
        await user

        // Task.detached inherits NO task-locals. Capture the value and re-bind it explicitly.
        // (Or ask whether it needs to be detached at all: a plain Task {} would inherit it.)
        let id = RequestLog.requestID
        await Task.detached {
            RequestLog.$requestID.withValue(id) {
                RequestLog.log("audit written", into: log)
            }
        }.value

        RequestLog.log("end", into: log)
    }
}
