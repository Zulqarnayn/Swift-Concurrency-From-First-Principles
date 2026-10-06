import Dispatch

// P0.07 — SOLUTION

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
    public static func loadProfile(
        id: String,
        callbackQueue: DispatchQueue,
        completion: @escaping @Sendable (Result<Profile, ProfileError>) -> Void
    ) {
        // One funnel for every exit path: always the right queue, and easy to audit "exactly once".
        let finish: @Sendable (Result<Profile, ProfileError>) -> Void = { result in
            callbackQueue.async { completion(result) }
        }

        guard !id.isEmpty else {
            finish(.failure(.invalidID))   // fix 1: early exit must still call back
            return
        }
        FakeNetwork.get("/users/\(id)") { result in
            switch result {                // fix 2: switch = exactly one branch runs (no fall-through)
            case .failure(let error):
                finish(.failure(error))
            case .success(let name):
                finish(.success(Profile(id: id, name: name))) // fix 3: success goes to callbackQueue too
            }
        }
    }
}
