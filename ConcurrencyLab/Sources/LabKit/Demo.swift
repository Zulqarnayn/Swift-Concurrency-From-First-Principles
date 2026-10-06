/// One runnable lesson demo. Registered in `Demos/Registry.swift`, run via `swift run lab <id>`.
public struct Demo: Sendable {
    public let id: String
    public let title: String
    /// Opt-in demos (crashes, deadlocks) only run when you type their exact id.
    public let optIn: Bool
    public let body: @Sendable () async throws -> Void

    public init(_ id: String, _ title: String, optIn: Bool = false, _ body: @escaping @Sendable () async throws -> Void) {
        self.id = id
        self.title = title
        self.optIn = optIn
        self.body = body
    }
}
