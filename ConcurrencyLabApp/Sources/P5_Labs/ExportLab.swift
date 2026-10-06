import Foundation
import LabKit
import SwiftUI

// P5.08 — "Tapping Export freezes the app." Watch the jank square and the stall meter, then profile it:
// Xcode → Product → Profile → Time Profiler (shows the Hangs track) or Swift Concurrency.
// (Spoiler for exercise P5_08 — do that first.)

nonisolated enum LabExporter {
    static func encode(_ count: Int) -> Data {
        burnCPU(ms: 250)
        return Data(count: count)
    }

    static func compress(_ data: Data) async -> Data { // plain async: runs on the CALLER's actor
        burnCPU(ms: 250)
        return data
    }

    @concurrent static func encodeAndCompress(_ count: Int) async -> Data {
        await compress(encode(count))
    }
}

struct ExportLab: View {
    var autorun = false
    @State private var status = "Idle"
    @State private var stall = StallMeter()
    private let log = TraceLog.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                JankIndicator()
                Text("worst stall: \(stall.worstStallMs)ms")
                    .monospacedDigit()
                    .foregroundStyle(stall.worstStallMs > 100 ? .red : .secondary)
            }
            Text(status)
            Button("Export (buggy: work runs on the main actor)") { Task { await exportOnMain() } }
            Button("Export (fixed: @concurrent helper)") { Task { await exportOffMain() } }
            Text("Profile it: Product → Profile → Time Profiler. Find the Hangs lane, select the hang, and read the heaviest stack trace. You'll land in LabExporter.encode/compress on the main thread.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TraceConsole(lines: log.lines)
        }
        .padding()
        .navigationTitle("P5.08 · Main-thread hang")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { stall.start() }
        .onDisappear { stall.stop() }
        .task {
            guard autorun else { return }
            log.clear()
            try? await Task.sleep(for: .milliseconds(300))
            for buggy in [true, false] {
                stall.reset()
                if buggy { await exportOnMain() } else { await exportOffMain() }
                try? await Task.sleep(for: .milliseconds(100))
                trace("■ \(buggy ? "buggy" : "fixed") export: worst main-thread stall \(stall.worstStallMs)ms")
            }
        }
    }

    private func exportOnMain() async {
        status = "Exporting…"
        trace("export (buggy): encode on main…")
        let encoded = LabExporter.encode(1_000)
        let compressed = await LabExporter.compress(encoded)
        status = "Exported \(compressed.count) bytes"
        trace("export (buggy): done")
    }

    private func exportOffMain() async {
        status = "Exporting…"
        trace("export (fixed): handing off to @concurrent…")
        let compressed = await LabExporter.encodeAndCompress(1_000)
        status = "Exported \(compressed.count) bytes"
        trace("export (fixed): done")
    }
}
