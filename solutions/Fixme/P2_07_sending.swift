// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: Sendable | @unchecked | nonisolated(unsafe) | @preconcurrency
//
// P2.07 — SOLUTION

final class Report {
    var lines: [String] = []
}

actor Archive {
    private var reports: [Report] = []
    func store(_ report: Report) { reports.append(report) }
    func count() -> Int { reports.count }
}

/// 1. `sending`: the CALLER promises to give up the report. Now forwarding it is provably safe,
///    and the compiler checks every call site instead (a caller that keeps using it gets the error).
func submit(_ report: sending Report, to archive: Archive) async {
    await archive.store(report)
}

/// 2. Read what you need BEFORE handing the report over. After `store`, it belongs to the archive.
func publishQuarterly(to archive: Archive) async {
    let report = Report()
    report.lines.append("Q3 revenue")
    let lineCount = report.lines.count
    await archive.store(report)
    print("stored report with \(lineCount) lines")
}

/// 3. `current` is owned by the main actor and stays reachable from it, so it can never be sent.
///    Send a fresh copy instead: a brand-new object in its own region, unreachable from anything else.
@MainActor
final class Editor {
    var current = Report()

    func publish(to archive: Archive) async {
        let snapshot = Report()
        snapshot.lines = current.lines // [String] is a value: copied, nothing shared
        await archive.store(snapshot)
    }
}
