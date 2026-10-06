import CoreGraphics
import LabKit
import Observation
import SwiftUI

// P4.10 — A grid of 60 cells showing 20 distinct images (lots of repeats, like a real feed).
// Naive loader: one download per cell, all at once, nothing evicted.
// Pipeline: dedupe in-flight + max 4 downloads + LRU cache. (Spoiler for exercise P4_10 — do that first.)

nonisolated final class FakeImageCDN: Sendable {
    let downloads = CallCounter()
    let meter = ConcurrencyMeter()

    @concurrent func download(_ id: Int) async throws -> CGImage {
        downloads.increment()
        meter.enter()
        defer { meter.leave() }
        try await Task.sleep(for: .milliseconds(250))
        return Self.render(id)
    }

    private static func render(_ id: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let hue = CGFloat(id % 20) / 20
        ctx.setFillColor(CGColor(red: hue, green: 1 - hue, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        return ctx.makeImage()!
    }
}

nonisolated protocol ImageLoading: Sendable {
    func image(_ id: Int) async throws -> CGImage
}

actor NaiveImageLoader: ImageLoading {
    let cdn: FakeImageCDN
    private var cache: [Int: CGImage] = [:]
    init(cdn: FakeImageCDN) { self.cdn = cdn }

    func image(_ id: Int) async throws -> CGImage {
        if let hit = cache[id] { return hit }
        let image = try await cdn.download(id) // reentrancy: 3 cells with the same id → 3 downloads
        cache[id] = image
        return image
    }
}

actor ImagePipelineLab: ImageLoading {
    let cdn: FakeImageCDN
    private let capacity: Int
    private var cache: [Int: CGImage] = [:]
    private var recency: [Int] = []
    private var inFlight: [Int: Task<CGImage, any Error>] = [:]
    private var freeSlots: Int
    private var slotWaiters: [CheckedContinuation<Void, Never>] = []

    init(cdn: FakeImageCDN, maxConcurrent: Int, capacity: Int) {
        self.cdn = cdn
        self.capacity = capacity
        freeSlots = maxConcurrent
    }

    func image(_ id: Int) async throws -> CGImage {
        if let hit = cache[id] { touch(id); return hit }
        if let running = inFlight[id] { return try await running.value }
        let task = Task {
            await acquire()
            defer { release() }
            return try await cdn.download(id)
        }
        inFlight[id] = task
        defer { inFlight[id] = nil }
        let image = try await task.value
        cache[id] = image
        touch(id)
        while recency.count > capacity { cache[recency.removeFirst()] = nil }
        return image
    }

    private func touch(_ id: Int) { recency.removeAll { $0 == id }; recency.append(id) }
    private func acquire() async {
        if freeSlots > 0 { freeSlots -= 1; return }
        await withCheckedContinuation { slotWaiters.append($0) }
    }
    private func release() {
        if slotWaiters.isEmpty { freeSlots += 1 } else { slotWaiters.removeFirst().resume() }
    }
}

struct ImageGridLab: View {
    var autorun = false
    @State private var usePipeline = false
    @State private var generation = 0
    @State private var loader: any ImageLoading = NaiveImageLoader(cdn: FakeImageCDN())
    @State private var cdn = FakeImageCDN()
    @State private var stats = "—"

    var body: some View {
        VStack(spacing: 10) {
            Toggle("Use pipeline (dedupe + max 4 + LRU 12)", isOn: $usePipeline)
                .onChange(of: usePipeline) { reset() }
            Text(stats).font(.caption.monospaced())
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                    ForEach(0..<60, id: \.self) { cell in
                        GridCell(id: cell % 20, loader: loader)
                    }
                }
                .id(generation) // a new generation = fresh cells
            }
        }
        .padding()
        .navigationTitle("P4.10 · Image pipeline")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reset() }
        .task {
            while !Task.isCancelled {
                stats = "downloads \(cdn.downloads.count) · peak in flight \(cdn.meter.peak) · cells 60 · distinct 20"
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        .task {
            guard autorun else { return }
            for pipeline in [false, true] {
                usePipeline = pipeline
                reset()
                try? await Task.sleep(for: .seconds(2.5))
                trace("■ \(pipeline ? "PIPELINE" : "NAIVE"): \(cdn.downloads.count) downloads, peak \(cdn.meter.peak) in flight (60 cells, 20 distinct images)")
            }
        }
    }

    private func reset() {
        cdn = FakeImageCDN()
        loader = usePipeline ? ImagePipelineLab(cdn: cdn, maxConcurrent: 4, capacity: 12) : NaiveImageLoader(cdn: cdn)
        generation += 1
    }
}

private struct GridCell: View {
    let id: Int
    let loader: any ImageLoading
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
            if let image { Image(decorative: image, scale: 1).resizable().clipShape(RoundedRectangle(cornerRadius: 6)) }
            Text("\(id)").font(.caption2).foregroundStyle(.secondary)
        }
        .aspectRatio(1, contentMode: .fit)
        .task { image = try? await loader.image(id) }
    }
}
