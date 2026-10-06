// swift-tools-version: 6.2
import PackageDescription

// "Modern" semantics = what a new Xcode 26 project gives you (Approachable Concurrency):
// a plain `nonisolated async func` runs on the CALLER's actor (SE-0461).
// To leave the caller's actor you must say `@concurrent`.
let modern: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "ConcurrencyLab",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "LabKit", targets: ["LabKit"]),
        .executable(name: "lab", targets: ["lab"]),
    ],
    targets: [
        // Shared tools: trace(), CPU/blocking/suspending work, meters, timeouts.
        .target(name: "LabKit", swiftSettings: modern),

        // Swift 5 mode, minimal checking. The ONLY place real data races compile.
        // Used to show races at runtime + Thread Sanitizer. Never write code like this for real.
        .target(
            name: "UnsafeZone",
            dependencies: ["LabKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        // Same Swift 6 checking, but PRE-6.2 async semantics: `nonisolated async` funcs always leave the
        // caller's actor (no NonisolatedNonsendingByDefault). Used to compare behaviors in P2.08 / P2.15.
        .target(name: "LegacySemantics", dependencies: ["LabKit"]),

        // Like a new Xcode 26 app target: everything is @MainActor unless marked otherwise (SE-0466). P2.09.
        .target(
            name: "MainActorDefault",
            dependencies: ["LabKit"],
            swiftSettings: modern + [.defaultIsolation(MainActor.self)]
        ),

        // "Predict the output" puzzles. Your predictions live in Exercises; tests compare them.
        .target(name: "Puzzles", dependencies: ["LabKit"], swiftSettings: modern),

        // One file per lesson demo. Run with `swift run lab <id>`.
        .target(
            name: "Demos",
            // Phase 5 demos are repro harnesses that run YOUR exercise code, hence the Exercises dependency.
            dependencies: ["LabKit", "UnsafeZone", "Puzzles", "LegacySemantics", "MainActorDefault", "Exercises"],
            swiftSettings: modern
        ),

        // YOUR work. Stubs compile but are wrong/broken; make the tests pass.
        .target(name: "Exercises", dependencies: ["LabKit", "UnsafeZone"], swiftSettings: modern),

        .executableTarget(name: "lab", dependencies: ["Demos", "LabKit"], swiftSettings: modern),

        .testTarget(name: "ExercisesTests", dependencies: ["Exercises", "LabKit", "Puzzles", "UnsafeZone"], swiftSettings: modern),
    ]
)
