// FLAGS: -swift-version 6 -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: warning: main actor-isolated property 'cgImage' can not be mutated from a Sendable closure
// EXPECT: warning: call to main actor-isolated global function 'decode' in a synchronous nonisolated context
// EXPECT: error: main actor-isolated property 'cgImage' can not be mutated from a nonisolated context
// EXPECT: error: main actor-isolated global function 'decode' cannot be called from outside of the actor
//
// Lesson P2.01. Compiled like a NEW Xcode 26 app target: MainActor by default + approachable concurrency.
// PREDICT for each function: compiles? warning? error? Then:
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_01_default_isolation.swift
//
// (Plain model class instead of a SwiftUI View, so this file compiles standalone. Same rules.)

import Foundation
import CoreGraphics

final class RobotModel {           // MainActor by default in this module
    var cgImage: CGImage?

    // Massicotte step: moving CPU work off main with GCD
    func loadWithGCD(url: URL) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            self.cgImage = decode(data ?? Data())
        }.resume()
    }

    // Massicotte step: @concurrent that mutates state
    @concurrent
    func loadConcurrent(url: URL) async {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        self.cgImage = decode(data)
    }
}

func decode(_ data: Data) -> CGImage? { nil }   // what isolation does this free function get?
