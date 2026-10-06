// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: Sendable | @unchecked | nonisolated(unsafe) | @preconcurrency
//
// P2.07 — `sending` and region-based isolation.
//   scripts/fixme.sh ConcurrencyLab/Fixme/P2_07_sending.swift
// Rule: `Report` must stay a non-Sendable class (FORBID includes the word Sendable).
// You may: add `sending`, reorder code, make copies. Make each error go away by making the code
// actually SAFE, i.e. no one can touch a Report after handing it to the archive.

final class Report {
    var lines: [String] = []
}

actor Archive {
    private var reports: [Report] = []
    func store(_ report: Report) { reports.append(report) }
    func count() -> Int { reports.count }
}

/// 1. Forwards a report it was given.
func submit(_ report: Report, to archive: Archive) async {
    await archive.store(report)
}

/// 2. Stores a report, then logs it.
func publishQuarterly(to archive: Archive) async {
    let report = Report()
    report.lines.append("Q3 revenue")
    await archive.store(report)
    print("stored report with \(report.lines.count) lines")
}

/// 3. A main-actor editor publishes its current document.
@MainActor
final class Editor {
    var current = Report()

    func publish(to archive: Archive) async {
        await archive.store(current)
    }
}
