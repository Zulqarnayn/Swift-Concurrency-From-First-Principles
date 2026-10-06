import Dispatch

// P1.05 — SOLUTION. Continuations: bridging callback APIs to async/await
// Lesson: lessons/P1-async-await/05-continuations.md
// Test:   swift test --filter P1_05

public enum WeatherError: Error, Equatable, Sendable {
    case unknownCity
}

public struct FakeImage: Equatable, Sendable {
    public let id: String
    public let isDegraded: Bool
    public init(id: String, isDegraded: Bool) {
        self.id = id
        self.isDegraded = isDegraded
    }
}

// MARK: - Legacy APIs (don't edit)

public enum LegacyWeather {
    /// Calls `completion` exactly once, on a background queue.
    /// Known cities: "Paris" → 21, "Oslo" → -3. Anything else → .unknownCity.
    public static func fetchTemperature(city: String, completion: @escaping @Sendable (Result<Int, WeatherError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(10)) {
            switch city {
            case "Paris": completion(.success(21))
            case "Oslo": completion(.success(-3))
            default: completion(.failure(.unknownCity))
            }
        }
    }
}

public enum LegacyImageManager {
    /// Behaves like `PHImageManager.requestImage`: calls `handler` TWICE.
    /// First a fast blurry thumbnail (isDegraded: true), then ~10ms later the full image (isDegraded: false).
    public static func requestImage(id: String, handler: @escaping @Sendable (FakeImage) -> Void) {
        DispatchQueue.global().async {
            handler(FakeImage(id: id, isDegraded: true))
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(10)) {
                handler(FakeImage(id: id, isDegraded: false))
            }
        }
    }
}

// MARK: - Your work

public enum P1_05 {
    /// TODO: wrap `LegacyWeather.fetchTemperature` using `withCheckedThrowingContinuation`.
    public static func temperature(in city: String) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            LegacyWeather.fetchTemperature(city: city) { result in
                // resume(with:) takes a Result: success → returns, failure → throws.
                // Thread doesn't matter: resuming from a background queue is fine; the task
                // continues on ITS executor (e.g. back on the main actor if the caller was there).
                continuation.resume(with: result)
            }
        }
    }

    /// TODO: wrap `LegacyImageManager.requestImage` and return the FULL image (isDegraded == false).
    /// Rule: a continuation must be resumed EXACTLY once. Twice = crash. Zero = task stuck forever.
    public static func fullImage(id: String) async -> FakeImage {
        await withCheckedContinuation { continuation in
            LegacyImageManager.requestImage(id: id) { image in
                // Ignore the degraded callback. Resume only on the final one.
                // Production note: if the API might NEVER send a non-degraded image (an error path),
                // you'd need a fallback, or the task hangs forever. Always ask "what if it never calls?"
                guard !image.isDegraded else { return }
                continuation.resume(returning: image)
            }
        }
    }
}
