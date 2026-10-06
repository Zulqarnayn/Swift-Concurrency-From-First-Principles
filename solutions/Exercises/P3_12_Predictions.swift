// P3.12 — SOLUTION. Review: structured concurrency output puzzles
// Lesson:  lessons/P3-structured/12-review.md
// Puzzles: Sources/Puzzles/StructuredPuzzles.swift   (read; don't run yet)
// Test:    swift test --filter P3_12

public enum P3_12 {
    public static let puzzle1: [String] = ["body", "child cancelled", "after scope"]
    public static let puzzle2: [String] = ["B", "C", "A"]
    public static let puzzle3: [String] = ["slow done", "caught"]
    public static let puzzle4: [String] = ["async let cancelled", "Task{} done"]
    public static let puzzle5: [String] = ["onCancel", "operation"]
    public static let puzzle6: [String] = ["ada", "anonymous", "ada", "anonymous"]
}
