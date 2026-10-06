import LabKit

// P1.07 — Errors in async code, typed throws
// Lesson: lessons/P1-async-await/07-errors.md
// Test:   swift test --filter P1_07

public enum NetworkError: Error, Equatable, Sendable {
    case offline
    case notFound
    case timeout
}

public enum ProfileLoadError: Error, Equatable, Sendable {
    case offline
    case userNotFound
    case unknown
}

public struct UserProfile: Equatable, Sendable {
    public let name: String
    public let avatar: String
    public init(name: String, avatar: String) {
        self.name = name
        self.avatar = avatar
    }
}

/// Fake backend (don't edit).
public enum ProfileBackend {
    /// 1 → "Ada", 2 → "Linus", 0 → .offline, 408 → .timeout, anything else → .notFound
    public static func fetchName(id: Int) async throws(NetworkError) -> String {
        await suspend(ms: 5)
        switch id {
        case 1: return "Ada"
        case 2: return "Linus"
        case 0: throw .offline
        case 408: throw .timeout
        default: throw .notFound
        }
    }

    /// id 2 → .timeout, otherwise "avatar-<id>.png"
    public static func fetchAvatar(id: Int) async throws(NetworkError) -> String {
        await suspend(ms: 5)
        if id == 2 { throw .timeout }
        return "avatar-\(id).png"
    }
}

public enum P1_07 {
    /// Rules:
    ///  - name fails with .offline   → throw .offline
    ///  - name fails with .notFound  → throw .userNotFound
    ///  - name fails any other way   → throw .unknown
    ///  - avatar fails (any reason)  → DON'T fail; use "default.png"
    ///
    /// TODO: implement it. With typed throws, `error` inside `catch` is already a `NetworkError`:
    /// no casting, and the compiler checks your `switch` is exhaustive.
    public static func loadProfile(id: Int) async throws(ProfileLoadError) -> UserProfile {
        throw .unknown
    }
}
