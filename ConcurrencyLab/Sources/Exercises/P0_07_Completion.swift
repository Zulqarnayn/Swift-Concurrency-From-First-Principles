import Dispatch

// P0.07 — Blocking vs suspending; completion-handler failure modes
// Lesson: lessons/P0-foundations/07-blocking-vs-suspending.md
// Test:   swift test --filter P0_07

public enum ProfileError: Error, Equatable, Sendable {
    case invalidID
    case network
}

public struct Profile: Equatable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A fake network. Calls back ~10ms later on some background thread. Don't edit.
public enum FakeNetwork {
    public static func get(_ path: String, completion: @escaping @Sendable (Result<String, ProfileError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(10)) {
            if path.contains("offline") {
                completion(.failure(.network))
            } else {
                completion(.success("Name-\(path.split(separator: "/").last ?? "")"))
            }
        }
    }
}

public enum P0_07 {
    /// CONTRACT: `completion` is called EXACTLY ONCE, and ALWAYS on `callbackQueue`.
    ///   - empty id          → .failure(.invalidID)
    ///   - id containing "offline" → .failure(.network)
    ///   - otherwise         → .success(Profile(id: id, name: "Name-<id>"))
    ///
    /// The code below breaks the contract in THREE ways. The compiler accepts all of them.
    /// TODO: find and fix all three.
    public static func loadProfile(
        id: String,
        callbackQueue: DispatchQueue,
        completion: @escaping @Sendable (Result<Profile, ProfileError>) -> Void
    ) {
        guard !id.isEmpty else {
            return
        }
        FakeNetwork.get("/users/\(id)") { result in
            if case .failure(let error) = result {
                callbackQueue.async { completion(.failure(error)) }
            }
            let name = (try? result.get()) ?? "unknown"
            completion(.success(Profile(id: id, name: name)))
        }
    }
}
