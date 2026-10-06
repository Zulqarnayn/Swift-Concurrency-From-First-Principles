// P5.10 — SOLUTION (evidence for each in the lesson spoiler). Crash forensics: read the crash, name the cause
// Lesson: lessons/P5-bug-zoo/10-crash-forensics.md
// Test:   swift test --filter P5_10
//
// Run each opt-in demo (they crash on purpose), read what the process prints / how it dies,
// and WITHOUT reading the demo source first, name the cause.

public enum CrashCause: Equatable, Sendable {
    case heapCorruptionFromDataRace        // concurrent mutation of a non-thread-safe value
    case dispatchSyncOntoOwnQueue          // sync onto the serial queue you're already on
    case recursiveLock                     // re-locking a non-recursive lock on the same thread
    case continuationResumedTwice
    case assumeIsolatedWrong               // MainActor.assumeIsolated when not on the main actor
    case preconcurrencyConformanceOffActor // a @preconcurrency conformance's runtime check failed
    case dynamicIsolationCheck             // an isolated closure was called on the wrong executor by unchecked code
    case cooperativePoolDeadlock           // every pool thread blocked; a watchdog killed it
    case unknown
}

public enum P5_10 {
    public static let p0_02b: CrashCause = .heapCorruptionFromDataRace
    public static let p0_05b: CrashCause = .dispatchSyncOntoOwnQueue
    public static let p0_05c: CrashCause = .recursiveLock
    public static let p1_03c: CrashCause = .cooperativePoolDeadlock
    public static let p1_05c: CrashCause = .continuationResumedTwice
    public static let p2_05c: CrashCause = .assumeIsolatedWrong
    public static let p2_12c: CrashCause = .preconcurrencyConformanceOffActor
    public static let p2_13c: CrashCause = .dynamicIsolationCheck
    public static let p4_04c: CrashCause = .cooperativePoolDeadlock
}
