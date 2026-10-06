/// Which isolation domain is the CALLER in? "MainActor", "nonisolated", or the actor's type name.
///
/// How it works: an `isolated` parameter makes the function run on that actor, and the default
/// argument `#isolation` is filled in at the call site with the caller's own actor (or nil).
/// This is the pre-Swift-6.2 way to "inherit the caller's isolation" (SE-0420). P2.02 / P2.10.
public func isolationLabel(_ isolation: isolated (any Actor)? = #isolation) -> String {
    guard let isolation else { return "nonisolated" }
    return String(describing: type(of: isolation))
}
