import LabKit
import Observation
import SwiftUI

// P4.06 — Search-as-you-type. Toggle debounce off and type fast: watch requests pile up and
// slow (short-query) responses overwrite newer ones. Toggle it on: one request per pause, never stale.
// (Spoiler for exercise P4_06 — do that first.)

nonisolated enum FakeSearchServer {
    /// Shorter queries match more rows → slower. That's what lets OLD responses arrive LAST.
    @concurrent static func search(_ query: String) async throws -> [String] {
        try await Task.sleep(for: .milliseconds(450 - min(query.count, 5) * 70))
        return (1...4).map { "\(query) · result \($0)" }
    }
}

@Observable
final class SearchLabModel {
    var debounce = false
    private(set) var results: [String] = []
    private(set) var showingResultsFor = ""
    private(set) var requests = 0
    private var pending: Task<Void, Never>?

    func queryChanged(_ query: String) {
        trace("⌨️  '\(query)'")
        guard !query.isEmpty else { return }
        if debounce {
            pending?.cancel()
            pending = Task {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    try await search(query)
                } catch {
                    trace("   ✂️ '\(query)' cancelled")
                }
            }
        } else {
            Task { try? await search(query) } // nobody owns this task: nobody cancels it
        }
    }

    private func search(_ query: String) async throws {
        requests += 1
        trace("🌐 request '\(query)'")
        let found = try await FakeSearchServer.search(query)
        if debounce { try Task.checkCancellation() }
        results = found
        showingResultsFor = query
        trace("🖥  screen now shows results for '\(query)'")
    }
}

struct SearchLab: View {
    var autorun = false
    @State private var model = SearchLabModel()
    @State private var query = ""
    private let log = TraceLog.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Debounce (300ms) + cancel previous", isOn: $model.debounce)
            TextField("Type fast…", text: $query)
                .textFieldStyle(.roundedBorder)
                .onChange(of: query) { _, newValue in model.queryChanged(newValue) }
            HStack {
                Text("requests: \(model.requests)")
                Spacer()
                Text("showing: '\(model.showingResultsFor)'")
                    .foregroundStyle(model.showingResultsFor == query || query.isEmpty ? Color.primary : Color.red)
            }
            .font(.caption.monospaced())
            ForEach(model.results, id: \.self) { Text($0).font(.caption) }
            TraceConsole(lines: log.lines)
        }
        .padding()
        .navigationTitle("P4.06 · Debounced search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            log.clear()
            if autorun { runScript() }
        }
    }

    /// Types "swift" quickly twice: debounce off, then on.
    private func runScript() {
        Task {
            for debounce in [false, true] {
                model.debounce = debounce
                trace("── debounce \(debounce ? "ON" : "OFF"): typing 'swift', 60ms per key ──")
                query = ""
                for count in 1...5 {
                    query = String("swift".prefix(count))
                    try? await Task.sleep(for: .milliseconds(60))
                }
                try? await Task.sleep(for: .milliseconds(900))
                trace("■ typed 'swift'; screen shows '\(model.showingResultsFor)'; total requests so far \(model.requests)")
            }
        }
    }
}
