import LabKit
import Observation
import SwiftUI

// P5.03 — Pagination bugs you can SEE. Toggle "fixed" off and scroll fast / refresh mid-load:
// duplicate rows and rows from the old feed. (Spoiler for exercise P5_03 — do that first.)

nonisolated enum FakeFeedAPI {
    @concurrent static func page(_ n: Int) async throws -> [String] {
        try await Task.sleep(for: .milliseconds(n == 2 ? 600 : 250))
        return (0..<8).map { "page \(n) · post \($0)" }
    }
}

@Observable
final class FeedLabModel {
    var fixed = false
    private(set) var posts: [String] = []
    private var nextPage = 1
    private var loading: Task<Void, Never>?
    private var generation = 0

    var duplicates: Int { posts.count - Set(posts).count }

    func loadNextPage() async {
        trace("📜 near the bottom → loadNextPage (next = \(nextPage))")
        if fixed, let loading {
            await loading.value
            return
        }
        let page = nextPage
        let generation = self.generation
        let task = Task {
            guard let items = try? await FakeFeedAPI.page(page) else { return }
            if fixed, generation != self.generation || Task.isCancelled {
                trace("🗑  dropped stale page \(page)")
                return
            }
            posts += items
            nextPage = page + 1
            trace("➕ appended page \(page) → \(posts.count) rows, \(duplicates) duplicates")
        }
        loading = task
        await task.value
        if generation == self.generation { loading = nil }
    }

    func refresh() async {
        trace("🔄 pull-to-refresh")
        if fixed {
            loading?.cancel()
            loading = nil
            generation += 1
        }
        posts = []
        nextPage = 1
        await loadNextPage()
    }
}

struct FeedLab: View {
    var autorun = false
    @State private var model = FeedLabModel()
    private let log = TraceLog.shared

    var body: some View {
        VStack(spacing: 8) {
            Toggle("Fixed (single-flight + generation check)", isOn: $model.fixed)
            HStack {
                Button("Fast scroll (3 triggers)") { Task { await fastScroll() } }
                Button("Refresh mid-load") { Task { await refreshMidLoad() } }
            }
            .buttonStyle(.bordered)
            Text("\(model.posts.count) rows · \(model.duplicates) duplicates")
                .font(.caption.monospaced())
                .foregroundStyle(model.duplicates > 0 ? .red : .secondary)
            List(Array(model.posts.enumerated()), id: \.offset) { _, post in
                Text(post).font(.caption)
            }
            .refreshable { await model.refresh() }
            .frame(maxHeight: 220)
            TraceConsole(lines: log.lines)
        }
        .padding()
        .navigationTitle("P5.03 · Pagination bugs")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadNextPage() }
        .task {
            guard autorun else { return }
            log.clear()
            for fixed in [false, true] {
                model.fixed = fixed
                trace("── fixed = \(fixed) ──")
                await model.refresh()
                await fastScroll()
                await refreshMidLoad()
                try? await Task.sleep(for: .milliseconds(800))
                trace("■ fixed=\(fixed): \(model.posts.count) rows, \(model.duplicates) duplicates, first page \(model.posts.first ?? "-")")
            }
        }
    }

    private func fastScroll() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 { group.addTask { await model.loadNextPage() } }
        }
    }

    /// Start loading the (slow) next page, then pull-to-refresh before it arrives.
    private func refreshMidLoad() async {
        let scroll = Task { await model.loadNextPage() }
        try? await Task.sleep(for: .milliseconds(100))
        await model.refresh()
        await scroll.value
    }
}
