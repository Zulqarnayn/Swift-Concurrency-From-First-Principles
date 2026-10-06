// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: actor  | @unchecked | nonisolated(unsafe) | @preconcurrency | Sendable | Task.detached
//
// P2.15 — Non-Sendable first design.
//   scripts/fixme.sh ConcurrencyLab/Fixme/P2_15_nonsendable_first.swift
// This design reached for actors first: a stateless "formatter actor" and a "store actor".
// Every call now crosses an isolation boundary, so `Draft` (a mutable class) can't go anywhere.
// Redesign WITHOUT any custom actor (FORBID: "actor "), without Sendable, without escape hatches.
// Keep EditorModel @MainActor and keep its public methods' signatures.

final class Draft {
    var title: String
    var body: String
    init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

actor DraftFormatter {
    func preview(_ draft: Draft) -> String { "\(draft.title): \(draft.body.prefix(20))" }
}

actor DraftStore {
    private var drafts: [Draft] = []
    func add(_ draft: Draft) { drafts.append(draft) }
    func all() -> [Draft] { drafts }
}

@MainActor
final class EditorModel {
    private let store = DraftStore()
    private let formatter = DraftFormatter()
    var preview = ""

    func save(_ draft: Draft) async {
        await store.add(draft)
        preview = await formatter.preview(draft)
    }

    func titles() async -> [String] {
        await store.all().map(\.title)
    }
}
