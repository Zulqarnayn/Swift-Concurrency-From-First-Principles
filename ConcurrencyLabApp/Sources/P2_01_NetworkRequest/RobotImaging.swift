import CoreGraphics
import Foundation
import ImageIO
import LabKit
import UniformTypeIdentifiers

// Helpers shared by every step.
//
// ⚠️ This target is MainActor-by-default. A plain free function here would be @MainActor too,
// and calling it from background code would either fail to compile or hop to the main thread.
// These helpers touch no shared state, so they are explicitly `nonisolated`: callable from anywhere,
// running on whatever thread calls them. (Try deleting one `nonisolated` and read the errors.)

nonisolated func robotRequest(_ name: String) -> URLRequest {
    // 5s timeout: robohash is sometimes slow; we'd rather fall back to a generated image.
    URLRequest(url: URL(string: "https://robohash.org/\(name).png?size=240x240")!, timeoutInterval: 5)
}

/// The CPU-bound part. Real apps: decoding, resizing, filters, ML.
/// The 300ms of `burnCPU` exaggerates it so you can SEE where it runs (stall meter, jank square).
nonisolated func decodeImage(_ data: Data) -> CGImage? {
    trace("    decodeImage: start (CPU-bound, ~300ms)")
    burnCPU(ms: 300)
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        trace("    decodeImage: FAILED to decode \(data.count) bytes: \(String(decoding: data.prefix(80), as: UTF8.self))")
        return nil
    }
    trace("    decodeImage: done")
    return image
}

/// Network fetch with an offline fallback, so the lab works on a plane too.
/// Plain `nonisolated async`: with approachable concurrency it runs on the CALLER's actor.
/// (The waiting itself holds no thread either way — URLSession does I/O off-thread.)
nonisolated func fetchRobotData(_ name: String) async -> Data {
    do {
        let (data, response) = try await URLSession.shared.data(for: robotRequest(name))
        return validated(data, response, nil, seed: name)
    } catch {
        return validated(nil, nil, error, seed: name)
    }
}

/// URLSession only throws for TRANSPORT errors. A 404/429/500 or an empty body "succeeds".
/// Always check the status code and the payload.
nonisolated func validated(_ data: Data?, _ response: URLResponse?, _ error: (any Error)?, seed: String) -> Data {
    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
    if let data, error == nil, status == 200, !data.isEmpty {
        return data
    }
    trace("    network problem (status \(status), \(data?.count ?? 0) bytes, \(error?.localizedDescription ?? "no error")) → generated image")
    return fallbackPNG(seed: seed)
}

nonisolated func fallbackPNG(seed: String) -> Data {
    let size = 240
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let hue = CGFloat(abs(seed.hashValue % 360)) / 360
    context.setFillColor(CGColor(red: hue, green: 0.5, blue: 1 - hue, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    context.setFillColor(CGColor(gray: 1, alpha: 0.9))
    context.fillEllipse(in: CGRect(x: 60, y: 60, width: 120, height: 120))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
}
