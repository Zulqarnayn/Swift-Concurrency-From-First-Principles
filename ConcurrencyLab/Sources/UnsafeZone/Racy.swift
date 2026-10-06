import Foundation
import LabKit

// ⚠️ UNSAFE ZONE ⚠️
// This target compiles in Swift 5 mode with minimal concurrency checking.
// Every function here contains a REAL data race on purpose, so you can watch one happen.
// The same code in a Swift 6 target is rejected or warned about — see Diagnostics/P0_02_racy_counter.swift.
//
// Run with Thread Sanitizer to get a precise report:
//     swift run --sanitize=thread lab p0.02

public enum Racy {
    /// `threads` threads each run `count += 1` `increments` times. No synchronization.
    public static func counter(threads: Int, increments: Int) -> Int {
        var count = 0
        let group = DispatchGroup()
        for _ in 0..<threads {
            DispatchQueue.global().async(group: group) {
                for _ in 0..<increments {
                    count += 1 // load → add → store. Three steps. Another thread can interleave.
                }
            }
        }
        group.wait()
        return count
    }

    /// Many threads append to one Array. Array may reallocate its buffer while another thread
    /// writes into the old one → heap corruption → crash. Not just "a wrong number".
    public static func arrayAppend(threads: Int, appends: Int) -> Int {
        var array: [Int] = []
        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            for i in 0..<appends {
                array.append(i)
            }
        }
        return array.count
    }
}

// MARK: - P2.11: `lazy var` is NOT thread-safe (unlike global/static `let`, which is initialized exactly once)

public final class LazyHolder {
    public let initCount = CallCounter()
    public lazy var expensive: Int = {
        initCount.increment()
        usleep(2_000) // slow initializer widens the window
        return 42
    }()
    public init() {}
}

// MARK: - P2.13: a legacy, un-annotated Swift 5 API that calls back on a background queue

public final class LegacyThermometerClient {
    /// Called on a BACKGROUND queue, once per reading. (No annotations: written before Swift concurrency.)
    public var onReading: ((Int) -> Void)?

    public init() {}

    public func start(count: Int) {
        DispatchQueue.global().async {
            for i in 0..<count {
                usleep(2_000)
                self.onReading?(20 + i)
            }
        }
    }
}

public enum LegacyScheduler {
    /// Swift 5 API taking a plain (non-Sendable) closure and calling it on a background queue.
    public static func runInBackground(_ work: @escaping () -> Void) {
        DispatchQueue.global().async { work() }
    }
}

// MARK: - P5.04: a legacy delegate-based location API (Swift 5, un-annotated, callbacks on a background queue)

public protocol LegacyLocationDelegate: AnyObject {
    func provider(_ provider: LegacyLocationProvider, didUpdate location: Int)
    func provider(_ provider: LegacyLocationProvider, didFailWith error: Error)
}

public final class LegacyLocationProvider {
    public enum Scenario { case success, denied, slow }

    /// Like CLLocationManager: the delegate is WEAK.
    public weak var delegate: LegacyLocationDelegate?
    public let scenario: Scenario
    public private(set) var stopCount = 0
    private var stopped = false
    private let lock = NSLock()

    public init(scenario: Scenario) {
        self.scenario = scenario
    }

    /// Calls back ONCE on a background queue: didUpdate (success, after 10ms; slow, after 500ms) or didFail (denied).
    /// After `stop()`, no callback is delivered at all.
    public func requestLocation() {
        let delay = scenario == .slow ? 500 : 10
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(delay)) {
            let isStopped = self.lock.withLock { self.stopped }
            if isStopped { return }
            switch self.scenario {
            case .success, .slow: self.delegate?.provider(self, didUpdate: 42)
            case .denied: self.delegate?.provider(self, didFailWith: NSError(domain: "kCLErrorDomain", code: 1))
            }
        }
    }

    public func stop() {
        lock.withLock {
            stopped = true
            stopCount += 1
        }
    }
}
