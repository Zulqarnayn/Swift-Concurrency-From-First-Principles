// FLAGS: -swift-version 6 -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances
// EXPECT: error: main actor-isolated conformance of 'User' to 'Decodable' cannot be used in nonisolated context
//
// Lesson P2.09. A new Xcode 26 app target. Why can't a @concurrent function decode this struct?
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_09_decodable.swift

import Foundation

struct User: Decodable { let name: String }

enum API {
    @concurrent static func decodeUser(_ data: Data) async throws -> User {
        try JSONDecoder().decode(User.self, from: data)
    }
}
