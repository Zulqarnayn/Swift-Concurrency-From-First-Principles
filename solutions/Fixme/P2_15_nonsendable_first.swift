// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: actor  | @unchecked | nonisolated(unsafe) | @preconcurrency | Sendable | Task.detached
//
// P2.15 — SOLUTION

final class Draft {
    var title: String
    var body: String
    init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// Had no state to protect → never needed to be an actor (Massicotte: "stateless actors" are a smell).
/// A plain value with a plain function.
struct DraftFormatter {
    func preview(_ draft: Draft) -> String { "\(draft.title): \(draft.body.prefix(20))" }
}

/// Non-Sendable, non-isolated class. It's owned by EditorModel, so it lives in the main actor's domain
/// and never crosses a boundary. Its async method (if it had I/O) would run on the OWNER's actor
/// thanks to nonisolated(nonsending) — which is what makes this design practical in Swift 6.2.
final class DraftStore {
    private var drafts: [Draft] = []
    func add(_ draft: Draft) async { drafts.append(draft) } // imagine: `await disk.write(...)` here
    func all() -> [Draft] { drafts }
}

@MainActor
final class EditorModel {
    private let store = DraftStore()
    private let formatter = DraftFormatter()
    var preview = ""

    func save(_ draft: Draft) async {
        await store.add(draft)                 // same isolation domain: no sending, no Sendable needed
        preview = formatter.preview(draft)     // synchronous: no actor hop at all
    }

    func titles() async -> [String] {
        store.all().map(\.title)
    }
}
