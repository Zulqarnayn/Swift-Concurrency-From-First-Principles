import LabKit

// P4.07 — SOLUTION. Single-flight: the token-refresh race
// Lesson: lessons/P4-classics/07-token-refresh.md
// Test:   swift test --filter P4_07

public struct Unauthorized: Error {}
public struct RefreshFailed: Error, Equatable {}

/// Fake auth server (don't edit).
///  - `fetch` succeeds only with the CURRENT token; anything else → Unauthorized (HTTP 401)
///  - `refresh` issues a new token and INVALIDATES the previous one (token rotation)
public final class FakeAuthServer: Sendable {
    private struct State { var generation = 1; var failRefresh = false }
    private let state = Locked(State())
    public let refreshCount = CallCounter()
    public init() {}

    public var currentToken: String { "t\(state.value.generation)" }

    public func setRefreshFails(_ fails: Bool) { state.withLock { $0.failRefresh = fails } }

    public func refresh() async throws -> String {
        refreshCount.increment()
        try await Task.sleep(for: .milliseconds(30))
        let newToken = state.withLock { s -> String? in
            if s.failRefresh { return nil }
            s.generation += 1
            return "t\(s.generation)"
        }
        guard let newToken else { throw RefreshFailed() }
        return newToken
    }

    public func fetch(_ path: String, token: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(5 + (path.count % 5) * 10)) // variable latency
        guard token == currentToken else { throw Unauthorized() }
        return "data:\(path)"
    }
}

public actor AuthClient {
    private let server: FakeAuthServer
    private var token: String
    private var refreshTask: Task<String, any Error>?

    /// Starts with an expired token, like an app resuming after a long background stay.
    public init(server: FakeAuthServer, token: String = "t0") {
        self.server = server
        self.token = token
    }

    /// Send a request. On 401: get a fresh token and retry ONCE.
    ///
    /// BUG: every caller that gets a 401 refreshes on its own. 10 concurrent requests → 10 refreshes,
    /// and because each refresh invalidates the previous token, most retries fail AGAIN.
    /// TODO: single-flight the refresh:
    ///  - concurrent callers needing a refresh all await ONE refresh
    ///  - a 401 for a token that has ALREADY been replaced must not trigger another refresh
    ///  - if the refresh fails, every waiter gets the error, and the NEXT call may refresh again
    public func send(_ path: String) async throws -> String {
        let used = token // remember WHICH token this request carried
        do {
            return try await server.fetch(path, token: used)
        } catch is Unauthorized {
            let fresh = try await validToken(replacing: used)
            return try await server.fetch(path, token: fresh) // retry once
        }
    }

    private func validToken(replacing stale: String) async throws -> String {
        // A late 401: someone already replaced the token this request used. Just use the new one.
        if token != stale { return token }

        // A refresh is in flight: join it (single-flight).
        if let running = refreshTask { return try await running.value }

        // We're first: start the refresh and publish it BEFORE suspending, so concurrent callers join it.
        let task = Task { try await server.refresh() }
        refreshTask = task
        defer { refreshTask = nil } // success or failure: the next 401 may start a new refresh
        let fresh = try await task.value // on failure, every joined waiter gets the same error
        token = fresh
        return fresh
    }
}
