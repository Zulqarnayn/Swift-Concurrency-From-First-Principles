import LabKit

// P2.08 — nonisolated(nonsending) vs @concurrent
// Lesson: lessons/P2-isolation/08-nonsending-vs-concurrent.md
// Test:   swift test --filter P2_08

public struct PipelineReport: Equatable, Sendable {
    public let validatedOnMain: Bool
    public let filteredOnMain: Bool
    public init(validatedOnMain: Bool, filteredOnMain: Bool) {
        self.validatedOnMain = validatedOnMain
        self.filteredOnMain = filteredOnMain
    }
}

/// Called from the main actor (think: a photo editor screen).
///   - `validate` is cheap, and in the real app reads state owned by the caller → must run on the CALLER's actor.
///   - `applyFilters` is 50ms of CPU work → must NOT run on the caller's actor (it would freeze the UI).
///
/// BUG: the annotations are exactly backwards. Fix them. Change annotations only.
public enum P2_08 {
    @concurrent
    public static func validate(_ pixels: [Int]) async -> Bool {
        _ = pixels.allSatisfy { $0 >= 0 }
        return isMainThread()
    }

    public static func applyFilters(_ pixels: [Int]) async -> Bool {
        burnCPU(ms: 50)
        return isMainThread()
    }

    public static func process(_ pixels: [Int]) async -> PipelineReport {
        let validated = await validate(pixels)
        let filtered = await applyFilters(pixels)
        return PipelineReport(validatedOnMain: validated, filteredOnMain: filtered)
    }
}
