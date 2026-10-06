import Dispatch
import LabKit

// P5.07 — SOLUTION. Bug hunt: "uploads keep running after leaving the screen, and an error alert pops up on the next screen"
// Lesson: lessons/P5-bug-zoo/07-cancellation-bugs.md
// Repro:  swift run lab p5.07        Test: swift test --filter P5_07

public struct UploadFailed: Error {}

/// A legacy upload API (don't edit), shaped like a URLSessionTask:
///  - `start` calls `completion` after 100ms; the first `failFirst` attempts fail (flaky network)
///  - `cancel()` stops the in-flight upload and calls its completion RIGHT AWAY with `CancellationError`
public final class LegacyUploader: Sendable {
    private struct State {
        var attempts = 0
        var cancels = 0
        var completion: (@Sendable (Result<Void, any Error>) -> Void)?
    }
    private let state = Locked(State())
    public let failFirst: Int

    public init(failFirst: Int = 0) { self.failFirst = failFirst }

    public var attempts: Int { state.value.attempts }
    public var cancels: Int { state.value.cancels }

    public func start(_ file: String, completion: @escaping @Sendable (Result<Void, any Error>) -> Void) {
        let attempt = state.withLock { s -> Int in
            s.attempts += 1
            s.completion = completion
            return s.attempts
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) { [self] in
            take()?(attempt <= failFirst ? .failure(UploadFailed()) : .success(()))
        }
    }

    public func cancel() {
        state.withLock { $0.cancels += 1 }
        take()?(.failure(CancellationError()))
    }

    private func take() -> (@Sendable (Result<Void, any Error>) -> Void)? {
        state.withLock { s in
            defer { s.completion = nil }
            return s.completion
        }
    }
}

@MainActor
public final class UploadController {
    /// Error messages shown to the user.
    public private(set) var alerts: [String] = []
    public private(set) var uploadedFiles: [String] = []
    private let uploader: LegacyUploader

    public init(uploader: LegacyUploader) {
        self.uploader = uploader
    }

    /// Upload with up to 3 attempts, 50ms apart. Runs in the screen's `.task`, so leaving the screen cancels it.
    public func upload(_ file: String) async {
        for attempt in 1...3 {
            do {
                try await send(file)
                uploadedFiles.append(file)
                return
            } catch is CancellationError {
                // ROOT CAUSE #1: the catch-all treated "the user left" as a failure (alert on the next
                // screen) and kept retrying. FIX: cancellation is not an error to report or retry.
                return
            } catch {
                if attempt == 3 {
                    alerts.append("Upload failed: \(error)")
                    return
                }
                // ROOT CAUSE #2: `try?` swallowed the cancellation, so the next attempt started at once.
                do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
            }
        }
    }

    private func send(_ file: String) async throws {
        try Task.checkCancellation()
        let uploader = self.uploader
        // ROOT CAUSE #3: cancellation was never forwarded to the legacy upload, so it ran to completion.
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                uploader.start(file) { continuation.resume(with: $0) }
            }
        } onCancel: {
            uploader.cancel() // completes the request with CancellationError → resumes the continuation once
        }
    }
}
