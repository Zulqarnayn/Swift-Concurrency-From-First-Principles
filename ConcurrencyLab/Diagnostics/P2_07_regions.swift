// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: sending 'r' risks causing data races
// EXPECT: error: sending 'report' risks causing data races
//
// Lesson P2.07. Region-based isolation: sending NON-Sendable values. Which functions compile?
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_07_regions.swift

final class Report { var lines: [String] = [] }
actor Archive { func store(_ r: Report) {} }

func a(_ archive: Archive) async {        // fresh object, never used after sending
    let r = Report()
    r.lines.append("draft")
    await archive.store(r)
}

func b(_ archive: Archive) async {        // fresh object, used after sending
    let r = Report()
    await archive.store(r)
    print(r.lines)
}

func c(_ archive: Archive, report: Report) async {           // a parameter: the caller may still hold it
    await archive.store(report)
}

func d(_ archive: Archive, report: sending Report) async {   // a 'sending' parameter
    await archive.store(report)
}

func makeReport() -> sending Report { Report() }              // a 'sending' result
