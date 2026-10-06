// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: call to main actor-isolated instance method 'rename()' in a synchronous nonisolated context
// EXPECT: error: main actor-isolated property 'title' can not be mutated from a Sendable closure
// EXPECT: error: main actor-isolated property 'title' can not be mutated from a nonisolated context
//
// Lesson P2.05. Where does @MainActor come from when you didn't write it?
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_05_inference.swift

import Foundation

@MainActor class BaseModel { var title = "" }

final class ChildModel: BaseModel {          // A. subclass of a @MainActor class
    func rename() { title = "child" }
}

func fromNonisolated(_ model: ChildModel) {
    model.rename()                           // B. call it from nonisolated sync code
}

@MainActor func closures(_ model: BaseModel) {
    let plain = { model.title = "plain closure" }                     // C. non-Sendable closure on main
    plain()
    let sendable: @Sendable () -> Void = { model.title = "sendable" } // D. @Sendable closure on main
    sendable()
    Task { model.title = "task" }                                     // E. Task {} on main
    Task.detached { model.title = "detached" }                        // F. Task.detached on main
}
