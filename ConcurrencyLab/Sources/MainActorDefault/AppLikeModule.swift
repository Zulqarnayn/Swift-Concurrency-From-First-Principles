import LabKit

// This module is compiled with `.defaultIsolation(MainActor.self)` — like a new Xcode 26 app target.
// Nothing below says @MainActor. Yet...

public final class Settings {             // implicitly @MainActor
    public var theme = "light"            // safe: only reachable on the main actor
    public init() {}
}

var launchCount = 0                       // a mutable GLOBAL that compiles in Swift 6 — it's @MainActor

public func recordLaunch() -> Int {       // implicitly @MainActor, so it may touch launchCount
    launchCount += 1
    return launchCount
}

public func freeFunctionIsolation() -> String {   // implicitly @MainActor
    isolationLabel()
}

public nonisolated func optedOutIsolation() -> String {
    isolationLabel()
}

@concurrent
public func concurrentHelper() async -> String {
    isMainThread() ? "MAIN" : "background"
}
