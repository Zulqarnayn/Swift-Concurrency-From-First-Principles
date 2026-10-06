// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency
//
// P2.06 — SOLUTION

import Foundation

/// A VALUE: make it a struct. Structs whose members are all Sendable are implicitly Sendable
/// (for non-public types; public ones should say `: Sendable` explicitly — it's part of the API).
/// (Also valid: `final class AppSettings: Sendable` with only `let` properties.)
struct AppSettings {
    var userName: String
    var fontSize: Int
}

/// SHARED + MUTABLE: protect the state. An actor serializes access; callers `await`.
/// (Also valid: a `final class: Sendable` holding a `Mutex<Int>` — keeps `record()` synchronous.)
actor HitCounter {
    private(set) var hits = 0
    func record() { hits += 1 }
}

/// Became Sendable automatically once AppSettings did: a struct of Sendable members.
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
                await counter.record() // crossing into the actor: `await`
            }
        }
    }

    let report = Report(title: "Weekly", settings: settings)
    let pages = await Task.detached { report.title.count + report.settings.fontSize }.value
    print(pages)
}
