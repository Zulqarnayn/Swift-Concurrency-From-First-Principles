import LabKit

// Compiled WITHOUT NonisolatedNonsendingByDefault: the Swift 6.0/6.1 rules.
// A plain `nonisolated async` function here ALWAYS runs on the global concurrent executor,
// no matter which actor called it.

public func legacyPlainAsync() async -> String {
    trace("  legacy module: plain async func")
    return isMainThread() ? "MAIN" : "background"
}

/// Opting IN to the new behavior explicitly works in any module (Swift 6.2+).
public nonisolated(nonsending) func legacyExplicitNonsending() async -> String {
    trace("  legacy module: explicitly nonisolated(nonsending)")
    return isMainThread() ? "MAIN" : "background"
}

/// A plain SYNC function runs on whatever thread calls it — in every module, under every rule.
public func legacyPlainSync() -> String {
    isMainThread() ? "MAIN" : "background"
}
