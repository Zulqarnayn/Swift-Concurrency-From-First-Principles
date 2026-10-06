import LabKit

// P3.07 — Cancellation propagation and owning unstructured tasks
// Lesson: lessons/P3-structured/07-cancellation-propagation.md
// Test:   swift test --filter P3_07

/// Fake search backend (don't edit). Shorter queries are SLOWER (they match more), so responses
/// for older keystrokes can arrive AFTER newer ones.
public final class SearchAPI: Sendable {
    public let cancellations = CallCounter()
    public init() {}

    public func search(_ query: String) async throws -> [String] {
        do {
            try await Task.sleep(for: .milliseconds(max(10, 90 - query.count * 30)))
        } catch {
            cancellations.increment()
            throw error
        }
        return ["\(query)1", "\(query)2"]
    }
}

@MainActor
public final class SearchModel {
    public private(set) var results: [String] = []
    /// Every query whose results were shown, in order.
    public private(set) var shown: [String] = []
    private let api: SearchAPI

    public init(api: SearchAPI) {
        self.api = api
    }

    /// Called on every keystroke (synchronously, from the UI).
    ///
    /// BUG: every keystroke starts a search that nobody owns. Old searches keep running, and a slow
    /// old response can overwrite a newer one (stale results).
    /// TODO: a new keystroke cancels the previous search; a cancelled search never touches `results`.
    public func queryChanged(_ query: String) {
        Task {
            let found = (try? await api.search(query)) ?? []
            results = found
            shown.append(query)
        }
    }
}
