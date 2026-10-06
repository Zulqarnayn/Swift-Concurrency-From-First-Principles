// P0.01 — Threads, cores, concurrency vs parallelism
// Lesson: lessons/P0-foundations/01-threads-cores.md
// Test:   swift test --filter P0_01

public enum P0_01 {
    /// `tasks` equal CPU-bound jobs of `taskMs` each, on `cores` cores.
    /// Assume perfect scheduling and zero overhead. How long does the whole batch take?
    ///
    ///     wallTimeMs(tasks: 8, taskMs: 100, cores: 4) == 200
    public static func wallTimeMs(tasks: Int, taskMs: Int, cores: Int) -> Int {
        // TODO
        return 0
    }

    /// Amdahl's law. A fraction `parallelFraction` (0...1) of a program can run in parallel,
    /// the rest must run serially. What is the best possible speedup on `cores` cores
    /// compared to one core?
    ///
    ///     amdahlSpeedup(parallelFraction: 0.5, cores: 2) ≈ 1.333
    public static func amdahlSpeedup(parallelFraction: Double, cores: Int) -> Double {
        // TODO
        return 0
    }
}
