import LabKit

// P3.02 — async let
// Lesson: lessons/P3-structured/02-async-let.md
// Test:   swift test --filter P3_02

public struct Dashboard: Equatable, Sendable {
    public let user: String
    public let news: [String]
    public let weather: String
    public init(user: String, news: [String], weather: String) {
        self.user = user
        self.news = news
        self.weather = weather
    }
}

public struct NewsUnavailable: Error, Equatable {}

/// Fake backend (don't edit). Every call is cancellation-aware and logs what happened.
public final class DashboardAPI: Sendable {
    public let log = EventLog()
    public let newsFails: Bool
    public init(newsFails: Bool = false) { self.newsFails = newsFails }

    private func call<T>(_ name: String, ms: Int, _ value: T) async throws -> T {
        do {
            try await Task.sleep(for: .milliseconds(ms))
        } catch {
            log.add("\(name) cancelled")
            throw error
        }
        log.add("\(name) done")
        return value
    }

    public func user() async throws -> String { try await call("user", ms: 100, "Ada") }

    public func news() async throws -> [String] {
        if newsFails {
            try await Task.sleep(for: .milliseconds(20))
            log.add("news failed")
            throw NewsUnavailable()
        }
        return try await call("news", ms: 100, ["Swift 6.2 ships"])
    }

    public func weather() async throws -> String { try await call("weather", ms: newsFails ? 400 : 100, "Sunny") }
}

public enum P3_02 {
    /// Load all three parts. They're independent: fetch them CONCURRENTLY.
    /// BUG: sequential. 300ms instead of 100ms. TODO: use `async let`.
    public static func loadDashboard(api: DashboardAPI) async throws -> Dashboard {
        let user = try await api.user()
        let news = try await api.news()
        let weather = try await api.weather()
        return Dashboard(user: user, news: news, weather: weather)
    }
}
