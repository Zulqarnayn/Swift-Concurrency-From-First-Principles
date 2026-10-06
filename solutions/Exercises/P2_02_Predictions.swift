// P2.02 — SOLUTION (explanations in the lesson spoiler). Isolation from first principles: the isolation map
// Lesson: lessons/P2-isolation/02-isolation-first-principles.md
// Code:   Sources/Puzzles/IsolationMap.swift   (read it; don't run it yet)
// Test:   swift test --filter P2_02
//
// For each call site a…i, what does `isolationLabel()` report there?
// Answer "MainActor", "nonisolated", or an actor's type name (e.g. "Ledger").

public enum P2_02 {
    public static let a = "MainActor"
    public static let b = "nonisolated"
    public static let c = "MainActor"
    public static let d = "nonisolated"
    public static let e = "Ledger"
    public static let f = "MainActor"
    public static let g = "nonisolated"
    public static let h = "nonisolated"
    public static let i = "Ledger"
}
