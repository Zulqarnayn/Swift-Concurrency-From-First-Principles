// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency
//
// P2.06 — Sendable. Make this compile with zero errors and warnings:
//   scripts/fixme.sh ConcurrencyLab/Fixme/P2_06_make_it_sendable.swift
// Rules: no escape hatches (see FORBID). Change the TYPES, not the logic in run().
// Each type has a different right answer. Ask: is it a value? immutable? shared AND mutable?

import Foundation

/// A snapshot of settings that gets handed to background work. Nobody mutates it after creation.
class AppSettings {
    var userName: String
    var fontSize: Int
    init(userName: String, fontSize: Int) {
        self.userName = userName
        self.fontSize = fontSize
    }
}

/// Shared by many tasks, and mutated by all of them.
final class HitCounter {
    private(set) var hits = 0
    func record() { hits += 1 }
}

/// A report that is passed around between tasks.
struct Report {
    let title: String
    let settings: AppSettings
}

func run() async {
    let settings = AppSettings(userName: "ada", fontSize: 14)
    let counter = HitCounter()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<10 {
            group.addTask {
                _ = settings.userName
                counter.record()
            }
        }
    }

    let report = Report(title: "Weekly", settings: settings)
    let pages = await Task.detached { report.title.count + report.settings.fontSize }.value
    print(pages)
}
