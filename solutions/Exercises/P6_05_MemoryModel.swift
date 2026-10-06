// P6.05 — SOLUTION. The memory model: happens-before
// Lesson: lessons/P6-internals/05-memory-model.md
// Test:   swift test --filter P6_05
//
// In each scenario, A writes `x = 1` (a plain, non-atomic variable), then B reads x.
// Is B GUARANTEED to see 1? (Not "will it usually" — is it guaranteed by the memory model?)

public enum Visibility: Equatable, Sendable { case guaranteed, notGuaranteed, unset }

public enum P6_05 {
    /// 1. A writes x, then unlocks mutex M. Later B locks M and reads x.
    public static let q1: Visibility = .guaranteed
    /// 2. A writes x, then sets an Atomic flag with `.relaxed`. B loads the flag with `.relaxed`, sees 1, reads x.
    public static let q2: Visibility = .notGuaranteed
    /// 3. Same as 2, but A stores the flag with `.releasing` and B loads it with `.acquiring`.
    public static let q3: Visibility = .guaranteed
    /// 4. A writes x inside an actor method. Later, B (another task) calls a method on the same actor that reads x.
    public static let q4: Visibility = .guaranteed
    /// 5. A submits `queue.async { x = 1 }` to a serial queue; afterwards B submits `queue.sync { read x }` to it.
    public static let q5: Visibility = .guaranteed
    /// 6. A writes x, then calls `continuation.resume()`. B is the task awaiting that continuation; it reads x after resuming.
    public static let q6: Visibility = .guaranteed
    /// 7. A writes a plain global var on one thread. B reads it on another thread, without any synchronization, one full second later.
    public static let q7: Visibility = .notGuaranteed
    /// 8. A writes x, then creates `Task { read x }` (B is that task).
    public static let q8: Visibility = .guaranteed
}
