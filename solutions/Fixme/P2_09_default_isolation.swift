// FLAGS: -swift-version 6 -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency | MainActor.run | Task.detached | @MainActor
//
// P2.09 — SOLUTION

import Foundation

/// `nonisolated`: a plain value type with no UI state has no reason to belong to the main actor.
/// Opting the TYPE out also makes its Codable conformance nonisolated, so it can be decoded anywhere.
nonisolated struct User: Codable {
    let id: Int
    let fullName: String
}

/// Pure helper: touches no shared state → nonisolated, callable from any isolation.
nonisolated func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
}

enum UserAPI {
    @concurrent
    static func decodeUsers(_ data: Data) async throws -> [User] {
        try makeDecoder().decode([User].self, from: data)
    }
}

/// Stays @MainActor (by default) — it's UI state. No change needed.
final class UserListModel {
    var users: [User] = []

    func load(_ data: Data) async throws {
        users = try await UserAPI.decodeUsers(data)
    }
}
