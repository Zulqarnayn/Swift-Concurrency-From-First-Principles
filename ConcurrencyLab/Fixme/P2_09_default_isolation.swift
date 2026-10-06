// FLAGS: -swift-version 6 -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency | MainActor.run | Task.detached | @MainActor
//
// P2.09 — MainActor by default. This file is compiled like a NEW Xcode 26 app target:
// everything below is implicitly @MainActor.
//   scripts/fixme.sh ConcurrencyLab/Fixme/P2_09_default_isolation.swift
// Goal: JSON decoding must happen OFF the main actor (it's in a @concurrent function — keep it there).
// Fix the errors by opting the right declarations OUT of the default isolation. Smallest change wins.

import Foundation

struct User: Codable {
    let id: Int
    let fullName: String
}

func makeDecoder() -> JSONDecoder {
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

final class UserListModel {
    var users: [User] = []

    func load(_ data: Data) async throws {
        users = try await UserAPI.decodeUsers(data)
    }
}
