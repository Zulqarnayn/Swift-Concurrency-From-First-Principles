// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances
// EXPECT: error: main actor-isolated conformance of 'ProfileModel' to 'Describable' cannot be used in nonisolated context
// EXPECT: error: main actor-isolated conformance of 'ProfileModel' to 'Describable' cannot satisfy conformance requirement for a 'Sendable' type parameter
//
// Lesson P2.12. Same type WITH InferIsolatedConformances (Swift 6.2 / Xcode 26 approachable concurrency):
// the declaration compiles — the conformance is inferred @MainActor. Where can it be USED?
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_12b_isolated_conformance_usage.swift

protocol Describable { func describe() -> String }

@MainActor final class ProfileModel: Describable {
    var name = "Ada"
    func describe() -> String { name }
}

func printAll(_ items: [any Describable]) { for i in items { print(i.describe()) } }

@MainActor func onMain(_ m: ProfileModel) { printAll([m]) }                  // 1. used on the main actor
@concurrent func offMain(_ m: ProfileModel) async { printAll([m]) }          // 2. used in @concurrent code
func generic<T: Describable & Sendable>(_ t: T) async { _ = t.describe() }
@MainActor func viaGeneric(_ m: ProfileModel) async { await generic(m) }    // 3. passed where Sendable is required
