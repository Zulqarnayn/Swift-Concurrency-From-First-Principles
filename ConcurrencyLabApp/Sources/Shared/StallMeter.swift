import Observation
import SwiftUI

/// Measures how long the main thread goes without running our heartbeat.
/// A main-actor task tries to wake every 10ms; if it wakes 300ms later, the main thread was busy (stalled) for ~300ms.
/// Users perceive stalls above ~100ms as "the app froze".
@Observable
final class StallMeter {
    private(set) var worstStallMs = 0
    private var heartbeat: Task<Void, Never>?

    func start() {
        stop()
        heartbeat = Task { // inherits @MainActor
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(10))
                let now = ContinuousClock.now
                let stall = Int((now - last) / .milliseconds(1)) - 10
                if stall > worstStallMs { worstStallMs = stall }
                last = now
            }
        }
    }

    func reset() { worstStallMs = 0 }

    func stop() {
        heartbeat?.cancel()
        heartbeat = nil
    }
}

/// A square rotated by the main thread every frame. If the main thread stalls, it visibly stutters.
/// (Unlike `ProgressView`, whose spinning is done by the render server and keeps going during a stall.)
struct JankIndicator: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            RoundedRectangle(cornerRadius: 4)
                .fill(.tint)
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(t.truncatingRemainder(dividingBy: 1) * 360))
        }
    }
}
