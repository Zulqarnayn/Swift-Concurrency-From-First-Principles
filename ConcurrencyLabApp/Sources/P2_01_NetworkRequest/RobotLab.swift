import LabKit
import SwiftUI

// P2.01 — Massicotte's "Concurrency Step-by-Step: A Network Request", rebuilt as a lab.
// https://www.massicotte.org/step-by-step-network-request/
//
// Every step does the same job — download a robot PNG, decode it (CPU-bound), show it —
// with a different concurrency design. Watch the trace console (which thread ran what)
// and the stall meter (how long the main thread froze).

enum RobotStep: String, CaseIterable, Identifiable {
    case gcd, asyncOnMain, concurrent, detached, mainActorRun

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gcd: "Step 1 · GCD + completion handler"
        case .asyncOnMain: "Step 2 · async/await, all on the main actor"
        case .concurrent: "Step 3 · @concurrent helper that RETURNS a value"
        case .detached: "Alt A · Task.detached + Task { @MainActor }"
        case .mainActorRun: "Alt B · @concurrent + MainActor.run"
        }
    }
}

struct RobotLab: View {
    let step: RobotStep
    var autorun = false

    @State private var cgImage: CGImage?
    @State private var robotName = "swift"
    @State private var runID = 0
    @State private var stall = StallMeter()
    private let log = TraceLog.shared

    var body: some View {
        VStack(spacing: 12) {
            LoadedImageView(cgImage: cgImage)

            HStack {
                Button("Load a new robot") { reload() }
                    .buttonStyle(.borderedProminent)
                Spacer()
                JankIndicator()
                Text("worst stall: \(stall.worstStallMs)ms")
                    .monospacedDigit()
                    .foregroundStyle(stall.worstStallMs > 100 ? .red : .secondary)
            }

            TraceConsole(lines: log.lines)
        }
        .padding()
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            stall.start()
            if autorun { runOnceAndReport() }
        }
        .onDisappear { stall.stop() }
        // The async steps start here. `.task(id:)` re-runs when runID changes and is cancelled automatically
        // if the view goes away. Its closure inherits the View's isolation: @MainActor.
        .task(id: runID) {
            guard runID > 0 else { return }
            switch step {
            case .gcd: break // not async; started directly in reload()
            case .asyncOnMain: await loadAsyncOnMain()
            case .concurrent: await loadWithConcurrentHelper()
            case .detached: loadWithDetached()
            case .mainActorRun: await loadWithMainActorRun()
            }
        }
    }

    private func runOnceAndReport() {
        Task {
            try? await Task.sleep(for: .milliseconds(500)) // let the stall meter settle first
            reload()
            try? await Task.sleep(for: .seconds(9)) // robohash can be slow
            trace("■ worst main-thread stall: \(stall.worstStallMs)ms")
        }
    }

    private func reload() {
        log.clear()
        stall.reset()
        cgImage = nil
        robotName = ["swift", "actor", "task", "await", "sendable", "isolation"].randomElement()! + "\(Int.random(in: 1...999))"
        trace("▶︎ \(step.title)")
        if step == .gcd {
            loadWithGCD()
        } else {
            runID += 1
        }
    }

    // MARK: - Step 1: GCD (the "correct GCD pattern": work in the background, hop to main for UI)

    private func loadWithGCD() {
        let request = robotRequest(robotName)
        let name = robotName
        trace("GCD: dataTask.resume()")
        URLSession.shared.dataTask(with: request) { data, response, error in
            trace("GCD: completion handler")
            let image = decodeImage(validated(data, response, error, seed: name))
            DispatchQueue.main.async {
                trace("GCD: main.async → assign cgImage")
                self.cgImage = image
            }
        }.resume()
        trace("GCD: loadWithGCD() returned")
    }

    // MARK: - Step 2: async/await, everything on the main actor

    private func loadAsyncOnMain() async {
        trace("step 2: start")
        let data = await fetchRobotData(robotName)
        trace("step 2: data arrived")
        cgImage = decodeImage(data)
        trace("step 2: assigned cgImage")
    }

    // MARK: - Step 3: a @concurrent helper returns the result; the main actor assigns it

    private func loadWithConcurrentHelper() async {
        trace("step 3: start")
        let image = await Self.fetchAndDecode(robotName)
        trace("step 3: back on the caller's actor → assign")
        cgImage = image
    }

    @concurrent
    private static func fetchAndDecode(_ name: String) async -> CGImage? {
        trace("  @concurrent fetchAndDecode: start")
        let data = await fetchRobotData(name)
        trace("  @concurrent fetchAndDecode: data arrived")
        return decodeImage(data)
    }

    // MARK: - Alternative A: Task.detached with a nested main-actor Task (discouraged)

    private func loadWithDetached() {
        let name = robotName
        trace("alt A: creating Task.detached")
        Task.detached {
            trace("  detached: start")
            let image = decodeImage(await fetchRobotData(name))
            Task { @MainActor in
                trace("  nested Task @MainActor: assign")
                self.cgImage = image
            }
            trace("  detached: done (UI not updated yet!)")
        }
        trace("alt A: function returned — the work is NOT done")
    }

    // MARK: - Alternative B: @concurrent + MainActor.run (works, but isolation is checked at runtime-ish call sites)

    private func loadWithMainActorRun() async {
        trace("alt B: start")
        await loadAndAssignViaMainActorRun(robotName)
        trace("alt B: done")
    }

    @concurrent
    private func loadAndAssignViaMainActorRun(_ name: String) async {
        trace("  @concurrent: start")
        let image = decodeImage(await fetchRobotData(name))
        await MainActor.run {
            trace("  MainActor.run: assign")
            self.cgImage = image
        }
    }
}

struct LoadedImageView: View {
    let cgImage: CGImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.quaternary)
            if let cgImage {
                Image(decorative: cgImage, scale: 1).resizable().scaledToFit()
            } else {
                Text("Tap “Load a new robot”").foregroundStyle(.secondary)
            }
        }
        .frame(height: 220)
    }
}

struct TraceConsole: View {
    let lines: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(line.contains("MAIN") ? Color.primary : Color.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
