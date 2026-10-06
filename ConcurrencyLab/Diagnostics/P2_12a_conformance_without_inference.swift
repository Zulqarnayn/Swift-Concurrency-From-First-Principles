// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: conformance of 'ProfileModel' to protocol 'Describable' crosses into main actor-isolated code and can cause data races
//
// Lesson P2.12. A @MainActor type conforms to a plain protocol — WITHOUT InferIsolatedConformances
// (Swift 6.0/6.1 behavior, or a target without "Approachable Concurrency").
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_12a_conformance_without_inference.swift

protocol Describable { func describe() -> String }

@MainActor final class ProfileModel: Describable {
    var name = "Ada"
    func describe() -> String { name }
}
