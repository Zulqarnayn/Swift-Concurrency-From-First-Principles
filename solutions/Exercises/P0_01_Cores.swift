// P0.01 — SOLUTION

public enum P0_01 {
    public static func wallTimeMs(tasks: Int, taskMs: Int, cores: Int) -> Int {
        // Work happens in "rounds": each round runs up to `cores` tasks side by side.
        // Rounds needed = ceil(tasks / cores). Integer ceil without floating point:
        let rounds = (tasks + cores - 1) / cores
        return rounds * taskMs
    }

    public static func amdahlSpeedup(parallelFraction p: Double, cores n: Int) -> Double {
        // Time on 1 core = 1.  Time on n cores = serial part + parallel part / n.
        // Speedup = 1 / ((1 - p) + p / n).  As n → ∞, speedup → 1 / (1 - p).
        1.0 / ((1.0 - p) + p / Double(n))
    }
}
