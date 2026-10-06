import LabKit

// P2.02 — The isolation map. For each call site, what does `isolationLabel()` report?
// ("MainActor", "nonisolated", or an actor's type name like "Ledger")
// Predict in Exercises/P2_02_Predictions.swift, then:  swift test --filter P2_02   /   swift run lab p2.02

public actor Ledger {
    var entries: [String] = []

    func methodLabel() -> String { isolationLabel() }

    func taskCapturingSelf() async -> String {
        await Task {
            self.entries.append("x")
            return isolationLabel()
        }.value
    }

    func taskIgnoringSelf() async -> String {
        await Task { isolationLabel() }.value
    }
}

func plainSync() -> String { isolationLabel() }
func plainAsync() async -> String { isolationLabel() }
@concurrent func concurrentAsync() async -> String { isolationLabel() }

public enum IsolationMap {
    @MainActor public static func a() async -> String { isolationLabel() }                        // inside a @MainActor function
    @MainActor public static func b() async -> String { plainSync() }                             // plain SYNC func, called from main
    @MainActor public static func c() async -> String { await plainAsync() }                      // plain ASYNC func, called from main
    @MainActor public static func d() async -> String { await concurrentAsync() }                 // @concurrent func, called from main
    @MainActor public static func e() async -> String { await Ledger().methodLabel() }            // actor method
    @MainActor public static func f() async -> String { await Task { isolationLabel() }.value }   // Task {} created on main
    @MainActor public static func g() async -> String { await Task.detached { isolationLabel() }.value } // Task.detached
    @MainActor public static func h() async -> String { await Ledger().taskIgnoringSelf() }       // Task {} in an actor, not using self
    @MainActor public static func i() async -> String { await Ledger().taskCapturingSelf() }      // Task {} in an actor, using self

    public static let all: [(String, @MainActor () async -> String)] = [
        ("a", a), ("b", b), ("c", c), ("d", d), ("e", e), ("f", f), ("g", g), ("h", h), ("i", i),
    ]
}
