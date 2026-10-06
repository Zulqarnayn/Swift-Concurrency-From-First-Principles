import Dispatch
import LabKit

// P1.09 — Lab: convert a GCD + completion-handler service to async/await
// Lesson: lessons/P1-async-await/09-lab-convert-gcd.md
// Test:   swift test --filter P1_09

public struct FeedUser: Equatable, Sendable {
    public let id: Int
    public let name: String
    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

public struct Post: Equatable, Sendable {
    public let id: Int
    public let title: String
    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}

public struct Feed: Equatable, Sendable {
    public let user: FeedUser
    public let posts: [Post]
    public let thumbnails: [Int: String] // post id → thumbnail URL
    public init(user: FeedUser, posts: [Post], thumbnails: [Int: String]) {
        self.user = user
        self.posts = posts
        self.thumbnails = thumbnails
    }
}

public enum FeedError: Error, Equatable, Sendable {
    case notLoggedIn
    case server
}

// MARK: - Callback-only backend (don't edit)

public enum FeedAPI {
    /// "" → .notLoggedIn. Any other token → user 7 "Ada".  Token "server-down" works here but breaks `posts`.
    public static func currentUser(token: String, completion: @escaping @Sendable (Result<FeedUser, FeedError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(5)) {
            token.isEmpty ? completion(.failure(.notLoggedIn)) : completion(.success(FeedUser(id: 7, name: token == "server-down" ? "Bob" : "Ada")))
        }
    }

    /// User "Bob" → .server. Otherwise three posts.
    public static func posts(for user: FeedUser, completion: @escaping @Sendable (Result<[Post], FeedError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(5)) {
            if user.name == "Bob" { return completion(.failure(.server)) }
            completion(.success([Post(id: 1, title: "Hello"), Post(id: 2, title: "Async"), Post(id: 3, title: "Await")]))
        }
    }

    /// Never fails.
    public static func thumbnail(postID: Int, completion: @escaping @Sendable (String) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(5)) {
            completion("https://img.example/\(postID).png")
        }
    }
}

// MARK: - The legacy implementation (works; read it, don't edit)

public enum LegacyFeedService {
    public static func loadFeed(
        token: String,
        callbackQueue: DispatchQueue,
        completion: @escaping @Sendable (Result<Feed, FeedError>) -> Void
    ) {
        FeedAPI.currentUser(token: token) { userResult in
            switch userResult {
            case .failure(let error):
                callbackQueue.async { completion(.failure(error)) }
            case .success(let user):
                FeedAPI.posts(for: user) { postsResult in
                    switch postsResult {
                    case .failure(let error):
                        callbackQueue.async { completion(.failure(error)) }
                    case .success(let posts):
                        let group = DispatchGroup()
                        let thumbnails = Locked<[Int: String]>([:])
                        for post in posts {
                            group.enter()
                            FeedAPI.thumbnail(postID: post.id) { url in
                                thumbnails.withLock { $0[post.id] = url }
                                group.leave()
                            }
                        }
                        group.notify(queue: callbackQueue) {
                            completion(.success(Feed(user: user, posts: posts, thumbnails: thumbnails.value)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Your work

public enum ModernFeedService {
    /// TODO: same behavior as `LegacyFeedService.loadFeed`, written with async/await.
    ///  1. Write private async wrappers for the 3 FeedAPI calls (continuations, P1.05).
    ///  2. Compose them top to bottom. No callbacks, no DispatchGroup, no locks.
    ///     Fetch thumbnails one after another for now; P3 will make them parallel.
    public static func loadFeed(token: String) async throws(FeedError) -> Feed {
        Feed(user: FeedUser(id: 0, name: "TODO"), posts: [], thumbnails: [:])
    }
}
