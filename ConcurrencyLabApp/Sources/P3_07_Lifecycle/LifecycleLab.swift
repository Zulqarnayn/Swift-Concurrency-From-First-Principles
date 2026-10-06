import LabKit
import SwiftUI

// P3.07 — Who cancels your task when the view goes away?
//
// Two child views run the same polling loop. One starts it with `.task`, the other with
// `onAppear { Task { } }`. Hide them and watch the trace: which loop keeps running?
// A third view uses `.task(id:)`: changing the id cancels the old task and starts a new one.

struct LifecycleLab: View {
    var autorun = false

    @State private var showChildren = true
    @State private var queryID = 1
    private let log = TraceLog.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Show child views", isOn: $showChildren)
            if showChildren {
                TaskModifierChild()
                OnAppearTaskChild()
            }
            HStack {
                Text(".task(id: \(queryID))")
                Spacer()
                Button("Change id") { queryID += 1 }
            }
            .task(id: queryID) {
                let id = queryID
                trace("🔁 .task(id: \(id)) started")
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    trace("🔁 .task(id: \(id)) cancelled")
                }
            }
            TraceConsole(lines: log.lines)
        }
        .padding()
        .navigationTitle("P3.07 · Task lifecycle")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            log.clear()
            if autorun { runScript() }
        }
    }

    private func runScript() {
        Task {
            try? await Task.sleep(for: .milliseconds(1_000))
            trace("── hiding both child views ──")
            showChildren = false
            try? await Task.sleep(for: .milliseconds(1_000))
            trace("── changing the .task id ──")
            queryID += 1
            try? await Task.sleep(for: .milliseconds(300))
            trace("■ done")
        }
    }
}

private struct TaskModifierChild: View {
    var body: some View {
        Label(".task { polling loop }", systemImage: "checkmark.circle")
            .task {
                var tick = 0
                do {
                    while true {
                        tick += 1
                        trace("✅ .task tick \(tick)")
                        try await Task.sleep(for: .milliseconds(300))
                    }
                } catch {
                    trace("✅ .task cancelled after \(tick) ticks (view disappeared)")
                }
            }
    }
}

private struct OnAppearTaskChild: View {
    var body: some View {
        Label("onAppear { Task { polling loop } }", systemImage: "exclamationmark.triangle")
            .onAppear {
                Task {
                    // Nobody holds this task, so nobody can cancel it. It outlives the view.
                    // (Capped at 20 ticks so the lab doesn't poll forever.)
                    for tick in 1...20 {
                        trace("⚠️ onAppear Task tick \(tick)")
                        try? await Task.sleep(for: .milliseconds(300))
                    }
                }
            }
    }
}
