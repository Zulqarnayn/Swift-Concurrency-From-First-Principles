// P6.03 — SOLUTION. The runtime: what do tasks and hops cost?
// Lesson: lessons/P6-internals/03-runtime-costs.md
// Test:   swift test --filter P6_03     (MEASURES this machine and grades your estimates)

public enum MemoryBucket: Equatable, Sendable {
    case under256Bytes, from256BytesTo4KB, from4KBTo64KB, over64KB, unset
}

public enum TimeBucket: Equatable, Sendable {
    case under100ns, from100nsTo100us, from100usTo10ms, over10ms, unset
}

public enum Ratio: Equatable, Sendable {
    case cheaper, aboutTheSame, from3xTo30x, over30x, unset
}

public enum P6_03 {
    /// Resident memory per task that is SUSPENDED (waiting on a continuation).
    public static let suspendedTaskMemory: MemoryBucket = .from256BytesTo4KB
    /// Virtual stack space reserved for each secondary Thread on Apple platforms.
    public static let threadStackReservation: MemoryBucket = .over64KB
    /// Creating a `Task { }` and awaiting its (empty) result.
    public static let taskCreateAndAwait: TimeBucket = .from100nsTo100us
    /// From a background task: `await` a @MainActor function and come back (one round trip).
    public static let mainActorRoundTrip: TimeBucket = .from100nsTo100us
    /// How much more does that MainActor round trip cost than calling an idle custom actor from the pool?
    public static let mainHopVersusActorCall: Ratio = .over30x
}
